-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 STRING PROCESSING                          --
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

with ada.strings;				use ada.strings;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;
with ada.text_io;				use ada.text_io;
-- with ada.float_text_io;			use ada.float_text_io;

-- with ada.containers;            use ada.containers;
-- with ada.containers.vectors;
-- with ada.containers.indefinite_vectors;
-- 
-- with interfaces;				use interfaces;
-- with ada.exceptions;

-- with ada.calendar;				use ada.calendar;
-- with ada.calendar.formatting;	use ada.calendar.formatting;
-- with ada.calendar.time_zones;	use ada.calendar.time_zones;

with m1_base;					use m1_base;
with m1_firmware; 				use m1_firmware;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories;	use m1_files_and_directories;
with m1_import;					use m1_import;
with m1_test_gen_and_exec;		use m1_test_gen_and_exec;

package body m1_string_processing is

	function wildcard_match (text_with_wildcards : in string; text_exact : in string) return boolean is
	-- Returns true if text_with_wildcards matches text_exact.
	-- text_with_wildcards is something like R41* , text_exact is something like R415
		count_asterisk		: natural := ada.strings.fixed.count(text_with_wildcards, 1 * latin_1.asterisk);
		count_question_mark	: natural := ada.strings.fixed.count(text_with_wildcards, 1 * latin_1.question);
		pos_asterisk		: natural := ada.strings.fixed.index(text_with_wildcards, 1 * latin_1.asterisk); -- first asterisk
		pos_question_mark	: natural := ada.strings.fixed.index(text_with_wildcards, 1 * latin_1.question); -- first question mark
		
		length_text_with_wildcards	: natural := text_with_wildcards'length;
		length_text_exact			: natural := text_exact'length;		
		
		match				: boolean := false;
	begin
		-- CS: zero-string length causes a no-match
		if length_text_exact = 0 or length_text_with_wildcards = 0 then
			return false;
		end if;
		
		-- CS: currently a question mark results in a no-match
		if count_question_mark > 0 then
			return false;
		end if;
		
		case count_asterisk is
			-- If no asterisks, texts must be equal in order to return a match:
			when 0 =>
				if length_text_exact = length_text_with_wildcards then
					if text_exact = text_with_wildcards then
						match := true;
					end if;
				end if;

			-- If one asterisk, compare left hand side of text_with_wildcards and text_exact:
			when 1 =>
				-- If text_exact is shorter than text_with_wildcards then we have no match.
				-- Example 1: text_exact is R41 and text_with_wildcards is R415*
				-- Example 2: text_exact is R41 and text_with_wildcards is R41*
				if length_text_exact < length_text_with_wildcards then
					match := false;
				elsif
				-- If text_exact and text_with_wildcards match from first character to pos_asterisk-1 we have a match.
				-- Example 1: text_exact is R415 and text_with_wildcards is R4*
					text_with_wildcards(text_with_wildcards'first .. text_with_wildcards'first - 1 + pos_asterisk - 1) = 
					text_exact         (text_exact'first          .. text_exact'first          - 1 + pos_asterisk - 1) then
					match := true;
