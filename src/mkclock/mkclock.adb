------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKCLOCK                             --
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

-- todo: 


with ada.text_io;				use ada.text_io;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
 
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1;
with m1_files_and_directories; use m1_files_and_directories;
with m1_internal; use m1_internal;
with m1_numbers; use m1_numbers;


procedure mkclock is

	version			: string (1..3) := "003";
	test_profile	: type_test_profile := clock;
	end_sdr			: type_end_sdr := PDR;
	end_sir			: type_end_sir := RTI;

	target_device	: universal_string_type.bounded_string;
	target_pin		: universal_string_type.bounded_string;

	retry_count		: type_sxr_retries;
	retry_delay		: type_delay_value;

	type type_algorithm is ( non_intrusive ); -- CS: others: intrusive
	algorithm 		: type_algorithm;
	
	prog_position	: natural := 0;



	procedure write_info_section is
	-- creates the sequence file,
	-- directs subsequent puts into the sequence file
	-- writes the info section into the sequence file

		colon_position : positive := 19;

	begin -- write_info_section
		-- create sequence file
		create( sequence_file, 
			name => (compose (universal_string_type.to_string(test_name), universal_string_type.to_string(test_name), file_extension_sequence)));
		set_output(sequence_file); -- set data sink

		put_line(section_mark.section & row_separator_0 & test_section.info);
		put_line(" created by clock test generator version "& version);
		put_line(row_separator_0 & section_info_item.date & (colon_position-(2+section_info_item.date'last)) * row_separator_0 & ": " & m1.date_now);
		put_line(row_separator_0 & section_info_item.data_base & (colon_position-(2+section_info_item.data_base'last)) * row_separator_0 & ": " & universal_string_type.to_string(name_file_data_base));
		put_line(row_separator_0 & section_info_item.test_name & (colon_position-(2+section_info_item.test_name'last)) * row_separator_0 & ": " & universal_string_type.to_string(test_name));
		put_line(row_separator_0 & section_info_item.test_profile & (colon_position-(2+section_info_item.test_profile'last)) * row_separator_0 & ": " & type_test_profile'image(test_profile));
		put_line(row_separator_0 & section_info_item.end_sdr & (colon_position-(2+section_info_item.end_sdr'last)) * row_separator_0 & ": " & type_end_sdr'image(end_sdr));
		put_line(row_separator_0 & section_info_item.end_sir & (colon_position-(2+section_info_item.end_sir'last)) * row_separator_0 & ": " & type_end_sir'image(end_sir));
		put_line(row_separator_0 & section_info_item.target_device & (colon_position-(2+section_info_item.target_device'last)) * row_separator_0 & ": " & universal_string_type.to_string(target_device));
		put_line(row_separator_0 & section_info_item.target_pin & (colon_position-(2+section_info_item.target_pin'last)) * row_separator_0 & ": " & universal_string_type.to_string(target_pin));
		put_line(row_separator_0 & section_info_item.retry_count & (colon_position-(2+section_info_item.retry_count'last)) * row_separator_0 & ":" & type_sxr_retries'image(retry_count));
		put_line(row_separator_0 & section_info_item.retry_delay & (colon_position-(2+section_info_item.retry_delay'last)) * row_separator_0 & ":" & type_delay_value'image(retry_delay) & " sec");

		put_line(section_mark.endsection); 
		new_line;
	end write_info_section;


	procedure check_target is
		target	: type_ptr_bscan_ic := get_bic_coordinates(target_device);
	begin
		-- check if target device exists
		if target = null then
			put_line ("ERROR: Specified target device '" & universal_string_type.to_string(target_device) & "' is not part of any scan path !");
			put_line ("       Check spelling or capitalization and try again !");
			raise constraint_error;
		end if;
	end check_target;


  	procedure atg_mkclock is

		-- Search in cell lists atg_drive, input_cells_class_NA, static_expect.
		-- Set list pointers at end of list.
		atg_expect			: type_ptr_cell_list_atg_expect := ptr_cell_list_atg_expect;
		class_NA 			: type_ptr_cell_list_input_cells_class_NA := ptr_cell_list_input_cells_class_NA;
		class_static_expect	: type_ptr_cell_list_static_expect := ptr_cell_list_static_expect;
 		target_device_found	: boolean := false;
		expect_high			: type_bit_char_class_0 := '1';
		expect_low			: type_bit_char_class_0 := '0';


		procedure write_receiver_cell(
			device 		: string;
			cell 		: type_cell_id;
			value 		: type_bit_char_class_0;
			net			: string
			) is
		begin
			put(" -- wait for "); put_character_class_0(value); 
			put_line(" on target device " & universal_string_type.to_string(target_device) & 
				row_separator_0 & "pin" & row_separator_0 & universal_string_type.to_string(target_pin) &
				row_separator_0 & "net " & net);

			put( -- write sdr expect header (like "set IC301 exp boundary")
				row_separator_0 & sequence_instruction_set.set & row_separator_0 &
				device & row_separator_0 &
				sxr_io_identifier.expect & row_separator_0 &
				sdr_target_register.boundary &
				type_cell_id'image(cell) & sxr_assignment_operator.assign -- write cell id and assigment operator (like "45=")
				);

			-- write expect value
			put_character_class_0(value);
			new_line;
			write_sdr(with_new_line => false); --  sdr id 3 option retry 10 delay 1
			put_line(row_separator_0 & sxr_option.option & row_separator_0 & sxr_option.retry &
				type_sxr_retries'image(retry_count) & row_separator_0 & sxr_option.dely & type_delay_value'image(retry_delay));

			new_line;

		end write_receiver_cell;

 	begin
 		-- First, search in atg_expect list for target device.
 		while atg_expect /= null
 			loop
 				if universal_string_type.to_string(atg_expect.device) = universal_string_type.to_string(target_device) then
					if universal_string_type.to_string(atg_expect.pin) = universal_string_type.to_string(target_pin) then
						target_device_found := true;

						write_receiver_cell(
							device => universal_string_type.to_string(target_device),
							cell => atg_expect.cell,
							value => expect_low,
							net => universal_string_type.to_string(atg_expect.net)
							);

						write_receiver_cell(
							device => universal_string_type.to_string(target_device),
							cell => atg_expect.cell,
							value => expect_high,
							net => universal_string_type.to_string(atg_expect.net)
							);

						exit; -- no more seaching required
					end if;
 				end if;
 				atg_expect := atg_expect.next; -- advance pointer in atg_expect list
 			end loop;

		-- If target not found, search in class NA list.
		if not target_device_found then
			while class_NA /= null
				loop
					if universal_string_type.to_string(class_NA.device) = universal_string_type.to_string(target_device) then
						if universal_string_type.to_string(class_NA.pin) = universal_string_type.to_string(target_pin) then
							target_device_found := true;

							write_receiver_cell(
								device => universal_string_type.to_string(target_device),
								cell => class_NA.cell,
								value => expect_low,
								net => universal_string_type.to_string(class_NA.net)
								);

							write_receiver_cell(
								device => universal_string_type.to_string(target_device),
								cell => class_NA.cell,
								value => expect_high,
								net => universal_string_type.to_string(class_NA.net)
								);

							exit; -- no more seaching required
						end if;

					end if;
					class_NA := class_NA.next; -- advance pointer in list
				end loop;
		end if;

		-- If target still not found, search in static expect list.
		if not target_device_found then
			while class_static_expect /= null
				loop
					if universal_string_type.to_string(class_static_expect.device) = universal_string_type.to_string(target_device) then
						if universal_string_type.to_string(class_static_expect.pin) = universal_string_type.to_string(target_pin) then
							target_device_found := true;

							put_line(standard_output,"NOTE: The target pin is in class " & type_net_class'image(class_static_expect.class) &
								row_separator_0 & "net '" & universal_string_type.to_string(class_static_expect.net) & "' !");
							put_line(standard_output,"      The test is likely to fail.");

							write_receiver_cell(
								device => universal_string_type.to_string(target_device),
								cell => class_static_expect.cell,
								value => expect_low,
								net => universal_string_type.to_string(class_static_expect.net)
								);

							write_receiver_cell(
								device => universal_string_type.to_string(target_device),
								cell => class_static_expect.cell,
								value => expect_high,
								net => universal_string_type.to_string(class_static_expect.net)
								);
							exit; -- no more seaching required
						end if;
					end if;
					class_static_expect := class_static_expect.next; -- advance pointer in list
				end loop;
		end if;

		if target_device_found = false then
			set_output(standard_output);
			put_line("ERROR : Target pin search failed !");
			put_line("        Make sure the targeted pin exists and is connected to a scan capable net !");
			raise constraint_error;
		end if;
		
	end atg_mkclock;



	procedure write_sequences is
	begin -- write_sequences
		new_line(2);

		all_in(sample);
		write_ir_capture;
		write_sir; new_line;

		load_safe_values;
		write_sdr; new_line;

		case algorithm is
			when non_intrusive => null;
			--when others => all_in(extest);
			--	write_sir; new_line;
		end case;

		load_safe_values;
		write_sdr; new_line;

		load_static_drive_values;
		load_static_expect_values;
		write_sdr; new_line;

		atg_mkclock;

		write_end_of_test;
	end write_sequences;






-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin

	put_line("clock test generator version "& version);
	put_line("=====================================================");

	-- COMMAND LINE ARGUMENTS COLLECTING BEGIN
	prog_position	:= 10;
 	name_file_data_base:= universal_string_type.to_bounded_string(Argument(1));
 	put_line ("data base      : " & universal_string_type.to_string(name_file_data_base));
 
	prog_position	:= 20;
 	test_name:= universal_string_type.to_bounded_string(Argument(2));
 	put_line ("test name      : " & universal_string_type.to_string(test_name));

	prog_position	:= 30;
	algorithm:= type_algorithm'value(Argument(3));
	put_line ("algorithm      : " & type_algorithm'image(algorithm));
	
	prog_position	:= 40;
	target_device:= universal_string_type.to_bounded_string(Argument(4));
	put_line ("target device  : " & universal_string_type.to_string(target_device));
	
	prog_position	:= 50;
	target_pin:= universal_string_type.to_bounded_string(Argument(5));
	put_line ("target pin     : " & universal_string_type.to_string(target_pin));
	
	prog_position	:= 60;
	retry_count:= type_sxr_retries'value(Argument(6));
	put_line ("retry count max:" & type_sxr_retries'image(retry_count));

	prog_position	:= 70;	
	retry_delay:= type_delay_value'value(Argument(7));
	put_line ("retry delay    :" & type_delay_value'image(retry_delay) & " sec");
	-- COMMAND LINE ARGUMENTS COLLECTING DONE

	prog_position	:= 90;	
	read_data_base;

	check_target;

	prog_position	:= 100;
 	create_temp_directory;
	
	prog_position	:= 110;
	create_test_directory(
		test_name 			=> universal_string_type.to_string(test_name),
		warnings_enabled 	=> false
		);

	prog_position	:= 120; 
	write_info_section;
	prog_position	:= 130;
	write_test_section_options;

	prog_position	:= 140;
	write_test_init;

	prog_position	:= 150;
	write_sequences;

	prog_position	:= 160;
	set_output(standard_output);

	prog_position	:= 170;
	close(sequence_file);

	prog_position	:= 180;
	write_diagnosis_netlist(
		data_base	=>	universal_string_type.to_string(name_file_data_base),
		test_name	=>	universal_string_type.to_string(test_name)
		);



	exception
		when event: others =>
			set_output(standard_output);
			set_exit_status(failure);
			case prog_position is
				when 10 =>
					put_line("ERROR: Data base file missing or insufficient access rights !");
					put_line("       Provide data base name as argument. Example: mktoggle my_uut.udb");
				when 20 =>
					put_line("ERROR: Test name missing !");
					put_line("       Provide test name as argument ! Example: mktoggle my_uut.udb my_clock_test");
				when 30 =>
					put_line("ERROR: Test algorithm missing or invalid !");
					put_line("       Provide test algorithm as argument ! Example: mkclock my_uut.udb my_clock_test non_intrusive");
					-- CS: put supported algorithms
				when 40 =>
					put_line("ERROR: Target device missing or invalid !");
					put_line("       Provide target device as argument ! Example: mkclock my_uut.udb my_clock_test non_intrusive IC1");
				when 50 =>
					put_line("ERROR: Target pin missing or invalid !");
					put_line("       Provide target pin as argument ! Example: mkclock my_uut.udb my_clock_test non_intrusive IC1 45");
				when 60 =>
					put_line("ERROR: Invalid retry count specified or missing. Allowed range:" & type_sxr_retries'image(type_sxr_retries'first) &
						".." & type_sxr_retries'image(type_sxr_retries'last) & " !");
				when 70 =>
					put_line("ERROR: Invalid retry delay time specified or missing. Allowed range:" & type_delay_value'image(type_delay_value'first) &
						".." & type_delay_value'image(type_delay_value'last) & " !");


				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & natural'image(prog_position));
			end case;
			
end mkclock;
