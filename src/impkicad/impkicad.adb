------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE IMPKICAD                            --
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
--   NOTE: This importer has been tested with kicad v4

--   history of changes:
--


with ada.text_io;				use ada.text_io;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;

with ada.strings;				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.exceptions; 			use ada.exceptions;

with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_base;					use m1_base;
with m1_import;					use m1_import;
with m1_database;               use m1_database;
with m1_numbers;                use m1_numbers;
with m1_files_and_directories;  use m1_files_and_directories;
with m1_string_processing;		use m1_string_processing;


procedure impkicad is

	version			: constant string (1..3) := "001";
    prog_position	: natural := 0;

	use type_net_name;
	use type_device_name;
	use type_device_value;
	use type_package_name;
	use type_pin_name;
	use type_map_of_nets;
	use m1_import.type_list_of_pins;
	use type_map_of_devices;

	use type_name_file_netlist;
	use type_universal_string;
	use type_name_file_skeleton_submodule;
	
	

	line_counter : natural := 0; -- the line number in the given kicad netlist file






-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := import_cad;

	-- create message/log file	
	format_cad := kicad;
	write_log_header(version);
	
	put_line(to_upper(name_module_cad_importer_kicad) & " version " & version);
	put_line("======================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages
	
	prog_position	:= 10;
	name_file_cad_netlist:= to_bounded_string(argument(1));
	
	write_message (
		file_handle => file_import_cad_messages,
		text => "netlist " & to_string(name_file_cad_netlist),
		console => true);

	prog_position	:= 20;		
	cad_import_target_module := type_cad_import_target_module'value(argument(2));
	write_message (
		file_handle => file_import_cad_messages,
		text => "target module " & type_cad_import_target_module'image(cad_import_target_module),
		console => true);
	
	prog_position	:= 30;
	if cad_import_target_module = m1_import.sub then
		target_module_prefix := to_bounded_string(argument(3));

		write_message (
			file_handle => file_import_cad_messages,
			text => "prefix " & to_string(target_module_prefix),
			console => true);
		
		name_file_skeleton_submodule := to_bounded_string(compose( name => 
			base_name(name_file_skeleton) & "_" & 
			to_string(target_module_prefix),
			extension => file_extension_text));
	end if;
	
	prog_position	:= 50;	
	--read_netlist;

	--sort_netlist;
	--make_map_of_devices;

	--write_skeleton (name_module_cad_importer_zuken, version);

	prog_position	:= 100;
	write_log_footer;	
	
	exception when event: others =>
		set_exit_status(failure);

		write_message (
			file_handle => file_import_cad_messages,
			text => message_error & "at program position " & natural'image(prog_position),
			console => true);
	
		if is_open(file_skeleton) then
			close(file_skeleton);
		end if;

		if is_open(file_cad_netlist) then
			close(file_cad_netlist);
		end if;

		case prog_position is
			when others =>
				write_message (
					file_handle => file_import_cad_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_import_cad_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;


end impkicad;
