------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE BSMGUI_CB                           --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               B o d y                                    --
--                                                                          --
--         Copyright (C) 2017 Mario Blunk, Blunk electronic                 --
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
--   info@blunk-electronic.de
--   or visit <http://www.blunk-electronic.de> for more contact data
--
--   history of changes:
--
--   todo: 

with ada.characters.handling; 	use ada.characters.handling;
with ada.directories;			use ada.directories;
with ada.containers;			use ada.containers;
with gnat.os_lib;   			use gnat.os_lib;
with gtk.main;

with m1_base;					use m1_base;
with m1_string_processing;		use m1_string_processing;
with m1_files_and_directories; 	use m1_files_and_directories;
with m1_test_gen_and_exec;		use m1_test_gen_and_exec;

package body bsmgui_cb is

	use type_name_directory_bin;
	use type_name_directory_home;
	use type_name_script;
	use type_name_project;
	use type_name_test;

	procedure write_log_header (version : in string) is
	begin
		if not exists (name_directory_messages) then
			create_directory(name_directory_messages);
		end if;

		create(
			file => file_gui_messages,
			mode => out_file,
			name => name_file_gui_messages);

		put_line(file_gui_messages, to_upper(name_module_cli) & " version " & version & " LOGFILE");
		put_line(file_gui_messages, "date " & date_now);
		put_line(file_gui_messages, column_separator_0);
	end write_log_header;

	procedure write_log_footer is
	begin
		put_line(file_gui_messages, column_separator_0);
		put_line(file_gui_messages, to_upper(name_module_gui) & " LOGFILE END");
	end write_log_footer;

	
	procedure write_session_file_headline is
	begin
