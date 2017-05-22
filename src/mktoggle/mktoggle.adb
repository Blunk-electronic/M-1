------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKTOGGLE                            --
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

-- todo: option/algorithm for reading back the target net


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


procedure mktoggle is

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
    use type_list_of_atg_drive_cells;
--     use type_list_of_input_cells_class_NA;
--     use type_list_of_static_expect_cells;

    target_net		: type_net_name.bounded_string;

	end_sdr			: type_end_sdr := PDR;
	end_sir			: type_end_sir := RTI;
    
	cycle_count_max	: constant positive := 20; -- CS: increase if neccessary. Greater values not reasonable.
	subtype type_cycle_count is positive range 1..cycle_count_max;
	cycle_count		: type_cycle_count;
	low_time		: type_delay_value;
	high_time		: type_delay_value;
	frequency		: float; -- CS: limit accuracy to a reasonable value
	




	procedure write_info_section is
	-- creates the sequence file,
	-- directs subsequent puts into the sequence file
	-- writes the info section into the sequence file

		colon_position : positive := 19;

	begin -- write_info_section
		put_line(file_sequence, section_mark.section & row_separator_0 & test_section.info);
		put_line(file_sequence, " created by " & name_module_mktoggle & " version "& version);
		put_line(file_sequence, row_separator_0 & section_info_item.date & (colon_position-(2+section_info_item.date'last)) * row_separator_0 & ": " & date_now);
		put_line(file_sequence, row_separator_0 & section_info_item.database & (colon_position-(2+section_info_item.database'last)) * row_separator_0 & ": " & to_string(name_file_database));
		put_line(file_sequence, row_separator_0 & section_info_item.name_test & (colon_position-(2+section_info_item.name_test'last)) * row_separator_0 & ": " & to_string(name_test));
		put_line(file_sequence, row_separator_0 & section_info_item.test_profile & (colon_position-(2+section_info_item.test_profile'last)) * row_separator_0 & ": " & type_test_profile'image(test_profile));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sdr & (colon_position-(2+section_info_item.end_sdr'last)) * row_separator_0 & ": " & type_end_sdr'image(end_sdr));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sir & (colon_position-(2+section_info_item.end_sir'last)) * row_separator_0 & ": " & type_end_sir'image(end_sir));

		put_line(file_sequence, row_separator_0 & section_info_item.target_net & (colon_position-(2+section_info_item.target_net'last)) * row_separator_0 & ": " & to_string(target_net));
		put_line(file_sequence, row_separator_0 & section_info_item.cycle_count & (colon_position-(2+section_info_item.cycle_count'last)) * row_separator_0 & ":" & type_cycle_count'image(cycle_count));
		put_line(file_sequence, row_separator_0 & section_info_item.low_time & (colon_position-(2+section_info_item.low_time'last)) * row_separator_0 & ":" & type_delay_value'image(low_time) & " sec");
		put_line(file_sequence, row_separator_0 & section_info_item.high_time & (colon_position-(2+section_info_item.high_time'last)) * row_separator_0 & ":" & type_delay_value'image(high_time) & " sec");
		put_line(file_sequence, row_separator_0 & section_info_item.frequency & (colon_position-(2+section_info_item.frequency'last)) * row_separator_0 & ":" & float'image(frequency) & " Hz");

		put_line(file_sequence, section_mark.endsection); 
		new_line(file_sequence);
	end write_info_section;




 	procedure atg_mktoggle is
	-- search in cell list atg_drive
		target_net_found	: boolean := false;
		drv_high			: type_bit_char_class_0 := '1';
		drv_low				: type_bit_char_class_0 := '0';
		driver_inverted		: boolean;

		procedure write_driver_cell(
			device 		: in type_device_name.bounded_string;
			cell 		: in type_cell_id;
			value 		: in type_bit_char_class_0;
			inverted	: in boolean := false;
			dely		: in type_delay_value
			) is
		begin
			if not inverted then
                put(file_sequence, row_separator_0 & comment & " drive "); 
			else
                put(file_sequence, row_separator_0 & comment & " drive (inverted) ");
			end if;
            put_character_class_0(file => file_sequence, char_in => value); 
            new_line(file_sequence);
            
			put(file_sequence, -- write sdr drive header (like "set IC301 drv boundary")
                row_separator_0 & sequence_instruction_set.set & row_separator_0 
                & to_string(device) & row_separator_0 & sxr_io_identifier.drive & row_separator_0 
                & sdr_target_register.boundary & type_cell_id'image(cell) 
                & sxr_assignment_operator.assign -- write cell id and assigment operator (like "45=")
				);

			-- write drive value
			if not inverted then
                put_character_class_0(file => file_sequence, char_in => value); 
			else
                put_character_class_0(file => file_sequence, char_in => negate_bit_character_class_0(value)); 
			end if;
			new_line(file_sequence);

            write_sdr; 
            new_line(file_sequence);
            put_line(file_sequence, row_separator_0 & sequence_instruction_set.dely & type_delay_value'image(dely)); 
            new_line(file_sequence);
		end write_driver_cell;

		procedure write_cycle (cycle : in type_cycle_count) is
		begin
			put_line(file_sequence, row_separator_0 & "----- cycle" & type_cycle_count'image(cycle) & " -----------------------" ); 
			new_line(file_sequence);
		end write_cycle;

	begin
		-- search in atg_drive list for target_net
        for d in 1..length(list_of_atg_drive_cells) loop
        -- NOTE: element(list_of_atg_drive_cells, positive(d)) means the current drive cell
            if to_string(element(list_of_atg_drive_cells, positive(d)).net) = to_string(target_net) then
                target_net_found := true;
                put_line(file_sequence, row_separator_0 & comment & type_cycle_count'image(cycle_count) & " cycles of LH follow ...");
                new_line(file_sequence);
                --put_line(column_separator_0);

                case element(list_of_atg_drive_cells, positive(d)).class is
                    when NR =>
                        -- CS: get init value from safebits

                        for n in 1..cycle_count
                            loop
                                write_cycle(n);
                                write_driver_cell(
                                    --cycle => n,
                                    device => element(list_of_atg_drive_cells, positive(d)).device,
                                    cell => element(list_of_atg_drive_cells, positive(d)).id,
                                    value => drv_low,
                                    dely => low_time
                                    );

                                write_driver_cell(
                                    --cycle => n,
                                    device => element(list_of_atg_drive_cells, positive(d)).device,
                                    cell => element(list_of_atg_drive_cells, positive(d)).id,
                                    value => drv_high,
                                    dely => high_time
                                    );
                            end loop;

                    when PU | PD => null;
                        -- CS: get init value from safebits

                        -- Pull-nets frequently are controlled by a control cell. If the cell is to be inverted
                        -- a flag is set. When assigning the drive value is is read.
                        if element(list_of_atg_drive_cells, positive(d)).controlled_by_control_cell then
                            if element(list_of_atg_drive_cells, positive(d)).inverted then
                                driver_inverted := true; -- control cell must be inverted
                            else 
                                driver_inverted := false; -- control cell must not be inverted
                            end if;
                        else -- net driven by output cell
                            driver_inverted := false; -- control cell must not be inverted
                        end if;

                        for n in 1..cycle_count
                            loop
                                write_cycle(n);
                                write_driver_cell(
                                    device => element(list_of_atg_drive_cells, positive(d)).device,
                                    cell => element(list_of_atg_drive_cells, positive(d)).id,
                                    value => drv_low,
                                    inverted => driver_inverted,
                                    dely => low_time
                                    );

                                write_driver_cell(
                                    device => element(list_of_atg_drive_cells, positive(d)).device,
                                    cell => element(list_of_atg_drive_cells, positive(d)).id,
                                    value => drv_high,
                                    inverted => driver_inverted,
                                    dely => high_time
                                    );
                            end loop;

                    when others => raise constraint_error; -- should never happen as nets in atg_drive are in class NR,PD or PU anyway
                end case;
            end if;
        end loop;
				
		-- target net found ?
		if target_net_found = false then
			write_message (
				file_handle => file_mktoggle_messages,
				text => message_error & "target net " & to_string(target_net) 
					& " search failed !" & latin_1.lf 
					& "make sure target net is:" & latin_1.lf 
					& " 1. a primary net !" & latin_1.lf
					& " 2. in class NR, PU or PD !", -- CS: use images of type net class
				console => true);
			raise constraint_error;
		end if;
		
	end atg_mktoggle;



	procedure write_sequences is
	begin -- write_sequences
		new_line(file_sequence,2);

		all_in(sample);
		write_ir_capture;
		write_sir; 
		new_line(file_sequence);

        load_safe_values;
-- CS: instead for safe values, the values of the database should be used ?
-- 		load_static_drive_values;
-- 		load_static_expect_values;
        
		write_sdr;
		new_line(file_sequence);

		all_in(extest);
		write_sir;
		new_line(file_sequence);

		load_safe_values;
-- 		load_static_drive_values;
-- 		load_static_expect_values;
		write_sdr;
		new_line(file_sequence);

		load_static_drive_values;
		load_static_expect_values;
		write_sdr;
		new_line(file_sequence);

		atg_mktoggle;

		write_end_of_test;
	end write_sequences;






-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := generate;
	test_profile := toggle;

	-- create message/log file
 	write_log_header(version);

	put_line(to_upper(name_module_mktoggle) & " version " & version);
	put_line("===========================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages

	-- COMMAND LINE ARGUMENTS COLLECTING BEGIN
	prog_position	:= 10;
 	name_file_database := to_bounded_string(argument(1));

	write_message (
		file_handle => file_mktoggle_messages,
		text => text_identifier_database & row_separator_0 & to_string(name_file_database),
		console => true);

	prog_position	:= 20;
	name_test := to_bounded_string(argument(2));
	write_message (
		file_handle => file_mktoggle_messages,
		text => text_test_name & row_separator_0 & to_string(name_test),
		console => true);

	prog_position	:= 30;
	target_net:= to_bounded_string(argument(3));
	write_message (
		file_handle => file_mktoggle_messages,
		text => "target net " & to_string(target_net),
		console => true);

	prog_position	:= 40;
	cycle_count:= type_cycle_count'value(argument(4));
	write_message (
		file_handle => file_mktoggle_messages,
		text => "cycles" & type_cycle_count'image(cycle_count),
		console => true);
	
	prog_position	:= 50;
	low_time:= type_delay_value'value(argument(5));
	write_message (
		file_handle => file_mktoggle_messages,
		text => "low time" & type_delay_value'image(low_time) & " sec",
		console => true);
	
	prog_position	:= 60;
	high_time:= type_delay_value'value(argument(6));
	write_message (
		file_handle => file_mktoggle_messages,
		text => "high time" & type_delay_value'image(high_time) & " sec",
		console => true);

	prog_position	:= 70;	
	frequency := 1.0/(high_time + low_time);
	write_message (
		file_handle => file_mktoggle_messages,
		text => "frequency" & float'image(frequency) & " Hz",
		console => true);
	-- COMMAND LINE ARGUMENTS COLLECTING DONE

	prog_position	:= 80;
	create_temp_directory;

	prog_position	:= 90;
	degree_of_database_integrity_check := light;
	read_uut_database;
	
	prog_position	:= 110;
	create_test_directory(name_test);

	-- create sequence file
	prog_position	:= 120;
	create( file_sequence, 
		name => (compose (to_string(name_test), to_string(name_test), file_extension_sequence)));
	
	prog_position	:= 130; 
	write_info_section;

	prog_position	:= 140;
	write_test_section_options;

	prog_position	:= 150;
	write_test_init;

	prog_position	:= 160;
	write_sequences;

	prog_position	:= 170;
	close(file_sequence);

	prog_position	:= 180;
	write_diagnosis_netlist(
		database	=>	name_file_database,
		test		=>	name_test
		);
	set_output(standard_output);
	
	prog_position	:= 190;
	write_log_footer;

	exception when event: others =>
		set_exit_status(failure);

		write_message (
			file_handle => file_mktoggle_messages,
			text => message_error & "at program position" & natural'image(prog_position),
			console => true);

		if is_open(file_sequence) then
			close(file_sequence);
		end if;

		case prog_position is
			when 10 =>
				write_message (
					file_handle => file_mktoggle_messages,
					text => message_error & text_identifier_database & " file missing !" & latin_1.lf
						& "Provide " & text_identifier_database & " name as argument. Example: "
						& name_module_mktoggle & row_separator_0 & example_database,
					console => true);
			when 20 =>
				write_message (
					file_handle => file_mktoggle_messages,
					text => message_error & "test name missing !" & latin_1.lf
						& "Provide test name as argument ! Example: " 
						& name_module_mktoggle & row_separator_0 & example_database 
						& " my_toggle_test",
					console => true);

			when 30 =>
				write_message (
					file_handle => file_mktoggle_messages,
					text => message_error & " target net not specified !" & latin_1.lf
						& "Provide target net as argument. Example: "
						& name_module_mktoggle & row_separator_0 & example_database
						& " my_toggle_test motor_on_off",
					console => true);

			when 40 =>
				write_message (
					file_handle => file_mktoggle_messages,
					text => message_error & "invalid cycle count specified " & latin_1.lf
						& "Provide number of cycles as argument. Example: "
						& name_module_mktoggle & row_separator_0 & example_database
						& " my_toggle_test motor_on_off 5" 
						& latin_1.lf
						& "Allowed range:" & type_cycle_count'image(type_cycle_count'first) 
						& ".." & type_cycle_count'image(type_cycle_count'last) & " !",
					console => true);

			when 50 =>
				write_message (
					file_handle => file_mktoggle_messages,
					text => message_error & "invalid low time specified " & latin_1.lf
						& "Provide low time as argument. Example: "
						& name_module_mktoggle & row_separator_0 & example_database
						& " my_toggle_test motor_on_off 5 2" 
						& latin_1.lf
						& "Allowed range:" & type_delay_value'image(type_delay_value'first) 
						& ".." & type_delay_value'image(type_delay_value'last) & " !",
					console => true);

			when 60 =>
				write_message (
					file_handle => file_mktoggle_messages,
					text => message_error & "invalid high time specified " & latin_1.lf
						& "Provide high time as argument. Example: "
						& name_module_mktoggle & row_separator_0 & example_database
						& " my_toggle_test motor_on_off 5 2 3" 
						& latin_1.lf
						& "Allowed range:" & type_delay_value'image(type_delay_value'first) 
						& ".." & type_delay_value'image(type_delay_value'last) & " !",
					console => true);

			when others =>
				write_message (
					file_handle => file_mktoggle_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_mktoggle_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;

end mktoggle;
