------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE BSMGUI                              --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               B o d y                                    --
--                                                                          --
--         Copyright (C) 2016 Mario Blunk, Blunk electronic                 --
--                                                                          --
--    This program is free software: you can redistribute it and/or modify  --
--    it under the terms of the GNU General Public License as published by  --
--    the Free Software Foundation, either version 3 of the License, or     --
--    (at your option) any later version.                                   --
--                                                                          --
--    This program is distributed in the hope that it will be useful,       --
--    but WITHOUT ANY WARRANTY; without even the implied warranty of        --
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
--    GNU General Public License for more details.                          --
--                                                                          --
--    You should have received a copy of the GNU General Public License     --
--    along with this program.  If not, see <http://www.gnu.org/licenses/>. --
------------------------------------------------------------------------------

--   Please send your questions and comments to:
--
--   Mario.Blunk@blunk-electronic.de
--   or visit <http://www.blunk-electronic.de> for more contact data
--
--   history of changes:
--
--   todo: 

--pragma Ada_2012;
with ada.text_io; 				use ada.text_io;
with ada.directories;			use ada.directories;

with m1_internal; 				use m1_internal;
with m1_numbers;				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;
with m1_firmware;				use m1_firmware;


--with gtkada;

with gtk.main;
with gtk.widget;  		use gtk.widget;
with gtk.window; 		use gtk.window;
with gtk.box;			use gtk.box;
with gtk.button;     	use gtk.button;
with gtk.Vbutton_Box;	use gtk.Vbutton_Box;
with gtk.label;			use gtk.label;
with gtk.image;			use gtk.image;
with gtk.file_chooser;	use gtk.file_chooser;
with gtk.file_chooser_button;	use gtk.file_chooser_button;
with gtkada.handlers; 	use gtkada.handlers;
with glib.object;
with gdk.event;


with hello_cb; use hello_cb;

procedure bsmgui is

	version			: string (1..3) := "015";
	window_main 	: gtk_window;
	box_back		: gtk_box;
	box_head		: gtk_hbox;
	box_bottom		: gtk_hbox;
--	box_selection	: gtk_box;
	box_selection_label		: gtk_vbox;
	box_selection_directory	: gtk_vbox;
	box_start_stop			: gtk_vbox;

--	button_box_selection : gtk_vbutton_box;

	--button_quit 	: gtk_button;
-- 	button_set_uut	: gtk_button;
-- 	button_select	: gtk_button;
	button_start_stop_test		: gtk_button;
	button_start_stop_script	: gtk_button;

	label_uut		: gtk.label.gtk_label;
	label_script	: gtk.label.gtk_label;
	label_test		: gtk.label.gtk_label;
	chooser_set_uut		: gtk_file_chooser_button;
	chooser_set_script	: gtk_file_chooser_button;
	chooser_set_test	: gtk_file_chooser_button;

	img_status		: gtk.image.gtk_image;

--	label_head		: gtk.label.gtk_label;
	label_bottom	: gtk.label.gtk_label;
--	label_test2		: gtk.label.gtk_label;


begin
	set_home_directory; -- sets variable name_directory_home (absolute path !)

