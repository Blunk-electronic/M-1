------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE COMPSEQ                             --
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
--	 2016-06-17: - in procdedure write_vector_file_header number of scanpaths written in list file fixed
--	  			 - procedure write_base_address fixed calculation of scanpath start address
--				 - procedure build_active_scanpath_info. the global variable active_scanpath_info is written in vec and list file
--				 - procedure write_base_address differentiates between first and subsequent scanpath base addresses (the base addres of subsequent
--				   scanpaths is now calculated correctly.

--   2016-07-29: - vector file dummy bytes (at pos. 10 and 11) removed. they now contain the step count (incl. low level commands)

--  todo:
--	- write udb and project in compile listing

with Ada.Text_IO;			use Ada.Text_IO;
with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
with Ada.Float_Text_IO;		use Ada.Float_Text_IO;
--with Ada.Characters; 		use Ada.Characters;
with Ada.Characters.Handling; 		use Ada.Characters.Handling;
--with ada.characters.conversions;	use ada.characters.conversions;

with m1; --use m1;
with m1_internal; use m1_internal;
with m1_firmware; use m1_firmware;
with m1_numbers; use m1_numbers;
with m1_files_and_directories; use m1_files_and_directories;

--with System.OS_Lib;   use System.OS_Lib;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.maps;	 	use Ada.Strings.maps;
with Ada.Strings.Fixed; 	use Ada.Strings.Fixed;
with Ada.Strings;		 	use Ada.Strings;
with interfaces;			use interfaces;
--with Ada.Numerics;			use Ada.Numerics;
--with Ada.Numerics.Elementary_Functions;	use Ada.Numerics.Elementary_Functions;

--with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
--with Ada.Task_Identification;  use Ada.Task_Identification;
with Ada.Exceptions; use Ada.Exceptions;
 
--with GNAT.OS_Lib;   	use GNAT.OS_Lib;
with Ada.Command_Line;	use Ada.Command_Line;
with Ada.Directories;	use Ada.Directories;
 
-- with Ada.Calendar;				use Ada.Calendar;
-- with Ada.Calendar.Formatting;	use Ada.Calendar.Formatting;
-- with Ada.Calendar.Time_Zones;	use Ada.Calendar.Time_Zones;

procedure compseq is

	compseq_version			: string (1..7) := "005.000";
	vector_format_version	: string (1..7) := "000.000";

	prog_position 			: natural := 0;

	size_of_vector_file		: natural := 0; -- incremented on every byte written in vector_file
	size_of_vector_header	: natural := 0; -- incremented on every byte written in vector_file_header

	destination_address		: natural;

	line_counter			: natural := 0; -- line counter in sequence file (global counter !)

	test_info				: type_test_info;
	scanpath_options		: type_scanpath_options;

	sxr_retries				: type_sxr_retries;
	sxr_retry_delay			: type_delay_value;


	active_scanpath_info	: unsigned_8 := 16#00#; -- for every active scanpath a bit is set here. CS: implies maximum of 8 scanpaths
	procedure build_active_scanpath_info is --(scanpath_id : type_scanpath_id) is
		-- builds a byte where a bit is set for a given scanpath. example: if scanpath_id is 2 -> active_scanpath_info is 00000010b
		-- for every further active scanpath the corresponding bit is set. so if next scanpath_id is 8 -> active_scanpath_info becomes 10000010b
		scratch : natural := 0;
	begin
		for sp in 1..scanport_count_max loop
			if is_scanport_active(sp) then
				--put_line(" -------------------> building active scanpath info ...");
				scratch := 2**(sp - 1);
				active_scanpath_info := active_scanpath_info + unsigned_8(scratch); -- 16#00#;
				--put_line(natural'image(scratch));
				--put_line(unsigned_8'image(active_scanpath_info));
			end if;
		end loop;
	end build_active_scanpath_info;

	
	sequence_count			: positive := 1;
	scanpath_being_compiled	: positive;	-- points to the scanpath being compiled
	sequence_being_compiled	: positive;	-- points to the sequence being compiled

-- 	vector_count_max		: constant positive := (2**16)-1;
-- 	subtype type_vector_id is positive range 1..vector_count_max;
-- NOTE: moved to m1_internal.ads

 	vector_id				: type_vector_id; -- as in "sdr id 456" or "sir id 5"


	ct_tmp					: positive := 1; -- used to identify position of bytes to be replaced by step count

	-- test_step_id is incremented on every test step (incl. low level commands) per scanpath
	test_step_id			: natural := 0; -- CS: upper limit ?

	ubyte_scratch			: unsigned_8; -- used for appending vector_file to vector_file_head

-- 	vector_length_max		: constant positive := (2**16)-1; -- CS: machine dependend and limited here
-- 										-- to a reasonable value
-- 	subtype type_vector_length is positive range 1..vector_length_max;
-- NOTE: moved to m1_internal.ads

	-- GLOBAL ARRAY THAT DESCRIBES ALL PHYSICAL AVAILABLE SCANPATHS
	-- non-active scanpaths have an irl_total of zero
	-- irl_total is the sum of all instuction registers in that scanpath + trailer length
	-- irl_total is computed when creating register files
	type type_single_scanport is
		record
	-- 			name		: unbounded_string;
	-- 			mem_ct		: natural := 0;
	-- 			members		: type_all_members_of_a_single_chain;
	 		irl_total	: natural := 0;
	-- 			drl_total	: natural := 0;
	-- 			ir_drv_all	: unbounded_string; -- MSB left !!!
	-- 			ir_exp_all	: unbounded_string; -- MSB left !!!
	-- 			dr_drv_all	: unbounded_string; -- MSB left !!!
	-- 			dr_exp_all	: unbounded_string; -- MSB left !!!
			register_file	: ada.text_io.file_type;
		end record;
	type type_all_scanports is array (natural range 1..scanport_count_max) of type_single_scanport;
	scanport	: type_all_scanports;




	type type_step_class is ( class_a, class_b);
	type type_step_class_b_binary_array is array (natural range <>) of unsigned_8;
	type type_step_class_b (byte_count : positive) is
		record
			binary	: type_step_class_b_binary_array(1..byte_count);
			source	: universal_string_type.bounded_string;
		end record;
			
	type type_test_step_pre;
	type ptr_type_test_step_pre is access all type_test_step_pre;
	type type_test_step_pre ( length_total : type_vector_length; step_class : type_step_class) is 
		record
			next		: ptr_type_test_step_pre;
			step_id		: positive; -- CS: use dedicated type
			--scanpath_id	: type_scanpath_id;
			scanpath_id	: type_scanport_id;
			sequence_id	: positive; -- CS: use dedicated type
			case step_class is
				when class_a => -- class a is an sxr
					scan		: type_scan;  -- SIR or SDR
					vector_id	: type_vector_id;
					-- CS: place information about targeted registers
					img_drive	: type_string_of_bit_characters_class_0(1..length_total);	-- LSB left (pos 1)
					img_expect	: type_string_of_bit_characters_class_0(1..length_total);	-- LSB left (pos 1)
					img_mask	: type_string_of_bit_characters_class_0(1..length_total);	-- LSB left (pos 1)
					retry_count	: unsigned_8;
					retry_delay	: unsigned_8;
					source		: universal_string_type.bounded_string; -- the command in plain text like "sir 3"
				when class_b => -- class b is a low level command
					command		: type_step_class_b(length_total);
			end case;
		end record;
	ptr_test_step_pre	: ptr_type_test_step_pre;

	procedure add_class_b_cmd_to_step_list_pre( -- low level command
		list				: in out ptr_type_test_step_pre;
		length_total_given	: natural; -- this is the number of bytes required for that command
		command_given		: type_step_class_b) is
	begin
		test_step_id := test_step_id + 1; -- just a number that helps ordering test steps later when reading the list
		list := new type_test_step_pre'(
			next 			=> list,
			step_id			=> test_step_id,
			scanpath_id		=> scanpath_being_compiled,
			sequence_id		=> sequence_being_compiled,
			step_class		=> class_b,
			length_total	=> length_total_given, -- here the discriminant length_total is misused to hold the number
												-- of bytes required for that command
			command			=> command_given
			);
	end add_class_b_cmd_to_step_list_pre;

	procedure add_class_a_cmd_to_step_list_pre( -- sxr command
		list				: in out ptr_type_test_step_pre;
		--step_class_given	: type_step_class;
		scan_given			: type_scan; -- SIR or SDR
		vector_id_given		: type_vector_id;
		length_total_given	: type_vector_length; -- this is the number of bits required for that vector
		img_drive_given		: type_string_of_bit_characters_class_0;	-- LSB left (pos 1)
		img_expect_given	: type_string_of_bit_characters_class_0;	-- LSB left (pos 1)
		img_mask_given		: type_string_of_bit_characters_class_0;	-- LSB left (pos 1)
		retry_count_given	: unsigned_8;
		retry_delay_given	: unsigned_8;
		source_given		: universal_string_type.bounded_string
		) is
	begin
		test_step_id := test_step_id + 1; -- just a number that helps ordering test steps later when reading the list
		list := new type_test_step_pre'(
			next 			=> list,
			step_id			=> test_step_id,
			scanpath_id		=> scanpath_being_compiled,
			sequence_id		=> sequence_being_compiled,
			step_class		=> class_a,
			scan			=> scan_given,
			vector_id		=> vector_id_given,
			length_total	=> length_total_given,
			img_drive		=> img_drive_given,		-- LSB left (pos 1)
			img_expect		=> img_expect_given,	-- LSB left (pos 1)
			img_mask		=> img_mask_given,		-- LSB left (pos 1)
			retry_count		=> retry_count_given,
			retry_delay		=> retry_delay_given,
			source			=> source_given
			);
	end add_class_a_cmd_to_step_list_pre;



------------------------------------------
	
-- 	type unsigned_3 is mod 8;
-- 	bit_pt	: unsigned_3 := 0;

	listing_offset 	: positive;
	listing_address	: positive;
	procedure write_listing_header is
	begin
		put_line(compile_listing,"M-1 Compiler Compseq Version " & compseq_version & " listing/report");
		put_line(compile_listing,"date: " & m1.date_now);
		put_line(compile_listing,"source file: " 
			& universal_string_type.to_string(test_name) 
			& "/" & universal_string_type.to_string(test_name) & ".seq");
		new_line(compile_listing);
		--put_line(compile_listing,"LOC(hex)       LINE    SOURCE CODE" );
		put_line(compile_listing,"LOC(hex)       OBJ_CODE       SOURCE_CODE/MEANING" );
		put_line(compile_listing,column_separator_0);
	end write_listing_header;

	type type_list_item is ( LOCATION, OBJECT_CODE, LINE_NUMBER, SOURCE_CODE, SEPARATOR);
	--subtype type_object_code is string (1..3); -- like EFh or 52h
	procedure write_listing (
		item 		: type_list_item;
		loc		 	: natural := 0;
		obj_code 	: unsigned_8 := 16#00#; -- type_object_code := "00h";
		line 		: natural := 0;
		src_code 	: string := "") is
	begin
		case item is
			when LOCATION =>
				put(compile_listing,natural_to_string(loc,16,8));
				put(compile_listing,6 * row_separator_0);
			when LINE_NUMBER =>
				put(compile_listing,natural'image(line));
				put(compile_listing,row_separator_0);
			when OBJECT_CODE =>
				put(compile_listing, natural_to_string( natural(obj_code), 16, 2)(1..2) );
				--put(compile_listing,obj_code(obj_code'first..obj_code'last-1)); -- strip format indicator 
				put(compile_listing,row_separator_0);
			when SOURCE_CODE => -- CS: improve formating !
				put(compile_listing,9 * row_separator_0);
				--Set_Col(20);
				--put(compile_listing,src_code);
				--Set_Col(1);
				put_line(compile_listing,src_code);
			when SEPARATOR =>
				put(compile_listing,row_separator_1);
			when others => null;
		end case;
	end write_listing;


	-- CS: procedure write_byte_in_vector_header ?

	procedure write_byte_in_vector_file (byte : unsigned_8) is
	-- writes a given byte into vector_file
	-- counts bytes and updates size_of_vector_file
	begin
		seq_io_unsigned_byte.write(vector_file, byte);
		size_of_vector_file := size_of_vector_file + 1;
	end write_byte_in_vector_file;

	procedure write_word_in_vector_file (word	: unsigned_16) is
		ubyte_scratch  : unsigned_8;
		u2byte_scratch : unsigned_16;
	begin
		-- lowbyte first
		u2byte_scratch := word;
 		u2byte_scratch := (shift_left(u2byte_scratch,8)); -- clear bits 15..8 by shift left 8 bit
 		u2byte_scratch := (shift_right(u2byte_scratch,8)); -- shift back by 8 bits
		ubyte_scratch := unsigned_8(u2byte_scratch); -- take lowbyte
		write_byte_in_vector_file(ubyte_scratch); -- write lowbyte in file

		-- highbyte
		u2byte_scratch := word;
 		u2byte_scratch := (shift_right(u2byte_scratch,8)); -- shift right by 8 bits
		ubyte_scratch := unsigned_8(u2byte_scratch); -- take highbyte
		write_byte_in_vector_file(ubyte_scratch); -- write highbyte in file
	end write_word_in_vector_file;

	procedure write_double_word_in_vector_file (dword	: unsigned_32) is
		ubyte_scratch  : unsigned_8;
		u4byte_scratch : unsigned_32;
	begin
		-- lowbyte first
		u4byte_scratch := dword;
 		u4byte_scratch := (shift_left(u4byte_scratch,3*8)); -- clear bits 31..8 by shift left 24 bit
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch); -- take lowbyte
		write_byte_in_vector_file(ubyte_scratch); -- write lowbyte in file

		u4byte_scratch := dword;
 		u4byte_scratch := (shift_left(u4byte_scratch,2*8)); -- clear bits 31..16 by shift left 16 bit
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch);
		write_byte_in_vector_file(ubyte_scratch);

		u4byte_scratch := dword;
 		u4byte_scratch := (shift_left(u4byte_scratch,1*8)); -- clear bits 31..24 by shift left 8 bit
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch);
		write_byte_in_vector_file(ubyte_scratch);

		-- highbyte
		u4byte_scratch := dword;
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift right by 8 bits
		ubyte_scratch := unsigned_8(u4byte_scratch); -- take lowbyte
		write_byte_in_vector_file(ubyte_scratch); -- write highbyte in file
	end write_double_word_in_vector_file;



	procedure write_llc
	-- writes a low level command
		(
		head	:	unsigned_8; -- low level command header that indicates the nature of the command
		arg1	:	unsigned_8; -- argument 1
		arg2	:	unsigned_8 := 16#00#; -- argument 2 (optional)
		source	:	string
		) is
		length		: positive := 5; -- all low level commands are 5 byte long
		llc_scratch : type_step_class_b(length);
	begin
		llc_scratch.binary(1) := get_byte_from_word(id_configuration,0); -- id lowbyte
		llc_scratch.binary(2) := get_byte_from_word(id_configuration,1); -- id highbyte
		llc_scratch.binary(3) := head;
		llc_scratch.binary(4) := arg1;
		llc_scratch.binary(5) := arg2;
		llc_scratch.source	:= universal_string_type.to_bounded_string(source);

		add_class_b_cmd_to_step_list_pre(
			list 				=> ptr_test_step_pre,
			length_total_given	=> length,
			command_given		=> llc_scratch);


