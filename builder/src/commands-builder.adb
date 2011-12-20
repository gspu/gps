------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2003-2012, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Strings;                      use Ada.Strings;
with Ada.Strings.Fixed;                use Ada.Strings.Fixed;
with Ada.Strings.Maps;                 use Ada.Strings.Maps;

with GNAT.OS_Lib;                      use GNAT.OS_Lib;
with GNAT.Expect;                      use GNAT.Expect;
with GNAT.Regpat;                      use GNAT.Regpat;
with GNAT.String_Split;                use GNAT.String_Split;
with GPS.Kernel.Messages; use GPS.Kernel.Messages;
with GPS.Kernel.Task_Manager; use GPS.Kernel.Task_Manager;

pragma Warnings (Off);
with GNAT.Expect.TTY;                  use GNAT.Expect.TTY;
pragma Warnings (On);

with Gtk.Text_View;                    use Gtk.Text_View;

with Gtkada.MDI;                       use Gtkada.MDI;

with GPS.Kernel;                       use GPS.Kernel;
with GPS.Kernel.Console;               use GPS.Kernel.Console;
with GPS.Kernel.MDI;                   use GPS.Kernel.MDI;
with GPS.Kernel.Messages.Legacy;       use GPS.Kernel.Messages.Legacy;
with GPS.Kernel.Messages.Tools_Output; use GPS.Kernel.Messages.Tools_Output;
with GPS.Kernel.Preferences;           use GPS.Kernel.Preferences;
with GPS.Styles;                       use GPS.Styles;
with GPS.Styles.UI;                    use GPS.Styles.UI;
with GPS.Intl;                         use GPS.Intl;
with Traces;                           use Traces;
with Basic_Types;                      use Basic_Types;
with UTF8_Utils;                       use UTF8_Utils;

with Builder_Facility_Module;          use Builder_Facility_Module;

