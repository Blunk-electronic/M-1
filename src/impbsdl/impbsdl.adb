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
-- with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
--with ada.characters;			use ada.characters;
--with ada.characters.handling;	use ada.characters.handling;
--with ada.characters.conversions;use ada.characters.conversions;
with ada.strings; 				use ada.strings;
--with ada.strings.maps;			use ada.strings.maps;
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
		begin
			list := new type_bsdl_entry'(
				next		=> list,
				line		=> line
				);
		end add_line_to_bsdl_entry;

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
						null;
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