-- 		-- write ID, which is always id_configuration
-- 		write_listing(item => location, loc => listing_address);
-- 		write_word_in_vector_file(id_configuration); -- id_configuration is 16bit wide
-- 		write_listing(item => object_code, obj_code => natural_to_string(natural(unsigned_8(id_configuration)),16,2)); -- write lowbyte
-- 		write_listing(item => object_code, obj_code => natural_to_string(natural(unsigned_8(id_configuration/256)),16,2)); -- write highbyte (shift right 8 bits)

		--write low level command type
		--write_listing(item => location, loc => size_of_vector_file + listing_offset);
-- 		write_byte_in_vector_file(llct);
-- 		write_listing(item => object_code, obj_code => natural_to_string(natural(unsigned_8(llct)),16,2)); -- write llct

		-- write chain pt
		-- write chain number in vec file. CS: chain number is ignored by executor
 		--write_byte_in_vector_file(16#00#);
		--write_listing(item => location, loc => size_of_vector_file + listing_offset);
-- 		write_byte_in_vector_file(unsigned_8(scanpath_being_compiled));  
-- 		write_listing(item => object_code, obj_code => natural_to_string(natural(unsigned_8(scanpath_being_compiled)),16,2)); -- write scanpath_being_compiled

		-- write low level command itself
--  		write_byte_in_vector_file(llcc); 
-- 		write_listing(item => object_code, obj_code => natural_to_string(natural(unsigned_8(llcc)),16,2)); -- write llcc

--		listing_address := listing_address + 5;
	end write_llc;



 	procedure compile_command (cmd : extended_string.bounded_string) is
		field_pt 				: positive := 1;
		field_ct 				: positive := get_field_count(extended_string.to_string(cmd));
		bic_name				: universal_string_type.bounded_string;
		bic_coordinates			: type_ptr_bscan_ic;
		set_direction		 	: type_set_direction;
		target_register			: type_set_target_register;
		set_assignment_method	: type_set_assigment_method;

		-- for cell id check. the highest id allowed is defined by the length of the targeted register
		cell_id_max				: natural; -- holds the id of the MSB cell in targeted register

		-- for upper and lower end check of register wise assigments
		-- example: set IC301 drv ir 4 downto 2 = 110
		-- cell_id_upper_end is 4, cell_id_lower_end is 2
		cell_id_upper_end		: natural := 0; -- holds the id of the upper bit in register wise assigments
		cell_id_lower_end		: natural := 0; -- holds the id of the lower bit in register wise assigments

		set_vector_orientation	: type_set_vector_orientation;

		cell_assignment			: type_set_cell_assignment;
		cell_position_in_image	: positive;
		cell_expect_mask 		: type_bit_char_class_0 := '1';

		sir_length_total 		: natural := 0;

		sxr_retries_unsigned_8		: unsigned_8 := 0; -- set by check_option_retry, otherwise this is default and means: no retries
		sxr_retry_delay_unsigned_8	: unsigned_8 := 0; -- set by check_option_retry, otherwise this is default


		procedure put_example(instruction : string) is
		begin
			put_line("       Example: " & sequence_instruction_set.imax & row_separator_0 
				& positive'image(type_power_channel_id'first) & row_separator_0
				& float'image(type_current_max'first) & row_separator_0
				& timeout_identifier & row_separator_0 & float'image(type_overload_timeout'first)
				);
			put_line("       Currently" & positive'image(power_channel_ct) & " power channels for power supervising are supported !");
		end put_example;

		function update_pattern(
		-- if assigment is register_wise !
		-- overwrites bit positions specified in range cell_pos_low..cell_pos_high with text_in
			pattern_old 	: type_string_of_bit_characters_class_0;
			length_total 	: positive;
			cell_pos_high	: positive;
			cell_pos_low	: positive;
			pattern_in		: string; -- MSB left (pos. 1)
			orientation		: type_set_vector_orientation;
			direction		: type_set_direction := drv;
			mask			: boolean := false
			) return type_string_of_bit_characters_class_0 is -- MSB left (pos. 1)

			pattern_in_length	: positive := cell_pos_high - cell_pos_low + 1;

			subtype type_pattern_1 is type_string_of_bit_characters_class_1 (1..pattern_in_length);
			pattern_in_class_1	: type_pattern_1;

			subtype type_pattern_0 is type_string_of_bit_characters_class_0 (1..pattern_in_length);
			pattern_new			: type_pattern_0;

			--whole_pattern_is_dont_care : boolean := false; -- used for exceptional case when pattern contains only one x
			--whole_pattern_is	: type_bit_char_class_1; -- x,0,1
			-- example: set IC202 exp boundary 16 downto 0 = x

		begin -- update_pattern

			-- if this is a pattern of length 1 and value x,0 or 1 -> assume all bits of this pattern have the same value
			-- example: set IC202 exp boundary 16 downto 0 = x
			prog_position	:= 500;
			if pattern_in'last = 1 then -- means if pattern_in is just one character
				case pattern_in(pattern_in'first) is
					when 'x' | 'X' =>
						-- fill pattern_in_class_1 with as much x as specified by cell_pos_high and cell_pos_low
						pattern_in_class_1	:= to_binary_class_1(  to_binary( pattern_in_length * 'x', pattern_in_length , class_1)  );
					when '0' =>
						-- fill pattern_in_class_1 with as much x as specified by cell_pos_high and cell_pos_low
						pattern_in_class_1	:= to_binary_class_1(  to_binary( pattern_in_length * '0', pattern_in_length , class_1)  );
					when '1' =>
						-- fill pattern_in_class_1 with as much x as specified by cell_pos_high and cell_pos_low
						pattern_in_class_1	:= to_binary_class_1(  to_binary( pattern_in_length * '1', pattern_in_length , class_1)  );
					when others =>
						put_line(standard_output,"ERROR: Invalid character for cell calue found !");
						raise constraint_error;
				end case;
			else
				--convert string given in pattern_in to string of bit characters class 1
				-- load result in text_in_class_1
				pattern_in_class_1	:= to_binary_class_1(  to_binary(pattern_in, pattern_in_length , class_1)  );
			end if;


			-- if a mask is to be created, the flag "mask" matters
			prog_position	:= 520;
			if mask then
				-- a mask can only be created when pattern_in is an expect value
				-- from the expect value (pattern_in_class_1), the mask is generated:
				-- for every dont care bit, a zero is created (means no expect value verification)
				-- for 0/1, a one is created (means there is an expect value verification)
				if direction = exp then
					for m in 1..pattern_in_length loop
						case pattern_in_class_1(m) is
							when 'x' | 'X' => pattern_new(m) := '0'; -- no test
							when '1' | '0' => pattern_new(m) := '1'; -- test
						end case;
					end loop;
					-- pattern_new now contains the mask
				else
					raise constraint_error;
				end if;
			else
				-- replace x (don't cares) in pattern_1 by zeroes
				-- load result in pattern_new
				pattern_new		:= replace_dont_care(pattern_in_class_1);
				-- pattern_new now contains the expect value
			end if;
	
			-- apply discrete ranges. CS
			prog_position	:= 530;
			if pattern_in_length = length_total then
				null;
			else
				put_line("ERROR: Assigning discrete ranges not supported yet !"); -- CS
				raise constraint_error;
-- 				for b in 1..length_total loop
-- 					--if b >= cell_pos_low
-- 					null;
-- 				end loop;
			end if;

			return pattern_new; -- MSB left (pos 1)
		end update_pattern;


		procedure check_option_retry is
		begin
			-- check option "retry" -- example: sdr id 4 option retry 10 delay 1
			-- CS: check other options here
			if field_ct > 3 then
				if get_field_from_line(cmd,4) = sxr_option.option then
					if get_field_from_line(cmd,5) = sxr_option.retry then
						if positive'value(get_field_from_line(cmd,6)) in type_sxr_retries then
							sxr_retries := positive'value(get_field_from_line(cmd,6));
							if get_field_from_line(cmd,7) = sxr_option.dely then
								if float'value(get_field_from_line(cmd,8)) in type_delay_value then
									sxr_retry_delay := float'value(get_field_from_line(cmd,8));

										sxr_retry_delay_unsigned_8	:= unsigned_8(natural(sxr_retry_delay * 10.0)); -- CS: why multiply by 10 ?
										sxr_retries_unsigned_8		:= unsigned_8(sxr_retries);

									if field_ct > 8 then
										put_warning_on_too_many_parameters(line_counter);
									end if;
								else
									put_line("ERROR: Maximum delay is" & float'image(delay_max) & " !");
									raise constraint_error;
								end if;
							else
								put_line("ERROR: Expected keyword '" & sxr_option.dely & "' !");
								raise constraint_error;
							end if;
						else
							put_line("ERROR: Retry count exceeded ! Max value is" & positive'image(sxr_retries_max) & " !");
							raise constraint_error;
						end if;
					else
						put_line("ERROR: Expected keyword '" & sxr_option.retry & "' !");
						-- CS: put other availabe options 
						raise constraint_error;
					end if;
				else
					put_line("ERROR: Expected keyword '" & sxr_option.option & "' after sxr id !");
					raise constraint_error;
				end if;
			end if;
	end check_option_retry;


	procedure concatenate_sir_images is
	-- concatenates sir images starting with device closest to BSC TDO ! This device has position 1.
	-- checks retry option
	-- adds images to list of test steps (pointed to by ptr_test_step_pre)
		length_total : positive := scanport(scanpath_being_compiled).irl_total;
		subtype type_sir_image is type_string_of_bit_characters_class_0 (1..length_total);
		sir_drive	: type_sir_image;
		sir_expect	: type_sir_image;
		sir_mask	: type_sir_image;
		b 			: type_ptr_bscan_ic;

		pos_start	: positive := 1;
		pos_end		: positive;

	begin -- concatenate_sir_images
		for p in reverse 1..summary.bic_ct loop -- p defines the position (start with the highest position, close to BSC TDI)
			b := ptr_bic;
			while b /= null loop -- loop in bic list
				if b.position = p then -- on position match
					if b.chain = scanpath_being_compiled then -- on scanpath match

						-- start pos initiated already
						-- calculate end position to place bic-image
						pos_end := (pos_start + b.len_ir) - 1;

						sir_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_ir_drive);
						sir_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_ir_expect);
						sir_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_ir_mask);

						put_line(scanport(scanpath_being_compiled).register_file, "step" 
							& positive'image(vector_id) & " device" & positive'image(p) & " ir");

						-- calculate start position to place next image
						pos_start := pos_end + 1;
					end if;
				end if;
				b := b.next;
			end loop;
		end loop;

		-- insert trailer at begin of drive image (so that the trailer gets sent into the target FIRST)
		sir_drive := shift_class_0(sir_drive,right,trailer_length);
		sir_drive(1..trailer_length) := mirror_class_0(scanpath_options.trailer_ir);

		-- insert trailer at end of expect/mask image (BSC receives trailer AFTER the target-capture values !)
		sir_expect(length_total-trailer_length+1..length_total) := mirror_class_0(scanpath_options.trailer_ir);
		-- mask for trailer has same position with all bits set (means all bits are checked) -- CS: disabling checking option ?
		-- CS: when manipulating the mask, it must be mirrored. for the time being no need since all bits are set
		sir_mask(length_total-trailer_length+1..length_total) := to_binary_class_0
																		(
																		to_binary( 
																			text_in => trailer_length * '1',
																			length	=> trailer_length,
																			class	=> class_0
																			)
																		);

		check_option_retry;

		add_class_a_cmd_to_step_list_pre(
			list				=> ptr_test_step_pre,
			--step_class_given	=> class_a,
			scan_given			=> SIR,
			vector_id_given		=> vector_id,
			length_total_given	=> length_total,
			img_drive_given		=> sir_drive, -- LSB left (pos 1)
			img_expect_given	=> sir_expect, -- LSB left (pos 1)
			img_mask_given		=> sir_mask, -- LSB left (pos 1)
			retry_count_given	=> sxr_retries_unsigned_8,
			retry_delay_given	=> sxr_retry_delay_unsigned_8,
			source_given		=> universal_string_type.to_bounded_string(extended_string.to_string(cmd))
			);

	end concatenate_sir_images;


	procedure concatenate_sdr_images is
	-- calculates total length of sdr image by the instructions loaded last
	-- concatenates sir images starting with device closest to BSC TDO ! This device has position 1.
	-- checks retry option
	-- adds images to list of test steps (pointed to by ptr_test_step_pre)

		length_total 	: natural := trailer_length; -- the trailer is always included
		b 				: type_ptr_bscan_ic;

		procedure build_sdr_image is
		-- with the total length known, the overall sdr image can be created
			subtype type_sdr_image is type_string_of_bit_characters_class_0 (1..length_total);
			sdr_drive	: type_sdr_image;
			sdr_expect	: type_sdr_image;
			sdr_mask	: type_sdr_image;
			b 			: type_ptr_bscan_ic;

			pos_start	: positive := 1;
			pos_end		: positive;

		begin -- build_sdr_image
			-- the last instruction loaded indicates the targeted data register
			for p in reverse 1..summary.bic_ct loop -- p defines the position (start with the highest position, close to BSC TDI)
				b := ptr_bic;
				while b /= null loop -- loop in bic list
					if b.position = p then -- on position match
						if b.chain = scanpath_being_compiled then -- on scanpath match

							-- b.pattern_last_xxx_xxxx has MSB on the left (pos 1)

							-- if last instruction was BYPASS
							if b.pattern_last_ir_drive = replace_dont_care(b.opc_bypass) then
								-- calculate end position to place bic-image
								pos_end := (pos_start + bic_bypass_register_length) - 1;

								sdr_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_bypass_drive);
								sdr_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_bypass_expect);
								sdr_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_bypass_mask);

								put_line(scanport(scanpath_being_compiled).register_file, "step" 
									& natural'image(vector_id) 
									& " device" & positive'image(p) & row_separator_0 & to_lower(type_bic_data_register'image(BYPASS)));

							-- if last instruction was EXTEST
							elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_extest) then
								-- calculate end position to place bic-image
								pos_end := (pos_start + b.len_bsr) - 1;

								sdr_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_boundary_drive);
								sdr_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_boundary_expect);
								sdr_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_boundary_mask);

								put_line(scanport(scanpath_being_compiled).register_file, "step" 
									& natural'image(vector_id) 
									& " device" & positive'image(p) & row_separator_0 & to_lower(type_bic_data_register'image(BOUNDARY)));

							-- if last instruction was SAMPLE
							elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_sample) then
								-- calculate end position to place bic-image
								pos_end := (pos_start + b.len_bsr) - 1;

								sdr_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_boundary_drive);
								sdr_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_boundary_expect);
								sdr_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_boundary_mask);

								put_line(scanport(scanpath_being_compiled).register_file, "step" 
									& natural'image(vector_id) 
									& " device" & positive'image(p) & row_separator_0 & to_lower(type_bic_data_register'image(BOUNDARY)));

							-- if last instruction was PRELOAD
							elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_preload) then
								-- calculate end position to place bic-image
								pos_end := (pos_start + b.len_bsr) - 1;

								sdr_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_boundary_drive);
								sdr_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_boundary_expect);
								sdr_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_boundary_mask);

								put_line(scanport(scanpath_being_compiled).register_file, "step" 
									& natural'image(vector_id) 
									& " device" & positive'image(p) & row_separator_0 & to_lower(type_bic_data_register'image(BOUNDARY)));

							-- if last instruction was HIGHZ
							elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_highz) then
								-- calculate end position to place bic-image
								pos_end := (pos_start + bic_bypass_register_length) - 1;

								sdr_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_bypass_drive);
								sdr_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_bypass_expect);
								sdr_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_bypass_mask);

								put_line(scanport(scanpath_being_compiled).register_file, "step" 
									& natural'image(vector_id) 
									& " device" & positive'image(p) & row_separator_0 & to_lower(type_bic_data_register'image(BYPASS)));

							-- if last instruction was CLAMP
							elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_clamp) then
								-- calculate end position to place bic-image
								pos_end := (pos_start + bic_bypass_register_length) - 1;

								sdr_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_bypass_drive);
								sdr_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_bypass_expect);
								sdr_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_bypass_mask);

								put_line(scanport(scanpath_being_compiled).register_file, "step" 
									& natural'image(vector_id) 
									& " device" & positive'image(p) & row_separator_0 & to_lower(type_bic_data_register'image(BYPASS)));

							-- if last instruction was IDCODE
							elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_idcode) then
								-- calculate end position to place bic-image
								pos_end := (pos_start + bic_idcode_register_length) - 1;

								sdr_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_idcode_drive);
								sdr_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_idcode_expect);
								sdr_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_idcode_mask);

								put_line(scanport(scanpath_being_compiled).register_file, "step" 
									& natural'image(vector_id) 
									& " device" & positive'image(p) & row_separator_0 & to_lower(type_bic_data_register'image(IDCODE)));

							-- if last instruction was USERCODE
							elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_usercode) then
								-- calculate end position to place bic-image
								pos_end := (pos_start + bic_usercode_register_length) - 1;

								sdr_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_usercode_drive);
								sdr_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_usercode_expect);
								sdr_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_usercode_mask);

								put_line(scanport(scanpath_being_compiled).register_file, "step" 
									& natural'image(vector_id) 
									& " device" & positive'image(p) & row_separator_0 & to_lower(type_bic_data_register'image(USERCODE)));

							-- if last instruction was INTEST
							elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_intest) then
								-- calculate end position to place bic-image
								pos_end := (pos_start + b.len_bsr) - 1;

								sdr_drive(pos_start..pos_end) 	:= mirror_class_0(b.pattern_last_boundary_drive);
								sdr_expect(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_boundary_expect);
								sdr_mask(pos_start..pos_end)	:= mirror_class_0(b.pattern_last_boundary_mask);

								put_line(scanport(scanpath_being_compiled).register_file, "step" 
									& natural'image(vector_id) 
									& " device" & positive'image(p) & row_separator_0 & to_lower(type_bic_data_register'image(BOUNDARY)));

							end if;


							-- calculate start position to place next image
							pos_start := pos_end + 1;
						end if;
					end if;
					b := b.next;
				end loop;
			end loop;

			-- insert trailer at begin of drive image (so that the trailer gets sent into the target FIRST)
			sdr_drive := shift_class_0(sdr_drive,right,trailer_length);
			sdr_drive(1..trailer_length) := mirror_class_0(scanpath_options.trailer_dr);

			-- insert trailer at end of expect/mask image (BSC receives trailer AFTER the target-capture values !)
			sdr_expect(length_total-trailer_length+1..length_total) := mirror_class_0(scanpath_options.trailer_dr);
			-- mask for trailer has same position with all bits set (means all bits are checked) -- CS: disabling checking option ?
			-- CS: when manipulating the mask, it must be mirrored. for the time being no need since all bits are set
			sdr_mask(length_total-trailer_length+1..length_total) := to_binary_class_0
																			(
																			to_binary( 
																				text_in => trailer_length * '1',
																				length	=> trailer_length,
																				class	=> class_0
																				)
																			);


			check_option_retry;

			add_class_a_cmd_to_step_list_pre(
				list				=> ptr_test_step_pre,
				--step_class_given	=> class_a,
				scan_given			=> SDR,
				vector_id_given		=> vector_id,
				length_total_given	=> length_total,
				img_drive_given		=> sdr_drive,	-- LSB left (pos 1)
				img_expect_given	=> sdr_expect,	-- LSB left (pos 1)
				img_mask_given		=> sdr_mask,	-- LSB left (pos 1)
				retry_count_given	=> sxr_retries_unsigned_8,
				retry_delay_given	=> sxr_retry_delay_unsigned_8,
				source_given		=> universal_string_type.to_bounded_string(extended_string.to_string(cmd))
				);

		end build_sdr_image;

	begin -- concatenate_sdr_images
		-- calculate total length of sdr image depending on latest loaded instructions
		-- from the total sdr length, the overall sdr image can be created
		for p in 1..summary.bic_ct loop -- p defines the position
			b := ptr_bic;
			while b /= null loop -- loop in bic list
				if b.position = p then -- on position match
					if b.chain = scanpath_being_compiled then -- on scanpath match

						-- chaining sdr drv and exp patterns starting with device closest to BSC TDO !
						-- use drv pattern depending on latest loaded instruction of particular device

						if b.pattern_last_ir_drive = replace_dont_care(b.opc_bypass) then
							length_total := length_total + bic_bypass_register_length;
						elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_extest) then
							length_total := length_total + b.len_bsr;
						elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_sample) then
							length_total := length_total + b.len_bsr;
						elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_preload) then
							length_total := length_total + b.len_bsr;
						elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_highz) then
							length_total := length_total + bic_bypass_register_length;
						elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_clamp) then
							length_total := length_total + bic_bypass_register_length;
						elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_idcode) then
							length_total := length_total + bic_idcode_register_length;
						elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_usercode) then
							length_total := length_total + bic_usercode_register_length;
						elsif b.pattern_last_ir_drive = replace_dont_care(b.opc_intest) then
							length_total := length_total + b.len_bsr;
						else
							put_line("ERROR: Instruction opcode for device '" 
								& universal_string_type.to_string(b.name) 
								& "' does not match any instruction covered in Std. " & bscan_standard_1 );
							raise constraint_error;
						end if;

					end if;
				end if;
				b := b.next;
			end loop;
		end loop;

		-- length_total now contains the length of the overall sdr image
		build_sdr_image;
	end concatenate_sdr_images;



 	begin -- compile_command
		prog_position	:= 400;

		--hard+soft trst (default)
		if get_field_from_line(cmd,1) = sequence_instruction_set.trst then
			write_llc(head => llc_head_tap, arg1 => llc_cmd_tap_trst, source => extended_string.to_string(cmd) ); 

		--only soft trst
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.strst then
			write_llc(head => llc_head_tap, arg1 => llc_cmd_tap_strst, source => extended_string.to_string(cmd) ); 

		--only hard trst
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.htrst then
			write_llc(head => llc_head_tap, arg1 => llc_cmd_tap_htrst, source => extended_string.to_string(cmd) ); 

		prog_position	:= 420;
		-- "tap_state" (example: tap_state test-logic-reset, tap_state pause-dr)
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.tap_state then
			if get_field_from_line(cmd,2) = tap_state.test_logic_reset then
				write_llc(head => llc_head_tap, arg1 => llc_cmd_tap_strst, source => extended_string.to_string(cmd) ); -- same as strst
			elsif get_field_from_line(cmd,2) = tap_state.run_test_idle then
				write_llc(head => llc_head_tap, arg1 => llc_cmd_tap_state_rti, source => extended_string.to_string(cmd) ); 
			elsif get_field_from_line(cmd,2) = tap_state.pause_dr then
				write_llc(head => llc_head_tap, arg1 => llc_cmd_tap_state_pdr, source => extended_string.to_string(cmd) ); 
			elsif get_field_from_line(cmd,2) = tap_state.pause_ir then 
				write_llc(head => llc_head_tap, arg1 => llc_cmd_tap_state_pir, source => extended_string.to_string(cmd) ); 
			else
				put_line("ERROR: TAP state not supported for low level operation !");
				raise constraint_error;
			end if;

		-- "connect" (example: connect port 1) -- CS: "connect all"
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.connect then
			if get_field_from_line(cmd,2) = scanport_identifier.port then 
				if get_field_from_line(cmd,3) = "1" then
					write_llc(head => llc_head_connect_disconnect, arg1 => 16#01#, arg2 => 16#01#, source => extended_string.to_string(cmd) ); 
				elsif get_field_from_line(cmd,3) = "2" then 
					write_llc(head => llc_head_connect_disconnect, arg1 => 16#02#, arg2 => 16#01#, source => extended_string.to_string(cmd) ); 
				else
					put_line("ERROR: Expected a valid scanport id. Example: " 
						& sequence_instruction_set.connect & row_separator_0
						& scanport_identifier.port & row_separator_0
						& "1");
					put_line("       Currently maximal" & positive'image(scanport_count_max) & " scanports are supported."); 
					raise constraint_error;
				end if;
			else
				put_line("ERROR: Expected keyword '" & scanport_identifier.port & "' after command '" & sequence_instruction_set.connect & "' !");
				raise constraint_error;
			end if;
 
		-- "disconnect" (example: disconnect port 1) -- CS: "disconnect all"
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.disconnect then
			if get_field_from_line(cmd,2) = scanport_identifier.port then 
				if get_field_from_line(cmd,3) = "1" then
					write_llc(head => llc_head_connect_disconnect, arg1 => 16#01#, arg2 => 16#00#, source => extended_string.to_string(cmd) ); 
				elsif get_field_from_line(cmd,3) = "2" then 
					write_llc(head => llc_head_connect_disconnect, arg1 => 16#02#, arg2 => 16#00#, source => extended_string.to_string(cmd) ); 
				else
					put_line("ERROR: Expected a valid scanport id. Example: " 
						& sequence_instruction_set.disconnect & row_separator_0
						& scanport_identifier.port & row_separator_0
						& "1");
					put_line("       Currently maximal" & positive'image(scanport_count_max) & " scanports are supported."); 
					raise constraint_error;
				end if;
			else
				put_line("ERROR: Expected keyword '" & scanport_identifier.port & "' after command '" & sequence_instruction_set.disconnect & "' !");
				raise constraint_error;
			end if;
 
		-- "power" example: power up 1, power down all
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.power then
			--write_llc(head => llc_head2, llcc => llc_cmd_internal_set_mux_sub_2, length => 5, source => "internal: set i2c mux sub bus 2" ); 
			if get_field_from_line(cmd,2) = power_cycle_identifier.up then

				-- pwr relay 1 on
				if get_field_from_line(cmd,3) = "1" then
					write_llc(head => llc_head_power_on_off, arg1 => 16#01#, arg2 => 16#01#, source => extended_string.to_string(cmd) ); 
				-- pwr relay 2 on
				elsif get_field_from_line(cmd,3) = "2" then
					write_llc(head => llc_head_power_on_off, arg1 => 16#02#, arg2 => 16#01#, source => extended_string.to_string(cmd) ); 
				-- pwr relay 3 on
				elsif get_field_from_line(cmd,3) = "3" then
					write_llc(head => llc_head_power_on_off, arg1 => 16#03#, arg2 => 16#01#, source => extended_string.to_string(cmd) ); 

				-- all pwr relays on
				elsif get_field_from_line(cmd,3) = power_channel_name.all_channels then 
					write_llc(head => llc_head_power_on_off, arg1 => 16#FF#, arg2 => 16#01#, source => extended_string.to_string(cmd) ); 
				-- gnd pwr relay on
				elsif get_field_from_line(cmd,3) = power_channel_name.gnd then
					write_llc(head => llc_head_power_on_off, arg1 => 16#00#, arg2 => 16#01#, source => extended_string.to_string(cmd) ); 
				else
					put_line("ERROR: Expected power channel id as positive integer or keyword '" 
						& power_channel_name.gnd & "' or '" & power_channel_name.all_channels & "' !");
					put_line("       Example: " & sequence_instruction_set.power & row_separator_0 & power_cycle_identifier.up 
						& row_separator_0 & power_channel_name.all_channels);
					put_line("       Currently" & positive'image(power_channel_ct) & " power channels for power supervising are supported !");
					put_line("       Additionally channel '" & power_channel_name.gnd & "' can be switched (without supervising feature) !");
					raise constraint_error;
				end if;

			elsif get_field_from_line(cmd,2) = power_cycle_identifier.down then

				-- pwr relay 1 off
				if get_field_from_line(cmd,3) = "1" then
					write_llc(head => llc_head_power_on_off, arg1 => 16#01#, arg2 => 16#00#, source => extended_string.to_string(cmd) ); 
				-- pwr relay 2 off
				elsif get_field_from_line(cmd,3) = "2" then
					write_llc(head => llc_head_power_on_off, arg1 => 16#02#, arg2 => 16#00#, source => extended_string.to_string(cmd) ); 
				-- pwr relay 3 off
				elsif get_field_from_line(cmd,3) = "3" then
					write_llc(head => llc_head_power_on_off, arg1 => 16#03#, arg2 => 16#00#, source => extended_string.to_string(cmd) ); 
				-- all pwr relays off
				elsif get_field_from_line(cmd,3) = power_channel_name.all_channels then 
					write_llc(head => llc_head_power_on_off, arg1 => 16#FF#, arg2 => 16#00#, source => extended_string.to_string(cmd) ); 
				-- gnd pwr relay off
				elsif get_field_from_line(cmd,3) = power_channel_name.gnd then
					write_llc(head => llc_head_power_on_off, arg1 => 16#00#, arg2 => 16#00#, source => extended_string.to_string(cmd) ); 
				else
					put_line("ERROR: Expected power channel id as positive integer or keyword '" 
						& power_channel_name.gnd & "' or '" & power_channel_name.all_channels & "' !");
					put_line("       Example: " & sequence_instruction_set.power & row_separator_0 & power_cycle_identifier.down
						& row_separator_0 & power_channel_name.all_channels);
					raise constraint_error;
				end if;

			else
				put_line("ERROR: Expected keyword '" & power_cycle_identifier.up & "' or '" & power_cycle_identifier.down 
					& "' after command '" & sequence_instruction_set.power & "' !");
				put_line("       Example: " & sequence_instruction_set.power & row_separator_0 & power_cycle_identifier.up 
					& row_separator_0 & power_channel_name.all_channels);
				put_line("       Currently" & positive'image(power_channel_ct) & " power channels for power supervising are supported !");
				put_line("       Additionally channel '" & power_channel_name.gnd & "' can be switched (without supervising feature) !");
				raise constraint_error;
			end if;

		-- "imax" example: imax 2 1 timeout 0.2 (means channel 2, max. current 1A, timeout to shutdown 0.2s)
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.imax then -- CS: check field count
			--write_llc(llct => llc_head2, llcc => llc_cmd_internal_set_mux_sub_3, length => 5, source => "internal: set i2c mux sub bus 3" ); 
			if positive'value(get_field_from_line(cmd,2)) in type_power_channel_id then
				power_channel_name.id := positive'value(get_field_from_line(cmd,2)); -- get power channel
			else
				put_line("ERROR: Expected power channel id after command '" & sequence_instruction_set.imax & "' !");
				put_example(sequence_instruction_set.imax);
				raise constraint_error;
			end if;

			-- get imax (as set by operator) and calculate 8 bit DAC value
			-- write llc (40h + pwr channel , current_limit_set_by_operator) as extended I2C operation
			current_limit_set_by_operator := float'value(get_field_from_line(cmd,3)); 
-- 			ubyte_scratch := unsigned_8(natural(22.4 * (5.7 + current_limit_set_by_operator)));
-- 			ubyte_scratch2 := 16#40# + unsigned_8(power_channel_name.id);
-- 			write_llc(llct => ubyte_scratch2, llcc => ubyte_scratch, length => 5, 
-- 				source => "internal: pwr channel " & natural_to_string(natural(ubyte_scratch2),16,2) & row_separator_0
-- 				& "current limit " & natural_to_string(natural(ubyte_scratch),16,2)); 

			write_llc(
				head => llc_head_imax,
				arg1 => unsigned_8(power_channel_name.id), 
				arg2 => unsigned_8(natural(22.4 * (5.7 + current_limit_set_by_operator))),
				source => " pwr channel" & natural'image(power_channel_name.id) & " imax" & float'image(current_limit_set_by_operator) & " Amp"
				);

			-- get timeout
			if get_field_from_line(cmd,4) = timeout_identifier then
				if float'value(get_field_from_line(cmd,5)) in type_overload_timeout then
					overload_timeout := float'value(get_field_from_line(cmd,5));
					-- set i2c muxer sub bus 2
					--write_llc(llct => llc_head2, llcc => llc_cmd_internal_set_mux_sub_2, length => 5, source => "internal: set i2c mux sub bus 2"); 

					-- cal. 8bit timeout value
					-- write llc (43h + pwr_channel) as extended I2C operation
-- 					ubyte_scratch := unsigned_8(natural(overload_timeout/overload_timeout_resolution)); 
-- 					ubyte_scratch2 := 16#43# + unsigned_8(power_channel_name.id);
-- 					write_llc(llct => ubyte_scratch2, llcc => ubyte_scratch, length => 5, source => extended_string.to_string(cmd) );

					write_llc(
						head => llc_head_timeout,
						arg1 => unsigned_8(power_channel_name.id),
						arg2 => unsigned_8(natural(overload_timeout/overload_timeout_resolution)),
						--source => extended_string.to_string(cmd)
						source => " pwr channel" & natural'image(power_channel_name.id) & " timeout" & float'image(overload_timeout) & " sec"
						); 
				else
					put_line("ERROR: Timeout value invalid !");
					put_line("       Provide a number between" & type_overload_timeout'image(type_overload_timeout'first) 
						& " and " & type_overload_timeout'image(type_overload_timeout'last) & ". Unit is 'seconds' !");
					put_example(sequence_instruction_set.imax);
				end if;
			else
				put_line("ERROR: Expected keyword '" & timeout_identifier & "' after current value !");
				raise constraint_error;
			end if;

 
		-- "delay" example: delay 0.5 (means: pause for 0.5 seconds)
 		elsif get_field_from_line(cmd,1) = sequence_instruction_set.dely then -- CS: check field count
			if float'value(get_field_from_line(cmd,2)) in type_delay_value then

				-- calc. 8 bit delay value and write llc as time operation
				delay_set_by_operator := float'value(get_field_from_line(cmd,2));
-- 				ubyte_scratch := unsigned_8(natural(delay_set_by_operator/delay_resolution));
-- 				write_llc(llct => llc_head3, llcc => ubyte_scratch, length => 5, source => extended_string.to_string(cmd) ); 

				write_llc(
					head => llc_head_delay, 
					arg1 => unsigned_8(natural(delay_set_by_operator/delay_resolution)),
					source => extended_string.to_string(cmd)
					); 
			else
				put_line("ERROR: Delay value invalid !");
				put_line("       Provide a number between" & float'image(delay_resolution) 
					& " and " & type_delay_value'image(type_delay_value'last) & ". Unit is 'seconds' !");
				put_line("       Example: " & sequence_instruction_set.dely & row_separator_0 & type_delay_value'image(type_delay_value'last));
			end if;


		-- "set" 
		-- examples: 
		-- set IC301 drv ir 7 downto 0 = 00000001 sample
		-- set IC301 exp ir 7 downto 0 = 000xxx01 instruction_capture
		-- set IC303 drv boundary 17 downto 0 = x1xxxxxxxxxxxxxxxx safebits
		-- set IC301 exp boundary 107 downto 0 = x
		-- set IC303 drv boundary 16=0 16=0 16=0 16=0 17=0 17=0 17=0 17=0
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.set then -- CS: check field count

			-- check if given device is a bic and get its coordinates
			bic_name := universal_string_type.to_bounded_string(get_field_from_line(cmd,2));
			bic_coordinates := get_bic_coordinates(bic_name);

			if bic_coordinates /= null then

				-- set set_direction flag
				if get_field_from_line(cmd,3) = sxr_io_identifier.drive then -- if "drv" found
					set_direction := drv;
				elsif get_field_from_line(cmd,3) = sxr_io_identifier.expect then -- if "drv" found
					set_direction := exp;
				else
					put_line("ERROR: Expected keyword '" & sxr_io_identifier.drive & "' or '" & sxr_io_identifier.expect & "' after device name !");
					raise constraint_error;
				end if;

				-- set target register and set cell_id_max for later checking the cell id
				-- CS: do something more professional like
-- 						case set_register is
-- 							when ir 		=> 
-- 							when idcode 	=> 
-- 							when usercode	=> 
-- 							when boundary	=> 
-- 							when bypass 	=> 
-- 						end case;
				if get_field_from_line(cmd,4) = sir_target_register.ir then
					target_register := ir;
					cell_id_max := bic_coordinates.len_ir - 1;
				elsif get_field_from_line(cmd,4) = sdr_target_register.boundary then
					target_register := boundary;
					cell_id_max := bic_coordinates.len_bsr - 1;
				elsif get_field_from_line(cmd,4) = sdr_target_register.bypass then
					target_register := bypass;
					cell_id_max := bic_bypass_register_length - 1;
				elsif get_field_from_line(cmd,4) = sdr_target_register.idcode then
					target_register := idcode;
					cell_id_max := bic_idcode_register_length - 1;
				elsif get_field_from_line(cmd,4) = sdr_target_register.usercode then
					target_register := usercode;
					cell_id_max := bic_usercode_register_length - 1;
				else
					put_line("ERROR: Invalid register name found ! Supported registers are:");
					for r in 0..type_set_target_register'pos(type_set_target_register'last) loop
						put(row_separator_0 & to_lower(type_set_target_register'image(type_set_target_register'val(r))));
					end loop;
					raise constraint_error;
				end if;

				-- set assignment method (bit-wise or register-wise)
				-- if "downto" found in field 6, the assignment method is assumed as "register-wise"
				-- if no "downto" found in field 6, we assume "bit-wise" assignment
				if get_field_from_line(cmd,6) = sxr_vector_orientation.downto then
					set_assignment_method 	:= register_wise;
					set_vector_orientation	:= downto;

					-- check if upper cell id is within targeted register
					-- and save cell id as cell_id_upper_end
					if natural'value(get_field_from_line(cmd,5)) <= cell_id_max then
						cell_id_upper_end := natural'value(get_field_from_line(cmd,5));
					else
						put_line("ERROR: Upper end cell id must be below or equal" & natural'image(cell_id_max) & " for this register !");
						raise constraint_error;
					end if;

					-- check if lower cell id is below cell_id_upper_end
					-- and save cell id as cell_id_lower_end
					if natural'value(get_field_from_line(cmd,7)) <= cell_id_upper_end then
						cell_id_lower_end := natural'value(get_field_from_line(cmd,7));
					else
						put_line("ERROR: Lower end cell id must be below or equal" & natural'image(cell_id_upper_end) & " for this register !");
						raise constraint_error;
					end if;


				elsif get_field_from_line(cmd,6) = sxr_vector_orientation.to then
					set_assignment_method 	:= register_wise;
					set_vector_orientation	:= to;
					put_line("ERROR: Register-wise assignment not supported with identifier '" & sxr_vector_orientation.to & "' !");
					put_line("       Check MSB, LSB and use '" & sxr_vector_orientation.downto & "' instead !");
					raise constraint_error;
					-- CS: should be supported
				else
					set_assignment_method := bit_wise;
				end if;

				for p in 1..summary.bic_ct loop
				-- p points to device in current chain. position 1 is closest to BSC TDO !

					-- scanpath_being_compiled holds the id of the current scanpath.
					-- we care for a device in that scanpath. if not in scanpath it is skipped.

					if bic_coordinates.chain = scanpath_being_compiled then -- if the device is in scanpath being compiled

						case set_assignment_method is
							when register_wise =>
								case set_direction is
									when drv =>
										-- update drive image
										case target_register is
											when ir =>
												bic_coordinates.pattern_last_ir_drive := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_ir_drive, -- MSB left !
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation
													);
												-- CS: verify the update yielded a valid instruction !
											when boundary =>
												bic_coordinates.pattern_last_boundary_drive := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_boundary_drive,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation
													);
											when bypass =>
												bic_coordinates.pattern_last_bypass_drive := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_bypass_drive,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation
													);
											when idcode =>
												bic_coordinates.pattern_last_idcode_drive := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_idcode_drive,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation
													);
											when usercode =>
												bic_coordinates.pattern_last_usercode_drive := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_usercode_drive,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation
													);
										end case;


									when exp =>
										-- update expect and mask image
										case target_register is
											when ir =>
												bic_coordinates.pattern_last_ir_expect := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_ir_expect,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction
													);
												bic_coordinates.pattern_last_ir_mask := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_ir_mask,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction,
													mask				=> true
													);

											when boundary =>
												bic_coordinates.pattern_last_boundary_expect := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_boundary_expect,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction
													);
												bic_coordinates.pattern_last_boundary_mask := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_boundary_mask,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction,
													mask				=> true
													);

											when bypass =>
												bic_coordinates.pattern_last_bypass_expect := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_bypass_expect,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction
													);
												bic_coordinates.pattern_last_bypass_mask := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_bypass_mask,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction,
													mask				=> true
													);

											when idcode =>
												bic_coordinates.pattern_last_idcode_expect := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_idcode_expect,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction
													);
												bic_coordinates.pattern_last_idcode_mask := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_idcode_mask,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction,
													mask				=> true
													);

											when usercode =>
												bic_coordinates.pattern_last_usercode_expect := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_usercode_expect,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction
													);
												bic_coordinates.pattern_last_usercode_mask := update_pattern(
													pattern_old 		=> bic_coordinates.pattern_last_usercode_mask,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation,
													direction			=> set_direction,
													mask				=> true
													);

										end case;

								end case;

							when bit_wise =>
								for c in 5..field_ct loop
									cell_assignment := get_cell_assignment(get_field_from_line(cmd,c));
									-- get cell id from assignment and check range
									-- cell_id_max has been set earlier according to the targeted register
									if cell_assignment.cell_id <= cell_id_max then
										-- the cell id must be converted (mirrored) to the position in the targeted image (drive, expect or mask)
										-- example: register length = 8, assignment 7=x: cell_position_in_image = 1
										cell_position_in_image := cell_id_max + 1 - cell_assignment.cell_id;
										case set_direction is
											when drv => 
												case target_register is
													when ir =>
														bic_coordinates.pattern_last_ir_drive(cell_position_in_image) := cell_assignment.value;
													when boundary =>
														bic_coordinates.pattern_last_boundary_drive(cell_position_in_image) := cell_assignment.value;
													when bypass =>
														bic_coordinates.pattern_last_bypass_drive(cell_position_in_image) := cell_assignment.value;
													when idcode =>
														bic_coordinates.pattern_last_idcode_drive(cell_position_in_image) := cell_assignment.value;
													when usercode =>
														bic_coordinates.pattern_last_usercode_drive(cell_position_in_image) := cell_assignment.value;
												end case;
											when exp =>
												-- if the value to be assigned is don't care (x), 
												-- the value to be assigned is replaced by zero
												-- further-on: the mask bit for this position is to be cleared
												-- in order not disable the check here
												cell_expect_mask := '1'; -- per default the check is enabled
												if cell_assignment.value = 'x' or cell_assignment.value = 'X' then
													cell_assignment.value := '0';
													cell_expect_mask := '0';
												end if;

												-- update the targeted register at position cell_position_in_image
												case target_register is
													when ir =>
														bic_coordinates.pattern_last_ir_expect(cell_position_in_image) := cell_assignment.value;
														bic_coordinates.pattern_last_ir_mask(cell_position_in_image) := cell_expect_mask;
													when boundary =>
														bic_coordinates.pattern_last_boundary_expect(cell_position_in_image) := cell_assignment.value;
														bic_coordinates.pattern_last_boundary_mask(cell_position_in_image) := cell_expect_mask;
													when bypass =>
														bic_coordinates.pattern_last_bypass_expect(cell_position_in_image) := cell_assignment.value;
														bic_coordinates.pattern_last_bypass_mask(cell_position_in_image) := cell_expect_mask;
													when idcode =>
														bic_coordinates.pattern_last_idcode_expect(cell_position_in_image) := cell_assignment.value;
														bic_coordinates.pattern_last_idcode_mask(cell_position_in_image) := cell_expect_mask;
													when usercode =>
														bic_coordinates.pattern_last_usercode_expect(cell_position_in_image) := cell_assignment.value;
														bic_coordinates.pattern_last_usercode_mask(cell_position_in_image) := cell_expect_mask;
												end case;
										end case;
									else
										put_line("ERROR: Cell id must be below or equal" & natural'image(cell_id_max) & " for this register !");
										raise constraint_error;
									end if;
								end loop;
								-- CS: verify the instruction is valid !
						end case;
					end if;

				end loop;

				-- CS: field 10 not read any more -> make it a comment


			else -- if device is not a bic
				put_line("ERROR: Device '" & universal_string_type.to_string(bic_name) & "' is not part of any scanpath ! Check name and capitalization !)");
				raise constraint_error;
			end if; -- if device is a bic

 
		-- "sir"
 		elsif get_field_from_line(cmd,1) = sequence_instruction_set.sir then -- CS: check id keyword and id itself ?
			vector_id := natural'value(get_field_from_line(cmd,3));

			-- concatenate sir drive, expect and mask images to a single large image
			concatenate_sir_images;

		-- "sdr"
 		elsif get_field_from_line(cmd,1) = sequence_instruction_set.sdr then -- CS: check id keyword and id itself ?
			vector_id := natural'value(get_field_from_line(cmd,3));

			concatenate_sdr_images;

 		end if;

-- 			if prog_position = "RE1" then
-- 				put_line("Retry specification invalid !");
-- 				put_line("Max. retry count is" & natural'image(retry_ct_max));
-- 				put("Max. delay is "); put(retry_delay_max, exp => 0 , aft => 1); put(" sec"); new_line;
-- 				put_line("Example for an sir with ID 7, 3 retries with 0.5sec delay inbetween: sir 7 option retry 3 delay 0.5");
-- 			end if;
 	end compile_command;

-----------------
	function get_destination_address_from_journal return natural is
	-- reads the latest entry of the journal and calculates the next available destination address
		line_counter	: natural := 0;
		line			: extended_string.bounded_string;
		last_dest_addr	: natural :=0;
		last_size		: natural :=0;
		next_dest_addr	: natural;
	begin
		if exists (journal) then -- if there is a journal, find last entry
			--prog_position := "JO1";
			open( 
				file => file_journal,
				mode => in_file,
				name => journal
				);
			set_input(file_journal);

			-- read journal until last line. values found there are taken for calculating next_dest_addr

			-- example of a journal:

-- 				test_name   dest_addr(hex)  size(dec)  comp_version  date(yyyy:mm:dd)  time(hh:mm:ss)
-- 				-------------------------------------------------------------------------------------
-- 				infra 00000000h 674 004.004 2016-04-13 14:25:46
-- 				intercon1 00000300h 1755 004.004 2016-04-13 14:25:50
-- 				sram_ic202 00000A00h 6906 004.004 2016-04-13 14:26:05
-- 				sram_ic203 00002500h 6906 004.004 2016-04-13 14:26:19
-- 				osc 00004000 426h 004.004 2016-04-13 14:26:28
-- 				LED_D401 00004200h 2562 004.004 2016-04-13 14:26:29
-- 				LED_D402 00004D00h 2562 004.004 2016-04-13 14:26:30
-- 				LED_D403 00005800h 2562 004.004 2016-04-13 14:26:30
-- 				LED_D404 00006300h 2562 004.004 2016-04-13 14:26:31


			while not end_of_file
				loop
					line_counter := line_counter + 1; -- count lines
					line		 := extended_string.to_bounded_string(get_line); -- get a line from the journal

					if line_counter > 2 then -- header and separator must be skipped (see example above)
						-- last_dest_addr is a hex number !!!
						last_dest_addr := string_to_natural(get_field_from_line(line,2));
						last_size := integer'value(get_field_from_line(line,3));  -- last_size is a dec number !!!
					end if;
				end loop;

				next_dest_addr := (last_dest_addr + last_size); -- calculate next_dest_addr

				-- round addr up to multiple of 256
				while (next_dest_addr rem 256) /= 0 loop
						next_dest_addr := next_dest_addr + 1;
				end loop;
				--set_output(standard_output);
				--put_line("compiling for destination address: " & natural'image(next_dest_addr));
				--put(mem_size);

				-- check if there is space left for vector file in BSC RAM
				if next_dest_addr >= mem_size then 
					put_line("ERROR: available address range exceeded !");
					raise constraint_error; 
				end if;

				set_input(standard_input);
				close(file_journal);

			-- if no journal found, default to start address 0
			else 
				next_dest_addr := 0;
		end if;

		return next_dest_addr;
	end get_destination_address_from_journal;


	procedure write_journal is
	-- writes test_name, destination_address, size, date in journal
	-- if journal not exists, create a new one. append otherwise.

		procedure write_numbers is
		-- writes something like: infra 00000000h 674 004.004 2016-04-13 14:25:46
		begin
			put(file_journal,universal_string_type.to_string(test_name) 
				& row_separator_0 & natural_to_string(destination_address,16,8) 
				& natural'image(size_of_vector_file) 
				& row_separator_0 & compseq_version
				& row_separator_0 & m1.date_now);
		end write_numbers;

	begin
		if exists(journal) then 
			open( 
				file => file_journal,
				mode => append_file,
				name => journal
				);
			write_numbers;
		else
			put_line("No journal found. Creating a new one ...");
			create(file_journal,out_file,journal);
			put_line(file_journal,"test_name   dest_addr(hex)  size(dec)  comp_version  date(yyyy:mm:dd)  time(hh:mm:ss)");
			put_line(file_journal,"-------------------------------------------------------------------------------------");
			write_numbers;
		end if;
	end write_journal;


	function get_test_info return type_test_info is
		ti					: type_test_info; -- to be returned after reading the section
		section_entered		: boolean := false;
		line_of_file		: extended_string.bounded_string;
	begin
		reset(sequence_file);
		line_counter := 0;
		while not end_of_file
			loop
				line_counter := line_counter + 1; -- count lines in sequence file
				line_of_file := extended_string.to_bounded_string(get_line);
				line_of_file := remove_comment_from_line(line_of_file);

				if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything
					--put_line(line);
					--Put( Integer'Image( Integer'Value("16#1A2B3C#") ) );  
					if section_entered then
						-- once inside section "info", wait for end of section mark
						if get_field_from_line(line_of_file,1) = section_mark.endsection then -- when endsection found
							section_entered := false; -- reset section entered flag
							-- SECTION "INFO" READING DONE.
							exit;

						else
							-- PROCESSING SECTION INFO BEGIN
							--put_line(extended_string.to_string(line_of_file));

							-- search for data base name and verify against data base given as argument
							if get_field_from_line(line_of_file,1) = section_info_item.data_base then
								if get_field_from_line(line_of_file,3) = universal_string_type.to_string(data_base) then
									ti.data_base_valid := true;
								else
									--put_line(standard_output,"WARNING: Data base mismatch in section '" & test_section.info & "' !");
									null;
									-- CS: abort ?
								end if;
							end if;

							-- search for test name and verify against test name given as argument
							if get_field_from_line(line_of_file,1) = section_info_item.test_name then
								if get_field_from_line(line_of_file,3) = universal_string_type.to_string(test_name) then
									ti.test_name_valid := true;
								else
									null;
									-- CS: abort ?
								end if;
							end if;

							-- search for end_sdr and end_sir. if no end_sdr/sir found default is uses (see m1_internal.ads)
							if get_field_from_line(line_of_file,1) = section_info_item.end_sdr then
								ti.end_sdr := type_end_sdr'value(get_field_from_line(line_of_file,3));
							end if;
							if get_field_from_line(line_of_file,1) = section_info_item.end_sir then
								ti.end_sir := type_end_sir'value(get_field_from_line(line_of_file,3));
							end if;

						end if;


					else
						-- wait for section "info" begin mark
						if get_field_from_line(line_of_file,1) = section_mark.section then
							if get_field_from_line(line_of_file,2) = test_section.info then
								section_entered := true; -- set section enterd "flag"
							end if;
						end if;
					end if;

				end if;
			end loop;
		
		if not ti.data_base_valid then
			put_line("WARNING: Name of data base not found or invalid in section '" & test_section.info & "' !");
		end if;

		if not ti.test_name_valid then
			put_line("WARNING: Name of test not found or invalid in section '" & test_section.info & "' !");
		end if;

		-- CS: write report

		return ti;
	end get_test_info;


	function get_scanpath_options return type_scanpath_options is
		so					: type_scanpath_options; -- to be returned after reading section options
		section_entered		: boolean := false;
		line_of_file		: extended_string.bounded_string;
		scratch_float		: float;

		function frequency_float_to_unsigned_8 (frequency_float : type_tck_frequency) return unsigned_8 is
			-- frequency_float is given in unit MHz
			frequency_unsigned_8: unsigned_8 := 16#52#;
			scan_clock_timer_float		: float;
			scan_clock_timer_positive	: positive;
			exponent_max				: positive := 8; -- 10^8
			subtype type_low_nibble is natural range 0..exponent_max;
			subtype type_high_nibble is positive range 1..15;
			low_nibble	: type_low_nibble;
			high_nibble	: type_high_nibble;
			frequency_real : float;
		begin
			put_line(standard_output,"calculating available tck frequency...");
			-- display frequency requested by user 
			put(standard_output," - requested:" & type_tck_frequency'image(frequency_float) & " MHz"); new_line(standard_output);

			-- calculate scan_clock_timer (N) required for half of a tck cycle (duty cycle of 50% applies)
			-- since the result is a float number, it must be converted to a positive number
			scan_clock_timer_float := float(executor_master_clock) / (2.0 * float(frequency_float));
			--put(standard_output,"scan clock timer float: " & float'image(scan_clock_timer_float)); new_line(standard_output);
			scan_clock_timer_positive := positive(scan_clock_timer_float);
			--put(standard_output,"scan clock timer n: " & positive'image(scan_clock_timer_positive)); new_line(standard_output);

			-- calculate frequency_unsigned_8 (low nibble and high nibble separately)
			-- then add them to obtain frequency_unsigned_8 (which will be written into the vector/list file)
			for e in 1..exponent_max loop
				--put(standard_output,"exponent: " & positive'image(e)); new_line(standard_output);
				if scan_clock_timer_positive < 10**e then
					low_nibble	:= e-1;
					high_nibble	:= type_high_nibble(scan_clock_timer_positive/(10**(e-1))); -- CS: fix rounding error when number ends in 5
					frequency_unsigned_8 := unsigned_8(high_nibble*16 + low_nibble);
					exit;
				end if;
			end loop;

			--put(standard_output,"high nibble: " & type_high_nibble'image(high_nibble)); new_line(standard_output);
			--put(standard_output," low nibble: " & type_low_nibble'image(low_nibble)); new_line(standard_output);
			-- calculate and display real frequency availabe close to the requested
			frequency_real := float(executor_master_clock) / float(2 * high_nibble * 10**low_nibble);
			put(standard_output," - selected: " & float'image(frequency_real) & " MHz"); new_line(standard_output);

			-- CS: if frequency given is zero (or option missing entirely) the hex value defaults (see m1_internal.ads)
			-- put_line("WARNING: frequency option invalid or missing. Falling back to safest frequency of " & type_tck_frequency'image(tck_frequency_default) & " Mhz ...");
			
			return frequency_unsigned_8;
		end frequency_float_to_unsigned_8;
		
	begin
		reset(sequence_file);
		line_counter := 0;
		while not end_of_file
			loop
				line_counter := line_counter + 1; -- count lines in sequence file (global counter !)
				line_of_file := extended_string.to_bounded_string(get_line);
				line_of_file := remove_comment_from_line(line_of_file);

				if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything
					--put_line(line);
					--Put( Integer'Image( Integer'Value("16#1A2B3C#") ) );  
					if section_entered then
						-- once inside section "options", wait for end of section mark
						if get_field_from_line(line_of_file,1) = section_mark.endsection then -- when endsection found
							section_entered := false; -- reset section entered flag
							-- SECTION "OPTIONS" READING DONE.
							exit;

						else
							-- PROCESSING SECTION OPTIONS BEGIN

							-- NOTE: if a particular option missing -> default to option as specified for type type_scanpath_options (see m1_internal.ads)
							--put_line(extended_string.to_string(line_of_file));

							-- search for option on_fail
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.on_fail then
								so.on_fail := type_on_fail_action'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option frequency
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.frequency then
								so.frequency := type_tck_frequency'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option trailer_ir. if not found, trailer_default is used (see m1_internal.ads)
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.trailer_ir then
								so.trailer_ir := to_binary_class_0(
													binary_in	=> to_binary(
															text_in		=> get_field_from_line(line_of_file,2),
															length		=> trailer_length,
															class		=> class_0
															)
													);
							end if;

							-- search for option trailer_dr. if not found, trailer_default is used (see m1_internal.ads)
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.trailer_dr then
								so.trailer_dr := to_binary_class_0(
													binary_in	=> to_binary(
															text_in		=> get_field_from_line(line_of_file,2),
															length		=> trailer_length,
															class		=> class_0
															)
													);
							end if;

--	type type_voltage_out is new type_voltage range 1.8 .. 3.3;
--	type type_threshold_tdi is new type_voltage range 0.1 .. 3.3;
--	type type_driver_characteristic is (push_pull , weak0, weak1, tie_high, tie_low, high_z);

							-- VOLTAGES AND DRIVER CHARACTERISTICS FOR PORT 1:

							-- search for option voltage_out_port_1. if not found, default to lowest value
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.voltage_out_port_1 then
								so.voltage_out_port_1 := type_voltage_out'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option tck_driver_port_1. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.tck_driver_port_1 then
								so.tck_driver_port_1 := type_driver_characteristic'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option tms_driver_port_1. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.tms_driver_port_1 then
								so.tms_driver_port_1 := type_driver_characteristic'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option tdo_driver_port_1. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.tdo_driver_port_1 then
								so.tdo_driver_port_1 := type_driver_characteristic'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option trst_driver_port_1. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.trst_driver_port_1 then
								so.trst_driver_port_1 := type_driver_characteristic'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option threshold_tdi_port_1. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.threshold_tdi_port_1 then
								so.threshold_tdi_port_1 := type_threshold_tdi'value(get_field_from_line(line_of_file,2));
							end if;


							-- VOLTAGES AND DRIVER CHARACTERISTICS FOR PORT 2:

							-- search for option voltage_out_port_2. if not found, default to lowest value
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.voltage_out_port_2 then
								so.voltage_out_port_2 := type_voltage_out'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option voltage_out_port_2. if not found, default to lowest value
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.voltage_out_port_2 then
								so.voltage_out_port_2 := type_voltage_out'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option tck_driver_port_2. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.tck_driver_port_2 then
								so.tck_driver_port_2 := type_driver_characteristic'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option tms_driver_port_2. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.tms_driver_port_2 then
								so.tms_driver_port_2 := type_driver_characteristic'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option tdo_driver_port_2. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.tdo_driver_port_2 then
								so.tdo_driver_port_2 := type_driver_characteristic'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option trst_driver_port_2. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.trst_driver_port_2 then
								so.trst_driver_port_2 := type_driver_characteristic'value(get_field_from_line(line_of_file,2));
							end if;

							-- search for option threshold_tdi_port_2. if not found, use default
							if get_field_from_line(line_of_file,1) = section_scanpath_options_item.threshold_tdi_port_2 then
								so.threshold_tdi_port_2 := type_threshold_tdi'value(get_field_from_line(line_of_file,2));
							end if;


						end if;

					else
						-- wait for section "info" begin mark
						if get_field_from_line(line_of_file,1) = section_mark.section then
							if get_field_from_line(line_of_file,2) = test_section.options then
								section_entered := true; -- set section enterd "flag"
							end if;
						end if;
					end if;

				end if;
			end loop;
			
			-- convert frequency to scan clock timer value
			so.frequency_prescaler_unsigned_8 := frequency_float_to_unsigned_8(so.frequency);
			
			-- calculate 8bit values required for DACs (by DAC resolution and full-scale value)
			-- CS: depends on transeiver hardware
			-- driver voltages:
			scratch_float := (float(so.voltage_out_port_1) * 255.0)/3.3;
			so.voltage_out_port_1_unsigned_8 := unsigned_8(natural(scratch_float));
			scratch_float := (float(so.voltage_out_port_2) * 255.0)/3.3;
			so.voltage_out_port_2_unsigned_8 := unsigned_8(natural(scratch_float));

			-- input threshold voltages
			scratch_float := (float(so.threshold_tdi_port_1) * 255.0)/3.3;
			so.threshold_tdi_port_1_unsigned_8 := unsigned_8(natural(scratch_float));
			scratch_float := (float(so.threshold_tdi_port_2) * 255.0)/3.3;
			so.threshold_tdi_port_2_unsigned_8 := unsigned_8(natural(scratch_float));

			-- convert driver characteristics to unsigned_8 -- CS: replace hex numbers by names in m1_firmware.ads
			-- port 1:
			case so.tck_driver_port_1 is
				when push_pull	=> so.tck_driver_port_1_unsigned_8	:= 16#06#;
				when weak1		=> so.tck_driver_port_1_unsigned_8	:= 16#01#;
				when weak0		=> so.tck_driver_port_1_unsigned_8	:= 16#02#;
				when tie_low	=> so.tck_driver_port_1_unsigned_8	:= 16#04#;
				when tie_high	=> so.tck_driver_port_1_unsigned_8	:= 16#05#;
				when highz		=> so.tck_driver_port_1_unsigned_8	:= 16#03#;
 			end case;
 
 			case so.tms_driver_port_1 is
				when push_pull	=> so.tms_driver_port_1_unsigned_8	:= 16#30#;
				when weak1		=> so.tms_driver_port_1_unsigned_8	:= 16#08#;
				when weak0		=> so.tms_driver_port_1_unsigned_8	:= 16#10#;
				when tie_low	=> so.tms_driver_port_1_unsigned_8	:= 16#20#;
				when tie_high	=> so.tms_driver_port_1_unsigned_8	:= 16#28#;
				when highz		=> so.tms_driver_port_1_unsigned_8	:= 16#18#;
 			end case;

 			case so.tdo_driver_port_1 is
				when push_pull	=> so.tdo_driver_port_1_unsigned_8	:= 16#06#;
				when weak1		=> so.tdo_driver_port_1_unsigned_8	:= 16#01#;
				when weak0		=> so.tdo_driver_port_1_unsigned_8	:= 16#02#;
				when tie_low	=> so.tdo_driver_port_1_unsigned_8	:= 16#04#;
				when tie_high	=> so.tdo_driver_port_1_unsigned_8	:= 16#05#;
				when highz		=> so.tdo_driver_port_1_unsigned_8	:= 16#03#;
 			end case;

 			case so.trst_driver_port_1 is
				when push_pull	=> so.trst_driver_port_1_unsigned_8	:= 16#30#;
				when weak1		=> so.trst_driver_port_1_unsigned_8	:= 16#08#;
				when weak0		=> so.trst_driver_port_1_unsigned_8	:= 16#10#;
				when tie_low	=> so.trst_driver_port_1_unsigned_8	:= 16#20#;
				when tie_high	=> so.trst_driver_port_1_unsigned_8	:= 16#28#;
				when highz		=> so.trst_driver_port_1_unsigned_8	:= 16#18#;
 			end case;

			-- port 2:
			case so.tck_driver_port_2 is
				when push_pull	=> so.tck_driver_port_2_unsigned_8	:= 16#06#;
				when weak1		=> so.tck_driver_port_2_unsigned_8	:= 16#01#;
				when weak0		=> so.tck_driver_port_2_unsigned_8	:= 16#02#;
				when tie_low	=> so.tck_driver_port_2_unsigned_8	:= 16#04#;
				when tie_high	=> so.tck_driver_port_2_unsigned_8	:= 16#05#;
				when highz		=> so.tck_driver_port_2_unsigned_8	:= 16#03#;
 			end case;
 
 			case so.tms_driver_port_2 is
				when push_pull	=> so.tms_driver_port_2_unsigned_8	:= 16#30#;
				when weak1		=> so.tms_driver_port_2_unsigned_8	:= 16#08#;
				when weak0		=> so.tms_driver_port_2_unsigned_8	:= 16#10#;
				when tie_low	=> so.tms_driver_port_2_unsigned_8	:= 16#20#;
				when tie_high	=> so.tms_driver_port_2_unsigned_8	:= 16#28#;
				when highz		=> so.tms_driver_port_2_unsigned_8	:= 16#18#;
 			end case;

 			case so.tdo_driver_port_2 is
				when push_pull	=> so.tdo_driver_port_2_unsigned_8	:= 16#06#;
				when weak1		=> so.tdo_driver_port_2_unsigned_8	:= 16#01#;
				when weak0		=> so.tdo_driver_port_2_unsigned_8	:= 16#02#;
				when tie_low	=> so.tdo_driver_port_2_unsigned_8	:= 16#04#;
				when tie_high	=> so.tdo_driver_port_2_unsigned_8	:= 16#05#;
				when highz		=> so.tdo_driver_port_2_unsigned_8	:= 16#03#;
 			end case;

 			case so.trst_driver_port_2 is
				when push_pull	=> so.trst_driver_port_2_unsigned_8	:= 16#30#;
				when weak1		=> so.trst_driver_port_2_unsigned_8	:= 16#08#;
				when weak0		=> so.trst_driver_port_2_unsigned_8	:= 16#10#;
				when tie_low	=> so.trst_driver_port_2_unsigned_8	:= 16#20#;
				when tie_high	=> so.trst_driver_port_2_unsigned_8	:= 16#28#;
				when highz		=> so.trst_driver_port_2_unsigned_8	:= 16#18#;
 			end case;


		-- CS: write report

		return so;
	end get_scanpath_options;


	function count_sequences return positive is
	-- returns number of sequences in sequence file
	-- CS: sequence id check
		sequence_count	: natural := 0;
		section_entered	: boolean := false;
		line_of_file	: extended_string.bounded_string;
	begin
		reset(sequence_file);
		line_counter := 0;
		while not end_of_file
			loop
				line_counter := line_counter + 1; -- count lines in sequence file (global counter !)
				line_of_file := extended_string.to_bounded_string(get_line);
				line_of_file := remove_comment_from_line(line_of_file);

				if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything

					if section_entered then

						-- once inside section "sequence", wait for end of section mark
						if get_field_from_line(line_of_file,1) = section_mark.endsection then -- when endsection found
							section_entered := false; -- reset section entered flag
							-- SECTION "SEQUENCE" READING DONE.

							sequence_count := sequence_count + 1;
							--exit;
							-- CS: check sequence id, make sure ids do not repeat

						else
							-- PROCESSING SECTION OPTIONS BEGIN
							null;
							--put_line(extended_string.to_string(line_of_file));
						end if;

					else
						-- wait for section "sequence" begin mark
						if get_field_from_line(line_of_file,1) = section_mark.section then
							if get_field_from_line(line_of_file,2) = test_section.sequence then
								section_entered := true; -- set section enterd "flag"
							end if;
						end if;
					end if;
				end if;

			end loop;

		if sequence_count = 0 then
			put_line("ERROR: No valid sequence found !");
			raise constraint_error;
		else
			put_line("found" & positive'image(sequence_count) & " sequence(s) ...");
		end if;

		return sequence_count;
	end count_sequences;
	

	procedure write_vector_file_header is
		nat_scratch : natural;
	begin
		seq_io_unsigned_byte.create( vector_file_header, seq_io_unsigned_byte.out_file, name => temp_directory & '/' & vector_header_file_name);

		--separate major and minor compiler version and write them in header
		nat_scratch := natural'value(compseq_version(1..3)); -- major number is the three digits before "."
    	seq_io_unsigned_byte.write(vector_file_header,unsigned_8(nat_scratch));
			-- record in list file
			write_listing (item => location, loc => size_of_vector_header);
			write_listing (item => object_code, obj_code => unsigned_8(nat_scratch)); --(natural_to_string(nat_scratch,16,2)));
		size_of_vector_header := size_of_vector_header + 1;
 
		nat_scratch := natural'value(compseq_version(5..7)); -- minor number is the three digits after "."
    	seq_io_unsigned_byte.write(vector_file_header,unsigned_8(nat_scratch));
			-- record in list file
			write_listing (item => object_code, obj_code => unsigned_8(nat_scratch));
			write_listing (item => source_code, src_code => "compiler version " & compseq_version);
		size_of_vector_header := size_of_vector_header + 1;

		-- write vector file format, CS: not supported yet, default is 00h each
		nat_scratch := natural'value(vector_format_version(1..3)); -- major number is the three digits before "."
    	seq_io_unsigned_byte.write(vector_file_header,unsigned_8(nat_scratch)); -- vector file format major number
			-- record in list file
			write_listing (item => location, loc => size_of_vector_header);
			write_listing (item => object_code, obj_code => unsigned_8(nat_scratch));

		nat_scratch := natural'value(vector_format_version(5..7)); -- vector file format minor number
    	seq_io_unsigned_byte.write(vector_file_header,unsigned_8(nat_scratch)); -- vector file format minor number
			-- record in list file
			write_listing (item => object_code, obj_code => unsigned_8(nat_scratch));
			write_listing (item => source_code, src_code => "vector format version " & vector_format_version);
		size_of_vector_header := size_of_vector_header + 2;
 
		--seq_io_unsigned_byte.write(vector_file_header, unsigned_8(summary.scanpath_ct)); -- this writes the number of active scanpaths
		build_active_scanpath_info; -- sets a bit for every active scanpath in active_scanpath_info
		--put_line(standard_output,"active scanpath info: " & unsigned_8'image(active_scanpath_info));
		seq_io_unsigned_byte.write(vector_file_header, active_scanpath_info); -- this writes a byte with a bit set for an active scanpath
			-- record in list file
			write_listing (item => location, loc => size_of_vector_header);
			--write_listing (item => object_code, obj_code => unsigned_8(summary.scanpath_ct));
			write_listing (item => object_code, obj_code => active_scanpath_info);
			--write_listing (item => source_code, src_code => "number of scanpaths");
			write_listing (item => source_code, src_code => "active scanpaths (bit set if active)");
		size_of_vector_header := size_of_vector_header + 1;
	end write_vector_file_header;
	

	procedure unknown_yet is
		b : type_ptr_bscan_ic;

		first_scanpath_address_written : boolean := false; -- this flag is used in procdedure write_base_address
		-- in order to calculate the base address for the first scanpath different from other scanpaths

	 	procedure write_base_address is
		-- writes base address of current scanpath in vector_file_header
			u4byte_scratch	: unsigned_32 := 0;
			ubyte_scratch	: unsigned_8 := 0;
	 	begin
			put_line("writing scanpath base address ...");
			new_line(compile_listing);

			-- calcualate the base address
			if not first_scanpath_address_written then
				-- if this is the first scanpath base address the calculation is as follows:
				size_of_vector_file := destination_address + 5 + size_of_vector_file + (summary.scanpath_ct * 4); -- correct
				first_scanpath_address_written := true;
			else
				-- for all subsequent scanpaths do this calculation
				size_of_vector_file := destination_address + size_of_vector_file;
			end if;

			-- write size_of_vector_file byte per byte in vec_header (lowbyte first)
	 		u4byte_scratch := unsigned_32(size_of_vector_file);

			u4byte_scratch := (shift_left(u4byte_scratch,3*8)); -- clear bits 31..8 by shift left 24 bits
			u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
	 		ubyte_scratch := unsigned_8(u4byte_scratch); -- take lowbyte
			seq_io_unsigned_byte.write(vector_file_header,ubyte_scratch); -- write bits 7..0 in file
				-- record in list file
				write_listing (item => location, loc => size_of_vector_header);
				write_listing (item => object_code, obj_code => unsigned_8(ubyte_scratch));
			size_of_vector_header := size_of_vector_header + 1;

			u4byte_scratch := unsigned_32(size_of_vector_file);
			u4byte_scratch := (shift_left(u4byte_scratch,2*8)); -- clear bits 31..16 by shift left 16 bit
			u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
			ubyte_scratch := unsigned_8(u4byte_scratch);
			seq_io_unsigned_byte.write(vector_file_header,ubyte_scratch); -- write bits 15..8 in file
				-- record in list file
				write_listing (item => object_code, obj_code => unsigned_8(ubyte_scratch));
			size_of_vector_header := size_of_vector_header + 1;

			u4byte_scratch := unsigned_32(size_of_vector_file);
			u4byte_scratch := (shift_left(u4byte_scratch,8)); -- clear bits 31..24 by shift left 8 bit
			u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
	 		ubyte_scratch := unsigned_8(u4byte_scratch);
			seq_io_unsigned_byte.write(vector_file_header,ubyte_scratch); -- write bits 23..16 in file
				-- record in list file
				write_listing (item => object_code, obj_code => unsigned_8(ubyte_scratch));
			size_of_vector_header := size_of_vector_header + 1;

			u4byte_scratch := unsigned_32(size_of_vector_file);
			u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift right by 24 bits
			ubyte_scratch := unsigned_8(u4byte_scratch); -- take highbyte
			seq_io_unsigned_byte.write(vector_file_header,ubyte_scratch); -- write bits 31..24 in file
				-- record in list file
				write_listing (item => object_code, obj_code => unsigned_8(ubyte_scratch));
				write_listing (item => source_code, src_code => "base address scanpath" & positive'image(scanpath_being_compiled) 
					& row_separator_0 & comment & " lowbyte left");
				new_line(compile_listing);
			size_of_vector_header := size_of_vector_header + 1;

		end write_base_address;


		procedure read_sequence(id : positive) is
		-- reads sequence specified by id
			section_entered		: boolean := false;
			section_processed	: boolean := false;  -- indicates if sequence has been found and processed successfully
			line_of_file		: extended_string.bounded_string;
		begin
			prog_position	:= 300;
			put_line(standard_output," - sequence" & positive'image(id) & " ...");
			reset(sequence_file);

			prog_position	:= 310;
			line_counter := 0;
			while not end_of_file
				loop
					line_counter := line_counter + 1; -- count lines in sequence file (global counter !)
					line_of_file := extended_string.to_bounded_string(get_line);
					line_of_file := remove_comment_from_line(line_of_file);

					prog_position	:= 320;
					if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything
						if section_entered then

							-- once inside section "sequence", wait for end of section mark
							prog_position	:= 330;
							if get_field_from_line(line_of_file,1) = section_mark.endsection then -- when endsection found
								section_entered := false; -- reset section entered flag
								section_processed := true;
								-- SECTION "SEQUENCE" READING DONE.
								exit;
							else
								-- PROCESSING SECTION SEQUENCE BEGIN
								prog_position	:= 340;
								compile_command(line_of_file);
								--put_line(standard_output,extended_string.to_string(line_of_file));
								-- PROCESSING SECTION SEQUENCE DONE
							end if;

						else
							-- wait for "section sequence id" begin mark
							prog_position	:= 350;
							if get_field_from_line(line_of_file,1) = section_mark.section then
								if get_field_from_line(line_of_file,2) = test_section.sequence then
									--put_line(standard_output,extended_string.to_string(line_of_file));
									if get_field_count(extended_string.to_string(line_of_file)) = 3 then
										--put_line(standard_output,extended_string.to_string(line_of_file));
										--put_line(standard_output,"-" & get_field_from_line(line_of_file,3) & "-");
										if get_field_from_line(line_of_file,3) = trim(positive'image(id),left) then
											--put_line(standard_output,"test");
											section_entered := true; -- set section enterd "flag"
										end if;
									end if;
								end if;
							end if;
						end if;
					end if;

				end loop;

			if not section_processed then 
				put_line("ERROR: Sequence" & positive'image(id) & " not found !");
				raise constraint_error;
			end if;

		end read_sequence;

		procedure order_img is
			t			: ptr_type_test_step_pre := ptr_test_step_pre;
			sxr_type	: unsigned_8 := 0; -- has a bit set for a particular option

			procedure write_image_in_vector_file(img : type_string_of_bit_characters_class_0; length : positive) is
			-- writes the image (LSB left, pos. 1) in vector file. starts with LSB

				-- create a last_byte that holds only zeroes
				-- left-over bits will overwrite it
				subtype type_b is type_string_of_bit_characters_class_0 (1..8);
				last_byte	: type_b := (others => '0');

				byte	: unsigned_8; -- scratch variable
				i		: positive := 1; -- points to first position of bit-group to process
				w		: constant positive := 8; -- size of a byte

				byte_count		: natural := length/w; -- holds number of full bytes
				remaining_bits	: natural := length rem w; -- holds number of left-over bits
				
			begin -- write_image_in_vector_file
				prog_position := 1100;
				-- if there are full bytes, they are processed first, one by one (point A)
				-- if no full bytes, but an incomplete byte, the left-over bits are proesssed at point B
				--put_line("length, byte count, rem:" & natural'image(length) & natural'image(byte_count) & natural'image(remaining_bits));

				if byte_count > 0 then
					-- A: process all full bytes
					prog_position := 1110;
					for b in 1..byte_count loop
						prog_position := 1120;
						--put_binary_class_0(img(i..i+w-1));
						--put_line("i:" & positive'image(i) & positive'image(i+w-1));
						byte := unsigned_8(to_natural(binary_in => img(i..i+w-1))); -- select bits 1..8 / 9..16 / 17..24 / ...
						write_byte_in_vector_file(byte);
						write_listing(item => object_code, obj_code => byte);  
						listing_address := listing_address + 1;
						i := i + w; -- i=9 / i=17 / i=25
					end loop;

					-- process left over bits (if any)
					if remaining_bits > 0 then
						prog_position := 1130;
						-- i points to first position of left-over bits
						-- the last bit of left-over bits is at position "length"
						--put_line("i:" & positive'image(i) & positive'image(length) & positive'image(img'last));
						last_byte(1..remaining_bits) := img(i..length); -- overwrite positions in last_byte with left-over bits
						write_byte_in_vector_file( unsigned_8(to_natural(last_byte)));
						write_listing(item => object_code, obj_code => unsigned_8(to_natural(last_byte)));  
						listing_address := listing_address + 1;
					end if;
				else
					-- B: an incomplete byte is given
					-- process left-over bits (if any)
					if remaining_bits > 0 then
						prog_position := 1140;
						last_byte(1..remaining_bits) := img(i..length); -- overwrite positions in last_byte with left-over bits
						write_byte_in_vector_file( unsigned_8(to_natural(last_byte)));
						write_listing(item => object_code, obj_code => unsigned_8(to_natural(last_byte))); 
						listing_address := listing_address + 1;
					end if;

				end if;
			end write_image_in_vector_file;

			nv : ptr_type_test_step_pre; -- points to position of next vector
			function get_pos_of_next_vector(cv : ptr_type_test_step_pre) return ptr_type_test_step_pre is
				t	: ptr_type_test_step_pre := ptr_test_step_pre;
				nv	: ptr_type_test_step_pre := ptr_test_step_pre;
			begin
				--put_line(standard_output,"--vector current:" & type_vector_id'image(cv.vector_id));
				for a in 1..vector_count_max loop -- "a" is the number of vectors to look ahead in the step list
												-- in order to find the next drive image
					-- for the start, we look for the closest vector after the one pointed to by "cv"
					-- iteratively, the look-ahead window increases

					t := ptr_test_step_pre;
					while t /= null loop
						-- the next vector must meet following criterions:
						-- check discriminants first
						if t.step_class = cv.step_class -- same class (class_a mostly)
						and t.length_total = cv.length_total -- same length
						then -- check other properties
							if t.scan = cv.scan -- same scan type (sir, sdr)
							and t.scanpath_id = cv.scanpath_id -- same scanpath id
							and t.sequence_id = cv.sequence_id -- same sequence id (CS: crossing sequence boundaries not supported yet)
							then
								if t.vector_id = cv.vector_id + a then -- vector id after given id. (not to confuse with step_id !)

									-- CS: check targeted registers
									-- if the look-ahead window is greater 1, put a warning.
									if t.scan = sdr and a > 1 then
										put_line(standard_output,"WARNING: Look-ahead window for next " & type_scan'image(t.scan) & " drive image is" & positive'image(a) & " steps !");
										put_line(standard_output,"         Vector id current:" & type_vector_id'image(cv.vector_id));
										put_line(standard_output,"         Vector id next   :" & type_vector_id'image(t.vector_id));
										put_line(standard_output,"         Make sure, the targeted registers are the same !");
									end if;
									return t; -- return pointer of next vector
								end if;
							end if;
						end if;
						t := t.next;
					end loop;
				end loop;

				-- search finished but no subsequent vector found
				return t; -- return null
			end get_pos_of_next_vector;

		begin -- order_img
			prog_position := 1000;
			for i in 1..test_step_id loop -- test_step_id contains the total number of test steps in the sequence file
				--put_line(standard_output,"ordering test step" & positive'image(i));

				t := ptr_test_step_pre;
				while t /= null loop
					--put_line(standard_output," sequence id" & positive'image(t.sequence_id));
					--if t.step_id = i and t.sequence_id = sequence_being_compiled then
					if t.step_id = i and t.scanpath_id = scanpath_being_compiled and t.sequence_id = sequence_being_compiled then
						--put_line(standard_output," post processing step id" & positive'image(i));

						case t.step_class is
							when class_a =>

								-- vector format is:  
								-- 16 bit ID , 8 bit SIR/SDR marker, (retries, retry_delay) , 8 bit scan path number, 32 bit vector length , drv data, mask data, exp data

								-- WRITE VECTOR ID (16 bit)
								write_word_in_vector_file(unsigned_16(t.vector_id));
								write_listing(item => location, loc => listing_address);
								write_listing(item => object_code, obj_code => get_byte_from_word(unsigned_16(t.vector_id),0) ); -- lowbyte
								write_listing(item => object_code, obj_code => get_byte_from_word(unsigned_16(t.vector_id),1) ); -- highbyte
								write_listing(item => separator);
								--write_listing(item => source_code, src_code => "dummy");
								listing_address := listing_address + 2; -- prepare next location to be written in listing

								-- WRITE SXR MARKER (8 bit) --
								-- bit meaning:
								-- 7 (MSB) : 1 -> sir, 0 -> sdr
								-- 6       : 1 -> end state RTI, 0 -> end state Pause-XR
								-- 5       : 1 -> on fail: hstrst
								-- 4       : 1 -> on fail: power down (priority in executor)
								-- 3       : 1 -> on fail: finish sxr (CS: not implemented yet)
								-- 2       : 1 -> retry on, 0 -> retry off
								-- 1:0     : not used yet
								sxr_type := 0; -- clear sxr_type from previous loop
								case t.scan is
									when sir =>
										sxr_type := set_clear_bit_unsigned_8(sxr_type,7,true); -- bit 7 set indicates sir
										case test_info.end_sir is
											when RTI => sxr_type := set_clear_bit_unsigned_8(sxr_type,6,true);  -- bit 6 set -> end state RTI
											when PIR => sxr_type := set_clear_bit_unsigned_8(sxr_type,6,false); -- bit 6 cleared -> end state pause-xr
										end case;
									when sdr =>
										sxr_type := set_clear_bit_unsigned_8(sxr_type,7,false); -- bit 7 cleard indicates sdr
										case test_info.end_sdr is
											when RTI => sxr_type := set_clear_bit_unsigned_8(sxr_type,6,true);  -- bit 6 set -> end state RTI
											when PDR => sxr_type := set_clear_bit_unsigned_8(sxr_type,6,false); -- bit 6 cleared -> end state pause-xr
										end case;
								end case;

								case scanpath_options.on_fail is
									when HSTRST => 
										sxr_type := set_clear_bit_unsigned_8(sxr_type,5,true); -- bit 5 set indicates: hstrst on fail
									when POWER_DOWN =>
										sxr_type := set_clear_bit_unsigned_8(sxr_type,4,true); -- bit 4 set indicates: power down on fail
		-- 							when FINISH_TEST =>
		-- 								put_line("ERROR: " & type_on_fail_action'image(scanpath_options.on_fail) & 
								end case;

								case t.retry_count is
									when 0 => 
										write_byte_in_vector_file(sxr_type);
										write_listing(item => object_code, obj_code => sxr_type);
										listing_address := listing_address + 1;
									when others => 
										sxr_type := set_clear_bit_unsigned_8(sxr_type,2,true); -- bit 2 set indicates retry type
										write_byte_in_vector_file(sxr_type);
										write_listing(item => object_code, obj_code => sxr_type);
										write_byte_in_vector_file(t.retry_count);
										write_listing(item => object_code, obj_code => t.retry_count);
										write_byte_in_vector_file(t.retry_delay);
										write_listing(item => object_code, obj_code => t.retry_delay);
										listing_address := listing_address + 3;
								end case;
								write_listing(item => separator);

								-- WRITE SCANPATH ID (8 bit) -- CS: ignored ?
								write_byte_in_vector_file(unsigned_8(scanpath_being_compiled));
								write_listing(item => object_code, obj_code => unsigned_8(scanpath_being_compiled));
								listing_address := listing_address + 1;
								write_listing(item => separator);

								-- WRITE SXR LENGTH (32 bit)
								write_double_word_in_vector_file(unsigned_32(t.length_total));
								write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),0));
								write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),1)); 
								write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),2)); 
								write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),3));  
								listing_address := listing_address + 4;
								write_listing(item => separator);

								case t.scan is
									when sir =>
										--put("sir ");
										case test_info.end_sir is
											when RTI => -- in this mode, no re-ordering is required
-- 												-- WRITE SXR LENGTH (32 bit)
-- 												write_double_word_in_vector_file(unsigned_32(t.length_total));
-- 												write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),0));
-- 												write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),1)); 
-- 												write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),2)); 
-- 												write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),3));  
-- 												listing_address := listing_address + 4;
-- 												write_listing(item => separator);

												-- WRITE IMAGES
												write_image_in_vector_file(t.img_drive,		t.length_total);
												write_listing(item => separator);
												write_image_in_vector_file(t.img_mask,		t.length_total);
												write_listing(item => separator);
												write_image_in_vector_file(t.img_expect,	t.length_total);
											when PIR =>
												nv := get_pos_of_next_vector(t);  -- nv points to position of next vector
												if nv /= null then -- means if next vector available, write drive image of that vector
													write_image_in_vector_file(nv.img_drive,	nv.length_total);
												else -- otherwise use drive image of current vector. CS: what else ?
													write_image_in_vector_file(t.img_drive,	t.length_total);
												end if;
												write_listing(item => separator);
												write_image_in_vector_file(t.img_mask,		t.length_total);
												write_listing(item => separator);
												write_image_in_vector_file(t.img_expect,	t.length_total);
										end case;
									when sdr =>
										--put("sdr ");
										case test_info.end_sdr is
											when RTI => -- in this mode, no re-ordering is required
												-- WRITE SXR LENGTH (32 bit)
