-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 TEST GENERATION AND EXECUTION              --
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
--with m1_database;				use m1_database;
with ada.text_io;				use ada.text_io;
with ada.characters;			use ada.characters;
with ada.characters.handling;	use ada.characters.handling;
with ada.strings;		 		use ada.strings;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.directories;			use ada.directories;

with interfaces;

with ada.containers;            use ada.containers;
with ada.containers.vectors;

with m1_base;	 				use m1_base;
with m1_string_processing;		use m1_string_processing;
with m1_serial_communications;

package body m1_test_gen_and_exec is

-- ATG memory connect
	function fraction_port_name(port_name_given : string) return type_port_vector is
	-- breaks down something line A[14:0] into the components name=A, msb=14, lsb=0 and length=15
	-- if a single port given like 'CE', the components are name=CE, msb=0, lsb=0 and length=1
 		length		: natural := port_name_given'last;
		ob			: string (1..1) := "[";
		cb			: string (1..1) := "]";
		ifs			: string (1..1) := ":";
		pos_ob		: positive;
		pos_cb		: positive;
		pos_ifs		: positive;
		ct_ifs		: natural := ada.strings.fixed.count(port_name_given,ifs);
		ct_ob		: natural := ada.strings.fixed.count(port_name_given,ob);
		ct_cb		: natural := ada.strings.fixed.count(port_name_given,cb);
		port_vector	: type_port_vector;
	begin
		if ct_ob = 1 and ct_cb = 1 and ct_ifs = 1 then -- it seems like a vector

			-- get position of opening, closing bracket and ifs to verify syntax
			pos_ob  := ada.strings.fixed.index(port_name_given,ob);
			pos_cb  := ada.strings.fixed.index(port_name_given,cb);
			pos_ifs := ada.strings.fixed.index(port_name_given,ifs);

			-- the opening bracket must be on position greater 1 -- example ADR[14:0]
			-- the closing bracket must be on last position
			if pos_ob > 1 and pos_cb = length then

				-- ifs must be within brackets, but not next to a bracket
				-- MSB is always on the left, LSB always on the left
				if pos_ifs > pos_ob + 1 and pos_ifs < pos_cb - 1 then
					port_vector.msb := positive'value(port_name_given (pos_ob+1 .. pos_ifs-1)); -- msb is always non-zero
					port_vector.lsb := natural'value(port_name_given (pos_ifs+1 .. pos_cb-1));

					-- msb must be greater than lsb
					if port_vector.msb > port_vector.lsb then
						-- the port name is from pos. 1 to opening bracket
						port_vector.name := type_port_name.to_bounded_string(port_name_given (port_name_given'first .. pos_ob-1));
					else
						raise constraint_error;
					end if;
				else
					raise constraint_error;
				end if;
			else
				raise constraint_error;
			end if;


		elsif ct_ob = 0 and ct_cb = 0 and ct_ifs = 0 then -- it is a single port (no vector)
			-- copy port_name_given as it is in port_name_given.name
			-- and set msb equal to lsb to indicate a non-vector port
			port_vector.name := type_port_name.to_bounded_string(port_name_given);
			port_vector.msb := 0;
			port_vector.lsb := 0;
		
		else -- other bracket counts are invalid
			raise constraint_error;
		end if;

		-- calculate vector length. in case of a single port, the length becomes 1
		port_vector.length := port_vector.msb - port_vector.lsb + 1;
		return port_vector;
	end fraction_port_name;


-- TEST STATUS
	function test_compiled (name_test : string) return boolean is
	-- Returns true if given test directory contains a vector file.
	-- name_test is assumed as absolute path !
	begin
		--put_line(name_test & row_separator_0 & simple_name(name_test) & row_separator_0 & file_extension_vector);
		if exists (compose (name_test, simple_name(name_test), file_extension_vector)) then
			return true;
		end if;
		return false;
	end test_compiled;

	function valid_script (name_script : string) return boolean is
	-- Returns true if given script is valid.
	begin
		if extension(name_script) = file_extension_script then
			-- CS: check more criteria
			return true;
		end if;
		return false;
	end valid_script;

	function valid_project (name_project : string) return boolean is
	-- Returns true if given project is valid.
	-- name_project is assumed as absolute path !
	begin
		if exists(compose (name_project, name_file_project_description)) then
			-- CS: check more criteria
			return true;
		end if;
		return false;
	end valid_project;

	procedure create_test_directory (test_name : in type_name_test.bounded_string) is
		
		use type_name_test;
		
-- 		file_output 		: ada.text_io.file_type;
	begin
		-- check if test exists 
-- 		if warnings_enabled then
-- 			new_line;
-- 			put_line("checking if test directory exists already ...");
-- 			new_line;
-- 		end if;

		-- create directory and description file
		
		if exists (to_string(test_name)) then -- if test directory exists
			put_line("deleting old test directory ...");
-- 			if exists (compose (to_string(test_name), to_string(test_name) , file_extension_sequence)) then -- if seq file exists

-- 				if warnings_enabled then
-- 					put_line("WARNING: Specified test already exists !");
-- 					put_line("         All test data will be overwritten !");
-- 
-- 					-- CS: retain description file ?
-- 					if request_user_confirmation(question_form => 0, show_confirmation_dialog => true) then
						delete_tree(to_string(test_name));
-- 					else
-- 						raise program_error;
-- 					end if;
-- 				else
-- 					if request_user_confirmation(question_form => 0, show_confirmation_dialog => false) then
-- 						delete_tree(to_string(test_name));
-- 					else
-- 						raise program_error;
-- 					end if;
-- 				end if; -- if warnings_enabled

-- 			else -- directory exists, but no seq file
-- 
-- 				if warnings_enabled then
-- 
-- 					put_line("WARNING: Specified directory does not contain test data !");
-- 					put_line("         All contents will be deleted !");
-- 
-- 					if request_user_confirmation(question_form => 0, show_confirmation_dialog => true) then
-- 						delete_tree(to_string(test_name));
-- 					else
-- 						raise program_error;
-- 					end if;
-- 				else
-- 					if request_user_confirmation(question_form => 0, show_confirmation_dialog => true) then
-- 						delete_tree(to_string(test_name));
-- 					else
-- 						raise program_error;
-- 					end if;
-- 				end if;

-- 			end if;
		end if;  -- if test directory exists

		put_line("creating test directory ...");
		create_directory(to_string(test_name));
-- 		create( file_output, name => (compose (to_string(test_name),"readme","txt"))); 
-- 		put (file_output,"Test description: write your info here ... ");
-- 		close(file_output);
	end create_test_directory;

	procedure write_diagnosis_netlist
		(
		-- Creates a netlist file in test directory.
		-- The fail diagnosis bases on this netlist.
		database	: type_name_database.bounded_string;
		test 		: type_name_test.bounded_string
		) is

		type_line_length_max	: constant natural := 20000;
		package type_line_of_file is new generic_bounded_length(type_line_length_max); use type_line_of_file;
		line : type_line_of_file.bounded_string;
		section_entered	: boolean := false;
	begin
		-- for the logs:
		put_line("writing netlist for diagnosis ...");

		create( file_test_netlist, name => compose (type_name_test.to_string(test), name_file_test_netlist));
		open(file => file_database, name => type_name_database.to_string(database), mode => in_file);

		while not end_of_file(file_database) 
			loop
				line := to_bounded_string(remove_comment_from_line(get_line(file_database))); -- CS: trim line
				if get_field_count(to_string(line)) > 0 then -- if line contains anything
					if section_entered then
						-- inside section, look for EndSection mark to clear section_entered flag
						if index(to_string(line),section_mark.endsection) > 0 then
							section_entered := false;
							put_line(file_test_netlist, to_string(line)); -- section header should also go into the netlist
						else
							-- write line in netlist
							put_line(file_test_netlist, to_string(line));
						end if;
					else
						-- if "Section netlist" found, set section_entered flag
						if index(to_string(line),section_mark.section & row_separator_0 & section_netlist) > 0 then
							section_entered := true;
							put_line(file_test_netlist, to_string(line)); -- section footer should also go into the netlist
						end if;
					end if;
				end if;
			end loop;
	end write_diagnosis_netlist;


	procedure write_test_section_options is
	-- writes section for options of test
		sp : type_scanport;

		function trailer_to_string (trailer_in : type_trailer_sxr) return string is
			-- converts given trailer character wise to a string
			trailer_out : string (1..trailer_length);
		begin
			for t in 1..trailer_length loop
				case trailer_in(t) is
					when '0' => trailer_out(t) := type_bit_char_class_0'image('0')(2); -- (2) strips delimiters
					when '1' => trailer_out(t) := type_bit_char_class_0'image('1')(2);
				end case;
			end loop;
			return trailer_out;
		end trailer_to_string;

	begin
		put_line("writing test options ...");
		new_line(file_sequence);
		put_line(file_sequence, section_mark.section & " options");
		put_line(file_sequence, " on_fail " & to_lower(type_on_fail_action'image(scanport_options_global.on_fail_action)));
		put_line(file_sequence, " frequency" & type_tck_frequency'image(scanport_options_global.tck_frequency)); 
		put_line(file_sequence, " trailer_ir " & trailer_to_string(scanport_options_global.trailer_sir));
		put_line(file_sequence, " trailer_dr " & trailer_to_string(scanport_options_global.trailer_sdr));

		-- put scanport options for active/used scanports only
		-- start search with port 1
		for s in 1..type_list_of_scanports.length(list_of_scanports) loop
			sp := type_list_of_scanports.element(list_of_scanports, positive(s));
			if sp.active then
				put_line(file_sequence, " voltage_out_port_"   & trim(ada.containers.count_type'image(s),left) & type_voltage_out'image(sp.voltage_out));
				put_line(file_sequence, " tck_driver_port_"    & trim(ada.containers.count_type'image(s),left) & row_separator_0 & to_lower(type_driver_characteristic'image(sp.characteristic_tck_driver)));
				put_line(file_sequence, " tms_driver_port_"    & trim(ada.containers.count_type'image(s),left) & row_separator_0 & to_lower(type_driver_characteristic'image(sp.characteristic_tms_driver))); 
				put_line(file_sequence, " tdo_driver_port_"    & trim(ada.containers.count_type'image(s),left) & row_separator_0 & to_lower(type_driver_characteristic'image(sp.characteristic_tdo_driver))); 
				put_line(file_sequence, " trst_driver_port_"   & trim(ada.containers.count_type'image(s),left) & row_separator_0 & to_lower(type_driver_characteristic'image(sp.characteristic_trst_driver)));
				put_line(file_sequence, " threshold_tdi_port_" & trim(ada.containers.count_type'image(s),left) & type_threshold_tdi'image(sp.voltage_threshold_tdi));
			end if;
		end loop;
		put_line(file_sequence, section_mark.endsection);
	end write_test_section_options;

	procedure write_test_init is
	-- append test init template file line by line to seq file

		type_line_length_max	: constant natural := 1000;
		package type_line_of_file is new generic_bounded_length(type_line_length_max); use type_line_of_file;
		line : type_line_of_file.bounded_string;

	begin
		put_line("writing test-init sequence ...");
		new_line(file_sequence);
		put_line(file_sequence, section_mark.section & " sequence 1"); -- because the init sequence is always sequence 1

		-- look which test init templates are available
		-- first, look for the customized template
		if exists(compose (name_directory_setup_and_templates, name_file_test_init_template)) then
			open( 
				file => file_test_init_template, 
				name => compose (name_directory_setup_and_templates, name_file_test_init_template),
				mode => in_file
				);
		else 
			put_line(message_warning & "no customized test-init template found in directory '" 
				& name_directory_setup_and_templates & "' ! Using default ...");

			if exists( compose (name_directory_setup_and_templates, name_file_test_init_template_default)) then
				open( 
					file => file_test_init_template, 
					name => (compose (name_directory_setup_and_templates, name_file_test_init_template_default)),
					mode => in_file
					);
			else
				write_message (
					file_handle => current_output,
					text => message_error & "no test-init template found !",
					console => true);
				raise constraint_error;
			end if;
		end if;

		-- copy test-init template in sequence file
		while not end_of_file(file_test_init_template) loop
			line := to_bounded_string(get_line(file_test_init_template));
			put_line(file_sequence, to_string(line));
		end loop;

	end write_test_init;

	procedure write_end_of_test is
	begin
		-- for the logs:
		put_line(" writing end of test ...");
		
		new_line(file_sequence);
		put_line(file_sequence, "-- finish test (uncomment commands if required)");
		put_line(file_sequence, row_separator_0 & sequence_instruction_set.trst);
		put_line(file_sequence, comment & row_separator_0 & sequence_instruction_set.power
			& row_separator_0 & power_cycle_identifier.down
			& row_separator_0 & power_channel_name.all_channels);

		for s in 1..scanport_count_max loop
			put_line(file_sequence, comment & row_separator_0 & sequence_instruction_set.disconnect & row_separator_0
				& scanport_identifier.port
				& positive'image(s));
		end loop;
		put_line(file_sequence, section_mark.endsection);
	end write_end_of_test;

	
	procedure put_warning_on_too_many_parameters(line_number : in positive) is
	begin
		put_line(message_warning & "too many parameters in line" & positive'image(line_number) & " ! Excessive parameters may be ignored !");
	end put_warning_on_too_many_parameters;


	procedure write_sir (with_new_line : in boolean := true) is
	-- writes something like "sir id 6", increments sxr_ct, by default adds a line break
	begin
		-- write sir instruction -- example: "sir id 6"
-- 		put(file_sequence, row_separator_0 & to_upper(sequence_instruction_set.sir) & sxr_id_identifier.id & type_vector_id'image(sxr_ct));
		put(file_sequence, row_separator_0 & type_scan'image(sir) 
			& row_separator_0 & sxr_id_identifier.id & type_vector_id'image(sxr_ct));
		if with_new_line then
			new_line(file_sequence);
		end if;
		sxr_ct := sxr_ct + 1;
	end write_sir;

	procedure write_sdr (with_new_line : in boolean := true) is
	-- writes something like "sdr id 6", increments sxr_ct, by default adds a line break
	begin
		-- write sdr instruction -- example: "sdr id 6"
-- 		put(file_sequence, row_separator_0 & to_upper(sequence_instruction_set.sdr) & sxr_id_identifier.id & type_vector_id'image(sxr_ct));
		put(file_sequence, row_separator_0 & type_scan'image(sdr) 
			& row_separator_0 & sxr_id_identifier.id & type_vector_id'image(sxr_ct));
		if with_new_line then
			new_line(file_sequence);
		end if;
		sxr_ct := sxr_ct + 1;
	end write_sdr;

	procedure all_in(instruction : type_bic_instruction) is
	-- writes something like "set IC301 drv ir 7 downto 0 = 00000001 sample" for all bics
	-- if the desired instruction/mode does not exists, it aborts

		procedure error_on_invalid_instruction(bic_name : type_device_name.bounded_string; instruction : type_bic_instruction) is
		begin
			write_message (
				file_handle => current_output,
				text => message_error & "device " & type_device_name.to_string(bic_name) &
					 " does not support mode " & type_bic_instruction'image(instruction) & " !",
				console => true);
			raise constraint_error;
		end error_on_invalid_instruction;

		use type_device_name;
		use type_list_of_bics;

		bic_cursor : type_list_of_bics.cursor := first(list_of_bics);
		bic : type_bscan_ic;
	begin
		put_line(file_sequence, " -- set all in mode " & type_bic_instruction'image(instruction));

		-- for the logs:
		put_line(" setting all BICs in " & type_bic_instruction'image(instruction) & " mode ...");
		
		--for b in 1..length(list_of_bics) loop
		while bic_cursor /= type_list_of_bics.no_element loop
			bic := element(bic_cursor);
			put_line("  " & to_string(key(bic_cursor)));

			-- if desired instruction does not exist, abort
			case instruction is
-- 				when bypass		=> if not instruction_present(element(list_of_bics,positive(b)).opc_bypass) then error_on_invalid_instruction(element(list_of_bics,positive(b)).name,instruction); end if;
-- 				when idcode		=> if not instruction_present(element(list_of_bics,positive(b)).opc_idcode) then error_on_invalid_instruction(element(list_of_bics,positive(b)).name,instruction); end if; 
-- 				when usercode	=> if not instruction_present(element(list_of_bics,positive(b)).opc_usercode) then error_on_invalid_instruction(element(list_of_bics,positive(b)).name,instruction); end if;
-- 				when preload	=> if not instruction_present(element(list_of_bics,positive(b)).opc_preload) then error_on_invalid_instruction(element(list_of_bics,positive(b)).name,instruction); end if;
-- 				when intest		=> if not instruction_present(element(list_of_bics,positive(b)).opc_intest) then error_on_invalid_instruction(element(list_of_bics,positive(b)).name,instruction); end if;
-- 				when clamp		=> if not instruction_present(element(list_of_bics,positive(b)).opc_clamp) then error_on_invalid_instruction(element(list_of_bics,positive(b)).name,instruction); end if;
-- 				when highz		=> if not instruction_present(element(list_of_bics,positive(b)).opc_highz) then error_on_invalid_instruction(element(list_of_bics,positive(b)).name,instruction); end if;
-- 				when sample		=> if not instruction_present(element(list_of_bics,positive(b)).opc_sample) then error_on_invalid_instruction(element(list_of_bics,positive(b)).name,instruction); end if;
-- 				when extest		=> if not instruction_present(element(list_of_bics,positive(b)).opc_extest) then error_on_invalid_instruction(element(list_of_bics,positive(b)).name,instruction); end if;

				when bypass		=> if not instruction_present(bic.opc_bypass)	then error_on_invalid_instruction(key(bic_cursor),instruction); end if;
				when idcode		=> if not instruction_present(bic.opc_idcode) 	then error_on_invalid_instruction(key(bic_cursor),instruction); end if; 
				when usercode	=> if not instruction_present(bic.opc_usercode) then error_on_invalid_instruction(key(bic_cursor),instruction); end if;
				when preload	=> if not instruction_present(bic.opc_preload) 	then error_on_invalid_instruction(key(bic_cursor),instruction); end if;
				when intest		=> if not instruction_present(bic.opc_intest) 	then error_on_invalid_instruction(key(bic_cursor),instruction); end if;
				when clamp		=> if not instruction_present(bic.opc_clamp) 	then error_on_invalid_instruction(key(bic_cursor),instruction); end if;
				when highz		=> if not instruction_present(bic.opc_highz) 	then error_on_invalid_instruction(key(bic_cursor),instruction); end if;
				when sample		=> if not instruction_present(bic.opc_sample) 	then error_on_invalid_instruction(key(bic_cursor),instruction); end if;
				when extest		=> if not instruction_present(bic.opc_extest) 	then error_on_invalid_instruction(key(bic_cursor),instruction); end if;
			end case;
			-- instruction exists

			-- write instruction drive (default part)
			-- example: "set IC301 drv ir 7 downto 0 := "
			put(file_sequence, row_separator_0 
				& sequence_instruction_set.set & row_separator_0
				-- 				& to_string(element(list_of_bics,positive(b)).name) & row_separator_0
				& to_string(key(bic_cursor)) & row_separator_0
				& sxr_io_identifier.drive & row_separator_0
				& sir_target_register.ir
				-- 				& type_register_length'image(element(list_of_bics,positive(b)).len_ir - 1) & row_separator_0
				& type_register_length'image(element(bic_cursor).len_ir - 1) & row_separator_0				
				& sxr_vector_orientation.downto & row_separator_0 & "0" & row_separator_0
				& sxr_assignment_operator.assign & row_separator_0
				);

			-- write instruction depended part
			case instruction is
-- 				when idcode 	=> put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).opc_idcode); -- example: "11111110 idcode"
-- 				when usercode 	=> put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).opc_usercode);
-- 				when sample 	=> put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).opc_sample);
-- 				when preload 	=> put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).opc_preload);
-- 				when clamp 		=> put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).opc_clamp);
-- 				when highz 		=> put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).opc_highz);
-- 				when intest 	=> put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).opc_intest);
-- 				when extest 	=> put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).opc_extest);
-- 				when bypass 	=> put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).opc_bypass);

				when idcode 	=> put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).opc_idcode); -- example: "11111110 idcode"
				when usercode 	=> put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).opc_usercode);
				when sample 	=> put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).opc_sample);
				when preload 	=> put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).opc_preload);
				when clamp 		=> put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).opc_clamp);
				when highz 		=> put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).opc_highz);
				when intest 	=> put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).opc_intest);
				when extest 	=> put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).opc_extest);
				when bypass 	=> put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).opc_bypass);
				
			end case;
			put_line(file_sequence, row_separator_0 & to_lower(type_bic_instruction'image(instruction)));

			next(bic_cursor);
		end loop;
	end all_in;

	procedure write_ir_capture is
	-- writes something like "set IC301 exp ir 7 downto 0 = 000XXX01" for all bics
		use type_list_of_bics;
		use type_device_name;
	
		bic_cursor : type_list_of_bics.cursor := first(list_of_bics);
	begin
		put_line(file_sequence, " -- set instruction capture pattern");

		-- for the logs:
		put_line(" setting ir capture values ..."); -- APPLIES FOR ALL BICS
		
-- 		for b in 1..length(list_of_bics) loop                
		while bic_cursor /= type_list_of_bics.no_element loop		
			put_line("  " & to_string(key(bic_cursor)));
			
			put(file_sequence, row_separator_0 
				& sequence_instruction_set.set & row_separator_0
-- 				& to_string(element(list_of_bics,positive(b)).name) & row_separator_0
				& to_string(key(bic_cursor)) & row_separator_0
				& sxr_io_identifier.expect & row_separator_0
				& sir_target_register.ir
-- 				& type_register_length'image(element(list_of_bics,positive(b)).len_ir - 1) & row_separator_0
				& type_register_length'image(element(bic_cursor).len_ir - 1) & row_separator_0
				& sxr_vector_orientation.downto & row_separator_0 & "0" & row_separator_0
				& sxr_assignment_operator.assign & row_separator_0
				);
-- 			put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).capture_ir);
			put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).capture_ir);

			new_line(file_sequence);
			next(bic_cursor);
		end loop;
	end write_ir_capture;

	procedure load_safe_values is
	-- writes something like "set IC303 drv boundary 17 downto 0 = X1XXXXXXXXXXXXXXXX"
	-- writes something like "set IC303 exp boundary 17 downto 0 = X"
		use type_list_of_bics;
		use type_device_name;

		bic_cursor : type_list_of_bics.cursor := first(list_of_bics);
	begin
		put_line(file_sequence, " -- load safe values");

		-- for the logs
		put_line(" setting safe values ..."); -- APPLIES FOR ALL BICS
		
		-- drive pattern
