------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE IMPZUKEN                            --
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


procedure impzuken is

	version			: constant string (1..3) := "003";
    prog_position	: natural := 0;

	use type_net_name;
	use type_device_name;
	use type_device_value;
	use type_package_name;
	use type_pin_name;
	
	use type_name_file_netlist;
	use type_universal_string;
	use type_name_file_skeleton_submodule;
	
	type type_line_of_netlist is record		
		net			: type_net_name.bounded_string;
		device		: type_device_name.bounded_string;
		value		: type_device_value.bounded_string;
		packge 		: type_package_name.bounded_string;
		pin  		: type_pin_name.bounded_string;
		-- CS: other elements ?
	--	processed	: Boolean := false;
	end record;

	package type_netlist is new vectors ( 
		element_type => type_line_of_netlist,
		index_type => positive);
	use type_netlist;
	netlist : type_netlist.vector;




-- 	function make_netlist_array
-- 		(
-- 		line_ct	: natural
-- 		) return natural is
-- 		
-- 		char_current	: character := ' ';
-- 		netlist_array	: netlist_array_type (Natural range 1..line_ct);
-- 		end_marker		: constant character := ';';
-- 		entries_counter : natural := 0;
-- 		scratch			: unbounded_string;
-- 		ct				: natural := 1;
-- 		net_ct			: natural := 0;
-- 
-- 		begin
-- 
-- 			while not end_of_file
-- 				loop
-- 					get(char_current);
-- 					case char_current is
-- 
-- 						when end_marker => 
-- 							entries_counter := entries_counter + 1;
-- 							line := line & Character'Val(10);
-- 							--put_line(line);
-- 
-- 							netlist_array(entries_counter).net := to_unbounded_string(replace_char(trim(replace_char(get_field(line,1,':'),'"',' '), side => both),' ','_'));
-- 							--put_line(netlist_array(entries_counter).net);
-- 
-- 							-- extract package field, replace '"' by ' ', trim sides, replace ' ' by '_'
-- 							netlist_array(entries_counter).packge := to_unbounded_string(replace_char(trim(replace_char(get_field(line,4,':'),'"',' '), side => both),' ','_'));
-- 							if netlist_array(entries_counter).packge = to_unbounded_string("") then netlist_array(entries_counter).packge := to_unbounded_string("package_unknown"); end if; 
-- 							--put_line(netlist_array(entries_counter).packge);
-- 
-- 							-- extract value field, replace '"' by ' ', trim sides, replace ' ' by '_'
-- 							netlist_array(entries_counter).value := to_unbounded_string(replace_char(trim(replace_char(get_field(line,3,':'),'"',' '), side => both),' ','_'));
-- 							--put_line(netlist_array(entries_counter).value);
-- 
-- 							-- extract device field, replace '"' by ' ', trim sides, replace ' ' by '_'
-- 							netlist_array(entries_counter).device := to_unbounded_string(replace_char(trim(replace_char(get_field(line,5,':'),'"',' '), side => both),' ','_'));
-- 							--put_line(netlist_array(entries_counter).device);
-- 
-- 							-- extract pin field, replace '"' by ' ', trim sides, replace ' ' by '_'
-- 							netlist_array(entries_counter).pin := to_unbounded_string(replace_char(trim(replace_char(get_field(line,6,':'),'"',' '), side => both),' ','_'));
-- 							--put_line(netlist_array(entries_counter).pin);
--  							
-- 							--new_line;
-- 							line := to_unbounded_string(""); -- clear line buffer
-- 							--netlist_array(entries_counter).processed := true;
-- 
-- 						when others => -- file line buffer char by char
-- 							line := line & char_current;
-- 					end case;
-- 
-- 
-- 					--pointer:=pointer+1;
-- 					--put_line(get_field(line,2,' '));
-- 					
-- 				end loop;
-- --		put_line(natural'image(entries_counter));
-- 
-- 		new_line;
-- 		put_line("Section netlist_skeleton");
-- 
-- 		-- make skeleton netlist from netlist_array
-- 		entries_counter := 1;
-- 		while entries_counter <= line_ct 
-- 			loop
-- 				if netlist_array(entries_counter).processed = false then -- care for unprocessed entries only
-- 					net_ct := net_ct + 1;
-- 					new_line;
-- 					put_line(" SubSection " & netlist_array(entries_counter).net & " class NA"); -- write net section header
-- 					put_line("  " & netlist_array(entries_counter).device & " ? " & netlist_array(entries_counter).value & " " & netlist_array(entries_counter).packge & " " & netlist_array(entries_counter).pin);
-- 					netlist_array(entries_counter).processed := true; -- mark entry as processed
-- 
-- 					-- search for entries having the same net name
-- 					ct := 1;
-- 					while ct <= line_ct  
-- 						loop
-- 							if netlist_array(ct).processed = false then -- care for unprocessed entries only
-- 								if netlist_array(ct).net = netlist_array(entries_counter).net then -- on net name match write dev, val, pack, pin in tmp/nets.tmp
-- 									put_line("  " & netlist_array(ct).device & " ? " & netlist_array(ct).value & " " & netlist_array(ct).packge & " " & netlist_array(ct).pin);
-- 									netlist_array(ct).processed := true; -- mark entry as processed
-- 								end if;
-- 							end if;
-- 							ct := ct + 1; -- advance entry pointer
-- 						end loop;
-- 					put_line(" EndSubSection"); -- close net section
-- 				end if;
-- 			
-- 				entries_counter := entries_counter + 1;	-- advance entry pointer
-- 			
-- 			end loop;
-- 		put_line("EndSection"); -- close netlist skeleton
-- 
-- 		return net_ct;
-- 	end make_netlist_array;
-- 


	line_counter : natural := 0;

	maximum_field_count_per_line : constant count_type := 10;

	procedure read_netlist is
	-- Reads the given netlist and stores it in a vector list named "netlist".
		line : type_fields_of_line;
		line_bak : type_fields_of_line;
		complete : boolean := true;
			
	begin
		write_message (
			file_handle => file_import_cad_messages,
			text => "reading netlist file ...",
			console => true);

		open (file => file_cad_netlist, mode => in_file, name => to_string(name_file_cad_netlist));
		set_input(file_cad_netlist);

		put_line("NOTE: The line number indicates the line in the given netlist where the last property of a pin has been found in.");
		while not end_of_file loop
			line_counter := line_counter + 1;
			line := read_line(get_line, latin_1.colon);
			case line.field_count is
				when 0 => null; -- empty line. nothing to do
				when maximum_field_count_per_line => -- Line complete. Alle fields can be appended to netlist right away.
					
					append(netlist, ( 
						net => 		to_bounded_string(strip_quotes(trim(get_field_from_line(line, 1),both))),
						value =>	to_bounded_string(strip_quotes(trim(get_field_from_line(line, 3),both))),
						packge =>	to_bounded_string(strip_quotes(trim(get_field_from_line(line, 4),both))),
						device =>	to_bounded_string(strip_quotes(trim(get_field_from_line(line, 5),both))),
						pin =>		to_bounded_string(strip_quotes(trim(get_field_from_line(line, 6),both)))
						));

				when 1..9 => -- An incomplete line has been found and must be stored in line_bak.
					-- The next line is expected to contain the remaining fields and is read in the next spin.

					if complete then
						line_bak := line;
						complete := false;

					else
						line := append(line_bak,line); 
						-- Now, line contains the complete line and should have maximum_field_count_per_line.
						-- If the two fragments have more than maximum_field_count_per_line the netlist file is
						-- considered as corrupted.
						if line.field_count = maximum_field_count_per_line then
							complete := true;

							-- Every complete line represents a pin:
							put_line(" line" & positive'image(line_counter) & " pin " & to_string(line));
							
							-- Append the complete line to the netlist:
							append(netlist, ( 
								net => 		to_bounded_string(strip_quotes(trim(get_field_from_line(line, 1),both))),
								value =>	to_bounded_string(strip_quotes(trim(get_field_from_line(line, 3),both))),
								packge =>	to_bounded_string(strip_quotes(trim(get_field_from_line(line, 4),both))),
								device =>	to_bounded_string(strip_quotes(trim(get_field_from_line(line, 5),both))),
								pin =>		to_bounded_string(strip_quotes(trim(get_field_from_line(line, 6),both)))
								));
						else
							line_bak := line;
						end if;
					end if;

				when others => -- If line contains more than maximum_field_count_per_line we have a corrupted netlist.
					write_message (
						file_handle => file_import_cad_messages,
						text => message_error & "too many fields in line " & natural'image(line_counter) & " !",
						console => true);
					raise constraint_error;
			end case;
		end loop;

		-- Finally the complete-flag must be found set.
		if not complete then
			write_message (
				file_handle => file_import_cad_messages,
				text => message_error & "too less fields in line" & natural'image(line_counter) & " !" 
					& " Netlist incomplete !",
				console => true);
			raise constraint_error;
		end if;

	end read_netlist;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin

	action := import_cad;

	-- create message/log file	
	format_cad := zuken;
	write_log_header(version);
	
	put_line(to_upper(name_module_cad_importer_zuken) & " version " & version);
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
	read_netlist;

--	write_skeleton;

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


end impzuken;
