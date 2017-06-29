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

	line_counter : natural := 0; -- the line number in the given kicad netlist file

	procedure read_netlist is
	-- Reads the given netlist file.

		-- Round brackets are used throuhout the netlist in order to nest
		-- sections:
		ob : constant character := '(';
		cb : constant character := ')';

		-- Here we define the set of characters that terminate a command or an argument.
		--char_seq : constant string (1..4) := latin_1.space & latin_1.ht & latin_1.lf & ')'; -- no need any more
		-- When a line has been fetched from file the horizontal tabs are replaced by space.
		-- Line-feeds are already removed by get_line. So we have to watch out for
		-- characters space and ')'.
		term_char_seq : constant string (1..2) := latin_1.space & ')';
		term_char_set : character_set := to_set(term_char_seq);

		line : unbounded_string; -- the line being processed
		cursor : natural; -- the position of the cursor

		-- instantiate the command stack. 
		-- We assume there is no deeper hierarchy than 20 currently. CS: increase if necessary.
		package command_stack is new stack_lifo(max => 20, item => unbounded_string);
        --use command_stack;

		procedure get_next_line is
		-- Fetches a new line. 
		-- Replaces all horizontal tabs by spaces.
		-- Increments line_counter.
		begin
			--new_line;
			line_counter := line_counter + 1;
			line := to_unbounded_string( translate(get_line,ht_to_space'access) );
			--put_line("line" & positive'image(line_counter) & "->" & to_string(line) & "<-");
		end get_next_line;
		
		procedure p1 is
		-- Updates the cursor position to the position of the next
		-- non_space character starting from the current cursor position.
		-- Fetches a new line if no further characters after current cursor position.
		begin
			cursor := index_non_blank(source => line, from => cursor + 1);
			while cursor = 0 loop
				get_next_line;
				cursor := index_non_blank(source => line, from => cursor + 1);
			end loop;
			--put_line("cursor at pos of next char" & natural'image(cursor));	
		end p1;

		cmd_prefix : constant string (1..4) := "cmd_";
		type type_command is (
			cmd_export,
			cmd_version,
			cmd_design,		
			cmd_source,
			cmd_date,
			cmd_tool,
			cmd_sheet,
			cmd_number,
			cmd_name,
			cmd_tstamps,
			cmd_title_block,
			cmd_title,
			cmd_company,
			cmd_rev,
			cmd_comment,
			cmd_value,
			cmd_components,
			cmd_comp,
			cmd_ref,
			cmd_footprint,
			cmd_libsource,
			cmd_sheetpath,
			cmd_tstamp
			-- CS: others
			);

		entered_export, 
		entered_version,
-- 		entered_design,		-- not used
-- 		entered_source,		-- not used
-- 		entered_date,		-- not used
-- 		entered_tool,		-- not used
-- 		entered_sheet,		-- not used
-- 		entered_number,		-- not used
-- 		entered_name,		-- not used
-- 		entered_tstamps,	-- not used
-- 		entered_title_block,-- not used
-- 		entered_title,		-- not used
-- 		entered_company,	-- not used
-- 		entered_rev,		-- not used
-- 		entered_comment,	-- not used
-- 		entered_value,		-- not used
		entered_components,	-- not used
		entered_comp,		-- not used
		entered_ref,		-- not used
		entered_value,		-- not used
		entered_footprint	-- not used
-- 		entered_libsource,	-- not used
--		entered_sheetpath,	-- not used
--		entered_tstamp,		-- not used
					: boolean := false;

--		section_components_entered : boolean := false;

		cmd : unbounded_string;
		arg : unbounded_string; -- here the argument goes finally

		procedure verify_cmd ( cmd : in unbounded_string) is
			depth : natural := command_stack.depth;

			procedure error_on_invalid_level is
			begin
				put_line(message_error & "line" 
					& positive'image(line_counter) & " : "
					& "keyword '"
					& to_string(cmd) & "'"
					& " not allowed in this level");
				raise constraint_error;
			end error_on_invalid_level;

		begin -- verify_cmd
			case type_command'value(cmd_prefix & to_string(cmd)) is

				when cmd_export => 
					if depth = 1 then
						entered_export := true;
					else
						error_on_invalid_level;
					end if;

				when cmd_version =>
					if depth = 2 then
						entered_version := true;
					else
						error_on_invalid_level;
					end if;

				when cmd_components =>
					if depth = 2 then
						entered_components := true;
						put_line("section components entered");
					else
						error_on_invalid_level;
					end if;
					
				when others => null;

			end case;
		end verify_cmd;


		procedure read_cmd is 
		-- Reads the command from current cursor position until termination
		-- character or its last character.
		-- Stores the command on command_stack.
			end_of_cmd : integer;  -- may become negative if no terminating character present
			--cmd : unbounded_string; -- here the command goes finally
		begin
			--put_line("cmd start at: " & natural'image(cursor));

			-- get position of last character
			end_of_cmd := index(source => line, from => cursor, set => term_char_set) -1;

			-- if no terminating character found, end_of_cmd assumes length of line
			if end_of_cmd = -1 then
				end_of_cmd := length(line);
			end if;

			--put_line("cmd end at  : " & positive'image(end_of_cmd));

			-- compose command from cursor..end_of_cmd
			cmd := to_unbounded_string( slice(line,cursor,end_of_cmd) );

			-- update cursor
			cursor := end_of_cmd;

			command_stack.push(cmd);

			verify_cmd(cmd);
			--set_section_flag(cmd);

			put_line(" level" & natural'image(command_stack.depth) 
				& " : cmd " & to_string(cmd));

			exception
				when constraint_error =>
					put_line(message_error & "line" 
						& positive'image(line_counter) & " : "
						& "invalid keyword '"
						& to_string(cmd) & "'");
					raise;
		end read_cmd;

		procedure read_arg is
		-- Reads the argument of a command.
		-- Mostly the argument is separated from the command by space.
		-- Some arguments are wrapped in quotations.
		-- Leaves the cursor at the position of the last character of the argument.
		-- If the argument was enclosed in quotations the cursor is left with
		-- the position of the trailing quotation.
			end_of_arg : integer; -- may become negative if no terminating character present
-- 			arg : unbounded_string; -- here the argument goes finally
		begin
			--put_line("arg start at: " & natural'image(cursor));

			-- We handle an argument that is wrapped in quotation different than
			-- a non-wrapped argument:
			if element(line, cursor) = latin_1.quotation then
				-- Read the quotation-wrapped argument (strip quotations)

				-- get position of last character (before trailing quotation)
				end_of_arg := index(source => line, from => cursor+1, pattern => 1 * latin_1.quotation) -1;

				--put_line("arg end at  : " & positive'image(end_of_arg));

				-- if no trailing quotation found -> error
				if end_of_arg = -1 then
					put_line(message_error & "line" 
						& positive'image(line_counter) & " : "
						& latin_1.quotation & " expected");
						raise constraint_error;
				end if;

				-- compose argument from first character after quotation until end_of_arg
				arg := to_unbounded_string( slice(line,cursor+1,end_of_arg) );

				-- update cursor (to position of trailing quotation)
				cursor := end_of_arg+1;
			else
				-- Read the argument from current cursor position until termination
				-- character or its last character.

				-- get position of last character
				end_of_arg := index(source => line, from => cursor, set => term_char_set) -1;

				-- if no terminating character found, end_of_arg assumes length of line
				if end_of_arg = -1 then
					end_of_arg := length(line);
				end if;

				--put_line("arg end at  : " & positive'image(end_of_arg));

				-- compose argument from cursor..end_of_arg
				arg := to_unbounded_string( slice(line,cursor,end_of_arg) );

				-- update cursor
				cursor := end_of_arg;
			end if;

			put_line("  arg " & to_string(arg));


			-- CS: verify arg -- remove from flow-chart ?
			-- CS: apply cmd + arg -- remove from flow-chart ?
		end read_arg;

		procedure exec_cmd is
-- 			cmd : unbounded_string;
		begin
			if entered_version then
				put_line("section version: " & to_string(cmd) & " " & to_string(arg));
				entered_version := false;
			end if;

			if entered_components then
				put_line("section components left");
				entered_components := false;
			end if;

			
			-- restore parent command from stack
			cmd := command_stack.pop;
		end exec_cmd;
			
	begin -- read_netlist
		write_message (
			file_handle => file_import_cad_messages,
			text => "reading kicad netlist file ...",
			console => true);

		open (file => file_cad_netlist, mode => in_file, name => to_string(name_file_cad_netlist));
		set_input(file_cad_netlist);

		command_stack.init;
		get_next_line;
		cursor := index(source => line, pattern => 1 * ob);
		
		while not end_of_file loop
			
			<<label_1>>
				p1; -- cursor at pos of next char
				read_cmd; -- cursor at end of cmd
				p1; -- cursor at pos of next char
				if element(line, cursor) = ob then goto label_1; end if;
			<<label_3>>
				read_arg;
				p1;
				if element(line, cursor) /= cb then
					put_line(message_error & "line" 
						& positive'image(line_counter) & " : "
						& cb & " expected");
					raise constraint_error;
				end if;
			<<label_2>>
				exec_cmd;
				if command_stack.depth = 0 then exit; end if;
				p1;

				-- Test for cb, ob or other character:
				case element(line, cursor) is

					-- If closing bracket after argument. example: (libpart (lib conn) (part CONN_01X02)
					when cb => goto label_2;

					-- If another command at a deeper level follows. example: (lib conn)
					when ob => goto label_1;

					-- In case an argument not enclosed in brackets 
					-- follows a closing bracket. example: (field (name Reference) P)
					when others => goto label_3; 
-- 						put_line(message_error & "line" 
-- 							& positive'image(line_counter) & " : "
-- 							& cb & " or " & ob & " expected"); -- CS
-- 						raise constraint_error;
				end case;
		end loop;
		--new_line(standard_output); -- finishes the progress bar
		put_line("done");

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
