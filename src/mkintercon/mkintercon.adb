------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKINTERCON                          --
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
with ada.integer_text_io;		use ada.integer_text_io;
with ada.characters.handling; 	use ada.characters.handling;

with ada.strings; 				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
with ada.numerics.elementary_functions; use ada.numerics.elementary_functions;
 
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1;
with m1_files_and_directories; use m1_files_and_directories;
with m1_internal; use m1_internal;
with m1_numbers; use m1_numbers;
with csv;


procedure mkintercon is

	version			: string (1..3) := "037";
	prog_position	: natural := 0;
	test_profile	: type_test_profile := interconnect;
	type type_algorithm is ( true_complement ); -- CS: others: count_up, count_down, count_complement, walking_one, walking_zero, ...
												-- mind number of sxrs !
	algorithm 		: type_algorithm;
	end_sdr			: type_end_sdr := PDR;
	end_sir			: type_end_sir := RTI;
	line_counter 	: natural := 0; -- counts lines in model file



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
		put_line(" created by interconnect test generator version "& version);
		put_line(row_separator_0 & section_info_item.date & (colon_position-(2+section_info_item.date'last)) * row_separator_0 & ": " & m1.date_now);
		put_line(row_separator_0 & section_info_item.data_base & (colon_position-(2+section_info_item.data_base'last)) * row_separator_0 & ": " & universal_string_type.to_string(data_base));
		put_line(row_separator_0 & section_info_item.test_name & (colon_position-(2+section_info_item.test_name'last)) * row_separator_0 & ": " & universal_string_type.to_string(test_name));
		put_line(row_separator_0 & section_info_item.test_profile & (colon_position-(2+section_info_item.test_profile'last)) * row_separator_0 & ": " & type_test_profile'image(test_profile));
		put_line(row_separator_0 & section_info_item.end_sdr & (colon_position-(2+section_info_item.end_sdr'last)) * row_separator_0 & ": " & type_end_sdr'image(end_sdr));
		put_line(row_separator_0 & section_info_item.end_sir & (colon_position-(2+section_info_item.end_sir'last)) * row_separator_0 & ": " & type_end_sir'image(end_sir));

		put_line(section_mark.endsection); 
		new_line;
	end write_info_section;



	procedure atg_mkintercon is
		exponent		: natural;
		dyn_ct_rouned	: natural;
		dyn_ct			: natural;
		step_ct			: type_vector_id; -- There can never be more ATG-Steps than vector_count_max (see m1_internal.ads).
		type type_interconnect_matrix is array (positive range <>, positive range <>) of type_bit_char_class_0;

		function build_interconnect_matrix return type_interconnect_matrix is
			--subtype type_interconnect_matrix_sized is type_interconnect_matrix (1..dyn_ct, 1..(step_ct*2));
			subtype type_interconnect_matrix_sized is type_interconnect_matrix (1..dyn_ct, 1..step_ct);
			driver_matrix	: type_interconnect_matrix_sized;
			grp_ct			: natural := 1;
			drv_high		: type_bit_char_class_0 := '1';
			drv_low			: type_bit_char_class_0 := '0';
			scratch			: natural := 1;
			drv_ptr			: natural := 1;
			grp_width		: natural := 1;
			grp_ptr			: natural := 0;
			step_ptr		: natural := 0;

			matrix_csv		: ada.text_io.file_type;
		begin
			-- PREPARE CSV FILE TO DUMP DRIVER MATRIX AT
			create( matrix_csv, name => (compose (universal_string_type.to_string(test_name), "interconnect_matrix","csv"))); 
			-- The first line contains the driver id (even if not all drivers used):
			csv.put_field(matrix_csv,"-");
			for n in 1..dyn_ct loop
				csv.put_field(matrix_csv,trim(positive'image(n),left));
			end loop;
			csv.put_lf(matrix_csv);

			case algorithm is

				when TRUE_COMPLEMENT =>

					-- CS: This procedure needs rework an a more professional approach.
					grp_width := dyn_ct;
					while grp_width > 1
						loop
							step_ptr := step_ptr + 1;
							grp_width := grp_width / 2;
							grp_ct := grp_ct * 2;
							--put ("step number : "); put (step_ptr); new_line;
							csv.put_field(matrix_csv,trim(positive'image(step_ptr),left));
							--put ("group width : "); put (grp_width); new_line;
							--put ("group count : "); put (grp_ct); new_line; new_line;

							drv_ptr := 1;
							grp_ptr := 0;
							while grp_ptr < grp_ct
								loop
									grp_ptr := grp_ptr + 1;

									scratch := 1;
									while scratch <= grp_width
										loop
											--put (scratch); new_line;
											driver_matrix (drv_ptr,step_ptr) := drv_high;
											csv.put_field(matrix_csv,"1");
											--put (driver_matrix(drv_ptr,step_ptr) & " ");
											scratch := scratch + 1;
											drv_ptr := drv_ptr + 1;
										end loop;

									grp_ptr := grp_ptr + 1;

									scratch := 1;
									while scratch <= grp_width
										loop
											--put (scratch); new_line;
											driver_matrix (drv_ptr,step_ptr) := drv_low;
											--put (driver_matrix(drv_ptr,step_ptr) & " ");
											csv.put_field(matrix_csv,"0");
											scratch := scratch + 1;
											drv_ptr := drv_ptr + 1;
										end loop;
								end loop;

							csv.put_lf(matrix_csv);
							--new_line;
						
						end loop;
			
					--put (" -- COMPLEMENT test"); new_line; new_line;
					grp_ct := 1;
					grp_width := dyn_ct;
					while grp_width > 1
						loop
							step_ptr := step_ptr + 1;
							grp_width := grp_width / 2;
							grp_ct := grp_ct * 2;
							--put ("step number : "); put (step_ptr); new_line;
							csv.put_field(matrix_csv,trim(positive'image(step_ptr),left));

							--put ("group width : "); put (grp_width); new_line;
							--put ("group count : "); put (grp_ct); new_line; new_line;

							drv_ptr := 1;
							grp_ptr := 0;
							while grp_ptr < grp_ct
								loop
									grp_ptr := grp_ptr + 1;

									scratch := 1;
									while scratch <= grp_width
										loop
											--put (scratch); new_line;
											driver_matrix (drv_ptr,step_ptr) := drv_low;
											--put (driver_matrix(drv_ptr,step_ptr) & " ");
											csv.put_field(matrix_csv,"0");
											scratch := scratch + 1;
											drv_ptr := drv_ptr + 1;
										end loop;

									grp_ptr := grp_ptr + 1;

									scratch := 1;
									while scratch <= grp_width
										loop
											--put (scratch); new_line;
											driver_matrix (drv_ptr,step_ptr) := drv_high;
											--put (driver_matrix(drv_ptr,step_ptr) & " ");
											csv.put_field(matrix_csv,"1");
											scratch := scratch + 1;
											drv_ptr := drv_ptr + 1;
										end loop;
								end loop;
							csv.put_lf(matrix_csv);
							--new_line;
						
						end loop;


			end case;

			close(matrix_csv);
			return driver_matrix;
		end build_interconnect_matrix;


		procedure write_dynamic_drive_and_expect_values ( interconnect_matrix : type_interconnect_matrix) is
		-- This procedure derives from the dimensions of the given interconnect_matrix the maximum of drivers (columns in x-axis)
		-- and the number of test steps (rows in y-axis).
		-- NOTE 1: The interconnect_matrix frequently has more columns (x) than the real number of drivers required on the UUT. The
		--         x-axis is of size 1,2,4,8,16,32,64, ... as rounded up earlier. See Note 2 below.
		-- Drivers are taken from cell list "atg_drive". Receivers are taken from cell list "atg_expect".
		-- Todo: CS: write ATG steps in detailed test coverage report (with drivers, nets and reveivers)
			step_ptr	: type_vector_id := 1; -- There can never be more ATG-Steps than vector_count_max (see m1_internal.ads).
			dyn_ct		: natural := interconnect_matrix'last(1); -- get dynamic net count from interconnect_matrix dimension x (see NOTE 1)
			step_ct		: type_vector_id := interconnect_matrix'last(2); -- get step count from interconnect_matrix dimension y
			driver_id	: natural := 0;
			atg_drive	: type_ptr_cell_list_atg_drive;	-- pointer to cell entries in list atg_drive
			atg_expect	: type_ptr_cell_list_atg_expect;-- pointer to cell entries in list atg_expect
			device		: type_ptr_bscan_ic; 			-- pointer to BIC list

			-- Every driver has (should have) one or more receivers. For every test step, after writing the driver in the sequence file,
			-- its receivers are collected in a list of objects type_receiver_list. The list is accessed by a pointer type_ptr_receiver_list.
			-- Since there are many drivers, an array of pointers type_ptr_receiver_list is created later.
			type type_receiver_list;
			type type_ptr_receiver_list is access all type_receiver_list;
			type type_receiver_list is
				record
					next		: type_ptr_receiver_list;				-- points to next object in list
					device		: universal_string_type.bounded_string;	-- name of BIC (boundary scan IC)
					cell		: type_vector_length;					-- receiver (or input) cell
					expect		: type_bit_char_class_0;				-- expect value of cell
				end record;
			
			-- Since the lists of receivers are read many times (while writing input cells in sequence file) the pointer position must be
			-- backup and restored. The end of the list (where the last receiver resides) must be saved and restored.
			ptr_last_receiver_of_list : type_ptr_receiver_list;

			-- Here we create the array of pointers of type_ptr_receiver_list. The array name is receivers_of_test_step.
			-- A copy of this brand new array is instantiated further-on. It serves to reset pointers when a new ATG step is generated.
			type type_receivers_of_test_step is array (1..dyn_ct) of type_ptr_receiver_list;
			receivers_of_test_step : type_receivers_of_test_step;
			receivers_of_test_step_init : type_receivers_of_test_step; -- used to reset pointers in receiver list

			-- This procedure is called each time a receiver is added to a receiver list.
			procedure add_to_receiver_list(
				list			: in out type_ptr_receiver_list;
				device_given	: universal_string_type.bounded_string;
				cell_given		: type_vector_length;
				expect_given	: type_bit_char_class_0
				) is
			begin
				list := new type_receiver_list'(
				next	=> list,
				device	=> device_given,
				cell	=> cell_given,
				expect	=> expect_given
				);
			end add_to_receiver_list;

		begin -- write_dynamic_drive_and_expect_values
			--put_line (" -- set dynamic drive and expect values");

			-- eloaborate matrix_current dimensions
			--put (" -- step ct : "); put (step_ct); new_line;
			--put (" -- dyn  ct : "); put (dyn_ct); new_line;

			-- GENERATE ATG STEPS BEGIN
			-- The number of ATG steps equals step_ct (number of rows in interconnect_matrix (y)).
			-- The number of drivers per ATG step is constant -> all drivers listed atg_drive list participate in test.
			while step_ptr <= step_ct
				loop
					--loop here for each ATG step

					-- Reset pointers in receiver lists (they still point to receivers from previous atg step).
					receivers_of_test_step := receivers_of_test_step_init;

					-- Write ATG step in sequence file.
					put_line(" -- ATG step #" & trim(type_vector_id'image(step_ptr),left));

					-- WRITE DRIVERS
					-- NOTE 2: For every driver found in atg_drive list, variable driver_id increments. The following loop
					--         ends once atg_drive list has been read. So there might be less drivers than proposed by the x-axis
					--         of the interconnect_matrix. See Note 1 above.
					driver_id := 0;
					device := ptr_bic; -- Set BIC pointer at end of list.
					while device /= null loop
						-- If device (BIC) has at least one dynamic drive cell, write sdr drive header (like "set IC301 drv boundary")
						-- In this case it appears in cell list atg_drive.
						if device.has_dynamic_drive_cell then
							put(
								row_separator_0 & sequence_instruction_set.set & row_separator_0 &
								universal_string_type.to_string(device.name) & row_separator_0 &
								sxr_io_identifier.drive & row_separator_0 &
								sdr_target_register.boundary
								);

							-- COLLECT CELL ID AND INVERTED-STATUS OF ALL DRIVERS OF THE DEVICE (BIC).
							-- The list "atg_drive" is searched for the current BIC. On match the driver cell and value are written in
							-- sequence file.
							atg_drive := ptr_cell_list_atg_drive; -- Set pointer of atg_drive list at end of list.
							while atg_drive /= null loop -- loop in list atg_drive
								-- On BIC name match, advance driver_id.
								if universal_string_type.to_string(atg_drive.device) = universal_string_type.to_string(device.name) then
									driver_id := driver_id + 1; -- advance driver_id for each driver cell
									put(type_vector_length'image(atg_drive.cell) & sxr_assignment_operator.assign); -- write cell id and assigment operator (like "45=")

									-- Check driver/control cell / inverted-status:
									-- If the driver is a control cell, it might be inverted. This requires negation of the value taken from the interconnect_matrix.
									-- If the driver is the output cell itself, the value from the matrix remains untouched.
									if atg_drive.controlled_by_control_cell then
										if atg_drive.inverted then
											put_character_class_0(negate_bit_character_class_0(interconnect_matrix(driver_id,step_ptr)));
										else
											put_character_class_0(interconnect_matrix(driver_id,step_ptr));
										end if;
									else -- controlled by output cell itself
										put_character_class_0(interconnect_matrix(driver_id,step_ptr));
									end if;

									-- COLLECT RECEIVERS
									-- Note: Receivers may be inside the driver net or may be in secondary nets.
									atg_expect := ptr_cell_list_atg_expect; -- Set pointer of atg_expect list at end of list.
									while atg_expect /= null loop -- loop in list atg_expect

										-- ADD RECEIVERS IN PRIMARY NETS
										-- In atg_expect list, receivers are in the same net as the driver. So on net name match:
										if universal_string_type.to_string(atg_expect.net) = universal_string_type.to_string(atg_drive.net) then
											-- add receivers to list
											add_to_receiver_list(
												list			=> receivers_of_test_step(driver_id),
												device_given	=> atg_expect.device,
												cell_given		=> atg_expect.cell,
												expect_given	=> interconnect_matrix(driver_id,step_ptr)
												);
										end if;

										-- ADD RECEIVERS IN SECONDARY NETS:
										-- Secondary nets in list atg_expect have the selector "primary_net_is".
										if atg_expect.level = secondary then
											-- On match of the primary net name, add the receiver found in the secondary net to the list of receivers.
											if universal_string_type.to_string(atg_expect.primary_net_is) = universal_string_type.to_string(atg_drive.net) then
												-- add receivers to list
												add_to_receiver_list(
													list			=> receivers_of_test_step(driver_id),
													device_given	=> atg_expect.device,
													cell_given		=> atg_expect.cell,
													expect_given	=> interconnect_matrix(driver_id,step_ptr)
													);
											end if;
										end if;

										atg_expect := atg_expect.next; -- advance pointer to next cell entry in atg_expect
									end loop;
								end if;

								atg_drive := atg_drive.next; -- advance pointer to next cell entry in atg_drive
							end loop;
							new_line;

						end if;
						device := device.next; -- advance pointer to BIC in bic list
					end loop;


					-- WRITE RECEIVERS
					-- The receivers collected in the receiver list are now written in the sequence file.
					-- The receiver cells are written for one BIC after another. For every BIC the driver id starts at position #1.
					device := ptr_bic;  -- Set BIC pointer at end of list.
					while device /= null loop

						--If device (BIC) has a dynamic expect cell, write sdr expect header. Something like "set IC301 exp boundary"
						if device.has_dynamic_expect_cell then
							-- WRITING RECEIVERS OF A SINGLE BIC BEGIN
							put(
								row_separator_0 & sequence_instruction_set.set & row_separator_0 &
								universal_string_type.to_string(device.name) & row_separator_0 &
								sxr_io_identifier.expect & row_separator_0 &
								sdr_target_register.boundary
								);

							-- For the current BIC: We start with the receivers connected with driver #1.
							-- Set pointer in array receivers_of_test_step to first position.
							driver_id := 1;

							-- Loop here as often as interconnect_matrix has columns (even if is has more than actually required).
							while driver_id <= dyn_ct loop -- CS: reduce the loops by using the number of drivers found above 

								-- For the current driver position, the list of connected receivers is read.
								-- But first, we must backup the pointer position receivers_of_test_step(driver_id) as it is pointing
								-- to the end of the list.
								ptr_last_receiver_of_list := receivers_of_test_step(driver_id); -- backup

								-- Read the receiver list and filter the receiver cells of the current BIC.
								while receivers_of_test_step(driver_id) /= null loop
									-- On match of BIC name: write the receiver cells of the current BIC in the sequence file (like "44=0 46=1 ..."
									if universal_string_type.to_string(receivers_of_test_step(driver_id).device) = universal_string_type.to_string(device.name) then
										put(
											type_vector_length'image(receivers_of_test_step(driver_id).cell) &
											sxr_assignment_operator.assign);
										put_character_class_0(receivers_of_test_step(driver_id).expect);
									end if;
									receivers_of_test_step(driver_id) := receivers_of_test_step(driver_id).next;
								end loop;

								-- Restore pointer of receivers_of_test_step(driver_id) so that it points to the last receiver again.
								-- When processing the next BIC, this pointer must point at the end of the list again.
								receivers_of_test_step(driver_id) := ptr_last_receiver_of_list; -- restore

								driver_id := driver_id + 1; -- advance driver_id
							end loop;
							new_line;
							-- WRITING RECEIVERS OF A SINGLE BIC FINISHED
						end if;
						device := device.next; -- advance BIC pointer
					end loop;
					-- WRITING RECEVIERS OF ATG STEP FINISHED

					write_sdr; new_line; -- writes something like " sdr id 4"

					-- Advance step_ptr.
					step_ptr := step_ptr + 1; 
				end loop;
		end write_dynamic_drive_and_expect_values;


		begin -- atg_mkintercon

			-- Take number of dynamic nets from udb summary.
			dyn_ct := summary.net_count_statistics.bs_dynamic;
			put_line (" -- generating test pattern for" & natural'image(dyn_ct) & " dynamic nets (secondary nets included) ...");

			-- If there are dynamic nets to generate a pattern for, calculate required step count.
			-- Then write drive and expect values in sequence file.
			if dyn_ct > 0 then
				put(" -- steps required for algorithm ");
				case algorithm is
					when TRUE_COMPLEMENT =>

						-- round up dynamic net count to next member in sequence 1,2,4,8,16,32,64, ...
						dyn_ct_rouned := 0;
						exponent := 0;
						while dyn_ct_rouned < dyn_ct
							loop
								exponent := exponent + 1;
								dyn_ct_rouned := 2 ** exponent;
							end loop;
						dyn_ct := dyn_ct_rouned;

						step_ct := 2 * natural(float'ceiling( log (base => 2.0, X => float(dyn_ct) ) ) ); -- logarithmic compression
						-- Step count is to be doubled because the algorithm is "true_complement".

						put_line(type_algorithm'image(algorithm) & ":" & type_vector_id'image(step_ct)); new_line;
						write_dynamic_drive_and_expect_values (build_interconnect_matrix);
				end case;
			end if;

			-- ATG finished
		end atg_mkintercon;



	procedure write_sequences is
		--lut_step_id		: positive;
		--lut_step 		: type_get_step_from_lut_result;
	begin -- write_sequences
		new_line(2);

		all_in(sample);
		write_ir_capture;
		write_sir; new_line;

		load_safe_values;
		write_sdr; new_line;

		all_in(extest);
		write_sir; new_line;

		load_safe_values;
		write_sdr; new_line;

		load_static_drive_values;
		load_static_expect_values;
		write_sdr; new_line;

		atg_mkintercon;

		write_end_of_test;
	end write_sequences;







-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin

	put_line("interconnect test generator version "& version);
	put_line("=====================================================");

	-- COMMAND LINE ARGUMENTS COLLECTING BEGIN
	prog_position	:= 10;
 	data_base:= universal_string_type.to_bounded_string(Argument(1));
 	put_line ("data base      : " & universal_string_type.to_string(data_base));
 
	prog_position	:= 20;
 	test_name:= universal_string_type.to_bounded_string(Argument(2));
 	put_line ("test name      : " & universal_string_type.to_string(test_name));

	prog_position	:= 30;
	-- CS: algorithm by Argument(3)
	algorithm := true_complement;
	put_line ("algorithm      : " & type_algorithm'image(algorithm));
	

	prog_position	:= 40;
	if argument_count = 3 then
		debug_level := natural'value(argument(3));
		put_line("debug level    :" & natural'image(debug_level));
	end if;
	-- COMMAND LINE ARGUMENTS COLLECTING DONE
	
	read_data_base;

	prog_position	:= 70;
 	create_temp_directory;
	
	prog_position	:= 80;
	create_test_directory(
		test_name 			=> universal_string_type.to_string(test_name),
		warnings_enabled 	=> false
		);

	prog_position	:= 90; 
	write_info_section;
	prog_position	:= 100;
	write_test_section_options;

	prog_position	:= 110;
	write_test_init;

	prog_position	:= 120;
	write_sequences;

	prog_position	:= 130;
	set_output(standard_output);

	prog_position	:= 140;
	close(sequence_file);

	prog_position	:= 150;
	write_diagnosis_netlist(
		data_base	=>	universal_string_type.to_string(data_base),
		test_name	=>	universal_string_type.to_string(test_name)
		);


	exception
		when event: others =>
			set_output(standard_output);
			set_exit_status(failure);
			case prog_position is
				when 10 =>
					put_line("ERROR: Data base file missing or insufficient access rights !");
					put_line("       Provide data base name as argument. Example: mkmemcon my_uut.udb");
				when 20 =>
					put_line("ERROR: Test name missing !");
					put_line("       Provide test name as argument ! Example: mkmemcon my_uut.udb my_memory_test");

				when 40 =>
					put_line("ERROR: Invalid argument for debug level. Debug level must be provided as natural number !");


				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & natural'image(prog_position));
			end case;

			
end mkintercon;
