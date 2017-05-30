------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKCLOCK                             --
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
--

-- todo: abort if DH or DL nets used (because in non-intrusive mode, extest not used)


with ada.text_io;				use ada.text_io;
with ada.integer_text_io;		use ada.integer_text_io;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling; 	use ada.characters.handling;

with ada.strings; 				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
 
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_base;					use m1_base;
with m1_database; 				use m1_database;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories;	use m1_files_and_directories;
with m1_test_gen_and_exec;		use m1_test_gen_and_exec;
with m1_string_processing;		use m1_string_processing;


procedure mkclock is

    version			: string (1..3) := "001";
    prog_position	: natural := 0;

	use type_name_database;
	use type_device_name;
	use type_name_test;
	use type_pin_name;
	use type_port_name;
	use type_net_name;
    use type_list_of_bics;	
	use type_list_of_nets;
	use type_list_of_pins;
    use type_list_of_atg_expect_cells;
    use type_list_of_input_cells_class_NA;
    use type_list_of_static_expect_cells;
    
    target_device   : type_device_name.bounded_string;
    target_pin		: type_pin_name.bounded_string;
    
	end_sdr			: type_end_sdr := PDR;
	end_sir			: type_end_sir := RTI;

	retry_count		: type_sxr_retries;
	retry_delay		: type_delay_value;

	type type_algorithm is ( non_intrusive ); -- CS: others: intrusive
	algorithm 		: type_algorithm;
	


	procedure write_info_section is
	-- creates the sequence file,
	-- directs subsequent puts into the sequence file
	-- writes the info section into the sequence file

		colon_position : positive := 19;

	begin -- write_info_section
