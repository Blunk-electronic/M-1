with Ada.Text_IO;			use Ada.Text_IO;
with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
with Ada.Float_Text_IO;		use Ada.Float_Text_IO;
with Ada.Sequential_IO;		--use Ada.Sequential_IO;
with Ada.Characters; 		use Ada.Characters;
with Ada.Characters.Handling; 		use Ada.Characters.Handling;
with ada.characters.conversions;	use ada.characters.conversions;

with m1; use m1;

--with System.OS_Lib;   use System.OS_Lib;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.maps;	 	use Ada.Strings.maps;
with Ada.Strings.Fixed; 	use Ada.Strings.Fixed;
with Ada.Strings;		 	use Ada.Strings;
with interfaces;			use interfaces;
--with Ada.Numerics;			use Ada.Numerics;
--with Ada.Numerics.Elementary_Functions;	use Ada.Numerics.Elementary_Functions;

with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
--with Ada.Task_Identification;  use Ada.Task_Identification;
with Ada.Exceptions; use Ada.Exceptions;
 
--with GNAT.OS_Lib;   	use GNAT.OS_Lib;
with Ada.Command_Line;	use Ada.Command_Line;
with Ada.Directories;	use Ada.Directories;
 
with Ada.Calendar;				use Ada.Calendar;
with Ada.Calendar.Formatting;	use Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;	use Ada.Calendar.Time_Zones;

procedure compseq is

	Version			: String (1..7) := "004.002";

	--type unsigned_byte is mod 256;
	package seq_io_unsigned_byte is new Ada.Sequential_IO(unsigned_8);
	
	type unsigned_3 is mod 8;
	bit_pt	: unsigned_3 := 0;

	power_channel_ct: natural := 3; -- number of available power monitor channels
	subtype type_power_channel is natural range 1..power_channel_ct;
	power_channel	: type_power_channel; -- power channel being processed

	imax			: float := 5.0; -- Amps
	subtype type_imax is float range 0.1..imax;
	imax_wanted		: type_imax;  --CS: default ?
 
	imax_timeout_max : float := 5.0; -- seconds
	imax_timeout_min : float := 0.02; -- seconds
	timeout_resolution : float := 0.02; -- seconds
	subtype type_imax_timeout is float range imax_timeout_min..imax_timeout_max;
	imax_timeout	: type_imax_timeout; --CS: default ?

	delay_max		: float := 25.0; -- seconds
	delay_min		: float := 0.1; -- seconds
	delay_resolution: float := 0.1; -- seconds
	subtype type_delay is float range delay_min..delay_max;
	delay_wanted	: type_delay; -- CS: default ?

	vectors_max		: constant natural := 1000;
	subtype vector_id_type is natural range 1..vectors_max;
	vector_id		: vector_id_type := 1;
	
	vector_length_max	: constant natural := 5000;
	subtype type_vector_length is natural range 1..vector_length_max;

	frequency_max	: natural := 4; -- Mhz
	frequency_dec	: natural := 0;

-- 	trailer_ir		: unsigned_8 := 2#1100101#;
-- 	trailer_dr		: unsigned_8 := 2#1100101#;
	length_trailer_ir	: constant natural := 8;
	length_trailer_dr	: constant natural := 8;
	trailer_ir		: string (1..length_trailer_ir) := "11001010"; -- CAh
	trailer_dr		: string (1..length_trailer_dr) := "11001010"; -- CAh

	on_fail			: unbounded_string := to_unbounded_string("power_down");
	frequency_hex	: unsigned_8 := 0;
	vcc_1			: unsigned_8 := 0;
	vcc_2			: unsigned_8 := 0;
	thi_1			: unsigned_8 := 0; -- default to 0.8V ?
	thi_2			: unsigned_8 := 0; -- default to 0.8V ?
	tck1_drv_char	: unsigned_8 := 16#06#; -- default push-pull characteristic
	tck2_drv_char	: unsigned_8 := 16#06#; -- default push-pull characteristic
	tms1_drv_char	: unsigned_8 := 16#30#; -- default push-pull characteristic
	tms2_drv_char	: unsigned_8 := 16#30#; -- default push-pull characteristic
	tdo1_drv_char	: unsigned_8 := 16#06#; -- default push-pull characteristics
	tdo2_drv_char	: unsigned_8 := 16#06#; -- default push-pull characteristic
	trst1_drv_char	: unsigned_8 := 16#30#; -- default push-pull characteristic
	trst2_drv_char	: unsigned_8 := 16#30#; -- default push-pull characteristic

	--string8_scratch	: string (1..8);
	char_scratch 	: character;
	ubyte_scratch	: unsigned_8 := 0;
	ubyte_scratch2	: unsigned_8 := 0;
	byte_scratch	: unsigned_8 := 0;
	u2byte_scratch	: unsigned_16 := 0;
	u4byte_scratch	: unsigned_32 := 0;
	unb_scratch		: unbounded_string;
	int_scratch		: integer := 0;
	nat_scratch		: natural := 0;
	nat_scratch2	: natural := 0;

	vcc				: float := 0.0;
	vcc_min			: float := 1.8;
	vcc_max			: float := 3.3;
	thi				: float := 0.8;
	thi_max			: float := 3.3;
	
	device   		: Unbounded_string;
	mem_size		: natural := integer'Value("16#0FFFFF#");
	line_ct			: Natural:=0;
	last_dest_addr	: Natural:=0;
	last_size		: Natural:=0;

	Previous_Output	: File_Type renames Current_Output;
	VectorFile 		: seq_io_unsigned_byte.File_Type;
	VectorFileHead	: seq_io_unsigned_byte.File_Type;
	DataBase 		: Ada.Text_IO.File_Type;
	SeqFile  		: Ada.Text_IO.File_Type;
	optionsfile		: Ada.Text_IO.File_Type;
	tmp_file 		: Ada.Text_IO.File_Type;
	journal_file_tmp: Ada.Text_IO.File_Type;
	chain_file 		: Ada.Text_IO.File_Type;
	sequence_file	: Ada.Text_IO.File_Type;
	reg_file 		: Ada.Text_IO.File_Type;
	size_of_vec_file	: Natural := 0;
	prog_position 	: string := "---"; 

	chain_ct		: natural := 0;
	chain_pt		: natural := 1;
	sequence_ct		: natural := 0;
	sequence_pt		: natural := 1;

	test_name		: Unbounded_string;
	data_base		: Unbounded_string;
	scratch			: Unbounded_string;
	Line			: Unbounded_string;
	reg_line		: Unbounded_string;
	hex_number_as_string	: Unbounded_string;
	next_dest_addr	: natural;
	dummy			: Integer;

	lp				: natural; -- line pointer
	bit_char	 : character_set := to_set("01x");
--	type string_ is array (Positive range <>) of My_Character;

	retry_ct_max	: natural := 100;
	retry_delay_max	: float := 25.5; -- sec.
	subtype type_retries is natural range 0..retry_ct_max;
	subtype type_retry_delay is float range 0.0..retry_delay_max;
	retries		: type_retries;
	retry_delay : type_retry_delay;


	chain_section_entered 			: boolean := false;
	device_register_section_entered : boolean := false;

	idc_length	: constant natural := 32;
	usc_length	: constant natural := 32;

	type type_single_member is
		record
			device	: unbounded_string;
			irl		: natural;
			bsl		: natural;
			ir_drv	: unbounded_string;		-- holds opcode of latest instruction loaded
			instruction	: unbounded_string; -- holds name of latest instruction loaded

			byp_drv	: character;
			bsr_drv	: unbounded_string;
			idc_drv	: unbounded_string;
			usc_drv	: unbounded_string;

			byp_exp	: character;
			bsr_exp	: unbounded_string;
			idc_exp	: unbounded_string;
			usc_exp	: unbounded_string;

			ir_exp	: unbounded_string;
--			dr_drv	: unbounded_string;
		end record;

	max_member_ct_per_chain	: constant natural := 100;
	type type_all_members_of_a_single_chain is array (natural range 1..max_member_ct_per_chain) of type_single_member;

	type type_single_chain is
		record
			name		: unbounded_string;
			mem_ct		: natural := 0;
			members		: type_all_members_of_a_single_chain;
			irl_total	: natural := 0;
			drl_total	: natural := 0;
			ir_drv_all	: unbounded_string; -- MSB left !!!
			ir_exp_all	: unbounded_string; -- MSB left !!!
			dr_drv_all	: unbounded_string; -- MSB left !!!
			dr_exp_all	: unbounded_string; -- MSB left !!!
			reg_file	: Ada.Text_IO.File_Type;
		end record;

	max_chain_ct	: constant natural := 2;
	type type_all_chains is array (natural range 1..max_chain_ct) of type_single_chain;

	type chain_mem_map is
		record
			offset		: natural;
			size		: natural;
		end record;

	type all_chain_mem_maps is array (natural range 1..max_chain_ct) of chain_mem_map;

	chain	: type_all_chains;
	mem_map	: all_chain_mem_maps;

	function umask( mask : integer ) return integer;
	pragma import( c, umask );

