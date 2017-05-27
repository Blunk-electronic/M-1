------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 TESTBENCH                                  --
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


with ada.text_io;				use ada.text_io;
-- with ada.integer_text_io;		use ada.integer_text_io;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling; 	use ada.characters.handling;

-- with ada.float_text_io;			use ada.float_text_io;

with ada.containers;            use ada.containers;

with ada.strings; 				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
 
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

-- with interfaces;				use interfaces;

with m1_base;					use m1_base;
with m1_database; 				use m1_database;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories;	use m1_files_and_directories;
with m1_test_gen_and_exec;		use m1_test_gen_and_exec;
with m1_string_processing;		use m1_string_processing;
with m1_firmware; 				use m1_firmware;

procedure testbench is

	prog_position 			: natural := 0;

	use type_name_database;
    use type_name_test;
	use type_device_name;    
	use type_list_of_scanports;
    use type_list_of_bics;
	use type_universal_string;
    use type_long_string;	
    use type_extended_string;    
	use type_list_of_strings;

	line : type_list_of_strings.vector;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
-- 	action := compile;
-- 
-- 	-- create message/log file
-- 	write_log_header(compseq_version);
-- 	
-- 	put_line(to_upper(name_module_compiler) & " version " & compseq_version);
-- 	put_line("=======================================");
-- 
-- 	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages

	prog_position := 10;
	name_file_database := to_bounded_string(argument(1));

	open (file_database, in_file, to_string(name_file_database));
	set_input( file_database);

	while not end_of_file loop
-- 		put_line(get_line);
		line := read_line(get_line);
		if length(line) > 0 then
-- 			for i in 1..length(line) loop
-- 				put(element(line, positive(i)) & latin_1.space);
-- 			end loop;
-- 			new_line;
			put_line( element(line, positive(1)));
		end if;
	end loop;

end testbench;
