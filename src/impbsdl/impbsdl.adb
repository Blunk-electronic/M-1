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

with ada.containers;			use ada.containers;
--with ada.containers.ordered_maps;
with ada.containers.doubly_linked_lists;

with gnat.os_lib;   		use gnat.os_lib;
with ada.command_line;		use ada.command_line;
with ada.directories;		use ada.directories;

with m1; --use m1;
with m1_internal; 				use m1_internal;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;


procedure impbsdl is

	version			: string (1..3) := "0x1";
	udb_summary		: type_udb_summary;
	prog_position	: natural := 0;

	-- We need a container that holds items of type type_cell (all boundary register cells).
	type type_cell is
		record
			cell_id 		: type_cell_id;
			cell_type 		: type_boundary_register_cell;
			port 			: universal_string_type.bounded_string;
			port_index 		: type_port_index;
			cell_function 	: type_cell_function;
			safe_value 		: type_bit_char_class_1;
			control_cell 	: type_control_cell_id;
			disable_value 	: type_bit_char_class_0;
			disable_result 	: type_disable_result;
		end record;
-- 	package cell_map is new ordered_maps( key_type => type_cell_id, element_type => type_cell);
-- 	use cell_map;
-- 	the_cell_map : cell_map.map;
	package cell_container is new doubly_linked_lists(element_type => type_cell);
	use cell_container;
	boundary_register_cell_container : list;
	cell_cursor : cursor;
	bc_scratch : type_cell;
	
	
	procedure read_bsld_models is
		bic				: type_ptr_bscan_ic_pre := ptr_bic_pre;
		file_bsdl 		: ada.text_io.file_type;
		line_of_file	: extended_string.bounded_string;
		bsdl_string		: unbounded_string;