-- 	function system( cmd : string ) return integer;
-- 	pragma Import( C, system );


	procedure write_base_address is
	begin
		-- get current size of vectorfile
		scratch := test_name;
		scratch := scratch & "/" & scratch & ".vec";
		size_of_vec_file := Natural'Value(file_size'image(size(to_string(scratch))));

		-- add offset due to header size (one byte is chain_count, 4 byte start address per chain)
		size_of_vec_file := (chain_ct * 4)+1 + size_of_vec_file + next_dest_addr;
		mem_map(chain_pt).offset := (chain_ct * 4) + 1; -- save chain offset -- CS: why ?
		mem_map(chain_pt).size := size_of_vec_file; -- save size_of_vec_file -- CS: what for ?
		-- write size_of_vec_file byte per byte in vec_header (lowbyte first)
		u4byte_scratch := unsigned_32(size_of_vec_file);
		--u4byte_scratch := 16#11223344#;

 		u4byte_scratch := (shift_left(u4byte_scratch,3*8)); -- clear bits 31..8 by shift left 24 bits
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch); -- take lowbyte
		seq_io_unsigned_byte.write(VectorFileHead,ubyte_scratch); -- write bits 7..0 in file

		-- reload size_of_vec_file
		u4byte_scratch := unsigned_32(size_of_vec_file);
 		u4byte_scratch := (shift_left(u4byte_scratch,2*8)); -- clear bits 31..16 by shift left 16 bit
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch);
		seq_io_unsigned_byte.write(VectorFileHead,ubyte_scratch); -- write bits 15..8 in file

		-- reload size_of_vec_file
		u4byte_scratch := unsigned_32(size_of_vec_file);
 		u4byte_scratch := (shift_left(u4byte_scratch,8)); -- clear bits 31..24 by shift left 8 bit
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch);
		seq_io_unsigned_byte.write(VectorFileHead,ubyte_scratch); -- write bits 23..16 in file

		-- reload size_of_vec_file
		u4byte_scratch := unsigned_32(size_of_vec_file);
 		--u4byte_scratch := (shift_left(u4byte_scratch,2*8)); -- clear bits 31..16 by shift left 16 bit
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift right by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch); -- take highbyte
		seq_io_unsigned_byte.write(VectorFileHead,ubyte_scratch); -- write bits 31..24 in file

	end write_base_address;


	procedure write_llc
		(
		llct	:	unsigned_8; -- low level command type
		llcc	:	unsigned_8  -- low level command itself
		) is
	begin
