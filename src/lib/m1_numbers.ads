-- ---------------------------------------------------------------------------
--                                                                          --
--                          SYSTEM M-1 NUMBERS                              --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               S p e c                                    --
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

with ada.text_io;			use ada.text_io;
with ada.sequential_io;
with interfaces;			use interfaces;

package m1_numbers is

	package seq_io_unsigned_byte is new ada.sequential_io(unsigned_8);

	type type_bit_character_class is ( class_0 , class_1 , class_2);
	package bit_character_class_io is new ada.text_io.enumeration_io (enum => type_bit_character_class);

 	--type type_hexadecimal_character is ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
	--type type_string_of_hexadecimal_characters is array (natural range <>) of type_hexadecimal_character;

	--hexadecimal_character : ada.strings.maps.character_set := ada.strings.maps.to_set( ranges =>  ( ('A','F'),('a','f'),('0','9') ) );
	-- if not ada.strings.maps.is_in(part_code_fac(c),valid_character) then
	--valid_special 	:	ada.strings.maps.character_set := ada.strings.maps.to_set("_-+%./"); -- ins v004
	--valid_character	:	ada.strings.maps.character_set := ada.strings.maps."or"(valid_letter,valid_special); -- compose set of valid characters


	type type_bit_character is ('x', 'X', '0', '1', 'z', 'Z');
	subtype type_bit_char_class_0 is type_bit_character range '0'..'1';
	subtype type_bit_char_class_1 is type_bit_character range 'x'..'1';
	subtype type_bit_char_class_2 is type_bit_character range 'x'..'Z';
	type type_string_of_bit_characters is array (natural range <>) of type_bit_character;  
	type type_string_of_bit_characters_class_0 is array (natural range <>) of type_bit_char_class_0;
	type type_string_of_bit_characters_class_1 is array (natural range <>) of type_bit_char_class_1;  
	type type_string_of_bit_characters_class_2 is array (natural range <>) of type_bit_char_class_2;    
	subtype type_bit_character_x is type_bit_character range 'x'..'X';
	subtype type_bit_character_z is type_bit_character range 'z'..'Z';
	subtype type_bit_character_0 is type_bit_character range '0'..'0';
	subtype type_bit_character_1 is type_bit_character range '1'..'1';
	
	type type_radix_indicator is ('d' , 'b' , 'h');
	radix_indicator_decimal : constant character := 'd';
	radix_indicator_binary  : constant character := 'b';
	radix_indicator_hexadecimal : constant character := 'h';

-- 	package binary_io_class_0 is new ada.text_io.enumeration_io (enum => type_bit_char_class_0);
-- 	package binary_io_class_1 is new ada.text_io.enumeration_io (enum => type_bit_char_class_1);
-- 	package binary_io_class_2 is new ada.text_io.enumeration_io (enum => type_bit_char_class_2);
-- NOTE: since the put of this package encloses the output in apostrophes we can't use it.

	procedure put_character_class_0(
		char_in : in type_bit_char_class_0;
		file : in file_type := standard_output
		);

	procedure put_binary_class_0(
		binary_in: in type_string_of_bit_characters_class_0;
		file : in file_type := standard_output
		);
	
	procedure put_binary_class_1(
		binary_in : in type_string_of_bit_characters_class_1;
		file : in file_type := standard_output
		);
	
	procedure put_binary_class_2(
		binary_in : in type_string_of_bit_characters_class_2;
		file : in file_type := standard_output
		);

	function to_binary_class_0 (binary_in : type_string_of_bit_characters) return type_string_of_bit_characters_class_0;
	function to_binary_class_1 (binary_in : type_string_of_bit_characters) return type_string_of_bit_characters_class_1;
	function to_binary_class_2 (binary_in : type_string_of_bit_characters) return type_string_of_bit_characters_class_2;
	-- converts a type_string_of_bit_characters to a type_string_of_bit_characters_class_2

	function replace_dont_care (binary_in : type_string_of_bit_characters_class_1; replace_by : type_bit_char_class_0 := '0') 
		return type_string_of_bit_characters_class_0;
	-- replaces all x (don't cares) by character given in "replace_by"

	--function to_binary(text_in : string; length : type_register_length; class : type_bit_character_class := class_0)
	function to_binary(text_in : string; length : positive; class : type_bit_character_class := class_0)  
		return type_string_of_bit_characters;
	-- converts a string (of letters x,X,0,1,z,Z) to type_string_of_bit_characters of class with length

 	type type_shift_direction is ( LEFT, RIGHT);
	function shift_class_0 (
	-- shifts a given type_string_of_bit_characters_class_0 left/right by shift_count
	-- fill bit is optionally specified with argument "fill"
		binary_in		: type_string_of_bit_characters_class_0; -- MSB left (pos. 1) !
		shift_direction	: type_shift_direction;
		shift_count 	: natural;
		fill_bit		: type_bit_char_class_0 := '0'
		) return type_string_of_bit_characters_class_0;

	function to_natural(binary_in: type_string_of_bit_characters_class_0) return natural;
	-- converts a type_string_of_bit_characters_class_0 to a natural
	-- assumes the LSB is on the left (pos. 1)


	function mirror_class_0 (binary_in : type_string_of_bit_characters_class_0) -- MSB left (pos. 1) !
		return type_string_of_bit_characters_class_0; -- LSB left (pos 1)
	-- swaps MSB and LSB

	function string_to_natural (text_in : string) return natural;
	-- converts a string like 1101b or ECCh or 512d to a natural number
	-- format is detected by trailing character (b,h,d)

	function natural_to_string(
	-- converts a natural to a string like EC5Fh or 0010110b
	-- the parameter base determines the format
		natural_in	: natural;	-- the natural number to convert 
		base 		: positive; -- the base for the conversion
		length 		: positive := 1		-- the length of the output string. if given, the output string will
										-- be filled with heading "0" characters so that the total length of
										-- the output string is "length"
										-- if given length is too short, it will be ignored
		) return string;


	subtype bit_position_unsigned_8 is natural range 0..7;
	function test_bit_unsigned_8 (byte_in : unsigned_8; position : bit_position_unsigned_8) return boolean;
	-- tests if given bit is set or not. returns true if set.

	function set_clear_bit_unsigned_8 (byte_in : unsigned_8; position : bit_position_unsigned_8; set : boolean := true) return unsigned_8;
	-- Sets a given bit if set=true, returns the given value with the bit set (default).
	-- Clears a given bit if set=false, returns the given value with the bit set.


	function get_byte_from_word(word_in : unsigned_16; position : natural) return unsigned_8;
	-- position 0 addresses lowbyte	
	function get_byte_from_doubleword(word_in : unsigned_32; position : natural) return unsigned_8;
	-- position 0 addresses lowbyte

	function negate_bit_character_class_0 (character_given : type_bit_char_class_0) return type_bit_char_class_0;

	function is_even ( number : in integer) return boolean;
	-- Returns true if given number is even.
end m1_numbers;
