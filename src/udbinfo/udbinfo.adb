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
with ada.characters;			use ada.characters;
with ada.characters.handling;	use ada.characters.handling;
with ada.characters.latin_1;	use ada.characters.latin_1;
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

	separator					: constant string (1..1) := "#";
	separator_position			: natural;
	length_of_inquired_target	: natural;
	inquired_target_sub_1		: type_universal_string.bounded_string;
	inquired_target_sub_2		: type_universal_string.bounded_string;


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := udbinfo;

	-- create message/log file
 	write_log_header(version);

	put_line(to_upper(name_module_database_query) & " version "& version);
	put_line("====================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages

	prog_position	:= 10;
 	name_file_database := type_name_database.to_bounded_string(argument(1));

	write_message (
		file_handle => file_udbinfo_messages,
		text => text_identifier_database & row_separator_0 & to_string(name_file_database),
		console => true);

	prog_position	:= 20;
	object_type_in_database := type_object_type_in_database'value(argument(2));

	write_message (
		file_handle => file_udbinfo_messages,
		text => "item " & type_object_type_in_database'image(object_type_in_database),
		console => true);

	prog_position	:= 30;
	object_name_in_database := to_bounded_string(argument(3));

	write_message (
		file_handle => file_udbinfo_messages,
		text => "name " & to_string(object_name_in_database),
		console => true);

	prog_position	:= 40;
	if argument_count = 4 then
		degree_of_database_integrity_check := type_degree_of_database_integrity_check'value(argument(4));

		write_message (
			file_handle => file_udbinfo_messages,
			text => "degree of integrity check " & type_degree_of_database_integrity_check'image(degree_of_database_integrity_check),
			console => true);
	end if;

	prog_position	:= 50;
	read_uut_database;

	prog_position	:= 60;
	case object_type_in_database is
		when net => print_net_info(to_string(object_name_in_database));
		when bic => print_bic_info(to_string(object_name_in_database));
		when scc => 
			separator_position := index(object_name_in_database,separator);
			length_of_inquired_target := length(object_name_in_database);
			inquired_target_sub_1 := to_bounded_string(slice(object_name_in_database,1,separator_position-1));
			inquired_target_sub_2 := to_bounded_string(slice(object_name_in_database,separator_position+1, length_of_inquired_target));

			print_scc_info(
				bic_name 			=> to_string(inquired_target_sub_1),
				control_cell_id		=> natural'value(to_string(inquired_target_sub_2))
				);
		when others => null;
	end case;

	prog_position	:= 60;
	write_log_footer;

	exception when event: others =>
		set_exit_status(failure);

		write_message (
			file_handle => file_udbinfo_messages,
			text => message_error & "at program position " & natural'image(prog_position),
			console => true);

		case prog_position is
			when 10 =>
				write_message (
					file_handle => file_udbinfo_messages,
					text => message_error & "name of " & text_identifier_database & " required !"
						& latin_1.lf 
						& "Provide data base name as argument. Example: udbinfo my_uut.udb",
					console => true);

			when 20 =>
				write_message (
					file_handle => file_udbinfo_messages,
					text => message_error & "Inquired item invalid or missing. Valid items are:",
					console => true);

				for i in 0..type_object_type_in_database'pos(type_object_type_in_database'last) loop
					write_message (
						file_handle => file_udbinfo_messages,
						text => row_separator_0 
							& type_object_type_in_database'image(type_object_type_in_database'val(i)),
						lf => false,
						console => true);
				end loop;

				write_message (
					file_handle => file_udbinfo_messages,
					text => latin_1.lf
						& "Provide item as argument ! Example: udbinfo my_uut.udb net",
					console => true);

			when 30 =>
				write_message (
					file_handle => file_udbinfo_messages,
					text => message_error & "Name of item missing. Provide name as argument !"
						& latin_1.lf
						& "Example 1: udbinfo my_uut.udb net cpu_clk"
						& latin_1.lf
						& "Example 2: udbinfo my_uut.udb bic IC303"
						& latin_1.lf
						& "Example 3: udbinfo my_uut.udb scc IC303#16",
					console => true);

			when 40 =>
				write_message (
					file_handle => file_udbinfo_messages,
					text => message_error & "Invalid degree of integrity check ! Provide degree as",
					console => true);

				for i in 0..type_degree_of_database_integrity_check'pos(type_degree_of_database_integrity_check'last) loop
					write_message (
						file_handle => file_udbinfo_messages,
						text => row_separator_0 
							& type_degree_of_database_integrity_check'image(type_degree_of_database_integrity_check'val(i)),
						lf => false,
						console => true);
				end loop;


			when others =>
				write_message (
					file_handle => file_udbinfo_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_udbinfo_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;
end udbinfo;