-- 		put_line(" writing header ...");
		put_line( file_session, "-- THIS FILE HOLDS THE SETTINGS OF THE LAST GUI SESSION");
		put_line( file_session, "-- DO NOT EDIT !");
		put_line( file_session, "-- date: " & date_now);
	end write_session_file_headline;

	procedure set_status_image(status : in type_status_image) is
	begin
		case status is
			when fail =>
				set(img_status, 
					to_string(name_directory_home) & name_directory_separator & -- /home/user/
					compose
						(
						containing_directory => name_directory_configuration_images,
						name => name_file_image_fail,
						extension => file_extension_png
						)
					);

			when pass =>
				set(img_status, 
					to_string(name_directory_home) & name_directory_separator & -- /home/user/
					compose
						(
						containing_directory => name_directory_configuration_images,
						name => name_file_image_pass,
						extension => file_extension_png
						)
					);

			when ready =>
				set(img_status, 
					to_string(name_directory_home) & name_directory_separator & -- /home/user/
					compose
						(
						containing_directory => name_directory_configuration_images,
						name => name_file_image_ready,
						extension => file_extension_png
						)
					);

			when running =>
				set(img_status, 
					to_string(name_directory_home) & name_directory_separator & -- /home/user/
					compose
						(
						containing_directory => name_directory_configuration_images,
						name => name_file_image_run,
						extension => file_extension_png
						)
					);

			when aborted =>
				set(img_status, 
					to_string(name_directory_home) & name_directory_separator & -- /home/user/
					compose
						(
						containing_directory => name_directory_configuration_images,
						name => name_file_image_aborted,
						extension => file_extension_png
						)
					);

			when abort_fail =>
				set(img_status, 
					to_string(name_directory_home) & name_directory_separator & -- /home/user/
					compose
						(
						containing_directory => name_directory_configuration_images,
						name => name_file_image_abort_failed,
						extension => file_extension_png
						)
					);


		end case;
	end set_status_image;

	procedure terminate_main (self : access gtk_widget_record'class) is
	begin
		put_line("saving session ...");
		create( file => file_session, name => compose
						(
						containing_directory => compose( to_string(name_directory_home), name_directory_configuration),
						name => name_file_configuration_session 
						)
			);
		-- write info headline
		write_session_file_headline;

		-- write current project, script and test in session configuration file
		put_line( file_session, text_project & row_separator_0 & to_string(name_project));
		put_line( file_session, text_script & row_separator_0 & simple_name(to_string(name_script))); -- CS: check if script valid ?
		put_line( file_session, text_test & row_separator_0 & simple_name(to_string(name_test))); -- CS: check if test valid ?
		close(file_session);

		put_line (name_module_gui & " terminated");
		
		gtk.main.main_quit;
		write_log_footer;		
	end terminate_main;



	procedure set_project (self : access gtk_file_chooser_button_record'class) is
		result : natural;
	begin
		name_project := to_bounded_string(gtk.file_chooser_button.get_current_folder(self));
		-- Check if this is a valid project directory.
		if valid_project(name_project) then

			-- IF PROJECT CHANGES: 
			--    clear bsc ram
			--    set project as requested
			--    set script to project directory as default
			--    set test to project directory as default
			if name_project /= name_project_previous then
				delay time_for_interface_to_become_free;
				spawn 
					(  
					program_name           => compose(to_string(name_directory_bin), name_module_cli),
					args                   => 	(
												1=> new string'(to_lower(type_action'image(clear)))
												),
					output_file_descriptor => standout,
					return_code            => result
					);

				if result = 0 then -- ram clearing successful
					name_project_previous := name_project; -- update name_project_previous to current name
					put_line("set project: " & to_string(name_project));

					-- Reset test and script choosers to project root directory as default.
					-- Disable start buttons. 
					if set_filename(chooser_set_script, to_string(name_project)) then 
						put_line("set script: " & to_string(name_project));
						set_sensitive (button_start_stop_script, false);
					end if;

					if set_filename(chooser_set_test, to_string(name_project)) then  
						put_line("set test: " & to_string(name_project));
						set_sensitive (button_start_stop_test, false);
					end if;

				else
					set_status_image(fail);
					raise constraint_error;
				end if;
			end if;

			-- enable test and script choosers
			-- update status image to "ready"
			set_sensitive (chooser_set_test, true);
			set_sensitive (chooser_set_script, true);
			set_status_image(ready);

		else
			put_line(message_error & "Invalid project" & exclamation);

			if set_filename(chooser_set_script, to_string(name_project)) then 
				null;
			end if;
			if set_current_folder(chooser_set_test, to_string(name_project)) then 
				null;
			end if;

			-- disable test and script choosers
			set_sensitive (chooser_set_test, false);
			set_sensitive (chooser_set_script, false);

			-- disable start buttons
			set_sensitive (button_start_stop_script, false);
			set_sensitive (button_start_stop_test, false);

			set_status_image(fail);
		end if;
	end set_project;


	procedure set_script (self : access gtk_file_chooser_button_record'class) is
	begin
		-- The script must be inside the current project directory.
		if containing_directory(gtk.file_chooser_button.get_filename(self)) = to_string(name_project) then

			-- Update script name. If valid, update status image.
			name_script := to_bounded_string(gtk.file_chooser_button.get_filename(self));

			if valid_script(name_script) then
				put_line("set script: " & to_string(name_script));
				--script_valid := true;
				set_sensitive (button_start_stop_script, true);
				set_status_image(ready);
			else
				put_line(message_error & "Script invalid" & exclamation);
				set_sensitive (button_start_stop_script, false);
				set_status_image(fail);
			end if;
		else
			if set_filename(chooser_set_script, to_string(name_project)) then
				put_line(message_error & "Script outside current project" & exclamation);
			end if;
			-- CS: find a way to jail the operator in the current project directory
		end if;
	end set_script;


	procedure set_test (self : access gtk_file_chooser_button_record'class) is
	begin
		-- The test must be inside the current project directory.
		if containing_directory(gtk.file_chooser_button.get_filename(self)) = to_string(name_project) then

			-- Update test name. If valid, update status image.
			name_test := to_bounded_string(gtk.file_chooser_button.get_filename(self));

			-- If test is compiled, enable start button.
			if test_compiled (to_string(name_test)) then
				put_line("set test: " & to_string(name_test));
				--test_valid := true;
				set_sensitive (button_start_stop_test, true);
				set_status_image(ready);
			else 
				put_line(message_error & "Test invalid or not compiled yet" & exclamation);
				set_sensitive (button_start_stop_test, false);
				set_status_image(fail);
			end if;
		else
			if set_filename(chooser_set_test, to_string(name_project)) then
				put_line(message_error & "Test outside current project" & exclamation);
			end if;
			-- CS: find a way to jail the operator in the current project directory
		end if;
	end set_test;



	procedure evaluate_result_file is
	-- EVALUATE TEST RESULT FILE (created by name_module_cli once test has finished).
	-- Depending on the test result (PASSED/FAILED) this file contains the single word PASSED or FAILED upon which
	-- the status image is updated. The file must exist. If missing, no status image update happens.
		input_file 	: ada.text_io.file_type;
		line		: type_fields_of_line;
		--field_count	: natural;
	begin
		if exists (compose (
				containing_directory => compose( to_string(name_project), name_directory_temp),
				name => name_file_test_result )) then
			open(
				file => input_file,
				mode => in_file,
				name => (compose (
					containing_directory => compose (to_string(name_project), name_directory_temp),
					name => name_file_test_result))
				);
			set_input(input_file);

			-- reading test result file commences here:
			while not end_of_file loop
				line := read_line(get_line);
				--put_line(extended_string.to_string(line));
				--field_count := get_field_count(extended_string.to_string(line));
				if line.field_count = 1 then
					if get_field_from_line(line, 1) = passed then
						--put_line(passed);
						-- UPDATE STATUS IMAGE TO "PASS"
						set_status_image(pass);
					else
						--put_line(failed);
						-- UPDATE STATUS IMAGE TO "FAIL"
						set_status_image(fail);
					end if;
				end if;
			end loop;
			close(input_file);
			set_input(standard_input);
		else
			put_line(message_error & "test result file " & name_file_test_result & " missing !");
			raise constraint_error;
		end if;
	end evaluate_result_file;

	procedure shutdown_uut is
		result : natural;
	begin
		delay time_for_interface_to_become_free;
		spawn 
			(  
			program_name           => compose( to_string(name_directory_bin), name_module_cli),
			args                   => 	(
										1=> new string'(to_lower(type_action'image(off)))
										),
			output_file_descriptor => standout,
			return_code            => result
			);

		if result = 0 then -- shutdown successful
			set_status_image(aborted);
		else -- shutdown failed
			set_status_image(abort_fail);
		end if;
	end shutdown_uut;


	procedure start_stop_test (self : access gtk_button_record'class) is
		result 	: natural := 0;
		dead	: boolean;
	begin
		set_sensitive (chooser_set_uut, false);
		set_sensitive (chooser_set_script, false);
		set_sensitive (chooser_set_test, false);
		set_sensitive (button_start_stop_script, false);

		set_directory (to_string(name_project));

		case status_test is
			when stopped | finished =>
				--set_sensitive (button_start_stop_script, false);
				set_label(button_start_stop_test,text_label_button_test_stop);
				put_line ("start test: " & to_string(name_test));

				-- UPDATE STATUS IMAGE TO "RUNNING"
				set_status_image(running);
				
				-- LAUNCH TEST (via name_module_cli and send it into background)
				while gtk.main.events_pending loop dead := gtk.main.main_iteration; end loop; -- refresh gui
				result := system
					(
					to_string(name_directory_bin) &
					name_directory_separator &
					name_module_cli & row_separator_0 &
					to_lower(type_action'image(run)) & row_separator_0 &
					simple_name(to_string(name_test)) & row_separator_0 &
					to_lower(type_step_mode'image(off)) & row_separator_0 & "&" & ASCII.NUL 
					);

				-- set test status to "running" so that next click on "test start" button takes us in case status_test "running"
				status_test := running;

				-- WAIT UNTIL TEST FINISHES
				-- This is achieved by polling the process id of name_module_cli until the process finishes.
				result := 0;
				while result = 0 loop
					delay gui_refresh_rate;
					while gtk.main.events_pending loop dead := gtk.main.main_iteration; end loop;
					spawn 
						(  
						program_name           => name_module_pidof,
						args                   => 	(
													1=> new string'(name_module_cli)
													),
						output_file_descriptor => trash_bin_text,

						return_code            => result
						);
				end loop;

				if not abort_pending then
					evaluate_result_file;
					set_label(button_start_stop_test,text_label_button_test_start);
				end if;

				status_test := finished;



			when running =>
				abort_pending := true;
				put_line ("aborting test " & to_string(name_test) & " ...");

				-- Kill process name_module_cli. -- CS: THIS DOES NOT WORK WITH MS-WINDOWS !
				--result := system( "p=$(pidof " & name_module_cli & "); kill $p" & ASCII.NUL );
				result := system( "p=$(" & name_module_pidof & row_separator_0 & name_module_cli & "); kill $p" & ASCII.NUL );

				-- When killed, shutdown UUT.
				if result = 0 then
					shutdown_uut;
				else -- process name_module_cli could not be killed
					set_status_image(abort_fail);
				end if;

				status_test := stopped;
				set_label(button_start_stop_test,text_label_button_test_start);
				abort_pending := false;
		end case;

		-- enable choosers
		set_sensitive (chooser_set_uut, true);
		set_sensitive (chooser_set_script, true);
		set_sensitive (chooser_set_test, true);
		set_sensitive (button_start_stop_script, true);			
	end start_stop_test;


	procedure start_stop_script (self : access gtk_button_record'class) is
		result 	: natural := 0;
		dead	: boolean;
	begin
		set_sensitive (chooser_set_uut, false);
		set_sensitive (chooser_set_script, false);
		set_sensitive (chooser_set_test, false);
		set_sensitive (button_start_stop_test, false);

		set_directory (to_string(name_project));

		-- Remove stale result file (in temp directory) from previous runs.
		delete_result_file; -- This does not require any scripts to do so on start-up.

		case status_script is
			when stopped | finished =>
				set_label (button_start_stop_script,text_label_button_script_stop);
				put_line ("start script " & to_string(name_script));

				-- UPDATE STATUS IMAGE TO "RUNNING"
				set_status_image(running);

				-- LAUNCH SCRIPT (as an external program in the background)
				while gtk.main.events_pending loop dead := gtk.main.main_iteration; end loop;
				result := system
					(
					to_string(name_script) & row_separator_0 & "&" & ASCII.NUL 
					);

				-- set test status to "running" so that next click on "script start" button takes us in case status_script "running"
				status_script := running;

				-- WAIT UNTIL SCRIPT FINISHES
				-- This is achieved by polling the process id of the script until the process finishes.
				result := 0;
				while result = 0 loop
					delay gui_refresh_rate;
					while gtk.main.events_pending loop dead := gtk.main.main_iteration; end loop;
					spawn 
						(  
						program_name           => name_module_pidof,
						args                   => 	(
													1=> new string'("-x"), -- x option makes pidof search for scripts
													2=> new string'(to_string(name_script))
													),
						output_file_descriptor => trash_bin_text,
						return_code            => result
						);
				end loop;

				if not abort_pending then
					evaluate_result_file; -- All scripts require to write the result file at the end of the script !
					set_label(button_start_stop_script,text_label_button_script_start);
				end if;

				status_script := finished;

			when running =>
				abort_pending := true;
				put_line ("aborting script " & to_string(name_script) & " ...");

				-- Kill process name_script. -- x option makes pidof searching for scripts
				--result := system( "p=$(pidof -x " & simple_name(universal_string_type.to_string(name_script)) & "); kill $p" & ASCII.NUL );
				result := system( "p=$(" & name_module_pidof & " -x " & simple_name(to_string(name_script)) & "); kill $p" & ASCII.NUL );
				-- CS: test result ?
				--result := system( "p=$(pidof " & name_module_cli & "); kill $p" & ASCII.NUL );
				result := system( "p=$(" & name_module_pidof & row_separator_0 & name_module_cli & "); kill $p" & ASCII.NUL );
				--result := system( "p=$(pidof " & name_module_kermit & "); kill $p" & ASCII.NUL );

				-- When killed, shutdown UUT.
				if result = 0 then
					--put_line ("killing ....");
					shutdown_uut;
				else
					set_status_image(abort_fail);
				end if;

				status_script := stopped;
				set_label(button_start_stop_script,text_label_button_script_start);
				abort_pending := false;
		end case;

		-- enable choosers
		set_sensitive (chooser_set_uut, true);
		set_sensitive (chooser_set_script, true);
		set_sensitive (chooser_set_test, true);
		set_sensitive (button_start_stop_test, true);			
	end start_stop_script;


	procedure abort_shutdown (self : access gtk_button_record'class) is
		result 	: natural;
		dead	: boolean;
	begin
		abort_pending := true;
		put_line(aborting);

		set_sensitive (chooser_set_uut, false);
		set_sensitive (chooser_set_script, false);
		set_sensitive (chooser_set_test, false);
		set_sensitive (button_start_stop_test, false);
		set_sensitive (button_start_stop_script, false);
		--set_directory(universal_string_type.to_string(name_project));

		while gtk.main.events_pending loop dead := gtk.main.main_iteration; end loop;
		--result := system( "p=$(pidof -x " & simple_name(universal_string_type.to_string(name_script)) & "); kill $p" & ASCII.NUL );
		result := system( "p=$(" & name_module_pidof & " -x " & simple_name(to_string(name_script)) & "); kill $p" & ASCII.NUL );
		-- CS: test result ?
		--result := system( "p=$(pidof " & name_module_cli & "); kill $p" & ASCII.NUL );
		result := system( "p=$(" & name_module_pidof & row_separator_0 & name_module_cli & "); kill $p" & ASCII.NUL );
		-- CS: test result ?
		--result := system( "p=$(pidof " & name_module_kermit & "); kill $p" & ASCII.NUL );
		-- CS: test result ?

		if result = 0 then
			null;
		else
			set_status_image(abort_fail);
		end if;

		shutdown_uut;

		if valid_project (to_string(name_project)) then
			if valid_script (to_string(name_script)) then
				set_sensitive (button_start_stop_script, true);
				set_sensitive (chooser_set_script, true);
			end if;
			if test_compiled (to_string(name_test)) then
				set_sensitive (button_start_stop_test, true);
				set_sensitive (chooser_set_test, true);
			end if;
		end if;

		set_sensitive (chooser_set_uut, true);

		abort_pending := false;

	end abort_shutdown;


end bsmgui_cb;
