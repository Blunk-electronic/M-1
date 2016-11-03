------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE IMPBSDL                             --
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
-- with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
-- with Ada.Float_Text_IO;		use Ada.Float_Text_IO;
with ada.characters.handling;   use ada.characters.handling;
-- 
-- --with System.OS_Lib;   use System.OS_Lib;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
--with ada.characters.handling;	use ada.characters.handling;
--with ada.characters.conversions;use ada.characters.conversions;
with ada.strings; 				use ada.strings;
with ada.strings.maps;			use ada.strings.maps;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
-- with Ada.Numerics;			use Ada.Numerics;
-- with Ada.Numerics.Elementary_Functions;	use Ada.Numerics.Elementary_Functions;
-- 
-- with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
-- with Ada.Task_Identification;  use Ada.Task_Identification;
-- with Ada.Exceptions; use Ada.Exceptions;
-- with Ada.IO_Exceptions; use Ada.IO_Exceptions;
--  
with gnat.os_lib;   		use gnat.os_lib;
with ada.command_line;		use ada.command_line;
with ada.directories;		use ada.directories;

with m1; --use m1;
with m1_internal; 				use m1_internal;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;


procedure impbsdl is

	version			: String (1..3) := "0xx";
	udb_summary		: type_udb_summary;


	procedure read_bsld_models is
		bic				: type_ptr_bscan_ic_pre := ptr_bic_pre;
		file_bsdl 		: ada.text_io.file_type;
		line_of_file	: extended_string.bounded_string;
		bsdl_string		: unbounded_string;
--		line_counter	: natural := 0;
		--entry_line_count: positive := 1;

-- 		type type_bsdl_entry;
-- 		type type_ptr_bsdl_entry is access all type_bsdl_entry;
-- 		type type_bsdl_entry is
-- 			record
-- 				next		: type_ptr_bsdl_entry;
-- 				line		: extended_string.bounded_string;
-- 			end record;
-- 		ptr_bsdl_entry : type_ptr_bsdl_entry;
-- 
-- 		procedure add_line_to_bsdl_entry (
-- 			list			: in out type_ptr_bsdl_entry;
-- 			line			: in extended_string.bounded_string
-- 			) is
-- 			line_cleaned_up	: extended_string.bounded_string;
-- 			--characters_to_replace : character_set;
-- 			--number_of_char_to_replace : natural := 0;
-- 			--ctrl_map : character_mapping := to_mapping("ab","cd");
-- 			--ctrl_map : character_mapping := to_mapping(latin_1.cr, latin_1.space);
-- 		begin
-- 			--characters_to_replace := to_set(latin_1.cr);
-- 			--characters_to_replace := to_set(latin_1.ht);
-- 			--number_of_char_to_replace := extended_string.count(line,characters_to_replace);
-- 
-- 			line_cleaned_up := line;
-- 			--entry_line_count := entry_line_count + 1;
-- 			--put_line(standard_output,extended_string.to_string(line));
-- 
-- 			-- replace control characters by space
--  			for c in 1..extended_string.length(line_cleaned_up) loop
-- 				if is_control(extended_string.element(line_cleaned_up,c)) then
-- 					extended_string.replace_element(line_cleaned_up,c,latin_1.space);
-- 				end if;

