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
-- bugfix: at prog_position BY2 and BY6 changed expected register assignment for bypass to 0=1 and 0=0
-- at prog_position MA1 EX1 added 'X' to don't care bit case
-- added letter X to bit_char 

with Ada.Text_IO;			use Ada.Text_IO;
with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
with Ada.Float_Text_IO;		use Ada.Float_Text_IO;
with Ada.Characters; 		use Ada.Characters;
with Ada.Characters.Handling; 		use Ada.Characters.Handling;
with ada.characters.conversions;	use ada.characters.conversions;

with m1; --use m1;
with m1_internal; use m1_internal;

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
 
with Ada.Calendar;				use Ada.Calendar;
with Ada.Calendar.Formatting;	use Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;	use Ada.Calendar.Time_Zones;

procedure compseq is

	compseq_version	: string (1..7) := "005.000";
	prog_position 	: natural := 0;

--	vector_file_head: seq_io_unsigned_byte.file_type;
	journal			: string (1..17) := "setup/journal.txt";
	file_journal	: ada.text_io.file_type;

	size_of_vector_file		: natural := 0;

	mem_size				: natural := integer'Value("16#0FFFFF#"); -- BSC RAM size
	destination_address		: natural;

	line_counter			: natural := 0; -- line counter in sequence file (global counter !)

	test_info				: type_test_info;
	scanpath_options		: type_scanpath_options;

	sequence_count			: positive := 1;
	scanpath_being_compiled	: positive;	-- points to the scanpath being compiled

	vector_id				: positive;

		-- GLOBAL ARRAY THAT DESCRIBES ALL PHYICAL AVAILABLE SCANPATHS
		-- non-active scanpaths have an irl_total of zero
		-- irl_total is the sum of all instuction registers in that scanpath
		-- irl_total is computed when creating register files
		type type_single_chain is
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
		type type_all_chains is array (natural range 1..scanport_count_max) of type_single_chain;
		chain	: type_all_chains;

------------------------------------------
	
-- 	type unsigned_3 is mod 8;
-- 	bit_pt	: unsigned_3 := 0;


-- 	
-- 	vector_length_max	: constant natural := 5000;
-- 	subtype type_vector_length is natural range 1..vector_length_max;
-- 
-- 	unb_scratch		: unbounded_string;
-- 	int_scratch		: integer := 0;
-- 	nat_scratch		: natural := 0;
-- 	nat_scratch2	: natural := 0;

