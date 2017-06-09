------------------------------------------------------------------------------
--                                                                          --
--                            CSV COMPONENTS                                --
--                                                                          --
--                                 CSV                                      --
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


with ada.strings; 			use ada.strings;
with ada.strings.bounded; 	use ada.strings.bounded;
with ada.strings.unbounded; use ada.strings.unbounded;
with ada.text_io;			use ada.text_io;

package body csv is

	function date_to_natural
	-- Takes an iso date like 1974-07-04 and converts into a natural from 0 to 99999999.
		(
		date 	: string --(1..10) := "0000-00-00"
		)
		return natural is

		package date_type is new generic_bounded_length(10); use date_type;
		date_given	: date_type.bounded_string := to_bounded_string(date); -- CS: check_date ? see lib m1
		date_scratch	: string (1..8);
		date_natural	: natural;
	begin
		delete(date_given,5,5);
		delete(date_given,7,7);
		--put_line(to_string(date_given));
		date_scratch := to_string(date_given);
		date_natural := natural'value(date_scratch); --CS: do a range check for dates from 0 to 22000000 or the like
		return date_natural;
	end date_to_natural;


	function get_field_count
	-- Returns number of fields separated by ifs. if line is empty zero will be returned.
		(
		line	: unbounded_string;
		ifs		: character := ';'	-- default separator is semicolon
		)
		return natural is	

		char_pt		:	natural := 1;				-- charcter pointer (points to character being processed inside the given line)
		char_current:	character;					-- holds current character being processed
		field_ct	:	natural := 0;				-- holds number of fields found in given line
	begin
		--put ("line  : "& Line); new_line;
		--put ("field : "); put (Field); new_line;
		--put ("value : "& Value); new_line;
		if (Length(Line)) > 0 then
			while char_pt <= Length(Line)
			loop
				--put (char_pt);
				char_current:=(To_String(Line)(char_pt)); -- get character where char_pt points to

				if char_current = ifs then -- scan for ifs
					field_ct:=field_ct+1;
				end if;

				char_pt:=char_pt+1; -- advance char_pt to next char in given line

			end loop;
			field_ct:=field_ct+1; -- at least one field must have been found
		end if;

		return field_ct;
	end get_field_count;


	function get_field_position
	-- Returns position of first field containing given string. If string not found, returns 0.
		(
		line	: unbounded_string;
		text 	: string;
		ifs		: character := ';'	-- default separator is semicolon
		)
		return natural is
		position :	natural := 0;
		field_ct : 	natural := get_field_count(line);
	begin
		--put(natural'image(field_ct)); new_line;
		if field_ct = 0 then return position; -- if line is empty, return 0
		else
			for i in 1..get_field_count(line)
				loop
					--put(natural'image(i)); new_line;
					if get_field(line,i) = text then -- on match
						return i; -- return number of column 
					end if;
				end loop;
		end if;
		return position; -- if no match, return 0
	end get_field_position;


	function get_field
	-- Returns field content indicated by field position and separated by ifs.
	-- If line is empty, "" will be returned
		(
		line	: unbounded_string;
		pos 	: natural;
		ifs		: character := ';'	-- default separator is semicolon
		)
		return string is

		char_pt		:	Natural := 1;				-- charcter pointer (points to character being processed inside the given line)
		char_current:	Character;					-- holds current character being processed
		field_pt	:	natural := 1;				-- holds number of fields found in given line
		field_content	: unbounded_string;
	begin
		if pos > get_field_count(line,ifs) then	return ""; end if; -- return "" if wanted pos is greater than field count of given line
		
		if get_field_count(line,ifs) > 0 then -- make sure there is at least one field in the line
			while char_pt <= Length(Line) -- process line until last character -- cs: speed improvement possible ?
			loop
				char_current:=(To_String(Line)(char_pt)); -- get character where char_pt points to  -- cs: speed improvement possible ?

				if char_current = ifs then -- scan for ifs
					--if field_pt = pos then return to_string(field_content); end if; -- return wanted field if ifs found and position matches -- rm v002
					if field_pt = pos then return strip_text_delimiters(to_string(field_content)); end if; -- return wanted field if ifs found and position matches -- ins v002
					field_pt := field_pt + 1; -- otherwise advance field_pt to next field
					field_content := to_unbounded_string(""); -- set initial field content to "" (empty field)

				-- if current charcter is no ifs, build field_content char by char
				else field_content := field_content & char_current;
				end if;

				char_pt:=char_pt+1; -- advance char_pt to next char in given line
			end loop;

			-- end of line reached
			--if field_pt = pos then return to_string(field_content); end if; -- if there is only one field and pos matches, return field_content -- rm v002
			if field_pt = pos then return strip_text_delimiters(to_string(field_content)); end if; -- if there is only one field and pos matches, return field_content -- ins v002
		end if;

		return ""; -- if no fields in line return ""
	end get_field;


	function strip_text_delimiters 
	-- Used to delete text delimiters such as quotes (" or ').
		(
		text_in		: string
		)
		return string is

		delimiter_status	:	natural := 0;
		delimiter_1			: character := '"';
		delimiter_2			: character := ''';
	begin
		-- if an empty string given, do nothing and return string unchanged

		-- if there is only one character given (rare case)
		if text_in'length = 1 then
			-- detect a single delimiter
			if text_in(text_in'first) = delimiter_1 or text_in(text_in'first) = delimiter_2 then
				delimiter_status := delimiter_status + 1;
			end if;
		end if;

		-- if there are 2 or more characters
		if text_in'length >= 2 then
			-- detect start delimiter
			if text_in(text_in'first) = delimiter_1 or text_in(text_in'first) = delimiter_2 then
				delimiter_status := delimiter_status + 1;
			end if;

			-- detect end delimiter
			if text_in(text_in'last) = delimiter_1 or text_in(text_in'last) = delimiter_2 then
				delimiter_status := delimiter_status + 2;
			end if;
		end if;

		--put_line(standard_output,text_in & natural'image(delimiter_status)); -- debug
		-- trim leading and trailing spaces

		case delimiter_status is -- if empty string given, nothing is to do here
			when 1 => return text_in(text_in'first+1 .. text_in'last);	-- only start delimiter found, return text without first character
			when 2 => return text_in(text_in'first .. text_in'last-1);	-- only end delimiter found, return text without last character
			when 3 => return text_in(text_in'first+1 .. text_in'last-1);-- start and end delimiter found, return text without frist and last character
			when others => null; 										-- no delimiters found, return text unchanged
		end case;

	return text_in; -- return string unchanged if empty
	end strip_text_delimiters;

	procedure put_field
	-- Puts a field into a csv file. If field is empty (default), no delimiters are used.
		(
		file	:	ada.text_io.file_type := current_output; -- default to current output if not specified otherwise
		text	:	string := "";
		ifs		:	character := ascii.semicolon; -- field separator
		delim 	:	character := ascii.quotation  -- text delimiter
		) is
	begin
		if text = "" then -- if empty field, just put an ifs
			put(file, ifs);
		else
			put(file, delim & to_string(trim(to_unbounded_string(text),both)) & delim & ifs); -- otherwise enclose trimmed text with delimiters
		end if;
	end put_field;


	procedure put_lf
	-- Puts a new_line into a csv file.
		(
		file	:	ada.text_io.file_type := current_output; -- default to current output if not specified otherwise
		count	:	natural := 1
		) 
		is
	begin
		for i in 1..count
		loop
			put(file, ascii.lf);
		end loop;
	end put_lf;
		
end csv;

