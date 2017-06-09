-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 FILES AND DIRECTORIES                      --
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
with interfaces;				use interfaces;
with ada.directories;			use ada.directories;
with ada.containers;			use ada.containers;
with gnat.os_lib;   			use gnat.os_lib;
with ada.environment_variables;	--use ada.environment_variables;
with m1_string_processing;		use m1_string_processing;
with m1_test_gen_and_exec;		use m1_test_gen_and_exec;

package body m1_files_and_directories is

	procedure set_home_directory is
	-- sets variable name_home_directory (absolute path !)
	begin
		put_line("setting home directory ...");	
		name_directory_home := type_name_directory_home.to_bounded_string
			(
			ada.environment_variables.value("HOME") -- CS: use predefined constant
			); 
	end set_home_directory;

	procedure check_environment is
		previous_input	: Ada.Text_IO.File_Type renames current_input;
		line_length_max : constant positive := 300;
		package type_line is new generic_bounded_length(line_length_max); use type_line;
		line			: type_fields_of_line;
		prog_position	: string (1..5) := "ENV00";

		use type_name_directory_home;
		use type_name_directory_bin;		
		use type_name_directory_enscript;
		use type_interface_to_bsc;
	begin
		put_line("checking environment ...");
		-- get home variable
		if not ada.environment_variables.exists(name_environment_var_home) then
			raise constraint_error;
		else
			-- compose home directory name
			set_home_directory;
		end if;

		-- check if conf file exists	
		prog_position := "ENV10";
		if not exists
				(
				compose
					(
					containing_directory => compose( to_string(name_directory_home), name_directory_configuration),
					name => name_file_configuration 
					)
				) then 
			put_line(message_error & "configuration file " & compose
					(
					containing_directory => compose( to_string(name_directory_home), name_directory_configuration),
					name => name_file_configuration 
					) & " not found !");
			raise constraint_error;
		else
			-- read configuration file
			put_line("reading configuration file ...");
			open(
				file => file_system_configuraion,
				mode => in_file,
				name => compose
							(
							containing_directory => compose( to_string(name_directory_home), name_directory_configuration),
							name => name_file_configuration 
							)
				);
			set_input(file_system_configuraion);

			while not end_of_file
			loop
				line := read_line(get_line);
				if line.field_count /= 0 then -- if line contains anything
					--put_line(extended_string.to_string(line));

					-- get language
					if get_field_from_line(line,1) = text_language then 
						prog_position := "ENV20";
						put(" language ");
						language := type_language'value(get_field_from_line(line,2));
						put_line(type_language'image(language));
					end if;

					-- get bin directory
					if get_field_from_line(line,1) = text_directory_bin then 
						prog_position := "ENV30";
						put(" directory of binary files ");
						if get_field_from_line(line,2)(1) /= name_directory_separator(1) then -- we compare characters here
						-- if no heading /, take this as relative to home directory
							name_directory_bin := to_bounded_string
								(
								compose
									(
									to_string(name_directory_home),
									get_field_from_line(line,3)
									)
								);
						else -- otherwise take this as an absolute path
							name_directory_bin := to_bounded_string(get_field_from_line(line,2));
						end if;
						put_line(to_string(name_directory_bin));
					end if;

					-- get enscript directory
					if get_field_from_line(line,1) = text_directory_enscript then 
						prog_position := "ENV40";
						put(" directory of enscript ");
						if get_field_from_line(line,2)(1) /= name_directory_separator(1) then -- we compare characters here
						-- if no heading /, take this as relative to home directory
							name_directory_enscript := to_bounded_string
								(
								compose
									(
									to_string(name_directory_home),
									get_field_from_line(line,2)
									)	
								);
						else -- otherwise take this as an absolute path
							name_directory_enscript := to_bounded_string(get_field_from_line(line,2));
						end if;
						put_line(to_string(name_directory_enscript));
					end if;

					-- Get interface_to_scan_master.
					-- If interface exists, the bsc status registers are read.
					-- The firmware version serves as indicator of a valid BSC.
					if get_field_from_line(line,1) = text_interface_bsc then 
						prog_position := "ENV50";
						put(" interface to boundary scan controller ");						
						interface_to_bsc := to_bounded_string(get_field_from_line(line,2)); -- must be something like /dev/ttyUSB0
						put_line(to_string(interface_to_bsc));
						
						if exists (to_string(interface_to_bsc)) then
--							if is_open (to_string(interface_to_bsc)) then -- CS
								read_bsc_status_registers(interface_to_bsc);
								if bsc_register_firmware_executor >= bsc_firmware_executor_min then -- see m1_firmware
									-- CS: read other registers ?
									scan_master_present := true;
								else
									put(message_warning & " boundary scan controller firmware invalid ! Test execution not possible !");
									-- CS: show firmware version detected
								end if;
-- 							else
-- 								put(message_warning & " boundary scan controller not connected or turned off ! Test execution not possible !");	
--							end if;
						else
							--put_line(message_error & " interface " & to_string(interface_to_bsc) & " to boundary scan controller not found !");
							--put_line("Make sure the USB connector is plugged into the PC !");
							put_line(message_error & "boundary scan controller communication failure !");
							put_line("Check cables, turn on boundary scan controller and try again !");
							raise constraint_error;
						end if;

						
					end if;

				end if; -- if line contains anything useful

			end loop;
			close(file_system_configuraion);
		end if;

		set_input(previous_input);

	exception -- CS: rework
			when others =>
				put_line(message_error & "in system configuration file !"); -- CS: refine output (line number, affected line, ...)
				put_line(prog_position);
				raise;
	end check_environment;


	function is_project_directory return boolean is
	-- Checks if working directory is a project.
		is_project : boolean;
	begin
		--put_line(name_file_project_description);
		if exists(name_file_project_description) then
			is_project := true;
		else
			is_project := false;
		end if; 
		return is_project;
	end is_project_directory;

	procedure create_temp_directory is
		-- recreate an empty tmp directory
	begin
		if exists (name_directory_temp) then 
			delete_tree(name_directory_temp);
			create_directory(name_directory_temp);
		else create_directory(name_directory_temp);
		end if;
	end create_temp_directory;

	procedure create_bak_directory is
	-- creates an empty bak directory if no existing already
	begin
		if not exists (name_directory_bak) then 
			create_directory(name_directory_bak);
		end if;
	end create_bak_directory;

	function strip_trailing_forward_slash
	-- Trims trailing forward slash (directory separator) from a string.
		(text_in	: string) 
		return string is
	begin
		if text_in(text_in'last) = name_directory_separator(1) then -- we compare characters here
			return text_in(text_in'first .. text_in'last-1); -- trim last character
		end if;
		return text_in; -- otherwise return text_in unchanged
	end strip_trailing_forward_slash;

	procedure make_result_file (result : string) is
	-- Creates a temporarily file (in directory tmp) that contains the single word PASSED or FAILED as passed by "result".
	-- The graphical user interface reads this file in order to set the status image to FAIL or PASS.
	begin
		--put_line(standard_output,"create result file");
		--put_line(standard_output,current_directory);
		create ( file_test_result, name => (compose 
										(
										current_directory & name_directory_separator & name_directory_temp,
										name_file_test_result
										))
				); 
		put_line (file_test_result, result);
		close (file_test_result);
		--put_line(standard_output,"created result file");
	end make_result_file;

	procedure delete_result_file is
	-- Deletes the temporarily file (created by make_result_file) (in directory tmp).
	begin
		--put_line(standard_output,"delete result file");
		if exists (compose 
						(
						current_directory & name_directory_separator & name_directory_temp,
						name_directory_temp,
						name_file_test_result
						)) then
			delete_file(name => (compose 
									(
									current_directory & name_directory_separator & name_directory_temp,
									name_directory_temp,
									name_file_test_result
									))
				);
			--put_line(standard_output,"delete result file");
		end if;
	end delete_result_file;


	function valid_project (name_project : in type_name_project.bounded_string) return boolean is
	-- Returns true if given project is valid.
	-- name_project is assumed as absolute path !
	begin
		if exists(compose (type_name_project.to_string(name_project), name_file_project_description)) then
			-- CS: check more criteria
			return true;
		end if;
		return false;
	end valid_project;

	function valid_script (name_script : in type_name_script.bounded_string) return boolean is
	-- Returns true if given script is valid.
	begin
		if extension(type_name_script.to_string(name_script)) = file_extension_script then
			-- CS: check more criteria
			return true;
		end if;
		return false;
	end valid_script;

	
end m1_files_and_directories;