-- 		-- create sequence file
-- 		create( file_sequence, 
-- 			name => (compose (to_string(name_test), to_string(name_test), file_extension_sequence)));
-- 		set_output(file_sequence); -- set data sink

		put_line(file_sequence, section_mark.section & row_separator_0 & test_section.info);
		put_line(file_sequence, " created by " & name_module_mkclock & " version "& version);
		put_line(file_sequence, row_separator_0 & section_info_item.date & (colon_position-(2+section_info_item.date'last)) * row_separator_0 & ": " & date_now);
		put_line(file_sequence, row_separator_0 & section_info_item.database & (colon_position-(2+section_info_item.database'last)) * row_separator_0 & ": " & to_string(name_file_database));
		put_line(file_sequence, row_separator_0 & section_info_item.name_test & (colon_position-(2+section_info_item.name_test'last)) * row_separator_0 & ": " & to_string(name_test));
		put_line(file_sequence, row_separator_0 & section_info_item.test_profile & (colon_position-(2+section_info_item.test_profile'last)) * row_separator_0 & ": " & type_test_profile'image(test_profile));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sdr & (colon_position-(2+section_info_item.end_sdr'last)) * row_separator_0 & ": " & type_end_sdr'image(end_sdr));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sir & (colon_position-(2+section_info_item.end_sir'last)) * row_separator_0 & ": " & type_end_sir'image(end_sir));
		put_line(file_sequence, row_separator_0 & section_info_item.target_device & (colon_position-(2+section_info_item.target_device'last)) * row_separator_0 & ": " & to_string(target_device));
		put_line(file_sequence, row_separator_0 & section_info_item.target_pin & (colon_position-(2+section_info_item.target_pin'last)) * row_separator_0 & ": " & to_string(target_pin));
		put_line(file_sequence, row_separator_0 & section_info_item.retry_count & (colon_position-(2+section_info_item.retry_count'last)) * row_separator_0 & ":" & type_sxr_retries'image(retry_count));
		put_line(file_sequence, row_separator_0 & section_info_item.retry_delay & (colon_position-(2+section_info_item.retry_delay'last)) * row_separator_0 & ":" & type_delay_value'image(retry_delay) & " sec");

		put_line(file_sequence, section_mark.endsection); 
		new_line(file_sequence);
	end write_info_section;


	procedure verify_target is
-- 		target_id : natural := get_bic_coordinates(target_device);
	begin
		-- check if target device exists
		if not is_bic(target_device) then
            write_message (
                file_handle => file_mkclock_messages,
                text => message_error & "specified target device " & to_string(target_device) 
                    & " is not part of any scanpath !" & latin_1.lf
                    & "Check spelling and capitalization and try again !",
                console => true);
            raise constraint_error;
		end if;
	end verify_target;


  	procedure atg_mkclock is

		-- Search in cell lists atg_drive, input_cells_class_NA, static_expect.
		-- Set list pointers at end of list.
-- 		atg_expect			: type_ptr_cell_list_atg_expect := ptr_cell_list_atg_expect;
-- 		class_NA 			: type_ptr_cell_list_input_cells_class_NA := ptr_cell_list_input_cells_class_NA;
-- 		class_static_expect	: type_ptr_cell_list_static_expect := ptr_cell_list_static_expect;
 		target_device_found	: boolean := false;
		expect_high			: type_bit_char_class_0 := '1';
		expect_low			: type_bit_char_class_0 := '0';


		procedure write_receiver_cell(
			device 		: type_device_name.bounded_string;
			cell 		: type_cell_id;
			value 		: type_bit_char_class_0;
			net			: type_net_name.bounded_string
			) is
		begin
			put(file_sequence, " -- wait for "); put_character_class_0(file => file_sequence, char_in => value); 
            put_line(file_sequence, " on target device " & to_string(target_device) 
                & row_separator_0 & "pin" & row_separator_0 & to_string(target_pin) 
                & row_separator_0 & "net " & to_string(net));

			put(file_sequence,  -- write sdr expect header (like "set IC301 exp boundary")
                row_separator_0 & sequence_instruction_set.set & row_separator_0 
                & to_string(device) & row_separator_0 & sxr_io_identifier.expect & row_separator_0 
                & sdr_target_register.boundary & type_cell_id'image(cell) 
                & sxr_assignment_operator.assign -- write cell id and assigment operator (like "45=")
				);

			-- write expect value
			put_character_class_0(file => file_sequence, char_in => value);
            new_line(file_sequence);
            
            -- write something like "sdr id 3 option retry 10 delay 1"
			write_sdr(with_new_line => false); 
            put_line(file_sequence, row_separator_0 & sxr_option.option 
                & row_separator_0 & sxr_option.retry 
                & type_sxr_retries'image(retry_count) & row_separator_0 
                & sxr_option.dely & type_delay_value'image(retry_delay));
            
			new_line(file_sequence);
		end write_receiver_cell;

 	begin
 		-- First, search in atg_expect list for target device.
        --  while atg_expect /= null
        for e in 1..length(list_of_atg_expect_cells) loop
            -- NOTE: element(list_of_atg_expect_cells, positive(e)) means the current expect cell
            if element(list_of_atg_expect_cells, positive(e)).device = target_device then
                if element(list_of_atg_expect_cells, positive(e)).pin = target_pin then
                    target_device_found := true;

                    -- write something like "set IC301 exp boundary 95=0"
                    write_receiver_cell(
                        device => target_device,
                        cell => element(list_of_atg_expect_cells, positive(e)).id,
                        value => expect_low,
                        net => element(list_of_atg_expect_cells, positive(e)).net
                        );

                    -- write something like "set IC301 exp boundary 95=1"                    
                    write_receiver_cell(
                        device => target_device,
                        cell => element(list_of_atg_expect_cells, positive(e)).id,
                        value => expect_high,
                        net => element(list_of_atg_expect_cells, positive(e)).net
                        );

                    exit; -- no more seaching required
                end if;
            end if;
--             atg_expect := atg_expect.next; -- advance pointer in atg_expect list
        end loop;

		-- If target not found, search in class NA list.
		if not target_device_found then
            -- 			while class_NA /= null
            for i in 1..length(list_of_input_cells_class_NA) loop
                -- NOTE: element(type_list_of_input_cells_class_NA, positive(i)) means the current input cell
                if element(list_of_input_cells_class_NA, positive(i)).device = to_string(target_device) then
                    if element(list_of_input_cells_class_NA, positive(i)).pin = target_pin then
                        target_device_found := true;

                        write_receiver_cell(
                            device => target_device,
                            cell => element(list_of_input_cells_class_NA, positive(i)).id,
                            value => expect_low,
                            net => element(list_of_input_cells_class_NA, positive(i)).net
                            );

                        write_receiver_cell(
                            device => target_device,
                            cell => element(list_of_input_cells_class_NA, positive(i)).id,
                            value => expect_high,
                            net => element(list_of_input_cells_class_NA, positive(i)).net
                            );

                        exit; -- no more seaching required
                    end if;

                end if;
--                 class_NA := class_NA.next; -- advance pointer in list
            end loop;
		end if;

		-- If target still not found, search in static expect list.
		if not target_device_found then
            -- 			while class_static_expect /= null
            for s in 1..length(list_of_static_expect_cells) loop
                -- NOTE: element(list_of_static_expect_cells, positive(s)) meand the current expect cell
					if element(list_of_static_expect_cells, positive(s)).device = target_device then
						if element(list_of_static_expect_cells, positive(s)).pin = target_pin then
							target_device_found := true;

                            write_message (
                                file_handle => file_mkclock_messages,
                                text => "NOTE: The target pin is in class " 
                                    & type_net_class'image(element(list_of_static_expect_cells, positive(s)).class) 
                                    & " net " & to_string(element(list_of_static_expect_cells, positive(s)).net) 
                                    & "' !" & latin_1.lf
                                    & " The test is likely to fail !",
                                console => true);

							write_receiver_cell(
								device => target_device,
								cell => element(list_of_static_expect_cells, positive(s)).id,
								value => expect_low,
								net => element(list_of_static_expect_cells, positive(s)).net
								);

							write_receiver_cell(
								device => target_device,
								cell => element(list_of_static_expect_cells, positive(s)).id,
								value => expect_high,
								net => element(list_of_static_expect_cells, positive(s)).net
								);
							exit; -- no more seaching required
						end if;
					end if;
-- 					class_static_expect := class_static_expect.next; -- advance pointer in list
				end loop;
		end if;

		if target_device_found = false then
            write_message (
                file_handle => file_mkclock_messages,
                text => message_error & "target pin search failed !"
                    & latin_1.lf
                    & "Make sure the targeted pin exists and is connected to a bscan capable net !",
                console => true);
			raise constraint_error;
		end if;
		
	end atg_mkclock;



	procedure write_sequences is
    begin -- write_sequences
		write_message (
			file_handle => file_mkclock_messages,
			text => "writing test steps ...",
			console => true);
        
		new_line(file_sequence, 2);

		all_in(sample);
		write_ir_capture;
        write_sir; 
        new_line(file_sequence);

		load_safe_values;
        write_sdr; 
        new_line(file_sequence);

		case algorithm is
			when non_intrusive => null;
			--when others => all_in(extest);
			--	write_sir; new_line;
		end case;

		load_safe_values;
        write_sdr; 
        new_line(file_sequence);

		load_static_drive_values;
		load_static_expect_values;
        write_sdr; 
        new_line(file_sequence);

		atg_mkclock;

		write_end_of_test;
	end write_sequences;






-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := generate;
    test_profile := clock;
    
	-- create message/log file
 	write_log_header(version);
	
	put_line(to_upper(name_module_mkclock) & " version " & version);
	put_line("=====================================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages

	-- COMMAND LINE ARGUMENTS COLLECTING BEGIN
	prog_position	:= 10;
 	name_file_database := to_bounded_string(argument(1));
	write_message (
		file_handle => file_mkclock_messages,
		text => text_identifier_database & row_separator_0 & to_string(name_file_database),
		console => true);

	prog_position	:= 20;
	name_test := to_bounded_string(argument(2));
	write_message (
		file_handle => file_mkclock_messages,
		text => text_test_name & row_separator_0 & to_string(name_test),
		console => true);

	prog_position	:= 30;
	algorithm := type_algorithm'value(argument(3));
	write_message (
		file_handle => file_mkclock_messages,
		text => "algorithm " & type_algorithm'image(algorithm),
		console => true);
    
	prog_position	:= 40;
	target_device := to_bounded_string(argument(4));
	write_message (
		file_handle => file_mkclock_messages,
		text => "target device " & to_string(target_device),
		console => true);    
	
	prog_position	:= 50;
	target_pin:= to_bounded_string(argument(5));
	write_message (
		file_handle => file_mkclock_messages,
		text => "target pin " & to_string(target_pin),
		console => true);    
    
	prog_position	:= 60;
	retry_count:= type_sxr_retries'value(argument(6));
	write_message (
		file_handle => file_mkclock_messages,
		text => "retry count max " & type_sxr_retries'image(retry_count),
		console => true);    

	prog_position	:= 70;	
	retry_delay:= type_delay_value'value(argument(7));
	write_message (
		file_handle => file_mkclock_messages,
		text => "retry delay " & type_delay_value'image(retry_delay) & " sec",
		console => true);    
	-- COMMAND LINE ARGUMENTS COLLECTING DONE

	prog_position	:= 80;
	create_temp_directory;

	prog_position	:= 90;	
	degree_of_database_integrity_check := light;
	read_uut_database;

	put_line("start test generation ...");

	prog_position	:= 100;
	verify_target;

	prog_position	:= 110;
    create_test_directory(name_test);

	-- create sequence file
	prog_position	:= 115;
	create( file_sequence, 
		name => (compose (to_string(name_test), to_string(name_test), file_extension_sequence)));
    
	prog_position	:= 120; 
    write_info_section;
    
	prog_position	:= 130;
	write_test_section_options;

	prog_position	:= 140;
	write_test_init;

	prog_position	:= 150;
	write_sequences;

	prog_position	:= 160;
	close(file_sequence);

	prog_position	:= 170;
	write_diagnosis_netlist(
		database	=>	name_file_database,
		test        =>	name_test
		);
    set_output(standard_output);
    
	prog_position	:= 180;
    write_log_footer;

    exception when event: others =>
        set_exit_status(failure);

        write_message (
            file_handle => file_mkclock_messages,
            text => message_error & "at program position" & natural'image(prog_position),
            console => true);

        if is_open(file_sequence) then
            close(file_sequence);
        end if;

        case prog_position is
            when 10 =>
                write_message (
                    file_handle => file_mkclock_messages,
                    text => message_error & text_identifier_database & " file missing !" & latin_1.lf
                        & "Provide " & text_identifier_database & " name as argument. Example: "
                        & name_module_mkclock & row_separator_0 & example_database,
                    console => true);
            when 20 =>
				write_message (
					file_handle => file_mkclock_messages,
					text => message_error & "test name missing !" & latin_1.lf
						& "Provide test name as argument ! Example: " 
						& name_module_mkclock & row_separator_0 & example_database 
						& " my_clock_test",
					console => true);
            when 30 =>
				write_message (
					file_handle => file_mkclock_messages,
                    text => message_error & "test algorithm missing or invalid !"
                        & latin_1.lf 
                        & "Provide test algorithm as argument ! Example: "
						& name_module_mkclock & row_separator_0 & example_database 
						& " my_clock_test " & type_algorithm'image(non_intrusive),
					console => true);
                -- CS: put supported algorithms
            when 40 =>
				write_message (
					file_handle => file_mkclock_messages,
                    text => message_error & "target device missing !"
                        & latin_1.lf 
                        & "Provide target device as argument ! Example: "
						& name_module_mkclock & row_separator_0 & example_database 
						& " my_clock_test " & type_algorithm'image(non_intrusive) & "IC1701",
					console => true);
            when 50 =>
				write_message (
					file_handle => file_mkclock_messages,
                    text => message_error & "target pin missing !"
                        & latin_1.lf 
                        & "Provide target pin as argument ! Example: "
						& name_module_mkclock & row_separator_0 & example_database 
						& " my_clock_test " & type_algorithm'image(non_intrusive) & "IC1701 188",
					console => true);
            when 60 =>
				write_message (
					file_handle => file_mkclock_messages,
                    text => message_error & "Retry count missing or invalid !"
                        & latin_1.lf 
                        & "Provide retry count as argument ! Example: "
						& name_module_mkclock & row_separator_0 & example_database 
                        & " my_clock_test " & type_algorithm'image(non_intrusive) & "IC1701 188 10"
                        & latin_1.lf 
                        & "Allowed range " & type_sxr_retries'image(type_sxr_retries'first) 
                        & ".." & type_sxr_retries'image(type_sxr_retries'last),
					console => true);
            when 70 =>
				write_message (
					file_handle => file_mkclock_messages,
                    text => message_error & "Retry delay missing or invalid !"
                        & latin_1.lf 
                        & "Provide retry delay as argument ! Example: "
						& name_module_mkclock & row_separator_0 & example_database 
                        & " my_clock_test " & type_algorithm'image(non_intrusive) & "IC1701 188 10 0.5"
                        & latin_1.lf 
                        & "Allowed range:" & type_delay_value'image(type_delay_value'first) 
                        & ".." & type_delay_value'image(type_delay_value'last),
					console => true);

			when others =>
				write_message (
					file_handle => file_mkclock_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_mkclock_messages,
					text => "exception message: " & exception_message(event),
					console => true);
        end case;

        write_log_footer;
			
end mkclock;
