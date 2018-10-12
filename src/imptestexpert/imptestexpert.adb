------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE IMPTESTEXPERT                       --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               B o d y                                    --
--                                                                          --
--         Copyright (C) 2018 Mario Blunk, Blunk electronic                 --
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

--   For correct displaying set tab with in your editor to 4.

--   The two letters "CS" indicate a "construction side" where things are not
--   finished yet or intended for the future.

--   Please send your questions and comments to:
--
--   info@blunk-electronic.de
--   or visit <http://www.blunk-electronic.de> for more contact data
--
--   history of changes:
--

with ada.text_io;				use ada.text_io;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;

with ada.strings;				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings.maps;			use ada.strings.maps;
with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.exceptions; 			use ada.exceptions;

with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_base;
with m1_import;
with m1_database;
with m1_files_and_directories;
with m1_string_processing;		use m1_string_processing;


procedure imptestexpert is

	version : constant string (1..3) := "001";

	procedure read_netlist is
		line_fields : m1_string_processing.type_fields_of_line;
		line_counter : positive_count;

		device_and_terminal_length : constant positive := 50;
		package type_device_and_terminal is new generic_bounded_length (device_and_terminal_length); -- D44.3 
		use type_device_and_terminal; 
		device_and_terminal : type_device_and_terminal.bounded_string;

		-- in an entry like IC501.56, the dot is from position 3 onwards. Examples: R3.2, LED54.2
		subtype type_position_of_dot is positive range 3..device_and_terminal_length;
		position_of_dot : type_position_of_dot;
			
		net_name		: m1_database.type_net_name.bounded_string;
		device_name		: m1_database.type_device_name.bounded_string;
		terminal_name	: m1_database.type_pin_name.bounded_string;

		net_cursor		: m1_import.type_map_of_nets.cursor;
		net_inserted	: boolean;

		use m1_database.type_net_name;
		use m1_database.type_device_name;
		use m1_database.type_pin_name;

		use m1_files_and_directories.type_name_file_netlist;
		
		procedure add_terminal (
		-- Adds the current terminal to the current net.
			net_name	: in m1_database.type_net_name.bounded_string;
			net			: in out m1_import.type_net) is
		begin
			put_line (" device '" & to_string (device_name) & "' terminal '" & to_string (terminal_name) & "'");
			m1_import.type_list_of_pins.append (
				container => net.pins,
				new_item => (
					name_device => device_name, -- IC501
					name_pin	=> terminal_name)); -- 56
		end add_terminal;

		use m1_import;
		use m1_files_and_directories;
		
	begin -- read_netlist
		write_message (
			file_handle	=> file_import_cad_messages,
			text		=> "reading netlist file ...",
			console 	=> true);

		open (
			file	=> file_cad_netlist, 
			mode 	=> in_file,
			name	=> to_string (name_file_cad_netlist));
		
		set_input (file_cad_netlist);

		while not end_of_file loop
			line_counter := line (current_input);
			line_fields := read_line (get_line);