-- 		for b in 1..length(list_of_bics) loop                
		while bic_cursor /= type_list_of_bics.no_element loop
			put_line("  " & to_string(key(bic_cursor)));
			
			-- WRITE DATA DRIVE (default part)
			-- example: "set IC300 drv"
			put(file_sequence, row_separator_0 
				& sequence_instruction_set.set & row_separator_0
				--& to_string(element(list_of_bics,positive(b)).name) & row_separator_0
				& to_string(key(bic_cursor)) & row_separator_0
				& sxr_io_identifier.drive & row_separator_0
				);

			-- example: "boundary 5 downto 0 := XXX11"
			put(file_sequence, sdr_target_register.boundary
-- 				& natural'image(element(list_of_bics,positive(b)).len_bsr - 1) & row_separator_0
				& natural'image(element(bic_cursor).len_bsr - 1) & row_separator_0 				
				& sxr_vector_orientation.downto 
				& " 0 "
				& sxr_assignment_operator.assign & row_separator_0
				);
-- 			put_binary_class_1(file => file_sequence, binary_in => element(list_of_bics,positive(b)).safebits);
			put_binary_class_1(file => file_sequence, binary_in => element(bic_cursor).safebits);
			new_line(file_sequence);

			next(bic_cursor);
		end loop;

		put_line(file_sequence, " -- nothing meaningful to expect here");

		-- expect pattern
		bic_cursor := first(list_of_bics);
