------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKINTERCON                          --
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


with ada.text_io;				use ada.text_io;
with ada.integer_text_io;		use ada.integer_text_io;
with ada.characters.handling; 	use ada.characters.handling;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling; 	use ada.characters.handling;

with ada.strings; 				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
with ada.numerics.elementary_functions; use ada.numerics.elementary_functions;
 
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_base;					use m1_base;
with m1_database; 				use m1_database;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories;	use m1_files_and_directories;
with m1_test_gen_and_exec;		use m1_test_gen_and_exec;
with m1_string_processing;		use m1_string_processing;

with csv;


procedure mkintercon is

	version			: string (1..3) := "001";
	prog_position	: natural := 0;

	use type_name_database;
	use type_device_name;
	use type_name_test;
	use type_list_of_bics;
	use type_list_of_atg_drive_cells;
	use type_list_of_atg_expect_cells;
	use type_net_name;
	
	type type_algorithm is ( true_complement ); -- CS: others: count_up, count_down, count_complement, walking_one, walking_zero, ...
												-- mind number of sxrs !
	algorithm 		: type_algorithm;
	end_sdr			: type_end_sdr := PDR;
	end_sir			: type_end_sir := RTI;


	procedure write_info_section is
	-- writes the info section into the sequence file

		colon_position : positive := 19;

	begin -- write_info_section
		write_message (
			file_handle => file_mkintercon_messages,
			text => "writing test info ...",
			console => false);

		put_line(file_sequence, section_mark.section & row_separator_0 & test_section.info);
		put_line(file_sequence, " created by interconnect test generator version "& version);
		put_line(file_sequence, row_separator_0 & section_info_item.date & (colon_position-(2+section_info_item.date'last)) * row_separator_0 & ": " & date_now);
		put_line(file_sequence, row_separator_0 & section_info_item.database & (colon_position-(2+section_info_item.database'last)) * row_separator_0 & ": " & to_string(name_file_database));
		put_line(file_sequence, row_separator_0 & section_info_item.name_test & (colon_position-(2+section_info_item.name_test'last)) * row_separator_0 & ": " & to_string(name_test));
		put_line(file_sequence, row_separator_0 & section_info_item.test_profile & (colon_position-(2+section_info_item.test_profile'last)) * row_separator_0 & ": " & type_test_profile'image(test_profile));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sdr & (colon_position-(2+section_info_item.end_sdr'last)) * row_separator_0 & ": " & type_end_sdr'image(end_sdr));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sir & (colon_position-(2+section_info_item.end_sir'last)) * row_separator_0 & ": " & type_end_sir'image(end_sir));

		put_line(file_sequence, section_mark.endsection); 
		new_line(file_sequence);
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
			create( matrix_csv, name => (compose (to_string(name_test), "interconnect_matrix", file_extension_csv))); 
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
-- 			atg_drive	: type_ptr_cell_list_atg_drive;	-- pointer to cell entries in list atg_drive
-- 			atg_expect	: type_ptr_cell_list_atg_expect;-- pointer to cell entries in list atg_expect
-- 			device		: type_ptr_bscan_ic; 			-- pointer to BIC list

			-- Every driver has (should have) one or more receivers. For every test step, after writing the driver in the sequence file,
			-- its receivers are collected in a list of objects type_receiver_list. The list is accessed by a pointer type_ptr_receiver_list.
			-- Since there are many drivers, an array of pointers type_ptr_receiver_list is created later.
			type type_receiver_list;
			type type_ptr_receiver_list is access all type_receiver_list;
			type type_receiver_list is
				record
					next		: type_ptr_receiver_list;				-- points to next object in list
					device		: type_device_name.bounded_string;		-- name of BIC (boundary scan IC)
					cell		: type_cell_id;							-- receiver (or input) cell
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
				device_given	: type_device_name.bounded_string;
				cell_given		: type_cell_id;
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

			bic_cursor : type_list_of_bics.cursor;

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
					put_line(file_sequence, " -- ATG step #" & trim(type_vector_id'image(step_ptr),left));

					-- WRITE DRIVERS
					-- NOTE 2: For every driver found in atg_drive list, variable driver_id increments. The following loop
					--         ends once atg_drive list has been read. So there might be less drivers than proposed by the x-axis
					--         of the interconnect_matrix. See Note 1 above.
					driver_id := 0;
					--device := ptr_bic; -- Set BIC pointer at end of list.
					--while device /= null loop
					--for b in 1..length(list_of_bics) loop
					bic_cursor := first(list_of_bics);
					while bic_cursor /= type_list_of_bics.no_element loop
						-- If device (BIC) has at least one dynamic drive cell, write sdr drive header (like "set IC301 drv boundary")
						-- In this case it appears in cell list atg_drive.

						-- NOTE: element(list_of_bics, positive(b)) means the current bic
-- 						if element(list_of_bics, positive(b)).has_dynamic_drive_cell then
-- 							put(file_sequence,
-- 								row_separator_0 & sequence_instruction_set.set & row_separator_0 &
-- 								to_string( element(list_of_bics, positive(b)).name ) & row_separator_0 &
-- 								sxr_io_identifier.drive & row_separator_0 &
-- 								sdr_target_register.boundary
-- 								);

						if element(bic_cursor).has_dynamic_drive_cell then
							put(file_sequence,
								row_separator_0 & sequence_instruction_set.set & row_separator_0 &
								to_string( key(bic_cursor) ) & row_separator_0 &
								sxr_io_identifier.drive & row_separator_0 &
								sdr_target_register.boundary
								);
							
							-- COLLECT CELL ID AND INVERTED-STATUS OF ALL DRIVERS OF THE DEVICE (BIC).
							-- The list "atg_drive" is searched for the current BIC. On match the driver cell and value are written in
							-- sequence file.
							
							--atg_drive := ptr_cell_list_atg_drive; -- Set pointer of atg_drive list at end of list.
							--while atg_drive /= null loop -- loop in list atg_drive
							for d in 1..length(list_of_atg_drive_cells) loop
								-- On BIC name match, advance driver_id.

								-- NOTE: element(list_of_atg_drive_cells, positive(c)) means the current atg drive cell
-- 								if to_string( element(list_of_atg_drive_cells, positive(d)).device ) = to_string(element(list_of_bics, positive(b)).name) then
								if element(list_of_atg_drive_cells, positive(d)).device = key(bic_cursor) then
									driver_id := driver_id + 1; -- advance driver_id for each driver cell
									put(file_sequence, type_cell_id'image(element(list_of_atg_drive_cells, positive(d)).id) 
										& sxr_assignment_operator.assign); -- write cell id and assigment operator (like "45=")

									-- Check driver/control cell / inverted-status:
									-- If the driver is a control cell, it might be inverted. This requires negation of the value taken from the interconnect_matrix.
									-- If the driver is the output cell itself, the value from the matrix remains untouched.
									if element(list_of_atg_drive_cells, positive(d)).controlled_by_control_cell then
										if element(list_of_atg_drive_cells, positive(d)).inverted then
											put_character_class_0(file => file_sequence, char_in => negate_bit_character_class_0(interconnect_matrix(driver_id,step_ptr)));
										else
											put_character_class_0(file => file_sequence, char_in => interconnect_matrix(driver_id,step_ptr));
										end if;
									else -- controlled by output cell itself
										put_character_class_0(file => file_sequence, char_in => interconnect_matrix(driver_id,step_ptr));
									end if;

									-- COLLECT RECEIVERS
									-- Note: Receivers may be inside the driver net or may be in secondary nets.
									--atg_expect := ptr_cell_list_atg_expect; -- Set pointer of atg_expect list at end of list.
									--while atg_expect /= null loop -- loop in list atg_expect
									for r in 1..length(list_of_atg_expect_cells) loop
										-- NOTE: element(list_of_atg_expect_cells, positive(r)) means the current atg expect cell
										-- ADD RECEIVERS IN PRIMARY NETS
										-- In atg_expect list, receivers are in the same net as the driver. So on net name match:
										if to_string( element(list_of_atg_expect_cells, positive(r)).net ) = to_string( element(list_of_atg_drive_cells, positive(d)).net) then
											-- add receivers to list
											add_to_receiver_list(
												list			=> receivers_of_test_step(driver_id),
												device_given	=> element(list_of_atg_expect_cells, positive(r)).device,
												cell_given		=> element(list_of_atg_expect_cells, positive(r)).id,
												expect_given	=> interconnect_matrix(driver_id,step_ptr)
												);
										end if;

										-- ADD RECEIVERS IN SECONDARY NETS:
										-- Secondary nets in list atg_expect have the selector "primary_net_is".
										if element(list_of_atg_expect_cells, positive(r)).level = secondary then
											-- On match of the primary net name, add the receiver found in the secondary net to the list of receivers.
											if to_string(element(list_of_atg_expect_cells, positive(r)).primary_net_is) = to_string(element(list_of_atg_drive_cells, positive(d)).net) then
												-- add receivers to list
												add_to_receiver_list(
													list			=> receivers_of_test_step(driver_id),
													device_given	=> element(list_of_atg_expect_cells, positive(r)).device,
													cell_given		=> element(list_of_atg_expect_cells, positive(r)).id,
													expect_given	=> interconnect_matrix(driver_id,step_ptr)
													);
											end if;
										end if;

									end loop;
								end if;

							end loop;
							new_line(file_sequence);

						end if;
						next(bic_cursor);
					end loop;


					-- WRITE RECEIVERS
					-- The receivers collected in the receiver list are now written in the sequence file.
					-- The receiver cells are written for one BIC after another. For every BIC the driver id starts at position #1.
					--for b in 1..length(list_of_bics) loop
					bic_cursor := first(list_of_bics);					
					while bic_cursor /= type_list_of_bics.no_element loop
						-- NOTE: element(list_of_bics, positive(b)) means the current bic
						
						--If device (BIC) has a dynamic expect cell, write sdr expect header. Something like "set IC301 exp boundary"
						-- if element(list_of_bics, positive(b)).has_dynamic_expect_cell then
						if element(bic_cursor).has_dynamic_expect_cell then						
							-- WRITING RECEIVERS OF A SINGLE BIC BEGIN
							put(file_sequence, 
								row_separator_0 & sequence_instruction_set.set & row_separator_0 &
								-- 								to_string(element(list_of_bics, positive(b)).name) & row_separator_0 &
								to_string(key(bic_cursor)) & row_separator_0 &
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
									--if to_string(receivers_of_test_step(driver_id).device) = to_string( element(list_of_bics, positive(b)).name ) then
									if receivers_of_test_step(driver_id).device = key(bic_cursor) then
										put(file_sequence, 
											type_cell_id'image(receivers_of_test_step(driver_id).cell) &
											sxr_assignment_operator.assign);
										put_character_class_0(file => file_sequence, char_in => receivers_of_test_step(driver_id).expect);
									end if;
									receivers_of_test_step(driver_id) := receivers_of_test_step(driver_id).next;
								end loop;

								-- Restore pointer of receivers_of_test_step(driver_id) so that it points to the last receiver again.
								-- When processing the next BIC, this pointer must point at the end of the list again.
								receivers_of_test_step(driver_id) := ptr_last_receiver_of_list; -- restore

								driver_id := driver_id + 1; -- advance driver_id
							end loop;
							new_line(file_sequence);
							-- WRITING RECEIVERS OF A SINGLE BIC FINISHED
						end if;

						next(bic_cursor);
					end loop;
					-- WRITING RECEVIERS OF ATG STEP FINISHED

					write_sdr; -- writes something like " sdr id 4" 
					new_line(file_sequence); 

					-- Advance step_ptr.
					step_ptr := step_ptr + 1; 
				end loop;
		end write_dynamic_drive_and_expect_values;

		function get_dynamic_bs_nets return natural is
			n : natural := 0;
			use type_list_of_nets;
			net_cursor : type_list_of_nets.cursor;
		begin
			net_cursor := first(list_of_nets);
			--for i in 1..positive(length(list_of_nets)) loop
			while net_cursor /= type_list_of_nets.no_element loop
-- 				if element(list_of_nets, i).class = NR 
-- 					or element(list_of_nets, i).class = PU
-- 					or element(list_of_nets, i).class = PD then
				if element(net_cursor).class = NR 
					or element(net_cursor).class = PU
					or element(net_cursor).class = PD then
					n := n + 1;
				end if;	
					
				next(net_cursor);
			end loop;
			return n;
		end get_dynamic_bs_nets;
			
		begin -- atg_mkintercon

			-- Take number of dynamic nets from udb summary.
			--dyn_ct := summary.net_count_statistics.bs_dynamic;
			dyn_ct := get_dynamic_bs_nets;
			put_line (" generating test pattern for" & natural'image(dyn_ct) & " dynamic nets (secondary nets included) ...");

			-- If there are dynamic nets to generate a pattern for, calculate required step count.
			-- Then write drive and expect values in sequence file.
			if dyn_ct > 0 then
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

						put_line(" with algorithm " & type_algorithm'image(algorithm) & type_vector_id'image(step_ct) & " steps are required"); 
-- 						new_line(file_sequence);
						write_dynamic_drive_and_expect_values (build_interconnect_matrix);
				end case;
			end if;

			-- ATG finished
		end atg_mkintercon;



	procedure write_sequences is
	begin -- write_sequences
		new_line(file_sequence,2);

		all_in(sample);

		write_ir_capture;
		write_sir; 
		new_line(file_sequence);

		load_safe_values;
		write_sdr;
		new_line(file_sequence);

		all_in(extest);
		write_sir;
		new_line(file_sequence);

		load_safe_values;
		write_sdr;
		new_line(file_sequence);

		load_static_drive_values;
		load_static_expect_values;
		write_sdr;
		new_line(file_sequence);

		put_line(" generating interconnect test pattern ...");
		atg_mkintercon;

		write_end_of_test;
	end write_sequences;







-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := generate;
	test_profile := interconnect;
	
	-- create message/log file
 	write_log_header(version);
	
	put_line(to_upper(name_module_mkintercon) & " version " & version);
	put_line("=====================================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages

	prog_position	:= 10;
 	name_file_database := to_bounded_string(argument(1));
	write_message (
		file_handle => file_mkintercon_messages,
		text => text_identifier_database & row_separator_0 & to_string(name_file_database),
		console => true);

	prog_position	:= 20;
	name_test := to_bounded_string(argument(2));
	write_message (
		file_handle => file_mkintercon_messages,
		text => text_test_name & row_separator_0 & to_string(name_test),
		console => true);

	prog_position	:= 30;
	create_temp_directory;

	prog_position	:= 40;
	-- CS: algorithm by Argument(3)
	algorithm := true_complement;
	write_message (
		file_handle => file_mkintercon_messages,
		text => "algorithm " & type_algorithm'image(algorithm),
		console => true);

	prog_position	:= 50;
	degree_of_database_integrity_check := light;
	read_uut_database;

	put_line("start test generation ...");
	
	prog_position	:= 60;
	create_test_directory(name_test);

	-- create sequence file
	prog_position	:= 70;
	create( file_sequence, 
		name => (compose (to_string(name_test), to_string(name_test), file_extension_sequence)));
	
	prog_position	:= 80; 
	write_info_section;
	
	prog_position	:= 90;
	write_test_section_options;

	prog_position	:= 100;
	write_test_init;

	prog_position	:= 110;
	write_sequences;

	prog_position	:= 130;
	close(file_sequence);

	prog_position	:= 140;
	write_diagnosis_netlist(
		database	=>	name_file_database,
		test		=>	name_test
		);
	set_output(standard_output);
	
	prog_position 	:= 150;
	write_log_footer;

	exception when event: others =>
		set_exit_status(failure);

		write_message (
			file_handle => file_mkintercon_messages,
			text => message_error & "at program position" & natural'image(prog_position),
			console => true);

		if is_open(file_sequence) then
			close(file_sequence);
		end if;

		case prog_position is
			when 10 =>
				write_message (
					file_handle => file_mkintercon_messages,
					text => message_error & text_identifier_database & " file missing !" & latin_1.lf
						& "Provide " & text_identifier_database & " name as argument. Example: "
						& name_module_mkinfra & row_separator_0 & example_database,
					console => true);
			when 20 =>
				write_message (
					file_handle => file_mkintercon_messages,
					text => message_error & "test name missing !" & latin_1.lf
						& "Provide test name as argument ! Example: " 
						& name_module_mkinfra & row_separator_0 & example_database 
						& " my_infrastructure_test",
					console => true);

			when others =>
				write_message (
					file_handle => file_mkintercon_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_mkintercon_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;
		
end mkintercon;