-- 				if c < extended_string.length(line_cleaned_up) then
-- 					if extended_string.element(line_cleaned_up,c) = latin_1.space and extended_string.element(line_cleaned_up,c+1) = latin_1.space then
-- 						null;
-- 						put_line(standard_output,"test");
-- 						put_line(standard_output,extended_string.to_string(line_cleaned_up));
-- 						extended_string.delete(line_cleaned_up,c,c);
-- 					end if;
-- 				end if;
-- 			end loop;
-- 			
-- 			list := new type_bsdl_entry'(
-- 				next		=> list,
-- 				line		=> line_cleaned_up
-- 				);
-- 		end add_line_to_bsdl_entry;
-- 
-- 		function get_entry return string is
-- 			e : type_ptr_bsdl_entry := ptr_bsdl_entry;
-- 			--line : string (1..entry_line_count * extended_string.max_length);
-- 			line : unbounded_string;
-- 			--entry_start : positive := 1;
-- 			--entry_end : positive := 1;
-- 		begin
-- 			while e /= null loop
-- 				--put_line(standard_output,extended_string.to_string(e.line));
-- 				line := to_unbounded_string(extended_string.to_string(e.line)) & row_separator_0 & line;
-- 				e := e.next;
-- 			end loop;
-- 			return to_string(line);
-- 		end get_entry;

		function get_field(
				text_in 	: in string;
				position 	: in positive;
				ifs 		: in character := latin_1.space;
				trailer 	: boolean := false;
				trailer_to 	: in character := latin_1.semicolon
				) return string is
			field			: unbounded_string;				-- field content to return (NOTE: gets converted to string on return) -- CS: use bounded string
			character_count	: natural := text_in'length;	-- number of characters in given string
			subtype type_character_pointer is natural range 0..character_count;
			char_pt			: type_character_pointer;		-- points to character being processed inside the given string
			field_ct		: natural := 0;					-- field counter (the first field found gets number 1 assigned)
			inside_field	: boolean := true;				-- true if char_pt points inside a field
			char_current	: character;					-- holds current character being processed
			char_last		: character := ifs;				-- holds character processed previous to char_current
		begin
			if character_count > 0 then
				char_pt := 1;
				for char_pt in 1..character_count loop
				--while char_pt <= character_count loop
					char_current := text_in(char_pt); 
					if char_current = ifs then
						inside_field := false;
					else
						inside_field := true;
					end if;
	
					-- count fields if ifs is followed by a non-ifs character
					if (char_last = ifs and char_current /= ifs) then
						field_ct := field_ct + 1;
					end if;

					case trailer is
						when false =>
							-- if targeted field reached
							if position = field_ct then
								if inside_field then -- if inside field
									field := field & char_current; -- append current character to field
									--field_pt := field_pt + 1;
								end if;
							else
								-- if next field reached, abort and return field content
								if field_ct > position then 
										exit;
								end if;
							end if;

						when true =>
							-- if targeted field reached or passed
							if position <= field_ct then
								if char_current = trailer_to then
									exit;
								else
									field := field & char_current; -- append current character to field
								end if;
							end if;
					end case;

					-- save last character
					char_last := char_current;
				end loop;
			else
				null;
			end if;
			return to_string(field);
		end get_field;

		function strip_quotes (text_in : in string) return string is
		begin
			return text_in(text_in'first+1..text_in'last-1);
		end strip_quotes;

		function get_bit_pattern (text_in : in string; width : in positive) return string is
			--scratch : unbounded_string;
			text_out : string (1..width);
			pattern_start : boolean := false;
			text_out_pt : positive := 1; -- CS: subtype of width
		begin
			for c in 1..text_in'length loop
				case text_in(c) is
					when latin_1.quotation => pattern_start := true;
					when 'x' | 'X' =>
						if pattern_start then
							text_out(text_out_pt) := text_in(c);
							text_out_pt := text_out_pt + 1;
						end if;
					when '0' =>
						if pattern_start then
							text_out(text_out_pt) := text_in(c);
							text_out_pt := text_out_pt + 1;
						end if;
					when '1' =>
						if pattern_start then
							text_out(text_out_pt) := text_in(c);
							text_out_pt := text_out_pt + 1;
						end if;
					when others => null;
				end case;
			end loop;
			return text_out;
		end get_bit_pattern;


		procedure parse_bsdl (bsdl_string : in string) is
			character_position 	: positive := 1;
			field_position		: positive := 1;
			field_count			: positive := get_field_count(bsdl_string);

			length_instruction_register		: type_register_length;
			length_boundary_register		: type_register_length;
			--type type_boundary_register is array (type_register_length range <>) of type_bit_of_boundary_register;

			idcode_register_found			: boolean := false;
			usercode_register_found			: boolean := false;
			trst_pin						: boolean := false;

			-- BSDL keywords -- NOTE: some of them also used as UDB keywords
			text_bsdl_entity				: constant string (1..6) := "entity";
			text_bsdl_attribute				: constant string (1..9) := "attribute";
			text_bsdl_instruction_length	: constant string (1..18) := "instruction_length";
			text_bsdl_instruction_capture	: constant string (1..19) := "instruction_capture";
			text_bsdl_idcode_register		: constant string (1..15) := "idcode_register";
			text_bsdl_usercode_register		: constant string (1..17) := "usercode_register";
			text_bsdl_boundary_length		: constant string (1..15) := "boundary_length";
			text_bsdl_boundary_register		: constant string (1..17) := "boundary_register";
			text_bsdl_tap_scan_reset		: constant string (1..14) := "tap_scan_reset";
			text_bsdl_of					: constant string (1..2) := "of";

			-- UDB keywords
			text_udb_none							: constant string (1..4) := "none";
			text_udb_instruction_register_length 	: constant string (1..27) := "instruction_register_length";
			text_udb_boundary_register_length		: constant string (1..24) := "boundary_register_length";
			text_udb_trst_pin						: constant string (1..8) := "trst_pin";
			text_udb_available						: constant string (1..9) := "available";

			procedure read_boundary_register (text_in : in string; width : in positive) is
				--subtype type_boundary_register_sized is type_boundary_register (1..length_boundary_register);
				--boundary_register : type_boundary_register_sized;
				pattern_start : boolean := false;
				text_scratch : string (1..text_in'length) := text_in'length * latin_1.space;
				text_scratch_pt : positive := 1; -- CS: subtype of width
				open_sections_ct : natural := 0;
				--cell_index : boolean := false;
				cell_id_as_string, control_cell_id_as_string : universal_string_type.bounded_string; -- CS: should be sufficient to hold a natural (as string) within range of type_cell_id
				cell_id, control_cell_id : type_cell_id;
				cell_type_as_string : universal_string_type.bounded_string;
				boundary_regiser_cell : type_boundary_register_cell;
				type type_boundary_register_cell_property is (prop_cell_type, prop_port, prop_function, prop_safe_value, prop_control_cell_id, prop_disable_value,  prop_disable_result);
				boundary_register_cell_property : type_boundary_register_cell_property := prop_cell_type;				
				port : universal_string_type.bounded_string;
				option_port_index, option_control_cell : boolean := false;
				port_index_as_string : universal_string_type.bounded_string;
				port_index : natural;
				cell_function_as_string : universal_string_type.bounded_string;
				cell_function : type_cell_function;
				cell_safe_value	: type_bit_char_class_1;
				cell_disable_value : type_bit_char_class_0;
				cell_disable_result_as_string : universal_string_type.bounded_string;
				cell_disable_result : type_disable_result;
			begin
				-- remove quotations and ampersands
				for c in 1..text_in'length loop
					case text_in(c) is
						when latin_1.quotation =>
							pattern_start := true;
							text_scratch(text_scratch_pt) := latin_1.space;
							text_scratch_pt := text_scratch_pt + 1;
						when latin_1.ampersand | latin_1.comma =>
							text_scratch(text_scratch_pt) := latin_1.space;
							text_scratch_pt := text_scratch_pt + 1;
						when others =>
							if pattern_start then
								text_scratch(text_scratch_pt) := text_in(c);
								text_scratch_pt := text_scratch_pt + 1;
							end if;
					end case;
				end loop;
				--put_line(standard_output,text_scratch);

				-- 0  (BC_1  Y2(4)  output3  X  16  1  Z)
				for c in 1..text_scratch'length loop
					case open_sections_ct is
						when 0 =>
							-- read cell id
							if is_digit(text_scratch(c)) then
								cell_id_as_string := universal_string_type.append(left => cell_id_as_string, right => text_scratch(c));
							else
								if universal_string_type.length(cell_id_as_string) > 0 then
									cell_id := type_cell_id'value(universal_string_type.to_string(cell_id_as_string));
									--put(standard_output, " cell_id " & type_cell_id'image(cell_id));
									boundary_register_cell_property := prop_cell_type;
								end if;
							end if;
							
						when 1 =>
							case boundary_register_cell_property is
								when prop_cell_type =>
									-- read cell type
									if is_digit(text_scratch(c)) or is_letter(text_scratch(c)) or text_scratch(c) = latin_1.low_line then
										cell_type_as_string := universal_string_type.append(left => cell_type_as_string, right => text_scratch(c));
									else
										if universal_string_type.length(cell_type_as_string) > 0 then
											boundary_regiser_cell := type_boundary_register_cell'value(universal_string_type.to_string(cell_type_as_string));
											--put(standard_output, " type " & type_boundary_register_cell'image(boundary_regiser_cell));
											boundary_register_cell_property := prop_port;
										end if;
									end if;

								when prop_port =>
									-- read port name
									if is_digit(text_scratch(c)) or is_letter(text_scratch(c)) or text_scratch(c) = latin_1.low_line or text_scratch(c) = latin_1.asterisk then
										port := universal_string_type.append(left => port, right => text_scratch(c));
									else
										if universal_string_type.length(port) > 0 then
											--put(standard_output, " port " & universal_string_type.to_string(port));
											boundary_register_cell_property := prop_function;
										end if;
										--port := universal_string_type.to_bounded_string("");
									end if;

								when prop_function =>
									-- read direction
									if is_digit(text_scratch(c)) or is_letter(text_scratch(c)) or text_scratch(c) = latin_1.low_line then
										cell_function_as_string := universal_string_type.append(left => cell_function_as_string, right => text_scratch(c));
									else
										if universal_string_type.length(cell_function_as_string) > 0 then
											cell_function := type_cell_function'value(universal_string_type.to_string(cell_function_as_string));
											--put(standard_output, " function " & type_cell_function'image(cell_function));
											boundary_register_cell_property := prop_safe_value;
										end if;
									end if;

								when prop_safe_value =>
									-- read safe value
									case text_scratch(c) is
										when 'X' | 'x' => 
											cell_safe_value := 'X';
											--put(standard_output, " sv " & type_bit_char_class_1'image(cell_safe_value));
											boundary_register_cell_property := prop_control_cell_id;
										when '0' => 
											cell_safe_value := '0';
											--put(standard_output, " sv " & type_bit_char_class_1'image(cell_safe_value));
											boundary_register_cell_property := prop_control_cell_id;
										when '1' => 
											cell_safe_value := '1';
											--put(standard_output, " sv " & type_bit_char_class_1'image(cell_safe_value));
											boundary_register_cell_property := prop_control_cell_id;
										when others => null;
									end case;

								when prop_control_cell_id =>
									-- read control cell id (optional)
									if is_digit(text_scratch(c)) then
										control_cell_id_as_string := universal_string_type.append(left => control_cell_id_as_string, right => text_scratch(c));
									else
										if universal_string_type.length(control_cell_id_as_string) > 0 then
											control_cell_id := type_cell_id'value(universal_string_type.to_string(control_cell_id_as_string));
											option_control_cell := true;
											--put(standard_output, " ctrl " & type_cell_id'image(control_cell_id));
											boundary_register_cell_property := prop_disable_value;
										end if;
									end if;

								when prop_disable_value =>
									-- read disable value (optional)
									case text_scratch(c) is
										when '0' => 
											cell_disable_value := '0';
											--put(standard_output, " dv " & type_bit_char_class_0'image(cell_disable_value));
											boundary_register_cell_property := prop_disable_result;
										when '1' => 
											cell_disable_value := '1';
											--put(standard_output, " dv " & type_bit_char_class_0'image(cell_disable_value));
											boundary_register_cell_property := prop_disable_result;
										when others => null;
									end case;

								when prop_disable_result =>
									-- read disable result (optional)
									if is_digit(text_scratch(c)) or is_letter(text_scratch(c)) then
										cell_disable_result_as_string := universal_string_type.append(left => cell_disable_result_as_string, right => text_scratch(c));
									else
										if universal_string_type.length(cell_disable_result_as_string) > 0 then
											cell_disable_result := type_disable_result'value(universal_string_type.to_string(cell_disable_result_as_string));
											--put(standard_output, " dr " & type_disable_result'image(cell_disable_result));
											--boundary_register_cell_property := prop_cell_type;
										end if;
									end if;
									

								when others => null;
							end case;

							-- 0  (BC_1  Y2(4)  output3  X  16  1  Z)

						when 2 =>
							-- read port index
							if is_digit(text_scratch(c)) then
								port_index_as_string := universal_string_type.append(left => port_index_as_string, right => text_scratch(c));
							else
								if universal_string_type.length(port_index_as_string) > 0 then
									port_index := natural'value(universal_string_type.to_string(port_index_as_string));
									option_port_index := true;
									--put(standard_output, " idx " & natural'image(port_index));
									boundary_register_cell_property := prop_function;
								end if;
								port_index_as_string := universal_string_type.to_bounded_string("");
							end if;
							
						when others => null;
					end case;

					case text_scratch(c) is
						when latin_1.left_parenthesis =>
							open_sections_ct := open_sections_ct + 1;
						when latin_1.right_parenthesis =>
							open_sections_ct := open_sections_ct - 1;
							if open_sections_ct = 0 then
								put(standard_output, " cell_id " & type_cell_id'image(cell_id));
								cell_id_as_string := universal_string_type.to_bounded_string("");

								put(standard_output, " type " & type_boundary_register_cell'image(boundary_regiser_cell));
								cell_type_as_string := universal_string_type.to_bounded_string("");

								put(standard_output, " port " & universal_string_type.to_string(port));
								port := universal_string_type.to_bounded_string("");

								if option_port_index then
									put(standard_output, " idx " & natural'image(port_index));
									option_port_index := false;
								end if;

								put(standard_output, " function " & type_cell_function'image(cell_function));
								cell_function_as_string := universal_string_type.to_bounded_string("");

								put(standard_output, " sv " & type_bit_char_class_1'image(cell_safe_value));

								if option_control_cell then
									put(standard_output, " ctrl " & type_cell_id'image(control_cell_id));
									control_cell_id_as_string := universal_string_type.to_bounded_string("");

									put(standard_output, " dv " & type_bit_char_class_0'image(cell_disable_value));

									put(standard_output, " dr " & type_disable_result'image(cell_disable_result));
									cell_disable_result_as_string := universal_string_type.to_bounded_string("");

									option_control_cell := false;
								end if;
							
							end if;
						when others =>
							null;
					end case;



				end loop;
				--put_line(standard_output,text_scratch);

				
			end read_boundary_register;

		begin
			set_output(file_data_base_preliminary);
			--put_line(bsdl_string);
			if to_lower(get_field(bsdl_string,1)) = text_bsdl_entity then
				put_line(2 * row_separator_0 & "value" & row_separator_0 & get_field(bsdl_string,2));

				-- instruction register length
				--put_line(standard_output,text_bsdl_instruction_length);
				for f in 1..field_count loop
					if to_lower(get_field(bsdl_string,f)) = text_bsdl_attribute then
						if to_lower(get_field(bsdl_string,f+1)) = text_bsdl_instruction_length then
							if to_lower(get_field(bsdl_string,f+2)) = text_bsdl_of then
								length_instruction_register := type_register_length'value
									(
									get_field
										(
										get_field
											(
											get_field(bsdl_string,f+2,trailer => true),
											ifs => ':',
											position => 2
											),
										position => 3
										)
									);

								put_line(2 * row_separator_0 & text_udb_instruction_register_length & row_separator_0 &
									trim(type_register_length'image(length_instruction_register),left));
								exit;
							end if;
						end if;
					end if;
				end loop;

				-- instruction capture
				for f in 1..field_count loop
					if to_lower(get_field(bsdl_string,f)) = text_bsdl_attribute then
						if to_lower(get_field(bsdl_string,f+1)) = text_bsdl_instruction_capture then
							if to_lower(get_field(bsdl_string,f+2)) = text_bsdl_of then
								put_line(2 * row_separator_0 & text_bsdl_instruction_capture & row_separator_0 & 
									get_bit_pattern(get_field(bsdl_string,f+2,trailer => true),width => length_instruction_register)
									);
								exit;
							end if;
						end if;
					end if;
				end loop;

				-- idcode register
				put(2 * row_separator_0 & text_bsdl_idcode_register & row_separator_0);
				for f in 1..field_count loop
					if to_lower(get_field(bsdl_string,f)) = text_bsdl_attribute then
						if to_lower(get_field(bsdl_string,f+1)) = text_bsdl_idcode_register then
							idcode_register_found := true;
							if to_lower(get_field(bsdl_string,f+2)) = text_bsdl_of then
								put_line(get_bit_pattern(get_field(bsdl_string,f+2,trailer => true),width => bic_idcode_register_length));
								exit;
							end if;
						end if;
					end if;
				end loop;
				if not idcode_register_found then
					put_line(text_udb_none);
				end if;

				-- usercode register
				put(2 * row_separator_0 & text_bsdl_usercode_register & row_separator_0);
				for f in 1..field_count loop
					if to_lower(get_field(bsdl_string,f)) = text_bsdl_attribute then
						if to_lower(get_field(bsdl_string,f+1)) = text_bsdl_usercode_register then
							usercode_register_found := true;
							if to_lower(get_field(bsdl_string,f+2)) = text_bsdl_of then
								put_line(get_bit_pattern(get_field(bsdl_string,f+2,trailer => true),width => bic_usercode_register_length));
								exit;
							end if;
						end if;
					end if;
				end loop;
				if not usercode_register_found then
					put_line(text_udb_none);
				end if;

				-- boundary length
				for f in 1..field_count loop
					if to_lower(get_field(bsdl_string,f)) = text_bsdl_attribute then
						if to_lower(get_field(bsdl_string,f+1)) = text_bsdl_boundary_length then
							if to_lower(get_field(bsdl_string,f+2)) = text_bsdl_of then
								length_boundary_register := type_register_length'value
									(
									get_field
										(
										get_field
											(
											get_field(bsdl_string,f+2,trailer => true),
											ifs => ':',
											position => 2
											),
										position => 3
										)
									);

								put_line(2 * row_separator_0 & text_udb_boundary_register_length & row_separator_0 &
									trim(type_register_length'image(length_boundary_register),left));
								exit;
							end if;
						end if;
					end if;
				end loop;

				-- trst pin
				put(2 * row_separator_0 & text_udb_trst_pin & row_separator_0);
				for f in 1..field_count loop
					if to_lower(get_field(bsdl_string,f)) = text_bsdl_attribute then
						if to_lower(get_field(bsdl_string,f+1)) = text_bsdl_tap_scan_reset then
							if to_lower(get_field(bsdl_string,f+2)) = text_bsdl_of then
								trst_pin := boolean'value(
									get_field
										(
										get_field
											(
											get_field(bsdl_string,f+2,trailer => true),
											ifs => ':',
											position => 2
											),
										position => 3
										)
									);
								exit;
							end if;
						end if;
					end if;
				end loop;
				if trst_pin then
					put_line(text_udb_available);
				else
					put_line(text_udb_none);
				end if;

				-- boundary register
				for f in 1..field_count loop
					if to_lower(get_field(bsdl_string,f)) = text_bsdl_attribute then
						if to_lower(get_field(bsdl_string,f+1)) = text_bsdl_boundary_register then
							if to_lower(get_field(bsdl_string,f+2)) = text_bsdl_of then
								read_boundary_register(get_field(bsdl_string,f+2,trailer => true), width => length_boundary_register);
								exit;
							end if;
						end if;
					end if;
				end loop;

			else
				put_line(message_error & "no entity found !");
				raise constraint_error;
			end if;
		end parse_bsdl;

	begin
		set_output(file_data_base_preliminary);
		while bic /= null loop
			put_line(row_separator_0 & section_mark.subsection & row_separator_0 & universal_string_type.to_string(bic.name));
			put_line(standard_output,"model file " & extended_string.to_string(bic.model_file));
			open(file => file_bsdl, mode => in_file, name => extended_string.to_string(bic.model_file));
			set_input(file_bsdl);
			--ptr_bsdl_entry := null;
			bsdl_string := to_unbounded_string("");
			while not end_of_file loop
				--line_counter := line_counter + 1;
				line_of_file := extended_string.to_bounded_string(get_line);
				line_of_file := remove_comment_from_line(line_of_file);
				if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything

					-- convert lines from bsdl file to a single string
					for c in 1..extended_string.length(line_of_file) loop
						if is_control(extended_string.element(line_of_file,c)) then -- control char. replaced by space
							bsdl_string := bsdl_string & latin_1.space;
						elsif extended_string.element(line_of_file,c) = latin_1.semicolon then -- add extra space after semicolon
							bsdl_string := bsdl_string & latin_1.semicolon & latin_1.space;
						else
							bsdl_string := bsdl_string & extended_string.element(line_of_file,c);
						end if;
					end loop;

-- 			put_line(2 * row_separator_0 & "usercode_register");
-- 			put_line(2 * row_separator_0 & "boundary_register_length");
-- 			put_line(2 * row_separator_0 & "trst_pin available");

				end if; -- if line contains anything
			end loop;

			--put_line(file_data_base_preliminary,to_string(bsdl_string));
			parse_bsdl(to_string(bsdl_string));

			close(file_bsdl);
			put_line(row_separator_0 & section_mark.endsubsection & row_separator_0 & universal_string_type.to_string(bic.name));
			new_line;
			bic := bic.next;
		end loop;

	end read_bsld_models;




-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin


	new_line;
	put_line("BSDL MODEL IMPORTER VERSION "& version);
	put_line("===============================");
	--prog_position	:= 10;
 	name_file_data_base:= universal_string_type.to_bounded_string(argument(1));
 	put_line("data base      : " & universal_string_type.to_string(name_file_data_base));

	--prog_position	:= 20;
	udb_summary := read_uut_data_base(universal_string_type.to_string(name_file_data_base));

	create_temp_directory;
	create_bak_directory;

	-- backup data base section scanpath_configuration (incl. comments)
	m1.extract_section( 
		universal_string_type.to_string(name_file_data_base),
		name_directory_bak & name_directory_separator & universal_string_type.to_string(name_file_data_base),
		section_mark.section,
		section_mark.endsection,
		section_scanpath_configuration
		);

	m1.extract_section( 
		universal_string_type.to_string(name_file_data_base),
		name_file_data_base_preliminary,
		section_mark.section,
		section_mark.endsection,
		section_scanpath_configuration
		);

	open( 
		file => file_data_base_preliminary,
		mode => append_file,
		name => name_file_data_base_preliminary
		);

	new_line (file_data_base_preliminary);
	put_line (file_data_base_preliminary,section_mark.section & row_separator_0 & section_registers);
	put_line (file_data_base_preliminary,column_separator_0);
	put_line (file_data_base_preliminary,"-- created by BSDL importer version " & version);
	put_line (file_data_base_preliminary,"-- date       : " & m1_internal.date_now); 

	read_bsld_models;

	put_line (file_data_base_preliminary,section_mark.endsection); 
	new_line (file_data_base_preliminary);

	close(file_data_base_preliminary);
--	copy_file(name_file_data_base_preliminary, universal_string_type.to_string(name_file_data_base));


	
end impbsdl;