-- 			put_line (standard_output, "line number " & positive_count'image (line_counter));
-- 			put_line (standard_output, "line " & to_string (line_fields));

			-- We ignore the file header and start reading nets from line 5 onward.
			-- CS: MAKE SURE THE NETS SECTION BEGINS HERE ALWAYS.
			if line_counter >= 5 then
				put_line ("line: " & to_string (line_fields));

				case line_fields.field_count is
					when 3 => -- A new net starts:
						net_name := to_bounded_string (get_field_from_line (line_fields, 3));
						put_line ("net '" & to_string (net_name) & "'");

						-- Insert a net in container map_of_nets.
						type_map_of_nets.insert (
							container	=> map_of_nets,
							key			=> net_name,
							position	=> net_cursor,
							inserted	=> net_inserted
							);

						-- CS exception occurs here if net occurs multiple times in the netlist
							
					when 1 => -- A terminal was found.
						
						device_and_terminal := to_bounded_string (get_field_from_line (line_fields, 1));

						position_of_dot := index (device_and_terminal, ".");
						-- CS exception would occur here if dot is at the wrong position in something like IC501.56

						-- Extract the device name from IC501.56
						device_name := to_bounded_string (slice (device_and_terminal, 1, position_of_dot - 1));

						-- Extract the terminal name from IC501.56
						terminal_name := to_bounded_string (slice (
							device_and_terminal,
							position_of_dot + 1,
							length (device_and_terminal)));

						-- Add the terminal to the net.
						type_map_of_nets.update_element (
							container	=> map_of_nets,
							position	=> net_cursor,
							process 	=> add_terminal'access);

					when 0 => null; -- empty line
						
					when others => -- invalid number of fields
						raise constraint_error;
				end case;
				
			end if;
		end loop;

		put_line("done");

		set_input (standard_input);
		close (file_cad_netlist);
		
	end read_netlist;

	
	procedure read_partlist is
		line_fields : m1_string_processing.type_fields_of_line;
		line_counter : positive_count;

		device_name		: m1_database.type_device_name.bounded_string;
		value			: m1_database.type_device_value.bounded_string;
		package_name	: m1_database.type_package_name.bounded_string;
		
		use m1_database.type_device_name;
		use m1_database.type_device_value;		
		use m1_database.type_package_name;

		use m1_files_and_directories.type_name_file_partlist;

		use m1_import;
		use m1_files_and_directories;

	begin
		-- map_of_devices : type_map_of_devices.map;		

		write_message (
			file_handle	=> file_import_cad_messages,
			text		=> "reading partlist file ...",
			console 	=> true);

		open (
			file	=> file_cad_partlist, 
			mode 	=> in_file,
			name	=> to_string (name_file_cad_partlist));
		
		set_input (file_cad_partlist);

		while not end_of_file loop
			line_counter := line (current_input);
			line_fields := read_line (get_line);

-- 			put_line (standard_output, "line number " & positive_count'image (line_counter));
-- 			put_line (standard_output, "line " & to_string (line_fields));

			-- We ignore the file header and start reading parts from line 8 onward.
			-- CS: MAKE SURE THE NETS SECTION BEGINS HERE ALWAYS.
			if line_counter >= 8 then
				put_line ("line: " & to_string (line_fields));

				case line_fields.field_count is
					when 8 => 	-- A valid device entry like: 
								-- IC501 7.400 15.400 180.0 A1 (T) '74193', 'SO16'
						device_name		:= to_bounded_string (get_field_from_line (line_fields, 1));
						value			:= to_bounded_string (get_field_from_line (line_fields, 7));
						package_name	:= to_bounded_string (get_field_from_line (line_fields, 8));

						-- strip quotes and trailing comma from value
						value := to_bounded_string (slice (value, 2, length (value) - 2));

						-- strip quotes from package name
						package_name := to_bounded_string (slice (package_name, 2, length (package_name) - 1));
						
						put_line ("device '" & to_string (device_name) & "'");
						put_line ("package '" & to_string (package_name) & "'");
						put_line ("value '" & to_string (value) & "'");

						-- Insert the device in container map_of_devices.
						type_map_of_devices.insert (
							container	=> map_of_devices,
							key			=> device_name,
							new_item	=> (
									packge	=> package_name,
									value	=> value));

						-- CS exception occurs here if device occurs multiple times in the partlist
							
					when others => null;
				end case;
				
			end if;
		end loop;

		put_line("done");

		set_input (standard_input);
		close (file_cad_partlist);
		
	end read_partlist;


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

	use m1_files_and_directories;
	
begin
	m1_base.action := m1_base.import_cad;

	-- create message/log file	
	m1_import.format_cad := m1_import.TESTEXPERT;
	write_log_header (version);
	
	put_line (to_upper (name_module_cad_importer_testexpert) & " version " & version);
	put_line("======================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages
	
	name_file_cad_netlist := type_name_file_netlist.to_bounded_string (argument (1));

	name_file_cad_partlist := type_name_file_partlist.to_bounded_string (argument (2));
	
	write_message (
		file_handle	=> file_import_cad_messages,
		text		=> "netlist  " & type_name_file_netlist.to_string (name_file_cad_netlist),
		console		=> true);

	write_message (
		file_handle	=> m1_files_and_directories.file_import_cad_messages,
		text		=> "partlist " & type_name_file_partlist.to_string (name_file_cad_partlist),
		console		=> true);
	
	m1_import.cad_import_target_module := m1_import.type_cad_import_target_module'value (argument (3));
	
	write_message (
		file_handle => m1_files_and_directories.file_import_cad_messages,
		text 		=> "target module " & m1_import.type_cad_import_target_module'image (m1_import.cad_import_target_module),
		console		=> true);
	
	if m1_import."=" (m1_import.cad_import_target_module, m1_import.SUB) then
		m1_import.target_module_prefix := m1_string_processing.type_universal_string.to_bounded_string (argument(4));

		write_message (
			file_handle	=> m1_files_and_directories.file_import_cad_messages,
			text		=> "prefix " & m1_string_processing.type_universal_string.to_string (m1_import.target_module_prefix),
			console		=> true);
		
		name_file_skeleton_submodule := m1_files_and_directories.type_name_file_skeleton_submodule.to_bounded_string (
			compose (
				name => 
					base_name (name_file_skeleton) & "_" & 
					type_universal_string.to_string (m1_import.target_module_prefix),
				extension => file_extension_text));
	end if;
	
	read_netlist;

	read_partlist;

	m1_import.write_skeleton (name_module_cad_importer_testexpert, version);

	write_log_footer;	
	
	exception when event: others =>
		set_exit_status (failure);

-- 		write_message (
-- 			file_handle => m1_files_and_directories.file_import_cad_messages,
-- 			--text		=> message_error & "at program position " & natural'image (prog_position),
-- 			text		=> message_error, -- CS line number in netlist ?
-- 			console		=> true);
	
		if is_open (file_skeleton) then
			close (file_skeleton);
		end if;

		if is_open (file_cad_netlist) then
			close (file_cad_netlist);
		end if;

		write_message (
			file_handle	=> m1_files_and_directories.file_import_cad_messages,
			text		=> "exception name: " & exception_name (event),
			console		=> true);

		write_message (
			file_handle => m1_files_and_directories.file_import_cad_messages,
			text		=> "exception message: " & exception_message (event),
			console		=> true);

		write_log_footer;


end imptestexpert;

-- Soli Deo Gloria