--		put_line("llct" & unsigned_byte'image(16#llct#));
		-- write ID -- a conf. word has ID 0000h
 		seq_io_unsigned_byte.write(vectorfile,16#00#); 	
 		seq_io_unsigned_byte.write(vectorfile,16#00#);

		-- write llct
 		seq_io_unsigned_byte.write(vectorfile,llct); --write low level command type

		-- write chain pt
		-- write chain number in vec file. NOTE: chain number is ignored by executor
 		seq_io_unsigned_byte.write(vectorfile,unsigned_8(chain_pt)); 
 		seq_io_unsigned_byte.write(vectorfile,llcc); -- write low level command itself
	end write_llc;


	procedure write_byte_in_vec_file
		(
		byte	: unsigned_8
		) is
	begin
		seq_io_unsigned_byte.write(vectorfile,byte); -- write a single byte in file
	end write_byte_in_vec_file;


	procedure write_word_in_vec_file
		(
		word	: unsigned_16
		) is
		ubyte_scratch  : unsigned_8;
		u2byte_scratch : unsigned_16;
	begin
		-- lowbyte first
		u2byte_scratch := word;
 		u2byte_scratch := (shift_left(u2byte_scratch,8)); -- clear bits 15..8 by shift left 8 bit
 		u2byte_scratch := (shift_right(u2byte_scratch,8)); -- shift back by 8 bits
		ubyte_scratch := unsigned_8(u2byte_scratch); -- take lowbyte
		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch); -- write lowbyte in file

		-- highbyte
		u2byte_scratch := word;
 		u2byte_scratch := (shift_right(u2byte_scratch,8)); -- shift right by 8 bits
		ubyte_scratch := unsigned_8(u2byte_scratch); -- take highbyte
		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch); -- write highbyte in file
	end write_word_in_vec_file;


	procedure write_double_word_in_vec_file
		(
		dword	: unsigned_32
		) is
		ubyte_scratch  : unsigned_8;
		u4byte_scratch : unsigned_32;
	begin
		-- lowbyte first
		u4byte_scratch := dword;
 		u4byte_scratch := (shift_left(u4byte_scratch,3*8)); -- clear bits 31..8 by shift left 24 bit
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch); -- take lowbyte
		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch); -- write lowbyte in file

		u4byte_scratch := dword;
 		u4byte_scratch := (shift_left(u4byte_scratch,2*8)); -- clear bits 31..16 by shift left 16 bit
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch);
		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch);

		u4byte_scratch := dword;
 		u4byte_scratch := (shift_left(u4byte_scratch,1*8)); -- clear bits 31..24 by shift left 8 bit
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift back by 24 bits
		ubyte_scratch := unsigned_8(u4byte_scratch);
		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch);

		-- highbyte
		u4byte_scratch := dword;
 		u4byte_scratch := (shift_right(u4byte_scratch,3*8)); -- shift right by 8 bits
		ubyte_scratch := unsigned_8(u4byte_scratch); -- take lowbyte
		seq_io_unsigned_byte.write(vectorfile,ubyte_scratch); -- write highbyte in file
	end write_double_word_in_vec_file;


	procedure make_binary_vector
		(
		sir_sdr	: string; -- "sir"
		drv_exp	: string; -- "drv"
		id 		: vector_id_type := 1; -- required for drive vector only
		vector_string 	: unbounded_string; -- vector as string like 00xx11101x
		retries			: unsigned_8 := 0; -- required for dirve vector only
		retry_delay 	: unsigned_8 := 0  -- required for dirve vector only
		) is
		vector_length : type_vector_length := length(vector_string);

	begin
		-- vector format is:  
		-- 16 bit ID , 8 bit SIR/SDR marker, (retries, retry_delay) , 8 bit scan path number, 32 bit vector length , drv data, mask data, exp data
		put(".");

		-- build drive vector
		if drv_exp = "drv" then
			write_word_in_vec_file(unsigned_16(id)); -- write vector id in vector file

			-- write sdr/sir marker in vec file
			if on_fail = "hstrst" then 
				if sir_sdr = "sdr" then
					if retries = 0 then seq_io_unsigned_byte.write(vectorfile,16#01#); end if; -- standard sdr
					if retries > 0 then 
						seq_io_unsigned_byte.write(vectorfile,16#05#);
						seq_io_unsigned_byte.write(vectorfile,retries); 
						seq_io_unsigned_byte.write(vectorfile,retry_delay);  
					end if; -- sdr with retry option
				end if;

				if sir_sdr = "sir" then
					if retries = 0 then seq_io_unsigned_byte.write(vectorfile,16#02#); end if; -- standard sir
					if retries > 0 then 
						seq_io_unsigned_byte.write(vectorfile,16#06#);
						seq_io_unsigned_byte.write(vectorfile,retries); 
						seq_io_unsigned_byte.write(vectorfile,retry_delay);  
					end if; -- sdr with retry option
				end if;

			elsif on_fail = "power_down" then
				if sir_sdr = "sdr" then
					if retries = 0 then seq_io_unsigned_byte.write(vectorfile,16#03#); end if; -- standard sdr
					if retries > 0 then 
						seq_io_unsigned_byte.write(vectorfile,16#07#);
						seq_io_unsigned_byte.write(vectorfile,retries); 
						seq_io_unsigned_byte.write(vectorfile,retry_delay);  
					end if; -- sdr with retry option
				end if;

				if sir_sdr = "sir" then
					if retries = 0 then seq_io_unsigned_byte.write(vectorfile,16#04#); end if; -- standard sir
					if retries > 0 then 
						seq_io_unsigned_byte.write(vectorfile,16#08#);
						seq_io_unsigned_byte.write(vectorfile,retries); 
						seq_io_unsigned_byte.write(vectorfile,retry_delay);  
					end if; -- sdr with retry option
				end if;
			end if;

			-- write chain id in vector file
			seq_io_unsigned_byte.write(vectorfile,unsigned_8(chain_pt)); 

			-- write vector length in vector file
			u4byte_scratch := unsigned_32(vector_length);
			write_double_word_in_vec_file(u4byte_scratch);

			-- write vector_string LSB first
			nat_scratch := vector_length;
			bit_pt := 0; -- bit pointer
			byte_scratch := 16#FF#; -- set all bits in byte to write (default)
			while nat_scratch > 0
				loop
					char_scratch := element(vector_string,nat_scratch);
					case char_scratch is
						-- clear bit position
						when '0' | 'x' | 'X' =>	byte_scratch := (16#7F# and byte_scratch); -- replace x,X by 0
						-- set bit position
						when '1' =>				byte_scratch := (16#80# or  byte_scratch);

						when others => 	prog_position := "DR1"; raise constraint_error;
					end case;
					
					-- skip shift_right on last bit
					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
					bit_pt := bit_pt + 1; -- go to next bit
			
					-- check if byte complete
					if bit_pt = 0 then
						write_byte_in_vec_file(byte_scratch);
						byte_scratch := 16#FF#; -- set all bits in byte to write (default)
					end if;
					nat_scratch := nat_scratch - 1;
				end loop;

			-- if all bits of vector_string processed but byte incomplete, fill remaining bits with 0
			while bit_pt /= 0
				loop
					byte_scratch := (16#7F# and byte_scratch); -- write 0

					-- skip shift_right on last bit
					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
					bit_pt := bit_pt + 1; -- go to next bit

					-- check if byte complete
					if bit_pt = 0 then
						write_byte_in_vec_file(byte_scratch);
					end if;
				end loop;

		end if; -- build drive vector


		-- build mask and expect vector
		if drv_exp = "exp" then

			-- mask vector
			-- write vector_string LSB first
			nat_scratch := vector_length;
			bit_pt := 0; -- bit pointer
			byte_scratch := 16#00#; -- clear all bits in byte to write (default)
			while nat_scratch > 0
				loop
					char_scratch := element(vector_string,nat_scratch);
					case char_scratch is
						-- set bit position where to expect something
						when '0' | '1' =>	byte_scratch := (16#80# or  byte_scratch); -- replace 1,0 by 1
						-- clear bit position where a "don't care" is
						when 'x' =>			byte_scratch := (16#7F# and byte_scratch); -- replace x by 0

						when others => 	prog_position := "MA1"; raise constraint_error;
					end case;

					-- skip shift_right on last bit
					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
					bit_pt := bit_pt + 1; -- go to next bit
			
					-- check if byte complete
					if bit_pt = 0 then
						write_byte_in_vec_file(byte_scratch);
						byte_scratch := 16#00#; -- clear all bits in byte to write (default)
					end if;
					nat_scratch := nat_scratch - 1;
				end loop;

			-- if all bits of vector_string processed but byte still incomplete, fill remaining bits with 0
			while bit_pt /= 0
				loop
					byte_scratch := (16#7F# and byte_scratch); -- write 0
					-- skip shift_right on last bit
					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
					bit_pt := bit_pt + 1; -- go to next bit

					-- check if byte complete
					if bit_pt = 0 then
						write_byte_in_vec_file(byte_scratch);
					end if;
				end loop;
			-- mask vector done
		

			-- expect vector
			-- write vector_string LSB first
			nat_scratch := vector_length;
			bit_pt := 0; -- bit pointer
			byte_scratch := 16#00#; -- clear all bits in byte to write (default)
			while nat_scratch > 0
				loop
					char_scratch := element(vector_string,nat_scratch);
					case char_scratch is
						-- set bit position where to expect 1
						when '1' =>			byte_scratch := (16#80# or  byte_scratch); -- write 1
						-- clear bit position where to expect 0 or where a don't care is
						when '0' | 'x' => 	byte_scratch := (16#7F# and byte_scratch); -- write 0, replace x by 0

						when others => 	prog_position := "EX1"; raise constraint_error;
					end case;

					-- skip shift_right on last bit
					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
					bit_pt := bit_pt + 1; -- go to next bit
			
					-- check if byte complete
					if bit_pt = 0 then
						write_byte_in_vec_file(byte_scratch);
						byte_scratch := 16#00#; -- clear all bits in byte to write (default)
					end if;
					nat_scratch := nat_scratch - 1;
				end loop;

			-- if all bits of vector_string processed but byte still incomplete, fill remaining bits with 0
			while bit_pt /= 0
				loop
					byte_scratch := (16#7F# and byte_scratch); -- write 0
					-- skip shift_right on last bit
					if bit_pt < 7 then byte_scratch := shift_right(byte_scratch,1); end if;
					bit_pt := bit_pt + 1; -- go to next bit

					-- check if byte complete
					if bit_pt = 0 then
						write_byte_in_vec_file(byte_scratch);
					end if;
				end loop;
			-- expect vector done

		end if; -- build mask and expect vector

	end make_binary_vector;


	function scale_pattern
		(
		input_string	: string;
		length_wanted	: natural
		) return string is
		
		char_scratch 	: character;
		scaled_pattern	: string (1..length_wanted);
	begin
		-- check string length. it must be 1
		if length(to_unbounded_string(input_string)) = 1 then
			char_scratch := input_string(input_string'first); -- read the first and only character from input string
			if is_in(char_scratch,bit_char) then -- check for 0,1 or x
				scaled_pattern := length_wanted * char_scratch; -- scale input char to wanted pattern
				--put(char_scratch); new_line;
				--put(scaled_pattern); new_line;
			else
				prog_position := "SC1";
				raise constraint_error; -- if not 0,1 or x
			end if;
		else
			prog_position := "SC2";
			raise constraint_error; -- if length is not 1
		end if;

		return(scaled_pattern);
		exception when constraint_error =>
			raise constraint_error; -- propagate exception to mainline program
	end scale_pattern;


	procedure check_option_retry is
	begin
		ubyte_scratch := 0;
		ubyte_scratch2 := 0;
		if get_field(line,4) = "option" then
			if get_field(line,5) = "retry" then
				prog_position := "RE1";
				if get_field_count(line) = 8 then -- expect 8 fields in line
					retries := natural'value(get_field(line,6));
					if get_field(line,7) = "delay" then
						retry_delay := float'value(get_field(line,8));
						ubyte_scratch2 := unsigned_8(natural(retry_delay * 10.0));
						ubyte_scratch := unsigned_8(retries);
					else raise constraint_error;
					end if; -- if "delay" found
				else raise constraint_error;
				end if;
			end if; -- if "retry" found
		end if; -- if "option" found
	end check_option_retry;


	procedure read_sequence_file is
	line_ct  : natural := 0;
	field_pt : natural := 0;
	field_ct : natural := 0;
	cell_pt  : natural := 0;
	cell_content : string (1..1);
				
	begin
		while not end_of_file
		loop
			line := get_line; line_ct := line_ct + 1;

			-- if a "trst" command in sequence found
			if get_field(line,1) = "trst"  then write_llc(16#30#,16#80#); end if;  --hard+soft trst (default)
			if get_field(line,1) = "strst" then write_llc(16#30#,16#81#); end if;  --only soft trst
			if get_field(line,1) = "htrst" then write_llc(16#30#,16#82#); end if;  --only hard trst

			-- if a "scanpath" command found
			if get_field(line,1) = "scanpath" then
				if get_field(line,2) = "reset"   then write_llc(16#30#,16#83#); end if; --go to tlr
				if get_field(line,2) = "idle"    then write_llc(16#30#,16#84#); end if; --go to idle
				if get_field(line,2) = "drpause" then write_llc(16#30#,16#85#); end if; --go to drpause
				if get_field(line,2) = "irpause" then write_llc(16#30#,16#86#); end if; --go to irpause
			end if;

			-- if a "connect" command found
			if get_field(line,1) = "connect" then
				if get_field(line,2) = "port" then 
					if get_field(line,3) = "1" then write_llc(16#40#,16#81#); end if; -- gnd 1, tap 1 relay on #CS: dio, aio ?
					if get_field(line,3) = "2" then write_llc(16#40#,16#82#); end if; -- gnd 2, tap 2 relay on #CS: dio, aio ?
				end if;
			end if;

			-- if a "disconnect" command found
			if get_field(line,1) = "disconnect" then
				if get_field(line,2) = "port" then 
					if get_field(line,3) = "1" then write_llc(16#40#,16#01#); end if; -- all port 1 relays off
					if get_field(line,3) = "2" then write_llc(16#40#,16#02#); end if; -- all port 2 realys off
				end if;
			end if;

			-- if a "power up" command found
			if get_field(line,1) = "power" then
				if get_field(line,2) = "up" then
					write_llc(16#40#,16#12#); -- set i2c muxer sub bus 2  # 14,13,11 ack error
					if get_field(line,3) = "1"   then write_llc(16#40#,16#83#); end if; -- pwr relay 1 on
					if get_field(line,3) = "2"   then write_llc(16#40#,16#84#); end if; -- pwr relay 2 on
					if get_field(line,3) = "3"   then write_llc(16#40#,16#85#); end if; -- pwr relay 3 on
					if get_field(line,3) = "all" then write_llc(16#40#,16#86#); end if; -- all pwr relays on
					if get_field(line,3) = "gnd" then write_llc(16#40#,16#87#); end if; -- gnd pwr relay on
				end if;
			end if;

			-- if a "power down" command found
			if get_field(line,1) = "power" then
				if get_field(line,2) = "down" then
					write_llc(16#40#,16#12#); -- set i2c muxer sub bus 2  # 14,13,11 ack error
					if get_field(line,3) = "1"   then write_llc(16#40#,16#03#); end if; -- pwr relay 1 off
					if get_field(line,3) = "2"   then write_llc(16#40#,16#04#); end if; -- pwr relay 2 off
					if get_field(line,3) = "3"   then write_llc(16#40#,16#05#); end if; -- pwr relay 3 off
					if get_field(line,3) = "all" then write_llc(16#40#,16#06#); end if; -- all pwr relays off
					if get_field(line,3) = "gnd" then write_llc(16#40#,16#07#); end if; -- gnd pwr relay off
				end if;
			end if;

			-- if a "imax" command found
			if get_field(line,1) = "imax" then -- CS: check field count
				write_llc(16#40#,16#13#); -- set i2c muxer sub bus 3
				prog_position := "IM1";
				power_channel := natural'value(get_field(line,2)); -- get power channel parameter with range check
				prog_position := "IM2"; 
				imax_wanted := float'value(get_field(line,3)); -- get imax parameter with range check
				--put(imax_wanted); new_line;
				ubyte_scratch := unsigned_8(natural(22.4 * (5.7 + imax_wanted))); -- cal. 8bit DAC value
				ubyte_scratch2 := 16#40# + unsigned_8(power_channel);
				-- write llc (40+pwr channel , imax_wanted)
				write_llc(ubyte_scratch2, ubyte_scratch); -- this is an extended I2C operation with data destination imax dac channel x (40+pwr_channel)
				prog_position := "IM3"; 
				--new_line; put("imax ");put(float'value(get_field(line,4))); new_line;
				if get_field(line,4) = "timeout" then imax_timeout := float'value(get_field(line,5)); end if; -- get timeout parameter with range check
				write_llc(16#40#,16#12#); -- set i2c muxer sub bus 2
				ubyte_scratch := unsigned_8(natural(imax_timeout/timeout_resolution)); -- cal. 8bit timeout value
				ubyte_scratch2 := 16#43# + unsigned_8(power_channel);
				write_llc(ubyte_scratch2, ubyte_scratch); -- this is an extended I2C operation with data destination imax timeout channel x (43+pwr_channel)
			end if;

			-- if a "delay" command found
			if get_field(line,1) = "delay" then -- CS: check field count
				prog_position := "DE1";
				delay_wanted := float'value(get_field(line,2));
				ubyte_scratch := unsigned_8(natural(delay_wanted/delay_resolution)); -- calc. 8 bit delay value
				write_llc(16#20#, ubyte_scratch); -- this is a time operation
			end if;

			-- if a "set" command found
			if get_field(line,1) = "set" then -- CS: check filed count
				if get_field(line,4) = "ir" then -- if "ir" found
					if get_field(line,3) = "drv" then -- if "drv" found
						--position 1 is closest to BSC TDO !
						nat_scratch := 1; -- points to device in current chain
						while nat_scratch <= chain(chain_pt).mem_ct
						loop
							-- if the device name from sequence matches the device name in chain
							if get_field(line,2) = chain(chain_pt).members(nat_scratch).device then
								-- sir drv found
								--put_line(chain(chain_pt).members(nat_scratch).device);
								-- check for register-wise assignment of drv value
								prog_position := "ID1";
								if get_field(line,6) /= "downto" then raise constraint_error; end if;

								-- check length of ir drv pattern
								prog_position := "ID2";
								if length(to_unbounded_string(get_field(line,9))) /= chain(chain_pt).members(nat_scratch).irl then raise constraint_error; end if;

								-- save ir drv pattern of particular device
								chain(chain_pt).members(nat_scratch).ir_drv := to_unbounded_string(get_field(line,9));

								-- save instruction name of particular device
								chain(chain_pt).members(nat_scratch).instruction := to_unbounded_string(get_field(line,10));

							end if;
						nat_scratch := nat_scratch + 1; -- go to next member in chain
						end loop;
					end if; -- if "drv" found

					if get_field(line,3) = "exp" then -- if "exp" found
						-- position 1 is closest to BSC TDO !
						nat_scratch := 1; -- points to device in current chain
						while nat_scratch <= chain(chain_pt).mem_ct
						loop

							-- if the device name from sequence matches the device name in chain
							if get_field(line,2) = chain(chain_pt).members(nat_scratch).device then
								-- sir exp found

								-- check for register-wise assignment of exp value
								prog_position := "IE1";
								if get_field(line,6) /= "downto" then raise constraint_error; end if;

								-- check length of ir exp pattern
								prog_position := "IE2";
								if length(to_unbounded_string(get_field(line,9))) /= chain(chain_pt).members(nat_scratch).irl then raise constraint_error; end if;

								-- save ir exp pattern of particular device
								chain(chain_pt).members(nat_scratch).ir_exp := to_unbounded_string(get_field(line,9));
							end if;
						nat_scratch := nat_scratch + 1; -- go to next member in chain
						end loop;
					end if; -- if "exp" found

				end if; -- if "ir" found

				-- if data register found
				if get_field(line,4) = "bypass" or get_field(line,4) = "idcode" or get_field(line,4) = "usercode" or get_field(line,4) = "boundary" then
					if get_field(line,3) = "drv" then -- if "drv" found
						--position 1 is closest to BSC TDO !
						nat_scratch := 1; -- points to device in current chain
						while nat_scratch <= chain(chain_pt).mem_ct
						loop

							-- if the device name from sequence matches the device name in chain
							if get_field(line,2) = chain(chain_pt).members(nat_scratch).device then
								-- sdr drv found
		
								-- what data register is it about ?
								
								-- if bypass register addressed
								if get_field(line,4) = "bypass" then

									-- make sure there is no downto-assignment
									prog_position := "BY1";
									if get_field(line,6) = "downto" then raise constraint_error; end if;

									-- get bypass drv bit of particular device
									prog_position := "BY2";
									if    get_field(line,5) = "1=0" then chain(chain_pt).members(nat_scratch).byp_drv := '0';
									elsif get_field(line,5) = "1=1" then chain(chain_pt).members(nat_scratch).byp_drv := '1';
									else raise constraint_error;
									end if;

								end if;

								-- if idcode register addressed
								if get_field(line,4) = "idcode" then
									-- make sure there IS a downto-assignment
									prog_position := "IC1";
									if get_field(line,6) /= "downto" then raise constraint_error; end if;

									-- check length of id drv pattern
									prog_position := "IC2";
									if length(to_unbounded_string(get_field(line,9))) = 1 then
										-- if a one char pattern found, scale it to desired length, then save it
										chain(chain_pt).members(nat_scratch).idc_drv := to_unbounded_string(scale_pattern(get_field(line,9),idc_length));
									-- if pattern is unequal idc_length, raise error
									elsif length(to_unbounded_string(get_field(line,9))) /= idc_length then raise constraint_error;
									-- otherwise the pattern is specified at full length
									else chain(chain_pt).members(nat_scratch).idc_drv := to_unbounded_string(get_field(line,9)); -- save pattern
									end if;
								end if;

								-- if usercode register addressed
								if get_field(line,4) = "usercode" then
									-- make sure there IS a downto-assignment
									prog_position := "UC1";
									if get_field(line,6) /= "downto" then raise constraint_error; end if;

									-- check length of drv pattern
									prog_position := "UC2";
									if length(to_unbounded_string(get_field(line,9))) = 1 then
										-- if a one char pattern found, scale it to desired length, then save it
										chain(chain_pt).members(nat_scratch).usc_drv := to_unbounded_string(scale_pattern(get_field(line,9),usc_length));
									-- if pattern is unequal usc_length, raise error
									elsif length(to_unbounded_string(get_field(line,9))) /= usc_length then raise constraint_error;
									-- otherwise the pattern is specified at full length
									else chain(chain_pt).members(nat_scratch).usc_drv := to_unbounded_string(get_field(line,9)); -- save pattern
									end if;
								end if;

								-- if boundary register addressed
								if get_field(line,4) = "boundary" then
									-- if there is a downto-assignment
									prog_position := "BO1";
									if get_field(line,6) = "downto" then

										-- check length of drv pattern
										prog_position := "BO2";
										if length(to_unbounded_string(get_field(line,9))) = 1 then
											-- if a one char pattern found, scale it to length of particular bsr, then save it
											chain(chain_pt).members(nat_scratch).bsr_drv := to_unbounded_string(scale_pattern(get_field(line,9),chain(chain_pt).members(nat_scratch).bsl));
										-- if pattern is unequal length or particular bsr, raise error
										elsif length(to_unbounded_string(get_field(line,9))) /= chain(chain_pt).members(nat_scratch).bsl then raise constraint_error;
										-- otherwise the pattern is specified at full length
										else chain(chain_pt).members(nat_scratch).bsr_drv := to_unbounded_string(get_field(line,9)); -- save pattern
										end if;
									else
									-- if bitwise assignment found
									-- read assigments starting from field 5
									field_pt := 5;
									field_ct := get_field_count(line);
									while field_pt <= field_ct
									loop
										-- get cell number to address
										cell_pt := natural'value ( get_field ( to_unbounded_string(get_field(line,field_pt)) ,1,'=') );
										prog_position := "BO3";
										cell_pt := chain(chain_pt).members(nat_scratch).bsl - cell_pt; -- mirror cell pointer (bsl - cell_pt)

										-- get cell value
										prog_position := "BO4";
										cell_content := ( get_field ( to_unbounded_string(get_field(line,field_pt)) ,2,'=') );
										-- check cell value
										if is_in( cell_content(cell_content'first), bit_char ) = false then raise constraint_error; end if;

										-- save cell value at position of bsr of current device
										replace_element (chain(chain_pt).members(nat_scratch).bsr_drv , cell_pt, cell_content(cell_content'first));
										field_pt := field_pt + 1;
									end loop;
									end if;

								end if; -- if boundary register addressed

							end if; -- if the device name from sequence matches the device name in chain

						nat_scratch := nat_scratch + 1; -- go to next member in chain
						end loop;
					end if; -- if "drv" found

					if get_field(line,3) = "exp" then -- if "exp" found
						--position 1 is closest to BSC TDO !
						nat_scratch := 1; -- points to device in current chain
						while nat_scratch <= chain(chain_pt).mem_ct
						loop

							-- if the device name from sequence matches the device name in chain
							if get_field(line,2) = chain(chain_pt).members(nat_scratch).device then
								-- sdr exp found
								-- what data register is it about ?
								
								-- if bypass register addressed
								if get_field(line,4) = "bypass" then

									-- make sure there is no downto-assignment
									prog_position := "BY5";
									if get_field(line,6) = "downto" then raise constraint_error; end if;

									-- get bypass exp bit of particular device
									prog_position := "BY6";
									if    get_field(line,5) = "1=0" then chain(chain_pt).members(nat_scratch).byp_exp := '0'; --put_line("exp");
									elsif get_field(line,5) = "1=1" then chain(chain_pt).members(nat_scratch).byp_exp := '1';
									else raise constraint_error;
									end if;

								end if;

								-- if idcode register addressed
								if get_field(line,4) = "idcode" then
									-- make sure there IS a downto-assignment
									prog_position := "IC5";
									if get_field(line,6) /= "downto" then raise constraint_error; end if;

									-- check length of id exp pattern
									prog_position := "IC6";
									if length(to_unbounded_string(get_field(line,9))) = 1 then
										-- if a one char pattern found, scale it to desired length, then save it
										chain(chain_pt).members(nat_scratch).idc_exp := to_unbounded_string(scale_pattern(get_field(line,9),idc_length));
									-- if pattern is unequal idc_length, raise error
									elsif length(to_unbounded_string(get_field(line,9))) /= idc_length then raise constraint_error;
									-- otherwise the pattern is specified at full length
									else chain(chain_pt).members(nat_scratch).idc_exp := to_unbounded_string(get_field(line,9)); -- save pattern
									end if;
								end if;

								-- if usercode register addressed
								if get_field(line,4) = "usercode" then
									-- make sure there IS a downto-assignment
									prog_position := "UC5";
									if get_field(line,6) /= "downto" then raise constraint_error; end if;

									-- check length of exp pattern
									prog_position := "UC6";
									if length(to_unbounded_string(get_field(line,9))) = 1 then
										-- if a one char pattern found, scale it to desired length, then save it
										chain(chain_pt).members(nat_scratch).usc_exp := to_unbounded_string(scale_pattern(get_field(line,9),usc_length));
									-- if pattern is unequal usc_length, raise error
									elsif length(to_unbounded_string(get_field(line,9))) /= usc_length then raise constraint_error;
									-- otherwise the pattern is specified at full length
									else chain(chain_pt).members(nat_scratch).usc_exp := to_unbounded_string(get_field(line,9)); -- save pattern
									end if;
								end if;

								-- if boundary register addressed
								if get_field(line,4) = "boundary" then
									-- if there is a downto-assignment
									prog_position := "BO5";
									if get_field(line,6) = "downto" then

										-- check length of exp pattern
										prog_position := "BO6";
										if length(to_unbounded_string(get_field(line,9))) = 1 then
											-- if a one char pattern found, scale it to length of particular bsr, then save it
											chain(chain_pt).members(nat_scratch).bsr_exp := to_unbounded_string(scale_pattern(get_field(line,9),chain(chain_pt).members(nat_scratch).bsl));
										-- if pattern is unequal length or particular bsr, raise error
										elsif length(to_unbounded_string(get_field(line,9))) /= chain(chain_pt).members(nat_scratch).bsl then raise constraint_error;
										-- otherwise the pattern is specified at full length
										else chain(chain_pt).members(nat_scratch).bsr_exp := to_unbounded_string(get_field(line,9)); -- save pattern
										end if;
									else
									-- if bitwise assignment found
									-- read assigments starting from field 5
									field_pt := 5;
									field_ct := get_field_count(line);
									while field_pt <= field_ct
									loop
										-- get cell number to address
										cell_pt := natural'value ( get_field ( to_unbounded_string(get_field(line,field_pt)) ,1,'=') );
										prog_position := "BO7";
										cell_pt := chain(chain_pt).members(nat_scratch).bsl - cell_pt; -- mirror cell pointer (bsl - cell_pt)

										-- get cell value
										prog_position := "BO8";
										cell_content := ( get_field ( to_unbounded_string(get_field(line,field_pt)) ,2,'=') );
										-- check cell value
										if is_in( cell_content(cell_content'first), bit_char ) = false then raise constraint_error; end if;

										-- save cell value at position of bsr of current device
										replace_element (chain(chain_pt).members(nat_scratch).bsr_exp , cell_pt, cell_content(cell_content'first));
										field_pt := field_pt + 1;
									end loop;
									end if;

								end if; -- if boundary register addressed

							end if; -- if the device name from sequence matches the device name in chain

						nat_scratch := nat_scratch + 1; -- go to next member in chain
						end loop;
					end if; -- if "exp" found

				end if; -- if data register found
			end if; -- if "set" command found

			-- if sir found
			if get_field(line,1) = "sir" then -- CS: check id ?
				vector_id := vector_id_type(natural'value(get_field(line,3)));

				-- reset chain ir drv image
				chain(chain_pt).ir_drv_all := to_unbounded_string("");
				-- reset chain ir exp image
				chain(chain_pt).ir_exp_all := to_unbounded_string("");

				-- chaining sir drv patterns starting with device closest to BSC TDO !
				nat_scratch := 1;
				while nat_scratch <= chain(chain_pt).mem_ct -- process number of devices in current chain
				loop
					-- chain up ir drv patterns
					chain(chain_pt).ir_drv_all := chain(chain_pt).ir_drv_all & chain(chain_pt).members(nat_scratch).ir_drv;

					-- chain up ir exp patterns
					chain(chain_pt).ir_exp_all := chain(chain_pt).ir_exp_all & chain(chain_pt).members(nat_scratch).ir_exp;

					Set_Output(chain(chain_pt).reg_file);
					put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " ir");
					Set_Output(standard_output);

					nat_scratch := nat_scratch + 1; -- go to next member in chain
				end loop;

				-- check option "retry"
				check_option_retry;

				-- make binary drive vector
				-- debug new_line; put_line("sir drv: " & chain(chain_pt).ir_drv_all & " " & trailer_ir);
				make_binary_vector
					(
					sir_sdr =>"sir",
					drv_exp => "drv",
					id => vector_id,
					vector_string => chain(chain_pt).ir_drv_all & trailer_ir, -- trailer must be attached to the lower end of a drv vector
					-- NOTE: vector_string is mirrored: LSB left, MSB right
					retries => ubyte_scratch,
					retry_delay => ubyte_scratch2
					);

				-- make binary expect and mask vector
				-- debug new_line; put_line("sir exp: " & trailer_ir & " " & chain(chain_pt).ir_exp_all);
				make_binary_vector
					(
					sir_sdr =>"sir",
					drv_exp => "exp",
					vector_string => trailer_ir & chain(chain_pt).ir_exp_all -- trailer must be attached to the upper end of a expect vector
					-- NOTE: vector_string is mirrored: LSB left, MSB right
					);

			end if; -- if sir found


			-- if sdr found
			if get_field(line,1) = "sdr" then -- CS: check id ?
				vector_id := vector_id_type(natural'value(get_field(line,3)));

				-- reset chain dr drv image
				chain(chain_pt).dr_drv_all := to_unbounded_string("");
				-- reset chain dr exp image
				chain(chain_pt).dr_exp_all := to_unbounded_string("");

				-- chaining sdr drv and exp patterns starting with device closest to BSC TDO !
				-- use drv pattern depending on latest loaded instruction of particular device
				nat_scratch := 1;
				while nat_scratch <= chain(chain_pt).mem_ct -- process number of devices in current chain
				loop
					-- chain up dr drv/exp patterns
					if chain(chain_pt).members(nat_scratch).instruction = "bypass" then
						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).byp_drv;
						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).byp_exp;

						Set_Output(chain(chain_pt).reg_file);
						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " bypass");
						Set_Output(standard_output);
					end if;

					if chain(chain_pt).members(nat_scratch).instruction = "idcode" then
						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).idc_drv;
						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).idc_exp;

						Set_Output(chain(chain_pt).reg_file);
						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " idcode");
						Set_Output(standard_output);
					end if;

					if chain(chain_pt).members(nat_scratch).instruction = "usercode" then
						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).usc_drv;
						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).usc_exp;

						Set_Output(chain(chain_pt).reg_file);
						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " usercode");
						Set_Output(standard_output);
					end if;

					if chain(chain_pt).members(nat_scratch).instruction = "sample" then
						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).bsr_drv;
						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).bsr_exp;

						Set_Output(chain(chain_pt).reg_file);
						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " boundary");
						Set_Output(standard_output);
					end if;

					if chain(chain_pt).members(nat_scratch).instruction = "extest" then
						chain(chain_pt).dr_drv_all := chain(chain_pt).dr_drv_all & chain(chain_pt).members(nat_scratch).bsr_drv;
						chain(chain_pt).dr_exp_all := chain(chain_pt).dr_exp_all & chain(chain_pt).members(nat_scratch).bsr_exp;

						Set_Output(chain(chain_pt).reg_file);
						put_line("step" & natural'image(vector_id) & " device" & natural'image(nat_scratch) & " boundary");
						Set_Output(standard_output);
					end if;

					nat_scratch := nat_scratch + 1; -- go to next member in chain
				end loop;

				-- check option "retry"
				check_option_retry;

				--make_binary_vector sdr drv ${chain_pt} ${seq[2]} $sdr_drv$trailer_dr $retries $retry_delay #ins V3.5

				-- make binary drive vector
				make_binary_vector
					(
					sir_sdr =>"sdr",
					drv_exp => "drv",
					id => vector_id,
					vector_string => chain(chain_pt).dr_drv_all & trailer_dr, -- trailer must be attached to the lower end of a drv vector
					-- NOTE: vector_string is mirrored: LSB left, MSB right
					retries => ubyte_scratch,
					retry_delay => ubyte_scratch2
					);

				-- make binary expect and mask vector
				make_binary_vector
					(
					sir_sdr =>"sdr",
					drv_exp => "exp",
					vector_string => trailer_dr & chain(chain_pt).dr_exp_all -- trailer must be attached to the upper end of a expect vector
					-- NOTE: vector_string is mirrored: LSB left, MSB right
					);

			end if; -- if sdr found

		end loop;
		exception when constraint_error =>
			new_line(2);
			--put("ERROR in line" & natural'image(line_ct) & " : ");
			put("ERROR in sequence" & natural'image(sequence_pt) & " : ");
			--put("ERROR : ");
			if prog_position = "IM1" then put_line("There are only" & natural'image(power_channel_ct) & " channels available for current watch/monitoring."); end if;
			--if prog_position = "IM2" then put_line("ERROR ! 'imax' must be between 0.1 and" & float'image(imax) & " Amps !"); end if;
			if prog_position = "IM2" then 
				put("Parameter for 'imax' must be between 0.1 and"); put(imax, aft => 1, exp => 0); put(" Amps !"); new_line;
			end if;
			if prog_position = "IM3" then 
				put("Parameter for 'timeout' must be between");
				put(imax_timeout_min, aft => 2, exp => 0); put(" and");
				put(imax_timeout_max, aft => 2, exp => 0);
				put(" sec !"); new_line;
			end if;
			if prog_position = "DE1" then 
				put("Parameter for 'delay' must be between");
				put(delay_min, aft => 2, exp => 0); put(" and ");
				put(delay_max, aft => 2, exp => 0);
				put(" sec !"); new_line;
			end if;
			if prog_position = "ID1" then
				put_line("Bitwise assignments for INSTRUCTION register drive not supported !");
			end if;
			if prog_position = "ID2" then 
				put_line("Instruction drive pattern length mismatch !"); 
			end if;
			if prog_position = "IE1" then
				put_line("Bitwise assignments for INSTRUCTION register capture not supported !");
			end if;
			if prog_position = "IE2" then 
				put_line("Instruction capture pattern length mismatch !"); 
			end if;
			if prog_position = "BY1" then 
				put_line("Downto-assignments for BYPASS register drive not allowed !");
			end if;
			if prog_position = "BY2" then 
				put_line("Missing or illegal BYPASS register drive assignment !");
			end if;
			if prog_position = "BY5" then 
				put_line("Downto-assignments for BYPASS register expect not allowed !");
			end if;
			if prog_position = "BY6" then 
				put_line("Missing or illegal BYPASS register expect assignment !");
			end if;
			if prog_position = "IC1" then 
				put_line("Downto-assignment required for IDCODE register drive !");
			end if;
			if prog_position = "IC2" then 
				put_line("IDCODE register drive pattern length mismatch !");
			end if;
			if prog_position = "IC5" then 
				put_line("Downto-assignment required for IDCODE register expect !");
			end if;
			if prog_position = "IC6" then 
				put_line("IDCODE register expect pattern length mismatch !");
			end if;
			if prog_position = "UC1" then 
				put_line("Downto-assignment required for USERCODE register drive !");
			end if;
			if prog_position = "UC2" then 
				put_line("USERCODE register drive pattern length mismatch !");
			end if;
			if prog_position = "UC5" then 
				put_line("Downto-assignment required for USERCODE register expect !");
			end if;
			if prog_position = "UC6" then 
				put_line("USERCODE register expect pattern length mismatch !");
			end if;
			if prog_position = "BO2" then 
				put_line("BOUNDARY register drive pattern length mismatch !");
			end if;
			if prog_position = "BO6" then 
				put_line("BOUNDARY register expect pattern length mismatch !");
			end if;
			if prog_position = "BO3" or prog_position = "BO7" then 
				put_line("Invalid cell number !");
				put_line("BOUNDARY register cell " & get_field ( to_unbounded_string(get_field(line,field_pt)) ,1,'=') & " does not exist !");
			end if;
			if prog_position = "BO4" or prog_position = "BO8" then 
				put_line("Invalid BOUNDARY register cell assignment: " & get_field(line,field_pt));
				put_line("Values to assign are: 0,1 or x");
			end if;
			if prog_position = "SC1" then
				put_line("Illegal character found. Allowed are 0,1,x");
			end if;
			if prog_position = "SC2" then
				put_line("Only one character allowed for pattern scaling !");
			end if;
			if prog_position = "RE1" then
				put_line("Retry specification invalid !");
				put_line("Max. retry count is" & natural'image(retry_ct_max));
				put("Max. delay is "); put(retry_delay_max, exp => 0 , aft => 1); put(" sec"); new_line;
				put_line("Example for an sir with ID 7, 3 retries with 0.5sec delay inbetween: sir 7 option retry 3 delay 0.5");
			end if;


			put_line("Affected line reads: " & line);
			raise constraint_error; -- propagate exception to mainline program

				--put_line("ERROR  : There are only" & natural'image(power_channel_ct) & "channels available for current watch/monitoring.");
	end read_sequence_file;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin



	dummy := umask ( 003 );

	clean_up_tmp_dir;

	-- clean up test_directory
	if exists(to_string(test_name) & "/" & to_string(test_name) & ".reg") then delete_file(to_string(test_name) & "/" & to_string(test_name) & ".reg"); end if; -- delete stale reg file


	scratch:=to_unbounded_string(Argument(1));
	put_line ("database       : " & scratch);
	data_base := scratch;

--  	Open( 
--  		File => database,
--  		Mode => In_File,
--  		Name => to_string(scratch)
--  		);
--  	--Set_Input(netlist_file);

	scratch:=to_unbounded_string(Argument(2));
	put_line ("test name      : " & scratch);
	test_name := scratch;

	-- create vectorfile
	scratch := scratch & "/" & scratch & ".vec";
	seq_io_unsigned_byte.Create( VectorFile, seq_io_unsigned_byte.out_file, Name => to_string(scratch)); --close(vectorfile);
	size_of_vec_file := Natural'Value(file_size'image(size(to_string(scratch))));
	--put (size_of_vec_file);

	-- read journal
	if exists ("setup/journal.txt") then -- if there is a journal, find last entry
		prog_position := "JO1";
		Open( 
			File => tmp_file,
			Mode => in_File,
			Name => "setup/journal.txt"
			);
		set_input(tmp_file);
		lp := 0; -- line pointer, required to evaluate lines with number greater 2
		while not end_of_file
			loop
				lp := lp + 1; -- count lines
				line := get_line;
				--put_line(line);
				--Put( Integer'Image( Integer'Value("16#1A2B3C#") ) );  

				if lp > 2 then
					last_dest_addr := Integer'Value("16#" & get_field(line,2) & "#");  	-- last_dest_addr is a hex number !!!
					last_size := Integer'Value(get_field(line,3));  					-- last_size is a dec number !!!
				end if;


			end loop;
			prog_position := "JO2";
			next_dest_addr := (last_dest_addr + last_size); -- calc next_dest_addr
			--next_dest_addr := 185344;
			-- round addr up to multiple of 256
			while (next_dest_addr rem 256) /= 0
				loop
					next_dest_addr := next_dest_addr + 1;
				end loop;
			--set_output(standard_output);
			--put_line("compiling for destination address: " & natural'image(next_dest_addr));
			--put(mem_size);
			-- check if there is space left for vector file in BSC RAM
			prog_position := "ME1";
			if next_dest_addr >= mem_size then 
				put_line("ERROR: available address range exceeded !");
				raise constraint_error; 
			end if;
			--set_input(tmp_file);

			set_input(standard_input);
			close(tmp_file);
		-- if no journal found, default to start address 0
		else next_dest_addr := 0;
	end if;


	prog_position := "FR1";
	remove_comments_from_file(to_string(data_base),"tmp/udb_no_comments.tmp");
	extract_section("tmp/udb_no_comments.tmp", "tmp/spc.tmp", "Section" , "EndSection" , "scanpath_configuration");

	-- write all chain sections of tmp/spc.tmp in tmp/chain.tmp
  	Open( 
  		File => tmp_file,
  		Mode => in_file,
  		Name => "tmp/spc.tmp"
  		);
 	set_input(tmp_file);

	Create( chain_file, Name => "tmp/chain.tmp"); close(chain_file);
 	Open( 
 		File => chain_file,
 		Mode => out_file,
 		Name => "tmp/chain.tmp"
 		);
	set_output(chain_file);

	prog_position := "FR2";
	while not end_of_file
	loop
		line := get_line;
		if get_field(line,1) = "SubSection" and get_field(line,2) = "chain" then chain_section_entered := true; end if;
		if chain_section_entered then put_line(line); end if;
		if get_field(line,1) = "EndSubSection" then chain_section_entered := false; end if;
	end loop;
	set_output(standard_output); set_input(standard_input);
	close(chain_file); close(tmp_file);

	-- extract options
	prog_position := "FR3";
	extract_section(to_string(test_name) & "/" & to_string(test_name) & ".seq", "tmp/options.tmp", "Section" , "EndSection" , "options");
	-- extract registers
	extract_section("tmp/udb_no_comments.tmp", "tmp/registers.tmp", "Section" , "EndSection" , "registers");

 	Open( 
 		File => optionsfile,
 		Mode => in_file,
 		Name => "tmp/options.tmp"
 		);
	set_input(optionsfile);

	-- read options
	prog_position := "OP1";
	while not end_of_file
		loop
			line := get_line;
			if get_field(line,1) = "trailer_ir" then
				prog_position := "TI1";
				--nat_scratch := natural'value("2#" & get_field(line,2) & "#"); -- make natural from trailer field
				trailer_ir := get_field(line,2); -- unsigned_8(nat_scratch); -- make unsigned_byte from natural
			end if;
			if get_field(line,1) = "trailer_dr" then
				prog_position := "TD1";
				--nat_scratch := natural'value("2#" & get_field(line,2) & "#"); -- make natural from trailer field
				trailer_dr := get_field(line,2); --unsigned_8(nat_scratch); -- make unsigned_byte from natural
			end if;
			if get_field(line,1) = "on_fail" then on_fail := to_unbounded_string(get_field(line,2)); end if;
			if get_field(line,1) = "frequency" then 
				prog_position := "FR1";
				frequency_dec := natural'value(get_field(line,2));
				if frequency_dec > frequency_max then
					put_line("WARNING: Maximal supported frequency is " & natural'image(frequency_max) & " Mhz !");
					frequency_dec := 4;
				end if;

				-- convert frequency_dec to prescaler value
				case frequency_dec is
					when 4 => frequency_hex 		:= 16#FF#;
					when 3 => frequency_hex 		:= 16#FE#;
					when 2 => frequency_hex 		:= 16#FD#;
					when 1 => frequency_hex 		:= 16#F8#;
					when others => frequency_hex 	:= 16#00#;
				end case;
			end if;

			-- read scan port 1 voltage
			if get_field(line,1) = "voltage_out_port_1" then 
				prog_position := "VC1";
				vcc := float'value(get_field(line,2));
				if vcc < vcc_min or vcc > vcc_max then
					put_line("ERROR  : Scan port 1 output voltage must be between +1.8V and +3.3V");
					raise constraint_error;
				end if;

				-- calc. vcc by DAC resolution and full-scale
				-- convert vcc to natural, then to unsigned_byte (later required as hex number by DAC)
				vcc := (vcc * 255.0)/3.3;
				vcc_1 := unsigned_8(natural(vcc));
			end if;

			-- read scan port 2 voltage
			if get_field(line,1) = "voltage_out_port_2" then 
				prog_position := "VC2";
				vcc := float'value(get_field(line,2));
				if vcc < vcc_min or vcc > vcc_max then
					put_line("ERROR  : Scan port 2 output voltage must be between +1.8V and +3.3V");
					raise constraint_error;
				end if;

				-- calc. vcc by DAC resolution and full-scale
				-- convert vcc to natural, then to unsigned_byte (later required as hex number by DAC)
				vcc := (vcc * 255.0)/3.3;
				vcc_2 := unsigned_8(natural(vcc));
			end if;

			-- read tdi 1 threshold voltage
			if get_field(line,1) = "threshold_tdi_port_1" then 
				prog_position := "TH1";
				thi := float'value(get_field(line,2));
				if thi > thi_max or thi < 0.0 then
					--put(thi); new_line;
					put_line("ERROR  : Scan port 1 TDI threshold voltage must be between 0V and +3.3V");
					raise constraint_error;
				end if;

				-- calc. thi by DAC resolution and full-scale
				-- convert thi to natural, then to unsigned_byte (later required as hex number by DAC)
				thi := (thi * 255.0)/3.3;
				thi_1 := unsigned_8(natural(thi));
			end if;

			-- read tdi 2 threshold voltage
			if get_field(line,1) = "threshold_tdi_port_2" then 
				prog_position := "TH2";
				thi := float'value(get_field(line,2));
				if thi > thi_max or thi < 0.0 then
					put_line("ERROR  : Scan port 2 TDI threshold voltage must be between 0V and +3.3V");
					raise constraint_error;
				end if;

				-- calc. thi by DAC resolution and full-scale
				-- convert thi to natural, then to unsigned_byte (later required as hex number by DAC)
				thi := (thi * 255.0)/3.3;
				thi_2 := unsigned_8(natural(thi));
			end if;

			-- read tck_driver_port_1 characteristic
			if get_field(line,1) = "tck_driver_port_1" then 
				if get_field(line,2) = "push-pull" then tck1_drv_char	:= 16#06#; end if;
				if get_field(line,2) = "weak1" then tck1_drv_char 		:= 16#01#; end if;
				if get_field(line,2) = "weak0" then tck1_drv_char 		:= 16#02#; end if;
				if get_field(line,2) = "tie_low" then tck1_drv_char 	:= 16#04#; end if;
				if get_field(line,2) = "tie_high" then tck1_drv_char 	:= 16#05#; end if;
				if get_field(line,2) = "high-z" then tck1_drv_char 		:= 16#03#; end if;
			end if;

			-- read tms_driver_port_1 characteristic
			if get_field(line,1) = "tms_driver_port_1" then 
				if get_field(line,2) = "push-pull" then tms1_drv_char	:= 16#30#; end if;
				if get_field(line,2) = "weak1" then tms1_drv_char 		:= 16#08#; end if;
				if get_field(line,2) = "weak0" then tms1_drv_char 		:= 16#10#; end if;
				if get_field(line,2) = "tie_low" then tms1_drv_char 	:= 16#20#; end if;
				if get_field(line,2) = "tie_high" then tms1_drv_char 	:= 16#28#; end if;
				if get_field(line,2) = "high-z" then tms1_drv_char 		:= 16#18#; end if;
			end if;

			-- read tdo_driver_port_1 characteristic
			if get_field(line,1) = "tdo_driver_port_1" then 
				if get_field(line,2) = "push-pull" then tdo1_drv_char	:= 16#06#; end if;
				if get_field(line,2) = "weak1" then tdo1_drv_char 		:= 16#01#; end if;
				if get_field(line,2) = "weak0" then tdo1_drv_char 		:= 16#02#; end if;
				if get_field(line,2) = "tie_low" then tdo1_drv_char 	:= 16#04#; end if;
				if get_field(line,2) = "tie_high" then tdo1_drv_char 	:= 16#05#; end if;
				if get_field(line,2) = "high-z" then tdo1_drv_char 		:= 16#03#; end if;
			end if;

			-- read trst_driver_port_1 characteristic
			if get_field(line,1) = "trst_driver_port_1" then 
				if get_field(line,2) = "push-pull" then trst1_drv_char	:= 16#30#; end if;
				if get_field(line,2) = "weak1" then trst1_drv_char 		:= 16#08#; end if;
				if get_field(line,2) = "weak0" then trst1_drv_char 		:= 16#10#; end if;
				if get_field(line,2) = "tie_low" then trst1_drv_char 	:= 16#20#; end if;
				if get_field(line,2) = "tie_high" then trst1_drv_char 	:= 16#28#; end if;
				if get_field(line,2) = "high-z" then trst1_drv_char 	:= 16#18#; end if;
			end if;

			-- read tck_driver_port_2 characteristic
			if get_field(line,1) = "tck_driver_port_2" then 
				if get_field(line,2) = "push-pull" then tck2_drv_char	:= 16#06#; end if;
				if get_field(line,2) = "weak1" then tck2_drv_char 		:= 16#01#; end if;
				if get_field(line,2) = "weak0" then tck2_drv_char 		:= 16#02#; end if;
				if get_field(line,2) = "tie_low" then tck2_drv_char 	:= 16#04#; end if;
				if get_field(line,2) = "tie_high" then tck2_drv_char 	:= 16#05#; end if;
				if get_field(line,2) = "high-z" then tck2_drv_char 		:= 16#03#; end if;
			end if;

			-- read tms_driver_port_2 characteristic
			if get_field(line,1) = "tms_driver_port_2" then 
				if get_field(line,2) = "push-pull" then tms2_drv_char	:= 16#30#; end if;
				if get_field(line,2) = "weak1" then tms2_drv_char 		:= 16#08#; end if;
				if get_field(line,2) = "weak0" then tms2_drv_char 		:= 16#10#; end if;
				if get_field(line,2) = "tie_low" then tms2_drv_char 	:= 16#20#; end if;
				if get_field(line,2) = "tie_high" then tms2_drv_char 	:= 16#28#; end if;
				if get_field(line,2) = "high-z" then tms2_drv_char 		:= 16#18#; end if;
			end if;

			-- read tdo_driver_port_2 characteristic
			if get_field(line,1) = "tdo_driver_port_2" then 
				if get_field(line,2) = "push-pull" then tdo2_drv_char	:= 16#06#; end if;
				if get_field(line,2) = "weak1" then tdo2_drv_char 		:= 16#01#; end if;
				if get_field(line,2) = "weak0" then tdo2_drv_char 		:= 16#02#; end if;
				if get_field(line,2) = "tie_low" then tdo2_drv_char 	:= 16#04#; end if;
				if get_field(line,2) = "tie_high" then tdo2_drv_char 	:= 16#05#; end if;
				if get_field(line,2) = "high-z" then tdo2_drv_char 		:= 16#03#; end if;
			end if;

			-- read trst_driver_port_2 characteristic
			if get_field(line,1) = "trst_driver_port_2" then 
				if get_field(line,2) = "push-pull" then trst2_drv_char	:= 16#30#; end if;
				if get_field(line,2) = "weak1" then trst2_drv_char 		:= 16#08#; end if;
				if get_field(line,2) = "weak0" then trst2_drv_char 		:= 16#10#; end if;
				if get_field(line,2) = "tie_low" then trst2_drv_char 	:= 16#20#; end if;
				if get_field(line,2) = "tie_high" then trst2_drv_char 	:= 16#28#; end if;
				if get_field(line,2) = "high-z" then trst2_drv_char 	:= 16#18#; end if;
			end if;

		end loop; -- read options

	-- mirror trailers
-- 	prog_position := "MT1";
-- 	nat_scratch := 1;
-- 	while nat_scratch <= 8
-- 		loop
-- 			string8_scratch(9 - nat_scratch) := trailer_ir(nat_scratch);
-- 			nat_scratch := nat_scratch + 1;
-- 		end loop;
-- 	trailer_ir := string8_scratch;
-- 
-- 	prog_position := "MT2";
-- 	nat_scratch := 1;
-- 	while nat_scratch <= 8
-- 		loop
-- 			string8_scratch(9 - nat_scratch) := trailer_dr(nat_scratch);
-- 			nat_scratch := nat_scratch + 1;
-- 		end loop;
-- 	trailer_dr := string8_scratch;
	-- mirror trailers done

	-- write options in vec file
	if frequency_hex = 0 then put_line("WARNING: frequency option invalid or missing. Falling back to safest frequency of 33 khz ..."); end if;

	seq_io_unsigned_byte.write(vectorfile,frequency_hex);
	seq_io_unsigned_byte.write(vectorfile,thi_1);
	seq_io_unsigned_byte.write(vectorfile,thi_2);
	seq_io_unsigned_byte.write(vectorfile,vcc_1);
	seq_io_unsigned_byte.write(vectorfile,vcc_2);
	seq_io_unsigned_byte.write(vectorfile,tck1_drv_char + tms1_drv_char); -- sum up drv characteristics of tck an tms to a single byte
	seq_io_unsigned_byte.write(vectorfile,tdo1_drv_char + trst1_drv_char); -- sum up drv characteristics of tdo an trst to a single byte
	seq_io_unsigned_byte.write(vectorfile,tck2_drv_char + tms2_drv_char); -- sum up drv characteristics of tck an tms to a single byte
	seq_io_unsigned_byte.write(vectorfile,tdo2_drv_char + trst2_drv_char); -- sum up drv characteristics of tdo an trst to a single byte
	seq_io_unsigned_byte.write(vectorfile,16#FF#); -- port 1 all relays off, ignored by executor
   	seq_io_unsigned_byte.write(vectorfile,16#FF#); -- port 2 all relays off, ignored by executor
	seq_io_unsigned_byte.close(vectorfile);
	-- options write done


	-- read chains and fill chain array with chain name, members, device names, irl and bsl
 	Open( 
 		File => tmp_file,
 		Mode => in_file,
 		Name => "tmp/chain.tmp"
 		);
	set_input(tmp_file);

	Open( 
		File => reg_file,
		Mode => in_file,
		Name => "tmp/registers.tmp"
		);
	
	while not end_of_file
		loop
			line := get_line;
			if get_field(line,1) = "SubSection" then
				chain_ct := chain_ct + 1; -- count chains on each occurence of "SubSection" from top to bottom of chain.tmp
				chain(chain_ct).name := to_unbounded_string(get_field(line,3)); -- read chain name
			end if;

			-- if line is not empty and does not start with SubSection or EndSubSection, it is a device entry
			if get_field_count(line) > 0 and get_field(line,1) /= "SubSection" and get_field(line,1) /= "EndSubSection" then
				-- count members of particular chain on each entry from top to bottom of chain.tmp
				chain(chain_ct).mem_ct := chain(chain_ct).mem_ct + 1;
				-- read device names of particular chain
				-- use chain(chain_ct).mem_ct as pointer to chain member
				chain(chain_ct).members ( chain(chain_ct).mem_ct ).device := to_unbounded_string(get_field(line,1));

				-- read irl and bsl of current device from register file
 				set_input(reg_file); reset(reg_file);
				device_register_section_entered := false;
				while not end_of_file
				loop
					reg_line := get_line;
					-- set device_register_section_entered flag if device section entered in register file
					if get_field(reg_line,1) = "SubSection" and get_field(reg_line,2) = chain(chain_ct).members ( chain(chain_ct).mem_ct ).device then
						device_register_section_entered := true;
					end if;

					-- if inside a device section, read irl and bsl
					if device_register_section_entered then 
						if get_field(reg_line,1) = "instruction_register_length" then
							chain(chain_ct).members ( chain(chain_ct).mem_ct ).irl := natural'value(get_field(reg_line,2));
						end if;
						if get_field(reg_line,1) = "boundary_register_length" then
							chain(chain_ct).members ( chain(chain_ct).mem_ct ).bsl := natural'value(get_field(reg_line,2));
						end if;
					end if;

					-- clear device_register_section_entered flag if device section left in register file
					if get_field(reg_line,1) = "EndSubSection" and get_field(reg_line,2) = chain(chain_ct).members ( chain(chain_ct).mem_ct ).device then
						device_register_section_entered := false;
					end if;

				end loop;
				-- reading from register file done

				set_input(tmp_file);
			end if;

		end loop;
	close(tmp_file);
	-- read chains and fill chain array with chain name, members, device names, irl and bsl done


	-- create reg files in test_directory
	-- CS: where to write the chain name ?
	set_output(standard_output);
	put_line("found" & natural'image(chain_ct) & " scan chain(s) ...");
	nat_scratch := 1; -- points to chain being processed
	while nat_scratch <= chain_ct
	loop
		-- create members_x.reg file for each chain
--		Create( tmp_file, Name => (to_string(test_name) & "/members_" & trim(natural'image(nat_scratch), side => left) & ".reg"));
		Create( chain(nat_scratch).reg_file, Name => (to_string(test_name) & "/members_" & trim(natural'image(nat_scratch), side => left) & ".reg"));
		Set_Output(chain(nat_scratch).reg_file);
		--put_line("test");

		-- write device and register info in current members_x.reg file
		nat_scratch2 := 1;
		while nat_scratch2 <= chain(nat_scratch).mem_ct -- get the members count to process from chain(chain_ct).mem_ct
		loop
			-- write something like: "device 1 IC301 irl 8 bsl 108" in the reg file
			put_line("device" & natural'image(nat_scratch2) & " " & chain(nat_scratch).members(nat_scratch2).device & " irl" & natural'image(chain(nat_scratch).members(nat_scratch2).irl) & " bsl" & natural'image(chain(nat_scratch).members(nat_scratch2).bsl));
			-- sum up irl of chain members , CS: assumption is that no device is bypassed or added in the chain later
			chain(nat_scratch).irl_total := chain(nat_scratch).irl_total + chain(nat_scratch).members(nat_scratch2).irl;
			nat_scratch2 := nat_scratch2 + 1; -- go to next member of current chain
		end loop;
		--close (tmp_file); -- close current reg file

		nat_scratch := nat_scratch + 1; -- go to next chain
	end loop;


	-- remove comments from seq file
	set_output(standard_output);
	set_input(standard_input);
	remove_comments_from_file(to_string(test_name) & "/" & to_string(test_name) & ".seq","tmp/seq_no_comments.tmp");

	-- extract sequences from seq file
 	Open( 
 		File => tmp_file,
 		Mode => in_file,
 		Name => "tmp/seq_no_comments.tmp"
 		);
	set_input(tmp_file);
	
	-- count sequences in seq file
	while not end_of_file
	loop
		line := get_line;
		if get_field(line,1) = "Section" and get_field(line,2) = "sequence" then
			sequence_ct := sequence_ct + 1;
		end if;
	end loop;
	put_line("found" & natural'image(sequence_ct) & " sequence(s) ...");
	set_input(standard_input);
	close(tmp_file);

	-- extract sequences in sequence_x.tmp file
	nat_scratch := 1;
	while nat_scratch <= sequence_ct
	loop
		extract_section
			(
			"tmp/seq_no_comments.tmp", -- input file
			"tmp/sequence_" & trim(natural'image(nat_scratch), side => left) & ".tmp", -- output file i.e. tmp/sequence_1.tmp
			section_begin_1 => "Section",
			section_begin_2 => "sequence",
			section_begin_3 => trim(natural'image(nat_scratch), side => left), -- start line is i.e. "Section sequence 1"
			section_end_1 => "EndSection"
			);
		nat_scratch := nat_scratch + 1; -- go to next sequence
	end loop;


	-- write vector file header
 
 	put("compiling chain");

	seq_io_unsigned_byte.Create( VectorFileHead, seq_io_unsigned_byte.out_file, Name => "tmp/vec_header.tmp");

	--separate major and minor compiler version and write in VectorFileHead
	nat_scratch := natural'value(get_field(to_unbounded_string(version),1,'.')); -- major number
	ubyte_scratch := unsigned_8(nat_scratch);
   	seq_io_unsigned_byte.write(VectorFileHead,ubyte_scratch);

	nat_scratch := natural'value(get_field(to_unbounded_string(version),2,'.')); -- minor number
	ubyte_scratch := unsigned_8(nat_scratch);
   	seq_io_unsigned_byte.write(VectorFileHead,ubyte_scratch);

	-- write vector file format, CS: not supported yet, default is 00h each
   	seq_io_unsigned_byte.write(VectorFileHead,16#00#); -- vector file format major number
   	seq_io_unsigned_byte.write(VectorFileHead,16#00#); -- vector file format minor number

	-- write chain count
	ubyte_scratch := unsigned_8(chain_ct);
   	seq_io_unsigned_byte.write(VectorFileHead,ubyte_scratch);

	-- process seq file line by line
	while chain_pt <= chain_ct
	loop
		new_line; put(natural'image(chain_pt)); -- output chain number being processed

		write_base_address; -- write base address of current chain in vec_header

		scratch := test_name;
		scratch := scratch & "/" & scratch & ".vec";
		seq_io_unsigned_byte.open( VectorFile, seq_io_unsigned_byte.append_file, Name => to_string(scratch));

		-- process sequence by sequence
		sequence_pt := 1; -- CS: check if there is a sequence 1, 2, 3,...
		while sequence_pt <= sequence_ct
		loop
			Open( 
				File => sequence_file,
				Mode => In_File,
				Name => "tmp/sequence_" & trim(natural'image(sequence_pt) ,side => left) & ".tmp"
				);
			Set_Input(sequence_file);

			read_sequence_file;

			close(sequence_file);
			sequence_pt := sequence_pt + 1; -- go to next sequence
		end loop;

		seq_io_unsigned_byte.close(vectorfile);
		--set_output(standard_output);
		chain_pt := chain_pt + 1; -- go to next chain
	end loop;
	new_line;

	-- open vector file one last time for write append
	-- write test end marker in vector file
	scratch := test_name;
	scratch := scratch & "/" & scratch & ".vec";
	seq_io_unsigned_byte.open( VectorFile, seq_io_unsigned_byte.append_file, Name => to_string(scratch));
	write_word_in_vec_file(16#0000#); 	-- a conf. word has ID 0000h
	write_byte_in_vec_file(16#77#);		-- 77h indicates end of test
	write_byte_in_vec_file(16#02#);		-- 02h indicates virtual begin of chain 2 data
	seq_io_unsigned_byte.close(vectorfile);

	-- append vector file to header file byte per byte
	seq_io_unsigned_byte.open( VectorFile, seq_io_unsigned_byte.in_file, Name => to_string(scratch));
	while not seq_io_unsigned_byte.end_of_file(VectorFile)
	loop
		seq_io_unsigned_byte.read(VectorFile,ubyte_scratch);
		seq_io_unsigned_byte.write(VectorFileHead,ubyte_scratch);
	end loop;
	seq_io_unsigned_byte.close(vectorfile);
	seq_io_unsigned_byte.close(VectorFileHead);

	-- make final vector file in test directory
	copy_file("tmp/vec_header.tmp",to_string(scratch));

    -- write journal
	scratch := test_name;
	scratch := scratch & "/" & scratch & ".vec";
	size_of_vec_file := Natural'Value(file_size'image(size(to_string(scratch))));

	prog_position := "JO3";
	if exists("setup/journal.txt") then
		 -->> setup/journal.txt	
		Open( 
			File => tmp_file,
			Mode => append_File,
			Name => "setup/journal.txt"
			);
		set_output(tmp_file);
		put(test_name & " " & hex_print(next_dest_addr,8) & natural'image(size_of_vec_file) & " " & version & " ");
		put(Image(clock) & " "); put(Integer(UTC_Time_Offset/60),1); new_line;
		set_output(standard_output);
	else
		put_line("No journal found. Creating a new one ...");
		create(tmp_file,out_file,"setup/journal.txt");
		set_output(tmp_file);
		put_line("test_name   dest_addr(hex)  size(dec)  comp_version  date(yyyy:mm:dd)  time(hh:mm:ss)  UTC_offset(h)");
		put_line("----------------------------------------------------------------------------------------------------");
		put(test_name & " " & hex_print(next_dest_addr,8) & natural'image(size_of_vec_file) & " " & version & " ");
		put(Image(clock) & " "); put(Integer(UTC_Time_Offset/60),1); new_line;
		set_output(standard_output);
	end if;


	exception
		when Constraint_Error => 
			new_line;
			put("ERROR ! : ");
	--		if prog_position = "MEM" then
			if prog_position = "JO1" then
				put_line("Journal corrupted or empty !");
			end if;
			if prog_position = "TI1" then
				put_line("Pattern for trailer_ir incorrect !");
				put_line("Please use an 8 bit pattern consisting of characters 0 or 1. Example 00110101");
 				put_line("Affected line reads : " & line);
			end if;
			if prog_position = "TD1" then
				put_line("Pattern for trailer_dr incorrect !");
				put_line("Please use an 8 bit pattern consisting of characters 0 or 1. Example 00110101");
 				put_line("Affected line reads : " & line);
			end if;

			put_line (prog_position); 
			put ("PROGRAM ABORTED !"); new_line; new_line;
			Set_Exit_Status(Failure);		
	


end compseq;
