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
with ada.characters.handling;	use ada.characters.handling;
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
with gtk.label;			use gtk.label;
with gtk.image;			use gtk.image;
with gtk.file_chooser;			use gtk.file_chooser;
with gtk.file_chooser_button;	use gtk.file_chooser_button;
with gtk.file_filter;			use gtk.file_filter;
with gtkada.handlers; 			use gtkada.handlers;
with glib.object;
with gdk.event;

with bsmgui_cb; 		use bsmgui_cb;

procedure bsmgui is

	version					: string (1..3) := "015";

	window_main 			: gtk_window;
	box_back				: gtk_box;
	box_head				: gtk_hbox;
	box_bottom				: gtk_hbox;
	box_selection_label		: gtk_vbox;
	box_selection_directory	: gtk_vbox;
	box_start_stop			: gtk_vbox;

	label_uut				: gtk.label.gtk_label;
	label_script			: gtk.label.gtk_label;
	label_test				: gtk.label.gtk_label;

	filter_scripts			: gtk_file_filter;
	--filter_tests			: gtk_file_filter;

	procedure read_last_session is
		file_session	: ada.text_io.file_type;
		line			: extended_string.bounded_string;
	begin
		if exists (compose
							(
							containing_directory => universal_string_type.to_string(name_directory_home) & name_directory_separator &
								name_directory_configuration,
							name => name_file_configuration_session 
							)
					) then

			put_line("reading last session ...");
			open(	file => file_session,
					mode => in_file,
					name => compose
								(
								containing_directory => universal_string_type.to_string(name_directory_home) & name_directory_separator &
									name_directory_configuration,
								name => name_file_configuration_session 
								)
				);
			set_input(file_session);

			while not end_of_file
			loop
				line := remove_comment_from_line(extended_string.to_bounded_string(get_line));
				--put_line(extended_string.to_string(line));
				if get_field_count(extended_string.to_string(line)) /= 0 then -- if line contains anything
					
					-- get project
					if get_field_from_line(line,1) = text_project then 
						name_project := universal_string_type.to_bounded_string(get_field_from_line(line,2));
						put_line(text_project & ": " & universal_string_type.to_string(name_project));
					end if;
					-- CS: check if project exists

					-- get script
					if get_field_from_line(line,1) = text_script then 
						name_script := universal_string_type.to_bounded_string( 
									(
									universal_string_type.to_string(name_project) &
									name_directory_separator & 
									get_field_from_line(line,2)
									));
						put_line(text_script & ": " & universal_string_type.to_string(name_script));
					end if;
					-- CS: check if script exists

					-- get test
					if get_field_from_line(line,1) = text_test then 
						name_test := universal_string_type.to_bounded_string( 
									(
									universal_string_type.to_string(name_project) &
									name_directory_separator & 
									get_field_from_line(line,2)
									));
						put_line(text_test & ": " & universal_string_type.to_string(name_test));
					end if;
					-- CS: check if test exists

				end if;
			end loop;
			close(file_session);

			if set_current_folder(chooser_set_uut, universal_string_type.to_string(name_project)) then
				put_line("set project: " & universal_string_type.to_string(name_project));

				-- reset test and script choosers to project root directory
				if set_filename(chooser_set_script,universal_string_type.to_string(name_script)) then  
					put_line("set script: " & universal_string_type.to_string(name_script));
					set_sensitive (chooser_set_script, true);
					set_sensitive (button_start_stop_script, true);
				end if;

				if set_current_folder(chooser_set_test,universal_string_type.to_string(name_test)) then 
					put_line("set test: " & universal_string_type.to_string(name_test));
					set_sensitive (chooser_set_test, true);
					set_sensitive (button_start_stop_test, true);
				end if;

				--put_line("project set");
			end if;




		else
			-- NO SESSION FILE EXISTS -> CREATE A NEW ONE 
			put_line("no session found, creating a new one ...");
			--create_session_configuration_file;
			create( file => file_session, name => compose
							(
							containing_directory => universal_string_type.to_string(name_directory_home) & name_directory_separator &
								name_directory_configuration,
							name => name_file_configuration_session 
							)
				);
			-- write info headline
			write_session_file_headline;

			-- The project directory will be $HOME/M-1/uut (default)
			put_line( file_session, text_project & row_separator_0 &
				universal_string_type.to_string(name_directory_home) &
				name_directory_separator &
				name_directory_projects_default
				);

			-- Since there is no project set yet, no script and no test can be set. So just write the identifiers:
			put_line( file_session, text_script);
			put_line( file_session, text_test);
			close(file_session);

			-- Set the project name, script and test to the default directory
			name_project := universal_string_type.to_bounded_string(
								universal_string_type.to_string(name_directory_home) &
								name_directory_separator &
								name_directory_projects_default
							);
			name_script := name_project;
			name_test := name_project;

			if set_current_folder(chooser_set_uut, universal_string_type.to_string(name_project)) then
				null;
			end if;

			if chooser_set_script.set_filename(universal_string_type.to_string(name_script)) then  
				null;
			end if;

			if set_current_folder(chooser_set_test,universal_string_type.to_string(name_test)) then  
				null;
			end if;

			-- Disable start buttons
			set_sensitive (button_start_stop_script, false);
			set_sensitive (button_start_stop_test, false);
		end if;


	end read_last_session;


