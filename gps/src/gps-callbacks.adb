------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2001-2014, AdaCore                     --
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

pragma Warnings (Off);
with GNAT.Expect.TTY.Remote;    use GNAT.Expect.TTY.Remote;
pragma Warnings (On);

with GNATCOLL.Traces;           use GNATCOLL.Traces;
with GPS.Main_Window;           use GPS.Main_Window;

package body GPS.Callbacks is

   Gtk_Trace : constant Trace_Handle := Create ("Gtk+");

   -------------
   -- Gtk_Log --
   -------------

   procedure Gtk_Log
     (Log_Domain : String;
      Log_Level  : Log_Level_Flags;
      Message    : String) is
   begin
      if Log_Domain = "" then
         --  Ignore this message, to avoid generating too much noise
         return;
      end if;

      if (Log_Level and Log_Level_Critical) /= 0 then
         Trace (Gtk_Trace, Log_Domain & "-CRITICAL: " & Message);
      elsif (Log_Level and Log_Level_Warning) /= 0 then
         Trace (Gtk_Trace, Log_Domain & "-WARNING: " & Message);
      else
         Trace (Gtk_Trace, Log_Domain & "-MISC: " & Message);
      end if;
   exception
      when E : others =>
         Trace (Gtk_Trace, E);
   end Gtk_Log;

   --------------------
   -- Ctrl_C_Handler --
   --------------------

   procedure Ctrl_C_Handler is
   begin
      --  Ignore Ctrl-C events

      null;
   end Ctrl_C_Handler;

   -------------------
   -- Title_Changed --
   -------------------

   procedure Title_Changed
     (MDI    : access GObject_Record'Class;
      Child  : Gtk_Args;
      Kernel : Kernel_Handle)
   is
      pragma Unreferenced (MDI);
      C : MDI_Child;
   begin
      if not Kernel.Is_In_Destruction then
         C := MDI_Child (To_Object (Child, 1));
         Set_Main_Title (Kernel, C);
      end if;
   end Title_Changed;

   --------------------
   -- Set_Main_Title --
   --------------------

   procedure Set_Main_Title
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : MDI_Child)
   is
      Win : constant GPS_Window := GPS_Window (Kernel.Get_Main_Window);
   begin
      if Win /= null then
         if Child = null then
            Reset_Title (Win);
         elsif Has_Title_Bar (Child) then
            Reset_Title (Win, Get_Short_Title (Child));
         else
            Reset_Title (Win, Get_Title (Child));
         end if;
      end if;
   end Set_Main_Title;

   --------------------
   -- Child_Selected --
   --------------------

   procedure Child_Selected
     (Mdi    : access GObject_Record'Class;
      Params : Glib.Values.GValues;
      Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Mdi);
      Child : MDI_Child;
   begin
      if Kernel /= null
        and then not Kernel.Is_In_Destruction
      then
         Child := MDI_Child (To_Object (Params, 1));
         Set_Main_Title (Kernel, Child);
         Context_Changed (Kernel);
      end if;
   end Child_Selected;

end GPS.Callbacks;