-- 	retry_ct_max	: natural := 100;
-- 	retry_delay_max	: float := 25.5; -- sec.
-- 	subtype type_retries is natural range 0..retry_ct_max;
-- 	subtype type_retry_delay is float range 0.0..retry_delay_max;
-- 	retries		: type_retries;
-- 	retry_delay : type_retry_delay;
-- 
-- 
-- 
-- 	type type_single_member is
-- 		record
-- 			device	: unbounded_string;
-- 			irl		: natural;
-- 			bsl		: natural;
-- 			ir_drv	: unbounded_string;		-- holds opcode of latest instruction loaded
-- 			instruction	: unbounded_string; -- holds name of latest instruction loaded
-- 
-- 			byp_drv	: character;
-- 			bsr_drv	: unbounded_string;
-- 			idc_drv	: unbounded_string;
-- 			usc_drv	: unbounded_string;
-- 
-- 			byp_exp	: character;
-- 			bsr_exp	: unbounded_string;
-- 			idc_exp	: unbounded_string;
-- 			usc_exp	: unbounded_string;
-- 
-- 			ir_exp	: unbounded_string;
-- --			dr_drv	: unbounded_string;
-- 		end record;
-- 
-- 	max_member_ct_per_chain	: constant natural := 100;
-- 	type type_all_members_of_a_single_chain is array (natural range 1..max_member_ct_per_chain) of type_single_member;


	procedure write_in_vector_file (byte : unsigned_8) is
	-- writes a given byte into vector_file
	-- counts bytes and updates size_of_vector_file
	begin
		seq_io_unsigned_byte.write(vector_file, byte);
		size_of_vector_file := size_of_vector_file + 1;
	end write_in_vector_file;



	procedure write_llc
	-- writes a low level command
		(
		llct	:	unsigned_8; -- low level command type
		llcc	:	unsigned_8  -- low level command itself
		) is
	begin
		-- write ID -- a conf. word has ID 0000h
		write_in_vector_file(16#00#);
		write_in_vector_file(16#00#);

		--write low level command type
		write_in_vector_file(llct);

		-- write chain pt
		-- write chain number in vec file. CS: chain number is ignored by executor
 		write_in_vector_file(16#00#); 

		-- write low level command itself
 		write_in_vector_file(llcc); 
	end write_llc;


-- 	procedure write_word_in_vec_file
-- 		(
-- 		word	: unsigned_16
-- 		) is
-- 		ubyte_scratch  : unsigned_8;
-- 		u2byte_scratch : unsigned_16;
-- 	begin
-- 		-- lowbyte first
-- 		u2byte_scratch := word;
--  		u2byte_scratch := (shift_left(u2byte_scratch,8)); -- clear bits 15..8 by shift left 8 bit
--  		u2byte_scratch := (shift_right(u2byte_scratch,8)); -- shift back by 8 bits
-- 		ubyte_scratch := unsigned_8(u2byte_scratch); -- take lowbyte
-- 		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch); -- write lowbyte in file
-- 
-- 		-- highbyte
-- 		u2byte_scratch := word;
--  		u2byte_scratch := (shift_right(u2byte_scratch,8)); -- shift right by 8 bits
-- 		ubyte_scratch := unsigned_8(u2byte_scratch); -- take highbyte
-- 		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch); -- write highbyte in file
-- 	end write_word_in_vec_file;
-- 
-- 
-- 	procedure write_double_word_in_vec_file
-- 		(
-- 		dword	: unsigned_32
-- 		) is
-- 		ubyte_scratch  : unsigned_8;
-- 		u4byte_scratch : unsigned_32;
-- 	begin
-- 		-- lowbyte first
-- 		u4byte_scratch := dword;
--  		u4byte_scratch := (shift_left(u4byte_scratch,3*8)); -- clear bits 31..8 by shift left 24 bit
--  		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
-- 		ubyte_scratch := unsigned_8(u4byte_scratch); -- take lowbyte
-- 		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch); -- write lowbyte in file
-- 
-- 		u4byte_scratch := dword;
--  		u4byte_scratch := (shift_left(u4byte_scratch,2*8)); -- clear bits 31..16 by shift left 16 bit
--  		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
-- 		ubyte_scratch := unsigned_8(u4byte_scratch);
-- 		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch);
-- 
-- 		u4byte_scratch := dword;
--  		u4byte_scratch := (shift_left(u4byte_scratch,1*8)); -- clear bits 31..24 by shift left 8 bit
--  		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
-- 		ubyte_scratch := unsigned_8(u4byte_scratch);
-- 		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch);
-- 
-- 		-- highbyte
-- 		u4byte_scratch := dword;
--  		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift right by 8 bits
-- 		ubyte_scratch := unsigned_8(u4byte_scratch); -- take lowbyte
-- 		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch); -- write highbyte in file
-- 	end write_double_word_in_vec_file;
-- 
-- 
-- 	procedure make_binary_vector
-- 		(
-- 		sir_sdr	: string; -- "sir"
-- 		drv_exp	: string; -- "drv"
-- 		id 		: vector_id_type := 1; -- required for drive vector only
-- 		vector_string 	: unbounded_string; -- vector as string like 00xx11101x
-- 		retries			: unsigned_8 := 0; -- required for dirve vector only
-- 		retry_delay 	: unsigned_8 := 0  -- required for dirve vector only
-- 		) is
-- 		vector_length : type_vector_length := length(vector_string);
-- 
-- 	begin
-- 		-- vector format is:  
-- 		-- 16 bit ID , 8 bit SIR/SDR marker, (retries, retry_delay) , 8 bit scan path number, 32 bit vector length , drv data, mask data, exp data
-- 		put(".");
-- 
-- 		-- build drive vector
-- 		if drv_exp = "drv" then
-- 			write_word_in_vec_file(unsigned_16(id)); -- write vector id in vector file
-- 
-- 			-- write sdr/sir marker in vec file
-- 			if on_fail = "hstrst" then 
-- 				if sir_sdr = "sdr" then
-- 					if retries = 0 then seq_io_unsigned_byte.write(vectorfile,16#01#); end if; -- standard sdr
-- 					if retries > 0 then 
-- 						seq_io_unsigned_byte.write(vectorfile,16#05#);
-- 						seq_io_unsigned_byte.write(vectorfile,retries); 
-- 						seq_io_unsigned_byte.write(vectorfile,retry_delay);  
-- 					end if; -- sdr with retry option
-- 				end if;
-- 
-- 				if sir_sdr = "sir" then
-- 					if retries = 0 then seq_io_unsigned_byte.write(vectorfile,16#02#); end if; -- standard sir
-- 					if retries > 0 then 
-- 						seq_io_unsigned_byte.write(vectorfile,16#06#);
-- 						seq_io_unsigned_byte.write(vectorfile,retries); 
-- 						seq_io_unsigned_byte.write(vectorfile,retry_delay);  
-- 					end if; -- sdr with retry option
-- 				end if;
-- 
-- 			elsif on_fail = "power_down" then
-- 				if sir_sdr = "sdr" then
-- 					if retries = 0 then seq_io_unsigned_byte.write(vectorfile,16#03#); end if; -- standard sdr
-- 					if retries > 0 then 
-- 						seq_io_unsigned_byte.write(vectorfile,16#07#);
-- 						seq_io_unsigned_byte.write(vectorfile,retries); 
-- 						seq_io_unsigned_byte.write(vectorfile,retry_delay);  
-- 					end if; -- sdr with retry option
-- 				end if;
-- 
-- 				if sir_sdr = "sir" then
-- 					if retries = 0 then seq_io_unsigned_byte.write(vectorfile,16#04#); end if; -- standard sir
-- 					if retries > 0 then 
-- 						seq_io_unsigned_byte.write(vectorfile,16#08#);
-- 						seq_io_unsigned_byte.write(vectorfile,retries); 
-- 						seq_io_unsigned_byte.write(vectorfile,retry_delay);  
-- 					end if; -- sdr with retry option
-- 				end if;
-- 			end if;
-- 
-- 			-- write chain id in vector file
-- 			seq_io_unsigned_byte.write(vectorfile,unsigned_8(chain_pt)); 
-- 
-- 			-- write vector length in vector file
-- 			u4byte_scratch := unsigned_32(vector_length);
-- 			write_double_word_in_vec_file(u4byte_scratch);
-- 
-- 			-- write vector_string LSB first
-- 			nat_scratch := vector_length;
-- 			bit_pt := 0; -- bit pointer
-- 			byte_scratch := 16#FF#; -- set all bits in byte to write (default)
-- 			while nat_scratch > 0
-- 				loop
-- 					char_scratch := element(vector_string,nat_scratch);
-- 					case char_scratch is
-- 						-- clear bit position
-- 						when '0' | 'x' | 'X' =>	byte_scratch := (16#7F# and byte_scratch); -- replace x,X by 0
-- 						-- set bit position
-- 						when '1' =>				byte_scratch := (16#80# or  byte_scratch);
-- 
-- 						when others => 	prog_position := "DR1"; raise constraint_error;
-- 					end case;
-- 					
-- 					-- skip shift_right on last bit
-- 					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
-- 					bit_pt := bit_pt + 1; -- go to next bit
-- 			
-- 					-- check if byte complete
-- 					if bit_pt = 0 then
-- 						write_byte_in_vec_file(byte_scratch);
-- 						byte_scratch := 16#FF#; -- set all bits in byte to write (default)
-- 					end if;
-- 					nat_scratch := nat_scratch - 1;
-- 				end loop;
-- 
-- 			-- if all bits of vector_string processed but byte incomplete, fill remaining bits with 0
-- 			while bit_pt /= 0
-- 				loop
-- 					byte_scratch := (16#7F# and byte_scratch); -- write 0
-- 
-- 					-- skip shift_right on last bit
-- 					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
-- 					bit_pt := bit_pt + 1; -- go to next bit
-- 
-- 					-- check if byte complete
-- 					if bit_pt = 0 then
-- 						write_byte_in_vec_file(byte_scratch);
-- 					end if;
-- 				end loop;
-- 
-- 		end if; -- build drive vector
-- 
-- 
-- 		-- build mask and expect vector
-- 		if drv_exp = "exp" then
-- 
-- 			-- mask vector
-- 			-- write vector_string LSB first
-- 			nat_scratch := vector_length;
-- 			bit_pt := 0; -- bit pointer
-- 			byte_scratch := 16#00#; -- clear all bits in byte to write (default)
-- 			while nat_scratch > 0
-- 				loop
-- 					char_scratch := element(vector_string,nat_scratch);
-- 					case char_scratch is
-- 						-- set bit position where to expect something
-- 						when '0' | '1' =>	byte_scratch := (16#80# or  byte_scratch); -- replace 1,0 by 1
-- 						-- clear bit position where a "don't care" is
-- 						when 'x' | 'X' =>	byte_scratch := (16#7F# and byte_scratch); -- replace x by 0
-- 
-- 						when others => 	prog_position := "MA1"; raise constraint_error;
-- 					end case;
-- 
-- 					-- skip shift_right on last bit
-- 					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
-- 					bit_pt := bit_pt + 1; -- go to next bit
-- 			
-- 					-- check if byte complete
-- 					if bit_pt = 0 then
-- 						write_byte_in_vec_file(byte_scratch);
-- 						byte_scratch := 16#00#; -- clear all bits in byte to write (default)
-- 					end if;
-- 					nat_scratch := nat_scratch - 1;
-- 				end loop;
-- 
-- 			-- if all bits of vector_string processed but byte still incomplete, fill remaining bits with 0
-- 			while bit_pt /= 0
-- 				loop
-- 					byte_scratch := (16#7F# and byte_scratch); -- write 0
-- 					-- skip shift_right on last bit
-- 					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
-- 					bit_pt := bit_pt + 1; -- go to next bit
-- 
-- 					-- check if byte complete
-- 					if bit_pt = 0 then
-- 						write_byte_in_vec_file(byte_scratch);
-- 					end if;
-- 				end loop;
-- 			-- mask vector done
-- 		
-- 
-- 			-- expect vector
-- 			-- write vector_string LSB first
-- 			nat_scratch := vector_length;
-- 			bit_pt := 0; -- bit pointer
-- 			byte_scratch := 16#00#; -- clear all bits in byte to write (default)
-- 			while nat_scratch > 0
-- 				loop
-- 					char_scratch := element(vector_string,nat_scratch);
-- 					case char_scratch is
-- 						-- set bit position where to expect 1
-- 						when '1' =>			byte_scratch := (16#80# or  byte_scratch); -- write 1
-- 						-- clear bit position where to expect 0 or where a don't care is
-- 						when '0' | 'x' | 'X' => byte_scratch := (16#7F# and byte_scratch); -- write 0, replace x by 0
-- 
-- 						when others => 	prog_position := "EX1"; raise constraint_error;
-- 					end case;
-- 
-- 					-- skip shift_right on last bit
-- 					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
-- 					bit_pt := bit_pt + 1; -- go to next bit
-- 			
-- 					-- check if byte complete
-- 					if bit_pt = 0 then
-- 						write_byte_in_vec_file(byte_scratch);
-- 						byte_scratch := 16#00#; -- clear all bits in byte to write (default)
-- 					end if;
-- 					nat_scratch := nat_scratch - 1;
-- 				end loop;
-- 
-- 			-- if all bits of vector_string processed but byte still incomplete, fill remaining bits with 0
-- 			while bit_pt /= 0
-- 				loop
-- 					byte_scratch := (16#7F# and byte_scratch); -- write 0
-- 					-- skip shift_right on last bit
-- 					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
-- 					bit_pt := bit_pt + 1; -- go to next bit
-- 
-- 					-- check if byte complete
-- 					if bit_pt = 0 then
-- 						write_byte_in_vec_file(byte_scratch);
-- 					end if;
-- 				end loop;
-- 			-- expect vector done
-- 
-- 		end if; -- build mask and expect vector
-- 
-- 	end make_binary_vector;
-- 
-- 
-- 	function scale_pattern
-- 		(
-- 		input_string	: string;
-- 		length_wanted	: natural
-- 		) return string is
-- 		
-- 		char_scratch 	: character;
-- 		scaled_pattern	: string (1..length_wanted);
-- 	begin
-- 		-- check string length. it must be 1
-- 		if length(to_unbounded_string(input_string)) = 1 then
-- 			char_scratch := input_string(input_string'first); -- read the first and only character from input string
-- 			if is_in(char_scratch,bit_char) then -- check for 0,1 or x
-- 				scaled_pattern := length_wanted * char_scratch; -- scale input char to wanted pattern
-- 				--put(char_scratch); new_line;
-- 				--put(scaled_pattern); new_line;
-- 			else
-- 				prog_position := "SC1";
-- 				raise constraint_error; -- if not 0,1 or x
-- 			end if;
-- 		else
-- 			prog_position := "SC2";
-- 			raise constraint_error; -- if length is not 1
-- 		end if;
-- 
-- 		return(scaled_pattern);
-- 		exception when constraint_error =>
-- 			raise constraint_error; -- propagate exception to mainline program
-- 	end scale_pattern;
-- 
-- 
-- 	procedure check_option_retry is
-- 	begin
-- 		ubyte_scratch := 0;
-- 		ubyte_scratch2 := 0;
-- 		if get_field(line,4) = "option" then
-- 			if get_field(line,5) = "retry" then
-- 				prog_position := "RE1";
-- 				if get_field_count(line) = 8 then -- expect 8 fields in line
-- 					retries := natural'value(get_field(line,6));
-- 					if get_field(line,7) = "delay" then
-- 						retry_delay := float'value(get_field(line,8));
-- 						ubyte_scratch2 := unsigned_8(natural(retry_delay * 10.0));
-- 						ubyte_scratch := unsigned_8(retries);
-- 					else raise constraint_error;
-- 					end if; -- if "delay" found
-- 				else raise constraint_error;
-- 				end if;
-- 			end if; -- if "retry" found
-- 		end if; -- if "option" found
-- 	end check_option_retry;
-- 
-- 
 	procedure compile_command (cmd : extended_string.bounded_string) is
		field_pt 				: positive := 1;
		field_ct 				: positive := get_field_count(extended_string.to_string(cmd));
		ubyte_scratch  			: unsigned_8;
		ubyte_scratch2		 	: unsigned_8;
		bic_name				: universal_string_type.bounded_string;
		bic_coordinates			: type_bscan_ic_ptr;
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
		-- overwrites bit positions specified in range cell_pos_low..cell_pos_high with text_in
			pattern_old 	: type_string_of_bit_characters_class_0;
			length_total 	: positive;
			cell_pos_high	: positive;
			cell_pos_low	: positive;
			pattern_in		: string;
			orientation		: type_set_vector_orientation;
			direction		: type_set_direction := drv;
			mask			: boolean := false
			) return type_string_of_bit_characters_class_0 is

			pattern_in_length	: positive := cell_pos_high - cell_pos_low + 1;

			subtype type_pattern_1 is type_string_of_bit_characters_class_1 (1..pattern_in_length);
			pattern_in_class_1	: type_pattern_1;

			subtype type_pattern_0 is type_string_of_bit_characters_class_0 (1..pattern_in_length);
			pattern_new			: type_pattern_0;

			whole_pattern_is_dont_care : boolean := false; -- used for exceptional case when expect pattern contains only one x
			-- example: set IC202 exp boundary 16 downto 0 = x

		begin -- update_pattern
			-- if this is an expect pattern of length 1 and value x -> assume all bits of this pattern are don't cares
			-- example: set IC202 exp boundary 16 downto 0 = x
			prog_position	:= 500;
			if direction = exp then
				if pattern_in'last = 1 then -- means if pattern_in is just one character
					if pattern_in(pattern_in'first) = 'x' or pattern_in(pattern_in'first) = 'X' then
					-- CS: use type type_bit_character_x
						whole_pattern_is_dont_care := true;
					end if;
				end if;
			end if;

			-- evaluate flag "whole_pattern_is_dont_care" (means fill all bits with dont cares if required)
			prog_position	:= 510;
			if whole_pattern_is_dont_care then
				-- fill pattern_in_class_1 with as much x as specified by cell_pos_high and cell_pos_low
				pattern_in_class_1	:= to_binary_class_1(  to_binary( pattern_in_length * 'x', pattern_in_length , class_1)  );
			else
				-- convert string given in pattern_in to string of bit characters class 1
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

			return pattern_new;
		end update_pattern;


	procedure concatenate_sir_images is
	-- concatenate sir drv patterns starting with device closest to BSC TDO ! This device has position 1.
		length_total : positive := chain(scanpath_being_compiled).irl_total;
		subtype type_sir_image is type_string_of_bit_characters_class_0 (1..length_total);
		sir_drive	: type_sir_image;
		sir_expect	: type_sir_image;
		sir_mask	: type_sir_image;
		b : type_bscan_ic_ptr;

		pos_start	: positive := 1;
		pos_end		: positive;
		
	begin
		for p in 1..summary.bic_ct loop -- p defines the position
			b := ptr_bic;
			while b /= null loop -- loop in bic list
				if b.position = p then -- on position match
					if b.chain = scanpath_being_compiled then -- on scanpath match

						-- start pos initiated already
						-- calculate end position to place bic-image
						pos_end := (pos_start + b.len_ir) - 1;

						sir_drive(pos_start..pos_end) 	:= b.pattern_last_ir_drive;
						sir_expect(pos_start..pos_end)	:= b.pattern_last_ir_expect;
						sir_mask(pos_start..pos_end)	:= b.pattern_last_ir_mask;

						put_line(chain(scanpath_being_compiled).register_file, "step" 
							& positive'image(vector_id) & " device" & positive'image(p) & " ir");

						-- calculate start position to place next image
						pos_start := pos_end + 1;
					end if;
				end if;
				b := b.next;
			end loop;
		end loop;
	end concatenate_sir_images;
 				
 	begin -- compile_command
		prog_position	:= 400;

		--hard+soft trst (default)
		if get_field_from_line(cmd,1) = sequence_instruction_set.trst then
			write_llc(16#30#,16#80#); 
		--only soft trst
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.strst then
			write_llc(16#30#,16#81#);
		--only hard trst
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.htrst then
			write_llc(16#30#,16#82#); 

		prog_position	:= 420;
		-- "scanpath" (example: tap_state test-logic-reset, tap_state pause-dr)
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.tap_state then
			if get_field_from_line(cmd,2) = tap_state.test_logic_reset then
				write_llc(16#30#,16#83#); 
			elsif get_field_from_line(cmd,2) = tap_state.run_test_idle then
				write_llc(16#30#,16#84#); 
			elsif get_field_from_line(cmd,2) = tap_state.pause_dr then
				write_llc(16#30#,16#85#); 
			elsif get_field_from_line(cmd,2) = tap_state.pause_ir then 
				write_llc(16#30#,16#86#); 
			else
				put_line("ERROR: TAP state not supported for low level operation !");
				raise constraint_error;
			end if;

		-- "connect" (example: connect port 1)
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.connect then
			if get_field_from_line(cmd,2) = scanport_identifier.port then 
				if get_field_from_line(cmd,3) = "1" then
					write_llc(16#40#,16#81#); -- gnd 1, tap 1 relay on #CS: dio, aio ?
				elsif get_field_from_line(cmd,3) = "2" then 
					write_llc(16#40#,16#82#); -- gnd 2, tap 2 relay on #CS: dio, aio ?
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
 
		-- "disconnect" (example: disconnect port 1)
		elsif get_field_from_line(cmd,1) = sequence_instruction_set.disconnect then
			if get_field_from_line(cmd,2) = scanport_identifier.port then 
				if get_field_from_line(cmd,3) = "1" then
					write_llc(16#40#,16#01#); -- gnd 1, tap 1 relay on #CS: dio, aio ?
				elsif get_field_from_line(cmd,3) = "2" then 
					write_llc(16#40#,16#02#); -- gnd 2, tap 2 relay on #CS: dio, aio ?
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
			write_llc(16#40#,16#12#); -- set i2c muxer sub bus 2  # 14,13,11 ack error
			if get_field_from_line(cmd,2) = power_cycle_identifier.up then

				-- pwr relay 1 on
				if get_field_from_line(cmd,3) = "1" then
					write_llc(16#40#,16#83#);
				-- pwr relay 2 on
				elsif get_field_from_line(cmd,3) = "2" then
					write_llc(16#40#,16#84#); 
				-- pwr relay 3 on
				elsif get_field_from_line(cmd,3) = "3" then
					write_llc(16#40#,16#85#);
				-- all pwr relays on
				elsif get_field_from_line(cmd,3) = power_channel_name.all_channels then 
					write_llc(16#40#,16#86#);
				-- gnd pwr relay on
				elsif get_field_from_line(cmd,3) = power_channel_name.gnd then
					write_llc(16#40#,16#87#);
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
					write_llc(16#40#,16#03#);
				-- pwr relay 2 off
				elsif get_field_from_line(cmd,3) = "2" then
					write_llc(16#40#,16#04#); 
				-- pwr relay 3 off
				elsif get_field_from_line(cmd,3) = "3" then
					write_llc(16#40#,16#05#);
				-- all pwr relays off
				elsif get_field_from_line(cmd,3) = power_channel_name.all_channels then 
					write_llc(16#40#,16#06#);
				-- gnd pwr relay off
				elsif get_field_from_line(cmd,3) = power_channel_name.gnd then
					write_llc(16#40#,16#07#);
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
			-- set i2c muxer sub bus 3
			write_llc(16#40#,16#13#); 
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
			ubyte_scratch := unsigned_8(natural(22.4 * (5.7 + current_limit_set_by_operator)));
			ubyte_scratch2 := 16#40# + unsigned_8(power_channel_name.id);
			write_llc(ubyte_scratch2, ubyte_scratch); 

			-- get timeout
			if get_field_from_line(cmd,4) = timeout_identifier then
				if float'value(get_field_from_line(cmd,5)) in type_overload_timeout then
					overload_timeout := float'value(get_field_from_line(cmd,5));
					-- set i2c muxer sub bus 2
					write_llc(16#40#,16#12#); 
					-- cal. 8bit timeout value
					-- write llc (43h + pwr_channel) as extended I2C operation
					ubyte_scratch := unsigned_8(natural(overload_timeout/overload_timeout_resolution)); 
					ubyte_scratch2 := 16#43# + unsigned_8(power_channel_name.id);
					write_llc(ubyte_scratch2, ubyte_scratch);
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
 				ubyte_scratch := unsigned_8(natural(delay_set_by_operator/delay_resolution));
 				write_llc(16#20#, ubyte_scratch); 
			else
				put_line("ERROR: Delay value invalid !");
				put_line("       Provide a number between" & type_delay_value'image(type_delay_value'first) 
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
													pattern_old 		=> bic_coordinates.pattern_last_ir_drive,
													length_total 		=> cell_id_max + 1,
													cell_pos_high		=> cell_id_upper_end + 1,
													cell_pos_low		=> cell_id_lower_end + 1,
													pattern_in			=> get_field_from_line(cmd,9),
													orientation			=> set_vector_orientation
													);
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
						end case;
					end if;

				end loop;

				-- CS: field 10 not read any more -> make it a comment


			else -- if device is not a bic
				put_line("ERROR: Device '" & universal_string_type.to_string(bic_name) & "' is not part of any scanpath ! Check name and capitalization !)");
				raise constraint_error;
			end if; -- if device is a bic

 
		-- "sir"
 		elsif get_field_from_line(cmd,1) = sequence_instruction_set.sir then -- CS: check id ?
			vector_id := natural'value(get_field_from_line(cmd,3));

			-- concatenate sir drive, expect and mask images to a single large image
			concatenate_sir_images;
-- 
-- 				-- check option "retry"
-- 				check_option_retry;
-- 
-- 				-- make binary drive vector
-- 				-- debug new_line; put_line("sir drv: " & chain(chain_pt).ir_drv_all & " " & trailer_ir);
-- 				make_binary_vector
-- 					(
-- 					sir_sdr =>"sir",
-- 					drv_exp => "drv",
-- 					id => vector_id,
-- 					vector_string => chain(chain_pt).ir_drv_all & trailer_ir, -- trailer must be attached to the lower end of a drv vector
-- 					-- NOTE: vector_string is mirrored: LSB left, MSB right
-- 					retries => ubyte_scratch,
-- 					retry_delay => ubyte_scratch2
-- 					);
-- 
-- 				-- make binary expect and mask vector
-- 				-- debug new_line; put_line("sir exp: " & trailer_ir & " " & chain(chain_pt).ir_exp_all);
-- 				make_binary_vector
-- 					(
-- 					sir_sdr =>"sir",
-- 					drv_exp => "exp",
-- 					vector_string => trailer_ir & chain(chain_pt).ir_exp_all -- trailer must be attached to the upper end of a expect vector
-- 					-- NOTE: vector_string is mirrored: LSB left, MSB right
-- 					);
-- 
-- 			end if; -- if sir found
-- 
-- 
-- 			-- if sdr found
-- 			if get_field_from_line(cmd,1) = "sdr" then -- CS: check id ?
-- 				vector_id := vector_id_type(natural'value(get_field_from_line(cmd,3)));
-- 
-- 				-- reset chain dr drv image
-- 				chain(chain_pt).dr_drv_all := to_unbounded_string("");
-- 				-- reset chain dr exp image
-- 				chain(chain_pt).dr_exp_all := to_unbounded_string("");
-- 
-- 				-- chaining sdr drv and exp patterns starting with device closest to BSC TDO !
-- 				-- use drv pattern depending on latest loaded instruction of particular device
-- 				nat_scratch := 1;
-- 				while nat_scratch <= chain(chain_pt).mem_ct -- process number of devices in current chain
-- 				loop
-- 					-- chain up dr drv/exp patterns
-- 					if chain(chain_pt).members(nat_scratch).instruction = "bypass" then
-- 						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).byp_drv;
-- 						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).byp_exp;
-- 
-- 						Set_Output(chain(chain_pt).reg_file);
-- 						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " bypass");
-- 						Set_Output(standard_output);
-- 					end if;
-- 
-- 					if chain(chain_pt).members(nat_scratch).instruction = "idcode" then
-- 						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).idc_drv;
-- 						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).idc_exp;
-- 
-- 						Set_Output(chain(chain_pt).reg_file);
-- 						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " idcode");
-- 						Set_Output(standard_output);
-- 					end if;
-- 
-- 					if chain(chain_pt).members(nat_scratch).instruction = "usercode" then
-- 						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).usc_drv;
-- 						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).usc_exp;
-- 
-- 						Set_Output(chain(chain_pt).reg_file);
-- 						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " usercode");
-- 						Set_Output(standard_output);
-- 					end if;
-- 
-- 					if chain(chain_pt).members(nat_scratch).instruction = "sample" then
-- 						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).bsr_drv;
-- 						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).bsr_exp;
-- 
-- 						Set_Output(chain(chain_pt).reg_file);
-- 						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " boundary");
-- 						Set_Output(standard_output);
-- 					end if;
-- 
-- 					if chain(chain_pt).members(nat_scratch).instruction = "extest" then
-- 						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).bsr_drv;
-- 						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).bsr_exp;
-- 
-- 						Set_Output(chain(chain_pt).reg_file);
-- 						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " boundary");
-- 						Set_Output(standard_output);
-- 					end if;
-- 
-- 					nat_scratch := nat_scratch + 1; -- go to next member in chain
-- 				end loop;
-- 
-- 				-- check option "retry"
-- 				check_option_retry;
-- 
-- 				--make_binary_vector sdr drv ${chain_pt} ${seq[2]} $sdr_drv$trailer_dr $retries $retry_delay #ins V3.5
-- 
-- 				-- make binary drive vector
-- 				make_binary_vector
-- 					(
-- 					sir_sdr =>"sdr",
-- 					drv_exp => "drv",
-- 					id => vector_id,
-- 					vector_string => chain(chain_pt).dr_drv_all & trailer_dr, -- trailer must be attached to the lower end of a drv vector
-- 					-- NOTE: vector_string is mirrored: LSB left, MSB right
-- 					retries => ubyte_scratch,
-- 					retry_delay => ubyte_scratch2
-- 					);
-- 
-- 				-- make binary expect and mask vector
-- 				make_binary_vector
-- 					(
-- 					sir_sdr =>"sdr",
-- 					drv_exp => "exp",
-- 					vector_string => trailer_dr & chain(chain_pt).dr_exp_all -- trailer must be attached to the upper end of a expect vector
-- 					-- NOTE: vector_string is mirrored: LSB left, MSB right
-- 					);
-- 
-- 			end if; -- if sdr found
-- 
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

-- 				test_name   dest_addr(hex)  size(dec)  comp_version  date(yyyy:mm:dd)  time(hh:mm:ss)  UTC_offset(h)
-- 				----------------------------------------------------------------------------------------------------
-- 				infra 00000000 674 004.004 2016-04-13 14:25:46 2
-- 				intercon1 00000300 1755 004.004 2016-04-13 14:25:50 2
-- 				sram_ic202 00000A00 6906 004.004 2016-04-13 14:26:05 2
-- 				sram_ic203 00002500 6906 004.004 2016-04-13 14:26:19 2
-- 				osc 00004000 426 004.004 2016-04-13 14:26:28 2
-- 				LED_D401 00004200 2562 004.004 2016-04-13 14:26:29 2
-- 				LED_D402 00004D00 2562 004.004 2016-04-13 14:26:30 2
-- 				LED_D403 00005800 2562 004.004 2016-04-13 14:26:30 2
-- 				LED_D404 00006300 2562 004.004 2016-04-13 14:26:31 2


			while not end_of_file
				loop
					line_counter := line_counter + 1; -- count lines
					line		 := extended_string.to_bounded_string(get_line); -- get a line from the journal

					--put_line(line);
					--Put( Integer'Image( Integer'Value("16#1A2B3C#") ) );  

					if line_counter > 2 then -- header and separator must be skipped (see example above)
						last_dest_addr := integer'value("16#" & get_field_from_line(line,2) & "#");  	-- last_dest_addr is a hex number !!!
						last_size := integer'value(get_field_from_line(line,3));  					-- last_size is a dec number !!!
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
								ti.end_sdr := type_end_sxr'value(get_field_from_line(line_of_file,3));
							end if;
							if get_field_from_line(line_of_file,1) = section_info_item.end_sir then
								ti.end_sir := type_end_sxr'value(get_field_from_line(line_of_file,3));
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
			
			-- convert frequency to prescaler value
			-- CS: depends on executor firmware
			-- if frequency given is zero (or option missing entirely) the hex value defaults (see m1_internal.ads)
			case so.frequency is
				when 4 => so.frequency_prescaler := 16#FF#;
				when 3 => so.frequency_prescaler := 16#FE#;
				when 2 => so.frequency_prescaler := 16#FD#;
				when 1 => so.frequency_prescaler := 16#F8#;
				when others => 
					-- CS: the lowest frequency depends on executor firmware
					put_line("WARNING: frequency option invalid or missing. Falling back to safest frequency of 33 khz ...");
			end case;

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

			-- convert driver characteristics to unsigned_8
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
		seq_io_unsigned_byte.create( vector_file_header, seq_io_unsigned_byte.out_file, name => temp_directory & "/vec_header.tmp");

		--separate major and minor compiler version and write them in header
		nat_scratch := natural'value(compseq_version(1..3)); -- major number is the three digits before "."
    	seq_io_unsigned_byte.write(vector_file_header,unsigned_8(nat_scratch));
 
		nat_scratch := natural'value(compseq_version(5..7)); -- minor number is the three digits after "."
    	seq_io_unsigned_byte.write(vector_file_header,unsigned_8(nat_scratch));

		-- write vector file format, CS: not supported yet, default is 00h each
    	seq_io_unsigned_byte.write(vector_file_header,16#00#); -- vector file format major number
    	seq_io_unsigned_byte.write(vector_file_header,16#00#); -- vector file format minor number
 
		-- write scanpath count -- CS: should be a (16bit) number that indicates active scanpaths
		seq_io_unsigned_byte.write(vector_file_header, unsigned_8(summary.scanpath_ct));
	end write_vector_file_header;
	

	procedure unknown_yet is


-- 		-- GLOBAL ARRAY THAT DESCRIBES ALL PHYICAL AVAILABLE SCANPATHS
-- 		-- non-active scanpaths have an irl_total of zero
-- 		-- irl_total is the sum of all instuction registers in that scanpath
-- 		-- irl_total is computed when creating register files
-- 		type type_single_chain is
-- 			record
-- 		-- 			name		: unbounded_string;
-- 		-- 			mem_ct		: natural := 0;
-- 		-- 			members		: type_all_members_of_a_single_chain;
-- 		 		irl_total	: natural := 0;
-- 		-- 			drl_total	: natural := 0;
-- 		-- 			ir_drv_all	: unbounded_string; -- MSB left !!!
-- 		-- 			ir_exp_all	: unbounded_string; -- MSB left !!!
-- 		-- 			dr_drv_all	: unbounded_string; -- MSB left !!!
-- 		-- 			dr_exp_all	: unbounded_string; -- MSB left !!!
-- 				register_file	: ada.text_io.file_type;
-- 			end record;
-- 		type type_all_chains is array (natural range 1..scanport_count_max) of type_single_chain;


	 	procedure write_base_address is
		-- writes base address of current scanpath in vector_file_header
			u4byte_scratch	: unsigned_32 := 0;
			ubyte_scratch	: unsigned_8 := 0;
	 	begin
 
			-- add offset due to header size (one byte is chain_count, 4 byte start address per chain) -- CS: unclear !!
			--size_of_vector_file := size_of_vector_file + (summary.scanpath_ct * 4)+1 + destination_address;
			size_of_vector_file := destination_address + size_of_vector_file + (summary.scanpath_ct * 4) +1;
			--size_of_vector_file := destination_address + 5 + size_of_vector_file + (summary.scanpath_ct * 4);

			-- write size_of_vector_file byte per byte in vec_header (lowbyte first)
	 		u4byte_scratch := unsigned_32(size_of_vector_file);

			u4byte_scratch := (shift_left(u4byte_scratch,3*8)); -- clear bits 31..8 by shift left 24 bits
			u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
	 		ubyte_scratch := unsigned_8(u4byte_scratch); -- take lowbyte
			seq_io_unsigned_byte.write(vector_file_header,ubyte_scratch); -- write bits 7..0 in file

			u4byte_scratch := unsigned_32(size_of_vector_file);
			u4byte_scratch := (shift_left(u4byte_scratch,2*8)); -- clear bits 31..16 by shift left 16 bit
			u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
			ubyte_scratch := unsigned_8(u4byte_scratch);
			seq_io_unsigned_byte.write(vector_file_header,ubyte_scratch); -- write bits 15..8 in file

			u4byte_scratch := unsigned_32(size_of_vector_file);
			u4byte_scratch := (shift_left(u4byte_scratch,8)); -- clear bits 31..24 by shift left 8 bit
			u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
	 		ubyte_scratch := unsigned_8(u4byte_scratch);
			seq_io_unsigned_byte.write(vector_file_header,ubyte_scratch); -- write bits 23..16 in file

			u4byte_scratch := unsigned_32(size_of_vector_file);
			u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift right by 24 bits
			ubyte_scratch := unsigned_8(u4byte_scratch); -- take highbyte
			seq_io_unsigned_byte.write(vector_file_header,ubyte_scratch); -- write bits 31..24 in file

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
	



-- 		chain	: type_all_chains;
		-- 	mem_map	: all_chain_mem_maps;

		b : type_bscan_ic_ptr;

	begin -- unknown_yet
		--	set_output(standard_output);
		put_line("found" & natural'image(summary.scanpath_ct) & " scan paths(s) ...");

		prog_position	:= 210;
		for sp in 1..scanport_count_max loop

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
				scanpath_being_compiled := sp;
				--put_line("active" & natural'image(sp) );

				-- CREATE REGISTER FILE (members_x.reg)
				-- write something like: "device 1 IC301 irl 8 bsl 108" in the reg file
				prog_position	:= 240;
 				create( 
					file => chain(sp).register_file,
					name => (universal_string_type.to_string(test_name) & "/members_" & trim(natural'image(sp), side => left) & ".reg")
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
								put_line(chain(sp).register_file,"device" & natural'image(p)
									& row_separator_0 & universal_string_type.to_string(b.name)
									& row_separator_0 & "irl" & positive'image(b.len_ir)
									& row_separator_0 & "bsl" & positive'image(b.len_bsr)
									);

								-- sum up irl of chain members to calculate the irl_total for that scanpath
								-- CS: assumption is that no device is bypassed or added/inserted in the chain later
								chain(sp).irl_total := chain(sp).irl_total + b.len_ir;
							end if;
						end if;
						b := b.next;
					end loop;
				end loop;

				-- WRITE BASE ADDRESS OF CURRENT SCANPATH
				prog_position	:= 260;
				write_base_address;

				-- PROCESS SEQUENCES one by one
				for s in 1..sequence_count loop
				prog_position	:= 270;
					read_sequence(s);
				end loop;

				-- CLOSE REGISER FILE
				prog_position	:= 280;
				close ( chain(sp).register_file);
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

	prog_position	:= 100;
	write_vector_file_header;

	-- WRITE GLOBAL CONFIGURATION IN VEC FILE
	-- frequency
	write_in_vector_file(scanpath_options.frequency_prescaler);
	-- threshold
	write_in_vector_file(scanpath_options.threshold_tdi_port_1_unsigned_8);
	write_in_vector_file(scanpath_options.threshold_tdi_port_2_unsigned_8);
	-- output voltage
	write_in_vector_file(scanpath_options.voltage_out_port_1_unsigned_8);
	write_in_vector_file(scanpath_options.voltage_out_port_2_unsigned_8);

	-- port 1: sum up drv characteristics of tck an tms to a single byte
	write_in_vector_file(scanpath_options.tck_driver_port_1_unsigned_8 + scanpath_options.tms_driver_port_1_unsigned_8);

	-- port 1: sum up drv characteristics of tdo an trst to a single byte
	write_in_vector_file(scanpath_options.tdo_driver_port_1_unsigned_8 + scanpath_options.trst_driver_port_1_unsigned_8);

	-- port 2: sum up drv characteristics of tck an tms to a single byte
	write_in_vector_file(scanpath_options.tck_driver_port_2_unsigned_8 + scanpath_options.tms_driver_port_2_unsigned_8);

	-- port 1: sum up drv characteristics of tdo an trst to a single byte
	write_in_vector_file(scanpath_options.tdo_driver_port_2_unsigned_8 + scanpath_options.trst_driver_port_2_unsigned_8);

	-- port 1 all scanport relays off, CS: ignored by executor
	write_in_vector_file(16#FF#);
	-- port 2 all scanport relays off, CS: ignored by executor
   	write_in_vector_file(16#FF#); 

 	--seq_io_unsigned_byte.close(vector_file);
 	-- options writing done

	prog_position	:= 200;
	unknown_yet;
 

 
-- 	-- open vector file one last time for write append
-- 	-- write test end marker in vector file
-- 	scratch := test_name;
-- 	scratch := scratch & "/" & scratch & ".vec";
-- 	seq_io_unsigned_byte.open( VectorFile, seq_io_unsigned_byte.append_file, Name => to_string(scratch));
-- 	write_word_in_vec_file(16#0000#); 	-- a conf. word has ID 0000h
-- 	write_byte_in_vec_file(16#77#);		-- 77h indicates end of test
-- 	write_byte_in_vec_file(16#02#);		-- 02h indicates virtual begin of chain 2 data
-- 	seq_io_unsigned_byte.close(vectorfile);
-- 
-- 	-- append vector file to header file byte per byte
-- 	seq_io_unsigned_byte.open( VectorFile, seq_io_unsigned_byte.in_file, Name => to_string(scratch));
-- 	while not seq_io_unsigned_byte.end_of_file(VectorFile)
-- 	loop
-- 		seq_io_unsigned_byte.read(VectorFile,ubyte_scratch);
-- 		seq_io_unsigned_byte.write(VectorFileHead,ubyte_scratch);
-- 	end loop;
-- 	seq_io_unsigned_byte.close(vectorfile);
-- 	seq_io_unsigned_byte.close(VectorFileHead);
-- 
-- 	-- make final vector file in test directory
-- 	copy_file("tmp/vec_header.tmp",to_string(scratch));
-- 
--     -- write journal
-- 	scratch := test_name;
-- 	scratch := scratch & "/" & scratch & ".vec";
-- 	size_of_vec_file := Natural'Value(file_size'image(size(to_string(scratch))));
-- 
-- 	prog_position := "JO3";
-- 	if exists("setup/journal.txt") then
-- 		 -->> setup/journal.txt	
-- 		Open( 
-- 			File => tmp_file,
-- 			Mode => append_File,
-- 			Name => "setup/journal.txt"
-- 			);
-- 		set_output(tmp_file);
-- 		put(test_name & " " & hex_print(next_dest_addr,8) & natural'image(size_of_vec_file) & " " & version & " ");
-- 		put(Image(clock) & " "); put(Integer(UTC_Time_Offset/60),1); new_line;
-- 		set_output(standard_output);
-- 	else
-- 		put_line("No journal found. Creating a new one ...");
-- 		create(tmp_file,out_file,"setup/journal.txt");
-- 		set_output(tmp_file);
-- 		put_line("test_name   dest_addr(hex)  size(dec)  comp_version  date(yyyy:mm:dd)  time(hh:mm:ss)  UTC_offset(h)");
-- 		put_line("----------------------------------------------------------------------------------------------------");
-- 		put(test_name & " " & hex_print(next_dest_addr,8) & natural'image(size_of_vec_file) & " " & version & " ");
-- 		put(Image(clock) & " "); put(Integer(UTC_Time_Offset/60),1); new_line;
-- 		set_output(standard_output);
-- 	end if;


	exception
		when event: others =>
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
-- 	--		if prog_position = "MEM" then
-- 			if prog_position = "JO1" then
-- 				put_line("Journal corrupted or empty !");
-- 			end if;
-- 			if prog_position = "TI1" then
-- 				put_line("Pattern for trailer_ir incorrect !");
-- 				put_line("Please use an 8 bit pattern consisting of characters 0 or 1. Example 00110101");
--  				put_line("Affected line reads : " & line);
-- 			end if;
-- 			if prog_position = "TD1" then
-- 				put_line("Pattern for trailer_dr incorrect !");
-- 				put_line("Please use an 8 bit pattern consisting of characters 0 or 1. Example 00110101");
--  				put_line("Affected line reads : " & line);
-- 			end if;


--			Set_Exit_Status(Failure);		

end compseq;
