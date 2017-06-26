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
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings.maps;			use ada.strings.maps;
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
	
-- 	type type_keyword is (
-- 		export,
	

	line_counter : natural := 0; -- the line number in the given kicad netlist file

	procedure read_netlist is
	-- Reads the given netlist file.

-- 		opening_bracket : constant string (1..1) := "("; --latin_1.left_parenthesis; -- '('
-- 		closing_bracket : constant string (1..1) := ")"; --latin_1.right_parenthesis; -- ')'

-- 		pos_obr, pos_cbr : natural; -- position of opening/closing bracket
-- 		pos_cursor : positive; 
-- 		pos_keyword_start, pos_keyword_end : positive := 1;
-- 		pos_arg_start, pos_arg_end : natural := 1;
-- 		--eol : boolean := false;
-- 		level : natural := 0;

-- 		procedure increment_level is begin level := level + 1; end increment_level;
-- 		procedure decrement_level is begin level := level - 1; end decrement_level;
-- 
-- 		procedure test_keyword (keyword : in string) is
-- 		begin
-- 			put_line(standard_output,"level" & natural'image(level) & " keyword " & keyword);
-- 			-- CS: do the test here
-- 		end test_keyword;
-- 
-- 		procedure test_argument (argument : in string) is
-- 		begin
-- 			put_line(standard_output,"level" & natural'image(level) & " argument " & argument);
-- 			-- CS: do the test here
-- 		end test_argument;

		
-- 		procedure process_line (line : in string) is
-- 		begin
-- 			put_line("line" & positive'image(line_counter) & ":" & line);
-- 			pos_cursor := 1; 
-- 			--while not eol loop
-- 			loop
-- 				-- RULE 1: AFTER AN OPENING BRACKET A KEYWORD FOLLOWS.
-- 
-- 				-- example: (export (version D)
-- 					
-- 				-- get pos of opening bracket after current cursor position:
-- 				pos_obr := index(source => line, pattern => opening_bracket, from => pos_cursor);
-- 
-- 				if pos_obr /= 0 then -- if there is an opening bracket. read follwing keyword:
-- 
-- 					-- RULE 2: AN OPENING BRACKET INCREASES THE HIERARCHY LEVEL BY ONE.
-- 					increment_level;
-- 
-- 					-- get start pos of keyword after opening bracket
-- 					pos_keyword_start := index_non_blank(source => line, from => pos_obr + 1);
-- 					--put_line(standard_output, positive'image(pos_keyword_start));
-- 
-- 					-- get end pos of keyword
-- 					pos_keyword_end := index(source => line, from => pos_keyword_start, set => char_set) -1;
-- 					--put_line(standard_output, positive'image(pos_keyword_end));
-- 
-- 					-- test keyword
-- 					test_keyword(keyword => (line(pos_keyword_start..pos_keyword_end)) );
-- 
-- 					-- RULE 3: AFTER A KEYWORD WE EXPECT AN ARGUMENT.
-- 					-- The argument may start:
-- 					--  - with an opening bracket (to indicate another underlying level).
-- 					--  - with other character (if it is a single argument)
-- 					
-- 					-- read argument
-- 					pos_arg_start := index_non_blank(source => line, from => pos_keyword_end + 1);
-- 					
-- 					if pos_arg_start /= 0 then -- there is an argument
-- 						if line(pos_arg_start) = opening_bracket(1) then
-- 							increment_level;
-- 						
-- 							-- expect keyword
-- 
-- 							-- update cursor pos.
-- 							pos_cursor := pos_arg_start;
-- 
-- 						else
-- 							-- We have a single argument. It ends in a character defined by char_set.
-- 							pos_arg_end := index(source => line, from => pos_arg_start, set => char_set) -1;
-- 							test_argument(argument => (line(pos_arg_start..pos_arg_end)) );
-- 							
-- 							-- update cursor pos.
-- 							pos_cursor := pos_arg_end;
-- 						end if;
-- 							
-- 					else -- no argument provided after keyword -> abort processing the line
-- 						exit;
-- 					end if;
-- 					
-- 				end if;
-- 
-- 				-- exit if end of line reached
-- 				if pos_cursor = line'last then
-- 					exit;
-- 				end if;
-- 				
-- 			end loop;
-- 			
-- 		end process_line;
		
		char_seq : constant string (1..4) := latin_1.space & latin_1.ht & latin_1.lf & ')';
		char_set : character_set := to_set(char_seq);

		line : unbounded_string;
		cursor : natural;

		--ht_to_space : character_mapping := to_mapping(from => "a", to => "B");
		
		procedure get_next_line is
		begin
			new_line;
			line_counter := line_counter + 1;
			--line := to_unbounded_string(trim(get_line,both));
			--line := to_unbounded_string( trim( translate(get_line,ht_to_space'access),both) );
			line := to_unbounded_string( translate(get_line,ht_to_space'access) );
			put_line("line" & positive'image(line_counter) & "->" & to_string(line) & "<-");
		end get_next_line;
		
		procedure p1 is
		begin
			cursor := index_non_blank(source => line, from => cursor + 1);
			while cursor = 0 loop
				get_next_line;
				cursor := index_non_blank(source => line, from => cursor + 1);
			end loop;
			--put_line("cursor at pos of next char" & natural'image(cursor));	
		end p1;

		procedure read_cmd is
			end_of_cmd : positive := index(source => line, from => cursor, set => char_set) -1;
			length_of_cmd : positive := end_of_cmd - cursor + 1;
			cmd : string (1..length_of_cmd) := slice(line,cursor,end_of_cmd);
		begin
			cursor := end_of_cmd;
			put_line("cmd " & cmd);
			-- CS: verify cmd
			-- CS: push cmd
		end read_cmd;

		procedure read_arg is
			end_of_arg : positive := index(source => line, from => cursor, set => char_set) -1;
			length_of_arg : positive := end_of_arg - cursor + 1;
			cmd : string (1..length_of_arg) := slice(line,cursor,end_of_arg);
		begin
			cursor := end_of_arg;
			put_line("arg " & cmd);
			-- CS: verify arg
			-- CS: apply cmd + arg
		end read_arg;

		procedure exec_cmd is
		begin
			null;
		end exec_cmd;
	
		
		
		ob : constant character := '(';
		cb : constant character := ')';
		
	begin -- read_netlist
		write_message (
			file_handle => file_import_cad_messages,
			text => "reading kicad netlist file ...",
			console => true);

		open (file => file_cad_netlist, mode => in_file, name => to_string(name_file_cad_netlist));
		set_input(file_cad_netlist);

		get_next_line;
		cursor := index(source => line, pattern => 1 * ob);
		
		while not end_of_file loop
			
			-- progrss bar
-- 			if (line_counter rem 200) = 0 then
-- 				put(standard_output,'.');
-- 			end if;

--			process_line(get_line);

			
			<<label_1>>
				p1; -- cursor at pos of next char
				read_cmd; -- cursor at end of cmd
				p1; -- cursor at pos of next char
				if element(line, cursor) = ob then goto label_1; end if;
				read_arg;
				p1;
				if element(line, cursor) /= cb then
					put_line(message_error & cb & " expected");
					raise constraint_error;
				end if;
			<<label_2>>
				exec_cmd;
				-- CS: if level = 0 then end
				p1;
				case element(line, cursor) is
					when cb => goto label_2;
					when ob => goto label_1;
					when others =>
						put_line(message_error & cb & " or " & ob & " expected"); -- CS
						raise constraint_error;
				end case;
		end loop;
		--new_line(standard_output); -- finishes the progress bar

	end read_netlist;





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
	read_netlist;

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
