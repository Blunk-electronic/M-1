------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKNETS                              --
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

with ada.text_io;				use ada.text_io;
with ada.characters.handling;   use ada.characters.handling;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.strings; 				use ada.strings;
with ada.strings.maps;			use ada.strings.maps;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
with ada.containers;			use ada.containers;
with ada.containers.doubly_linked_lists;

with gnat.os_lib;   			use gnat.os_lib;
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_internal; 				use m1_internal;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;


procedure mknets is

	version			: constant string (1..3) := "044";
	udb_summary		: type_udb_summary;
	prog_position	: natural := 0;

	type type_skeleton_pin is
		record
			device_name			: universal_string_type.bounded_string;
			device_class		: type_device_class := '?'; -- default is an unknown device
			device_value		: universal_string_type.bounded_string;
			device_package		: universal_string_type.bounded_string;
			device_pin_name		: universal_string_type.bounded_string;
		end record;
	package pin_container is new doubly_linked_lists(element_type => type_skeleton_pin);
	use pin_container;
	
	type type_skeleton_net is
		record
			name			: universal_string_type.bounded_string;
			--class			: type_net_class;
			--pin_count		: positive;
			pin_list		: pin_container.list;
			pin_cursor		: pin_container.cursor;
		end record;
	package net_container is new doubly_linked_lists(element_type => type_skeleton_net);
	use net_container;
	netlist : net_container.list;
	net_cursor : net_container.cursor;
	

	procedure read_skeleton is
		line_of_file 			: extended_string.bounded_string;
		line_counter			: natural := 0;
		section_netlist_entered	: boolean := false;
		subsection_net_entered	: boolean := false;
		pin_scratch				: type_skeleton_pin;
		net_scratch				: type_skeleton_net;
	begin
		put_line("reading skeleton ...");
		open(file => file_skeleton, name => name_file_skeleton_default, mode => in_file);
		set_input(file_skeleton);
		while not end_of_file
		loop
			prog_position := 1000;
			line_counter := line_counter + 1;
			line_of_file := extended_string.to_bounded_string(get_line);
			line_of_file := remove_comment_from_line(line_of_file);

			if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything
				if not section_netlist_entered then
					if get_field_from_line(line_of_file,1) = section_mark.section then
						if get_field_from_line(line_of_file,2) = text_skeleton_section_netlist then
							section_netlist_entered := true;
						end if;
					end if;
				else
					if get_field_from_line(line_of_file,1) = section_mark.endsection then
						section_netlist_entered := false;
					else
						-- process net content

						-- The net header starts with "SubSection". The 3rd field must read "class".
						if get_field_from_line(line_of_file,1) = section_mark.subsection then
							-- save net name
							net_scratch.name := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,1));

							-- check for keyword "class"
							if get_field_from_line(line_of_file,3) = text_udb_class then
								put_line(extended_string.to_string(line_of_file));
							else
								put_line(message_error & "missing keyword " & text_udb_class);
								raise constraint_error;
							end if;

							-- check for default class 
							if get_field_from_line(line_of_file,4) = type_net_class'image(NA) then
								--net_scratch.class := NA;
								null;
							else
								put_line(message_error & "expecting default net class" & type_net_class'image(NA));
								raise constraint_error;
							end if;
						end if;
					end if;
				end if;

			end if;
		end loop;
	end read_skeleton;
	






-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin

	new_line;
	put_line("NET MAKER VERSION "& version);
	put_line("===============================");
	prog_position	:= 10;
 	name_file_data_base:= universal_string_type.to_bounded_string(argument(1));
 	put_line("data base      : " & universal_string_type.to_string(name_file_data_base));

	prog_position	:= 30;
	create_temp_directory;
	prog_position	:= 40;
	create_bak_directory;

	-- create premilinary data base (contining scanpath_configuration and registers)
	prog_position	:= 60;
	extract_section( 
		input_file => universal_string_type.to_string(name_file_data_base),
		output_file => name_file_data_base_preliminary,
		section_begin_1 => section_mark.section,
		section_end_1 => section_mark.endsection,
		section_begin_2 => section_scanpath_configuration
		);
	prog_position	:= 70;
	extract_section( 
		input_file => universal_string_type.to_string(name_file_data_base),
		output_file => name_file_data_base_preliminary,
		append => true,
		section_begin_1 => section_mark.section,
		section_end_1 => section_mark.endsection,
		section_begin_2 => section_registers
		);

	-- read premilinary data base
	prog_position	:= 80;
	udb_summary := read_uut_data_base(name_file_data_base_preliminary);
	put_line (" number of BICs" & natural'image(udb_summary.bic_ct));

	-- read skeleton
 	prog_position := 90;
	read_skeleton;

	-- open premilinary data base again and start writing bsld information
	prog_position	:= 100;
	open( 
		file => file_data_base_preliminary,
		mode => append_file,
		name => name_file_data_base_preliminary
		);

	-- write netlist in data base	
	prog_position	:= 110;
	set_output(file_data_base_preliminary);
	new_line;
	put_line (section_mark.section & row_separator_0 & section_netlist);
	put_line (column_separator_0);
	put_line ("-- created by " & name_module_mknets & " version " & version);
	put_line ("-- date " & date_now); 
	new_line;
	--write_netlist;
	put_line (section_mark.endsection);
	new_line (file_data_base_preliminary);
	prog_position := 200;
	close(file_data_base_preliminary);
	copy_file(name_file_data_base_preliminary, universal_string_type.to_string(name_file_data_base));

	exception
		when event: others =>
			set_output(standard_output);
			set_exit_status(failure);
			case prog_position is
-- 				when 10 =>
-- 					put_line("ERROR: Data base file missing or insufficient access rights !");
-- 					put_line("       Provide data base name as argument. Example: mkinfra my_uut.udb");
-- 				when 20 =>
-- 					put_line("ERROR: Test name missing !");
-- 					put_line("       Provide test name as argument ! Example: mkinfra my_uut.udb my_infrastructure_test");
-- 				when 30 =>
-- 					put_line("ERROR: Invalid argument for debug level. Debug level must be provided as natural number !");

				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & natural'image(prog_position));
			end case;
	
end mknets;
