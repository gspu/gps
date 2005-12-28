-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                         Copyright (C) 2005                        --
--                              AdaCore                              --
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
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with HTables;
with String_List_Utils; use String_List_Utils;
with VCS;               use VCS;
with VFS;               use VFS;

package VCS_Status is

   type Status_Cache is private;

   type Line_Record is record
      Status : File_Status_Record;
      --  The file status

      Log    : Boolean;
      --  Whether the file is associated with a changelog
   end record;

   No_Data : constant Line_Record;

   function Get_Cache
     (Cache : Status_Cache;
      File  : VFS.Virtual_File) return Line_Record;
   --  Return the cached status for the given file. The result must not be
   --  freed.

   procedure Set_Cache
     (Cache : Status_Cache;
      File  : VFS.Virtual_File; Status : in out Line_Record);
   --  Record the Status for the given file

   procedure Clear_Cache (Cache : Status_Cache);
   --  Clear all recorded file status

   procedure Free (X : in out Line_Record);

   function Copy (X : Line_Record) return Line_Record;
   --  Return a deep copy of X

private

   No_Data : constant Line_Record :=
               ((VFS.No_File, Unknown, others => String_List.Null_List),
                False);

   type Header_Num is range 1 .. 5_000;

   function Hash (F : Virtual_File) return Header_Num;

   package Status_Hash is new HTables.Simple_HTable
     (Header_Num, Line_Record, Free, No_Data, Virtual_File, Hash, "=");
   --  Store for each file the current status. This is a cache to avoid sending
   --  requests to the VCS.

   type HTable_Access is access Status_Hash.HTable;

   type Table is record
      T : HTable_Access := new Status_Hash.HTable;
   end record;

   type Status_Cache is new Table;

end VCS_Status;
