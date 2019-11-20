------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                     Copyright (C) 2005-2019, AdaCore                     --
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

--  This package helps build simple views that are associated with a single
--  window, that are saved in the desktop, and have a simple menu in Tools/
--  to open them.
--  This package must be instanciated at library-level

with Glib;
with Gtk.Box;
with Gtk.Button;
with Gtk.Button_Box; use Gtk.Button_Box;
with Gtk.Menu;
with Gtk.Menu_Item;
with Gtk.Toolbar;
with Gtk.Tool_Item;
with Gtk.Widget;
with Gtkada.Handlers;
with Gtkada.MDI;

with GPS.Kernel.Modules;
with GPS.Kernel.MDI;
with GPS.Kernel.Search;
with GPS.Search;
with GUI_Utils;
with XML_Utils;
with Histories;
with Filter_Panels;

private with Glib.Object;
private with Gdk.Event;
private with Gtk.Toggle_Tool_Button;
private with Gtkada.Entry_Completion;

package Generic_Views is

   -----------------
   -- View_Record --
   -----------------

   type View_Record is new Gtk.Box.Gtk_Box_Record with private;
   type Abstract_View_Access is access all View_Record'Class;

   procedure Save_To_XML
     (View : access View_Record;
      XML  : in out XML_Utils.Node_Ptr) is null;
   --  Saves View's attributes to an XML node.
   --  Node has already been created (and the proper tag name set), but this
   --  procedure can add attributes or child nodes to it as needed.

   procedure Load_From_XML
     (View : access View_Record; XML : XML_Utils.Node_Ptr) is null;
   --  Initialize View from XML. XML is the contents of the desktop node for
   --  the View, and was generated by Save_To_XML.

   procedure Create_Toolbar
     (View    : not null access View_Record;
      Toolbar : not null access Gtk.Toolbar.Gtk_Toolbar_Record'Class) is null;
   --  If the view needs a local toolbar, this function is called when the
   --  toolbar needs to be filled. It is not called if Local_Toolbar is set to
   --  null in the instantiation of the generic below.
   --  In general, local toolbars should be described in menus.xml rather than
   --  hard-coded. However, this procedure is still useful when you want to add
   --  filters to your view.
   --  This toolbar should contain operations that apply to the current view,
   --  but not settings or preferences for that view (use Create_Menu for the
   --  latter).

   procedure Create_Menu
     (View    : not null access View_Record;
      Menu    : not null access Gtk.Menu.Gtk_Menu_Record'Class) is null;
   --  Fill the menu created by the local configuration menu (see Local_Config
   --  in the generic formal parameters below).
   --  This menu should contain entries that configure the current view, for
   --  instance by using GPS.Kernel.Preferences.Append_Menu or
   --  GPS.Kernel.Modules.UI.Append_Menu.

   procedure Create_Buttons_Area
     (View        : not null access View_Record;
      Buttons_Box : not null access Gtk_Button_Box_Record'Class) is null;
   --  Override this procedure if the view needs additional buttons in the
   --  bottom area.

   procedure Append_Toolbar
     (Self        : not null access View_Record;
      Toolbar     : not null access Gtk.Toolbar.Gtk_Toolbar_Record'Class;
      Item        : not null access Gtk.Tool_Item.Gtk_Tool_Item_Record'Class;
      Right_Align : Boolean := False;
      Homogeneous : Boolean := True);
   --  Appends an item to the local toolbar.
   --  If Right_Align is True, the item will be right-aligned.
   --  All items with Homogeneous set to True will have the same width.
   --  It is better to use this procedure than Gtk.Toolbar.Insert, since the
   --  latter makes it harder to know how to append items to the left or to
   --  the right.

   procedure Set_Toolbar
     (View    : not null access View_Record'Class;
      Toolbar : access Gtk.Toolbar.Gtk_Toolbar_Record'Class);
   function Get_Toolbar
     (View    : not null access View_Record'Class)
      return Gtk.Toolbar.Gtk_Toolbar;
   --  Access the local toolbar for the view (if any).
   --  This toolbar is created automatically by the generic package below.

   function Kernel
     (Self : not null access View_Record'Class)
      return GPS.Kernel.Kernel_Handle with Inline;
   --  Return the kernel stored in Self

   procedure Set_Kernel
     (View   : not null access View_Record'Class;
      Kernel : not null access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Set the Kernel field (needed only internally from the generic, where
   --  we can directly access the kernel field)

   procedure On_Create
     (View  : not null access View_Record;
      Child : not null access GPS.Kernel.MDI.GPS_MDI_Child_Record'Class)
   is null;
   --  This is called after a new view has been created, and it has been added
   --  to the MDI.

   procedure On_Destroy
     (View : not null access View_Record) is null;
   --  Called each time a view is destroyed (e.g: when the user closes the
   --  view).

   -----------------------
   -- Search bar fields --
   -----------------------

   procedure Build_Search
     (Self    : not null access View_Record;
      Toolbar : not null access Gtk.Toolbar.Gtk_Toolbar_Record'Class;
      P       : not null access GPS.Kernel.Search.Kernel_Search_Provider'Class;
      Name                : Histories.History_Key;
      Case_Sensitive      : Boolean := False;
      Placeholder         : String := "search");
   --  Build a search bar panel, looking like the omnisearch bar, by giving a
   --  custom search provider.
   --  Placeholder is used as the entry's placeholder text.

   procedure Override_Search_Provider
     (Self : not null access View_Record;
      P    : not null access GPS.Kernel.Search.Kernel_Search_Provider'Class);
   --  Override the search bar default provider (i.e: the one passed in
   --  parameter when calling Build_Search).

   procedure Reset_Search_Provider (Self : not null access View_Record);
   --  Get back to the default search provider (i.e: the one passed in
   --  parameter when calling Build_Search).

   function Is_Search_Provider_Overridden
     (Self : not null access View_Record) return Boolean;
   --  Return True if the search provider is currently overriden, False if the
   --  the default one is used.

   ------------------------------
   -- Search and filter fields --
   ------------------------------

   procedure Build_Filter
     (Self        : not null access View_Record;
      Toolbar     : not null access Gtk.Toolbar.Gtk_Toolbar_Record'Class;
      Hist_Prefix : Histories.History_Key;
      Tooltip     : String := "";
      Placeholder : String := "";
      Options     : Filter_Panels.Filter_Options_Mask := 0;
      Name        : String := "");
   --  Build a filter panel which provides a standard look-and-feel:
   --     * rounded corner (through the theme)
   --     * "clear" icon
   --     * placeholder text
   --     * tooltip
   --     * a number of predefined options
   --     * remember option settings across sessions (through Hist_Prefix)
   --     * name is used to access filter from testsuite
   --  Whenever the pattern is changed (or cleared), Self.Filter_Changed is
   --  called.
   --  Nothing is done if the filter panel has already been built.
   --  This function should be called from Create_Toolbar.

   procedure Filter_Changed
     (Self    : not null access View_Record;
      Pattern : in out GPS.Search.Search_Pattern_Access) is null;
   --  Called when the user has changed the filter applied to the view.
   --  Pattern must be freed by the callee.
   --  null is passed when no pattern is set by the user.

   function Get_Filter
     (View : not null access View_Record'Class)
      return Filter_Panels.Filter_Panel;
   --  Return the filter or null if the filter is not defined for this view

   procedure Set_Filter
     (Self : not null access View_Record;
      Text : String);
   --  Change the text of the filter (assuming a filter was added through
   --  Build_Filter);

   -------------------
   -- Progress Bars --
   -------------------

   procedure Set_Activity_Progress_Bar_Visibility
     (Self    : not null access View_Record'Class;
      Visible : Boolean);
   --  Show or hide the view's activity progress bar.
   --  This progress bar can be used to tell the user that something is being
   --  computed in the background and that the view is waiting for displaying
   --  the results..

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

      type Formal_MDI_Child is new GPS.Kernel.MDI.GPS_MDI_Child_Record
        with private;
      --  The type of MDI child, in case the view needs to use a specialized
      --  type, for instance to add drag-and-drop capabilities

      Reuse_If_Exist : Boolean := True;
      --  If True a single MDI child will be created and shared

      with function Initialize
        (View : access Formal_View_Record'Class)
         return Gtk.Widget.Gtk_Widget is <>;
      --  Function used to create the view itself.
      --  The Gtk_Widget returned, if non-null, is the Focus Widget to pass
      --  to the MDI. If null, the focus will be given to the view's
      --  search/filter bar (created via Build_Search/Build_Filter), if any.
      --  View has already been allocated, and the kernel has been set.

      Local_Toolbar : Boolean := False;
      --  Whether the view should contain a local toolbar. If it does, the
      --  toolbar will be filled by calling the Create_Toolbar primitive
      --  operation on the view.

      Local_Config : Boolean := False;
      --  If true, a button will be displayed to show the configuration menu
      --  for the view. If true, this also forces the use of a local toolbar.
      --  Such a menu is always displayed for floating windows, so that they
      --  have an automatic "Unfloat" menu there.

      Position : Gtkada.MDI.Child_Position := Gtkada.MDI.Position_Bottom;
      --  The preferred position for newly created views.

      Group  : Gtkada.MDI.Child_Group := GPS.Kernel.MDI.Group_View;
      --  The group for newly created views.

      Commands_Category : String := "Views";
      --  Name of the category in the Key Shortcuts editor for the commands
      --  declared in this package. If this is the empty string, no command is
      --  registered.

      MDI_Flags : Gtkada.MDI.Child_Flags := Gtkada.MDI.All_Buttons;
      --  Special flags used when creating the MDI window.

      Areas : Gtkada.MDI.Allowed_Areas := Gtkada.MDI.Both;
      --  Where is the view allowed to go ?

      Default_Width  : Glib.Gint := 215;
      Default_Height : Glib.Gint := 600;
      --  The default size of the MDI child

      Add_Close_Button_On_Float : Boolean := False;
      --  If true:
      --  When the child is floated, a [Close] button will be added. When
      --  the child is unfloated, it is put inside a scrolled_window so that
      --  it can be resized to any size while within the MDI. The size and
      --  position of the floating window are saved and restored automatically.

      Save_Duplicates_In_Perspectives : Boolean := True;
      --  All instances will be stored in perspectives if this is true and only
      --  the first instance if it is False.

   package Simple_Views is
      M_Name : constant String := Module_Name;
      --  So that it can be referenced from the outside, for instance to create
      --  filters.

      type View_Access is access all Formal_View_Record'Class;

      procedure Register_Module
        (Kernel      : access GPS.Kernel.Kernel_Handle_Record'Class;
         ID          : GPS.Kernel.Modules.Module_ID := null);
      --  Register the module. This sets it up for proper desktop handling, as
      --  well as create a menu in Tools/ so that the user can open the view.
      --  ID can be passed in parameter if a special tagged type needs to be
      --  used.

      function Get_Module return GPS.Kernel.Modules.Module_ID;
      --  Return the module ID corresponding to that view

      function Create_Finalized_View
        (View       : not null access Formal_View_Record'Class;
         Toolbar_Id : String := View_Name)
         return Gtk.Widget.Gtk_Widget;
      --  If a local toolbar is needed for View, create a parent container
      --  widget for View, containing a newly created toolbar on the top.
      --  If no local toolbar is needed, return View.
      --  Toolbar_Id is the name of the toolbar to use. It refers to names in
      --  menus.xml, or toolbars created via
      --  GPS.Kernel.Module.UI.Create_Toolbar.

      function Get_Or_Create_View
        (Kernel     : access GPS.Kernel.Kernel_Handle_Record'Class;
         Focus      : Boolean := True;
         Toolbar_Id : String := View_Name;
         Init       : access procedure
            (View : not null access Formal_View_Record'Class) := null)
         return View_Access;
      --  Return the view (create a new one if necessary, or always if
      --  Reuse_If_Exist is False).
      --  The view gets the focus automatically if Focus is True.
      --
      --  Toolbar_Id is the name of the toolbar to use. It refers to names in
      --  menus.xml, or toolbars from GPS.Kernel.Module.UI.Create_Toolbar. This
      --  has no effect, though, if the view already existed.
      --
      --  Init is called just before the primitive On_Create operation. It
      --  comes in addition, since a different version can be called every
      --  time Get_Or_Create_View is called, and can get information from the
      --  local procedure. Typically, this would be used to set a filter on
      --  the view, and then On_Create is called to further set things up.
      --  Init is called even if the view already existed.

      function Retrieve_View
        (Kernel       : access GPS.Kernel.Kernel_Handle_Record'Class;
         Visible_Only : Boolean := False)
         return View_Access;
      --  Retrieve any of the existing views.
      --  If Visible_Only is True, this function returns the view only if it's
      --  visible in the current perspective. Otherwise, the view will be
      --  returned and automatically put back in the current perspective.

      procedure Reset_Toolbar
        (View       : not null access Formal_View_Record'Class;
         Toolbar_Id : String := View_Name);
      --  Recreate the toolbar from scratch.
      --  This is only needed if you need to change the buttons that are
      --  displayed there via your Create_Toolbar method.

      procedure Close
        (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class);
      --  Close the view

      type Local_Formal_MDI_Child is new Formal_MDI_Child with null record;
      type Access_Local_Formal_MDI_Child is
        access all Local_Formal_MDI_Child'Class;
      overriding function Save_Desktop
        (Self : not null access Local_Formal_MDI_Child)
         return XML_Utils.Node_Ptr;
      overriding function Get_Actual_Widget
        (Self : not null access Local_Formal_MDI_Child)
         return Gtk.Widget.Gtk_Widget;

      function View_From_Child
        (Child : not null access Gtkada.MDI.MDI_Child_Record'Class)
         return View_Access
      is (View_Access
          (GPS.Kernel.MDI.GPS_MDI_Child (Child).Get_Actual_Widget));
      function Child_From_View
        (View : not null access Formal_View_Record'Class)
         return access Local_Formal_MDI_Child'Class;
      --  Return the MDI Child containing view.

   private
      --  The following subprograms need to be in the spec so that we can get
      --  access to them from callbacks in the body

      function Load_Desktop
        (MDI  : Gtkada.MDI.MDI_Window;
         Node : XML_Utils.Node_Ptr;
         User : GPS.Kernel.Kernel_Handle) return Gtkada.MDI.MDI_Child;
      Load_Desktop_Access : constant
        GPS.Kernel.MDI.Load_Desktop_Function := Load_Desktop'Access;
      --  Support functions for the MDI

      function On_Display_Local_Config
        (View : access Glib.Object.GObject_Record'Class;
         Event : Gdk.Event.Gdk_Event_Button) return Boolean;
      On_Display_Local_Config_Access : constant
        Gtk.Widget.Cb_GObject_Gdk_Event_Button_Boolean :=
        On_Display_Local_Config'Access;
      --  Called to display the local config menu

      procedure On_Float_Child
        (Child : access Gtk.Widget.Gtk_Widget_Record'Class);
      On_Float_Child_Access : constant
        Gtkada.Handlers.Widget_Callback.Simple_Handler :=
          On_Float_Child'Access;

      procedure On_Before_Unfloat_Child
        (Child : access Gtk.Widget.Gtk_Widget_Record'Class);
      On_Before_Unfloat_Child_Access : constant
        Gtkada.Handlers.Widget_Callback.Simple_Handler :=
          On_Before_Unfloat_Child'Access;

      function On_Delete_Floating_Child
        (Self : access Gtk.Widget.Gtk_Widget_Record'Class) return Boolean;
      On_Delete_Floating_Child_Access : constant
        Gtkada.Handlers.Return_Callback.Simple_Handler :=
          On_Delete_Floating_Child'Access;
      --  Used to store the view's position when closing if floating

      procedure On_Close_Floating_Child
        (Self : access Gtk.Widget.Gtk_Widget_Record'Class);
      On_Close_Floating_Child_Access : constant
        Gtkada.Handlers.Widget_Callback.Simple_Handler :=
          On_Close_Floating_Child'Access;
   end Simple_Views;

private

   type Search_Panel_Record is new Gtk.Tool_Item.Gtk_Tool_Item_Record
   with record
      Completion_Entry      : Gtkada.Entry_Completion.Gtkada_Entry;
      Is_Provider_Overriden : Boolean := False;
   end record;
   type Search_Panel is access all Search_Panel_Record'Class;
   --  Type used to create a search bar in the view's local toolbar

   type View_Record is new Gtk.Box.Gtk_Box_Record with record
      Kernel  : GPS.Kernel.Kernel_Handle;
      Toolbar : Gtk.Toolbar.Gtk_Toolbar;
      Filter  : Filter_Panels.Filter_Panel;   --  might be null
      Search  : Search_Panel;                 --  might be null

      Config       : Gtk.Toggle_Tool_Button.Gtk_Toggle_Tool_Button;
      Config_Menu  : Gtk.Menu.Gtk_Menu;
      --  The button that shows the config menu, and the menu itself
      Unfloat_Menu : Gtk.Menu_Item.Gtk_Menu_Item;
      --  The menu item containing the unfloat action

      Button_Box   : Gtk.Button_Box.Gtk_Button_Box := null;
      --  The button box that contains the "close" button, for dialog-like
      --  views.

      Close_Button : Gtk.Button.Gtk_Button := null;
      --  The optional 'Close' button that appears when the view is floating

      Progress_Bar : GUI_Utils.Activity_Progress_Bar;
      --  An activity progress bar. Useful to warn users that messages are
      --  being processed.
   end record;

end Generic_Views;
