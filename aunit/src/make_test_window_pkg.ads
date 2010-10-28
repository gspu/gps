-----------------------------------------------------------------------
--                              G P S                                --
--                                                                   --
--                 Copyright (C) 2001-2010, AdaCore                  --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Gtk.Button;       use Gtk.Button;
with Gtk.Check_Button; use Gtk.Check_Button;
with Gtk.Dialog;       use Gtk.Dialog;
with Gtk.GEntry;       use Gtk.GEntry;
with Gtk.Label;        use Gtk.Label;
with GPS.Kernel;

package Make_Test_Window_Pkg is
   --  "AUnit_Make_Test" main window definition.  Generated by Glade

   type Make_Test_Window_Record is new Gtk_Dialog_Record with record
      Kernel             : GPS.Kernel.Kernel_Handle;
      Directory_Entry    : Gtk_Entry;
      Name_Entry         : Gtk_Entry;
      Description_Entry  : Gtk_Entry;
      Override_Tear_Down : Gtk_Check_Button;
      Override_Set_Up    : Gtk_Check_Button;
      Browse_Directory   : Gtk_Button;
      Label              : Gtk_Label;
   end record;
   type Make_Test_Window_Access is access all Make_Test_Window_Record'Class;

   procedure Gtk_New
     (Make_Test_Window : out Make_Test_Window_Access;
      Handle           : GPS.Kernel.Kernel_Handle);

   procedure Initialize
     (Make_Test_Window : access Make_Test_Window_Record'Class;
      Handle           : GPS.Kernel.Kernel_Handle);

end Make_Test_Window_Pkg;