-- 		for b in 1..length(list_of_bics) loop                
		while bic_cursor /= type_list_of_bics.no_element loop
	
			-- WRITE DATA EXPECT (default part)
			-- example: "set IC300 exp"
			put(file_sequence, row_separator_0 
				& sequence_instruction_set.set & row_separator_0
-- 				& to_string(element(list_of_bics,positive(b)).name) & row_separator_0
				& to_string(key(bic_cursor)) & row_separator_0				
				& sxr_io_identifier.expect & row_separator_0
				);

			-- example: "boundary 5 downto 0 := X"
			put(file_sequence, sdr_target_register.boundary
				-- 				& natural'image(element(list_of_bics,positive(b)).len_bsr - 1) & row_separator_0 & sxr_vector_orientation.downto
				& natural'image(element(bic_cursor).len_bsr - 1) 
				& row_separator_0 & sxr_vector_orientation.downto
				& " 0 "
				& sxr_assignment_operator.assign & row_separator_0
				& "X"
				);
			new_line(file_sequence);

			next(bic_cursor);
		end loop;
	end load_safe_values;


	procedure load_static_drive_values is
	-- writes something like "set IC303 drv boundary 16=0 16=0 16=0 16=0 17=0 17=0 17=0 17=0"
		use type_list_of_bics;
		use type_device_name;

		-- definition of an object consisting of bic_name and cell_id. the object is part of a list which
		-- contains shared control cells already placed in the line.
		type type_shared_control_cell is
			record
				bic_name	: type_device_name.bounded_string;
				cell_id		: type_cell_id;
			end record;
		package type_list_of_shared_control_cells is new vectors
			(index_type => positive, element_type => type_shared_control_cell);
		use type_list_of_shared_control_cells;
		list_of_shared_control_cells : type_list_of_shared_control_cells.vector;

		function cell_already_written (bic_name : type_device_name.bounded_string; cell_id : type_cell_id) return boolean is
		-- some cells are shared control cells and must be written only once
		-- so we first check if the cell is shared. if yes, it must be checked if it has been written already
		-- if not written already it gets added to a list of "already placed shared control cells"
			scp : type_shared_control_cell;
			cell_already_written : boolean := false; -- initial assumption is that the current cell has not been written yet
			use type_device_name;
		begin
			if is_shared(bic_name, cell_id) then -- if is_shared

				-- search in list of "already placed shared control cells"
				-- if cell found, set flag cell_already_written
				for s in 1..length(list_of_shared_control_cells) loop
					scp := element(list_of_shared_control_cells, positive(s));
					if scp.bic_name = bic_name and scp.cell_id = cell_id then -- cell already written
						return true; -- once cell found, no more searching required
					end if;
				end loop;

				-- because this code is reached, the cell has not been written yet
				-- add bic and cell id to "list of already placed shared control cells"
				append(list_of_shared_control_cells, (bic_name => bic_name, cell_id => cell_id));
				return false;
			else
				return false;
			end if;  -- if is_shared
		end cell_already_written;

		procedure look_up_locked_control_cells_in_class_EH_EL_NA_nets(bic_name : type_device_name.bounded_string) is
		-- for the given bic_name, extracts all cell ids and drive values from a list of lines like: 
		-- class NA primary_net /CS_000-800H device IC300 pin 2 control_cell 105 locked_to disable_value 0
			cell : type_static_control_cell_class_EX_NA;
			use type_list_of_static_control_cells_class_EX_NA;
			use type_device_name;
		begin
			for c in 1..length(list_of_static_control_cells_class_EX_NA) loop
				cell := element(list_of_static_control_cells_class_EX_NA, positive(c));
				if cell.device = bic_name then -- if bic found in cell list

					if not cell_already_written(cell.device, cell.id) then
						put(file_sequence, type_cell_id'image(cell.id) & sxr_assignment_operator.assign
						& type_bit_char_class_0'image(cell.disable_value)(2)); -- strip delimiters
					end if;

				end if; -- if bic found in cell list
			end loop;  -- loop through cell list
		end look_up_locked_control_cells_in_class_EH_EL_NA_nets;

		procedure look_up_locked_control_cells_in_class_DX_NR(bic_name : type_device_name.bounded_string) is
		-- extracts cell id and drive value from a line like: 
		-- class NR secondary_net LED0_R device IC301 pin 2 control_cell 105 locked_to disable_value 0
		-- class NR primary_net LED0 device IC303 pin 10 control_cell 16 locked_to enable_value 0
			cell : type_cell_of_cell_list;
			use type_list_of_static_control_cells_class_DX_NR;
			use type_device_name;
		begin
			for c in 1..length(list_of_static_control_cells_class_DX_NR) loop
				cell := type_cell_of_cell_list(element(list_of_static_control_cells_class_DX_NR, positive(c)));
				if cell.device = bic_name then -- bic found in cell list

					-- shared control cells must be written only once					
					if not cell_already_written(cell.device, cell.id) then
						put(file_sequence, type_cell_id'image(cell.id) & sxr_assignment_operator.assign);
						case element(list_of_static_control_cells_class_DX_NR, positive(c)).locked_to_enable_state is
							when true  => put(file_sequence, type_bit_char_class_0'image(
											element(list_of_static_control_cells_class_DX_NR, positive(c)).enable_value)(2)); -- strip delimiters
							when false => put(file_sequence, type_bit_char_class_0'image(
											element(list_of_static_control_cells_class_DX_NR, positive(c)).disable_value)(2)); -- strip delimiters
						end case;
					end if;

				end if; -- if bic found in cell list
			end loop;
		end look_up_locked_control_cells_in_class_DX_NR;

		procedure look_up_locked_control_cells_in_class_PU_PD_nets(bic_name : type_device_name.bounded_string) is
		-- for the given bic_name, extracts all cell ids and drive values from a list of lines like: 
		-- class PU primary_net PU1 device IC300 pin 42 control_cell 45 locked_to disable_value 0
			cell : type_static_control_cell_class_PX;
			use type_list_of_static_control_cells_class_PX;
			use type_device_name;
		begin
			for c in 1..length(list_of_static_control_cells_class_PX) loop
				cell := element(list_of_static_control_cells_class_PX, positive(c));
				if cell.device = bic_name then -- if bic found in cell list

					if not cell_already_written(cell.device, cell.id) then
						put(file_sequence, type_cell_id'image(cell.id) & sxr_assignment_operator.assign
							& type_bit_char_class_0'image(cell.disable_value)(2)); -- strip delimiters
					end if;

				end if; -- if bic found in cell list
			end loop;  -- loop through cell list
		end look_up_locked_control_cells_in_class_PU_PD_nets;

		procedure look_up_locked_output_cells_in_class_PU_PD_nets(bic_name : type_device_name.bounded_string) is
		-- for the given bic_name, extracts all cell ids and drive values from a list of lines like: 
		-- class PU primary_net A14 device IC300 pin 33 output_cell 19 locked_to drive_value 0
			cell : type_static_output_cell_class_PX;
			use type_list_of_static_output_cells_class_PX;
			use type_device_name;
		begin
			for c in 1..length(list_of_static_output_cells_class_PX) loop
				cell := element(list_of_static_output_cells_class_PX, positive(c));
				if cell.device = bic_name then -- if bic found in cell list

					if not cell_already_written(cell.device, cell.id) then
						put(file_sequence, type_cell_id'image(cell.id) & sxr_assignment_operator.assign
							& type_bit_char_class_0'image(cell.drive_value)(2)); -- strip delimiters
					end if;

				end if; -- if bic found in cell list
			end loop;  -- loop through cell list
		end look_up_locked_output_cells_in_class_PU_PD_nets;

		procedure look_up_static_output_cells_class_DX_NR(bic_name : type_device_name.bounded_string) is
		-- for the given bic_name, extracts all cell ids and drive values from a list of lines like: 
		-- class DL primary_net RST device IC300 pin 25 output_cell 4 locked_to drive_value 0
			cell : type_static_output_cell_class_DX_NR;
			use type_list_of_static_output_cells_class_DX_NR;
			use type_device_name;
		begin
			for c in 1..length(list_of_static_output_cells_class_DX_NR) loop
				cell := element(list_of_static_output_cells_class_DX_NR, positive(c));
				if cell.device = bic_name then -- if bic found in cell list

					if not cell_already_written(cell.device, cell.id) then
						put(file_sequence, type_cell_id'image(cell.id) & sxr_assignment_operator.assign
							& type_bit_char_class_0'image(cell.drive_value)(2)); -- strip delimiters
					end if;

				end if; -- if bic found in cell list
			end loop;  -- loop through cell list
		end look_up_static_output_cells_class_DX_NR;

		bic_cursor : type_list_of_bics.cursor := first(list_of_bics);
		
	begin -- load_static_drive_values
		put_line(file_sequence, " -- set static drive values");

		--for the logs:
		put_line(" setting static drive values ..."); -- APPLIES FOR ALL BICS
		
			-- drive pattern
		--for b in 1..length(list_of_bics) loop    
		while bic_cursor /= type_list_of_bics.no_element loop
			put_line("  " & to_string(key(bic_cursor)));
			
			-- look ahead in cell lists if bic is listed there at all
			-- if bic is not in cell any list, the particular bic can be skipped
-- 			if element(list_of_bics,positive(b)).has_static_drive_cell then
			if element(bic_cursor).has_static_drive_cell then			

				-- WRITE DATA DRIVE (default part)
				-- example: "set IC300 drv boundary"
				put(file_sequence, row_separator_0 
					& sequence_instruction_set.set & row_separator_0
-- 					& to_string(element(list_of_bics,positive(b)).name) & row_separator_0
					& to_string(key(bic_cursor)) & row_separator_0					
					& sxr_io_identifier.drive & row_separator_0
					);
				put(file_sequence, sdr_target_register.boundary);

				-- WRITE DATA DRIVE (bic and cell depended part)
-- 				look_up_locked_control_cells_in_class_EH_EL_NA_nets(element(list_of_bics,positive(b)).name);
-- 				look_up_locked_control_cells_in_class_DX_NR(element(list_of_bics,positive(b)).name);
-- 				look_up_locked_control_cells_in_class_PU_PD_nets(element(list_of_bics,positive(b)).name);
-- 				look_up_locked_output_cells_in_class_PU_PD_nets(element(list_of_bics,positive(b)).name);
-- 				look_up_static_output_cells_class_DX_NR(element(list_of_bics,positive(b)).name);
				look_up_locked_control_cells_in_class_EH_EL_NA_nets (key(bic_cursor));
				look_up_locked_control_cells_in_class_DX_NR			(key(bic_cursor));
				look_up_locked_control_cells_in_class_PU_PD_nets	(key(bic_cursor));
				look_up_locked_output_cells_in_class_PU_PD_nets		(key(bic_cursor));
				look_up_static_output_cells_class_DX_NR				(key(bic_cursor));
				new_line(file_sequence);

			end if;

			next(bic_cursor);
		end loop;
	end load_static_drive_values;


	procedure load_static_expect_values is
	-- writes something like " set IC300 exp boundary 14=0 11=1 5=0"
		use type_list_of_bics;
		use type_device_name;

		procedure look_up_static_expect(bic_name : type_device_name.bounded_string) is
		-- for the given bic_name, extracts all cell ids and expect values from the static_expect cell list of lines like: 
		-- example 1 : class DL primary_net /CPU_MREQ device IC300 pin 28 input_cell 14 expect_value 0
		-- example 2 : class DH secondary_net MREQ device IC300 pin 28 input_cell 14 expect_value 1 primary_net_is MR45
			cell : type_cell_of_cell_list;
			use type_list_of_static_expect_cells;
			use type_device_name;
		begin
			for c in 1..length(list_of_static_expect_cells) loop
				cell := type_cell_of_cell_list(element(list_of_static_expect_cells, positive(c)));
				if cell.device = bic_name then -- if bic found in cell list

					put(file_sequence, type_cell_id'image(cell.id) & sxr_assignment_operator.assign
						& type_bit_char_class_0'image(element(list_of_static_expect_cells, positive(c)).expect_value)(2)); -- strip delimiters

				end if; -- if bic found in cell list
			end loop;  -- loop through cell list
		end look_up_static_expect;

		bic_cursor : type_list_of_bics.cursor := first(list_of_bics);
		
	begin -- load_static_expect_values
		put_line(file_sequence, " -- load static expect values");

		-- for the logs:
		put_line(" setting static expect values ..."); -- APPLIES FOR ALL BICS
		
		-- drive pattern
-- 		for b in 1..length(list_of_bics) loop    
		while bic_cursor /= type_list_of_bics.no_element loop
			put_line("  " & to_string(key(bic_cursor)));
			
			-- look ahead in cell list static_expect if bic is listed there at all
			-- if bic is not in cell list, the particular bic can be skipped
			-- if element(list_of_bics,positive(b)).has_static_expect_cell then
			if element(bic_cursor).has_static_expect_cell then			

				-- WRITE DATA EXPECT (default part)
				-- example: "set IC300 exp boundary"
				put(file_sequence, row_separator_0 
					& sequence_instruction_set.set & row_separator_0
					-- 					& to_string(element(list_of_bics,positive(b)).name) & row_separator_0
					& to_string(key(bic_cursor)) & row_separator_0
					& sxr_io_identifier.expect & row_separator_0
					);
				put(file_sequence, sdr_target_register.boundary);

				-- WRITE DATA EXPECT (bic and cell depended part)
				-- 				look_up_static_expect(element(list_of_bics,positive(b)).name);
				look_up_static_expect(key(bic_cursor));
				new_line(file_sequence);

			end if;

			next(bic_cursor);
		end loop;
	end load_static_expect_values;

	function get_cell_assignment (text_in : string) return type_set_cell_assignment is
	-- fractions a given string like 102=1 into cell id and value
		ca			: type_set_cell_assignment;
		ifs_pos		: natural;
		ifs_ct		: natural;
		ifs_length	: natural := sxr_assignment_operator.assign'last;

		procedure put_example is
		begin
			put_line(standard_output,"       NOTE: Whitespace not allowed in cell assignments !");
			put_line(standard_output,"       Example: set IC1 drv boundary 16" & sxr_assignment_operator.assign & "1"
										& " 17" & sxr_assignment_operator.assign & "x"
										& " 77" & sxr_assignment_operator.assign & "0");
			raise constraint_error;
		end put_example;
	begin
		-- count occurences of ifs
		-- it must occur only once, otherwise abort
		ifs_ct	:= ada.strings.fixed.count(text_in,sxr_assignment_operator.assign);
		if ifs_ct = 1 then
			-- ifs must not be at the start of the field.
			-- ifs must not be at the end of the field (length of ifs matters here !).
			ifs_pos := index(text_in,sxr_assignment_operator.assign);
			if ifs_pos > 1 and ifs_pos < text_in'last-(ifs_length-1) then
				-- extract cell id
				ca.cell_id := type_cell_id'value(text_in(text_in'first..ifs_pos-1));

				-- there must be only one character after ifs
				if text_in'last - (ifs_pos + ifs_length) = 0 then
					-- extract value
					case text_in(text_in'last) is
						when '0' 		=> ca.value := '0';
						when '1' 		=> ca.value := '1';
						when 'x' | 'X'	=> ca.value := 'x';
						when others =>
							put_line(standard_output,"ERROR: Expected a 0,1 or x. Found '" & text_in(text_in'last) & "' !");
							put_example;
					end case;
				else
					--put_line(standard_output,text_in & natural'image(text_in'last) & natural'image(ifs_pos) & natural'image(ifs_length));
					put_line(standard_output,"ERROR: Field separator '" & sxr_assignment_operator.assign & "' must be followed by a single character like 0,1 or x !");
					put_example;
				end if;
			else
				put_line(standard_output,"ERROR: Field separator '" & sxr_assignment_operator.assign & "' must be preceeded by a cell id and followed by the value !");
				put_example;
			end if;
		else
			put_line(standard_output,"ERROR: One field separator '" & sxr_assignment_operator.assign & "' allowed/required in cell assigment !");
			put_example;
		end if;

		return ca;
	end get_cell_assignment;

	function get_test_base_address ( test_name : type_name_test.bounded_string) return string is
		previous_input	: ada.text_io.file_type renames current_input;
		input_file 		: ada.text_io.file_type;

		line_length_max : constant positive := 300;
		package type_line is new generic_bounded_length(line_length_max); use type_line;
		line			: type_line.bounded_string;

		--base_address	: hex_number_32bit := "FFFFFFFF"; -- this default address is regarded as illegal for the calling program
		base_address	: string (1..8) := "FFFFFFFF"; -- this default address is regarded as illegal for the calling program
		-- cs: base_address should be a type hex_number_32bit

		use type_name_test;
	begin
		-- check if journal file exists	
		if not exists ( "setup/journal.txt" ) then 
			put_line(message_error & "No journal found ! Please compile test '" & to_string(test_name) & "' first !");
			raise constraint_error;
		else
			-- read journal file
			open(
				file => input_file,
				mode => in_file,
				name => "setup/journal.txt"
				);
			set_input(input_file);

			-- search for latest entry of test
			while not end_of_file
			loop
				line := to_bounded_string(remove_comment_from_line(get_line));
				if get_field_from_line(to_string(line),1) = test_name then -- on match
					--base_address := hex_number_32bit(m1.get_field(line,2)); -- updated base_address until last matching entry found
					--base_address := m1.get_field(line,2); -- updated base_address until last matching entry found
					base_address := get_field_from_line(to_string(line),2)(1..8); -- leave off format indicator
				end if;
			end loop;

			--put_line(hex_number'(base_address));
			-- if test entry not found
			if base_address = "FFFFFFFF" then -- if base_address still default
				put_line(message_error & "No compilation found ! Please compile test '" & to_string(test_name) & "' first !");
				raise constraint_error;
			end if;

		end if;

		close(input_file);
		set_input(previous_input);

		return base_address;
	end get_test_base_address;
	
	procedure find_net_in_netlist -- CS: REWORK ASAP, use container for netlist !
		(
		test_name	: type_name_test.bounded_string;
		device		: type_device_name.bounded_string;
		bit_pos		: type_sxr_fail_position; -- zero-based
		expect_value: type_logic_level_as_word
		) is
		previous_input		: ada.text_io.file_type renames current_input;
		previous_output		: ada.text_io.file_type renames current_output;
		input_file 			: ada.text_io.file_type;

		line_length_max : constant positive := 300;
		package type_line is new generic_bounded_length(line_length_max); use type_line;
		line : type_line.bounded_string;

		net_name			: type_net_name.bounded_string;
		net_name_primary	: type_net_name.bounded_string;
		net_class			: type_net_class;
		net_section_entered				: boolean := false;
		secondary_net_section_entered 	: boolean := false;
		primary_net_section_entered 	: boolean := false;
		secondary_net_entered 			: boolean := false;
		primary_net 					: boolean := false;

		use type_name_test;		
		use type_name_test_netlist;
		
		use type_net_name;
		use type_device_name;
	begin
		set_output(standard_output);
		name_test_netlist := to_bounded_string(to_string(test_name) & "/netlist.txt"); -- compose name of netlist file
		--put_line("---0---> ");
		if exists(to_string(name_test_netlist)) then
            -- read netlist
			open(
				file => input_file,
				mode => in_file,
				name => to_string(name_test_netlist)
				);
			set_input(input_file);

			-- step 1:
			-- find affected receiver pin in net list
			-- once found, the last net name found must be saved
			while not end_of_file
			loop
                line := to_bounded_string(remove_comment_from_line(get_line));
				if get_field_count(to_string(line)) > 0 then -- if line contains anything

					if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) /= "secondary_nets_of" then
						--net_count := net_count + 1; -- count nets
						net_name := to_bounded_string(get_field_from_line(to_string(line),2));
						net_class := type_net_class'value(get_field_from_line(to_string(line),4));
					end if;

					if get_field_from_line(to_string(line),1) = to_string(device) then
--                         put_line (type_line.to_string (line));
                        case type_line.count (line, "|") is
                            when 1 =>
                                if to_lower (get_field_from_line (to_string (line),10)) = "input" then
                                    if type_cell_id'value (get_field_from_line (to_string (line),8)) = bit_pos then
                                        exit;
                                    end if;

-- cs: add more possible fields for input cell, self monitoring cells, ...
            -- 						new_line;
            -- 						if secondary_net then
            -- 							put_line("secondary net : " & net_name);
            -- 						else
            -- 							put_line("primary net   : " & net_name);
            -- 							net_name_primary := net_name;
            -- 						end if;
--                                     put_line("---2---> " & to_string(net_name));
--                                     exit;
                                    -- cs: show pins
                                    -- cs: show primary/secondary nets
                                end if;

                            when 2 =>
                                if to_lower (get_field_from_line (to_string (line),10)) = "input" then
                                    if type_cell_id'value (get_field_from_line (to_string (line),8)) = bit_pos then 
                                        exit;
                                    end if;
                                elsif to_lower (get_field_from_line (to_string (line),18)) = "input" then
									if type_cell_id'value (get_field_from_line (to_string (line),16)) = bit_pos then
										exit;
                                    end if;
                                end if;
                                
                            when others => null;

                        end case;
                        
                    end if;
				end if; -- if line contains anything
			end loop;
			put_line("net class         : " & type_net_class'image(net_class));
			-- now, we know the net name and net class

--             put_line ("XXXXXXXXXX");
            
			-- step 2:
			-- find net again by the name found before and find out if it is a primary or secondary net
			reset(input_file);
			while not end_of_file loop
				line := to_bounded_string(remove_comment_from_line(get_line));
				if get_field_count(to_string(line)) > 0 then -- if line contains anything

					-- if net outside a secondary net section, it is a primary net
					if not secondary_net_section_entered then
						if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) = to_string(net_name) then
							primary_net := true; -- set primary net flag
							exit;
						end if;
					end if;

					-- if net inside a secondary net section, it is a secondary net
					if secondary_net_section_entered then
						if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) = to_string(net_name) then
							exit; -- leave primary net flag reset
						end if;
					end if;

					if not secondary_net_section_entered then
						if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) = "secondary_nets_of" then
							secondary_net_section_entered := true;
						end if;
					end if;

					if secondary_net_section_entered then
						if get_field_from_line(to_string(line),1) = "EndSubSection" and get_field_from_line(to_string(line),2) = "secondary_nets_of" then
							secondary_net_section_entered := false;
						end if;
					end if;

				end if; -- if line contains anything
			end loop;
			-- now, we know if it is a primary or secondary net (flag primary_net)

			-- step 3:
			new_line;
			reset(input_file);
			-- if it is a primary net, show its content
			if primary_net then
				put_line("primary net       : " & to_string(net_name));
				new_line;
				--put_line("check pins :");
				while not end_of_file loop
					line := to_bounded_string(remove_comment_from_line(get_line));
					if get_field_count(to_string(line)) > 0 then -- if line contains anything

						if primary_net_section_entered then
							if get_field_from_line(to_string(line),1) = "EndSubSection" then
								--new_line;
								exit;
							end if;
						end if;

						if primary_net_section_entered then
							put_line(get_field_from_line(to_string(line),1) & " pin " & get_field_from_line(to_string(line),5));
						end if;

						if not primary_net_section_entered then
							if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) = to_string(net_name) then
								primary_net_section_entered := true;
							end if;
						end if;

					end if; -- if line contains anything
				end loop;

				-- find secondary nets belonging to this primary net
				-- and show their content
				reset(input_file);
				secondary_net_section_entered := false;
				while not end_of_file loop
					line := to_bounded_string(remove_comment_from_line(get_line));
					if get_field_count(to_string(line)) > 0 then -- if line contains anything

						if secondary_net_section_entered then
							if get_field_from_line(to_string(line),1) = "EndSubSection" and get_field_from_line(to_string(line),2) = "secondary_nets_of" and
							   get_field_from_line(to_string(line),3) = to_string(net_name) then
								secondary_net_section_entered := false;
								exit;
							end if;
						end if;

						if secondary_net_section_entered then
							if secondary_net_entered then
								if get_field_from_line(to_string(line),1) = "EndSubSection" then
									secondary_net_entered := false;
									new_line;
								end if;
							end if;

							if secondary_net_entered then
								put_line(get_field_from_line(to_string(line),1) & " pin " & get_field_from_line(to_string(line),5));
							end if;

							if get_field_from_line(to_string(line),1) = "SubSection" then
								secondary_net_entered := true;
								put_line("secondary net     : " & get_field_from_line(to_string(line),2));
								--put_line("check :");
								new_line;
							end if;
						end if;

						if not secondary_net_section_entered then
							if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) = "secondary_nets_of" and
							   get_field_from_line(to_string(line),3) = to_string(net_name) then
								secondary_net_section_entered := true;
								--put_line("secondary net : " & net_name);
								--new_line;
								--put_line("check :");
								new_line;
							end if;
						end if;

					end if; -- if line contains anything
				end loop;

			else -- it is a secondary net

				-- find this secondary net
				-- and show its content
				reset(input_file);
				secondary_net_entered := false;
				while not end_of_file loop
					line := to_bounded_string(remove_comment_from_line(get_line));
					if get_field_count(to_string(line)) > 0 then -- if line contains anything

						if secondary_net_entered then
							if get_field_from_line(to_string(line),1) = "EndSubSection" then
								secondary_net_entered := false;
								exit;
							end if;
						end if;

						if secondary_net_entered then
							--put_line(line);
							put_line(get_field_from_line(to_string(line),1) & " pin " & get_field_from_line(to_string(line),5));
						end if;

						-- remember the most recent primary net name
						if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) = "secondary_nets_of" then
							net_name_primary := to_bounded_string(get_field_from_line(to_string(line),3));
						end if;

						if not secondary_net_entered then
							if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) = to_string(net_name) then
								secondary_net_entered := true;
								put_line("secondary net     : " & to_string(net_name));
								--new_line;
								--put_line("check :");
								new_line;
							end if;
						end if;
					
					end if; -- if line contains anything
				end loop;

				-- find primary net belonging to this secondary net 
				-- and show its content
				reset(input_file);
				primary_net_section_entered := false;
				new_line;
				while not end_of_file loop
					line := to_bounded_string(remove_comment_from_line(get_line));
					if get_field_count(to_string(line)) > 0 then -- if line contains anything

						if primary_net_section_entered then
							if get_field_from_line(to_string(line),1) = "EndSubSection" then
								primary_net_section_entered := false;
								exit;
							end if;
						end if;

						if primary_net_section_entered then
							put_line(get_field_from_line(to_string(line),1) & " pin " & get_field_from_line(to_string(line),5));
						end if;

						if not primary_net_section_entered then
							if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) = to_string(net_name_primary) then
								primary_net_section_entered := true;
								put_line("primary net       : " & to_string(net_name_primary));
								--new_line;
								--put_line("check :");
								new_line;
							end if;
						end if;

					end if; -- if line contains anything
				end loop;

				-- show remaining secondary nets
				-- find secondary nets belonging to this primary net
				-- and show their content
				reset(input_file);
				new_line;
				secondary_net_section_entered := false;
				while not end_of_file loop
					line := to_bounded_string(remove_comment_from_line(get_line));
					if get_field_count(to_string(line)) > 0 then -- if line contains anything

						if secondary_net_section_entered then
							if get_field_from_line(to_string(line),1) = "EndSubSection" and get_field_from_line(to_string(line),2) = "secondary_nets_of" and
							   get_field_from_line(to_string(line),3) = to_string(net_name_primary) then
								secondary_net_section_entered := false;
								exit;
							end if;
						end if;

						if secondary_net_section_entered then

							if secondary_net_entered then
								if get_field_from_line(to_string(line),1) = "EndSubSection" then
									secondary_net_entered := false;
									new_line;
								end if;
							end if;

							if secondary_net_entered then
								put_line(get_field_from_line(to_string(line),1) & " pin " & get_field_from_line(to_string(line),5));
							end if;

							-- skip the secondary net already displayed (see above)
							if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) /= to_string(net_name) then
								secondary_net_entered := true;
								put_line("secondary net : " & get_field_from_line(to_string(line),2));
								--put_line("check :");
								new_line;
							end if;
						end if;

						if not secondary_net_section_entered then
							if get_field_from_line(to_string(line),1) = "SubSection" and get_field_from_line(to_string(line),2) = "secondary_nets_of" and
							   get_field_from_line(to_string(line),3) = to_string(net_name_primary) then
								secondary_net_section_entered := true;
								--put_line("secondary nets affected further-on:");
								--new_line;
							end if;
						end if;
				
					end if; -- if line contains anything
				end loop;


			end if; -- if it is a primary net

			-- DIAGNOSIS ON STUCK-AT AND MISSING PULL-RESISTORS
			new_line;
			put("stuck at ");
			case net_class is
				when EL | DL => put_line(type_logic_level_as_word'image(HIGH));
				when EH | DH => put_line(type_logic_level_as_word'image(LOW));
				when NR => 
					case expect_value is
						when LOW => put_line(type_logic_level_as_word'image(HIGH));
						when HIGH => put_line(type_logic_level_as_word'image(LOW));
					end case;
				when PU =>
					case expect_value is
						when LOW => put_line(type_logic_level_as_word'image(HIGH));
						when HIGH => put_line(type_logic_level_as_word'image(LOW) & " or Pull-Up resistor missing !");
					end case;
				when PD =>
					case expect_value is
						when HIGH => put_line(type_logic_level_as_word'image(LOW));
						when LOW => put_line(type_logic_level_as_word'image(HIGH) & " or Pull-Down resistor missing !");
					end case;
				when others => null;
			end case;


			close(input_file);

		else -- if netlist exists
			put_line(message_warning & "Netlist file " & to_string(name_test_netlist) & "' not found !");
			put_line("         More detailled diagnosis not possible !");
		end if;
		set_input(previous_input);
		set_output(previous_output);

-- 	exception
-- 		when constraint_error => 
-- 				put_line("constraint_error at position :" & prog_position);
-- 		when others => 
-- 				put_line("exception at position :" & prog_position);

	end find_net_in_netlist;

	procedure message_on_scan_master_not_present is
	begin
		put_line(message_error & "No " & name_bsc & " connected or invalid firmware !");
	end message_on_scan_master_not_present;

	
	procedure show_failed_device
		(
		position	: in positive;
		name		: in type_device_name.bounded_string;
		register	: in string;
		bit_pos 	: in type_sxr_fail_position;
		expect_value: in type_logic_level_as_word
		) is
	begin
		put_line("device position   :" & positive'image(position));
		put_line("device name       : " & type_device_name.to_string(name));
		put_line("register          : " & register);
		put_line("failed bit pos.   :" & type_sxr_fail_position'image(bit_pos) & " (zero-based)");
		put_line("expected          : " & type_logic_level_as_word'image(expect_value));
	end show_failed_device;
	
	
	procedure locate_fail -- locates fail by test_name, failed_scanpath, sxr_id, sxr_length and sxr_fail_pos
		( 
		test_name		: type_name_test.bounded_string; -- test_name indicates where to look for the register files (that is the test directory)
		failed_scanpath	: type_scanport_id;
		sxr_id			: type_vector_id;
		sxr_length		: type_vector_length;
		sxr_fail_pos	: type_sxr_fail_position; --zero-based !
		expect_value	: type_logic_level_as_word
		)
		is
		previous_input	: ada.text_io.file_type renames current_input;
		previous_output	: ada.text_io.file_type renames current_output;
		input_file 		: ada.text_io.file_type;

		line_length_max : constant positive := 100;
		package type_line is new generic_bounded_length(line_length_max); use type_line;
		line : type_line.bounded_string;

		device_count	: natural := 0;
 		fail_pos_temp	: type_sxr_fail_position;  --zero-based !
		sxr				: type_scan; -- SIR or SDR

		use type_name_test_registers;
		use type_name_test;
		use type_device_name;

		scanpath_device_count_max : natural := 100; -- CS: should be dynamic
		type scanpath_device_type is 
			record
				name						: type_device_name.bounded_string;
				length_register_instruction	: type_vector_length;
				length_register_boundary	: type_vector_length;
				data_register_selected		: type_bic_data_register;
				-- CS: add more (manufacturer specific) registers and properties here
			end record;
		type scanpath_device_array_type is array (natural range <>) of scanpath_device_type;
		subtype scanpath_device_array_type_sized is scanpath_device_array_type (1..scanpath_device_count_max);
		scanpath_device 	: scanpath_device_array_type_sized; -- contains as much devices as given in scanpath_device_count_max

	begin
		set_output(standard_output);

				-- compose name of affected register file
				name_test_registers := to_bounded_string( compose (
										to_string(test_name),
										to_string(test_name) & "_" & trim( natural'image(failed_scanpath) ,left),
										file_extension_registers));
				--put_line(standard_output,reg_file_name);
				if exists(to_string(name_test_registers)) then
					-- read register file
					open(
						file => input_file,
						mode => in_file,
						name => to_string(name_test_registers)
					);
					set_input(input_file);
					loop_through_register_file:
					while not end_of_file -- loop through register file
					loop
						line := to_bounded_string(remove_comment_from_line(get_line));

						-- find line that starts with "device" and collect register lengths
						if get_field_from_line(to_string(line),1) = "device" then

							-- count devices in chain
							-- NOTE: the first device (number 1) found is closest to scan master TDO
							device_count := device_count + 1;    

							-- fill register information fields

							-- device name
							scanpath_device(device_count).name := to_bounded_string(get_field_from_line(to_string(line),3));

							-- instruction register length
							scanpath_device(device_count).length_register_instruction := 
											string_to_natural(
												get_field_from_line(to_string(line),5) & "d"
												);

							-- boundary register length
 							scanpath_device(device_count).length_register_boundary :=
											string_to_natural(
												get_field_from_line(to_string(line),7) & "d"
												);
 						end if;  -- if device found

						-- find failed step by step_id
						if get_field_from_line(to_string(line),1) = "step" and
							string_to_natural(get_field_from_line(to_string(line),2) & "d") = sxr_id then

							fail_pos_temp := sxr_fail_pos; --load fail_pos_temp with start value. it will be used for locating the failed device

							--put_line(line);
							-- figure out if the fail occured in an SIR or SDR
							-- if m1.get_field(line,5) = "ir" then -- cs: we assume all other devices are also in SIR mode
							if get_field_from_line(to_string(line),5) = "ir" then
								--scanpath(s).scan_type := SIR; -- so it is now clear that the fail occured during an SIR
								sxr := SIR; -- so it is now clear that the fail occured during an SIR
								put_line("scan type         : " & type_scan'image(sxr));

								-- start fail bit search with device closest to BSC_TDI in given regfile, that is device with higest number
								-- the UUT LSB is at the scan master TDI
								--for d in reverse 1..scanpath(s).device_count
								for d in reverse 1..device_count
								loop
									-- since this is an SIR we assume all devices are in ir mode. so we address only the ir registers
									if fail_pos_temp >= scanpath_device(d).length_register_instruction then -- fail pos outside current ir register
										-- update fail_pos_tmp
										fail_pos_temp := fail_pos_temp - scanpath_device(d).length_register_instruction;
										--put_line("bit pos. tmp  :" & natural_32bit_type'image(fail_pos_temp));
									else
										show_failed_device
											(
											position => d,
											name => scanpath_device(d).name,
											register => type_bic_instruction_register'image(IR),
											bit_pos => fail_pos_temp,
											expect_value => expect_value
											);
										exit loop_through_register_file;
									end if;
								end loop;

								-- if fail bit not in any device, it is a trailer failure 
								put_line("trailer failure at bit position :" & type_vector_length'image(fail_pos_temp) & " (zero-based)");

							else -- cs: we assume all other scan types are data scans (SDR)
								 -- cs: if at least one field 5 is a data register name, assume all remaining devices also in SDR mode
								--scanpath(s).scan_type := SDR; -- so it is now clear that the fail occured during an SDR
								sxr := SDR; -- so it is now clear that the fail occured during an SDR
								--put_line("scan type     : SDR");
								put_line("scan type         : " & type_scan'image(sxr));

								-- read selected data registers selected in devices. 
								-- read lines ahead to get data registers of all devices belonging to this step
								-- for d in 1..scanpath(s).device_count
								--for d in reverse 1..scanpath(s).device_count -- CS: assume device closest to BSC TDI appears first (highest pos.)
								for d in reverse 1..device_count loop -- CS: assume device closest to BSC TDI appears first (highest pos.)
									--if d > 1 then -- the current line is to be skipped as we are already there
									--if d < scanpath(s).device_count then -- the current line is to be skipped as we are already there
									if d < device_count then -- the current line is to be skipped as we are already there
										line := to_bounded_string(remove_comment_from_line(get_line));
									end if;
									--put_line(line);
									--if m1.get_field(line,5) = "bypass" then
									if get_field_from_line(to_string(line),5) = to_lower(type_bic_data_register'image(BYPASS)) then
										scanpath_device(d).data_register_selected := BYPASS;
									end if;

									--if m1.get_field(line,5) = "idcode" then
									if get_field_from_line(to_string(line),5) = to_lower(type_bic_data_register'image(IDCODE)) then
										scanpath_device(d).data_register_selected := IDCODE;
									end if;

									--if m1.get_field(line,5) = "usercode" then
									if get_field_from_line(to_string(line),5) = to_lower(type_bic_data_register'image(USERCODE)) then
										scanpath_device(d).data_register_selected := USERCODE;
									end if;

									--if m1.get_field(line,5) = "boundary" then
									if get_field_from_line(to_string(line),5) = to_lower(type_bic_data_register'image(BOUNDARY)) then
										scanpath_device(d).data_register_selected := BOUNDARY;
										--put_line(line);
									end if;
								end loop;
								-- now we know: which device of this scanpath had which data register selected
	
								-- start fail bit search with device closest to BSC_TDI in given regfile, that is device with higest number
								-- the UUT LSB is at the scan master TDI
								--for d in reverse 1..scanpath(s).device_count
								for d in reverse 1..device_count loop
									case scanpath_device(d).data_register_selected is
														-- if fail pos outside selected data register, updating fail_pos_temp required
										when BYPASS => 
													if fail_pos_temp >= bic_bypass_register_length then 
														fail_pos_temp := fail_pos_temp - bic_bypass_register_length;
													else
														show_failed_device
															(
															position => d,
															name => scanpath_device(d).name,
															register => type_bic_data_register'image(scanpath_device(d).data_register_selected),
															bit_pos => fail_pos_temp,
															expect_value => expect_value
															);
														exit loop_through_register_file;
													end if;
										when IDCODE => 
													if fail_pos_temp >= bic_idcode_register_length then
														fail_pos_temp := fail_pos_temp - bic_idcode_register_length;
													else
														show_failed_device
															(
															position => d,
															name => scanpath_device(d).name,
															register => type_bic_data_register'image(scanpath_device(d).data_register_selected),
															bit_pos => fail_pos_temp,
															expect_value => expect_value
															);
														exit loop_through_register_file;
													end if;
										when USERCODE => 
													if fail_pos_temp >= bic_usercode_register_length then
														fail_pos_temp := fail_pos_temp - bic_usercode_register_length;
													else
														show_failed_device
															(
															position => d,
															name => scanpath_device(d).name,
															register => type_bic_data_register'image(scanpath_device(d).data_register_selected),
															bit_pos => fail_pos_temp,
															expect_value => expect_value
															);
														exit loop_through_register_file;
													end if;
										when BOUNDARY =>
													--put_line("device    : " & natural'image(d));
													if fail_pos_temp >= scanpath_device(d).length_register_boundary then
														fail_pos_temp := fail_pos_temp - scanpath_device(d).length_register_boundary;
														--put_line("fail pos. : " & natural_32bit_type'image(fail_pos_temp));
													else
														show_failed_device
															(
															position => d,
															name => scanpath_device(d).name,
															register => type_bic_data_register'image(scanpath_device(d).data_register_selected),
															bit_pos => fail_pos_temp,
															expect_value => expect_value
															);
														find_net_in_netlist(
															test_name => test_name,
															device => scanpath_device(d).name,
															bit_pos => fail_pos_temp,
															expect_value => expect_value
															);
														exit loop_through_register_file;
													end if;
									end case;	
									
								end loop;

								-- if fail bit not in any device, it is a trailer failure 
								put_line("trailer failure at bit position :" & type_sxr_fail_position'image(fail_pos_temp) & " (zero-based)");
							end if;

							exit; -- no further register file scan required, cs: remove if more fails are to be located
						end if;
					end loop loop_through_register_file;
					close(input_file);

				else
					put_line(message_warning & "Scanpath #" & type_scanport_id'image(failed_scanpath) & " register file not found !");
					put_line("         More detailled diagnosis not possible !");
				end if;
-- 			end if;  -- if failed scan path found
-- 		end loop;
		set_input(previous_input);
		set_output(previous_output);
-- 	exception
-- 		when Constraint_Error => 
-- 				put_line("constraint_error at position :" & prog_position);
-- 		when others => 
-- 				put_line("exception at position :" & prog_position);
	end locate_fail;

	function execute_test
		(
		test_name					: type_name_test.bounded_string;
		interface_to_scan_master	: type_interface_to_bsc.bounded_string;
		step_mode					: type_step_mode -- step width
		) return result_test_type is
		test_step_done	: boolean := false;
		expect_value	: type_logic_level_as_word;

		base_address	: type_mem_address_byte;
		previous_output	: ada.text_io.file_type renames current_output;

		use interfaces;
		use m1_serial_communications;
		use type_interface_to_bsc;
		use type_name_test;
		
		procedure display_scanport_bits (sp : type_scanport_id) is
			scratch : unsigned_8;
		begin
			scratch := get_byte_from_word(word_in => bsc_register_scanport_bits_1_2, position => sp-1); -- position 0 addresses lowbyte	
			new_line;			
			-- position 7    6    5    4    3    2    1    0
			put_line(" TDI  EXP  MASK FAIL TRST TDO  TMS  TCK"); put(row_separator_0);
			for b in reverse 0..7 loop -- start with bit 7 (MSB, on the left)
				if test_bit_unsigned_8(byte_in => scratch, position => b) then
					put(" H   ");
				else
					put(" L   ");
				end if;
			end loop;
			new_line(2);
--			put_line(" --------------------------------------"); new_line;
			--put_line(scanport_bits(char_position..char_position+1));
		end display_scanport_bits;

	begin
		set_output(standard_output);		
		if scan_master_present then		
			base_address := string_to_natural(get_test_base_address(test_name) & 'h');
			put_line ("base address   : " & natural_to_string(natural_in => base_address, base => 16, length => 8));

			-- set start address
			interface_init(interface_name => to_string(interface_to_scan_master));
			
			interface_write(sercom_head_write);
			interface_write(sercom_addr_addr_start_a);
			interface_write(get_byte_from_doubleword(word_in => unsigned_32(base_address), position => 0));

			interface_write(sercom_head_write);
			interface_write(sercom_addr_addr_start_b);
			interface_write(get_byte_from_doubleword(word_in => unsigned_32(base_address), position => 1));

			interface_write(sercom_head_write);
			interface_write(sercom_addr_addr_start_c);
			interface_write(get_byte_from_doubleword(word_in => unsigned_32(base_address), position => 2));

			-- set path
			interface_write(sercom_head_write);
			interface_write(sercom_addr_path);
			interface_write(sercom_path_ex_reads_ram);

			-- clear command
			interface_write(sercom_head_write);
			interface_write(sercom_addr_cmd);
			interface_write(sercom_cmd_null);
			
			-- issue start command
			interface_write(sercom_head_write);
			interface_write(sercom_addr_cmd);
			-- map step_mode given to appropiate start command byte
			case step_mode is
				when OFF => 	interface_write(sercom_cmd_step_test);
				when TCK => 	interface_write(sercom_cmd_step_tck);
				when SXR => 	interface_write(sercom_cmd_step_sxr);
				--when others => 	step_width_hex := cmd_step_test; -- CS: should result in an an error !
			end case;

			-- check if test has been started
			read_bsc_status_registers(interface_to_scan_master);
			if bsc_register_state_executor /= ex_state_idle then
				put_line("Test/step '"& to_string(test_name) & "' started ...");
			else
				put_line(message_error & "Test/step '"& to_string(test_name) &"' NOT started !");
				raise constraint_error;
			end if;
			
			-- wait for test/step done by cyclic reading of bsc status registers
			while not test_step_done
			loop
				read_bsc_status_registers(interface_to_scan_master);
				delay 1.0;
				put_line("waiting for test/step end ...");
				case bsc_register_state_executor is
	-- 				when ex_state_wait_step_sxr => -- test step sxr passed
	-- 					result_test := pass;
	-- 					test_step_done := true;
	-- 					exit; -- no more polling required 
					when ex_state_end_of_test => -- test finished and passed
						result_test := pass;
						test_step_done := true;
						exit; -- no more polling required 
					when ex_state_test_fail => -- test failed
						result_test := fail;
						test_step_done := true;
						exit; -- no more polling required 
					when ex_state_test_abort => -- test aborted
						result_test := fail;
						test_step_done := true;
						exit; -- no more polling required 
						
					-- several BSC error states:
					when ex_state_error_compiler => -- test data invalid or not loaded yet
						result_test := not_loaded;
						test_step_done := true;
						exit;
					when ex_state_error_frmt => -- test data invalid or not loaded yet
						result_test := not_loaded;
						test_step_done := true;
						exit; -- no more searching required 
					when ex_state_error_act_scnpth => -- test data invalid or not loaded yet
						result_test := not_loaded;
						test_step_done := true;
						exit; -- no more searching required 
					when ex_state_error_sxr_type => -- test data invalid or not loaded yet
						result_test := not_loaded;
						test_step_done := true;
						exit; -- no more searching required 
					when ex_state_error_rd_sxr_sp_id => -- test data invalid or not loaded yet
						result_test := not_loaded;
						test_step_done := true;
						exit; -- no more searching required 
					when ex_state_wait_step_sxr | ex_state_shift => -- step mode
						result_test := pass;
						test_step_done := true;
						put_line("STEP MODE / WAIT");
						exit;
					when others => null;
				end case;
			end loop;

			-- if breakpoint set, display properties
			if bsc_register_breakpoint_sxr_id /= 0 then
				new_line;
				put_line("BREAKPOINT after:");
				put(" sxr :" & type_vector_id_breakpoint'image(type_vector_id_breakpoint(bsc_register_breakpoint_sxr_id)));
				if bsc_register_breakpoint_sxr_id = bsc_register_step_id then
					put(" ... reached");
				end if;
				if bsc_register_breakpoint_sxr_id < bsc_register_step_id then
					put(" ... passed");
				end if;
				new_line;

				if bsc_register_breakpoint_bit_pos /= 0 then
					put(" bit :" & type_sxr_break_position'image(type_sxr_break_position(bsc_register_breakpoint_bit_pos)) & " (one-based)");
					if bsc_register_breakpoint_bit_pos = bsc_register_processed_bits_1 or
						bsc_register_breakpoint_bit_pos = bsc_register_processed_bits_2 then
						put(" ... reached");
					end if;
					if bsc_register_breakpoint_bit_pos < bsc_register_processed_bits_1 and
						bsc_register_breakpoint_bit_pos < bsc_register_processed_bits_2 then
						put(" ... passed");
					end if;
					new_line;
				end if;
			end if;
					
			-- display information on processed sxr if step mode is tck OR a breakpoint at a certain bit pos. is set
			new_line;
			if step_mode = SXR or step_mode = TCK or
				bsc_register_breakpoint_sxr_id /= 0 or bsc_register_breakpoint_bit_pos /= 0 then
				put_line("DEBUG STATUS:"); new_line;
				put(" SXR #" & trim(type_vector_id_breakpoint'image(type_vector_id_breakpoint(bsc_register_step_id)),left));
				if step_mode = TCK then
					put(" ... in progress");
				end if;
				new_line;

				if step_mode = TCK or (bsc_register_breakpoint_sxr_id /= 0 and bsc_register_breakpoint_bit_pos /= 0) then

					-- display tap states
					new_line(2);
						for s in 1..scanport_count_max loop

							put_line(" TAP" & positive'image(s) & ":");
							put_line(" ------");
							display_scanport_bits(s); -- CS: show active scanpaths only

							case (bsc_register_state_tap_1_2 and 15 * (16**(s-1)) ) is 
								when m1_firmware.tap_test_logic_reset 	=> put_line(row_separator_0 & tap_test_logic_reset);
								when m1_firmware.tap_run_test_idle 		=> put_line(row_separator_0 & tap_run_test_idle);
								when m1_firmware.tap_select_dr_scan 	=> put_line(row_separator_0 & tap_select_dr_scan);
								when m1_firmware.tap_capture_dr 		=> put_line(row_separator_0 & tap_capture_dr);
								when m1_firmware.tap_shift_dr 			=> put_line(row_separator_0 & tap_shift_dr);
								when m1_firmware.tap_exit1_dr 			=> put_line(row_separator_0 & tap_exit1_dr);
								when m1_firmware.tap_pause_dr 			=> put_line(row_separator_0 & tap_pause_dr);
								when m1_firmware.tap_exit2_dr 			=> put_line(row_separator_0 & tap_exit2_dr);
								when m1_firmware.tap_update_dr			=> put_line(row_separator_0 & tap_update_dr);
								when m1_firmware.tap_select_ir_scan 	=> put_line(row_separator_0 & tap_select_ir_scan);
								when m1_firmware.tap_capture_ir 		=> put_line(row_separator_0 & tap_capture_ir);
								when m1_firmware.tap_shift_ir 			=> put_line(row_separator_0 & tap_shift_ir);
								when m1_firmware.tap_exit1_ir 			=> put_line(row_separator_0 & tap_exit1_ir);
								when m1_firmware.tap_pause_ir 			=> put_line(row_separator_0 & tap_pause_ir);
								when m1_firmware.tap_exit2_ir 			=> put_line(row_separator_0 & tap_exit2_ir);
								when m1_firmware.tap_update_ir			=> put_line(row_separator_0 & tap_update_ir);
								when others => null; -- CS: ERROR
							end case;

							put(" processed bits :");
							case s is
								when 1 =>
									put(type_sxr_fail_position'image(type_sxr_fail_position(bsc_register_processed_bits_1)) & "/" &
										trim(type_sxr_fail_position'image(type_sxr_fail_position(bsc_register_length_sxr_1)),left));
								when 2 =>
									put(type_sxr_fail_position'image(type_sxr_fail_position(bsc_register_processed_bits_2)) & "/" &
										trim(type_sxr_fail_position'image(type_sxr_fail_position(bsc_register_length_sxr_2)),left));
								when others => null;
							end case;
							put_line(" (one-based)");
							put_line(" --------------------------------------");
							new_line;
						end loop;
				end if;
				--put_line(column_separator_0);
			end if;

				
			-- DIAGNOSIS
			case bsc_register_state_executor is
				when ex_state_test_fail => -- test failed
					put_line("Test" & row_separator_0 & failed & exclamation & " Diagnosis:");
					put_line("failed scanpath   :" & unsigned_8'image(bsc_register_failed_scanpath));
					put_line("step id (dec)     :" & type_vector_id'image(type_vector_id(bsc_register_step_id)));
					put("sxr length (dec)  :");
					case bsc_register_failed_scanpath is
						when 1 =>
							put(type_vector_length'image(type_vector_length(bsc_register_length_sxr_1)));
						when 2 =>
							put(type_vector_length'image(type_vector_length(bsc_register_length_sxr_2)));
						when others => null;
					end case;
					put_line(" (one-based)");

					put("sxr fail pos (dec):");
					case bsc_register_failed_scanpath is
						when 1 =>
							put(type_vector_length'image(type_vector_length(bsc_register_processed_bits_1)));
						when 2 =>
							put(type_vector_length'image(type_vector_length(bsc_register_processed_bits_2)));
						when others => null;
					end case;
					put_line(" (one-based)");

					--put("expected          : ");
					case bsc_register_failed_scanpath is
						when 1 =>
							if (bsc_register_scanport_bits_1_2 and 64) = 64 then
								expect_value := high;
							else
								expect_value := low;
							end if;
						when 2 =>
							if (bsc_register_scanport_bits_1_2 and 64 * 256) = 64 * 256 then
								expect_value := high;
							else
								expect_value := low;
							end if;
						when others => null;
					end case;
					--put_line(type_logic_level_as_word'image(expect_value));

					-- locate fail
					case bsc_register_failed_scanpath is
						when 1 =>
							locate_fail(
								test_name		=> test_name,
								failed_scanpath	=> type_scanport_id(bsc_register_failed_scanpath),
								sxr_id			=> type_vector_id(bsc_register_step_id),
								sxr_length		=> type_vector_length(bsc_register_length_sxr_1),
								sxr_fail_pos	=> type_sxr_fail_position(bsc_register_processed_bits_1 - 1), 
										-- since fail bit position is one-base we must subtract 1
										-- because locate_fail requires zero-based indexing 
								expect_value	=> expect_value
								);
						when 2 =>
							locate_fail(
								test_name		=> test_name,
								failed_scanpath	=> type_scanport_id(bsc_register_failed_scanpath),
								sxr_id			=> type_vector_id(bsc_register_step_id),
								sxr_length		=> type_vector_length(bsc_register_length_sxr_2),
								sxr_fail_pos	=> type_sxr_fail_position(bsc_register_processed_bits_2 - 1), 
										-- since fail bit position is one-base we must subtract 1
										-- because locate_fail requires zero-based indexing 
								expect_value	=> expect_value
								);
						when others => null;
					end case;
							
				when ex_state_test_abort => -- test aborted
					put_line("Test" & row_separator_0 & aborted & row_separator_0 & exclamation);

				when others => null;
			end case;


			interface_close;

			-- read bsc status to get rx/tx errors
			read_bsc_status_registers(interface_to_scan_master,display => false);
			
		else
			result_test := fail;
			message_on_scan_master_not_present;
		end if;

		set_output(previous_output);		
		return result_test;

		exception
			when others =>
				result_test := fail;
				raise;
				return result_test;
	end execute_test;

	function load_test
	-- Uploads a given test (vector file) in the BSC. Returns true if successful.
	-- Uses the page write mode when transferring the actual data.
		(
		test_name					: type_name_test.bounded_string;
		interface_to_scan_master	: type_interface_to_bsc.bounded_string
		) return boolean is
		use interfaces;
		use type_name_test;
		use type_interface_to_bsc;
		use m1_serial_communications;
		
		result_action		: boolean := false;
		base_address		: type_mem_address_byte; -- the mem address to load the file at
		previous_output		: ada.text_io.file_type renames current_output;
		byte_scratch		: unsigned_8;
		size_of_vec_file	: file_size;
		page_count			: natural;
		byte_count_total	: natural;
		fill_byte_count		: natural;
	begin
		set_output(standard_output);		
		if scan_master_present then		
			if exists (compose (to_string(test_name), to_string(test_name), file_extension_vector)) then -- CS: use function test_compiled ?
				put_line ("test name      : " & to_string(test_name));
				base_address := string_to_natural(get_test_base_address(test_name) & 'h');
				put_line ("base address   : " & natural_to_string(natural_in => base_address, base => 16, length => 8));
				size_of_vec_file := size(compose (to_string(test_name), to_string(test_name), file_extension_vector));
				put_line ("file size      :" & natural'image(natural(size_of_vec_file))); 

				interface_init(interface_name => to_string(interface_to_scan_master));

				-- clear command
				interface_write(sercom_head_write);
				interface_write(sercom_addr_cmd);
				interface_write(sercom_cmd_null);

				-- set path
				interface_write(sercom_head_write);
				interface_write(sercom_addr_path);
				interface_write(sercom_path_rf_writes_ram);

				-- set start address
				interface_write(sercom_head_write);
				interface_write(sercom_addr_addr_start_a);
				interface_write(get_byte_from_doubleword(word_in => unsigned_32(base_address), position => 0));

				interface_write(sercom_head_write);
				interface_write(sercom_addr_addr_start_b);
				interface_write(get_byte_from_doubleword(word_in => unsigned_32(base_address), position => 1));

				interface_write(sercom_head_write);
				interface_write(sercom_addr_addr_start_c);
				interface_write(get_byte_from_doubleword(word_in => unsigned_32(base_address), position => 2));

				-- SEND FILE
				-- open vector file
				seq_io_unsigned_byte.open(file_vector, seq_io_unsigned_byte.in_file, 
					compose(to_string(test_name), to_string(test_name), file_extension_vector));

				-- If vector file is smaller than a page, the page_count must be set to 1. Because
				-- we are going to transfer at least one page.
				-- If vector file is larger than a page, calculate the number of pages required. Round up if nessecariy.
				if ( natural(size_of_vec_file) < sercom_page_size ) then -- only one page
					page_count := 1;
				else -- more than one page
					page_count := natural(size_of_vec_file) / sercom_page_size;
					if ( natural(size_of_vec_file) rem sercom_page_size ) > 0 then -- round up
						page_count := page_count + 1;
					end if;
				end if;

				-- Send header with page bit set.
				interface_write(sercom_head_write + sercom_head_page);

				-- Calculate the number of fill bits required in case the last page is not completely filled 
				-- with payload data. 
				-- Calculate the total number of bytes to transfer (incl. fill bytes)
				fill_byte_count := page_count * sercom_page_size - natural(size_of_vec_file);
				byte_count_total := natural(size_of_vec_file) + fill_byte_count;
--				put_line("byte count total " & natural'image(byte_count_total));

				-- Send payload bytes one by one. When the actual number of "real" data bytes
				-- is reached, start sending fill bytes. When a new page is to begin, send header (with page bit set).
				for b in 1..byte_count_total loop
--					put("byte " & natural'image(b));

					if b <= natural(size_of_vec_file) then -- get real data from vector file
						seq_io_unsigned_byte.read(file_vector, byte_scratch);
					else -- set fill byte
						byte_scratch := sercom_page_fill_byte;
					end if;
					
					interface_write(byte_scratch); -- send data

					-- send header when new page begins (execpt when last byte has been transferred)
					if b < byte_count_total then
						if (b rem sercom_page_size) = 0 then
							-- CS: read rx errors
							put(".");
							interface_write(sercom_head_write + sercom_head_page);
						end if;
					end if;
				end loop;
-- 				if page_count > 2 then 
-- 					new_line;
-- 				end if;
				-- CS: read rx errors

				-- close vector file
				seq_io_unsigned_byte.close(file_vector);

				-- set path
				interface_write(sercom_head_write);
				interface_write(sercom_addr_path);
				interface_write(sercom_path_null);
						
				interface_close;

				-- read bsc status to get rx/tx errors
				read_bsc_status_registers(interface_to_scan_master,display => false);
				
				result_action := true;
			else
				put_line(message_error & "Test '"& to_string(test_name) & "' either does not exist or has not been compiled yet !");
				put_line("        Please generate/compile test, then try again.");
				result_action := false;
			end if;
		else
			message_on_scan_master_not_present;
		end if;
		
		set_output(previous_output);
		return result_action;

		exception
			when others =>
				result_action := false;
				return result_action;
	end load_test;

	function dump_ram
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string;
		mem_addr					: in type_mem_address_byte
		) return boolean is
		use interfaces;
		use type_interface_to_bsc;
		use m1_serial_communications;
		
		result_action		: boolean := false;
		previous_output		: ada.text_io.file_type renames current_output;
		backup_addr_start_a	: unsigned_8;
		backup_addr_start_b	: unsigned_8;
		backup_addr_start_c	: unsigned_8;
		byte_scratch		: unsigned_8;
		mem_addr_scratch	: type_mem_address_byte := mem_addr;
	begin
		set_output(standard_output);
		if scan_master_present then		

			-- backup current start address
			interface_init(interface_name => to_string(interface_to_scan_master));
			interface_write(sercom_head_read);
			interface_write(sercom_addr_addr_start_a);
			backup_addr_start_a := interface_read; -- lowbyte

			interface_write(sercom_head_read);
			interface_write(sercom_addr_addr_start_b);
			backup_addr_start_b := interface_read;

			interface_write(sercom_head_read);
			interface_write(sercom_addr_addr_start_c);
			backup_addr_start_c := interface_read; -- highbyte

			-- set path
			interface_write(sercom_head_write);
			interface_write(sercom_addr_path);
			interface_write(sercom_path_rf_reads_ram);

			-- set address to read ram content from
			interface_write(sercom_head_write);
			interface_write(sercom_addr_addr_start_a);
			byte_scratch := get_byte_from_doubleword( 
				word_in => unsigned_32(mem_addr),
				position => 0);
			interface_write(byte_scratch); -- lowbyte
			
			interface_write(sercom_head_write);
			interface_write(sercom_addr_addr_start_b);
			byte_scratch := get_byte_from_doubleword( 
				word_in => unsigned_32(mem_addr),
				position => 1);
			interface_write(byte_scratch);

			interface_write(sercom_head_write);
			interface_write(sercom_addr_addr_start_c);
			byte_scratch := get_byte_from_doubleword( 
				word_in => unsigned_32(mem_addr),
				position => 2);
			interface_write(byte_scratch); -- highbyte
			
			-- READ DATA
			-- The RAM dump has 10 rows with 16 bytes each.
			-- On each read access the BSC increments the address automatically.
			-- Variable mem_addr_scratch is ouput at the begin of a row and must be incremented 
			-- on each read access too.
			for row in 1..10 loop

				-- begin of row
				put(natural_to_string(natural_in => mem_addr_scratch, base => 16, length => 6));

				for l in 1..16 loop
					-- read access
					interface_write(sercom_head_read);
					interface_write(sercom_addr_data);
					byte_scratch := interface_read; -- data read

					-- display the byte just read
					put(row_separator_0 & 
						natural_to_string(natural_in => natural(byte_scratch), base => 16, length => 2)(1..2)
					);

					-- increment address (used for displaying only. the bsc has internal ram address which
					-- increments on every read access.)
					mem_addr_scratch := mem_addr_scratch + 1;
				end loop;
				new_line;

			end loop;
			
			-- restore start address
			interface_write(sercom_head_write);
			interface_write(sercom_addr_addr_start_a);
			interface_write(backup_addr_start_a); -- lowbyte

			interface_write(sercom_head_write);
			interface_write(sercom_addr_addr_start_b);
			interface_write(backup_addr_start_b);

			interface_write(sercom_head_write);
			interface_write(sercom_addr_addr_start_c);
			interface_write(backup_addr_start_c); -- highbyte

			-- set path
			interface_write(sercom_head_write);
			interface_write(sercom_addr_path);
			interface_write(sercom_path_null);
			
			interface_close;

			-- read bsc status to get rx/tx errors
			read_bsc_status_registers(interface_to_scan_master,display => false);
			
			result_action	:= true;
		else
			message_on_scan_master_not_present;
		end if;
		
		set_output(previous_output);
		return result_action;

		exception
			when others =>
				result_action := false;
				return result_action;

	end dump_ram;

	function clear_ram
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string
		) return boolean is

		use interfaces;
		use type_interface_to_bsc;
		use m1_serial_communications;

		result_action	: boolean := false;
		previous_output	: ada.text_io.file_type renames current_output;
		byte_scratch	: unsigned_8;
	begin
		set_output(standard_output);
		if scan_master_present then		
			new_line;

			interface_init(interface_name => to_string(interface_to_scan_master));
			
			interface_write(sercom_head_write);
			interface_write(sercom_addr_cmd);
			interface_write(sercom_cmd_null);

			-- set path
			interface_write(sercom_head_write);
			interface_write(sercom_addr_path);
			interface_write(sercom_path_null);

			-- clear ram
			interface_write(sercom_head_write);
			interface_write(sercom_addr_cmd);
			interface_write(sercom_cmd_clear_ram);

			delay 1.0; -- CS: we assume the ram clearing is done within this time. status polling ?
			
			interface_write(sercom_head_read); -- head read
			interface_write(sercom_addr_path_state_mmu_readback);
			byte_scratch := interface_read; -- data read

			-- status check
			if byte_scratch = path_null * 16 + mmu_state_rout1 then -- equals F4h or 244d
				result_action := true;
			else
				result_action := false;
			end if;

			interface_close;

			-- read bsc status to get rx/tx errors
			read_bsc_status_registers(interface_to_scan_master,display => false);
		else
			message_on_scan_master_not_present;
		end if;

		set_output(previous_output);
		return result_action;

		exception
			when others =>
				result_action := false;
				return result_action;
	end clear_ram;

	function show_firmware
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string
		) return boolean is

		use type_interface_to_bsc;
		use m1_serial_communications;
		
		result_action	: boolean := false;
		previous_output	: ada.text_io.file_type renames current_output;
	begin
		set_output(standard_output);		

		if scan_master_present then
			read_bsc_status_registers(interface_to_scan_master);
			put_line(bsc_text_firmware_executor & row_separator_0 &
					natural_to_string(natural_in => natural(bsc_register_firmware_executor), base => 16, length => 4)(1..4)
					);
			result_action := true;
		else
			message_on_scan_master_not_present;
		end if;
		
		set_output(previous_output);
		return result_action;

		exception
			when others =>
				result_action := false;
				return result_action;
		
	end show_firmware;


	function set_breakpoint
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string;
		vector_id_breakpoint		: in type_vector_id_breakpoint;
		bit_position				: in type_sxr_break_position
		) return boolean is

		use interfaces;
		use type_interface_to_bsc;
		use m1_serial_communications;

		result_action	: boolean := false;
	begin
		if scan_master_present then
			interface_init(interface_name => to_string(interface_to_scan_master));

			-- set sxr id
			interface_write(sercom_head_write);
			interface_write(sercom_addr_breakpoint_sxr_a); -- lowbyte
			interface_write(get_byte_from_word(word_in => unsigned_16(vector_id_breakpoint), position => 0));
			
			interface_write(sercom_head_write);
			interface_write(sercom_addr_breakpoint_sxr_b); -- highbyte
			interface_write(get_byte_from_word(word_in => unsigned_16(vector_id_breakpoint), position => 1));

			-- bit position
			interface_write(sercom_head_write);
			interface_write(sercom_addr_breakpoint_bit_pos_a); -- lowbyte
			interface_write(get_byte_from_doubleword(word_in => unsigned_32(bit_position), position => 0));
			
			interface_write(sercom_head_write);
			interface_write(sercom_addr_breakpoint_bit_pos_b);
			interface_write(get_byte_from_doubleword(word_in => unsigned_32(bit_position), position => 1));

			interface_write(sercom_head_write);
			interface_write(sercom_addr_breakpoint_bit_pos_c);
			interface_write(get_byte_from_doubleword(word_in => unsigned_32(bit_position), position => 2));

			interface_write(sercom_head_write);
			interface_write(sercom_addr_breakpoint_bit_pos_d); -- highbyte
			interface_write(get_byte_from_doubleword(word_in => unsigned_32(bit_position), position => 3));
			
			interface_close;

			-- CS: read back breakpoint data and verify. use read_bsc_status_registers

			-- read bsc status to get rx/tx errors
			read_bsc_status_registers(interface_to_scan_master,display => false);
			
			result_action := true;
		else
			message_on_scan_master_not_present;
		end if;

		return result_action;

		exception
			when others =>
				result_action := false;
				return result_action;
	end set_breakpoint;

	
	procedure read_bsc_status_registers
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string;
		display 					: in boolean := false
		) is
		use interfaces;
		use m1_serial_communications;
		use type_interface_to_bsc;
	begin
		interface_init(interface_name => to_string(interface_to_scan_master));

		-- state executor
		interface_write(sercom_head_read);
		interface_write(sercom_addr_state_executor);
		bsc_register_state_executor := interface_read;

		-- step id
		interface_write(sercom_head_read);
		interface_write(sercom_addr_sxr_id_a);
		bsc_register_step_id := unsigned_16(interface_read); -- lowbyte

		interface_write(sercom_head_read);
		interface_write(sercom_addr_sxr_id_b);
		bsc_register_step_id := bsc_register_step_id + 256 * unsigned_16(interface_read); -- highbyte
		
		-- failed scanpath
		interface_write(sercom_head_read);
		interface_write(sercom_addr_failed_scanpath);
		bsc_register_failed_scanpath := interface_read; -- bit set for every failed scanpath -> display in binary form
		-- Multiple scanpaths may fail at the same time. We look for the lowest failed scanpath only. All other fail-bits
		-- are cleared in bsc_register_failed_scanpath :
		for s in 0..scanport_count_max-1 loop
			if test_bit_unsigned_8(bsc_register_failed_scanpath,s) then 
				bsc_register_failed_scanpath := unsigned_8(s+1);
				exit;
			end if;
		end loop;		

		-- sxr length 1
		interface_write(sercom_head_read);
		interface_write(sercom_addr_length_sxr_1_a);
		bsc_register_length_sxr_1 := unsigned_32(interface_read); -- lowbyte

		interface_write(sercom_head_read);
		interface_write(sercom_addr_length_sxr_1_b);
		bsc_register_length_sxr_1 := bsc_register_length_sxr_1 + 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_length_sxr_1_c);
		bsc_register_length_sxr_1 := bsc_register_length_sxr_1 + 256 * 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_length_sxr_1_d); -- highbyte
		bsc_register_length_sxr_1 := bsc_register_length_sxr_1 + 256 * 256 * 256 * unsigned_32(interface_read);
		
		-- sxr length 2
		interface_write(sercom_head_read);
		interface_write(sercom_addr_length_sxr_2_a);
		bsc_register_length_sxr_2 := unsigned_32(interface_read); -- lowbyte

		interface_write(sercom_head_read);
		interface_write(sercom_addr_length_sxr_2_b);
		bsc_register_length_sxr_2 := bsc_register_length_sxr_2 + 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_length_sxr_2_c);
		bsc_register_length_sxr_2 := bsc_register_length_sxr_2 + 256 * 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_length_sxr_2_d); -- highbyte
		bsc_register_length_sxr_2 := bsc_register_length_sxr_2 + 256 * 256 * 256 * unsigned_32(interface_read);

		-- processed bits 1
		interface_write(sercom_head_read);
		interface_write(sercom_addr_processed_bits_1_a);
		bsc_register_processed_bits_1 := unsigned_32(interface_read); -- lowbyte

		interface_write(sercom_head_read);
		interface_write(sercom_addr_processed_bits_1_b);
		bsc_register_processed_bits_1 := bsc_register_processed_bits_1 + 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_processed_bits_1_c);
		bsc_register_processed_bits_1 := bsc_register_processed_bits_1 + 256 * 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_processed_bits_1_d); -- highbyte
		bsc_register_processed_bits_1 := bsc_register_processed_bits_1 + 256 * 256 * 256 * unsigned_32(interface_read);

		-- processed bits 2
		interface_write(sercom_head_read);
		interface_write(sercom_addr_processed_bits_2_a);
		bsc_register_processed_bits_2 := unsigned_32(interface_read); -- lowbyte

		interface_write(sercom_head_read);
		interface_write(sercom_addr_processed_bits_2_b);
		bsc_register_processed_bits_2 := bsc_register_processed_bits_2 + 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_processed_bits_2_c);
		bsc_register_processed_bits_2 := bsc_register_processed_bits_2 + 256 * 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_processed_bits_2_d); -- highbyte
		bsc_register_processed_bits_2 := bsc_register_processed_bits_2 + 256 * 256 * 256 * unsigned_32(interface_read);
		
		-- breakpoint sxr id
		interface_write(sercom_head_read);
		interface_write(sercom_addr_breakpoint_sxr_a); -- lowbyte
		bsc_register_breakpoint_sxr_id := unsigned_16(interface_read); -- lowbyte

		interface_write(sercom_head_read);
		interface_write(sercom_addr_breakpoint_sxr_b); -- highbyte
		bsc_register_breakpoint_sxr_id := bsc_register_breakpoint_sxr_id + 256 * unsigned_16(interface_read);

		-- breakpoint bit pos
		interface_write(sercom_head_read);
		interface_write(sercom_addr_breakpoint_bit_pos_a);
		bsc_register_breakpoint_bit_pos := unsigned_32(interface_read); -- lowbyte

		interface_write(sercom_head_read);
		interface_write(sercom_addr_breakpoint_bit_pos_b);
		bsc_register_breakpoint_bit_pos := bsc_register_breakpoint_bit_pos + 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_breakpoint_bit_pos_c);
		bsc_register_breakpoint_bit_pos := bsc_register_breakpoint_bit_pos + 256 * 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_breakpoint_bit_pos_d); -- highbyte
		bsc_register_breakpoint_bit_pos := bsc_register_breakpoint_bit_pos + 256 * 256 * 256 * unsigned_32(interface_read);

		-- tap state 1 & 2
		interface_write(sercom_head_read);
		interface_write(sercom_addr_state_tap_1_2);
		bsc_register_state_tap_1_2 := interface_read;

		-- scanport bits 1 & 2
		interface_write(sercom_head_read);
		interface_write(sercom_addr_scanport_bits_1); -- lowbyte
		bsc_register_scanport_bits_1_2 := unsigned_16(interface_read); -- lowbyte

		interface_write(sercom_head_read);
		interface_write(sercom_addr_scanport_bits_2); -- highbyte
		bsc_register_scanport_bits_1_2 := bsc_register_scanport_bits_1_2 + 256 * unsigned_16(interface_read);

		-- i2c master
		interface_write(sercom_head_read);
		interface_write(sercom_addr_state_i2c);
		bsc_register_state_i2c_master := interface_read;

		-- cmd readback
		interface_write(sercom_head_read);
		interface_write(sercom_addr_cmd_readback);
		bsc_register_cmd_readback := interface_read;

		-- state llc processor
		interface_write(sercom_head_read);
		interface_write(sercom_addr_state_llc);
		bsc_register_state_llc_processor := interface_read;
		
		-- shifter 1
		interface_write(sercom_head_read);
		interface_write(sercom_add_state_shifter_1);
		bsc_register_state_shifter_1 := interface_read;

		-- shifter 2
		interface_write(sercom_head_read);
		interface_write(sercom_add_state_shifter_2);
		bsc_register_state_shifter_2 := interface_read;

		-- path and mmu state
		interface_write(sercom_head_read);
		interface_write(sercom_addr_path_state_mmu_readback);
		bsc_register_state_mmu := interface_read;

		-- address output by rf
		interface_write (sercom_head_read);
		interface_write (sercom_addr_addr_start_a); -- lowbyte [15:8]
		bsc_register_address_rf_out := 0;
		bsc_register_address_rf_out := unsigned_32 (interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_addr_start_b); -- [23:16]
		bsc_register_address_rf_out := bsc_register_address_rf_out + 256 * unsigned_32 (interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_addr_start_c); -- highbyte -- [31:24]
		bsc_register_address_rf_out := bsc_register_address_rf_out + 256 * 256 * unsigned_32 (interface_read);
		
		-- RAM address generated by executor
		interface_write(sercom_head_read);
		interface_write(sercom_addr_addr_ram_a); -- lowbyte
		bsc_register_ram_address_ex_out := unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_addr_ram_b);
		bsc_register_ram_address_ex_out := bsc_register_ram_address_ex_out + 256 * unsigned_32(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_addr_ram_c); -- highbyte
		bsc_register_ram_address_ex_out := bsc_register_ram_address_ex_out + 256 * 256 * unsigned_32(interface_read);

        -- output RAM data
--      interface_write(sercom_head_read);
--      interface_write(sercom_addr_data);
--      bsc_register_output_ram_data := interface_read; -- increments address output by rf
        
		-- CS: input RAM data
		
		-- firmware
		interface_write(sercom_head_read);
		interface_write(sercom_addr_firmware_executor_a); -- lowbyte
		bsc_register_firmware_executor := unsigned_16(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_firmware_executor_b); -- highbyte
		bsc_register_firmware_executor := bsc_register_firmware_executor + 256 * unsigned_16(interface_read);

		-- rx error counter
		interface_write(sercom_head_read);
		interface_write(sercom_addr_rx_error_counter_a); -- lowbyte
		bsc_register_rx_error_counter := unsigned_16(interface_read);

		interface_write(sercom_head_read);
		interface_write(sercom_addr_rx_error_counter_b); -- highbyte
		bsc_register_rx_error_counter := bsc_register_rx_error_counter + 256 * unsigned_16(interface_read);
		
		-- if display required as given as parameter
		if display then
			put_line(bsc_text_state_mmu & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_state_mmu), base => 16, length => 2));
			put_line(bsc_text_cmd & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_cmd_readback), base => 16, length => 2));			
			put_line(bsc_text_state_executor & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_state_executor), base => 16, length => 2));
			put_line(bsc_text_state_llc_processor & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_state_llc_processor), base => 16, length => 2));			
			put_line(bsc_text_state_shifter_1 & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_state_shifter_1), base => 16, length => 2));
			put_line(bsc_text_state_shifter_2 & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_state_shifter_2), base => 16, length => 2));			
			put_line(bsc_text_processed_step_id & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_step_id), base => 16, length => 4));
			put_line(bsc_text_failed_scanpath & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_failed_scanpath), base => 2, length => 8));
			put_line(bsc_text_chain_length_total & " 1" & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_length_sxr_1), base => 16, length => 8));
			put_line(bsc_text_chain_length_total & " 2" & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_length_sxr_2), base => 16, length => 8));
			put_line(bsc_text_bits_processed & " 1" & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_processed_bits_1), base => 16, length => 8));			
			put_line(bsc_text_bits_processed & " 2" & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_processed_bits_2), base => 16, length => 8));
			put_line(bsc_text_breakpoint_step_id & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_breakpoint_sxr_id), base => 16, length => 4));
			put_line(bsc_text_breakpoint_bit_position & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_breakpoint_bit_pos), base => 16, length => 8));			
			put_line(bsc_text_state_tap & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_state_tap_1_2), base => 16, length => 2));	-- CS: decode to human understandable form like RTI or Pause-DR
			put_line(bsc_text_scanport_bits & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_scanport_bits_1_2), base => 2, length => 16)); -- CS: decode to TDI,EXP,MASK,FAIL,TRST,TDO,TMS,TCK
			put_line(bsc_text_state_i2c_master & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_state_i2c_master), base => 16, length => 2));
			put_line (bsc_text_address_rf_out & row_separator_0 & natural_to_string (natural_in => natural (bsc_register_address_rf_out), base => 16, length => 8));
			put_line(bsc_text_ram_address_ex_out & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_ram_address_ex_out), base => 16, length => 8));
			--put_line(bsc_text_output_ram_data & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_output_ram_data), base => 16, length => 2));
			put_line(bsc_text_firmware_executor & row_separator_0 & natural_to_string(natural_in => natural(bsc_register_firmware_executor), base => 16, length => 4));
		end if;

		-- RX AND TX ERRORS ARE DISPLAYED IF ANY OCCURED, REGARDLESS OF PARAMETER "DISPLAY"
		if bsc_register_rx_error_counter > 0 then
			-- bsc rx errors are displayed in decimal notation
			put_line(message_warning & bsc_text_rx_errors & natural'image(natural(bsc_register_rx_error_counter)));
		end if;

		if interface_rx_error_count > 0 then
			-- host machine tx errors are displayed in decimal notation
			put_line(message_warning & bsc_text_tx_errors & natural'image(interface_rx_error_count)); 
			-- NOTE: read comments in m1_firmware.ads !!
		end if;

		
		interface_close;

		exception
			when others =>
				raise; -- CS: return false

	end read_bsc_status_registers;


	function query_status
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string
		) return boolean is

		use m1_serial_communications;
		
		result_action	: boolean := false;
		previous_output	: ada.text_io.file_type renames current_output;
	begin
		set_output(standard_output);
		if scan_master_present then		
			read_bsc_status_registers(interface_to_scan_master,display => true);

			case bsc_register_state_executor is
				when ex_state_end_of_test =>
					put_line("Test PASSED");
				when ex_state_test_fail =>
					put_line("Test FAILED");
				when ex_state_error_frmt | ex_state_error_act_scnpth | ex_state_error_sxr_type | ex_state_error_rd_sxr_sp_id =>
					put_line("Test NOT LOADED or INVALID");
				when ex_state_wait_step_sxr | ex_state_shift =>
					put_line("STEP MODE / WAIT");
				when ex_state_test_abort =>
					put_line("Test ABORTED");
				when ex_state_idle =>
					put_line("IDLE/RESET");
				when others => 
					put_line("Test RUNNING");
			end case;
				
			result_action := true;
		else
			message_on_scan_master_not_present;
		end if;

		set_output(previous_output);
		return result_action;

		exception
			when others =>
				result_action := false;
				return result_action;
		
	end query_status;

	function shutdown
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string
		) return boolean is
		
		use m1_serial_communications;
		use type_interface_to_bsc;
		
		result_action	: boolean := false;
		previous_output	: ada.text_io.file_type renames current_output;
	begin
		set_output(standard_output);

		if scan_master_present then
			interface_init(interface_name => to_string(interface_to_scan_master));

			-- clear command
			interface_write(sercom_head_write);
			interface_write(sercom_addr_cmd);
			interface_write(sercom_cmd_null);

			-- send command "abort"
			interface_write(sercom_head_write);
			interface_write(sercom_addr_cmd);
			interface_write(sercom_cmd_test_abort);

			-- break data path
			interface_write(sercom_head_write);
			interface_write(sercom_addr_path);
			interface_write(sercom_path_null);

			read_bsc_status_registers(interface_to_scan_master);

			-- verify executor has aborted test
			case bsc_register_state_executor is
				when ex_state_test_abort =>
					--put_line("Test ABORTED");
					result_action := true;
				when others => 
					result_action := false;
			end case;

			interface_close;

			-- read bsc status to get rx/tx errors
			read_bsc_status_registers(interface_to_scan_master,display => false);
			
		else
			message_on_scan_master_not_present;
		end if;

		set_output(previous_output);
		return result_action;

		exception
			when others =>
				result_action := false;
				return result_action;
--				raise;
	end shutdown;

	function test_compiled (name_test : in type_name_test.bounded_string) return boolean is
	-- Returns true if given test directory contains a vector file.
	-- name_test is assumed as absolute path !
		use type_name_test;
	begin
		--put_line(name_test & row_separator_0 & simple_name(name_test) & row_separator_0 & file_extension_vector);
		if exists (compose (to_string(name_test), simple_name(to_string(name_test)), file_extension_vector)) then
			return true;
		end if;
		return false;
	end test_compiled;

	
end m1_test_gen_and_exec;