--		line_counter	: natural := 0;

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
		begin -- get_field
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
			text_bsdl_instruction_opcode	: constant string (1..18) := "instruction_opcode";
			text_bsdl_tap_scan_reset		: constant string (1..14) := "tap_scan_reset";
			text_bsdl_of					: constant string (1..2) := "of";

			-- UDB keywords
			text_udb_none							: constant string (1..4) := "none";
			text_udb_instruction_register_length 	: constant string (1..27) := "instruction_register_length";
			text_udb_boundary_register_length		: constant string (1..24) := "boundary_register_length";
			text_udb_trst_pin						: constant string (1..8) := "trst_pin";
			text_udb_available						: constant string (1..9) := "available";
			text_udb_safebits						: constant string (1..8) := "safebits";
			text_udb_opcodes						: constant string (1..7) := "opcodes";			

			procedure read_boundary_register (text_in : in string; width : in type_register_length) is
				-- Extracts from given string text_in cell id, type, port+index, function, save value and optional: control cell, disable value, disable result.
				-- Optional elements like port-index, control cell, disable value, disable result have a default in case not present.

				--subtype type_boundary_register_sized is type_boundary_register (1..length_boundary_register);
				--boundary_register : type_boundary_register_sized;

				pattern_start : boolean := false; -- used to trim header from text_in. the part that follows the first quotation matters.
				text_scratch : string (1..text_in'length) := text_in'length * latin_1.space; -- here a copy of text_in goes for subsequent in depth processing
				text_scratch_pt : positive := 1; -- points to character being processed when text_scratch is built
				open_sections_ct : natural := 0; -- increments on every opening parenthesis, decrements on every closing parenthesis found in text_scratch

				-- While extracting bounded strings are used as temporarily storage. Later they are converted to the actual types.
				-- Finally, when all elements of the cell are read, they are emptied ("") so that on reading the next cell things are cleaned up.
				cell_id_as_string, control_cell_id_as_string, cell_type_as_string, port_index_as_string,
				cell_function_as_string, cell_disable_result_as_string : universal_string_type.bounded_string; 
				-- CS: should be sufficient to hold those values

				cell_id 					: type_cell_id; -- id of actual cell --CS: make a subtype that does not exceed given width
				control_cell_id				: type_control_cell_id := -1; --  id of optional control cell. may be -1 if no control cell present --CS: make a subtype that does not exceed given width
				boundary_register_cell 		: type_boundary_register_cell; -- contains the cell type like BC_1

				-- This type is used to set the property of a cell to be read next:
				type type_boundary_register_cell_property is (prop_cell_type, prop_port, prop_function, prop_safe_value, prop_control_cell_id, prop_disable_value,  prop_disable_result);
				boundary_register_cell_property : type_boundary_register_cell_property := prop_cell_type;

				port : universal_string_type.bounded_string; -- the port name
				option_port_index, option_control_cell : boolean := false; -- true if port has an index like A4(3) / if cell has a control cell
				port_index				: type_port_index := -1; -- holds the port index (if present)

				cell_function 			: type_cell_function; -- holds something like output3
				cell_safe_value			: type_bit_char_class_1; -- holds the safe value of the cell
				cell_disable_value 		: type_bit_char_class_0 := '0'; -- holds the optional disable value of the control cell
				cell_disable_result 	: type_disable_result := Z; -- holds the disable result of the optional control cell

				procedure pack_cell_in_container(
					cell_id : in type_cell_id;
					cell_type : in type_boundary_register_cell;
					port : in universal_string_type.bounded_string;
					port_index : in type_port_index;
					cell_function : in type_cell_function;
					safe_value : in type_bit_char_class_1;
					control_cell : in type_control_cell_id;
					disable_value : in type_bit_char_class_0;
					disable_result : in type_disable_result
					) is
					bc : type_cell;
				begin
					bc.cell_id := cell_id;
					bc.cell_type := cell_type;
                    bc.port := port;
                    bc.port_index := port_index;
                    bc.cell_function := cell_function;
                    bc.safe_value := safe_value;
                    bc.control_cell := control_cell;
                    bc.disable_value := disable_value;
					bc.disable_result := disable_result;
					
					append(container => boundary_register_cell_container, new_item => bc);
				end pack_cell_in_container;

				
			begin -- read_boundary_register
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

				-- text_scratch contains segments like "0  (BC_1  Y2(4)  output3  X  16  1  Z)"
				-- This is the actual extracting work. Variable open_sections_ct indicates the level to parse at.
				for c in 1..text_scratch'length loop
					case open_sections_ct is
						when 0 => -- At this level we expect only the id of the actual boundary register cell.
							-- read cell id
							-- Collect digits of cell id in temporarily string. If digits have been collected and a non-digit is found,
							-- the cell_id is assumed as complete.
							if is_digit(text_scratch(c)) then
								cell_id_as_string := universal_string_type.append(left => cell_id_as_string, right => text_scratch(c));
							else
								if universal_string_type.length(cell_id_as_string) > 0 then -- cell_id complete
									cell_id := type_cell_id'value(universal_string_type.to_string(cell_id_as_string));
									--put(standard_output, " cell_id " & type_cell_id'image(cell_id));
									boundary_register_cell_property := prop_cell_type; -- up next: cell type at level 1 (after the first open parenthesis)
								end if;
							end if;
							
						when 1 => -- After passing the first opening parenthesis the level increases to 1. The element expected next is the cell type.
							case boundary_register_cell_property is
								when prop_cell_type =>
									-- read cell type
									-- Collect letters and digits of cell type in temporarily string. If character other that digits, letter and underscore
									-- found, the cell type is assumed as complete. like BC_7
									if is_digit(text_scratch(c)) or is_letter(text_scratch(c)) or text_scratch(c) = latin_1.low_line then
										cell_type_as_string := universal_string_type.append(left => cell_type_as_string, right => text_scratch(c));
									else
										if universal_string_type.length(cell_type_as_string) > 0 then
											boundary_register_cell := type_boundary_register_cell'value(universal_string_type.to_string(cell_type_as_string));
											--put(standard_output, " type " & type_boundary_register_cell'image(boundary_register_cell));
											boundary_register_cell_property := prop_port; -- up next: port name
										end if;
									end if;

								when prop_port =>
									-- read port name
									-- Collect charactes allowed for a port name. If foreign characters found, assume port name as complete.
									-- If opening parenthesis found, level increases to 2. This leads to reading the port index.
									-- After reading the port index, parsing continues here as the level then decreases to 1.
									if is_digit(text_scratch(c)) or is_letter(text_scratch(c)) or text_scratch(c) = latin_1.low_line or text_scratch(c) = latin_1.asterisk then
										port := universal_string_type.append(left => port, right => text_scratch(c));
									else
										if universal_string_type.length(port) > 0 then
											--put(standard_output, " port " & universal_string_type.to_string(port));
											boundary_register_cell_property := prop_function; -- up next: cell function (after reading the optional port index)
										end if;
									end if;

								when prop_function =>
									-- read direction
									-- Collect charactes allowed for cell function. If foreign characters found, assume function as complete.
									if is_digit(text_scratch(c)) or is_letter(text_scratch(c)) or text_scratch(c) = latin_1.low_line then
										cell_function_as_string := universal_string_type.append(left => cell_function_as_string, right => text_scratch(c));
									else
										if universal_string_type.length(cell_function_as_string) > 0 then
											cell_function := type_cell_function'value(universal_string_type.to_string(cell_function_as_string));
											--put(standard_output, " function " & type_cell_function'image(cell_function));
											boundary_register_cell_property := prop_safe_value; -- up next: safe value
										end if;
									end if;

								when prop_safe_value =>
									-- read safe value
									-- The safe value is a single character (x,X,0,1). Once a different character found,
									-- the safe value is complete.
									case text_scratch(c) is
										when 'X' | 'x' => 
											cell_safe_value := 'X';
											--put(standard_output, " sv " & type_bit_char_class_1'image(cell_safe_value));
											boundary_register_cell_property := prop_control_cell_id; -- up next: control cell id
										when '0' => 
											cell_safe_value := '0';
											--put(standard_output, " sv " & type_bit_char_class_1'image(cell_safe_value));
											boundary_register_cell_property := prop_control_cell_id; -- up next: control cell id
										when '1' => 
											cell_safe_value := '1';
											--put(standard_output, " sv " & type_bit_char_class_1'image(cell_safe_value));
											boundary_register_cell_property := prop_control_cell_id; -- up next: control cell id
										when others => null;
									end case;

								when prop_control_cell_id =>
									-- read control cell id (optional)
									-- Collect digits of control cell id in temporarily string. If digits have been collected and a non-digit is found,
									-- the control_cell_id is assumed as complete.
									-- The option_control_cell flag is set to indicate later that there is a control cell.
									if is_digit(text_scratch(c)) then
										control_cell_id_as_string := universal_string_type.append(left => control_cell_id_as_string, right => text_scratch(c));
									else
										if universal_string_type.length(control_cell_id_as_string) > 0 then
											control_cell_id := type_cell_id'value(universal_string_type.to_string(control_cell_id_as_string));
											option_control_cell := true;
											--put(standard_output, " ctrl " & type_cell_id'image(control_cell_id));
											boundary_register_cell_property := prop_disable_value; -- up next: disable value
										end if;
									end if;

								when prop_disable_value =>
									-- read disable value (optional)
									-- The disable value is a single character (0,1). Once a different character found,
									-- the disable value is complete.
									case text_scratch(c) is
										when '0' => 
											cell_disable_value := '0';
											--put(standard_output, " dv " & type_bit_char_class_0'image(cell_disable_value));
											boundary_register_cell_property := prop_disable_result; -- up next: disable result
										when '1' => 
											cell_disable_value := '1';
											--put(standard_output, " dv " & type_bit_char_class_0'image(cell_disable_value));
											boundary_register_cell_property := prop_disable_result; -- up next: disable result
										when others => null;
									end case;

								when prop_disable_result =>
									-- read disable result (optional)
									-- Collect characters allowed for disable result. If foreign characters found, assume disable result as complete.
									if is_digit(text_scratch(c)) or is_letter(text_scratch(c)) then
										cell_disable_result_as_string := universal_string_type.append(left => cell_disable_result_as_string, right => text_scratch(c));
									else
										if universal_string_type.length(cell_disable_result_as_string) > 0 then
											cell_disable_result := type_disable_result'value(universal_string_type.to_string(cell_disable_result_as_string));
											--put(standard_output, " dr " & type_disable_result'image(cell_disable_result));
											-- up next: cell id of next boundary register cell at level 0
										end if;
									end if;
									

								when others => null;
							end case;

							-- 0  (BC_1  Y2(4)  output3  X  16  1  Z)

						when 2 =>
							-- read port index
							-- This level is reached after a second opening parenthesis after reading the port name.
							-- Collect digits of port index in temporarily string. If digits have been collected and a non-digit is found,
							-- the index is assumed as complete.
							-- The option_port_index flag is set to indicate later that there is a port with index.
							-- Once a second closing parenthesis is detected, the level decreases to 1.
							if is_digit(text_scratch(c)) then
								port_index_as_string := universal_string_type.append(left => port_index_as_string, right => text_scratch(c));
							else
								if universal_string_type.length(port_index_as_string) > 0 then
									port_index := type_port_index'value(universal_string_type.to_string(port_index_as_string));
									option_port_index := true;
									--put(standard_output, " idx " & natural'image(port_index));
									boundary_register_cell_property := prop_function; -- up next: cell function at level 1
								end if;
-- 								port_index_as_string := universal_string_type.to_bounded_string("");
							end if;
							
						when others => null; -- there are no other levels. means no more than two opening parenthesis.
					end case;

					-- Count up/down opening and closing parenthesis to detect the parsing level:
					-- 0 -> all parenthesis closed
					-- 1 -> one open parenthesis
					-- 2 -> two open parenthesis
					-- Once all parenthesis closed. All cell properties have been read. Cell is ready for inserting into container.
					case text_scratch(c) is
						when latin_1.left_parenthesis => -- open parenthesis found
							open_sections_ct := open_sections_ct + 1;
						when latin_1.right_parenthesis => -- close parenthesis found
							open_sections_ct := open_sections_ct - 1;

							if open_sections_ct = 0 then -- cell data complete
								--put(standard_output, " cell_id " & type_cell_id'image(cell_id));
								--put(standard_output, " type " & type_boundary_register_cell'image(boundary_register_cell));
								--put(standard_output, " port " & universal_string_type.to_string(port));

								-- if port has index, reset flag that indicates so
								if option_port_index then
									--put(standard_output, " idx " & type_port_index'image(port_index));
									option_port_index := false;
								end if;

								--put(standard_output, " function " & type_cell_function'image(cell_function));
								--put(standard_output, " sv " & type_bit_char_class_1'image(cell_safe_value));

								-- if cell has control cell, reset flag that indicates so
								if option_control_cell then
									--put(standard_output, " ctrl " & type_cell_id'image(control_cell_id));
									--put(standard_output, " dv " & type_bit_char_class_0'image(cell_disable_value));
									--put(standard_output, " dr " & type_disable_result'image(cell_disable_result));
									option_control_cell := false;
								end if;
								--new_line(standard_output); -- for debug
								
								pack_cell_in_container(
									cell_id => cell_id,
									cell_type => boundary_register_cell,
									port => port,
									port_index => port_index,
									cell_function => cell_function,
									safe_value => cell_safe_value,
									control_cell => control_cell_id,
									disable_value => cell_disable_value,
									disable_result => cell_disable_result
									);

								-- empty temporarily strings
								cell_id_as_string := universal_string_type.to_bounded_string(""); -- empty temporarily string
								cell_type_as_string := universal_string_type.to_bounded_string("");  -- empty temporarily string
								port := universal_string_type.to_bounded_string("");  -- empty temporarily string
								port_index_as_string := universal_string_type.to_bounded_string("");  -- empty temporarily string
								cell_function_as_string := universal_string_type.to_bounded_string("");  -- empty temporarily string
								control_cell_id_as_string := universal_string_type.to_bounded_string("");  -- empty temporarily string
								cell_disable_result_as_string := universal_string_type.to_bounded_string("");  -- empty temporarily string
							end if;

						when others => -- other characters don't matter for the parse level
							null;
					end case;
				end loop;
				--put_line(standard_output,text_scratch);
			end read_boundary_register;

			procedure read_opcodes(text_in : in string; width : in type_register_length) is
				-- Extracts from given string text_in instruction, opcode and alternative opcodes.
				pattern_start : boolean := false; -- used to trim header from text_in. the part that follows the first quotation matters.
				text_scratch : string (1..text_in'length) := text_in'length * latin_1.space; -- here a copy of text_in goes for subsequent in depth processing
				text_scratch_pt : positive := 1; -- points to character being processed when text_scratch is built
				open_sections_ct : natural := 0; -- increments on every opening parenthesis, decrements on every closing parenthesis found in text_scratch

				-- While extracting bounded strings are used as temporarily storage. Later they are converted to the actual types.
				-- Finally, when all elements of the cell are read, they are emptied ("") so that on reading the next cell things are cleaned up.
				instruction_as_string, opcode_as_string : universal_string_type.bounded_string; 
				-- CS: should be sufficient to hold those values.
				instruction_name_complete : boolean := false;
				opcode_complete : boolean := false;
				--instruction : type_bic_instruction; 
				--type type_opcode is array (type_register_length range 1..width) of type_bit_char_class_1;
				--opcode : type_opcode;
				--opcode : type_string_of_bit_characters_class_1 (1..width);
				
			begin -- read_opcodes
				-- remove quotations, commas and ampersands
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

				-- text_scratch contains segments like "BYPASS (11111111  10000100  00000101  10001000  00000001)"
				-- This is the actual extracting work. Variable open_sections_ct indicates the level to parse at.
 				for c in 1..text_scratch'length loop
 					case open_sections_ct is
 						when 0 => -- At this level we expect only the instruction names.
 							-- read instruction name
 							-- Collect characters allowed in instruction names in temporarily string. If other character found,
							-- the name is assumed as complete.
							if not instruction_name_complete then
								if is_letter(text_scratch(c)) then
									instruction_as_string := universal_string_type.append(left => instruction_as_string, right => text_scratch(c));
								else
									if universal_string_type.length(instruction_as_string) > 0 then -- instruction name complete
										instruction_name_complete := true;
										put(standard_output, " instruction " & universal_string_type.to_string(instruction_as_string));
	-- 									boundary_register_cell_property := prop_cell_type; -- up next: cell type at level 1 (after the first open parenthesis)
									end if;
								end if;
							end if;

						when 1 => -- After passing the first opening parenthesis the level increases to 1. The element expected next is the cell type.
							-- read opcodes
							-- Collect charactes allowed for opcodes. If foreign character found, assume opcode as complete.
								if text_scratch(c) = 'x' or text_scratch(c) = 'X' or text_scratch(c) = '0' or text_scratch(c) = '1' then
									opcode_as_string := universal_string_type.append(left => opcode_as_string, right => text_scratch(c));
									opcode_complete := false;
								else
									if universal_string_type.length(opcode_as_string) > 0 then
										opcode_complete := true;
										--opcode := to_binary(text_in => universal_string_type.to_string(opcode_as_string); length => width; class => class_1);
										--opcode := to_binary(text_in => "0101"; length => width; class => class_1);
										put(standard_output, " opcode " & universal_string_type.to_string(opcode_as_string));
									end if;
								end if;

 						when others => null; -- there are no other levels. means no more than two opening parenthesis.
 					end case;
 
					-- Count up/down opening and closing parenthesis to detect the parsing level:
					-- 0 -> all parenthesis closed
					-- 1 -> one open parenthesis
					-- Once all parenthesis closed. All cell properties have been read. Cell is ready for inserting into container.
					case text_scratch(c) is
						when latin_1.left_parenthesis => -- open parenthesis found
							open_sections_ct := open_sections_ct + 1;
						when latin_1.right_parenthesis => -- close parenthesis found
							open_sections_ct := open_sections_ct - 1;

							if open_sections_ct = 0 then -- instruction data complete
								--put(standard_output, " cell_id " & type_cell_id'image(cell_id));
								--put(standard_output, " type " & type_boundary_register_cell'image(boundary_register_cell));
								--put(standard_output, " port " & universal_string_type.to_string(port));

								instruction_name_complete := false;	
								instruction_as_string := universal_string_type.to_bounded_string("");
								opcode_as_string := universal_string_type.to_bounded_string("");
								null;
							end if;

						when others => -- other characters don't matter for the parse level
							null;
					end case;
				end loop;
				--put_line(standard_output,text_scratch);
			end read_opcodes;
			
		begin -- parse_bsdl
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

				-- read boundary register
				for f in 1..field_count loop
					if to_lower(get_field(bsdl_string,f)) = text_bsdl_attribute then
						if to_lower(get_field(bsdl_string,f+1)) = text_bsdl_boundary_register then
							if to_lower(get_field(bsdl_string,f+2)) = text_bsdl_of then
								-- The whole boundary register is passed as a single long string to procedure read_boundary_register:
								read_boundary_register(get_field(bsdl_string,f+2,trailer => true), width => length_boundary_register);
								exit;
							end if;
						end if;
					end if;
				end loop;

				-- write safe bits
				put_line(2 * row_separator_0 & section_mark.subsection & row_separator_0 & text_udb_safebits);
				put_line(10 * row_separator_0 & "-- MSB..LSB");
				put(4 * row_separator_0 & text_udb_safebits & row_separator_0);

				for s in reverse 0..length_boundary_register-1 loop -- start with MSB
					cell_cursor := first(boundary_register_cell_container);
					bc_scratch := element(cell_cursor);
					while bc_scratch.cell_id /= s loop
						cell_cursor := next(cell_cursor);
						bc_scratch := element(cell_cursor);
					end loop;
					if bc_scratch.cell_id = s then
						put(type_bit_char_class_1'image(bc_scratch.safe_value)(2)); -- strip quotes from safe value
					end if;
				end loop;
				new_line;
				put_line(4 * row_separator_0 & "total " & type_register_length'image(length_boundary_register));
				put_line(2 * row_separator_0 & section_mark.endsubsection);

				-- opcodes
				new_line;				
				put_line(2 * row_separator_0 & section_mark.subsection & row_separator_0 & text_udb_opcodes);
				put_line(2 * row_separator_0 & "-- instruction opcode [alternative opcode]");
				for f in 1..field_count loop
					if to_lower(get_field(bsdl_string,f)) = text_bsdl_attribute then
						if to_lower(get_field(bsdl_string,f+1)) = text_bsdl_instruction_opcode then
							if to_lower(get_field(bsdl_string,f+2)) = text_bsdl_of then
								-- The whole opcode section is passed as a single long string to procedure read_opcodes:
								read_opcodes(get_field(bsdl_string,f+2,trailer => true), width => length_instruction_register);
								exit;
							end if;
						end if;
					end if;
				end loop;


				
				put_line(2 * row_separator_0 & section_mark.endsubsection);
				--put_line(standard_output,"query cell: ");

-- 				put_line(standard_output, type_cell_id'image(bc_scratch.cell_id));
-- 				put_line(standard_output, universal_string_type.to_string(bc_scratch.port));
				-- 				put_line(standard_output, type_cell_function'image(bc_scratch.cell_function));

				
				clear(boundary_register_cell_container); -- purge container for next BSDL model
			else
				put_line(message_error & "no entity found !");
				raise constraint_error;
			end if;
		end parse_bsdl;

	begin -- read_bsld_models
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
	prog_position	:= 10;
 	name_file_data_base:= universal_string_type.to_bounded_string(argument(1));
 	put_line("data base      : " & universal_string_type.to_string(name_file_data_base));

	prog_position	:= 20;
	udb_summary := read_uut_data_base(universal_string_type.to_string(name_file_data_base));

	prog_position	:= 30;
	create_temp_directory;
	prog_position	:= 40;
	create_bak_directory;

	-- backup data base section scanpath_configuration (incl. comments)
	prog_position	:= 50;
	m1.extract_section( 
		universal_string_type.to_string(name_file_data_base),
		name_directory_bak & name_directory_separator & universal_string_type.to_string(name_file_data_base),
		section_mark.section,
		section_mark.endsection,
		section_scanpath_configuration
		);

	prog_position	:= 60;
	m1.extract_section( 
		universal_string_type.to_string(name_file_data_base),
		name_file_data_base_preliminary,
		section_mark.section,
		section_mark.endsection,
		section_scanpath_configuration
		);

	prog_position	:= 70;
	open( 
		file => file_data_base_preliminary,
		mode => append_file,
		name => name_file_data_base_preliminary
		);

	prog_position	:= 80;
	new_line (file_data_base_preliminary);
	put_line (file_data_base_preliminary,section_mark.section & row_separator_0 & section_registers);
	put_line (file_data_base_preliminary,column_separator_0);
	put_line (file_data_base_preliminary,"-- created by BSDL importer version " & version);
	put_line (file_data_base_preliminary,"-- date       : " & m1_internal.date_now); 

	prog_position	:= 90;
	read_bsld_models;

	prog_position	:= 100;
	put_line (file_data_base_preliminary,section_mark.endsection); 
	new_line (file_data_base_preliminary);

	prog_position	:= 110;
	close(file_data_base_preliminary);
--	copy_file(name_file_data_base_preliminary, universal_string_type.to_string(name_file_data_base));

-- CS: exception handler
	
end impbsdl;
