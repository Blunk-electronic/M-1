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
with ada.characters.handling;   use ada.characters.handling;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.strings; 				use ada.strings;
with ada.strings.maps;			use ada.strings.maps;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
with ada.containers;			use ada.containers;
with ada.containers.doubly_linked_lists;

with gnat.os_lib;   		use gnat.os_lib;
with ada.command_line;		use ada.command_line;
with ada.directories;		use ada.directories;

with m1; --use m1;
with m1_internal; 				use m1_internal;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;


procedure impbsdl is

	version			: string (1..3) := "035";
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
		option_remove_prefix : boolean := false;
		option_prefix_to_remove : universal_string_type.bounded_string;
		
		function get_field
		-- Extracts a field separated by ifs at position. If trailer is true, the trailing content untiil trailer_to is also returned.
				(
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
				port_index				: type_port_index := type_port_index'first; -- holds the port index (if present), default is -1 to indicate there is no index

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

								-- If port has index, reset flag option_port_index for next cell.
								-- If port has no index, set control cell id to default (-1) to indicate there is no index.
								if option_port_index then
									--put(standard_output, " idx " & type_port_index'image(port_index));
									option_port_index := false;
								else
									port_index := type_port_index'first;
								end if;

								--put(standard_output, " function " & type_cell_function'image(cell_function));
								--put(standard_output, " sv " & type_bit_char_class_1'image(cell_safe_value));

								-- If cell has control cell, reset flag option_control_cell for next cell.
								-- If cell has no control cell, set control_cell_id to default (-1) to indicate there is no control cell.
								if option_control_cell then
									--put(standard_output, " ctrl " & type_cell_id'image(control_cell_id));
									--put(standard_output, " dv " & type_bit_char_class_0'image(cell_disable_value));
									--put(standard_output, " dr " & type_disable_result'image(cell_disable_result));
									option_control_cell := false;
								else
									control_cell_id := type_control_cell_id'first;
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
				-- CS: limit to 1 as the parsing level never increases further here.

				-- While extracting bounded strings are used as temporarily storage. Later they are converted to the actual types.
				-- Finally, when all elements of the cell are read, they are emptied ("") so that on reading the next cell things are cleaned up.
				instruction_as_string, opcode_as_string : universal_string_type.bounded_string; -- CS: for opcode_as_string use fixed string of length = width
				-- CS: should be sufficient to hold those values.
				instruction_name_complete : boolean := false;
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
				-- open_sections_ct never raises above 1.
 				for c in 1..text_scratch'length loop
 					case open_sections_ct is
 						when 0 => -- At this level we expect only the instruction names.
 							-- read instruction name
 							-- Collect characters allowed in instruction names in temporarily string. If other character found,
							-- the name is assumed as complete.
							-- When the instruction is complete, the flag instruction_name_complete is set so that subsequent characters at this
							-- level are ignored.
							if not instruction_name_complete then
								if is_letter(text_scratch(c)) then
									instruction_as_string := universal_string_type.append(left => instruction_as_string, right => text_scratch(c));
								else
									if universal_string_type.length(instruction_as_string) > 0 then -- instruction name complete
										instruction_name_complete := true;
										put(4 * row_separator_0 & universal_string_type.to_string(instruction_as_string));
										--put(standard_output, " instruction " & universal_string_type.to_string(instruction_as_string));
									end if;
								end if;
							end if;

						when 1 => -- After passing the first opening parenthesis the level increases to 1. The element expected next is the first opcode.
							-- read opcodes
							-- Collect charactes allowed for opcodes. If foreign character found, assume opcode as complete.
								if text_scratch(c) = 'x' or text_scratch(c) = 'X' or text_scratch(c) = '0' or text_scratch(c) = '1' then
									opcode_as_string := universal_string_type.append(left => opcode_as_string, right => text_scratch(c));
								else
									if universal_string_type.length(opcode_as_string) > 0 then
										--put(standard_output, " opcode " & universal_string_type.to_string(opcode_as_string));
										-- CS: check std conformity of opcode
										--if universal_string_type.length(opcode_as_string) = width then
										put(row_separator_0 & universal_string_type.to_string(opcode_as_string));
										opcode_as_string := universal_string_type.to_bounded_string("");
									end if;
								end if;

 						when others => null; -- there are no other levels. means no more than two opening parenthesis.
 					end case;
 
					-- Count up/down opening and closing parenthesis to detect the parsing level:
					-- 0 -> all parenthesis closed
					-- 1 -> one open parenthesis
					-- Once all parenthesis closed. All opcodes of the current instruction have been read. Reset flag instruction_name_complete so that
					-- next instruction name can be read.
					case text_scratch(c) is
						when latin_1.left_parenthesis => -- open parenthesis found
							open_sections_ct := open_sections_ct + 1;
						when latin_1.right_parenthesis => -- close parenthesis found
							open_sections_ct := open_sections_ct - 1;

							if open_sections_ct = 0 then -- instruction data complete
								instruction_name_complete := false;	
								instruction_as_string := universal_string_type.to_bounded_string(""); -- clean up for next instruction name
								new_line;
							end if;

						when others => -- other characters don't matter for the parse level
							null;
					end case;
				end loop;
				--put_line(standard_output,text_scratch);
			end read_opcodes;


			procedure put_cell_properties(bc : in type_cell) is
			begin
				put(4 * row_separator_0 &
				type_cell_id'image(bc_scratch.cell_id) & row_separator_0 &
				type_boundary_register_cell'image(bc_scratch.cell_type) & row_separator_0 &
				universal_string_type.to_string(bc_scratch.port)
				); 
				if bc_scratch.port_index > type_port_index'first then
					put('(' & trim(type_port_index'image(bc_scratch.port_index),left) & ')');
				end if;
				put(row_separator_0 & type_cell_function'image(bc_scratch.cell_function) & row_separator_0 &
					type_bit_char_class_1'image(bc_scratch.safe_value)(2) & row_separator_0  -- strip quotes from safe value
				);
				if bc_scratch.control_cell > type_control_cell_id'first then
					put(trim(type_cell_id'image(bc_scratch.control_cell),left) & row_separator_0 &
						type_bit_char_class_0'image(bc_scratch.disable_value)(2) & row_separator_0 & -- strip quotes from disable value
						type_disable_result'image(bc_scratch.disable_result)
						);
				end if;
				new_line;
			end put_cell_properties;

			procedure read_port_io_map(text_in : in string) is
			-- Extracts the port io map from the given string. The port io map starts with keyword "port" and the first opening parenthesis follwing "port".
			-- The port io map ends when all parenthesis are closed (level 0 reached).
				text_scratch : string (1..text_in'length) := text_in'length * latin_1.space; -- here a copy of text_in goes for subsequent in depth processing				
				text_scratch_pt : positive := positive'first; -- points to character being processed
				open_sections_ct : natural := 0; -- increments on every opening parenthesis, decrements on every closing parenthesis found in text_scratch 
				-- CS: limit to 2
				
				port_identifier_complete 	: boolean := false;
				port_identifier_as_string 	: universal_string_type.bounded_string;
				port_name_complete 			: boolean := false;				
				port_name_as_string 		: universal_string_type.bounded_string;

				procedure fraction_port_string (text_in : in string) is 
				-- Breaks down a string like "OE_NEG1:in bit; Y1:out bit_vector 1 to 4 ; Y2:out bit_vector 1 to 4 ; OE_NEG2:in bit; GND, VCC:linkage bit; TDO:out bit"
				-- into ports like "OE_NEG1:in bit"
					text_scratch : string (1..text_in'length + 1) := text_in & latin_1.semicolon; -- with this copy of text_in we continue. it requires a semicolon at 
					-- the end in order to detect the end of the last port segment.
					port_string : universal_string_type.bounded_string;

					procedure write_port_name (text_in : in string) is -- "Y1:out bit_vector 1 to 4" or "GND, VCC:linkage bit" or "OE_NEG2:in bit"
						port_name : universal_string_type.bounded_string;

						procedure write_port_direction (text_in : in string) is -- "out bit_vector 1 to 4"
						-- writes port direction and vector parameters in premilinary database.
						begin
							-- the first field here is either "out", "in" or "linkage" 
							put(get_field(text_in => text_in, position => 1) & row_separator_0); 

							-- the next field is either "bit" or "bit_vector". other fields are not accepted and considered as invalid
							if get_field(text_in => text_in, position => 2) = text_bsdl_bit_vector then

								-- field 4 contains "to" or "downto". write vector start and end indexes.
								if get_field(text_in => text_in, position => 4) = text_bsdl_to then
									put(get_field(text_in => text_in, position => 3) & row_separator_0 & text_bsdl_to & row_separator_0 & get_field(text_in => text_in, position => 5));
								elsif get_field(text_in => text_in, position => 4) = text_bsdl_downto then
									put(get_field(text_in => text_in, position => 5) & row_separator_0 & text_bsdl_downto & row_separator_0 & get_field(text_in => text_in, position => 3));
								else -- no "to" or "downto" found
									raise constraint_error;
								end if;
							elsif get_field(text_in => text_in, position => 2) = text_bsdl_bit then
								null;
							else -- field 2 invalid
								raise constraint_error;
							end if;
							new_line;
						end write_port_direction;
						
					begin -- write_port_name
						--put_line(standard_output,text_in);
						-- A colon separates between port name and direction like "OE_NEG2:in bit" or "GND, VCC:linkage bit"
						-- Once the colon has been found put the port name. Once the colon has been found, the port name is written into the premilinary data base.
						-- Subsequent characters (belonging to the port direction) are collected and finally passed to write_port_direction.
						-- A comma separates port names belonging to a linkage group. The comma is replaced by space.
						for c in text_in'first..text_in'last loop
							case text_in(c) is
								when latin_1.colon =>
									put(5 * row_separator_0 & trim(universal_string_type.to_string(port_name),both) & row_separator_0 & latin_1.colon & row_separator_0);
									port_name := universal_string_type.to_bounded_string("");
								when latin_1.comma =>
									port_name := universal_string_type.append(left => port_name, right => latin_1.space);
								when others => 
									port_name := universal_string_type.append(left => port_name, right => text_in(c));
							end case;
						end loop;
						write_port_direction (universal_string_type.to_string(port_name));
					end write_port_name;
						
				begin -- fraction_port_string
				-- A semicolon indicates the end of the port. All characters found until semicolon are collected and 
				-- then passed to write_port_name.
					for c in text_scratch'first..text_scratch'last loop
						case text_scratch(c) is
							when latin_1.semicolon =>
								--put_line(standard_output, universal_string_type.to_string(port_string));
								write_port_name(universal_string_type.to_string(port_string)); -- "OE_NEG2:in bit"
								port_string := universal_string_type.to_bounded_string(""); -- clear port_string for next port
							when others => 
								port_string := universal_string_type.append(left => port_string, right => text_scratch(c));
						end case;
					end loop;
--					put_line(standard_output,text_in);
				end fraction_port_string;
				
			begin -- read_port_io_map
				-- This is the actual extracting work. Variable open_sections_ct indicates the level to parse at.
 				for c in 1..text_in'length loop
 					case open_sections_ct is
 						when 0 => -- At this level we expect only the port identifier.
 							-- Collect characters allowed in port identifier in temporarily string. If other character found,
							-- and the word matches text_bsdl_port_identifier then the identifier is assumed as complete.
							-- When the port identifier is complete, the flag port_identifier_complete is set so that subsequent characters at this
							-- level are ignored. This flag also signals that characters found at level 1 and 2 are to be processed further-on (because they
							-- belong to the port io map.).
							if not port_identifier_complete then
								if is_letter(text_in(c)) then
									port_identifier_as_string := universal_string_type.append(left => port_identifier_as_string, right => text_in(c));
								else
									if universal_string_type.length(port_identifier_as_string) > 0 then -- identifier complete
										if to_lower(universal_string_type.to_string(port_identifier_as_string)) = text_bsdl_port_identifier then -- identifier match
											port_identifier_complete := true;
											--put(standard_output,"port ");
										else
											port_identifier_as_string := universal_string_type.to_bounded_string("");
										end if;
									end if;
								end if;
							end if;

						when 1 | 2 => -- Process characters at this level if port identifier has been found at level 0.
							if port_identifier_complete then

								-- replace parenthesis by space. other characters are to be collected in text_scratch
								if text_in(c) = latin_1.right_parenthesis or text_in(c) = latin_1.left_parenthesis then
									text_scratch(text_scratch_pt) := latin_1.space;
								else
									text_scratch(text_scratch_pt) := text_in(c);
								end if;
								text_scratch_pt := text_scratch_pt + 1; -- advance character pointer in text_scratch (for next character)
							end if;

 						when others => null; -- there are no other levels. means no more than two opening parenthesis.
 					end case;
 
					-- Count up/down opening and closing parenthesis to detect the parsing level:
					-- 0 -> all parenthesis closed
					-- 1 -> one open parenthesis
					-- Once all parenthesis closed, the port io map has been read. The port io map is then passed to procedure fraction_port_string.
					case text_in(c) is
						when latin_1.left_parenthesis => -- open parenthesis found
							open_sections_ct := open_sections_ct + 1;
						when latin_1.right_parenthesis => -- close parenthesis found
							open_sections_ct := open_sections_ct - 1;

							if open_sections_ct = 0 then
								if port_identifier_complete then
									--put_line(standard_output,text_scratch(text_scratch'first..text_scratch_pt));
									-- "OE_NEG1:in bit; Y1:out bit_vector 1 to 4 ; Y2:out bit_vector 1 to 4 ; OE_NEG2:in bit; GND, VCC:linkage bit; TDO:out bit"
									fraction_port_string(text_scratch(text_scratch'first..text_scratch_pt));
									--port_identifier_complete := false;
									--text_scratch_pt := positive'first;
									exit;
								end if;
							end if;

						when others => -- other characters don't matter for the parse level
							null;
					end case;
				end loop;
				--put_line(standard_output,text_scratch);

			end read_port_io_map;


			procedure read_port_pin_map(text_in : in string; package_name : in string) is
			-- Extracts the port pin map from the given string. The port pin map starts with keyword "constant" followed by the package name.
			-- The port pin map ends with a semicolon.
			-- example:     constant DW : PIN_MAP_STRING := "OE_NEG1:1, Y1:(2,3,4,5)," &
            --				"Y2:(7,8,9,10), A1:(23,22,21,20)," &
            --				"A2:(19,17,16,15), OE_NEG2:24, GND:6," &
            --				"VCC:18, TDO:11, TDI:14, TMS:12, TCK:13";
				open_sections_ct : natural := 0; -- increments on every opening parenthesis, decrements on every closing parenthesis found in text_scratch 
				-- CS: limit to 2
				scratch_string 	: universal_string_type.bounded_string;
				keyword_constant_complete : boolean := false; -- goes true once a keyword "constant" found
				pattern_start : positive := positive'first; -- the position of the first character after the targeted package

				procedure trim_port_pin_map(text_in : in string) is
				-- Extracts from a string like
				-- : PIN_MAP_STRING := "OE_NEG1:1, Y1:(2,3,4,5)," & "Y2:(7,8,9,10), A1:(23,22,21,20)," & "A2:(19,17,16,15), OE_NEG2:24, GND:6," & "VCC:18, TDO:11, TDI:14, TMS:12, TCK:13"
				-- the port name like "OE_NEG1" and its pin names "2 3 4 5".
					text_scratch : string (1..text_in'length) := text_in; -- here a copy of text_in goes for subsequent in depth processing
					map_start : positive := index(text_scratch, 1 * latin_1.quotation); -- the pin map string starts at the first quotation in the given string
					port : extended_string.bounded_string;
					port_index : boolean := false; -- true when cursor is inside a port index group like "(7,8,9,10)"

					procedure format_port (text_in : in string) is -- "OE_NEG1:1" or "Y1:2 3 4 5"
					-- Replaces in text_in the colon by space and writes the string in the premilinary data base.
					-- If option "remove_pin_prefix xyz" given, the prefix xyz gets removed from the pin name.
						text_scratch : string (1..text_in'length) := text_in; -- here a copy of text_in goes for subsequent in depth processing						
						position_colon : positive := index(text_scratch, 1 * latin_1.colon);
					begin
						-- check option
						if option_remove_prefix then
							put_line(standard_output,"remove prefix " & universal_string_type.to_string(option_prefix_to_remove));
						end if;
						text_scratch(position_colon) := latin_1.space;
						put_line(5 * row_separator_0 & text_scratch);
					end format_port;
					
				begin -- trim_port_pin_map
					-- First we replace quotes and ampersands by space (within the range of interest)
					for c in map_start..text_scratch'last loop
						case text_scratch(c) is
							when latin_1.quotation => 
								text_scratch(c) := latin_1.space;
							when latin_1.ampersand => 								
								text_scratch(c) := latin_1.space;
							when others => null;
						end case;
					end loop;

					-- text_scratch now holds something like 
					-- OE_NEG1:1, Y1:(2,3,4,5), Y2:(7,8,9,10), A1:(23,22,21,20), A2:(19,17,16,15), OE_NEG2:24, GND:6, VCC:18, TDO:11, TDI:14, TMS:12, TCK:13
					--put_line(text_scratch(map_start..text_scratch'last));

					-- Commas inside a port index group are replaced by space.
					-- Other commas signal the end of the port like "Y2:(7,8,9,10),". The port is then passed to procedure format_port.
					for c in map_start..text_scratch'last loop
						case text_scratch(c) is
							when latin_1.left_parenthesis => port_index := true;
							when latin_1.right_parenthesis => port_index := false;
							when latin_1.comma =>
								if port_index then -- pin separator inside port index group
									port := extended_string.append(left => port, right => latin_1.space);
									--put_line(standard_output,extended_string.to_string(port));
								else -- end of port reached
									format_port(trim(extended_string.to_string(port),left));
									port := extended_string.to_bounded_string(""); -- clean up for next port
								end if;
							when others => -- collect characters belonging to port
								port := extended_string.append(left => port, right => text_scratch(c));
						end case;
					end loop;
					-- The last port does not end with a comma. So we pass it to format_port finally.
 					format_port(trim(extended_string.to_string(port),left));
				end trim_port_pin_map;
				
			begin -- read_port_pin_map
				--put_line(text_in);
				-- This is the actual extracting work. Variable open_sections_ct indicates the level to parse at.
 				for c in 1..text_in'length loop
 					case open_sections_ct is
 						when 0 => -- At this level we expect only the keyword "constant".
 							-- Collect letters. If other character found nd the scratch_string matches "constant" then the package name is expected next.
							-- When "constant" found, the flag keyword_constant_complete is set so that the package name is seached for next.
							-- The position of the first character after the package name is saved in pattern_start. Once pattern_start has been loaded with 
							-- that position, the targeted port pin map is passed to trim_port_pin_map.
							if not keyword_constant_complete then
								if is_letter(text_in(c)) then
									scratch_string := universal_string_type.append(left => scratch_string, right => text_in(c));
 								else
 									if universal_string_type.length(scratch_string) > 0 then -- any word complete
										if to_lower(universal_string_type.to_string(scratch_string)) = text_bsdl_constant then -- keyword "constant" match
											--put_line(standard_output,"constant");
											keyword_constant_complete := true;
										end if;
										scratch_string := universal_string_type.to_bounded_string(""); -- clean up scratch for next word
									end if;
								end if;
							else
								if pattern_start = positive'first then -- no package match yet
									if is_letter(text_in(c)) or is_digit(text_in(c)) then
										scratch_string := universal_string_type.append(left => scratch_string, right => text_in(c));
										--put(standard_output,text_in(c));
									else
										if universal_string_type.length(scratch_string) > 0 then -- any word complete
											if to_lower(universal_string_type.to_string(scratch_string)) = to_lower(package_name) then -- package name match
												--put_line(standard_output,"package");
												pattern_start := c; -- save position of first character after package name
											end if;
											scratch_string := universal_string_type.to_bounded_string(""); -- clean up scratch for next word
										end if;
									end if;
								else -- package name found. wait for first semicolon in string and pass string to trim_port_pin_map
									if text_in(c) = latin_1.semicolon then
				 						-- : PIN_MAP_STRING := "OE_NEG1:1, Y1:(2,3,4,5)," & "Y2:(7,8,9,10), A1:(23,22,21,20)," & "A2:(19,17,16,15), OE_NEG2:24, GND:6," & "VCC:18, TDO:11, TDI:14, TMS:12, TCK:13";
										--put_line(text_in(pattern_start..c-1));
										trim_port_pin_map(text_in(pattern_start..c-1)); -- omitting the trailing semicolon
										exit;
									end if;
								end if;
 							end if;

 						when others => null; -- there are no other levels of interest
 					end case;
 
					-- Count up/down opening and closing parenthesis to detect the parsing level:
					case text_in(c) is
						when latin_1.left_parenthesis => -- open parenthesis found
							open_sections_ct := open_sections_ct + 1;
						when latin_1.right_parenthesis => -- close parenthesis found
							open_sections_ct := open_sections_ct - 1;
						when others => -- other characters don't matter for the parse level
							null;
					end case;
				end loop;
			end read_port_pin_map;
				
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
				
				-- boundary register 
				-- write something like "0 bc_1 * internal x" / "5 bc_1 pb01_16 input x" / "4 bc_1 pb01_16 output3 x 3 0 z"
				-- We start with cell id 0 by picking it out of container boundary_register_cell_container.
				new_line;				
				put_line(2 * row_separator_0 & section_mark.subsection & row_separator_0 & text_bsdl_boundary_register);
				put_line(2 * row_separator_0 & "-- num cell port function safe [control_cell disable_value disable_result]");
				for s in 0..length_boundary_register-1 loop -- start with LSB
					cell_cursor := first(boundary_register_cell_container); -- set cursor at begin of container
					-- Search container from first until last element until cell id match.
					while cell_cursor /= last(boundary_register_cell_container) loop
						bc_scratch := element(cell_cursor);
						if bc_scratch.cell_id = s then -- cell id match
							put_cell_properties(bc_scratch); -- write cell properies
						end if;
						cell_cursor := next(cell_cursor);
					end loop;

					-- test last element in container
					bc_scratch := element(cell_cursor);
					if bc_scratch.cell_id = s then
						put_cell_properties(bc_scratch); -- write cell properies
					end if;
				end loop;
				put_line(2 * row_separator_0 & section_mark.endsubsection);

				-- port io map
				new_line;
				put_line(2 * row_separator_0 & section_mark.subsection & row_separator_0 & text_udb_port_io_map);
				put_line(2 * row_separator_0 & "-- port(s) : direction [up/down vector]");
				read_port_io_map(bsdl_string);
				put_line(2 * row_separator_0 & section_mark.endsubsection);

				-- port pin map
				new_line;
				put_line(2 * row_separator_0 & section_mark.subsection & row_separator_0 & text_udb_port_pin_map &
						 " -- for package " & universal_string_type.to_string(bic.housing));
				put_line(2 * row_separator_0 & "-- port pin(s)");
				read_port_pin_map(text_in => bsdl_string, package_name => universal_string_type.to_string(bic.housing));
				put_line(2 * row_separator_0 & section_mark.endsubsection);
				--new_line;
				
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

			-- display options (if given)
			option_remove_prefix := false;
			if universal_string_type.length(bic.options) > 0 then
				if to_lower(get_field(universal_string_type.to_string(bic.options),1)) = text_udb_option then
					if get_field(universal_string_type.to_string(bic.options),2) = to_lower(type_bic_option'image(remove_pin_prefix)) then
						put_line(standard_output,2 * row_separator_0 & universal_string_type.to_string(bic.options));
						option_remove_prefix := true;
						option_prefix_to_remove := universal_string_type.to_bounded_string(get_field(universal_string_type.to_string(bic.options),3));
					end if;
				end if;
			end if;
			
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

	--prog_position	:= 20;

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

	-- create premilinary data base (contining scanpath_configuration)
	prog_position	:= 60;
	m1.extract_section( 
		universal_string_type.to_string(name_file_data_base),
		name_file_data_base_preliminary,
		section_mark.section,
		section_mark.endsection,
		section_scanpath_configuration
		);

	-- read premilinary data base
	prog_position	:= 65;
	udb_summary := read_uut_data_base(name_file_data_base_preliminary);

	-- open premilinary data base again and start writing bsld information
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
	put_line (file_data_base_preliminary,"-- date " & m1_internal.date_now); 
-- 	put_line (file_data_base_preliminary,"-- number of scanpaths" & type_scanport_id'image(udb_summary.scanpath_ct)); 
-- 	put_line (file_data_base_preliminary,"-- number of BICs" & natural'image(udb_summary.bic_ct));
	new_line (file_data_base_preliminary);
	
	prog_position	:= 90;
	read_bsld_models;

	prog_position	:= 100;
	put_line (file_data_base_preliminary,section_mark.endsection); 
	new_line (file_data_base_preliminary);

	prog_position	:= 110;
	close(file_data_base_preliminary);
	copy_file(name_file_data_base_preliminary, universal_string_type.to_string(name_file_data_base));

	exception
		when event: others =>
			set_output(standard_output);
			set_exit_status(failure);
			case prog_position is
-- 				when 10 =>
-- 					put_line("ERROR: Data base file missing or insufficient access rights !");
-- 					put_line("       Provide data base name as argument. Example: mkinfra my_uut.udb");
-- 				when 20 =>
-- 					put_line("ERROR: Test name missing !");
-- 					put_line("       Provide test name as argument ! Example: mkinfra my_uut.udb my_infrastructure_test");
-- 				when 30 =>
-- 					put_line("ERROR: Invalid argument for debug level. Debug level must be provided as natural number !");

				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & natural'image(prog_position));
			end case;
	
end impbsdl;