-- 					put_line(standard_output,"match");
				end if;

			-- CS: currently more than one asterisk results in a no-match
			when others =>
				match := false;
		end case;
		
		return match;
	end wildcard_match;
	

	function remove_comment_from_line(text_in : string) return string is
		position_of_comment : natural;
		-- NOTE: tabulators will be left unchanged. no substituion with whitespace is done !
	begin
		if text_in'length > 0 then -- if line contains something
			position_of_comment := index(text_in,"--");
			case position_of_comment is -- check position of comment
				when 0 => -- no comment found -> return line as it is
					return text_in;
				when 1 => return ""; -- comment at beginning of line -> do nothing
				when others => -- comment somewhere in the line -> delete comment
					--put_line("comment at pos :" & natural'image(position_of_comment));
					return delete(text_in, position_of_comment, text_in'length); -- remove comment
			end case;
		end if;
		return "";
	end remove_comment_from_line;

	function get_field_count (text_in : string) return natural is
		line_length	:	Natural := text_in'last;	-- length of given text
		char_pt		:	Natural := 1;				-- charcter pointer (points to character being processed inside the given line)
		IFS1		: 	constant Character := ' '; 				-- field separator space
		IFS2		: 	constant Character := Character'Val(9); -- field separator tabulator
		field_ct	:	Natural := 0;				-- field counter (the first field found gets number 1 assigned)
		field_pt	:	Natural := 1;				-- field pointer (points to the charcter being processed inside the current field)
		inside_field:	Boolean := true;			-- true if char_pt points inside a field
		char_current:	Character;					-- holds current character being processed
		char_last	:	Character := ' ';			-- holds character processed previous to char_current
	begin
		while char_pt <= line_length
			loop
				--put (char_pt);
				char_current:= text_in(char_pt); 
				if char_current = IFS1 or char_current = IFS2 then
					inside_field := false;
				else
					inside_field := true;
				end if;

				-- count fields if character other than IFS found
				if ((char_last = IFS1 or char_last = IFS2) and (char_current /= IFS1 and char_current /= IFS2)) then
					field_ct:=field_ct+1;
				end if;

				-- save last character
				char_last:=char_current;
				-- advance character pointer by one
				char_pt:=char_pt+1; 
				--put (char_current); put (" --"); new_line;
			end loop;
		return field_ct;
	end get_field_count;


-- 	function get_field_from_line (
-- 		text_in 	: in string;
-- 		position 	: in positive;
-- 		ifs 		: in character := latin_1.space
-- 		) return string is
-- 		
-- 		use type_long_string;
-- 		value		:	type_long_string.bounded_string;	-- field content to return (NOTE: Value gets converted to string on return)
-- 		line_length	:	natural :=	text_in'length;	-- length of given line
-- 		char_pt		:	positive := 1;				-- charcter pointer (points to character being processed inside the given line)
-- 		ifs1		: 	character; 					-- field separator space
-- 		ifs2		: 	character; 					-- field separator tabulator
-- 		field_ct	:	natural := 0;				-- field counter (the first field found gets number 1 assigned)
-- 		field_pt	:	natural := 1;				-- field pointer (points to the charcter being processed inside the current field)
-- 		inside_field:	boolean := true;			-- true if char_pt points inside a field
-- 		char_current:	character;					-- holds current character being processed
-- 		char_last	:	character := ifs;			-- holds character processed previous to char_current
-- 	begin
-- 		if ifs = ' ' then
-- 			ifs1 := ifs;
-- 			ifs2 := character'Val(9); -- tabulator
-- 			char_last := ' ';
-- 		else
-- 			ifs1 := ifs;
-- 			ifs2 := ifs;
-- 			char_last := ifs;
-- 		end if;
-- 		while char_pt <= line_length
-- 			loop
-- 				char_current := text_in(char_pt); 
-- 				if char_current = IFS1 or char_current = IFS2 then
-- 					inside_field := false;
-- 				else
-- 					inside_field := true;
-- 				end if;
-- 	
-- 				count fields if character other than IFS found
-- 				if ((char_last = IFS1 or char_last = IFS2) and (char_current /= IFS1 and char_current /= IFS2)) then
-- 					field_ct:=field_ct+1;
-- 				end if;
-- 				if (position = field_ct) then
-- 					if (inside_field = true) then -- if field entered
-- 						skip LF -- CS: skip other control characters ?
-- 						if char_current /= character'val(10) then 
-- 							value := value & char_current; 
-- 						end if;
-- 						
-- 						field_pt:=field_pt+1;
-- 					end if;
-- 				end if;
-- 
-- 				if (field_ct > position) then return to_string(value); end if;
-- 							
-- 				save last character
-- 				char_last:=char_current;
-- 
-- 				advance character pointer by one
-- 				char_pt:=char_pt+1; 
-- 
-- 				put (char_current); put (" --"); new_line;
-- 			end loop;
-- 		return to_string(value);
-- 	end get_field_from_line;

	function strip_quotes (text_in : in string) return string is
	-- removes heading and trailing quotation from given string		
	begin
		-- CS: do not strip anything if no quotes present
		-- if text_in(text_in'first) = latin_1.quote
		return text_in(text_in'first+1..text_in'last-1);
	end strip_quotes;

	function enclose_in_quotes (text_in : in string; quote : in character := latin_1.apostrophe) return string is
	-- Adds heading and trailing quotate to given string.
	begin
		return quote & text_in & quote;
	end enclose_in_quotes;

	function trim_space_in_string (text_in : in string) return string is
	-- shrinks successive space characters to a single one in given string		
		text_scratch : string (1..text_in'length) := text_in;
		
		use type_universal_string;
		s : type_universal_string.bounded_string; -- CS: might be not sufficient ! use type_long_string instead
		
		l : natural := text_scratch'length;
		sc : natural := natural'first;
	begin
		for c in 1..l loop
			case text_scratch(c) is
				when latin_1.space =>
					sc := sc + 1;
				when others =>
					if sc > 0 then
						s := append(left => s, right => latin_1.space);
					end if;
					s := append(left => s, right => text_scratch(c));
					sc := 0;
			end case;
		end loop;
		return to_string(s);
	end trim_space_in_string;

	function get_field_from_line( 
	-- Extracts a field separated by ifs at position. If trailer is true, the trailing content until trailer_to is also returned.
		text_in 	: in string;
		position 	: in positive;
		ifs 		: in character := latin_1.space;
		trailer 	: boolean := false;
		trailer_to 	: in character := latin_1.semicolon
		) return string is
		use type_extended_string;
		field			: type_extended_string.bounded_string;	-- field content to return (NOTE: gets converted to string on return) 
		character_count	: natural := text_in'length;	-- number of characters in given string
		subtype type_character_pointer is natural range 0..character_count;
		char_pt			: type_character_pointer;		-- points to character being processed inside the given string
		field_ct		: natural := 0;					-- field counter (the first field found gets number 1 assigned)
		inside_field	: boolean := true;				-- true if char_pt points inside a field
		char_current	: character;					-- holds current character being processed
		char_last		: character := ifs;				-- holds character processed previous to char_current
	begin -- get_field
		if character_count > 0 then
			char_pt := 1;
			for char_pt in 1..character_count loop
			--while char_pt <= character_count loop
				char_current := text_in(char_pt); 
				
-- 				if char_current = ifs then
-- 					inside_field := false;
-- 				else
-- 					inside_field := true;
-- 				end if;

				-- CS: if ifs is space and fields are separated by a single ht, they are currently
				-- not split up. fix it !
				

				-- if ifs is space, then horizontal tabs must be threated equally
				if ifs = latin_1.space then
					if char_current = ifs or char_current = latin_1.ht then
						inside_field := false;
					else
						inside_field := true;
					end if;

					-- count fields if ifs is followed by a non-ifs character
					if (char_last = ifs or char_last = latin_1.ht) and (char_current /= ifs and char_current /= latin_1.ht) then
						field_ct := field_ct + 1;
					end if;
				else
					if char_current = ifs then
						inside_field := false;
					else
						inside_field := true;
					end if;

					-- count fields if ifs is followed by a non-ifs character
					if (char_last = ifs and char_current /= ifs) then
						field_ct := field_ct + 1;
					end if;
				end if;
				

-- 				-- count fields if ifs is followed by a non-ifs character
-- 				if (char_last = ifs and char_current /= ifs) then
-- 					field_ct := field_ct + 1;
-- 				end if;

				case trailer is
					when false =>
						-- if targeted field reached
						if position = field_ct then
							if inside_field then -- if inside field
								field := field & char_current; -- append current character to field
								--field_pt := field_pt + 1;
							end if;
						else
							-- if next field reached, abort and return field content
							if field_ct > position then 
									exit;
							end if;
						end if;

					when true =>
						-- if targeted field reached or passed
						if position <= field_ct then
							if char_current = trailer_to then
								exit;
							else
								field := field & char_current; -- append current character to field
							end if;
						end if;
				end case;

				-- save last character
				char_last := char_current;
			end loop;
		else
			null;
		end if;
		return to_string(field);
	end get_field_from_line;

	-- CS: comments
	function read_line ( line : in string; ifs : in character := latin_1.space) return type_fields_of_line is
		list : type_list_of_strings.vector;
-- 		field_count : natural := ada.strings.fixed.count (line, ifs);

		procedure read_fields ( line : in string) is
			end_of_line : boolean := false;
			i : natural := 0;
		begin
-- 			put_line(line);
			while not end_of_line loop
				i := i + 1;
				if get_field_from_line(line, i, ifs)'last > 0 then
					type_list_of_strings.append(list, get_field_from_line(line, i, ifs));
				else
					end_of_line := true;
				end if;
			end loop;
		end read_fields;

	begin -- read_line
		read_fields(remove_comment_from_line(line));
		--1 + ada.strings.fixed.count(line,row_separator_1a);
-- 		type_list_of_strings.reserve_capacity(
-- 			list, 
-- 			count_type( ada.strings.fixed.count (line, ifs) ));
		
		return ( fields => list, field_count => type_list_of_strings.length(list));
	end read_line;

	function append (left : in type_fields_of_line; right : in type_fields_of_line) return type_fields_of_line is
		line : type_fields_of_line;
		use type_list_of_strings;
	begin
--		line.fields := fields);
--		line.field_count := 0;

		line.fields := left.fields & right.fields;
		line.field_count := left.field_count + right.field_count;
-- 		if right.field_count > 0 then
-- 			null;
-- 		end if;
		return line;
	end append;


	-- CS: comments
	function get_field_from_line (line : in type_fields_of_line; position : in positive) return string is
		use type_list_of_strings;
	begin
		if count_type(position) > line.field_count then
			return "";
		else
			return element(line.fields, positive(position));
		end if;
	end get_field_from_line;

	-- CS: comments	
	function to_string ( line : in type_fields_of_line) return string is
		s : unbounded_string;
		ifs : constant character := latin_1.space;
	begin
		if line.field_count > 0 then
			for i in 1..positive(line.field_count) loop
				case i is
					when 1 =>
						s := to_unbounded_string(trim(get_field_from_line(line, i),both));
					when others =>
						s := s & ifs & to_unbounded_string(trim(get_field_from_line(line, i),both));
				end case;
			end loop;
		end if;
		return to_string(s);
	end to_string;


-- MESSAGES

	procedure direct_messages is
	-- Sets the output channel to logfile accroding to action.
	begin
		-- direct messages according to action -- CS: add other actions
		case action is
			when import_cad =>
				set_output(file_import_cad_messages);
			when import_bsdl =>
				set_output(file_import_bsdl_messages);
			when join_netlist =>
				set_output(file_join_netlist_messages);
			when mknets =>
				set_output(file_mknets_messages);
			when mkoptions =>
				set_output(file_mkoptions_messages);
			when chkpsn =>
				set_output(file_chkpsn_messages);
			when udbinfo =>
				set_output(file_udbinfo_messages);

			when generate =>
				case test_profile is
					when infrastructure =>
						set_output(file_mkinfra_messages);
					when interconnect =>
						set_output(file_mkintercon_messages);
					when memconnect =>
                        set_output(file_mkmemcon_messages);
					when clock =>
						set_output(file_mkclock_messages);
					when toggle =>
						set_output(file_mktoggle_messages);
					when others => null;
				end case;
				
            when compile =>
				set_output(file_compiler_messages);
				
			when others =>
				set_output(standard_output);
		end case;
	end direct_messages;

	
	procedure write_log_header (module_version : in string) is
	-- Creates logfile according to current action.
	-- Writes header information in logfile and leaves it open.

		-- backup current output channel
		previous_output	: file_type renames current_output;

		procedure write (module : in string) is
		begin
			put_line(to_upper(module) & " version " & module_version & " LOGFILE");
			put_line("date " & date_now);
			put_line(column_separator_0);
		end write;

	begin -- write_log_header

		-- A newly created uut needs a directory for log messages.
		-- Create directory if not existing.
		if not exists (name_directory_messages) then 
			create_directory(name_directory_messages);
		end if;

		case action is
			when import_cad =>
				create(
					file => file_import_cad_messages,
					mode => out_file,
					name => name_file_import_cad_messages);
				set_output(file_import_cad_messages);
				
				case format_cad is
					when protel =>
						write(name_module_cad_importer_protel);
					when zuken =>
						write(name_module_cad_importer_zuken);
					when orcad =>
						write(name_module_cad_importer_orcad);
					when others => null; -- CS: add more importers here
				end case;

			when import_bsdl =>
				create(
					file => file_import_bsdl_messages,
					mode => out_file,
					name => name_file_import_bsdl_messages);
				set_output(file_import_bsdl_messages);
				write(name_module_importer_bsdl);

			when join_netlist =>
				create(
					file => file_join_netlist_messages,
					mode => out_file,
					name => name_file_join_netlist_messages);
				set_output(file_join_netlist_messages);
				write(name_module_join_netlist);
				
			when mknets =>
				create(
					file => file_mknets_messages,
					mode => out_file,
					name => name_file_mknets_messages);
				set_output(file_mknets_messages);
				write(name_module_mknets);

			when chkpsn =>
				create(
					file => file_chkpsn_messages,
					mode => out_file,
					name => name_file_chkpsn_messages);
				set_output(file_chkpsn_messages);
				write(name_module_chkpsn);

			when mkoptions =>
				create(
					file => file_mkoptions_messages,
					mode => out_file,
					name => name_file_mkoptions_messages);
				set_output(file_mkoptions_messages);
				write(name_module_mkoptions);

			when udbinfo =>
				create(
					file => file_udbinfo_messages,
					mode => out_file,
					name => name_file_udbinfo_messages);
				set_output(file_udbinfo_messages);
				write(name_module_database_query);

			when generate =>
				case test_profile is
					when infrastructure =>
						create(
							file => file_mkinfra_messages,
							mode => out_file,
							name => name_file_mkinfra_messages);
						set_output(file_mkinfra_messages);
						write(name_module_mkinfra);

					when interconnect =>
						create(
							file => file_mkintercon_messages,
							mode => out_file,
							name => name_file_mkintercon_messages);
						set_output(file_mkintercon_messages);
						write(name_module_mkintercon);

					when memconnect =>
						create(
							file => file_mkmemcon_messages,
							mode => out_file,
							name => name_file_mkmemcon_messages);
						set_output(file_mkmemcon_messages);
						write(name_module_mkmemcon);

					when toggle =>
						create(
							file => file_mktoggle_messages,
							mode => out_file,
							name => name_file_mktoggle_messages);
						set_output(file_mktoggle_messages);
						write(name_module_mktoggle);

					when clock =>
						create(
							file => file_mkclock_messages,
							mode => out_file,
							name => name_file_mkclock_messages);
						set_output(file_mkclock_messages);
						write(name_module_mkclock);
				end case;

			when compile =>
				create(
					file => file_compiler_messages,
					mode => out_file,
					name => name_file_compiler_messages);
				set_output(file_compiler_messages);
				write(name_module_compiler);
				

			when others => null;
		end case;

		-- restore previous output channel
		set_output(previous_output);
	end write_log_header;

	
	procedure write_log_footer is
	-- Writes the footer in logfile according to current action.
	-- Writes footer information in logfile and closes it.

		-- backup current output channel
		--previous_output	: file_type renames current_output;

		procedure write (module : in string) is
		begin
			put_line(column_separator_0);
			put_line(to_upper(module) & " LOGFILE END");
		end write;

	begin -- write_log_footer
		case action is
			when import_cad =>

				-- All import messages go here (regardless of CAD format):
				set_output(file_import_cad_messages);

				case format_cad is
					when protel =>
						write(name_module_cad_importer_protel);
					when zuken =>
						write(name_module_cad_importer_zuken);
					when orcad =>
						write(name_module_cad_importer_orcad);
					when others => null; -- CS: add more importers here
				end case;

				close(file_import_cad_messages);

			when import_bsdl =>
				set_output(file_import_bsdl_messages);
				write(name_module_importer_bsdl);
				-- if is_open(file_import_bsdl_messages) then
				close(file_import_bsdl_messages);
				-- end if;

			when join_netlist =>
				set_output(file_join_netlist_messages);
				write(name_module_join_netlist);
				-- if is_open(file_mknets_messages) then
				close(file_join_netlist_messages);
				-- end if;
				
			when mknets =>
				set_output(file_mknets_messages);
				write(name_module_mknets);
				-- if is_open(file_mknets_messages) then
				close(file_mknets_messages);
				-- end if;

			when chkpsn =>
				set_output(file_chkpsn_messages);
				write(name_module_chkpsn);
				-- if is_open(file_chkpsn_messages) then
				close(file_chkpsn_messages);
				-- end if;

			when mkoptions =>
				set_output(file_mkoptions_messages);
				write(name_module_mkoptions);
				-- if is_open(file_mkoptions_messages) then
				close(file_mkoptions_messages);
				-- end if;

			when udbinfo =>
				set_output(file_udbinfo_messages);
				write(name_module_database_query);
				close(file_udbinfo_messages);

			when generate =>
				case test_profile is
					when infrastructure =>
						set_output(file_mkinfra_messages);
						write(name_module_mkinfra);
						close(file_mkinfra_messages);

					when interconnect =>
						set_output(file_mkintercon_messages);
						write(name_module_mkintercon);
						close(file_mkintercon_messages);

					when memconnect =>
						set_output(file_mkmemcon_messages);
						write(name_module_mkmemcon);
						close(file_mkmemcon_messages);

					when toggle =>
						set_output(file_mktoggle_messages);
						write(name_module_mktoggle);
						close(file_mktoggle_messages);

					when clock =>
						set_output(file_mkclock_messages);
						write(name_module_mkclock);
						close(file_mkclock_messages);
				end case;

			when compile =>
				set_output(file_compiler_messages);
				write(name_module_compiler);
				close(file_compiler_messages);
				
			when others => null;
			
		end case;

		-- restore previous output channel
		--set_output(previous_output);
		set_output(standard_output);
		
	end write_log_footer;

	
	procedure write_message (
		file_handle : in ada.text_io.file_type;
		identation : in natural := 0; -- CS: rename to "indentation"
		text : in string; 
		lf   : in boolean := true;		
		file : in boolean := true;
		console : in boolean := false) is
	begin
		if file then
			ada.text_io.put(file_handle, identation * ' ' & text);
			if lf then 
				new_line(file_handle);
			end if;
		end if;

		if console then
			-- ada.text_io.put(standard_output,identation * ' ' & text);
			ada.text_io.put(standard_output,text);
			if lf then 
				new_line(standard_output);
			end if;
		end if;
	end write_message;
	
end m1_string_processing;