-- 												write_double_word_in_vector_file(unsigned_32(t.length_total));
-- 												write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),0));
-- 												write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),1)); 
-- 												write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),2)); 
-- 												write_listing(item => object_code, obj_code => get_byte_from_doubleword(unsigned_32(t.length_total),3));  
-- 												listing_address := listing_address + 4;
-- 												write_listing(item => separator);

												write_image_in_vector_file(t.img_drive,		t.length_total);
												write_listing(item => separator);
												write_image_in_vector_file(t.img_mask,		t.length_total);
												write_listing(item => separator);
												write_image_in_vector_file(t.img_expect,	t.length_total);
											when PDR =>
												nv := get_pos_of_next_vector(t);  -- nv points to position of next vector
												if nv /= null then -- means if next vector available, write drive image of that vector
													write_image_in_vector_file(nv.img_drive,	nv.length_total);
												else -- otherwise use drive image of current vector. CS: what else ?
													write_image_in_vector_file(t.img_drive,	t.length_total);
												end if;
												write_listing(item => separator);
												write_image_in_vector_file(t.img_mask,		t.length_total);
												write_listing(item => separator);
												write_image_in_vector_file(t.img_expect,	t.length_total);
										end case;
								end case;
								write_listing(item => source_code, src_code => universal_string_type.to_string(t.source) 
									& row_separator_0 & comment & " lowbyte left: sxr_id | sxr_type | scanpath | length | drv | mask | exp");

							when class_b =>

								-- WRITE LOW LEVEL COMMAND
								write_listing(item => location, loc => listing_address);
								for b in 1..t.length_total loop
									write_byte_in_vector_file(t.command.binary(b));	
									write_listing(item => object_code, obj_code => t.command.binary(b));
								end loop;
								write_listing(item => source_code, src_code => universal_string_type.to_string(t.command.source));
								listing_address := listing_address + t.length_total; -- prepare next location to be written in listing

						end case;
					end if;
					t := t.next;
				end loop;

			end loop;
		end order_img;


	begin -- unknown_yet
		--	set_output(standard_output);
		put_line("found" & natural'image(summary.scanpath_ct) & " scan paths(s) ...");

		prog_position	:= 210;
		for sp in 1..scanport_count_max loop -- loop for every physical available scanport (regardless if it is active or not)
			-- sp points to scanport

			-- delete all stale register files
			prog_position	:= 220;
			if exists(universal_string_type.to_string(test_name) 
				& "/" & universal_string_type.to_string(test_name) & "_" & trim(positive'image(sp),left) & ".reg") then 
					delete_file(universal_string_type.to_string(test_name) & "/" 
					& universal_string_type.to_string(test_name) & "_" & trim(positive'image(sp),left) & ".reg"); 
			end if;

			-- process active scanpaths only
			prog_position	:= 230;
 			if is_scanport_active(sp) then
				put_line("compiling scanpath" & natural'image(sp));
				scanpath_being_compiled := sp; -- set global variable scanpath_being_compiled to active scanport (pointed to by sp)
				--put_line("active" & natural'image(sp) );

				-- CREATE REGISTER FILE (members_x.reg)
				-- write something like: "device 1 IC301 irl 8 bsl 108" in the reg file
				prog_position	:= 240;
 				create( 
					file => scanport(sp).register_file,
					--name => (universal_string_type.to_string(test_name) & "/members_" & trim(natural'image(sp), side => left) & ".reg")
					name => (universal_string_type.to_string(test_name) & "/" & register_file_prefix & trim(natural'image(sp), side => left) & register_file_suffix)
					);
 
				-- search for bic in the scanpath being processed
				prog_position	:= 250;
				for p in 1..summary.bic_ct loop -- loop here for as much as bics are present. 
				-- position search starts with position 1, that is the device closes to BSC TDO (first in subsection chain x)
					b := ptr_bic; -- set bic pointer at end of bic list
					while b /= null loop
						if b.chain = sp then -- on match of scanpath id
							if b.position = p then -- on match of position 
								-- write in register file something like "device 1 IC301 irl 8 bsl 108" in the reg file"
								put_line(scanport(sp).register_file,"device" & natural'image(p)
									& row_separator_0 & universal_string_type.to_string(b.name)
									& row_separator_0 & "irl" & positive'image(b.len_ir)
									& row_separator_0 & "bsl" & positive'image(b.len_bsr)
									);

								-- sum up irl of chain members of that scanpath
								-- CS: assumption is that no device is bypassed or added/inserted in the chain later
								--scanport(sp).irl_total := scanport(sp).irl_total + b.len_ir + trailer_length ;
								scanport(sp).irl_total := scanport(sp).irl_total + b.len_ir;
							end if;
						end if;
						b := b.next;
					end loop;
				end loop;
				-- add trailer length to obtain the total sir length
				scanport(sp).irl_total := scanport(sp).irl_total + trailer_length;

				-- WRITE BASE ADDRESS OF CURRENT SCANPATH
				prog_position	:= 260;
				write_base_address;

				-- PROCESS SEQUENCES one by one
				for s in 1..sequence_count loop
				prog_position	:= 270;
					sequence_being_compiled := s; -- set global variable sequence_being_compiled
					read_sequence(s);

					-- ORDER DRV/EXP IMAGES AS SPECIFIED IN OPTION END_SDR/SIR
					order_img;
				end loop;


				-- CLOSE REGISER FILE
				prog_position	:= 280;
				close ( scanport(sp).register_file);
 			end if;

		end loop;

	end unknown_yet;



-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin

	create_temp_directory;

	prog_position	:= 10;
 	data_base:= universal_string_type.to_bounded_string(Argument(1));
 	put_line ("data base      : " & universal_string_type.to_string(data_base));
 
	prog_position	:= 20;
 	test_name:= universal_string_type.to_bounded_string(Argument(2));
 	put_line ("test name      : " & universal_string_type.to_string(test_name));

	-- create list file
	prog_position	:= 25;
	create(
		file	=> compile_listing,
		mode	=> out_file, 
		name 	=> universal_string_type.to_string(test_name) & "/" & universal_string_type.to_string(test_name) & ".lis"
		);
	write_listing_header;

	-- create vectorfile
	prog_position	:= 30;
	seq_io_unsigned_byte.create(
		file	=> vector_file, 
		mode	=> seq_io_unsigned_byte.out_file, 
		name 	=> universal_string_type.to_string(test_name) & "/" & universal_string_type.to_string(test_name) & ".vec"
		);
	--size_of_vec_file := natural'value(
	--	file_size'image(size(universal_string_type.to_string(test_name) & "/" & universal_string_type.to_string(test_name) & ".vec"))
	--	);
	--put (size_of_vec_file);

	prog_position	:= 40;
	read_data_base;

	-- read journal
	prog_position	:= 50;
	destination_address := get_destination_address_from_journal;
	--put_line(natural'image(destination_address));

	prog_position	:= 60;
	open(
		file	=> sequence_file,
		mode	=> in_file,
		name	=> universal_string_type.to_string(test_name) & "/" & universal_string_type.to_string(test_name) & ".seq"
		);
	set_input(sequence_file);

	prog_position	:= 70;
	put_line("reading sequence file ...");
	test_info := get_test_info;
	prog_position	:= 80;
	scanpath_options := get_scanpath_options;
	prog_position	:= 90;
	sequence_count := count_sequences;
	if sequence_count > sequence_count_max then
		put_line("ERROR: Currently maximal" & positive'image(sequence_count_max) & " sequences supported !");
		raise constraint_error;
	end if;

	prog_position	:= 100;
	write_vector_file_header;

	-- WRITE GLOBAL CONFIGURATION IN VEC FILE
	listing_offset := size_of_vector_header + summary.scanpath_ct * 4;

	-- frequency
	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(scanpath_options.frequency_prescaler_unsigned_8);
	write_listing(item => object_code, obj_code => scanpath_options.frequency_prescaler_unsigned_8);
	write_listing(item => source_code, src_code => "scan clock timer (high nibble -> multipier, low nibble -> exponent)");

	-- threshold
	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(scanpath_options.threshold_tdi_port_1_unsigned_8);
	write_listing(item => object_code, obj_code => scanpath_options.threshold_tdi_port_1_unsigned_8);
	write_listing(item => source_code, src_code => section_scanpath_options_item.threshold_tdi_port_1);

	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(scanpath_options.threshold_tdi_port_2_unsigned_8);
	write_listing(item => object_code, obj_code => scanpath_options.threshold_tdi_port_2_unsigned_8);
	write_listing(item => source_code, src_code => section_scanpath_options_item.threshold_tdi_port_2);

	-- output voltage
	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(scanpath_options.voltage_out_port_1_unsigned_8);
	write_listing(item => object_code, obj_code => scanpath_options.voltage_out_port_1_unsigned_8);
	write_listing(item => source_code, src_code => section_scanpath_options_item.voltage_out_port_1);

	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(scanpath_options.voltage_out_port_2_unsigned_8);
	write_listing(item => object_code, obj_code => scanpath_options.voltage_out_port_2_unsigned_8);
	write_listing(item => source_code, src_code => section_scanpath_options_item.voltage_out_port_2);

	-- port 1: sum up drv characteristics of tms (bit 6..3) and tck (bit 2..0) to a single byte
	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(scanpath_options.tms_driver_port_1_unsigned_8 + scanpath_options.tck_driver_port_1_unsigned_8);
	write_listing(item => object_code, obj_code => scanpath_options.tms_driver_port_1_unsigned_8 + scanpath_options.tck_driver_port_1_unsigned_8);
	write_listing(item => source_code, src_code => 
		section_scanpath_options_item.tms_driver_port_1 & " bit [6..3] " & section_scanpath_options_item.tck_driver_port_1
		& " bit [2..0]"
		);

	-- port 1: sum up drv characteristics of trst (bit 6..3) and tdo (bit 2..0) to a single byte
	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(scanpath_options.trst_driver_port_1_unsigned_8 + scanpath_options.tdo_driver_port_1_unsigned_8);
	write_listing(item => object_code, obj_code => scanpath_options.trst_driver_port_1_unsigned_8 + scanpath_options.tdo_driver_port_1_unsigned_8);
	write_listing(item => source_code, src_code => 
		section_scanpath_options_item.trst_driver_port_1 & " bit [6..3] " & section_scanpath_options_item.tdo_driver_port_1
		& " bit [2..0]"
		);

	-- port 2: sum up drv characteristics of tck an tms to a single byte
	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(scanpath_options.tms_driver_port_2_unsigned_8 + scanpath_options.tck_driver_port_2_unsigned_8);
	write_listing(item => object_code, obj_code => scanpath_options.tms_driver_port_2_unsigned_8 + scanpath_options.tck_driver_port_2_unsigned_8);
	write_listing(item => source_code, src_code => 
		section_scanpath_options_item.tms_driver_port_2 & " bit [6..3] " & section_scanpath_options_item.tck_driver_port_2
		& " bit [2..0]"
		);

	-- port 2: sum up drv characteristics of tdo an trst to a single byte
	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(scanpath_options.tdo_driver_port_2_unsigned_8 + scanpath_options.trst_driver_port_2_unsigned_8);
	write_listing(item => object_code, obj_code => scanpath_options.trst_driver_port_2_unsigned_8 + scanpath_options.tdo_driver_port_2_unsigned_8);
	write_listing(item => source_code, src_code => 
		section_scanpath_options_item.trst_driver_port_2 & " bit [6..3] " & section_scanpath_options_item.tdo_driver_port_2
		& " bit [2..0]"
		);

	-- NOTE 1:
	-- since the total number of test steps (incl. low level commands) is not known yet, it is assumed as FFFFh
	-- later when finishing compiling, it will be replaced by the real number of steps found in the source code
	-- !! CURRENTLY THE TOTAL NUMBER OF STEPS IS NOT WRITTEN IN THE LISTING !! -- CS
	-- CAUTION: THIS IS A HACK AND NEEDS PROPER REWORK !!! -- CS
	-- step count, lowbyte
	write_listing(item => location, loc => size_of_vector_file + listing_offset);
	write_byte_in_vector_file(16#FF#);
	write_listing(item => object_code, obj_code => 16#FF#);
	write_listing(item => source_code, src_code => "step count (lowbyte) NOTE: currently invalid here -> see *.vec file instead !");
	-- step count, higbyte
	write_listing(item => location, loc => size_of_vector_file + listing_offset);
   	write_byte_in_vector_file(16#FF#); 
	write_listing(item => object_code, obj_code => 16#FF#);
	write_listing(item => source_code, src_code => "step count (highbyte) NOTE: currently invalid here -> see *.vec file instead !");

	-- listing_address will be used further-on for writing locations in listing file
	listing_address := size_of_vector_file + listing_offset;
 	--seq_io_unsigned_byte.close(vector_file);
 	-- options writing done

	prog_position	:= 200;
	unknown_yet;
 

	-- write test end marker in vector file
	prog_position	:= 2000;
 	write_word_in_vector_file(id_configuration);
	write_listing(item => location, loc => listing_address);
	write_listing(item => object_code, obj_code => get_byte_from_word(id_configuration,0)); -- id lowbyte
	write_listing(item => object_code, obj_code => get_byte_from_word(id_configuration,1)); -- id highbyte

 	write_byte_in_vector_file(mark_end_of_test);
	write_listing(item => object_code, obj_code => mark_end_of_test);
	write_listing(item => source_code, src_code => "end of test");
--	listing_address := listing_address + 3; -- prepare next location to be written in listing

--  write_byte_in_vector_file(16#02#);	-- 02h indicates virtual begin of chain 2 data -- CS: ?
-- 	write_listing(item => location, loc => listing_address);
-- 	write_listing(item => object_code, obj_code => 16#02#);
-- 	write_listing(item => source_code, src_code => "dummy");
	
	-- close list file
	close(compile_listing);


	-- append vector file to header file byte per byte
	-- later the header is renamed to the actual vector file (*.vec)
	-- CAUTION: THIS IS A HACK AND NEEDS PROPER REWORK !!! -- CS
	prog_position	:= 2010;
	seq_io_unsigned_byte.reset(
		file 	=> vector_file,
		mode	=> seq_io_unsigned_byte.in_file);
	prog_position	:= 2020;
	--put_line("size of vec file:" & natural'image(size_of_vector_file));
	--put_line("size of vec head:" & natural'image(size_of_vector_header));

	-- the total number of test steps (inc. low level commands) is test_step_id divided by scanpath_ct.
	-- why ?: test_step_id is incremented on every test step per scanpath. since all scanpaths have equal test step counts
	-- it must be divided by scanpath_ct to obtain the real number of steps.
	put_line("test steps total:" & positive'image(test_step_id/summary.scanpath_ct) & " (incl. low level commands)");
 	while not seq_io_unsigned_byte.end_of_file(vector_file) loop

		-- read byte from vector file
 		seq_io_unsigned_byte.read(vector_file,ubyte_scratch);

		-- as said in NOTE 1, the bytes 10 and 11 of the vector file are now replaced by the step count
		-- CAUTION: THIS IS A HACK AND NEEDS PROPER REWORK !!! -- CS
		-- ct_tmp (starts with 1) serves as pointer to the byte position to be modified
		case ct_tmp is
			when 10 => ubyte_scratch := unsigned_8(test_step_id/summary.scanpath_ct); -- write lowbyte of step count
			when 11 => ubyte_scratch := unsigned_8(shift_right(unsigned_16(test_step_id/summary.scanpath_ct),8)); -- write highbyte of step count
			when others => null; -- other bytes untouched
		end case;
		ct_tmp := ct_tmp + 1;

		-- write byte in vector file header
		seq_io_unsigned_byte.write(vector_file_header,ubyte_scratch);
		size_of_vector_header := size_of_vector_header + 1;
 	end loop;
	prog_position	:= 2030;
 	seq_io_unsigned_byte.close(vector_file);
	seq_io_unsigned_byte.close(vector_file_header);

	-- make final vector file in test directory (overwrite old vector file by the final one)
	-- CAUTION: THIS IS A HACK AND NEEDS PROPER REWORK !!! -- CS
	prog_position	:= 2040;
	copy_file(
		temp_directory & '/' & vector_header_file_name, -- from here
		universal_string_type.to_string(test_name) & "/" & universal_string_type.to_string(test_name) & ".vec"); -- to here
 

	-- size_of_vector_header now contains the total size of the vector file 
	prog_position := 2050;
	size_of_vector_file := size_of_vector_header;
	-- do a cross checking of the file size: it must match the size returned by function "size"
	if size_of_vector_file = natural(
		size(universal_string_type.to_string(test_name) & "/" & universal_string_type.to_string(test_name) & ".vec")
		) then null;
	else
		put_line("ERROR: Vector file size error !");
		raise constraint_error;
	end if;

    -- write journal 
	prog_position := 2060;
	write_journal;


	exception
		when event: others =>
			set_exit_status(failure);

			set_output(standard_output);
			case prog_position is
				when 0 => null;
				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("error in sequence file in line :" & natural'image(line_counter));
					put_line("program error at position " & natural'image(prog_position));
			end case;

end compseq;
