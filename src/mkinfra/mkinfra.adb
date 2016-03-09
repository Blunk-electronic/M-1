------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKINFRA                             --
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

with Ada.Text_IO;				use Ada.Text_IO;
with Ada.Integer_Text_IO;		use Ada.Integer_Text_IO;
with Ada.Characters.Handling; 	use Ada.Characters.Handling;

with Ada.Strings.Bounded; 		use Ada.Strings.Bounded;
with Ada.Exceptions; 			use Ada.Exceptions;
 
with Ada.Command_Line;			use Ada.Command_Line;
with Ada.Directories;			use Ada.Directories;

with m1;
with m1_internal; use m1_internal;


procedure mkinfra is

	version			: String (1..3) := "039";
	prog_position	: natural := 0;

	type type_algorithm is ( standard , intrusive);
	algorithm : type_algorithm;
	--type type_option is ( none, intrusive ); -- CS

	procedure write_info_section is
		--previous_output	: file_fype renames current_output;
		--Previous_Input	: File_Type renames Current_Input;
	begin
		-- create sequence file
		create( sequence_file, 
			name => (compose (universal_string_type.to_string(test_name), universal_string_type.to_string(test_name), "seq")));

			set_output(sequence_file); -- set data sink

			put_line ("Section info");
			put_line (" created by infra structure test generator version "& version);
			put_line (" date          : " & date_now); 
			--put_line (" UTC_Offset    : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; 
			put_line (" data base     : " & universal_string_type.to_string(data_base));
			put_line (" bic count     :" & positive'image(summary.bic_ct));
			put_line (" algorithm     : " & type_algorithm'image(standard));
			--put_line (" options       : " & type_option'image()); -- CS 
			put_line ("EndSection"); new_line;

			--Close(OutputFile); --Close(InputFile);
			--Set_Output(Previous_Output); --Set_Input(Previous_Input);
		end;

	procedure write_sir is
	begin
		-- write sir instruction -- example: "sir id 6"
		put_line(row_separator_0 & sequence_instruction_set.sir & sxr_id_identifier.id & positive'image(sxr_ct));
		sxr_ct := sxr_ct + 1;
	end write_sir;

	procedure write_sdr is
	begin
		-- write sdr instruction -- example: "sdr id 6"
		put_line(row_separator_0 & sequence_instruction_set.sdr & sxr_id_identifier.id & positive'image(sxr_ct));
		sxr_ct := sxr_ct + 1;
	end write_sdr;

	procedure write_sequences is
		b : type_bscan_ic_ptr;

		procedure one_of_all( 
			position	: positive; 
			instruction	: type_bic_instruction_for_infra_structure;
			write_sxr	: boolean := true
			) is
			b : type_bscan_ic_ptr;
		begin
				b := ptr_bic; -- reset bic pointer b
				while b /= null loop
					if b.id = position then -- if bic id matches p:

						-- if desired instruction does not exist, skip writing test vector and exit
						case instruction is
							when bypass		=> if not instruction_present(b.opc_bypass) 
								then 
									put_line(standard_output,"ERROR: IC '" & universal_string_type.to_string(b.name) 
										& "' does not support mandatory BYPASS mode !");
									raise constraint_error;
								end if;
							when idcode		=> if not instruction_present(b.opc_idcode) then exit; end if;
							when usercode	=> if not instruction_present(b.opc_usercode) then exit; end if;
							when preload	=> if not instruction_present(b.opc_preload) then exit; end if;
							when sample		=> if not instruction_present(b.opc_sample) then
								put_line(standard_output,"WARNING: IC '" & universal_string_type.to_string(b.name) 
									& "' does not support SAMPLE mode !");
								exit; end if;
							when extest		=> if not instruction_present(b.opc_extest) then exit; end if;
						end case;
						-- instruction exists

						-- write instruction drive (default part)
						-- example: "set IC301 drv ir 7 downto 0 := "
						new_line;
						put(row_separator_0 
							& sequence_instruction_set.set & row_separator_0
							& universal_string_type.to_string(b.name) & row_separator_0
							& sxr_io_identifier.drive & row_separator_0
							& sir_target_register.ir
							& type_register_length'image(b.len_ir - 1) & row_separator_0
							& sxr_vector_direction.downto & row_separator_0 & "0" & row_separator_0
							& sxr_assignment_operator.assign & row_separator_0
							);
						-- write instruction depended part
						case instruction is
							when idcode => m1_internal.put_binary_class_1(b.opc_idcode); -- example: "11111110 idcode"
							when usercode => m1_internal.put_binary_class_1(b.opc_usercode);
							when sample => m1_internal.put_binary_class_1(b.opc_sample);
							when preload => m1_internal.put_binary_class_1(b.opc_preload);
							when extest => 
								put_line(standard_output,"WARNING: IC '" & universal_string_type.to_string(b.name) 
									& "' WILL BE OPERATED IN EXTEST MODE !");
								m1_internal.put_binary_class_1(b.opc_extest);
							when others => 
								put_line(standard_output,"ERROR: Instruction '" & bic_instruction'image(instruction)
									& "' not allowed for infra structure test !");
								raise constraint_error;
						end case;
						put_line(row_separator_0 & to_lower(bic_instruction'image(instruction)));

						if write_sxr then
							write_sir;
						end if;

						-- WRITE DATA DRIVE (default part)
						-- example: "set IC300 drv"
						put(row_separator_0 
							& sequence_instruction_set.set & row_separator_0
							& universal_string_type.to_string(b.name) & row_separator_0
							& sxr_io_identifier.drive & row_separator_0
							);
						-- write instruction depended part
						case instruction is
							when idcode =>
								-- example: "idcode 31 downto 0 := 0"
								put_line(sdr_target_register.idcode
									--& " 31 " & sxr_vector_direction.downto 
									& type_register_length'image(bic_idcode_register_length - 1)
									& row_separator_0
									& sxr_vector_direction.downto 
									& " 0 "
									& sxr_assignment_operator.assign
									& " 0" -- we drive 32bits of 0 into the register. but it is a read-only register (as specified in std)
									);

							when usercode =>
								-- example: "usercode 31 downto 0 := 0"
								put_line(sdr_target_register.usercode
									& type_register_length'image(bic_usercode_register_length -1)
									& row_separator_0
									& sxr_vector_direction.downto 
									& " 0 "
									& sxr_assignment_operator.assign
									& " 0" -- we drive 32bits of 0 into the register. but it is a read-only register (as specified in std)
									);

							when others => -- sample, preload, extest
								-- example: "boundary 5 downto 0 := XXX11"
								put(sdr_target_register.boundary
									& natural'image(b.len_bsr - 1) & row_separator_0 & sxr_vector_direction.downto 
									& " 0 "
									& sxr_assignment_operator.assign & row_separator_0
									);
								m1_internal.put_binary_class_1(b.safebits);
								new_line;

						end case;
						
						-- WRITE DATA EXPECT (default part)
						-- example: "set IC300 exp"
						put(row_separator_0 
							& sequence_instruction_set.set & row_separator_0
							& universal_string_type.to_string(b.name) & row_separator_0
							& sxr_io_identifier.expect & row_separator_0
							);
						-- write instruction depended part
						case instruction is
							when idcode =>
								-- example: "idcode 31 downto 0 = xxxx1001010100000010000010010011"
								put(sdr_target_register.idcode
									& type_register_length'image(bic_idcode_register_length -1)
									& row_separator_0 
									& sxr_vector_direction.downto 
									& " 0 "
									& sxr_assignment_operator.assign & row_separator_0
									);
								m1_internal.put_binary_class_1(b.idcode); -- expect the idcode acc. bsdl. regardless what has been written here (see above)

							when usercode =>
								-- example: "usercode 31 downto 0 = xxxx1001010100000010000010010011"
								put(sdr_target_register.usercode
									& type_register_length'image(bic_usercode_register_length -1)
									& row_separator_0
									& sxr_vector_direction.downto 
									& " 0 "
									& sxr_assignment_operator.assign & row_separator_0
									);
								m1_internal.put_binary_class_1(b.usercode); -- expect the idcode acc. bsdl. regardless what has been written here (see above)
								-- NOTE: if usercode not programmed yet, it is all x

							when others => -- sample, preload, extest
								-- example: "boundary 5 downto 0 := X"
								put(sdr_target_register.boundary
									& natural'image(b.len_bsr - 1) & row_separator_0 & sxr_vector_direction.downto 
									& " 0 "
									& sxr_assignment_operator.assign
									& " X "
									);

						end case;
						new_line;

						if write_sxr then
							write_sdr;
						end if;

						exit; -- bic addressed by p processed. no further search of bic required
					end if; -- if bic id matches p

					b := b.next;
				end loop;
		end one_of_all;

	begin -- write_sequences
		new_line(2);
		put_line(" -- check bypass registers");

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

		for p in 1..summary.bic_ct loop -- process as much as bics are in udb

			b := ptr_bic; -- reset bic pointer b
			while b /= null loop
				if b.id = p then -- if bic id matches p:

					-- write instruction drive
					put(row_separator_0 
						& sequence_instruction_set.set & row_separator_0
						& universal_string_type.to_string(b.name) & row_separator_0
						& sxr_io_identifier.drive & row_separator_0
						& sir_target_register.ir
						& type_register_length'image(b.len_ir - 1) & row_separator_0
						& sxr_vector_direction.downto & row_separator_0 & "0" & row_separator_0
						& sxr_assignment_operator.assign & row_separator_0
						);
					m1_internal.put_binary_class_1(b.opc_bypass);
					put_line(" bypass");

					-- write instruction capture
					put(row_separator_0 
						& sequence_instruction_set.set & row_separator_0
						& universal_string_type.to_string(b.name) & row_separator_0
						& sxr_io_identifier.expect & row_separator_0
						& sir_target_register.ir
						& type_register_length'image(b.len_ir - 1) & row_separator_0
						& sxr_vector_direction.downto & row_separator_0 & "0" & row_separator_0
						& sxr_assignment_operator.assign & row_separator_0
						);
					m1_internal.put_binary_class_1(b.capture_ir);
					new_line;

				end if; -- if bic id matches p

				b := b.next;
			end loop;
		end loop;

		write_sir;


		-- write sdr bypass:

-- 		set IC301 drv bypass 1=1
-- 		set IC301 exp bypass 1=0
-- 		set IC300 drv bypass 1=1
-- 		set IC300 exp bypass 1=0
-- 		set IC303 drv bypass 1=1
-- 		set IC303 exp bypass 1=0
-- 		sdr id 2

		for p in 1..summary.bic_ct loop -- process as much as bics are in udb

			b := ptr_bic; -- reset bic pointer b
			while b /= null loop
				if b.id = p then -- if bic id matches p:

					-- write data drive
					put(row_separator_0 
						& sequence_instruction_set.set & row_separator_0
						& universal_string_type.to_string(b.name) & row_separator_0
						& sxr_io_identifier.drive & row_separator_0
						& sdr_target_register.bypass
						& " 0" -- bit position (since this addresses the bypass register)
						& sxr_assignment_operator.assign
						& "1" -- we drive a 1 into the register. if it is a read-only register (as specified in std) a 0 is expected
						);
					new_line;

					-- write data expect
					put(row_separator_0 
						& sequence_instruction_set.set & row_separator_0
						& universal_string_type.to_string(b.name) & row_separator_0
						& sxr_io_identifier.expect & row_separator_0
						& sdr_target_register.bypass
						& " 0" -- bit position (since this addresses the bypass register)
						& sxr_assignment_operator.assign
						& type_bit_char_class_0'image(b.capture_bypass)(2) -- expect a 0 acc. std. regardless what has been written here (see above)
						);
					new_line;

				end if; -- if bic id matches p

				b := b.next;
			end loop;
		end loop;

		write_sdr;


		-- IDCODE CHECK ---------------------
		new_line(2);
		put_line(" -- check idcode registers");
		for p in 1..summary.bic_ct loop -- process as much as bics are in udb
			one_of_all(p,idcode);
		end loop;


		-- USERCODE CHECK ---------------------
		new_line(2);
		put_line(" -- check usercode registers");
		for p in 1..summary.bic_ct loop -- process as much as bics are in udb
			one_of_all(p,usercode);
		end loop;

		-- BOUNDARY REGISTER CHECK ---------------------
		new_line(2);
		put_line(" -- check boundary registers");
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

		new_line;
		put_line(row_separator_0 & sequence_instruction_set.trst);
		put_line(section_mark.endsection);

	end write_sequences;


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	new_line;
	put_line("INFRA STRUCTURE TEST GENERATOR VERSION "& version);
	put_line("===========================================");

	prog_position	:= 10;
 	data_base:= universal_string_type.to_bounded_string(argument(1));
 	put_line("data base      : " & universal_string_type.to_string(data_base));

	prog_position	:= 20;
	test_name := universal_string_type.to_bounded_string(argument(2));
	put_line("test name      : " & universal_string_type.to_string(test_name));

	prog_position	:= 30;
	if argument_count = 3 then
		debug_level := natural'value(argument(3));
		put_line("debug level    :" & natural'image(debug_level));
	end if;

	-- CS: get algorithm as argument
	-- for the time being it is fixed
	algorithm := standard;

	prog_position	:= 40;
	read_data_base;

	create_temp_directory;
	create_test_directory(
		test_name 			=> universal_string_type.to_string(test_name),
		warnings_enabled 	=> false
		);

	write_info_section;
	write_test_section_options;

	write_test_init;
	write_sequences;

	set_output(standard_output);
	close(sequence_file);


	exception
-- 		when constraint_error => 

		when event: others =>
			case prog_position is
				when 10 =>
					put_line("ERROR: Data base file missing or insufficient access rights !");
					put_line("       Provide data base name as argument. Example: udbinfo my_uut.udb");
				when 20 =>
					put_line("ERROR: Test name missing !");
					put_line("       Provide test name as argument ! Example: mkinfra my_uut.udb my_infrastructure_test");
				when 30 =>
					put_line("ERROR: Invalid argument for debug level. Debug level must be provided as natural number !");


				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & natural'image(prog_position));
			end case;
			--clean_up;
			--raise;

end mkinfra;