begin
	-- read system configuration file and set variables: name_directory_home, language, name_directory_bin, name_directory_enscript, interface_to_bsc
	check_environment;

--  Initialize GtkAda.
	gtk.main.init;

	-- create the  main window
	gtk_new (window_main);
	window_main.set_title (name_system);

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
	gtk_new (label_uut, to_upper(text_project));
	pack_start (box_selection_label, label_uut, true, true, 5);
	show (label_uut);
	gtk_new (label_script, to_upper(text_script));
	pack_start (box_selection_label, label_script, true, true, 5);
	show (label_script);
	gtk_new (label_test, to_upper(text_test));
	pack_start (box_selection_label, label_test, true, true, 5);
	show (label_test);

	-- BOX SELECTION CHOOSERS
	gtk_new_vbox (box_selection_directory);
	pack_start (box_head, box_selection_directory, true, true, 5);
	show (box_selection_directory);

	-- chooser UUT
 	gtk_new (chooser_set_uut, to_upper(text_project), action_select_folder);
 	pack_start (box_selection_directory, chooser_set_uut);
 	show (chooser_set_uut);

	-- chooser script
 	gtk_new (chooser_set_script, text_script, action_open);
 	pack_start (box_selection_directory, chooser_set_script);
	set_sensitive (chooser_set_script, false);
	-- filter 
	gtk_new(filter_scripts);
	add_pattern (filter_scripts, "*." & file_extension_script);
	set_filter (chooser_set_script, filter_scripts);
 	show (chooser_set_script);

	-- chooser test
 	gtk_new (chooser_set_test, text_test, action_select_folder);
 	pack_start (box_selection_directory, chooser_set_test);
	set_sensitive (chooser_set_test, false);
 	show (chooser_set_test);


	-- BOX START / STOP BUTTON
	gtk_new_vbox (box_start_stop);
	pack_start (box_head, box_start_stop, true, true, 5);
	show (box_start_stop);
	gtk_new (button_abort_shutdown, "ABORT/POWER OFF");
	pack_start (box_start_stop, button_abort_shutdown, true, true, 5);
	show (button_abort_shutdown);
	gtk_new (button_start_stop_script, text_label_button_script_start);
	pack_start (box_start_stop, button_start_stop_script, true, true, 5);
	set_sensitive (button_start_stop_script, false);
	show (button_start_stop_script);
	gtk_new (button_start_stop_test, text_label_button_test_start);
	pack_start (box_start_stop, button_start_stop_test, true, true, 5);
	set_sensitive (button_start_stop_test, false);
	show (button_start_stop_test);

	-- restore last session
	read_last_session;


	-- STATUS WINDOW
	gtk_new (img_status);
	set_status_image(ready);
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