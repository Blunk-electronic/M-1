------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE BSMGUI_CB                           --
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

--with ada.strings; 				use ada.strings;
--with ada.strings.fixed; 		use ada.strings.fixed;
--with ada.text_io; 				use ada.text_io;
with ada.characters.handling; 	use ada.characters.handling;
with ada.directories;			use ada.directories;
with gnat.os_lib;   			use gnat.os_lib;
--with ada.environment_variables;	--use ada.environment_variables;
with gtk.main;
with m1_internal; 				use m1_internal;
with m1_files_and_directories; 	use m1_files_and_directories;

package body bsmgui_cb is

	procedure terminate_main (self : access gtk_widget_record'class) is
	begin
		put_line ("terminated");
		--destroy (self);
		gtk.main.main_quit;
	end terminate_main;



	procedure set_project (self : access gtk_file_chooser_button_record'class) is
	begin
	-- CS: check if this is a valid project directory
		name_project := universal_string_type.to_bounded_string(gtk.file_chooser_button.get_current_folder(self));

			put_line("set project:" & universal_string_type.to_string(name_project));

			if chooser_set_test.set_current_folder(universal_string_type.to_string(name_project)) then 
				put_line("project preset for test: " & universal_string_type.to_string(name_project));
			end if;
			if chooser_set_script.set_current_folder(universal_string_type.to_string(name_project)) then 
				put_line("project preset for script: " & universal_string_type.to_string(name_project));
			end if;

			set_sensitive (chooser_set_test, true);
			set_sensitive (chooser_set_script, true);

	end set_project;


	procedure set_script (self : access gtk_file_chooser_button_record'class) is
	-- CS: check if this is a valid script (even if the file filter selects *.sh)
	begin
		set_sensitive (button_start_stop_script, true);
		name_script := universal_string_type.to_bounded_string(gtk.file_chooser_button.get_filename(self));
		put_line("set script: " & universal_string_type.to_string(name_script));
	end set_script;


	procedure set_test (self : access gtk_file_chooser_button_record'class) is
	begin
	-- CS: check if this is a test directory with a vector file
		set_sensitive (button_start_stop_test, true);
		name_test := universal_string_type.to_bounded_string(gtk.file_chooser_button.get_filename(self));
		put_line("set test: " & universal_string_type.to_string(name_test));
	end set_test;



	procedure evaluate_result_file is
	-- EVALUATE TEST RESULT FILE (created by name_module_cli once test has finished).
	-- Depending on the test result (PASSED/FAILED) this file contains the single word PASSED or FAILED upon which
	-- the status image is updated. The file must exist. If missing, no status image update happens.
		input_file 	: ada.text_io.file_type;
		line		: extended_string.bounded_string;
		field_count	: natural;
	begin
		if exists (compose 
						(
						current_directory & name_directory_separator & name_directory_temp,
						name_file_test_result
						)) then
			open(
				file => input_file,
				mode => in_file,
				name => (compose 
								(
								current_directory & name_directory_separator & name_directory_temp,
								name_file_test_result
								))
				);
			set_input(input_file);

			-- reading test result file commences here:
			while not end_of_file loop
				line := extended_string.to_bounded_string(get_line);
				--put_line(extended_string.to_string(line));
				field_count := get_field_count(extended_string.to_string(line));
				if field_count = 1 then
					if get_field_from_line(text_in => line, position => 1) = passed then
						--put_line(passed);
						-- UPDATE STATUS IMAGE TO "PASS"
						set(img_status, 
							universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
							compose
								(
								containing_directory => name_directory_configuration_images,
								name => name_file_image_pass,
								extension => file_extension_png
								)
							);
					else
						--put_line(failed);
						-- UPDATE STATUS IMAGE TO "FAIL"
						set(img_status, 
							universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
							compose
								(
								containing_directory => name_directory_configuration_images,
								name => name_file_image_fail,
								extension => file_extension_png
								)
							);
					end if;
				end if;
			end loop;
			close(input_file);
			set_input(standard_input);
		else
			put_line(message_error & " Test result file " & quote_single & name_file_test_result & quote_single & " missing" & exclamation);
			raise constraint_error;
		end if;
	end evaluate_result_file;

	procedure shutdown_uut is
		result : natural;
	begin
		delay time_to_free_the_interface; -- CS: poll interface until no blocked any more
		spawn 
			(  
			program_name           => universal_string_type.to_string(name_directory_bin) & name_directory_separator & name_module_cli,
			args                   => 	(
										1=> new string'(to_lower(type_action'image(off)))
										),
			output_file_descriptor => standout,
			return_code            => result
			);

		if result = 0 then -- shutdown successful
			set(img_status, 
				universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
				compose
					(
					containing_directory => name_directory_configuration_images,
					name => name_file_image_aborted,
					extension => file_extension_png
					)
				);

		else -- shutdown failed
			set(img_status, 
				universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
				compose
					(
					containing_directory => name_directory_configuration_images,
					name => name_file_image_abort_failed,
					extension => file_extension_png
					)
				);
		end if;
	end shutdown_uut;


	procedure start_stop_test (self : access gtk_button_record'class) is
		result 	: natural := 0;
		dead	: boolean;
	begin
		--open(file => file_thrash_bin, name => "/dev/null", mode => out_file);

		set_sensitive (chooser_set_uut, false);
		set_sensitive (chooser_set_script, false);
		set_sensitive (chooser_set_test, false);

		set_directory(universal_string_type.to_string(name_project));

		case status_test is
			when stopped | finished =>
				--set_sensitive (button_start_stop_script, false);
				set_label(button_start_stop_test,"STOP"); -- CS: variable for label
				put_line ("start test: " & universal_string_type.to_string(name_test));

				-- UPDATE STATUS IMAGE TO "RUNNING"
				set(img_status, 
					universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
					compose
						(
						containing_directory => name_directory_configuration_images,
						name => name_file_image_run,
						extension => file_extension_png
						)
					);
				
				-- LAUNCH TEST (via name_module_cli and send it into background)
				while gtk.main.events_pending loop dead := gtk.main.main_iteration; end loop; -- refresh gui
				result := system
					(
					universal_string_type.to_string(name_directory_bin) &
					name_directory_separator &
					name_module_cli & row_separator_0 &
					to_lower(type_action'image(run)) & row_separator_0 &
					simple_name(universal_string_type.to_string(name_test)) & row_separator_0 &
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
						program_name           => "/bin/pidof", -- CS: needs variable setup by environment check
						args                   => 	(
													--1=> new string'("-p"),
													1=> new string'(name_module_cli)
													),
						output_file_descriptor => standout, -- CS: send it to /dev/null
						return_code            => result
						);
				end loop;

				evaluate_result_file;
				set_label(button_start_stop_test,"START"); -- CS: variable for label
				status_test := finished;



			when running =>
				put_line ("aborting test: " & universal_string_type.to_string(name_test));

				-- Kill process name_module_cli.
				result := system( "p=$(pidof " & name_module_cli & "); kill $p; sleep 1" & ASCII.NUL ); -- CS: variable for delay value

				-- When killed, shutdown UUT.
				if result = 0 then
					shutdown_uut;
				else -- process name_module_cli could not be killed
					set(img_status, 
						universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
						compose
							(
							containing_directory => name_directory_configuration_images,
							name => name_file_image_abort_failed,
							extension => file_extension_png
							)
						);
				end if;

				status_test := stopped;
				set_label(button_start_stop_test,"START");
		end case;



-- 		if result = 0 then
-- 			put_line(passed);
-- 
-- 		else
-- 			put_line(failed);
-- 
-- 		end if;

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

		set_directory(universal_string_type.to_string(name_project));

		-- Remove stale result file (in temp directory) from previous runs.
		delete_result_file; -- This does not require any scripts to do so on start-up.

		case status_script is
			when stopped | finished =>
				set_label(button_start_stop_script,"STOP"); -- CS: variable for label
				put_line ("start script: " & universal_string_type.to_string(name_script));

				-- UPDATE STATUS IMAGE TO "RUNNING"
				set(img_status, 
					universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
					compose
						(
						containing_directory => name_directory_configuration_images,
						name => name_file_image_run,
						extension => file_extension_png
						)
					);


				-- LAUNCH SCRIPT (as an external program in the background)
				while gtk.main.events_pending loop dead := gtk.main.main_iteration; end loop;
				result := system
					(
					universal_string_type.to_string(name_script) & row_separator_0 & "&" & ASCII.NUL 
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
						program_name           => "/bin/pidof", -- CS: needs variable setup by environment check
						args                   => 	(
													1=> new string'("-x"),
													2=> new string'(universal_string_type.to_string(name_script))
													),
						output_file_descriptor => standout, -- CS: send it to /dev/null
						return_code            => result
						);
				end loop;

				evaluate_result_file; -- All scripts require to write the result file at the end of the script !
				set_label(button_start_stop_script,"START"); -- CS: variable for label
				status_script := finished;

			when running =>
				put_line ("aborting script: " & universal_string_type.to_string(name_script));

				-- Kill process name_script.
				result := system( "p=$(pidof -x " & universal_string_type.to_string(name_script) & "); kill $p; sleep 1" & ASCII.NUL ); -- CS: variable for delay value

				-- When killed, shutdown UUT.
				if result = 0 then
					--put_line ("aborting ....");
					shutdown_uut;
				else
					set(img_status, 
						universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
						compose
							(
							containing_directory => name_directory_configuration_images,
							name => name_file_image_abort_failed,
							extension => file_extension_png
							)
						);
				end if;

				status_script := stopped;
				set_label(button_start_stop_script,"START");
		end case;

		set_sensitive (chooser_set_uut, true);
		set_sensitive (chooser_set_script, true);
		set_sensitive (chooser_set_test, true);
		set_sensitive (button_start_stop_test, true);
	end start_stop_script;


	procedure abort_shutdown (self : access gtk_button_record'class) is
		result 	: natural;
	begin
		set_sensitive (chooser_set_uut, false);
		set_sensitive (chooser_set_script, false);
		set_sensitive (chooser_set_test, false);
		set_sensitive (button_start_stop_test, false);
		--set_directory(universal_string_type.to_string(name_project));

		put_line(aborting);

		spawn 
			(  
			program_name           => universal_string_type.to_string(name_directory_bin) & name_directory_separator & name_module_cli,
			args                   => 	(
										1=> new string'(to_lower(type_action'image(off)))
										),
			output_file_descriptor => standout,
			return_code            => result
			);

		if result = 0 then
			put_line(successful);
			set(img_status, 
				universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
				compose
					(
					containing_directory => name_directory_configuration_images,
					name => name_file_image_aborted,
					extension => file_extension_png
					)
				);

		else
			put_line(failed);
			set(img_status, 
				universal_string_type.to_string(name_directory_home) & name_directory_separator & -- /home/user/
				compose
					(
					containing_directory => name_directory_configuration_images,
					name => name_file_image_abort_failed,
					extension => file_extension_png
					)
				);

		end if;

		set_sensitive (chooser_set_uut, true);
		set_sensitive (chooser_set_script, true);
		set_sensitive (chooser_set_test, true);
		set_sensitive (button_start_stop_test, true);
	end abort_shutdown;

end bsmgui_cb;
