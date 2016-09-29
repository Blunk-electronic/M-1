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
with gtk.file_chooser;			use gtk.file_chooser;
with gtk.file_chooser_button;	use gtk.file_chooser_button;
with gtkada.handlers; 			use gtkada.handlers;
with glib.object;
with gdk.event;

with bsmgui_cb; 		use bsmgui_cb;


procedure bsmgui is

	version			: string (1..3) := "015";
	window_main 	: gtk_window;
	box_back		: gtk_box;
	box_head		: gtk_hbox;
	box_bottom		: gtk_hbox;
	box_selection_label		: gtk_vbox;
	box_selection_directory	: gtk_vbox;
	box_start_stop			: gtk_vbox;

-- 	button_start_stop_test		: gtk_button;
-- 	button_start_stop_script	: gtk_button;

	label_uut			: gtk.label.gtk_label;
	label_script		: gtk.label.gtk_label;
	label_test			: gtk.label.gtk_label;
-- 	chooser_set_uut		: gtk_file_chooser_button;
-- 	chooser_set_script	: gtk_file_chooser_button;
-- 	chooser_set_test	: gtk_file_chooser_button;

-- 	img_status			: gtk.image.gtk_image;



begin
	-- read system configuration file and set variables: name_directory_home, language, name_directory_bin, name_directory_enscript, interface_to_bsc
	check_environment;

--  Initialize GtkAda.
	gtk.main.init;

	-- create the  main window
	gtk_new (window_main);
	window_main.set_title ("BOUNDARY SCAN TEST SYSTEM M-1");

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


	-- BOX SELECTION LABELS
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

	-- BOX SELECTION CHOOSERS
	gtk_new_vbox (box_selection_directory);
	pack_start (box_head, box_selection_directory, true, true, 5);
	show (box_selection_directory);
 	gtk_new (chooser_set_uut, "UUT", action_select_folder);

	-- set default projects directory
	if set_current_folder(chooser_set_uut, universal_string_type.to_string(name_directory_home) & name_directory_separator & name_directory_projects_default) then
		put_line("project directory default: " & universal_string_type.to_string(name_directory_home) &
			name_directory_separator & name_directory_projects_default);
	end if;

 	pack_start (box_selection_directory, chooser_set_uut);
 	show (chooser_set_uut);
 	gtk_new (chooser_set_script, "Script", action_open);
 	pack_start (box_selection_directory, chooser_set_script);
	set_sensitive (chooser_set_script, false);
 	show (chooser_set_script);
 	gtk_new (chooser_set_test, "Test", action_select_folder);
 	pack_start (box_selection_directory, chooser_set_test);
	set_sensitive (chooser_set_test, false);
 	show (chooser_set_test);

	-- BOX START / STOP BUTTON
	gtk_new_vbox (box_start_stop);
	pack_start (box_head, box_start_stop, true, true, 5);
	show (box_start_stop);
	gtk_new (button_start_stop_script, "Start Script");
	pack_start (box_start_stop, button_start_stop_script, true, true, 5);
	set_sensitive (button_start_stop_script, false);
	show (button_start_stop_script);
	gtk_new (button_start_stop_test, "Start Test");
	pack_start (box_start_stop, button_start_stop_test, true, true, 5);
	set_sensitive (button_start_stop_test, false);
	show (button_start_stop_test);
	gtk_new (button_abort_shutdown, "ABORT/POWER OFF");
	pack_start (box_start_stop, button_abort_shutdown, true, true, 5);
	show (button_abort_shutdown);


	-- STATUS WINDOW
	gtk_new (img_status, 
		universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
		compose
			(
			containing_directory => name_directory_configuration_images,
			name => name_file_image_ready,
			extension => file_extension_png
			)
		);
	pack_start (box_bottom, img_status, true, true, 10);
	show (img_status);



	-- BUTTONS CLICKED
	chooser_set_uut.on_file_set(set_project'access);
	chooser_set_script.on_file_set(set_script'access);
	chooser_set_test.on_file_set(set_test'access);

	button_start_stop_test.on_clicked(start_stop_test'access);
	button_start_stop_script.on_clicked(start_stop_script'access);
	button_abort_shutdown.on_clicked(abort_shutdown'access);

	--  Show the window
	window_main.show_all;

	-- All GTK applications must have a Gtk.Main.Main. Control ends here
	-- and waits for an event to occur (like a key press or a mouse event),
	-- until Gtk.Main.Main_Quit is called.
	gtk.main.main;

end bsmgui;