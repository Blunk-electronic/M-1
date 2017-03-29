------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE UDBINFO                             --
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

-- todo: set exit code 2 when item not found

with ada.text_io;				use ada.text_io;
with ada.exceptions; 			use ada.exceptions;
with ada.command_line;			use ada.command_line;

with m1_base;					use m1_base;
with m1_database;				use m1_database;
with m1_files_and_directories; 	use m1_files_and_directories;
with m1_string_processing;		use m1_string_processing;

procedure udbinfo is
	
	version			: constant string (1..3) := "003";
	prog_position	: natural := 0;

	use type_universal_string;
	use type_name_database;

	inquired_item				: type_item_udbinfo;
	inquired_target				: type_universal_string.bounded_string;
	separator					: constant string (1..1) := "#";
	separator_position			: natural;
	length_of_inquired_target	: natural;
	inquired_target_sub_1		: type_universal_string.bounded_string;
	inquired_target_sub_2		: type_universal_string.bounded_string;


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	new_line;
	put_line("UUT DATA BASE INFO version "& version);
	put_line("====================================");

	prog_position	:= 10;
 	name_file_database := type_name_database.to_bounded_string(argument(1));
 	put_line("data base      : " & to_string(name_file_database));

	prog_position	:= 20;
	inquired_item := type_item_udbinfo'value(argument(2));
	put_line("item           : " & type_item_udbinfo'image(inquired_item));

	prog_position	:= 30;
	inquired_target := to_bounded_string(argument(3));
	put_line("name           : " & to_string(inquired_target));

	prog_position	:= 40;
	if argument_count = 4 then
		debug_level := natural'value(argument(4));
		put_line("debug level    :" & natural'image(debug_level));
	end if;

	prog_position	:= 50;
	read_database;


		case inquired_item is
			when net => print_net_info(to_string(inquired_target));
			when bic => print_bic_info(to_string(inquired_target));
			when scc => 
				separator_position := index(inquired_target,separator);
				length_of_inquired_target := length(inquired_target);
				inquired_target_sub_1 := to_bounded_string(slice(inquired_target,1,separator_position-1));
				inquired_target_sub_2 := to_bounded_string(slice(inquired_target,separator_position+1, length_of_inquired_target));

				print_scc_info(
					bic_name 			=> to_string(inquired_target_sub_1),
					control_cell_id		=> natural'value(to_string(inquired_target_sub_2))
					);
			when others => null;
		end case;

	exception
-- 		when constraint_error => 

		when event: others =>
			case prog_position is
				when 10 =>
					put_line(message_error & "Database file missing or insufficient access rights !");
					put_line("       Provide data base name as argument. Example: udbinfo my_uut.udb");
				when 20 =>
					put(message_error & "Inquired item invalid or missing. Valid items are:");
					for i in 0..type_item_udbinfo'pos(type_item_udbinfo'last) loop
						put(row_separator_0 & type_item_udbinfo'image(type_item_udbinfo'val(i)));
					end loop;
					new_line;
					put_line("       Provide item as argument ! Example: udbinfo my_uut.udb net");
				when 30 =>
					put_line(message_error & "Name of item missing. Provide name as argument !");
					put_line("       Example 1: udbinfo my_uut.udb net cpu_clk");
					put_line("       Example 2: udbinfo my_uut.udb bic IC303");
					put_line("       Example 3: udbinfo my_uut.udb scc IC303#16");
				when 40 =>
					put_line(message_error & "Invalid argument for debug level. Debug level must be provided as natural number !");


				when others =>
-- 					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & natural'image(prog_position));
			end case;
			--clean_up;
			--raise;

end udbinfo;
