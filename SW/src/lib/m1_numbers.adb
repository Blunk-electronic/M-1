-- ---------------------------------------------------------------------------
--                                                                          --
--                          SYSTEM M-1 NUMBERS                              --
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

--with Ada.Strings; 			use Ada.Strings;
with ada.strings.fixed; 				use ada.strings.fixed;
with ada.strings.unbounded; 			use ada.strings.unbounded;

with ada.numerics.elementary_functions;	use ada.numerics.elementary_functions;
with ada.numerics;						use ada.numerics;
with ada.numerics.generic_elementary_functions;

with m1_string_processing;				use m1_string_processing;

package body m1_numbers is

	procedure put_character_class_0(
		char_in : in type_bit_char_class_0;
		file : in file_type := standard_output
		) is
	begin
		case char_in is
			when '0' => put(file,'0');
			when '1' => put(file,'1');
		end case;
	end put_character_class_0;

	procedure put_binary_class_0(
		binary_in : in type_string_of_bit_characters_class_0;
		file : in file_type := standard_output
		) is
	begin
		for c in 1..binary_in'last loop 
		-- CS better: for c in binary_in'first..binary_in'last loop
			case binary_in(c) is
				when '0' => put(file,'0');
				when '1' => put(file,'1');
			end case;
		end loop;
	end put_binary_class_0;

	procedure put_binary_class_1(
		binary_in : in type_string_of_bit_characters_class_1;
		file : in file_type := standard_output
		) is
	begin
		for c in 1..binary_in'last loop
		-- CS better: for c in binary_in'first..binary_in'last loop
			case binary_in(c) is
				when '0' => put(file,'0');
				when '1' => put(file,'1');
				when 'x' => put(file,'X');
				when 'X' => put(file,'X');
			end case;
		end loop;
	end put_binary_class_1;

	procedure put_binary_class_2(
		binary_in : in type_string_of_bit_characters_class_2;
		file : in file_type := standard_output
		) is
	begin
		for c in 1..binary_in'last loop
		-- CS better: for c in binary_in'first..binary_in'last loop
			case binary_in(c) is
				when '0' => put(file,'0');
				when '1' => put(file,'1');
				when 'x' => put(file,'X');
				when 'X' => put(file,'X');
				when 'z' => put(file,'Z');
				when 'Z' => put(file,'Z');
			end case;
		end loop;
	end put_binary_class_2;

	function to_binary_class_0 (binary_in : type_string_of_bit_characters) return type_string_of_bit_characters_class_0 is
		subtype type_b is type_string_of_bit_characters_class_0 (1..binary_in'last);
		a : type_b;
	begin
		for c in 1..binary_in'last loop
		-- CS better: for c in binary_in'first..binary_in'last loop
			case binary_in(c) is
				when '0' => a(c) := '0';
				when '1' => a(c) := '1';
				when others => raise constraint_error;
			end case;
		end loop;
		return a;
	end to_binary_class_0;

	function to_binary_class_1 (binary_in : type_string_of_bit_characters) return type_string_of_bit_characters_class_1 is
		subtype type_b is type_string_of_bit_characters_class_1 (1..binary_in'last);
		a : type_b;
	begin
		for c in 1..binary_in'last loop
		-- CS better: for c in binary_in'first..binary_in'last loop
			case binary_in(c) is
				when '0' => a(c) := '0';
				when '1' => a(c) := '1';
				when 'x' => a(c) := 'X';
				when 'X' => a(c) := 'X';
				when others => raise constraint_error;
			end case;
		end loop;
		return a;
	end to_binary_class_1;

	function to_binary_class_2 (binary_in : type_string_of_bit_characters) return type_string_of_bit_characters_class_2 is
	-- converts a type_string_of_bit_characters to a type_string_of_bit_characters_class_2
		subtype type_b is type_string_of_bit_characters_class_2 (1..binary_in'last);
		a : type_b;
	begin
		for c in 1..binary_in'last loop
		-- CS better: for c in binary_in'first..binary_in'last loop
			case binary_in(c) is
				when '0' => a(c) := '0';
				when '1' => a(c) := '1';
				when 'x' => a(c) := 'X';
				when 'X' => a(c) := 'X';
				when 'z' => a(c) := 'Z';
				when 'Z' => a(c) := 'Z';
				when others => raise constraint_error;
			end case;
		end loop;
		return a;
	end to_binary_class_2;

	function replace_dont_care (binary_in : type_string_of_bit_characters_class_1; replace_by : type_bit_char_class_0 := '0') 
		return type_string_of_bit_characters_class_0 is
	-- replaces all x (don't cares) by character given in "replace_by"
		subtype type_b is type_string_of_bit_characters_class_0 (1..binary_in'last);
		a : type_b;
	begin
		for c in 1..binary_in'last loop
		-- CS better: for c in binary_in'first..binary_in'last loop
			case binary_in(c) is
				when '0' => a(c) := '0';
				when '1' => a(c) := '1';
				when 'x' => a(c) := replace_by;
				when 'X' => a(c) := replace_by;
				when others => raise constraint_error;
			end case;
		end loop;
		return a;
	end replace_dont_care;


	--function to_binary(text_in : string; length : type_register_length; class : type_bit_character_class := class_0) return type_string_of_bit_characters is
	function to_binary(text_in : string; length : positive; class : type_bit_character_class := class_0) return type_string_of_bit_characters is
	-- converts a string (of letters x,X,0,1,z,Z) to type_string_of_bit_characters of class with length
		subtype type_string_of_bit_characters_sized is type_string_of_bit_characters (1..length);
		a : type_string_of_bit_characters_sized;

		procedure error_on_invalid_character(c : character) is
		begin
			put_line("ERROR: Invalid character '" & c & "' found in string.");
				case class is
					when class_0 => put_line("Allowed are :"); --'0', '1'
									for c in type_bit_char_class_0'pos(type_bit_char_class_0'first) .. type_bit_char_class_0'pos(type_bit_char_class_0'last) loop
										put(" " & type_bit_char_class_0'image(type_bit_char_class_0'val(c)));
									end loop;
									new_line;
					when class_1 => put_line("Allowed are :"); --'0', '1', 'x', 'X'
									for c in type_bit_char_class_1'pos(type_bit_char_class_1'first) .. type_bit_char_class_1'pos(type_bit_char_class_1'last) loop
										put(" " & type_bit_char_class_1'image(type_bit_char_class_1'val(c)));
									end loop;
									new_line;
					when class_2 => put_line("Allowed are :"); --'0', '1', 'x', 'X', 'z' or 'Z'
									for c in type_bit_char_class_2'pos(type_bit_char_class_2'first) .. type_bit_char_class_2'pos(type_bit_char_class_2'last) loop
										put(" " & type_bit_char_class_2'image(type_bit_char_class_2'val(c)));
									end loop;
									new_line;
				end case;
			raise constraint_error;
		end error_on_invalid_character;
	begin
		-- make sure given string length matches bit count (given in "length")
		if text_in'last /= length then
			put_line(message_error & "Invalid string length of" & natural'image(text_in'last) & " found !");
			raise constraint_error;
		end if;
		case class is
			when class_0 =>
				for d in 1..length loop
					case text_in(d) is
						when '0' => a(d) := '0';
						when '1' => a(d) := '1';
						when others => error_on_invalid_character(text_in(d));
					end case;
				end loop;
			when class_1 =>
				for d in 1..length loop
					case text_in(d) is
						when '0' => a(d) := '0';
						when '1' => a(d) := '1';
						when 'x' => a(d) := 'X';
						when 'X' => a(d) := 'X';
						when others => error_on_invalid_character(text_in(d));
					end case;
				end loop;
			when class_2 =>
				for d in 1..length loop
					case text_in(d) is
						when '0' => a(d) := '0';
						when '1' => a(d) := '1';
						when 'x' => a(d) := 'X';
						when 'X' => a(d) := 'X';
						when 'z' => a(d) := 'Z';
						when 'Z' => a(d) := 'Z';
						when others => error_on_invalid_character(text_in(d));
					end case;
				end loop;
		end case;
		--a := "00000000";
		return a;
	end to_binary;



	function shift_class_0 (
	-- shifts a given type_string_of_bit_characters_class_0 left/right by shift_count
	-- fill bit is optionally specified with argument "fill"
		binary_in		: type_string_of_bit_characters_class_0; -- MSB left (pos. 1) !
		shift_direction	: type_shift_direction;
		shift_count 	: natural;
		fill_bit		: type_bit_char_class_0 := '0'
		) return type_string_of_bit_characters_class_0 is

		subtype type_b is type_string_of_bit_characters_class_0 (1..binary_in'last);
		a : type_b;
	begin
		case shift_direction is
			when right =>
				-- fill bits on the left
				-- example: if 5 bits shift to the right demanded, five bits on the left get filled by fill_bit
				a(1..shift_count) := to_binary_class_0
					(  
					to_binary( 
						text_in => shift_count * type_bit_char_class_0'image(fill_bit)(2), -- delimiters (') must be stipped
						length	=> shift_count,
						class	=> class_0
						)
					);
				-- do the actual shifting to the right
				a(shift_count+1..binary_in'last) := binary_in(1..binary_in'last-shift_count);

			when left =>
				put_line("ERROR: Left shifting not supported yet !");
				raise constraint_error;
		end case;

		return a;
	end shift_class_0;

	function to_natural(binary_in: type_string_of_bit_characters_class_0) return natural is
	-- converts a type_string_of_bit_characters_class_0 to a natural
	-- assumes the LSB is on the left (pos. 1)
		a	: natural := 0; -- is the output
		w	: positive := 1; -- weight of bit position (doubled from pos. to pos. 1-2-4-8-16...)
	begin
		-- process as many bits as binary_in is long
		for i in binary_in'first..binary_in'last loop -- LSB left (pos. 1)
			
			-- if bit is zero, do nothing
			-- if bit is one, add to a the weight of that position
			case binary_in(i) is
				when '0' => null;
				when '1' => a := a + w;
			end case;

			w := w * 2; -- double the weight
		end loop;
		return a;
	end to_natural;

	function mirror_class_0 (binary_in : type_string_of_bit_characters_class_0) -- MSB left (pos. 1) !
		return type_string_of_bit_characters_class_0 is -- LSB left (pos 1)
	-- swaps MSB and LSB
		subtype type_b is type_string_of_bit_characters_class_0 (1..binary_in'last);
		a : type_b := binary_in;
		b : type_b;
	begin
		for i in 1..binary_in'last loop
		-- CS better: for i in binary_in'first..binary_in'last loop
			b(binary_in'last - i + 1) := a(i);
		end loop;

		return b; -- LSB left (pos 1)
	end mirror_class_0;

	function string_to_natural (text_in : string) return natural is
	-- converts a string like 1101b or ECCh or 512d to a natural number
	-- format is detected by trailing character (b,h,d)
		n		: natural := 0;
		l		: natural := text_in'last;
		base	: positive;

		function update_n(digit_weight : natural; char_position : positive) return natural is
		begin
			return n + digit_weight * base**(l-1-char_position);
		end update_n;
	begin
		if l > 0 then -- if lenght is greater zero (emtpy strings are not accepted)
			case text_in(l) is
				when 'h' => -- the given string is a hex number like 8000h
					base := 16;
					-- convert given number character by character to a decimal number
					-- process as many characters as given in text_in 
					-- skip last character as this is the format indicator (in this case 'h')
					for char_position in reverse 1..l-1 loop 
						case text_in(char_position) is
							when '0' => n := update_n(0,char_position); 
							when '1' => n := update_n(1,char_position);
							when '2' => n := update_n(2,char_position);
							when '3' => n := update_n(3,char_position);
							when '4' => n := update_n(4,char_position); 
							when '5' => n := update_n(5,char_position);
							when '6' => n := update_n(6,char_position);
							when '7' => n := update_n(7,char_position);
							when '8' => n := update_n(8,char_position); 
							when '9' => n := update_n(9,char_position);
							when 'A' | 'a' => n := update_n(10,char_position);
							when 'B' | 'b' => n := update_n(11,char_position);
							when 'C' | 'c' => n := update_n(12,char_position); 
							when 'D' | 'd' => n := update_n(13,char_position);
							when 'E' | 'e' => n := update_n(14,char_position);
							when 'F' | 'f' => n := update_n(15,char_position);
							when others => 
								put_line("ERROR: Expected hexadecimal character !");
								raise constraint_error;
						end case;
					end loop;

				when 'd' =>  -- the given string is a decimal number like 2028d
					n := natural'value(text_in(text_in'first..text_in'last-1));

				when 'b' =>  -- the given string is a binary number like 10010b
					base := 2;
					-- convert given number character by character to a decimal number
					-- process as many characters as given in text_in 
					-- skip last character as this is the format indicator (in this case 'b')
					for char_position in reverse 1..l-1 loop 
						case text_in(char_position) is
							when '0' => n := update_n(0,char_position); 
							when '1' => n := update_n(1,char_position);
							when others => 
								put_line("ERROR: Expected binary character !");
								raise constraint_error;
						end case;
					end loop;

				when others =>
					put_line("ERROR: Unkown number format specified by last character !");
					raise constraint_error;
				end case;
		else
			put_line("ERROR: Expected string with at least two characters !");
			raise constraint_error;
		end if;
		return n;
	end string_to_natural;

	function natural_to_string(
	-- converts a natural to a string like EC5Fh or 0010110b
	-- the parameter base determines the format
		natural_in	: natural;	-- the natural number to convert 
		base 		: positive; -- the base for the conversion
		length 		: positive := 1		-- the length of the output string. if given, the output string will
										-- be filled with heading "0" characters so that the total length of
										-- the output string is "length"
										-- if given length is too short, it will be ignored
		) return string is
		i			: natural := natural_in; -- i holds the input number
		text_out 	: unbounded_string; -- this is what will be returned before converted to a string
		digit		: natural := 0; -- points to the digit being processed

		-- used for conversion to hex format
		subtype type_x is positive range 1..15;
		x			: type_x;

		-- instantiate functions library
		package functions is new generic_elementary_functions(float);
		scratch	: float;
		width	: positive; -- holds the number of bits required by the given input number

		procedure fill_heading_space is
		begin
			if length > digit then
				text_out := (length - digit - 1) * "0";
			end if;
		end fill_heading_space;

		-- width is calculated before conversion
	begin	
		-- calculate number of bits required
		--put_line(standard_output,"i :" & natural'image(i));

		-- an input value of zero must be excluded from the conversion
		-- and can be converted to a string "0" instantly
		if i = 0 then
			case base is
				when 2 =>
					text_out := to_unbounded_string(length * "0" & "b"); -- creates something like 0000000b
				when 16 =>
					text_out := to_unbounded_string(length * "0" & "h"); -- creates something like 0000h
				when others =>
					put_line("ERROR: Base not supported !");
					raise constraint_error;
			end case;

		else
			scratch := functions.log(x => float(i), base => float(2));
			--put_line(standard_output,"scratch:" & float'image(scratch));
			-- scratch holds a float number which must be rounded up to an integer (because the bit count is always an integer)
			-- rounding does not work if scratch is zero. for example: if input is 1, scratch becomes zero. in this case we need only one bit.
			if scratch > float(0) then

				-- if scratch is an integer, the remainder is zero -> increment width by 1
				-- example: given natural_in = 8, log 8 = 3, four bits required -> add 1 to scratch
				if float'remainder(scratch, float'ceiling(scratch) ) = float(0) then
					-- no rounding required, add 1 to scratch to obtain number of bits required
					--put_line("remainder 0");
					--width := positive(float'ceiling(scratch)) + 1;
					width := positive(scratch) + 1;
				else
					-- scratch is not integer, rouding up to next integer required
					--put_line("remainder greater 0");
					width := positive(float'ceiling(scratch));
				end if;

			else 
				-- if scratch is zero, only one bit is required
				width := 1;
			end if;
			--put_line("width :" & positive'image(width));
			-- calculating width done

			-- depending on given base do the conversion
			case base is
				when 2 =>
-- 					if i = 0 then -- exclude input value of zero from conversion
-- 						text_out := to_unbounded_string("0");

--					else -- begin conversion:

						-- find highest relevant digit
						for d in 0..width+1 loop
							if base**d > i then
								digit := d - 1;
								exit;
							end if;
						end loop;
						-- now "digit" points to the MSB

						fill_heading_space;

						-- convert i to binary string (start with MSB)
						for d in reverse 0..digit loop
							if base**d <= i then
								i := i - base**d; -- update i
								text_out := text_out & "1";
							else
								text_out := text_out & "0";
							end if;
						end loop;
						-- end conversion
--					end if;

					-- add trailing format indicator
					text_out := text_out & "b";


				when 16 =>
-- 					if i = 0 then -- exclude input value of zero from conversion
-- 						text_out := to_unbounded_string("0");
-- 
-- 					else -- begin conversion:

						-- find highest digit
						for d in 0..width+1 loop
							if base**d > i then
								digit := d - 1;
								exit;
							end if;
						end loop;
						-- now "digit" points to the MSB

						fill_heading_space;

						-- convert i to binary string, start with MSB
						for d in reverse 0..digit loop
							if base**d <= i then
								x := abs(i/base**d);
								i := i - x * base**d; -- update i
								case x is
									when 1 => text_out := text_out & "1";
									when 2 => text_out := text_out & "2";
									when 3 => text_out := text_out & "3";
									when 4 => text_out := text_out & "4";
									when 5 => text_out := text_out & "5";
									when 6 => text_out := text_out & "6";
									when 7 => text_out := text_out & "7";
									when 8 => text_out := text_out & "8";
									when 9 => text_out := text_out & "9";
									when 10 => text_out := text_out & "A";
									when 11 => text_out := text_out & "B";
									when 12 => text_out := text_out & "C";
									when 13 => text_out := text_out & "D";
									when 14 => text_out := text_out & "E";
									when 15 => text_out := text_out & "F";
								end case;
							else
								text_out := text_out & "0";
							end if;
						end loop;
						-- end conversion
-- 					end if;

					-- add trailing format indicator
					text_out := text_out & "h";

				when others => 
					put_line("ERROR: Base not supported !");
					raise constraint_error;
			end case;
		end if;

		return to_string(text_out);
	end natural_to_string;


	function test_bit_unsigned_8 (byte_in : unsigned_8; position : bit_position_unsigned_8) return boolean is
	-- tests if given bit is set or not. returns true if set.
		i	: unsigned_8 := unsigned_8(2**position); -- has a bit at given position set
		o	: unsigned_8;
	begin
		--put_line("POS.  : " & natural'image(position));
		--put_line("INPUT : " & unsigned_8'image(byte_in));
		o := byte_in and i;
		--put_line("OUTPUT: " & unsigned_8'image(o));
		if o = 0 then 
			return false;
		else
			return true;
		end if;
	end test_bit_unsigned_8;

	function set_clear_bit_unsigned_8 (byte_in : unsigned_8; position : bit_position_unsigned_8; set : boolean := true) return unsigned_8 is
	-- Sets a given bit if set=true, returns the given value with the bit set (default).
	-- Clears a given bit if set=false, returns the given value with the bit set.
		s	: unsigned_8 := unsigned_8(2**position); -- has a bit at given position set
		c	: unsigned_8 := -s; -- has a bit at given position cleared
		o	: unsigned_8;
	begin
		--put_line("POS.  : " & natural'image(position));
		--put_line("INPUT : " & unsigned_8'image(byte_in));
		if set then
			o := byte_in or s;
		else
			o := byte_in and c;
		end if;
		--put_line("OUTPUT: " & unsigned_8'image(o));
		return o;
	end set_clear_bit_unsigned_8;


	function get_byte_from_word(word_in : unsigned_16; position : natural) return unsigned_8 is
		w	: unsigned_16 := word_in;
		b	: unsigned_8;
	begin
		case position is
			when 0 => -- return lowbyte
				w := shift_left(w,8); -- clear highbyte by shifting left
				w := shift_right(w,8); -- shift back to the right
				b := unsigned_8(w); -- copy lowbyte to byte
			when 1 => -- return highbyte
				w := shift_right(w,8); -- shift to the right
				b := unsigned_8(w); -- copy lowbyte to byte
			when others =>
				put_line("ERROR: Invalid byte position specified !");
				raise constraint_error;
		end case;
		return b;
	end get_byte_from_word;

	function get_byte_from_doubleword(word_in : unsigned_32; position : natural) return unsigned_8 is
		w	: unsigned_32 := word_in;
		b	: unsigned_8;
	begin
		case position is
			when 0 => -- return bits (7..0)
				w := shift_left(w,3*8); -- clear highbytes by shifting left
				w := shift_right(w,3*8); -- shift back to the right
				b := unsigned_8(w); -- copy lowbyte to byte
			when 1 => -- return bits (15..8)
				w := shift_left(w,2*8); -- clear highbytes by shifting left
				w := shift_right(w,3*8); -- shift back to the right
				b := unsigned_8(w); -- copy lowbyte to byte
			when 2 => -- return bits (23..16)
				w := shift_left(w,1*8); -- clear highbytes by shifting left
				w := shift_right(w,3*8); -- shift back to the right
				b := unsigned_8(w); -- copy lowbyte to byte
			when 3 => -- return bits (31..24)
				w := shift_right(w,3*8); -- shift back to the right
				b := unsigned_8(w); -- copy lowbyte to byte
			when others =>
				put_line("ERROR: Invalid byte position specified !");
				raise constraint_error;
		end case;
		return b;
	end get_byte_from_doubleword;

	function negate_bit_character_class_0 (character_given : type_bit_char_class_0) return type_bit_char_class_0 is
	begin
		case character_given is
			when '0' => return '1';
			when '1' => return '0';
		end case;
	end negate_bit_character_class_0;

	function is_even ( number : in integer) return boolean is
	-- Returns true if given number is even.
	begin
		if (number rem 2) = 0 then
			return true;
		else
			return false;
		end if;
	end is_even;
	
end m1_numbers;