--  Initialize GtkAda.
	gtk.main.init;

	-- create the  main window
	gtk_new (window_main);
	window_main.set_title ("BOUNDARY SCAN TEST SYSTEM M-1");

   -- When the window emits the "delete-event" signal (which is emitted
   -- by GTK+ in response to an event coming from the window manager,
   -- usually as a result of clicking the "close" window control), we
   -- ask it to call the on_delete_event() function as defined above.
   --Win.On_Delete_Event (main_del'Access);

	-- connect the "destroy" signal
	window_main.on_destroy (terminate_main'access); -- close window

	--window_main.set_default_size (800, 600);

	-- set the border width of the window
	window_main.set_border_width (10);
	-- create and place background box
	gtk_new_vbox (box_back, false, 0);
	gtk.window.add (window_main, box_back);

	-- create and place box_head in box_back
	gtk_new_hbox (box_head, false, 0);
	pack_start (box_back, box_head, true, true, 0);
	set_spacing (box_head, 20);
	-- create and place box_bottom in box_back
	gtk_new_hbox (box_bottom, false, 0);
	pack_start (box_back, box_bottom, true, true, 0);
	set_spacing (box_head, 20);


	
-- 	gtk_new_vbox (box_selection, false, 0);
-- 	pack_start (box_head, box_selection, true, true, 0);

	-- create and place box_selection_label in box_head
	gtk_new_vbox (box_selection_label);
	pack_start (box_head, box_selection_label, true, true, 5);
	show (box_selection_label);
	gtk_new (label_uut, "UUT");
	pack_start (box_selection_label, label_uut, true, true, 5);
	show (label_uut);
	gtk_new (label_script, "SCR");
	pack_start (box_selection_label, label_script, true, true, 5);
	show (label_script);
	gtk_new (label_test, "TEST");
	pack_start (box_selection_label, label_test, true, true, 5);
	show (label_test);

	gtk_new_vbox (box_selection_directory);
	pack_start (box_head, box_selection_directory, true, true, 5);
	show (box_selection_directory);
 	gtk_new (chooser_set_uut, "UUT", action_select_folder);
 	pack_start (box_selection_directory, chooser_set_uut);
 	show (chooser_set_uut);
 	gtk_new (chooser_set_script, "Script", action_open);
 	pack_start (box_selection_directory, chooser_set_script);
 	show (chooser_set_script);
 	gtk_new (chooser_set_test, "Test", action_select_folder);
 	pack_start (box_selection_directory, chooser_set_test);
 	show (chooser_set_test);

	gtk_new_vbox (box_start_stop);
	pack_start (box_head, box_start_stop, true, true, 5);
	show (box_start_stop);
	gtk_new (button_start_stop_script, "Start Script");
	pack_start (box_start_stop, button_start_stop_script, true, true, 5);
	show (button_start_stop_script);
	gtk_new (button_start_stop_test, "Start Test");
	pack_start (box_start_stop, button_start_stop_test, true, true, 5);
	show (button_start_stop_test);




-- 	gtk_new (label_head, "HEAD");
-- 	pack_start (box_head, label_head, true, true, 5);
-- 	show (label_head);

-- 	gtk_new (label_bottom, "BOTTOM");
-- 	pack_start (box_bottom, label_bottom, true, true, 5);
-- 	show (label_bottom);

	gtk_new (img_status, 
		universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
		compose
			(
			containing_directory => name_directory_configuration_images,
			name => name_file_image_request_upload,
			extension => file_extension_png
			)
		);
	pack_start (box_bottom, img_status, true, true, 10);
	show (img_status);



-- 
-- 	gtk_new (label_script, "SCR");
-- 	pack_start (box_selection, label_script, true, true, 5);
-- 	show (label_script);
-- 
-- 
-- 
-- 
-- 	gtk_new (box_selection_directory);
-- 	pack_start (box_selection, box_selection_directory, true, true, 5);
-- 	show (box_selection_directory);
-- 










	-- create "set UUT" button and pack it into box_selection
-- 	gtk_new (button_set_uut, "Set UUT");
-- 	pack_start (button_box_selection, button_set_uut, true, true, 5);
-- 	show (button_set_uut);

-- 	gtk_new (label_uut_name, "UUT");
-- 	pack_start (box_selection, label_uut_name, false, false, 5);
-- 	show (label_uut_name);

-- 



	--button_set_uut.on_clicked (set_uut'access);
	--button_set_uut.on_clicked (button_quit_clicked'access);

	-- create "select" button and pack it into box_selection


	-- create a button with label
	--gtk_new (button_quit, "QUIT");

	-- connect the click signal
	--button_quit.on_clicked (button_quit_clicked'access);

	-- connect the "clicked" signal of the button_quit to destroy function
-- 	widget_callback.object_connect
-- 		(
-- 		button_quit,
-- 		"clicked",
-- 		widget_callback.to_marshaller (terminate_main'access),
-- 		window_main
-- 		);

	-- This packs the button into the window. A Gtk_Window inherits from
	-- Gtk_Bin which is a special container that can only have one child.
--	window_main.add (button_quit);

	--  Show the window
	window_main.show_all;

	-- All GTK applications must have a Gtk.Main.Main. Control ends here
	-- and waits for an event to occur (like a key press or a mouse event),
	-- until Gtk.Main.Main_Quit is called.
	gtk.main.main;

end bsmgui;