-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                 Copyright (C) 2005-2010, AdaCore                  --
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

--  This package helps build simple views that are associated with a single
--  window, that are saved in the desktop, and have a simple menu in Tools/
--  to open them.
--  This package must be instanciated at library-level

with GPS.Kernel.Modules;
with GPS.Kernel.MDI;
with Glib.Object;
with XML_Utils;
with Gtk.Scrolled_Window;
with Gtk.Widget;
with Gtkada.MDI;

package Generic_Views is

   -----------------
   -- View_Record --
   -----------------

   type View_Record is new Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record
      with null record;

   function Save_To_XML
     (View : access View_Record) return XML_Utils.Node_Ptr;
   --  Return an XML represention of the view. This is used to save the view
   --  to the desktop, and possibly for debug purposes.
   --  By default, this returns null

   procedure Load_From_XML
     (View : access View_Record; XML : XML_Utils.Node_Ptr);
   --  Initialize View from XML. XML is the contents of the desktop node for
   --  the View, and was generated by Save_To_XML.
   --  By default, this function does nothing

   ------------------
   -- Simple_Views --
   ------------------

   generic
      Module_Name : String;
      --  The name of the module, and name used in the desktop file. It mustn't
      --  contain any space.

      View_Name   : String;
      --  Name of MDI window that is used to create the view

      type Formal_View_Record is new View_Record with private;
      --  Type of the widget representing the view

      Reuse_If_Exist : Boolean;
      --  If True a single MDI child will be created and shared

      with function Initialize
        (View   : access Formal_View_Record'Class;
         Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
         return Gtk.Widget.Gtk_Widget is <>;
      --  Function used to create the view itself.
      --  The Gtk_Widget returned, if non-null, is the Focus Widget to pass
      --  to the MDI.

   package Simple_Views is

      type View_Access is access all Formal_View_Record'Class;

      procedure Register_Module
        (Kernel      : access GPS.Kernel.Kernel_Handle_Record'Class;
         ID          : GPS.Kernel.Modules.Module_ID := null;
         Menu_Name   : String := View_Name;
         Before_Menu : String := "");
      --  Register the module. This sets it up for proper desktop handling, as
      --  well as create a menu in Tools/ so that the user can open the view.
      --  ID can be passed in parameter if a special tagged type needs to be
      --  used.
      --  Menu_Name is the name of the menu, in tools, that is used to create
      --  the view.
      --  If Before_Menu is not empty, the menu entry will be added before it.

      function Get_Module return GPS.Kernel.Modules.Module_ID;
      --  Return the module ID corresponding to that view

      function Get_Or_Create_View
        (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class;
         Focus  : Boolean := True;
         Group  : Gtkada.MDI.Child_Group := GPS.Kernel.MDI.Group_View)
         return View_Access;
      --  Return the view (create a new one if necessary, or always if
      --  Reuse_If_Exist is False).
      --  The view gets the focus automatically if Focus is True.

   private
      --  The following subprograms need to be in the spec so that we can get
      --  access to them from callbacks in the body

      procedure On_Open_View
        (Widget : access Glib.Object.GObject_Record'Class;
         Kernel : GPS.Kernel.Kernel_Handle);
      On_Open_View_Access : constant
        GPS.Kernel.Kernel_Callback.Marshallers.Void_Marshaller.Handler :=
          On_Open_View'Access;
      --  Create a new view if none exists, or raise the existing one

      function Load_Desktop
        (MDI  : Gtkada.MDI.MDI_Window;
         Node : XML_Utils.Node_Ptr;
         User : GPS.Kernel.Kernel_Handle) return Gtkada.MDI.MDI_Child;
      Load_Desktop_Access : constant
        GPS.Kernel.MDI.Load_Desktop_Function := Load_Desktop'Access;
      function Save_Desktop
        (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
         User   : GPS.Kernel.Kernel_Handle) return XML_Utils.Node_Ptr;
      Save_Desktop_Access : constant
        GPS.Kernel.MDI.Save_Desktop_Function := Save_Desktop'Access;
      --  Support functions for the MDI
   end Simple_Views;

end Generic_Views;
