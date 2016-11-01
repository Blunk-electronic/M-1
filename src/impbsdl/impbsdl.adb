------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE IMPBSDL                             --
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
-- with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
-- with Ada.Float_Text_IO;		use Ada.Float_Text_IO;
with ada.characters.handling;   use ada.characters.handling;
-- 
-- --with System.OS_Lib;   use System.OS_Lib;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
--with ada.characters.handling;	use ada.characters.handling;
--with ada.characters.conversions;use ada.characters.conversions;
with ada.strings; 				use ada.strings;
with ada.strings.maps;			use ada.strings.maps;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
-- with Ada.Numerics;			use Ada.Numerics;
-- with Ada.Numerics.Elementary_Functions;	use Ada.Numerics.Elementary_Functions;
-- 
-- with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
-- with Ada.Task_Identification;  use Ada.Task_Identification;
-- with Ada.Exceptions; use Ada.Exceptions;
-- with Ada.IO_Exceptions; use Ada.IO_Exceptions;
--  
with gnat.os_lib;   		use gnat.os_lib;
with ada.command_line;		use ada.command_line;
with ada.directories;		use ada.directories;

with m1; use m1;
with m1_internal; 				use m1_internal;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;


procedure impbsdl is

	version			: String (1..3) := "0xx";
	udb_summary		: type_udb_summary;


	procedure read_bsld_models is
		bic				: type_ptr_bscan_ic_pre := ptr_bic_pre;
		file_bsdl 		: ada.text_io.file_type;
		line_of_file	: extended_string.bounded_string;
		line_counter	: natural := 0;
		--entry_line_count: positive := 1;

		type type_bsdl_entry;
		type type_ptr_bsdl_entry is access all type_bsdl_entry;
		type type_bsdl_entry is
			record
				next		: type_ptr_bsdl_entry;
				line		: extended_string.bounded_string;
			end record;
		ptr_bsdl_entry : type_ptr_bsdl_entry;

		procedure add_line_to_bsdl_entry (
			list			: in out type_ptr_bsdl_entry;
			line			: in extended_string.bounded_string
			) is
			line_cleaned_up	: extended_string.bounded_string;
			--characters_to_replace : character_set;
			--number_of_char_to_replace : natural := 0;
			--ctrl_map : character_mapping := to_mapping("ab","cd");
			--ctrl_map : character_mapping := to_mapping(latin_1.cr, latin_1.space);
		begin
			--characters_to_replace := to_set(latin_1.cr);
			--characters_to_replace := to_set(latin_1.ht);
			--number_of_char_to_replace := extended_string.count(line,characters_to_replace);

			line_cleaned_up := line;
			--entry_line_count := entry_line_count + 1;
			--put_line(standard_output,extended_string.to_string(line));

			-- replace control characters by space
 			for c in 1..extended_string.length(line_cleaned_up) loop
				if is_control(extended_string.element(line_cleaned_up,c)) then
					extended_string.replace_element(line_cleaned_up,c,latin_1.space);
				end if;

-- 				if c < extended_string.length(line_cleaned_up) then
-- 					if extended_string.element(line_cleaned_up,c) = latin_1.space and extended_string.element(line_cleaned_up,c+1) = latin_1.space then
-- 						null;
-- 						put_line(standard_output,"test");
-- 						put_line(standard_output,extended_string.to_string(line_cleaned_up));
-- 						extended_string.delete(line_cleaned_up,c,c);
-- 					end if;
-- 				end if;
			end loop;
			
			list := new type_bsdl_entry'(
				next		=> list,
				line		=> line_cleaned_up
				);
		end add_line_to_bsdl_entry;

		function get_entry return string is
			e : type_ptr_bsdl_entry := ptr_bsdl_entry;
			--line : string (1..entry_line_count * extended_string.max_length);
			line : unbounded_string;
			--entry_start : positive := 1;
			--entry_end : positive := 1;
		begin
			while e /= null loop
				--put_line(standard_output,extended_string.to_string(e.line));
				line := to_unbounded_string(extended_string.to_string(e.line)) & row_separator_0 & line;
				e := e.next;
			end loop;
			return to_string(line);
		end get_entry;

	begin
		set_output(file_data_base_preliminary);
		while bic /= null loop
			put_line(row_separator_0 & section_mark.subsection & row_separator_0 & universal_string_type.to_string(bic.name));
			put_line(standard_output,"model file " & extended_string.to_string(bic.model_file));
			open(file => file_bsdl, mode => in_file, name => extended_string.to_string(bic.model_file));
			set_input(file_bsdl);
			ptr_bsdl_entry := null;
			while not end_of_file loop
				line_counter := line_counter + 1;
				line_of_file := extended_string.to_bounded_string(get_line);
				line_of_file := remove_comment_from_line(line_of_file);
				if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything
					add_line_to_bsdl_entry(list => ptr_bsdl_entry, line => line_of_file);
					if extended_string.index(line_of_file, ";") > 0 then
						put_line(file_data_base_preliminary,get_entry);
						ptr_bsdl_entry := null;
					end if;

				--put_line(get_entry);
-- 			put_line(2 * row_separator_0 & "value");
-- 			put_line(2 * row_separator_0 & "instruction_register_length");
-- 			put_line(2 * row_separator_0 & "instruction_capture");
-- 			put_line(2 * row_separator_0 & "idcode_register");
-- 			put_line(2 * row_separator_0 & "usercode_register");
-- 			put_line(2 * row_separator_0 & "boundary_register_length");
-- 			put_line(2 * row_separator_0 & "trst_pin available");

				end if; -- if line contains anything
			end loop;
			close(file_bsdl);
			put_line(row_separator_0 & section_mark.endsubsection & row_separator_0 & universal_string_type.to_string(bic.name));
			bic := bic.next;
		end loop;

	end read_bsld_models;




-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin


	new_line;
	put_line("BSDL MODEL IMPORTER VERSION "& version);
	put_line("===============================");
	--prog_position	:= 10;
 	name_file_data_base:= universal_string_type.to_bounded_string(argument(1));
 	put_line("data base      : " & universal_string_type.to_string(name_file_data_base));

	--prog_position	:= 20;
	udb_summary := read_uut_data_base(universal_string_type.to_string(name_file_data_base));

	create_temp_directory;
	create_bak_directory;

	-- backup data base section scanpath_configuration (incl. comments)
	extract_section( 
		universal_string_type.to_string(name_file_data_base),
		name_directory_bak & name_directory_separator & universal_string_type.to_string(name_file_data_base),
		section_mark.section,
		section_mark.endsection,
		section_scanpath_configuration
		);

	extract_section( 
		universal_string_type.to_string(name_file_data_base),
		name_file_data_base_preliminary,
		section_mark.section,
		section_mark.endsection,
		section_scanpath_configuration
		);

	open( 
		file => file_data_base_preliminary,
		mode => append_file,
		name => name_file_data_base_preliminary
		);

	new_line (file_data_base_preliminary);
	put_line (file_data_base_preliminary,section_mark.section & row_separator_0 & section_registers);
	put_line (file_data_base_preliminary,column_separator_0);
	put_line (file_data_base_preliminary,"-- created by BSDL importer version " & version);
	put_line (file_data_base_preliminary,"-- date       : " & m1_internal.date_now); 

	read_bsld_models;

	put_line (file_data_base_preliminary,section_mark.endsection); 
	new_line (file_data_base_preliminary);

	close(file_data_base_preliminary);
--	copy_file(name_file_data_base_preliminary, universal_string_type.to_string(name_file_data_base));


	
end impbsdl;
