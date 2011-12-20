------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2006-2012, AdaCore                     --
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

--  This package handles the AUnit templates, and creates the source files
--  from these templates

with GPS.Kernel;   use GPS.Kernel;
with GNATCOLL.VFS; use GNATCOLL.VFS;

with Templates_Parser; use Templates_Parser;

package AUnit_Templates is

   function Get_Template_File_Name
     (Kernel : access Kernel_Handle_Record'Class;
      Base   : Filesystem_String) return Virtual_File;
   --  Retrieve the template's full file name from base name

   procedure Create_Files
     (Kernel         : access Kernel_Handle_Record'Class;
      Base_Template  : Filesystem_String;
      Translations   : Translate_Set;
      Directory_Name : Virtual_File;
      Name           : String;
      Success        : out Boolean);
   --  Create Directory_Name/Name.ads and Directory_Name/Name.adb files using
   --  Base_Template name and the translations

end AUnit_Templates;
