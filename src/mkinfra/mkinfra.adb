------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKINFRA                             --
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
--   todo: - alorithm that switches bics back to bypass once a particular register
--           has been tested.

with ada.text_io;				use ada.text_io;
with ada.integer_text_io;		use ada.integer_text_io;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling; 	use ada.characters.handling;

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

procedure mkinfra is

	version			: string (1..3) := "001";
	prog_position	: natural := 0;

	use type_name_database;
	use type_device_name;
	use type_name_test;
	
	type type_algorithm is ( standard , intrusive);
	algorithm : constant type_algorithm := standard;
	--type type_option is ( none, intrusive ); -- CS

	end_sir			: type_end_sir		:= RTI;
	end_sdr			: type_end_sdr		:= RTI;

	procedure write_info_section is
	-- creates the sequence file,
	-- directs subsequent puts into the sequence file
	-- writes the info section into the sequence file

		colon_position : positive := 19;
	begin
		write_message (
			file_handle => file_mkinfra_messages,
			text => "writing test info ...",
			console => false);

		put_line(file_sequence, section_mark.section & row_separator_0 & test_section.info);
		put_line(file_sequence, " created by infra structure test generator " & to_upper(name_module_mkinfra) & " version "& version);
		put_line(file_sequence, row_separator_0 & section_info_item.date & (colon_position-(2+section_info_item.date'last)) * row_separator_0 & ": " & date_now);
		put_line(file_sequence, row_separator_0 & section_info_item.database & (colon_position-(2+section_info_item.database'last)) * row_separator_0 & ": " & to_string(name_file_database));
		put_line(file_sequence, row_separator_0 & section_info_item.name_test & (colon_position-(2+section_info_item.name_test'last)) * row_separator_0 & ": " & to_string(name_test));
		put_line(file_sequence, row_separator_0 & section_info_item.test_profile & (colon_position-(2+section_info_item.test_profile'last)) * row_separator_0 & ": " & type_test_profile'image(test_profile));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sdr & (colon_position-(2+section_info_item.end_sdr'last)) * row_separator_0 & ": " & type_end_sdr'image(end_sdr));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sir & (colon_position-(2+section_info_item.end_sir'last)) * row_separator_0 & ": " & type_end_sir'image(end_sir));

		put_line(file_sequence, " bic count        :" & positive'image(summary.bic_ct));
		--put_line (" bic count        :" & positive'image(natural(type_list_of_bics.length(list_of_bics))));
		put_line(file_sequence, " algorithm        : " & type_algorithm'image(standard));
		--put_line (" options       : " & type_option'image()); -- CS 
		put_line(file_sequence, section_mark.endsection); 
	end;

	procedure write_sequences is

		procedure one_of_all( 
			position	: positive; 
			instruction	: type_bic_instruction_for_infra_structure;
			write_sxr	: boolean := true
			) is
		begin -- one_of_all
			for b in 1..type_list_of_bics.length(list_of_bics) loop    
				if positive(b) = position then -- if bic id matches position:

					-- if desired instruction does not exist, skip writing test vector and exit
					case instruction is
						when bypass		=> if not instruction_present(type_list_of_bics.element(list_of_bics,positive(b)).opc_bypass) 
							then 
								write_message (
									file_handle => file_mkinfra_messages,
									text => message_error & "device " & to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) 
											& "' does not support mandatory " & type_bic_instruction'image(bypass) & " mode !",
									console => true);
								raise constraint_error;
							end if;
						when idcode		=> if not instruction_present(type_list_of_bics.element(list_of_bics,positive(b)).opc_idcode) then exit; end if;
						when usercode	=> if not instruction_present(type_list_of_bics.element(list_of_bics,positive(b)).opc_usercode) then exit; end if;
						when preload	=> if not instruction_present(type_list_of_bics.element(list_of_bics,positive(b)).opc_preload) then exit; end if;
						when sample		=> if not instruction_present(type_list_of_bics.element(list_of_bics,positive(b)).opc_sample) then
							write_message (
								file_handle => file_mkinfra_messages,
								text => message_warning & "device " & to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) 
									 & "' does not support " & type_bic_instruction'image(sample) & " mode !",
								console => true);
							exit; end if;
						when extest		=> if not instruction_present(type_list_of_bics.element(list_of_bics,positive(b)).opc_extest) then exit; end if;
					end case;
					-- instruction exists

					-- write instruction drive (default part)
					-- example: "set IC301 drv ir 7 downto 0 := "
					--new_line(file_sequence);
					put(file_sequence, row_separator_0 
						& sequence_instruction_set.set & row_separator_0
						& to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) & row_separator_0
						& sxr_io_identifier.drive & row_separator_0
						& sir_target_register.ir
						& type_register_length'image(type_list_of_bics.element(list_of_bics,positive(b)).len_ir - 1) & row_separator_0
						& sxr_vector_orientation.downto & row_separator_0 & "0" & row_separator_0
						& sxr_assignment_operator.assign & row_separator_0
						);
					-- write instruction depended part
					case instruction is
						when idcode => 		put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).opc_idcode); -- example: "11111110 idcode"
						when usercode => 	put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).opc_usercode);
						when sample => 		put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).opc_sample);
						when preload =>		put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).opc_preload);
						when extest => 
							write_message (
								file_handle => file_mkinfra_messages,
								text => message_warning & "device " & to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) 
									 & "' WILL BE OPERATED IN " & type_bic_instruction'image(extest) & " MODE !",
								console => true);

							put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).opc_extest);
						when others => 
							write_message (
								file_handle => file_mkinfra_messages,
								text => message_error & "instruction " & type_bic_instruction'image(instruction)
										& " not allowed for " & type_test_profile'image(test_profile) & " test !",
								console => true);
							raise constraint_error;
					end case;
					put_line(file_sequence, row_separator_0 & to_lower(type_bic_instruction'image(instruction)));

					if write_sxr then
						write_sir;
					end if;
					new_line(file_sequence);
					
					-- WRITE DATA DRIVE (default part)
					-- example: "set IC300 drv"
					put(file_sequence, row_separator_0 
						& sequence_instruction_set.set & row_separator_0
						& to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) & row_separator_0
						& sxr_io_identifier.drive & row_separator_0
						);
					-- write instruction depended part
					case instruction is
						when idcode =>
							-- example: "idcode 31 downto 0 := 0"
							put_line(file_sequence, sdr_target_register.idcode
								--& " 31 " & sxr_vector_direction.downto 
								& type_register_length'image(bic_idcode_register_length - 1)
								& row_separator_0
								& sxr_vector_orientation.downto 
								& " 0 "
								& sxr_assignment_operator.assign
								& " 0" -- we drive 32bits of 0 into the register. but it is a read-only register (as specified in std)
								);

						when usercode =>
							-- example: "usercode 31 downto 0 := 0"
							put_line(file_sequence, sdr_target_register.usercode
								& type_register_length'image(bic_usercode_register_length -1)
								& row_separator_0
								& sxr_vector_orientation.downto 
								& " 0 "
								& sxr_assignment_operator.assign
								& " 0" -- we drive 32bits of 0 into the register. but it is a read-only register (as specified in std)
								);

						when others => -- sample, preload, extest
							-- example: "boundary 5 downto 0 := XXX11"
							put(file_sequence, sdr_target_register.boundary
								& natural'image(type_list_of_bics.element(list_of_bics,positive(b)).len_bsr - 1) & row_separator_0 & sxr_vector_orientation.downto 
								& " 0 "
								& sxr_assignment_operator.assign & row_separator_0
							   );
							put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).safebits);
							new_line(file_sequence);
					end case;
					
					-- WRITE DATA EXPECT (default part)
					-- example: "set IC300 exp"
					put(file_sequence, row_separator_0 
						& sequence_instruction_set.set & row_separator_0
						& to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) & row_separator_0
						& sxr_io_identifier.expect & row_separator_0
						);
					-- write instruction depended part
					case instruction is
						when idcode =>
							-- example: "idcode 31 downto 0 = xxxx1001010100000010000010010011"
							put(file_sequence, sdr_target_register.idcode
								& type_register_length'image(bic_idcode_register_length -1)
								& row_separator_0 
								& sxr_vector_orientation.downto 
								& " 0 "
								& sxr_assignment_operator.assign & row_separator_0
							   );
							put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).idcode); -- expect the idcode acc. bsdl. regardless what has been written here (see above)

						when usercode =>
							-- example: "usercode 31 downto 0 = xxxx1001010100000010000010010011"
							put(file_sequence, sdr_target_register.usercode
								& type_register_length'image(bic_usercode_register_length -1)
								& row_separator_0
								& sxr_vector_orientation.downto 
								& " 0 "
								& sxr_assignment_operator.assign & row_separator_0
							   );
							put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).usercode); -- expect the idcode acc. bsdl. regardless what has been written here (see above)
							-- NOTE: if usercode not programmed yet, it is all x

						when others => -- sample, preload, extest
							-- example: "boundary 5 downto 0 := X"
							put(file_sequence, sdr_target_register.boundary
								& natural'image(type_list_of_bics.element(list_of_bics,positive(b)).len_bsr - 1) & row_separator_0 & sxr_vector_orientation.downto 
								& " 0 "
								& sxr_assignment_operator.assign
								& " X "
								);

					end case;
					new_line(file_sequence);

					if write_sxr then
						write_sdr;
					end if;
					new_line(file_sequence);
					
					exit; -- bic addressed by p processed. no further search of bic required
				end if; -- if bic id matches position

			end loop;
		end one_of_all;

	begin -- write_sequences
		put_line("writing ir/dr scans for testing of ...");
		
		new_line(file_sequence,2);
		put_line(" bypass registers ...");
		put_line(file_sequence," -- BYPASS REGISTER TEST");

		-- write sir bypass:

		-- the bic shall be written into the seq file in the same order as section scanpath configuration (see udb)
		-- the scanpath itself does not matter here

		-- writes something like:

-- 		set IC301 drv ir 7 downto 0 = 11111111 bypass
-- 		set IC301 exp ir 7 downto 0 = 000xxx01
-- 		set IC300 drv ir 7 downto 0 = 11111111 bypass
-- 		set IC300 exp ir 7 downto 0 = 000xxx01
-- 		set IC303 drv ir 7 downto 0 = 11111111 bypass
-- 		set IC303 exp ir 7 downto 0 = 10000001
-- 		sir id 1

		for b in 1..type_list_of_bics.length(list_of_bics) loop    

			-- write instruction drive
			put(file_sequence, row_separator_0 
				& sequence_instruction_set.set & row_separator_0
				& to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) & row_separator_0
				& sxr_io_identifier.drive & row_separator_0
				& sir_target_register.ir
				& type_register_length'image(type_list_of_bics.element(list_of_bics,positive(b)).len_ir - 1) & row_separator_0
				& sxr_vector_orientation.downto & row_separator_0 & "0" & row_separator_0
				& sxr_assignment_operator.assign & row_separator_0
			   );
			put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).opc_bypass);
			put_line(file_sequence," bypass");

			-- write instruction capture
			put(file_sequence, row_separator_0 
				& sequence_instruction_set.set & row_separator_0
				& to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) & row_separator_0
				& sxr_io_identifier.expect & row_separator_0
				& sir_target_register.ir
				& type_register_length'image(type_list_of_bics.element(list_of_bics,positive(b)).len_ir - 1) & row_separator_0
				& sxr_vector_orientation.downto & row_separator_0 & "0" & row_separator_0
				& sxr_assignment_operator.assign & row_separator_0
			   );
			put_binary_class_1(file => file_sequence, binary_in => type_list_of_bics.element(list_of_bics,positive(b)).capture_ir);
			new_line(file_sequence);

		end loop;

		write_sir;
		new_line(file_sequence);

		-- write sdr bypass:

-- 		set IC301 drv bypass 1=1
-- 		set IC301 exp bypass 1=0
-- 		set IC300 drv bypass 1=1
-- 		set IC300 exp bypass 1=0
-- 		set IC303 drv bypass 1=1
-- 		set IC303 exp bypass 1=0
-- 		sdr id 2


		for b in 1..type_list_of_bics.length(list_of_bics) loop                

			-- write data drive
			put(file_sequence, row_separator_0 
				& sequence_instruction_set.set & row_separator_0
				& to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) & row_separator_0
				& sxr_io_identifier.drive & row_separator_0
				& sdr_target_register.bypass
				& " 0" -- bit position (since this addresses the bypass register)
				& sxr_assignment_operator.assign
				& "1" -- we drive a 1 into the register. if it is a read-only register (as specified in std) a 0 is expected
				);
			new_line(file_sequence);

			-- write data expect
			put(file_sequence, row_separator_0 
				& sequence_instruction_set.set & row_separator_0
				& to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) & row_separator_0
				& sxr_io_identifier.expect & row_separator_0
				& sdr_target_register.bypass
				& " 0" -- bit position (since this addresses the bypass register)
				& sxr_assignment_operator.assign
				& type_bit_char_class_0'image(type_list_of_bics.element(list_of_bics,positive(b)).capture_bypass)(2) -- expect a 0 acc. std. regardless what has been written here (see above)
				);
			new_line(file_sequence);

		end loop;

		write_sdr;

		-- IDCODE CHECK ---------------------
		put_line(" idcodes ...");
		new_line(file_sequence,2);
		put_line(file_sequence, " -- IDCODE REGISTER TEST");
		for p in 1..summary.bic_ct loop -- process as much as bics are in udb
			one_of_all(p,idcode);
		end loop;


		-- USERCODE CHECK ---------------------
		put_line(" usercodes ...");
		new_line(file_sequence,2);
		put_line(file_sequence," -- USERCODE REGISTER TEST");
		for p in 1..summary.bic_ct loop -- process as much as bics are in udb
			one_of_all(p,usercode);
		end loop;

		-- BOUNDARY REGISTER CHECK ---------------------
		put_line(" boundary registers ...");
		new_line(file_sequence,2);
		put_line(file_sequence," -- BOUNDARY REGISTER TEST");

		-- We test the boundary registers in both the sample and preload mode:
		for p in 1..summary.bic_ct loop -- process as much as bics are in udb
			one_of_all(p,sample);
		end loop;

		for p in 1..summary.bic_ct loop -- process as much as bics are in udb
			one_of_all(p,preload);
		end loop;

		-- CAUTION: USE FOR INTRUSIVE MODE ONLY
		if algorithm = intrusive then
			for p in 1..summary.bic_ct loop -- process as much as bics are in udb
				one_of_all(
					position 	=> p,
					instruction => extest,
					write_sxr	=> false
					);
			end loop;
			write_sir; -- SWTICHING TO EXTEST MUST HAPPEN FOR ALL BICS SIMULTANEOUSLY
			write_sdr;
		end if;

		new_line(file_sequence);
		put_line(file_sequence, row_separator_0 & sequence_instruction_set.trst);
		put_line(file_sequence, section_mark.endsection);

	end write_sequences;


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := generate;
	test_profile := infrastructure;
	
	-- create message/log file
 	write_log_header(version);

	put_line(to_upper(name_module_mkinfra) & " version " & version);
	put_line("===========================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages

	prog_position	:= 10;
 	name_file_database := to_bounded_string(argument(1));

	write_message (
		file_handle => file_mkinfra_messages,
		text => text_identifier_database & row_separator_0 & to_string(name_file_database),
		console => true);

	prog_position	:= 20;
	name_test := to_bounded_string(argument(2));
	write_message (
		file_handle => file_mkinfra_messages,
		text => text_test_name & row_separator_0 & to_string(name_test),
		console => true);

	prog_position	:= 30;
	create_temp_directory;

	-- CS: get algorithm as argument
	-- for the time being it is constant
	--algorithm := standard;

	prog_position	:= 40;
	degree_of_database_integrity_check := light;
	read_uut_database;

	put_line("start test generation ...");

	prog_position	:= 50;
	create_test_directory(name_test);

	-- create sequence file
	prog_position	:= 60;
	create( file_sequence, 
		name => (compose (to_string(name_test), to_string(name_test), file_extension_sequence)));


-- 	prog_position	:= 70;
-- 	set_output(file_sequence); -- set data sink	
	
	prog_position	:= 80;
	write_info_section;

	prog_position	:= 90;
	write_test_section_options;

	prog_position	:= 100;
	write_test_init;

	prog_position	:= 110;
	write_sequences;

	prog_position	:= 120;
	set_output(standard_output);
	close(file_sequence);

	prog_position 	:= 130;
	write_log_footer;

	exception when event: others =>
		set_exit_status(failure);

		write_message (
			file_handle => file_mkinfra_messages,
			text => message_error & "at program position" & natural'image(prog_position),
			console => true);

		if is_open(file_sequence) then
			close(file_sequence);
		end if;

		case prog_position is
			when 10 =>
				write_message (
					file_handle => file_mkinfra_messages,
					text => message_error & text_identifier_database & " file missing !" & latin_1.lf
						& "Provide " & text_identifier_database & " name as argument. Example: "
						& name_module_mkinfra & row_separator_0 & example_database,
					console => true);

			when 20 =>
				write_message (
					file_handle => file_mkinfra_messages,
					text => message_error & "test name missing !" & latin_1.lf
						& "Provide test name as argument ! Example: " 
						& name_module_mkinfra & row_separator_0 & example_database 
						& " my_infrastructure_test",
					console => true);

			when others =>
				write_message (
					file_handle => file_mkinfra_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_mkinfra_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;
end mkinfra;