package body Commands.Builder is

   Shell_Env : constant String := Getenv ("SHELL").all;

   -----------------------
   -- Local subprograms --
   -----------------------

   procedure Parse_Compiler_Output
     (Kernel           : Kernel_Handle;
      Styles           : Builder_Message_Styles;
      Output           : String;
      Data             : Build_Callback_Data);
   --  Parse the output of build engine and insert the result
   --    - in the GPS results view if it corresponds to a file location
   --    - in the GPS console if it is a general message.
   --  Category is the category to add to in the results view.
   --  Warning_Category and Style_Category correspond to the categories
   --  used for warnings and style errors.

   procedure Build_Callback (Data : Process_Data; Output : String);
   --  Callback for the build output

   procedure End_Build_Callback (Data : Process_Data; Status : Integer);
   --  Called at the end of the build

   -------------
   -- Destroy --
   -------------

   overriding procedure Destroy (Data : in out Build_Callback_Data) is
   begin
      null;
   end Destroy;

   -----------------------
   -- Get_Build_Console --
   -----------------------

   function Get_Build_Console
     (Kernel              : GPS.Kernel.Kernel_Handle;
      Shadow              : Boolean;
      Background          : Boolean;
      Create_If_Not_Exist : Boolean;
      New_Console_Name    : String := "") return Interactive_Console is
   begin
      if New_Console_Name /= "" then
         return Create_Interactive_Console
           (Kernel              => Kernel,
            Title               => New_Console_Name,
            History             => "interactive",
            Create_If_Not_Exist => True,
            Module              => null,
            Force_Create        => False,
            ANSI_Support        => True,
            Accept_Input        => True);
      end if;

      if Background then
         return Create_Interactive_Console
           (Kernel              => Kernel,
            Title               => -"Background Builds",
            History             => "interactive",
            Create_If_Not_Exist => Create_If_Not_Exist,
            Module              => null,
            Force_Create        => False,
            Accept_Input        => False);

      elsif Shadow then
         return Create_Interactive_Console
           (Kernel              => Kernel,
            Title               => -"Auxiliary Builds",
            History             => "interactive",
            Create_If_Not_Exist => Create_If_Not_Exist,
            Module              => null,
            Force_Create        => False,
            Accept_Input        => False);
      else
         return Get_Console (Kernel);
      end if;
   end Get_Build_Console;

   ------------------------------
   -- Display_Compiler_Message --
   ------------------------------

   procedure Display_Compiler_Message
     (Kernel     : GPS.Kernel.Kernel_Handle;
      Message    : String;
      Data       : Build_Callback_Data)
   is
      Console : Interactive_Console;
   begin
      Console := Get_Build_Console
        (Kernel, Data.Shadow, Data.Background, False);

      if Console /= null then
         Insert (Console, Message, Add_LF => False);
      end if;
   end Display_Compiler_Message;

   ------------------------
   -- End_Build_Callback --
   ------------------------

   procedure End_Build_Callback (Data : Process_Data; Status : Integer) is
      Build_Data : Build_Callback_Data
                     renames Build_Callback_Data (Data.Callback_Data.all);

   begin
      --  Raise the messages window is compilation was unsuccessful
      --  and no error was parsed. See D914-005

      if Category_Count (Data.Kernel, To_String (Build_Data.Category_Name)) = 0
        and then Status /= 0
        and then not Build_Data.Background
      then
         Console.Raise_Console (Data.Kernel);
      end if;

      Destroy (Build_Data.Background_Env);

      if Build_Data.Background then
         --  We remove the previous background build data messages only when
         --  the new background build is completed.

         Get_Messages_Container (Data.Kernel).Remove_Category
           (Previous_Background_Build_Id, Background_Message_Flags);

         Background_Build_Finished;
      end if;

      --  ??? should also pass the Status value to Compilation_Finished
      --  and to the corresponding hook

      Compilation_Finished
        (Data.Kernel,
         To_String (Build_Data.Category_Name),
         To_String (Build_Data.Target_Name),
         To_String (Build_Data.Mode_Name),
         Build_Data.Shadow,
         Build_Data.Background,
         Status);
   end End_Build_Callback;

   --------------------
   -- Build_Callback --
   --------------------

   procedure Build_Callback (Data : Process_Data; Output : String) is
      Last_EOL : Natural := 1;
      Str      : GNAT.OS_Lib.String_Access;

      Build_Data : Build_Callback_Data
        renames Build_Callback_Data (Data.Callback_Data.all);
   begin
      if not Data.Process_Died then
         Last_EOL := Index (Output, (1 => ASCII.LF), Backward);

         --  In case we did not find any LF in the output, we'll just append it
         --  in the current buffer.

         if Last_EOL = 0 then
            Append (Build_Data.Buffer, Output);
            return;
         end if;

      else
         if Output'Length > 0 then
            Last_EOL := Output'Length + 1;
         end if;
      end if;

      --  Collect the relevant portion of the output

      if Output'Length > 0 then
         Str := new String'
           (To_String (Build_Data.Buffer)
            & Output (Output'First .. Last_EOL - 1) & ASCII.LF);

         Build_Data.Buffer :=
           To_Unbounded_String (Output (Last_EOL + 1 .. Output'Last));

      elsif Data.Process_Died then
         Str := new String'(To_String (Build_Data.Buffer) & ASCII.LF);
         Build_Data.Buffer := Null_Unbounded_String;
      else
         return;
      end if;

      --  If we reach this point, this means we have collected some output to
      --  parse. In this case, verify that it is proper UTF-8 before
      --  transmitting it to the rest of GPS.

      --  It is hard to determine which encoding the compiler result is,
      --  especially given that we are supporting third-party compilers, build
      --  scripts, etc. Therefore, we call Unknown_To_UTF8.

      declare
         Output : Basic_Types.Unchecked_String_Access;
         Len    : Natural;
         Valid  : Boolean;

      begin
         Unknown_To_UTF8 (Str.all, Output, Len, Valid);

         if Valid then
            if Output = null then
               Process_Builder_Output
                 (Kernel  => Data.Kernel,
                  Command => Data.Command,
                  Output  => Str.all,
                  Data    => Build_Data);

            else
               Process_Builder_Output
                 (Kernel  => Data.Kernel,
                  Command => Data.Command,
                  Output  => Output (1 .. Len),
                  Data    => Build_Data);
            end if;
         else
            Console.Insert
              (Data.Kernel,
               -"Could not convert compiler output to UTF8",
               Mode => Console.Error);
         end if;

         Free (Str);
         Basic_Types.Free (Output);
      end;
   end Build_Callback;

   ---------------------------
   -- Parse_Compiler_Output --
   ---------------------------

   procedure Parse_Compiler_Output
     (Kernel : Kernel_Handle;
      Styles : Builder_Message_Styles;
      Output : String;
      Data   : Build_Callback_Data)
   is
      pragma Unreferenced (Styles);
      Last  : Natural;
      Lines : Slice_Set;

   begin
      Display_Compiler_Message (Kernel, Output, Data);

      if Output'Length = 0
        or else
          (Output'Length = 1
            and then Output (Output'First) = ASCII.LF)
      then
         return;
      end if;

      --  A string terminated by an ASCII.LF is split into the some string plus
      --  an extra empty one. We therefore need to remove the trailing ASCII.LF
      --  from the string before splitting it.

      Last := Output'Last;

      if Last > Output'First
        and then Output (Last) = ASCII.LF
      then
         Last := Last - 1;
      end if;

      Create
        (Lines,
         From       => Output (Output'First .. Last),
         Separators => To_Set (ASCII.LF),
         Mode       => Single);

      for J in 1 .. Slice_Count (Lines) loop
         Append_To_Build_Output
           (Kernel, Slice (Lines, J), To_String (Data.Target_Name),
            Data.Shadow,
            Data.Background);
      end loop;

      Parse_File_Locations
        (Kernel,
         Output,
         Category          => To_String (Data.Category_Name),
         Highlight         => True,
         Styles            => Builder_Styles,
         Show_In_Locations => not Data.Background);

   exception
      when E : others => Trace (Exception_Handle, E);
   end Parse_Compiler_Output;

   ----------------------------
   -- Process_Builder_Output --
   ----------------------------

   Completed_Matcher : constant Pattern_Matcher := Compile
     ("completed ([0-9]+) out of ([0-9]+) \(([^\n]*)%\)\.\.\.\n", Single_Line);
   --  ??? This is configurable in some cases (from XML for instance), so
   --  we should not have a hard coded regexp here.

   procedure Process_Builder_Output
     (Kernel     : access GPS.Kernel.Kernel_Handle_Record'Class;
      Command    : Commands.Command_Access;
      Output     : Glib.UTF8_String;
      Data       : Build_Callback_Data)
   is
      Start   : Integer := Output'First;
      Matched : Match_Array (0 .. 3);
      Buffer  : Unbounded_String;

   begin
      while Start <= Output'Last loop
         Match (Completed_Matcher, Output (Start .. Output'Last), Matched);
         exit when Matched (0) = No_Match;

         Command.Progress.Current := Natural'Value
           (Output (Matched (1).First .. Matched (1).Last));
         Command.Progress.Total := Natural'Value
           (Output (Matched (2).First .. Matched (2).Last));

         Append (Buffer, Output (Start .. Matched (0).First - 1));
         Start := Matched (0).Last + 1;
      end loop;

      Append (Buffer, Output (Start .. Output'Last));

      if Length (Buffer) /= 0 then
         Parse_Compiler_Output
           (Kernel           => Kernel_Handle (Kernel),
            Styles           => Builder_Styles,
            Output           => To_String (Buffer),
            Data             => Data);
      end if;
   end Process_Builder_Output;

   --------------------------
   -- Launch_Build_Command --
   --------------------------

   procedure Launch_Build_Command
     (Kernel           : GPS.Kernel.Kernel_Handle;
      CL               : Arg_List;
      Data             : Build_Callback_Data_Access;
      Server           : Server_Type;
      Synchronous      : Boolean;
      Use_Shell        : Boolean;
      New_Console_Name : String;
      Directory        : Virtual_File)
   is
      Console  : Interactive_Console;
      Success  : Boolean := False;
      Cmd_Name : Unbounded_String;
      Cb       : Output_Callback;
      Exit_Cb  : Exit_Callback;
      Is_A_Run : Boolean;
      Show_Output  : Boolean;
      Show_Command : Boolean;
      Created_Command : Scheduled_Command_Access;
      Background : constant Boolean := Data.Background;
   begin
      if New_Console_Name /= "" then
         Console := Get_Build_Console
           (Kernel, Data.Shadow, Data.Background, False, New_Console_Name);
         Cb      := null;
         Exit_Cb := null;
         Show_Output := not Data.Background;
         Show_Command := not Data.Background;
         Is_A_Run := True;

         Modify_Font (Get_View (Console), View_Fixed_Font.Get_Pref);

      else
         Console := Get_Build_Console
           (Kernel, Data.Shadow, Data.Background, False);
         Cb      := Build_Callback'Access;
         Exit_Cb := End_Build_Callback'Access;
         Show_Output := False;
         Show_Command := not Data.Background;
         Is_A_Run := False;
      end if;

      if not Is_A_Run
        and then not Data.Background
      then
         --  If we are starting a "real" build, remove messages from the
         --  current background build
         Get_Messages_Container (Kernel).Remove_Category
           (Previous_Background_Build_Id, Background_Message_Flags);
      end if;

      if not (Data.Shadow or else Data.Quiet or else Data.Background) then
         if Is_A_Run then
            Clear (Console);
            Raise_Child (Find_MDI_Child (Get_MDI (Kernel), Console),
                         Give_Focus => True);
         else
            Raise_Console (Kernel);
         end if;
      end if;

      if Is_A_Run
        or else Compilation_Starting
          (Handle     => Kernel,
           Category   => To_String (Data.Category_Name),
           Quiet      => Data.Quiet,
           Shadow     => Data.Shadow,
           Background => Data.Background)
      then
         Append_To_Build_Output
           (Kernel, To_Display_String (CL), To_String (Data.Target_Name),
            Data.Shadow, Data.Background);

         if Data.Mode_Name /= "default" then
            Cmd_Name := Data.Target_Name & " (" & Data.Mode_Name & ")";
         else
            Cmd_Name := Data.Target_Name;
         end if;

         if Use_Shell
           and then Shell_Env /= ""
           and then Is_Local (Server)
         then
            declare
               CL2 : Arg_List;
            begin
               Append_Argument (CL2, Shell_Env, One_Arg);
               Append_Argument (CL2, "-c", One_Arg);
               Append_Argument (CL2, To_Display_String (CL), One_Arg);

               Launch_Process
                 (Kernel,
                  CL                   => CL2,
                  Server               => Server,
                  Console              => Console,
                  Show_Command         => Show_Command,
                  Show_Output          => Show_Output,
                  Callback_Data        => Data.all'Access,
                  Success              => Success,
                  Line_By_Line         => False,
                  Directory            => Directory,
                  Callback             => Cb,
                  Exit_Cb              => Exit_Cb,
                  Show_In_Task_Manager => not Data.Background,
                  Name_In_Task_Manager => To_String (Cmd_Name),
                  Synchronous          => Synchronous,
                  Show_Exit_Status     => not (Data.Shadow
                    or else Data.Background),
                  Created_Command      => Created_Command);
            end;

         else
            Launch_Process
              (Kernel,
               CL                   => CL,
               Server               => Server,
               Console              => Console,
               Show_Command         => Show_Command,
               Show_Output          => Show_Output,
               Callback_Data        => Data.all'Access,
               Success              => Success,
               Line_By_Line         => False,
               Directory            => Directory,
               Callback             => Cb,
               Exit_Cb              => Exit_Cb,
               Show_In_Task_Manager => not Data.Background,
               Name_In_Task_Manager => To_String (Cmd_Name),
               Synchronous          => Synchronous,
               Show_Exit_Status     => not (Data.Shadow
                 or else Data.Background),
               Created_Command      => Created_Command);
         end if;

         --  ??? check value of Success

         if Success and then Background then
            Background_Build_Started (Created_Command);
         end if;
      end if;

   end Launch_Build_Command;

end Commands.Builder;
