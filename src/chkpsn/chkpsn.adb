------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE CHKPSN                              --
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

with ada.text_io;				use ada.text_io;
with ada.characters;			use ada.characters;
with ada.characters.handling; 	use ada.characters.handling;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings; 				use ada.strings;

with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.containers.indefinite_vectors;

with ada.exceptions; 			use ada.exceptions;
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;


with m1_base;					use m1_base;
with m1_database;				use m1_database;
with m1_numbers;				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;
with m1_string_processing;		use m1_string_processing;

procedure chkpsn is

	use type_universal_string;
	use type_name_database;
	use type_name_file_options;
	use type_net_name;
	use type_device_name;
	use type_device_value;
	use type_package_name;
	use type_pin_name;
	use type_port_name;

	use type_list_of_pins;  
	use type_list_of_nets;
	use type_list_of_secondary_net_names;

	use type_list_of_static_control_cells_class_EX_NA;
	use type_list_of_static_control_cells_class_DX_NR;
	use type_list_of_static_control_cells_class_PX;
	use type_list_of_static_output_cells_class_PX;
	use type_list_of_static_output_cells_class_DX_NR;
	use type_list_of_static_expect_cells;
	use type_list_of_atg_expect_cells;
	use type_list_of_atg_drive_cells;
	use type_list_of_input_cells_class_NA;

	
	version			: constant string (1..3) := "001";

	prog_position	: natural := 0;
	
	name_file_database_backup			: type_name_database.bounded_string; 
	-- used when overwriting the old database with the preliminary database

	total_options_net_count				: natural := 0; 
	-- CS: currently assigned but not read. useful for addtional statistics

	type type_net_count_statistics is record
		pu				: natural := 0;
		pd				: natural := 0;
		dh				: natural := 0;
		dl				: natural := 0;
		eh				: natural := 0;
		el				: natural := 0;
		nr				: natural := 0;
		na				: natural := 0;
		total			: natural := 0;
		bs_static		: natural := 0;
		bs_static_l		: natural := 0;
		bs_static_h		: natural := 0;
		bs_dynamic		: natural := 0;
		bs_testable		: natural := 0;
		atg_drivers		: natural := 0;
		atg_receivers	: natural := 0;
	end record;
	net_count_statistics : type_net_count_statistics;
	
	type type_options_net (has_secondaries : boolean := true) is record
		name						: type_net_name.bounded_string;
		class						: type_net_class;
		line_number					: positive;
		case has_secondaries is
			when true =>
				list_of_secondary_net_names	: type_list_of_secondary_net_names.vector;
			when false =>
				null;
		end case;
	end record;
	package type_list_of_options_nets is new indefinite_vectors (index_type => positive, element_type => type_options_net);
	use type_list_of_options_nets;
	list_of_options_nets : type_list_of_options_nets.vector; -- all nets of options file go into this list

	function control_cell_in_enable_state_by_any_cell_list(
	-- searches cell lists for given control cell and returns false if cell is not in enable state
	-- aborts if cell in enable state or targeted by atg
		class		: in type_net_class;
		net			: in type_net_name.bounded_string;
		device		: in type_device_name.bounded_string;
		cell_id		: in type_cell_id) 
		return boolean is

		procedure print_error_on_shared_control_cell_conflict is
		begin
			put_line(standard_output,message_error & "Shared control cell conflict in class " & type_net_class'image(class) 
				& " net '" & to_string(net) & "' !");
		end print_error_on_shared_control_cell_conflict;

	begin -- control_cell_in_enable_state_by_any_cell_list
		if length(list_of_static_control_cells_class_DX_NR) > 0 then
			for i in 1..length(list_of_static_control_cells_class_DX_NR) loop
				if element(list_of_static_control_cells_class_DX_NR, positive(i)).device = device then -- on device name match
					if element(list_of_static_control_cells_class_DX_NR, positive(i)).id = cell_id then -- on cell id match
						if element(list_of_static_control_cells_class_DX_NR, positive(i)).locked_to_enable_state = true then -- if locked to enable state
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & to_string(device) 
								& "' control cell" & type_cell_id'image(cell_id)
								& " already locked to enable state " 
								& type_bit_char_class_0'image(
									element(list_of_static_control_cells_class_DX_NR, positive(i)).enable_value));
							put_line(standard_output,"       by class " 
								& type_net_class'image(
									element(list_of_static_control_cells_class_DX_NR, positive(i)).class) 
								& row_separator_0 
								& to_lower(type_net_level'image(
									element(list_of_static_control_cells_class_DX_NR, positive(i)).level)) 
								& " net '" & to_string(element(list_of_static_control_cells_class_DX_NR, positive(i)).net) & "' !");
							raise constraint_error;
						end if; -- if locked to enable state
					end if; -- in cell id match
				end if; -- on device name match
			end loop;
		end if;

		if length(list_of_atg_drive_cells) > 0 then
			for i in 1..length(list_of_atg_drive_cells) loop
				if element(list_of_atg_drive_cells, positive(i)).device = device then -- on device name match
					if element(list_of_atg_drive_cells, positive(i)).id = cell_id then -- on cell id match
						if element(list_of_atg_drive_cells, positive(i)).controlled_by_control_cell then -- if control cell is targeted by atg
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & to_string(device) 
								& "' control cell" & type_cell_id'image(cell_id)
								& " already reserved for ATG");
							put_line(standard_output,"       by class " & type_net_class'image(
									element(list_of_atg_drive_cells, positive(i)).class) 
								& row_separator_0 
								& " primary net '" & to_string(
									element(list_of_atg_drive_cells, positive(i)).net) & "' !");
							raise constraint_error;
						end if; -- if targeted by atg
					end if;
				end if;
			end loop;
		end if;

		-- given control cell is not in enable state
		return false;
	end control_cell_in_enable_state_by_any_cell_list;

	procedure verify_primary_net_appears_only_once (name : in type_net_name.bounded_string) is
	-- Checks if given primary net has been added to list_of_options_nets already.
		s : type_list_of_secondary_net_names.vector;
	begin
		for i in 1..length(list_of_options_nets) loop
		
-- 			if debug_level >= 50 then
-- 				put_line("searching primary net : " & universal_string_type.to_string(n.name) & " ...");
-- 			end if;

			-- if primary net already specified as primary net:
			if element(list_of_options_nets, positive(i)).name = name then
				put_line(message_error & "Net '" & to_string(name) & "' already specified as primary net !");
				raise constraint_error;
			end if;

			-- if primary net already specified as secondary net:
			if element(list_of_options_nets, positive(i)).has_secondaries then
				s := element(list_of_options_nets, positive(i)).list_of_secondary_net_names; -- load secondary net names in s
				for i in 1..length(s) loop -- search secondary nets
					if element(s, positive(i)) = name then
						put_line(message_error & "Net '" & to_string(name) 
							& "' already specified as secondary net of primary net '" 
							& to_string(
								element(list_of_options_nets, positive(i)).name) & "' !");
						raise constraint_error;
					end if;
				end loop;
			end if;
		end loop;
	end verify_primary_net_appears_only_once;

	procedure verify_secondary_net_appears_only_once (name : in type_net_name.bounded_string) is
	-- checks if secondary net appears only once in options file
		n	: type_options_net;
		l	: count_type := length(list_of_options_nets);
	begin
		if l > 0 then -- do the check if list_of_options_nets contains something already
			for i in 1..l loop
				n := element(list_of_options_nets, positive(i)); -- load a primary net
				
-- 				if debug_level >= 30 then
-- 					put_line("searching secondary net in primary net : " & universal_string_type.to_string(n.name) & " ...");
-- 				end if;

				-- if secondary net already specified as primary net:
				if n.name = name then
					put_line(message_error & "Net '" & to_string(name) & "' already specified as primary net !");
					raise constraint_error;
				end if;

				-- if secondary net already specified as secondary net:
				if n.has_secondaries then
					for i in 1..length(n.list_of_secondary_net_names) loop -- search in secondary nets
						if element(n.list_of_secondary_net_names, positive(i)) = name then
							put_line(message_error & "Net '" & to_string(name) & "' already specified as secondary net of primary net '" 
								& to_string(n.name) & "' !");
							raise constraint_error;
						end if;
					end loop;
				end if;
			end loop;
		end if;
	end verify_secondary_net_appears_only_once;
	
	procedure add_to_options_net_list(
		-- this procedure adds a primary net (incl. secondary nets) to the options net list
		-- multiple occurencs of nets in options file will be checked
		name				: in type_net_name.bounded_string;
		class				: in type_net_class;
		line_number			: in positive;
		secondary_net_names	: in type_list_of_secondary_net_names.vector
		) is

		secondary_net_count : natural := natural(length(secondary_net_names));
		
		sn1, sn2 : type_net_name.bounded_string; -- for temporarily storage of secondary net names

	begin -- add_to_options_net_list
		
		verify_primary_net_appears_only_once(name); -- checks other primary nets and their secondary nets in options file

-- 		if debug_level >= 20 then
-- 			put_line("adding to options net list : " & name_given);
-- 		end if;

		case secondary_net_count is
			when 0 => 
				append(list_of_options_nets,( 
					has_secondaries => false, 
					name => name,
					class => class,
					line_number => line_number));

			when others =>
				-- if secondary nets present, the object to create does have a list of secondary nets which needs checking:
				for s in 1..secondary_net_count loop
					sn1 := element(secondary_net_names, positive(s));
-- 					if debug_level >= 30 then
-- 						put_line("checking secondary net : " & universal_string_type.to_string(list_of_secondary_net_names_given(s)) 
-- 							& "' for multiple occurences ...");
-- 					end if;

					-- Make sure the list of secondary nets does contain unique net names 
					-- (means no multiple occurences of of the same net).
					for i in s+1..secondary_net_count loop -- search starts with the net after sn1
						sn2 := element(secondary_net_names, positive(i));
						if sn2 = sn1 then
							put_line(message_error & "Net '" & to_string(sn1) 
							& "' must be specified only once as secondary net of this primary net !");
							raise constraint_error;
						end if;
					end loop;

					-- check if secondary net occurs in other primary and secondary nets
					verify_secondary_net_appears_only_once(sn1);
				end loop;

-- 				list := new type_options_net'(
-- 					next => list,
-- 					name					=> universal_string_type.to_bounded_string(name_given),
-- 					class					=> class_given,
-- 					line_number				=> line_number_given,
-- 					has_secondaries			=> true,
-- 					secondary_net_count		=> secondary_net_ct_given,
-- 					list_of_secondary_net_names	=> list_of_secondary_net_names_given
-- 					);
				
				append(list_of_options_nets, ( 
					has_secondaries => true, 
					name => name,
					class => class,
					line_number => line_number,
					list_of_secondary_net_names => secondary_net_names));

		end case;

		-- update net counter of options file by: one primary net + number of attached secondaries
		total_options_net_count := total_options_net_count + 1 + secondary_net_count;

	end add_to_options_net_list;



--	procedure disable_remaining_drivers ( d : in type_net) is
	procedure disable_remaining_drivers ( net_name : in type_net_name.bounded_string; net : in type_net) is
-- 		p : type_pin;
	begin
		write_message (
			file_handle => file_chkpsn_messages,
			identation => 4,
			text => "disabling remaining drivers ...",
			console => false);

		-- FIND CONTROL CELLS TO BE DISABLED:
		-- 			for p in 1..net.part_ct loop -- loop through pin list of given net
		for i in 1..length(net.pins) loop
			--p := element(net.pins, positive(i));
			-- NOTE: element(net.pins, positive(i)) equals the particular pin
			if element(net.pins, positive(i)).is_bscan_capable then -- care for scan capable pins only
				-- pin must have a control cell and an output cell
				if element(net.pins, positive(i)).cell_info.control_cell_id /= -1 and element(net.pins, positive(i)).cell_info.output_cell_id /= -1 then 
					if not element(net.pins, positive(i)).cell_info.selected_as_driver then -- care for drivers not marked as active

						-- if non-shared control cell, just turn it off:
						--  write disable value in cell list
						--  write drive value 0 of useless output cell in cell list
						if not element(net.pins, positive(i)).cell_info.control_cell_shared then
							case net.class is
								when DH | DL | NR =>
									-- add control cell to list
									write_message (
										file_handle => file_chkpsn_messages,
										identation => 5,
										text => "static non-shared control cell: device " & to_string(element(net.pins, positive(i)).device_name) 
											& " pin " & to_string(element(net.pins, positive(i)).device_pin_name) & row_separator_0 
											& " cell " & type_cell_id'image(element(net.pins, positive(i)).cell_info.control_cell_id),
										console => false);
									
-- 										add_to_locked_control_cells_in_class_DH_DL_NR_nets(
-- 											-- prepares writing a cell list entry like:
-- 											-- class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0
-- 											list				=> ptr_cell_list_static_control_cells_class_DX_NR,
-- 											class_given			=> class,
-- 											level_given			=> level,
-- 											net_given			=> universal_string_type.to_bounded_string(name),
-- 											device_given		=> net.pin(p).device_name,
-- 											pin_given			=> net.pin(p).device_pin_name,
-- 											cell_given			=> net.pin(p).cell_info.control_cell_id,
-- 											locked_to_enable_state_given	=> false, -- the pin is to be disabled
-- 											disable_value_given				=> net.pin(p).cell_info.disable_value
-- 											);

									append(list_of_static_control_cells_class_DX_NR,(
										locked_to_enable_state	=> false, 
										level					=> net.level,
										class					=> net.class,
										--net						=> net.name,
										net						=> net_name,
										device					=> element(net.pins, positive(i)).device_name,
										pin						=> element(net.pins, positive(i)).device_pin_name,
										id						=> element(net.pins, positive(i)).cell_info.control_cell_id,
										disable_value			=> element(net.pins, positive(i)).cell_info.disable_value));

									-- add (unused) output cell to list
-- 										add_to_locked_output_cells_in_class_DH_DL_nets(
-- 											list				=> ptr_cell_list_static_output_cells_class_DX_NR,
-- 											class_given			=> class,
-- 											net_given			=> universal_string_type.to_bounded_string(name),
-- 											device_given		=> net.pin(p).device_name,
-- 											pin_given			=> net.pin(p).device_pin_name,
-- 											cell_given			=> net.pin(p).cell_info.output_cell_id,
-- 											drive_value_given	=> '0' --drive_value_derived_from_class(class) 
-- 												-- the drive value is meaningless since the pin is disabled
-- 											);

									write_message (
										file_handle => file_chkpsn_messages,
										identation => 5,
										text => "static output cell: device " & to_string(element(net.pins, positive(i)).device_name) 
											& " pin " & to_string(element(net.pins, positive(i)).device_pin_name) & row_separator_0 
											& " cell " & type_cell_id'image(element(net.pins, positive(i)).cell_info.output_cell_id),
										console => false);
									
									append(list_of_static_output_cells_class_DX_NR,(
										class					=> net.class,
										--net						=> net.name,
										net						=> net_name,
										device					=> element(net.pins, positive(i)).device_name,
										pin						=> element(net.pins, positive(i)).device_pin_name,
										id						=> element(net.pins, positive(i)).cell_info.output_cell_id,
										drive_value				=> '0')); -- meaningless since the pin is disabled -- CS: default constant drive_value_default ?

								when PU | PD =>
									-- add control cell to list
									write_message (
										file_handle => file_chkpsn_messages,
										identation => 5,
										text => "static non-shared control cell: device " & to_string(element(net.pins, positive(i)).device_name) 
											& " pin " & to_string(element(net.pins, positive(i)).device_pin_name) & row_separator_0 
											& " cell " & type_cell_id'image(element(net.pins, positive(i)).cell_info.control_cell_id),
										console => false);

-- 									add_to_locked_control_cells_in_class_PU_PD_nets(
										-- prepares writing a cell list entry like:
										-- class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
										-- class PD secondary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
-- 											list				=> ptr_cell_list_static_control_cells_class_PX,
-- 											class_given			=> class,
-- 											level_given			=> level,
-- 											net_given			=> universal_string_type.to_bounded_string(name),
-- 											device_given		=> net.pin(p).device_name,
-- 											pin_given			=> net.pin(p).device_pin_name,
-- 											cell_given			=> net.pin(p).cell_info.control_cell_id,
-- 											disable_value_given				=> net.pin(p).cell_info.disable_value
-- 											);

									append(list_of_static_control_cells_class_PX,(
										level					=> net.level,																					 
										class					=> net.class,
										--	net						=> net.name,
										net						=> net_name,										
										device					=> element(net.pins, positive(i)).device_name,
										pin						=> element(net.pins, positive(i)).device_pin_name,
										id						=> element(net.pins, positive(i)).cell_info.control_cell_id,
										disable_value			=> element(net.pins, positive(i)).cell_info.disable_value));
									
								when others => null;
							end case;
						else
						-- we have a shared control cell:

							-- check if control cell can be set to disable state
							if not control_cell_in_enable_state_by_any_cell_list( 
-- 								net		=> net.name,
								net		=> net_name,	
								class	=> net.class,
								device	=> element(net.pins, positive(i)).device_name,
								cell_id	=> element(net.pins, positive(i)).cell_info.control_cell_id) then

								case net.class is
									when DH | DL | NR =>
										-- add control cell to list
										write_message (
											file_handle => file_chkpsn_messages,
											identation => 5,
											text => "static shared control cell: device " & to_string(element(net.pins, positive(i)).device_name) 
												& " pin " & to_string(element(net.pins, positive(i)).device_pin_name) & row_separator_0 
												& " cell " & type_cell_id'image(element(net.pins, positive(i)).cell_info.control_cell_id),
											console => false);
										
-- 											add_to_locked_control_cells_in_class_DH_DL_NR_nets(
-- 												-- prepares writing a cell list entry like:
-- 												-- class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0
-- 												list				=> ptr_cell_list_static_control_cells_class_DX_NR,
-- 												class_given			=> class,
-- 												level_given			=> level,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> net.pin(p).device_name,
-- 												pin_given			=> net.pin(p).device_pin_name,
-- 												cell_given			=> net.pin(p).cell_info.control_cell_id,
-- 												locked_to_enable_state_given	=> false, -- the pin is to be disabled
-- 												disable_value_given				=> net.pin(p).cell_info.disable_value
-- 												);

										append(list_of_static_control_cells_class_DX_NR,(
											locked_to_enable_state	=> false, 
											level					=> net.level,																					 
											class					=> net.class,
											--net						=> net.name,
											net						=> net_name,
											device					=> element(net.pins, positive(i)).device_name,
											pin						=> element(net.pins, positive(i)).device_pin_name,
											id						=> element(net.pins, positive(i)).cell_info.control_cell_id,
											disable_value			=> element(net.pins, positive(i)).cell_info.disable_value));
									
										-- add (unused) output cell to list
										write_message (
											file_handle => file_chkpsn_messages,
											identation => 5,
											text => "static output cell: device " & to_string(element(net.pins, positive(i)).device_name) 
												& " pin " & to_string(element(net.pins, positive(i)).device_pin_name) & row_separator_0 
												& " cell " & type_cell_id'image(element(net.pins, positive(i)).cell_info.output_cell_id),
											console => false);
										
-- 											add_to_locked_output_cells_in_class_DH_DL_nets(
-- 												list				=> ptr_cell_list_static_output_cells_class_DX_NR,
-- 												class_given			=> class,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> net.pin(p).device_name,
-- 												pin_given			=> net.pin(p).device_pin_name,
-- 												cell_given			=> net.pin(p).cell_info.output_cell_id,
-- 												drive_value_given	=> '0' --drive_value_derived_from_class(class) 
-- 													-- the drive value is meaningless since the pin is disabled
-- 												);

										append(list_of_static_output_cells_class_DX_NR,(
											class					=> net.class,
-- 											net						=> net.name,
											net						=> net_name,
											device					=> element(net.pins, positive(i)).device_name,
											pin						=> element(net.pins, positive(i)).device_pin_name,
											id						=> element(net.pins, positive(i)).cell_info.output_cell_id,
											drive_value				=> '0')); -- meaningless since the pin is disabled -- CS: default constant


									when PU | PD =>
										-- add control cell to list
										write_message (
											file_handle => file_chkpsn_messages,
											identation => 5,
											text => "static shared control cell: device " & to_string(element(net.pins, positive(i)).device_name) 
												& " pin " & to_string(element(net.pins, positive(i)).device_pin_name) & row_separator_0 
												& " cell " & type_cell_id'image(element(net.pins, positive(i)).cell_info.control_cell_id),
											console => false);

-- 											add_to_locked_control_cells_in_class_PU_PD_nets(
-- 												-- prepares writing a cell list entry like:
-- 												-- class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
-- 												-- class PD secondary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
-- 												list				=> ptr_cell_list_static_control_cells_class_PX,
-- 												class_given			=> class,
-- 												level_given			=> level,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> net.pin(p).device_name,
-- 												pin_given			=> net.pin(p).device_pin_name,
-- 												cell_given			=> net.pin(p).cell_info.control_cell_id,
-- 												disable_value_given	=> net.pin(p).cell_info.disable_value
-- 												);

										append(list_of_static_control_cells_class_PX,(
											level					=> net.level,																					 
											class					=> net.class,
-- 											net						=> net.name,
											net						=> net_name,
											device					=> element(net.pins, positive(i)).device_name,
											pin						=> element(net.pins, positive(i)).device_pin_name,
											id						=> element(net.pins, positive(i)).cell_info.control_cell_id,
											disable_value			=> element(net.pins, positive(i)).cell_info.disable_value));

										
									when others => null;
								end case;
							end if; -- check if control cell can be set to disable state

						end if; -- if non-shared control cell, just turn it off
					end if;  -- care for drivers not marked as active
				end if; -- pin must have a control cell and an output cell
			end if;
		end loop;
	end disable_remaining_drivers;


	function control_cell_in_disable_state_by_any_cell_list(
	-- Searches cell lists for given control cell and returns false if cell is not in disable state.
	-- Aborts if cell in disable state or targeted by atg.
		class		: in type_net_class;
		net			: in type_net_name.bounded_string;
		device		: in type_device_name.bounded_string;
		cell_id		: in type_cell_id) 
		return boolean is

		a : type_static_control_cell_class_EX_NA;
		c : type_static_control_cell_class_PX;

		procedure print_error_on_shared_control_cell_conflict is
		begin
			put_line(standard_output,message_error & "Shared control cell conflict in class " & type_net_class'image(class) 
				& " net '" & to_string(net) & "' !");
		end print_error_on_shared_control_cell_conflict;

	begin -- control_cell_in_disable_state_by_any_cell_list
		if length(list_of_static_control_cells_class_EX_NA) > 0 then
			for i in 1..length(list_of_static_control_cells_class_EX_NA) loop
				a := element(list_of_static_control_cells_class_EX_NA, positive(i));
				if a.device = device then -- on device name match
					if a.id = cell_id then -- on cell id match
						print_error_on_shared_control_cell_conflict;
						put_line(standard_output,"       Device '" & to_string(a.device) 
							& "' control cell" & type_cell_id'image(a.id)
							& " already locked to disable state " & type_bit_char_class_0'image(a.disable_value));
						put_line(standard_output,"       by class " & type_net_class'image(a.class) & row_separator_0 
							& to_lower(type_net_level'image(a.level)) 
							& " net '" & to_string(a.net) & "' !");
						raise constraint_error;
					end if;
				end if;
			end loop;
		end if;

		if length(list_of_static_control_cells_class_DX_NR) > 0 then
			for i in 1..length(list_of_static_control_cells_class_DX_NR) loop
				if element(list_of_static_control_cells_class_DX_NR, positive(i)).device = device then -- on device name match
					if element(list_of_static_control_cells_class_DX_NR, positive(i)).id = cell_id then -- on cell id match
						if element(list_of_static_control_cells_class_DX_NR, positive(i)).locked_to_enable_state = false then -- if locked to disable state
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & to_string(device) 
								& "' control cell" & type_cell_id'image(cell_id)
								& " already locked to disable state " & type_bit_char_class_0'image(
									element(list_of_static_control_cells_class_DX_NR, positive(i)).disable_value));
							put_line(standard_output,"       by class " & type_net_class'image(
									element(list_of_static_control_cells_class_DX_NR, positive(i)).class) 
								& row_separator_0 
								& to_lower(type_net_level'image(element(list_of_static_control_cells_class_DX_NR, positive(i)).level)) 
								& " net '" & to_string(element(list_of_static_control_cells_class_DX_NR, positive(i)).net) & "' !");
							raise constraint_error;
						end if; -- if locked to disable state
					end if;
				end if;
			end loop;
		end if;

		-- CS: not tested yet:
		if length(list_of_static_control_cells_class_PX) > 0 then
			for i in 1..length(list_of_static_control_cells_class_PX) loop
				c := element(list_of_static_control_cells_class_PX, positive(i));
				if c.device = device then -- on device name match
					if c.id = cell_id then -- on cell id match
						--if c.locked_to_enable_state = false then -- if locked to disable state
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & to_string(c.device) 
								& "' control cell" & type_cell_id'image(c.id)
								& " already locked to disable state " & type_bit_char_class_0'image(c.disable_value));
							put_line(standard_output,"       by class " & type_net_class'image(c.class) & row_separator_0 
								& to_lower(type_net_level'image(c.level)) 
								& " net '" & to_string(c.net) & "' !");
							raise constraint_error;
						--end if; -- if locked to disable state
					end if;
				end if;
			end loop;
		end if;

		-- CS: not tested yet:
		if length(list_of_atg_drive_cells) > 0 then
			for i in 1..length(list_of_atg_drive_cells) loop
				if element(list_of_atg_drive_cells, positive(i)).device = device then -- on device name match
					if element(list_of_atg_drive_cells, positive(i)).id = cell_id then -- on cell id match
						if element(list_of_atg_drive_cells, positive(i)).controlled_by_control_cell then -- if control cell is targeted by atg
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & to_string(device) 
								& "' control cell" & type_cell_id'image(cell_id)
								& " already reserved for ATG");
							put_line(standard_output,"       by class " & type_net_class'image(
									element(list_of_atg_drive_cells, positive(i)).class) 
								& row_separator_0 
								& " primary net '" & to_string(
									element(list_of_atg_drive_cells, positive(i)).net) & "' !");
							raise constraint_error;
						end if; -- if targeted by atg
					end if;
				end if;
			end loop;
		end if;

		-- given control cell is not in disable state
		return false;
	end control_cell_in_disable_state_by_any_cell_list;


	procedure update_cell_lists(name : in type_net_name.bounded_string; net : in type_net ) is
	-- updates cell lists by the net given (from database netlist)
		drivers_without_disable_spec_ct 			: natural := 0;
		driver_with_non_shared_control_cell_found 	: boolean := false;
		driver_with_shared_control_cell_found		: boolean := false;

		d : type_net := net;

-- CS:		procedure write_message_is_shared is
-- 		begin
-- 
		-- 		end write_message_is_shared;

		procedure set_selected_as_driver (pin : in out type_pin) is
		begin
			pin.cell_info.selected_as_driver := true;
		end set_selected_as_driver;

	begin -- update_cell_lists
		-- d holds the net being processed

		write_message (
			file_handle => file_chkpsn_messages,
			identation => 3,
			--text => "updating cell lists by class " & type_net_class'image(d.class) & " net " & to_string(d.name),
			text => "updating cell lists by class " & type_net_class'image(d.class) & " net " & to_string(name), 
			console => false);

		-- FIND INPUT CELLS AND CONTROL CELLS TO BE DISABLED:
		-- 		for p in 1..d.part_ct loop -- loop through pin list of given net
		for i in 1..length(d.pins) loop
			-- p := element(d.pins, positive(i));
			-- NOTE: element(d.pins, positive(i)) equals the particular pin

			-- CS: add a variable that holds the pin count of the net

			if element(d.pins, positive(i)).is_bscan_capable then -- care for scan capable pins only

				-- THIS IS ABOUT INPUT CELLS:
				-- add all input cells of static and dynamic (atg) nets to cell list "static_expect" and "atg_expect"
				-- since all input cells are listening, the net level (primary/secondary) does not matter
				-- here and will not be evaluated
				if element(d.pins, positive(i)).cell_info.input_cell_id /= -1 then -- if pin does have an input cell
					case d.class is
						when EH | EL | DH | DL =>

							write_message (
								file_handle => file_chkpsn_messages,
								identation => 4,
								text => "static input cell: device " & to_string(element(d.pins, positive(i)).device_name) 
									& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
									& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.input_cell_id),
								console => false);

							case d.level is
								when primary =>
									append(list_of_static_expect_cells,(
										level			=> primary,
										class			=> d.class,
										--net				=> d.name,
										net				=> name,
										device			=> element(d.pins, positive(i)).device_name,
										pin				=> element(d.pins, positive(i)).device_pin_name,
										id				=> element(d.pins, positive(i)).cell_info.input_cell_id,
										expect_value	=> expect_value_derived_from_class(d.class)));
									
							   when secondary =>
									append(list_of_static_expect_cells,(
										level			=> secondary,
										primary_net_is	=> d.name_of_primary_net,
										class			=> d.class,
										--net				=> d.name,
										net				=> name,
										device			=> element(d.pins, positive(i)).device_name,
										pin				=> element(d.pins, positive(i)).device_pin_name,
										id				=> element(d.pins, positive(i)).cell_info.input_cell_id,
										expect_value	=> expect_value_derived_from_class(d.class)));
							end case;
							
						when NR | PU | PD =>

-- 							add_to_atg_expect(
-- 								list			=> ptr_cell_list_atg_expect,
-- 								class_given		=> class,
-- 								level_given		=> level, 
-- 								-- if secondary net, the argument "primary_net_is" will be evaluated, otherwise ignored
-- 								primary_net_is_given	=> primary_net_is,
-- 								net_given		=> universal_string_type.to_bounded_string(name),
-- 								device_given	=> d.pin(p).device_name,
-- 								pin_given		=> d.pin(p).device_pin_name,
-- 								cell_given		=> d.pin(p).cell_info.input_cell_id
-- 								);

							write_message (
								file_handle => file_chkpsn_messages,
								identation => 4,
								text => "atg input cell: device " & to_string(element(d.pins, positive(i)).device_name) 
									& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
									& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.input_cell_id),
								console => false);

							case d.level is
								when primary =>
									append(list_of_atg_expect_cells,(
										level			=> primary,
										class			=> d.class,
										--net				=> d.name,
										net				=> name,
										device			=> element(d.pins, positive(i)).device_name,
										pin				=> element(d.pins, positive(i)).device_pin_name,
										id				=> element(d.pins, positive(i)).cell_info.input_cell_id));
									
							   when secondary =>
									append(list_of_atg_expect_cells,(
										level			=> secondary,
										primary_net_is	=> d.name_of_primary_net,
										class			=> d.class,
										--net				=> d.name,
										net				=> name,
										device			=> element(d.pins, positive(i)).device_name,
										pin				=> element(d.pins, positive(i)).device_pin_name,
										id				=> element(d.pins, positive(i)).cell_info.input_cell_id));
							end case;

						when NA =>
-- 							add_to_input_cells_in_class_NA_nets(
-- 								list			=> ptr_cell_list_input_cells_class_NA,
-- 								level_given		=> level, 
-- 								-- if secondary net, the argument "primary_net_is" will be evaluated, otherwise ignored
-- 								primary_net_is_given	=> primary_net_is,
-- 								net_given		=> universal_string_type.to_bounded_string(name),
-- 								device_given	=> d.pin(p).device_name,
-- 								pin_given		=> d.pin(p).device_pin_name,
-- 								cell_given		=> d.pin(p).cell_info.input_cell_id
-- 								);

							write_message (
								file_handle => file_chkpsn_messages,
								identation => 4,
								text => "input cell: device " & to_string(element(d.pins, positive(i)).device_name) 
									& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
									& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.input_cell_id),
								console => false);
														
							case d.level is
								when primary =>
									append(list_of_input_cells_class_NA,(
										level			=> primary,
										class			=> d.class,
										--net				=> d.name,
										net				=> name,
										device			=> element(d.pins, positive(i)).device_name,
										pin				=> element(d.pins, positive(i)).device_pin_name,
										id				=> element(d.pins, positive(i)).cell_info.input_cell_id));
									
							   when secondary =>
									append(list_of_input_cells_class_NA,(
										level			=> secondary,
										primary_net_is	=> d.name_of_primary_net,
										class			=> d.class,
										--net				=> d.name,
										net				=> name,
										device			=> element(d.pins, positive(i)).device_name,
										pin				=> element(d.pins, positive(i)).device_pin_name,
										id				=> element(d.pins, positive(i)).cell_info.input_cell_id));
							end case;

					end case; -- class
				end if;

				-- THIS IS ABOUT CONTROL CELLS IN PRIMARY AND SECONDARY NETS OF CLASS EH, EL, NA:
				-- in nets of class EH, EL or NA, all control cells must be in disable state, regardless of net level
				if element(d.pins, positive(i)).cell_info.control_cell_id /= -1 then -- if pin has disable spec. (means: a control cell)
					case d.class is
						when EL | EH | NA =>

							write_message (
								file_handle => file_chkpsn_messages,
								identation => 4,
								text => "control cell: device " & to_string(element(d.pins, positive(i)).device_name) 
									& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
									& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.control_cell_id),
								lf => false,
								console => false);

							if element(d.pins, positive(i)).cell_info.control_cell_shared then
								-- if driver has a shared control cell
								-- the driver pin can be disabled if its control cell is not already enabled 
								-- or targeted by atg

								write_message (
									file_handle => file_chkpsn_messages,
									text => " is shared",
									lf => false,									
									console => false);
								
								-- check if control cell can be set to disable state
								if not control_cell_in_enable_state_by_any_cell_list( 
									--net		=> d.name,
									net		=> name,
									class	=> d.class,
									device	=> element(d.pins, positive(i)).device_name,
									cell_id	=> element(d.pins, positive(i)).cell_info.control_cell_id) then

									write_message (
										file_handle => file_chkpsn_messages,
										text => " but can be set to disable state.",
										console => false);
									
										-- all control cells of those nets must be in disable state (don't care about net level)
-- 										add_to_locked_control_cells_in_class_EH_EL_NA_nets(
-- 											list				=> ptr_cell_list_static_control_cells_class_EX_NA,
-- 											class_given			=> class,
-- 											level_given			=> level,
-- 											net_given			=> universal_string_type.to_bounded_string(name),
-- 											device_given		=> d.pin(p).device_name,
-- 											pin_given			=> d.pin(p).device_pin_name,
-- 											cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 											disable_value_given	=> d.pin(p).cell_info.disable_value
-- 											);

									append(list_of_static_control_cells_class_EX_NA, (
										level			=> d.level,																					 
										class			=> d.class,
										--net				=> d.name,
										net				=> name,
										device			=> element(d.pins, positive(i)).device_name,
										pin				=> element(d.pins, positive(i)).device_pin_name,
										id				=> element(d.pins, positive(i)).cell_info.control_cell_id,
										disable_value	=> element(d.pins, positive(i)).cell_info.disable_value));
								end if;

							else -- driver has a non-shared control cell
								-- so there is no need to check cell lists 
								-- all control cells of those nets must be in disable state

-- 								add_to_locked_control_cells_in_class_EH_EL_NA_nets(
-- 									list				=> ptr_cell_list_static_control_cells_class_EX_NA,
-- 									class_given			=> class,
-- 									level_given			=> level,
-- 									net_given			=> universal_string_type.to_bounded_string(name),
-- 									device_given		=> d.pin(p).device_name,
-- 									pin_given			=> d.pin(p).device_pin_name,
-- 									cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 									disable_value_given	=> d.pin(p).cell_info.disable_value
-- 									);

								write_message (
									file_handle => file_chkpsn_messages,
									text => " is not shared",
									lf => false,									
									console => false);
								
								append(list_of_static_control_cells_class_EX_NA, (
									level			=> d.level,																					 
									class			=> d.class,
									--net				=> d.name,
									net				=> name,
									device			=> element(d.pins, positive(i)).device_name,
									pin				=> element(d.pins, positive(i)).device_pin_name,
									id				=> element(d.pins, positive(i)).cell_info.control_cell_id,
									disable_value	=> element(d.pins, positive(i)).cell_info.disable_value));

							end if; -- if driver has a shared control cell

							write_message (
								file_handle => file_chkpsn_messages,
								text => "",
								lf => true,
								console => false);
							
						when others => 
							null;
-- 							prog_position := "UC2230";
					end case;
				end if;


				-- THIS IS ABOUT CONTROL CELLS IN SECONDARY NETS IN CLASS DH , DL , NR , PU AND PD:
				case d.level is
					when secondary =>
						-- all control cells in secondary nets must be in disable state
						if element(d.pins, positive(i)).cell_info.control_cell_id /= -1 then -- if pin has a control cell
							case d.class is
								when EL | EH | NA =>
-- 									prog_position := "UC2310"; -- no need to disable control cells again, as this has been done earlier (see above)
									null;
									--add_to_locked_control_cells_in_class_EH_EL_NA_nets(
									--	list				=> cell_list_locked_control_cells_in_class_EH_EL_NA_nets_ptr,
									--	class_given			=> class,
									--	level_given			=> level,
									--	net_given			=> universal_string_type.to_bounded_string(name),
									--	device_given		=> d.pin(p).device_name,
									--	pin_given			=> d.pin(p).device_pin_name,
									--	cell_given			=> d.pin(p).cell_info.control_cell_id,
									--	disable_value_given	=> d.pin(p).cell_info.disable_value
									--	);
								when DH | DL | NR =>

									write_message (
										file_handle => file_chkpsn_messages,
										identation => 4,
										text => "control cell: device " & to_string(element(d.pins, positive(i)).device_name) 
											& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
											& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.control_cell_id),
										lf => false,
										console => false);

-- 									prog_position := "UC2320";
									if element(d.pins, positive(i)).cell_info.control_cell_shared then
										-- if driver has a shared control cell
										-- the driver pin can be disabled if its control cell is not already enabled 
										-- or targeted by atg
-- 										prog_position := "UC2330";

										write_message (
											file_handle => file_chkpsn_messages,
											text => " is shared",
											lf => false,									
											console => false);
										
										-- check if control cell can be set to disable state
										if not control_cell_in_enable_state_by_any_cell_list( 
											--net		=> d.name,
											net		=> name,
											class	=> d.class,
											device	=> element(d.pins, positive(i)).device_name,
											cell_id	=> element(d.pins, positive(i)).cell_info.control_cell_id) then

											write_message (
												file_handle => file_chkpsn_messages,
												text => " but can be set to disable state.",
												console => false);
											
-- 											prog_position := "UC2340";
-- 											add_to_locked_control_cells_in_class_DH_DL_NR_nets(
-- 												list				=> ptr_cell_list_static_control_cells_class_DX_NR,
-- 												class_given			=> class,
-- 												level_given			=> level,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> d.pin(p).device_name,
-- 												pin_given			=> d.pin(p).device_pin_name,
-- 												cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 												locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
-- 																						-- must be in disable state
-- 												disable_value_given				=> d.pin(p).cell_info.disable_value
-- 												);

											-- because this is a secondary net, the control cell must be in disable state
											append(list_of_static_control_cells_class_DX_NR,(
												locked_to_enable_state	=> false, 
												level					=> d.level,																					 
												class					=> d.class,
												--net						=> d.name,
												net						=> name,
												device					=> element(d.pins, positive(i)).device_name,
												pin						=> element(d.pins, positive(i)).device_pin_name,
												id						=> element(d.pins, positive(i)).cell_info.control_cell_id,
												disable_value			=> element(d.pins, positive(i)).cell_info.disable_value));
										end if; -- check if control cell can be set to disable state

									else 
										-- driver has a non-shared control cell
										-- so there is no need to check cell lists 
										-- all control cells of those nets must be in disable state

										write_message (
											file_handle => file_chkpsn_messages,
											text => " is not shared",
											lf => false,									
											console => false);
										
-- 										add_to_locked_control_cells_in_class_DH_DL_NR_nets(
-- 											list				=> ptr_cell_list_static_control_cells_class_DX_NR,
-- 											class_given			=> class,
-- 											level_given			=> level,
-- 											net_given			=> universal_string_type.to_bounded_string(name),
-- 											device_given		=> d.pin(p).device_name,
-- 											pin_given			=> d.pin(p).device_pin_name,
-- 											cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 											locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
-- 																					-- must be in disable state
-- 											disable_value_given				=> d.pin(p).cell_info.disable_value
-- 											);

										-- because this is a secondary net, the control cell must be in disable state
										append(list_of_static_control_cells_class_DX_NR,(
											locked_to_enable_state	=> false, 
											level					=> d.level,																					 
											class					=> d.class,
											--net						=> d.name,
											net						=> name,
											device					=> element(d.pins, positive(i)).device_name,
											pin						=> element(d.pins, positive(i)).device_pin_name,
											id						=> element(d.pins, positive(i)).cell_info.control_cell_id,
											disable_value			=> element(d.pins, positive(i)).cell_info.disable_value));
										
									end if; -- if driver has a shared control cell

									write_message (
										file_handle => file_chkpsn_messages,
										text => "",
										lf => true,
										console => false);

								when PU | PD =>

									write_message (
										file_handle => file_chkpsn_messages,
										identation => 4,
										text => "control cell: device " & to_string(element(d.pins, positive(i)).device_name) 
											& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
											& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.control_cell_id),
										lf => false,
										console => false);
									
									if element(d.pins, positive(i)).cell_info.control_cell_shared then
										-- if driver has a shared control cell
										-- the driver pin can be disabled if its control cell is not already enabled 
										-- or targeted by atg

										write_message (
											file_handle => file_chkpsn_messages,
											text => " is shared",
											lf => false,									
											console => false);
										
										-- check if control cell can be set to disable state
										if not control_cell_in_enable_state_by_any_cell_list( 
											--net		=> d.name,
											net		=> name,
											class	=> d.class,
											device	=> element(d.pins, positive(i)).device_name,
											cell_id	=> element(d.pins, positive(i)).cell_info.control_cell_id) then

											write_message (
												file_handle => file_chkpsn_messages,
												text => " but can be set to disable state.",
												console => false);
											
-- 											add_to_locked_control_cells_in_class_PU_PD_nets(
-- 												list				=> ptr_cell_list_static_control_cells_class_PX,
-- 												class_given			=> class,
-- 												level_given			=> level,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> d.pin(p).device_name,
-- 												pin_given			=> d.pin(p).device_pin_name,
-- 												cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 												--locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
-- 																						-- must be in disable state
-- 												disable_value_given				=> d.pin(p).cell_info.disable_value
-- 												);

											-- because this is a secondary net, the control cell must be in disable state
											append(list_of_static_control_cells_class_PX,(
												level					=> d.level,																					 
												class					=> d.class,
												--net						=> d.name,
												net						=> name,
												device					=> element(d.pins, positive(i)).device_name,
												pin						=> element(d.pins, positive(i)).device_pin_name,
												id						=> element(d.pins, positive(i)).cell_info.control_cell_id,
												disable_value			=> element(d.pins, positive(i)).cell_info.disable_value));
											
										end if;  -- check if control cell can be set to disable state

									else 
										-- driver has a non-shared control cell
										-- so there is no need to check cell lists 
										-- all control cells of those nets must be in disable state

										write_message (
											file_handle => file_chkpsn_messages,
											text => " is not shared",
											lf => false,									
											console => false);
										
-- 										add_to_locked_control_cells_in_class_PU_PD_nets(
-- 											list				=> ptr_cell_list_static_control_cells_class_PX,
-- 											class_given			=> class,
-- 											level_given			=> level,
-- 											net_given			=> universal_string_type.to_bounded_string(name),
-- 											device_given		=> d.pin(p).device_name,
-- 											pin_given			=> d.pin(p).device_pin_name,
-- 											cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 											--locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
-- 																					-- must be in disable state
-- 											disable_value_given				=> d.pin(p).cell_info.disable_value
-- 											);

										-- because this is a secondary net, the control cell must be in disable state
										append(list_of_static_control_cells_class_PX,(
											level					=> d.level,																					 
											class					=> d.class,
											--net						=> d.name,
											net						=> name,
											device					=> element(d.pins, positive(i)).device_name,
											pin						=> element(d.pins, positive(i)).device_pin_name,
											id						=> element(d.pins, positive(i)).cell_info.control_cell_id,
											disable_value			=> element(d.pins, positive(i)).cell_info.disable_value));
									
									end if; -- if driver has a shared control cell

									write_message (
										file_handle => file_chkpsn_messages,
										text => "",
										lf => true,
										console => false);

							end case;
						end if;
					when primary => -- because it is about secondary nets here
						null;
-- 						prog_position := "UC2400";
				end case;

			end if; -- if pin is scan capable
		end loop;

		-- FIND SUITABLE DRIVER PIN BEGIN:
		-- It will be searched for only one driver !
		write_message (
			file_handle => file_chkpsn_messages,
			identation => 4,
			text => "searching suitable driver pin ...",
			console => false);

		case d.level is
			when primary => -- search driver in primary nets only
				case d.class is -- search in these net classes only
					when DH | DL | NR | PU | PD =>
						-- FIND ALL OUTPUT PINS WITHOUT DISABLE SPEC

						write_message (
							file_handle => file_chkpsn_messages,
							identation => 5,
							text => "drivers without disable specification (output2):",
							console => false);
						
						-- if there is such a pin, it is to be preferred over other drivers
						drivers_without_disable_spec_ct := 0; -- reset counter for drivers without disable spec
						for i in 1..length(d.pins) loop -- loop through pin list of given net
							--p := element(d.pins, positive(i));
							-- NOTE: element(d.pins, positive(i)) equals the particular pin
							if element(d.pins, positive(i)).is_bscan_capable then -- care for scan capable pins only
								-- if pin has no disable spec. (means: no control cell)
								if element(d.pins, positive(i)).cell_info.output_cell_id /= -1 and element(d.pins, positive(i)).cell_info.control_cell_id = -1 then
									
									case d.class is
										when DH | DL =>

											write_message (
												file_handle => file_chkpsn_messages,
												identation => 6,
												text => "static output cell: device " & to_string(element(d.pins, positive(i)).device_name) 
													& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
													& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.output_cell_id),
												console => false);
											
-- 											add_to_locked_output_cells_in_class_DH_DL_nets(
-- 												list				=> ptr_cell_list_static_output_cells_class_DX_NR,
-- 												class_given			=> class,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> d.pin(p).device_name,
-- 												pin_given			=> d.pin(p).device_pin_name,
-- 												cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 												drive_value_given	=> drive_value_derived_from_class(class)
-- 												);
										
											append(list_of_static_output_cells_class_DX_NR,(
												class					=> d.class,
												--net						=> d.name,
												net						=> name,
												device					=> element(d.pins, positive(i)).device_name,
												pin						=> element(d.pins, positive(i)).device_pin_name,
												id						=> element(d.pins, positive(i)).cell_info.output_cell_id,
												drive_value				=> drive_value_derived_from_class(d.class)));
										
										when NR =>

											write_message (
												file_handle => file_chkpsn_messages,
												identation => 5,
												text => "static output cell: device " & to_string(element(d.pins, positive(i)).device_name) 
													& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
													& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.control_cell_id),
												console => false);
											
-- 											add_to_atg_drive(
-- 												list				=> ptr_cell_list_atg_drive,
-- 												class_given			=> class,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> d.pin(p).device_name,
-- 												pin_given			=> d.pin(p).device_pin_name,
-- 												cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 												controlled_by_control_cell_given	=> false -- controlled by output cell
-- 												-- example: class NR primary_net LED7 device IC303 pin 2 output_cell 7
-- 												);

											append(list_of_atg_drive_cells,(
												class						=> d.class,
												--net							=> d.name,
												net							=> name,
												device						=> element(d.pins, positive(i)).device_name,
												pin							=> element(d.pins, positive(i)).device_pin_name,
												id							=> element(d.pins, positive(i)).cell_info.control_cell_id,
												controlled_by_control_cell	=> false));

										when others => 
-- 											prog_position := "UC2650";
											raise constraint_error; -- CS: this should never happen, special message required
									end case; -- class

									-- mark driver as active
									update_element(d.pins, positive(i), set_selected_as_driver'access);
									-- CS: CAUTION ! MAKE SURE ATG SYNCRONIZES THOSE DRIVERS !
									drivers_without_disable_spec_ct := drivers_without_disable_spec_ct + 1;

								end if;
							end if; -- if pin is scan capable
						end loop; -- loop through pin list of given net

						-- if output pin without disable spec found, other drivers must be found and disabled
						if drivers_without_disable_spec_ct > 0 then
-- 							if debug_level >= 30 then
-- 								put_line(standard_output, positive'image(drivers_without_disable_spec_ct) & " driver(s) with non-shared control cell found in net " & universal_string_type.to_string(d.name));
-- 							end if;
							if drivers_without_disable_spec_ct > 1 then
								put_line(standard_output, message_error & "Common mode drivers are not supported currently !"); -- CS
								raise constraint_error;
							end if;
							disable_remaining_drivers(net_name => name, net => d); -- disable left over drivers in net
						else 
						-- NO OUTPUT PIN WITHOUT DISABLE SPEC FOUND
						-- FIND ONE DRIVER WITH NON-SHARED CONTROL CELL

							write_message (
								file_handle => file_chkpsn_messages,
								identation => 5,
								text => "... none found. Searching driver with disable specification (output3) and non-shared control cell ...",
								console => false);

							for i in 1..length(d.pins) loop -- loop through pin list of given net -- CS: use a variable that holds the pin count of the net
								--p := element(d.pins, positive(i));
								-- NOTE: element(d.pins, positive(i)) equals the particular pin
								if element(d.pins, positive(i)).is_bscan_capable then -- care for scan capable pins only
									-- if pin has output cell with disable spec. (means: there is a control cell)
									if element(d.pins, positive(i)).cell_info.output_cell_id /= -1 and element(d.pins, positive(i)).cell_info.control_cell_id /= -1 then
										-- select non-shared control cells

										if not element(d.pins, positive(i)).cell_info.control_cell_shared then

											case d.class is
												when DH | DL =>

													write_message (
														file_handle => file_chkpsn_messages,
														identation => 6,
														text => "static control cell: device " & to_string(element(d.pins, positive(i)).device_name) 
															& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
															& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.control_cell_id),
														console => false);

													-- add control cell to list (no need to check cell lists, as this control cell is non-shared)
-- 													add_to_locked_control_cells_in_class_DH_DL_NR_nets(
-- 														list				=> ptr_cell_list_static_control_cells_class_DX_NR,
-- 														class_given			=> class,
-- 														level_given			=> level,
-- 														net_given			=> universal_string_type.to_bounded_string(name),
-- 														device_given		=> d.pin(p).device_name,
-- 														pin_given			=> d.pin(p).device_pin_name,
-- 														cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 														locked_to_enable_state_given	=> true, -- the pin is to be enabled
-- 														enable_value_given				=> negate_bit_character_class_0(d.pin(p).cell_info.disable_value)
-- 														);

													append(list_of_static_control_cells_class_DX_NR,(
														locked_to_enable_state	=> true, 
														level					=> d.level,																					 
														class					=> d.class,
														--net						=> d.name,
														net						=> name,
														device					=> element(d.pins, positive(i)).device_name,
														pin						=> element(d.pins, positive(i)).device_pin_name,
														id						=> element(d.pins, positive(i)).cell_info.control_cell_id,
														enable_value			=> negate_bit_character_class_0(element(d.pins, positive(i)).cell_info.disable_value)));

													
													-- add output cell to list

													write_message (
														file_handle => file_chkpsn_messages,
														identation => 6,
														text => "static output cell: device " & to_string(element(d.pins, positive(i)).device_name) 
															& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
															& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.output_cell_id),
														console => false);
													
-- 													add_to_locked_output_cells_in_class_DH_DL_nets(
-- 														list				=> ptr_cell_list_static_output_cells_class_DX_NR,
-- 														class_given			=> class,
-- 														net_given			=> universal_string_type.to_bounded_string(name),
-- 														device_given		=> d.pin(p).device_name,
-- 														pin_given			=> d.pin(p).device_pin_name,
-- 														cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 														drive_value_given	=> drive_value_derived_from_class(class)
-- 														);

													append(list_of_static_output_cells_class_DX_NR,(
														class					=> d.class,
														--net						=> d.name,
														net						=> name,
														device					=> element(d.pins, positive(i)).device_name,
														pin						=> element(d.pins, positive(i)).device_pin_name,
														id						=> element(d.pins, positive(i)).cell_info.output_cell_id,
														drive_value				=> drive_value_derived_from_class(d.class)));

												when NR =>
													-- add control cell to list

													write_message (
														file_handle => file_chkpsn_messages,
														identation => 6,
														text => "static control cell: device " & to_string(element(d.pins, positive(i)).device_name) 
															& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
															& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.control_cell_id),
														console => false);
													
-- 													add_to_locked_control_cells_in_class_DH_DL_NR_nets(
-- 														list				=> ptr_cell_list_static_control_cells_class_DX_NR,
-- 														class_given			=> class,
-- 														level_given			=> level,
-- 														net_given			=> universal_string_type.to_bounded_string(name),
-- 														device_given		=> d.pin(p).device_name,
-- 														pin_given			=> d.pin(p).device_pin_name,
-- 														cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 														locked_to_enable_state_given	=> true, -- the pin is to be enabled
-- 														enable_value_given				=> negate_bit_character_class_0(d.pin(p).cell_info.disable_value)
-- 														);

													append(list_of_static_control_cells_class_DX_NR,(
														locked_to_enable_state	=> true, 
														level					=> d.level,																					 
														class					=> d.class,
														--net						=> d.name,
														net						=> name,
														device					=> element(d.pins, positive(i)).device_name,
														pin						=> element(d.pins, positive(i)).device_pin_name,
														id						=> element(d.pins, positive(i)).cell_info.control_cell_id,
														enable_value			=> negate_bit_character_class_0(
																					element(d.pins, positive(i)).cell_info.disable_value)));
													
-- 													-- add output cell to list
													write_message (
														file_handle => file_chkpsn_messages,
														identation => 6,
														text => "atg drive cell: device " & to_string(element(d.pins, positive(i)).device_name) 
															& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
															& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.output_cell_id),
														console => false);
													
-- 													add_to_atg_drive(
-- 														list				=> ptr_cell_list_atg_drive,
-- 														class_given			=> class,
-- 														net_given			=> universal_string_type.to_bounded_string(name),
-- 														device_given		=> d.pin(p).device_name,
-- 														pin_given			=> d.pin(p).device_pin_name,
-- 														cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 														controlled_by_control_cell_given	=> false -- controlled by output cell
-- 														-- example: class NR primary_net LED7 device IC303 pin 2 output_cell 7
-- 														);

													append(list_of_atg_drive_cells,(
														class						=> d.class,
														--net							=> d.name,
														net							=> name,
														device						=> element(d.pins, positive(i)).device_name,
														pin							=> element(d.pins, positive(i)).device_pin_name,
														id							=> element(d.pins, positive(i)).cell_info.output_cell_id,
														controlled_by_control_cell	=> false));

												when PU | PD =>
													-- add output cell to list
													-- NOTE: in pull-up/down nets, the output cell of the driver is static

													write_message (
														file_handle => file_chkpsn_messages,
														identation => 6,
														text => "static output cell: device " & to_string(element(d.pins, positive(i)).device_name) 
															& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
															& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.output_cell_id),
														console => false);
													
-- 													add_to_locked_output_cells_in_class_PU_PD_nets(
-- 														list				=> ptr_cell_list_static_output_cells_class_PX,
-- 														class_given			=> class,
-- 														net_given			=> universal_string_type.to_bounded_string(name),
-- 														device_given		=> d.pin(p).device_name,
-- 														pin_given			=> d.pin(p).device_pin_name,
-- 														cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 														drive_value_given	=> drive_value_derived_from_class(class)
-- 														-- example: class PU primary_net /SYS_RESET device IC300 pin 39 output_cell 37 locked_to drive_value 0
-- 														);

													append(list_of_static_output_cells_class_PX,(
														class						=> d.class,
														--net							=> d.name,
														net							=> name,
														device						=> element(d.pins, positive(i)).device_name,
														pin							=> element(d.pins, positive(i)).device_pin_name,
														id							=> element(d.pins, positive(i)).cell_info.output_cell_id,
														drive_value					=> drive_value_derived_from_class(d.class)));

													-- add control cell to list
													-- NOTE: in pull-up/down nets, the control cell of the driver is dynamic (means ATG controlled)
													write_message (
														file_handle => file_chkpsn_messages,
														identation => 6,
														text => "atg drive cell: device " & to_string(element(d.pins, positive(i)).device_name) 
															& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
															& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.control_cell_id),
														console => false);													

-- 													add_to_atg_drive(
-- 														list				=> ptr_cell_list_atg_drive,
-- 														class_given			=> class,
-- 														net_given			=> universal_string_type.to_bounded_string(name),
-- 														device_given		=> d.pin(p).device_name,
-- 														pin_given			=> d.pin(p).device_pin_name,
-- 														cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 														controlled_by_control_cell_given	=> true, -- controlled by control cell
-- 														control_cell_inverted_given	=> inverted_status_derived_from_class_and_disable_value(
-- 																							class_given => class,
-- 																							disable_value_given => d.pin(p).cell_info.disable_value
-- 																							)
-- 														-- example: -- class PU primary_net /CPU_WR device IC300 pin 26 control_cell 6 inverted yes
-- 														);

													append(list_of_atg_drive_cells,(
														class						=> d.class,
														--net							=> d.name,
														net							=> name,
														device						=> element(d.pins, positive(i)).device_name,
														pin							=> element(d.pins, positive(i)).device_pin_name,
														id							=> element(d.pins, positive(i)).cell_info.control_cell_id,
														controlled_by_control_cell	=> true,
														inverted					=> inverted_status_derived_from_class_and_disable_value(
																							class => d.class,
																							disable_value => element(
																								d.pins, positive(i)).cell_info.disable_value)));


												when others => 
												--prog_position := "UC2890"; 
													null; -- in EL and EH nets, no driver is to be searched for
													-- this code should never be reached
											end case;

											-- mark driver as active
											update_element(d.pins, positive(i), set_selected_as_driver'access);
											
											driver_with_non_shared_control_cell_found := true;
											exit; -- no more driver search required

										end if; -- if non-shared control cell
									end if; -- if pin has output and control cell
								end if; -- if pin is scan capable
							end loop; -- loop through pin list of given net

							if driver_with_non_shared_control_cell_found then
-- 								if debug_level >= 30 then
-- 									put_line(standard_output,"   driver with non-shared control cell found in net " & universal_string_type.to_string(d.name));
-- 								end if;
								--disable_remaining_drivers(d); -- disable left over drivers in net where d points to
								disable_remaining_drivers(net_name => name, net => d); -- disable left over drivers in net
							else
							-- NO OUTPUT PIN WITHOUT NON-SHARED CONTROL CELL FOUND
							-- FIND DRIVER WITH SHARED CONTROL CELL

								write_message (
									file_handle => file_chkpsn_messages,
									identation => 5,
									text => "... none found. Searching driver with disable specification (output3) and shared control cell ...",
									console => false);
								
								-- FOR PU/PD NETS, WITHOUT SPECIAL THREATMENT, ABORT HERE
								-- pull-nets require a driver with a fully independed control cell
								if d.class = PU or d.class = PD then
									put_line(standard_output,message_error & "Shared control cell conflict ! No suitable driver pin found in class " 
										--& type_net_class'image(d.class) & " net '" & to_string(d.name) & "' !.");
										& type_net_class'image(d.class) & " net '" & to_string(name) & "' !.");
									put_line(standard_output,"Class PU or PD nets require a driver with a fully independed control cell !");
									-- CS: refine error output
									raise constraint_error;
								end if;

								-- for p in 1..d.part_ct loop -- loop through pin list of given net
								for i in 1..length(d.pins) loop
									--p := element(d.pins, positive(i));
									-- NOTE: element(d.pins, positive(i)) equals the particular pin
									if element(d.pins, positive(i)).is_bscan_capable then -- care for scan capable pins only
										-- if pin has output cell with disable spec. (means: there is a control cell)
										if element(d.pins, positive(i)).cell_info.output_cell_id /= -1 and element(d.pins, positive(i)).cell_info.control_cell_id /= -1 then

											-- care for shared control cells only
											if element(d.pins, positive(i)).cell_info.control_cell_shared then

												case d.class is
													when DH | DL | NR =>
														-- the driver pin can be used if its control cell is not already disabled 
														-- or targeted by atg
														-- so the cell lists must be checked

														if not control_cell_in_disable_state_by_any_cell_list( 
															--net		=> d.name,
															net		=> name,
															class	=> d.class,
															device	=> element(d.pins, positive(i)).device_name,
															cell_id	=> element(d.pins, positive(i)).cell_info.control_cell_id) then

															-- the driver pin can be used as driver, its control cell is not in use by atg and not in disable state

															-- add control cell to list
															write_message (
																file_handle => file_chkpsn_messages,
																identation => 6,
																text => "static control cell: device " & to_string(element(d.pins, positive(i)).device_name) 
																	& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
																	& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.control_cell_id),
																console => false);
															
-- 															add_to_locked_control_cells_in_class_DH_DL_NR_nets(
-- 																list				=> ptr_cell_list_static_control_cells_class_DX_NR,
-- 																class_given			=> class,
-- 																level_given			=> level,
-- 																net_given			=> universal_string_type.to_bounded_string(name),
-- 																device_given		=> d.pin(p).device_name,
-- 																pin_given			=> d.pin(p).device_pin_name,
-- 																cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 																locked_to_enable_state_given	=> true, -- the pin is to be enabled
-- 																enable_value_given				=> negate_bit_character_class_0(d.pin(p).cell_info.disable_value)
-- 																);
	
															append(list_of_static_control_cells_class_DX_NR,(
																class					=> d.class,
																level					=> d.level,
																--net						=> d.name,
																net						=> name,
																device					=> element(d.pins, positive(i)).device_name,
																pin						=> element(d.pins, positive(i)).device_pin_name,
																id						=> element(d.pins, positive(i)).cell_info.control_cell_id,
																locked_to_enable_state	=> true,
																enable_value			=> negate_bit_character_class_0(element(
																							d.pins, positive(i)).cell_info.disable_value)));

															case d.class is
																when DH | DL =>
																	-- add output cell to list
																	write_message (
																		file_handle => file_chkpsn_messages,
																		identation => 6,
																		text => "static output cell: device " & to_string(element(d.pins, positive(i)).device_name) 
																			& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
																			& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.output_cell_id),
																		console => false);
																	
-- 																	add_to_locked_output_cells_in_class_DH_DL_nets(
-- 																		list				=> ptr_cell_list_static_output_cells_class_DX_NR,
-- 																		class_given			=> class,
-- 																		net_given			=> universal_string_type.to_bounded_string(name),
-- 																		device_given		=> d.pin(p).device_name,
-- 																		pin_given			=> d.pin(p).device_pin_name,
-- 																		cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 																		drive_value_given	=> drive_value_derived_from_class(class)
-- 																		);

																	append(list_of_static_output_cells_class_DX_NR,(
																		class				=> d.class,
																		--net					=> d.name,
																		net					=> name,
																		device				=> element(d.pins, positive(i)).device_name,
																		pin					=> element(d.pins, positive(i)).device_pin_name,
																		id					=> element(d.pins, positive(i)).cell_info.output_cell_id,
																		drive_value			=> drive_value_derived_from_class(d.class)));

																when NR =>
																	-- add output cell to list

																	write_message (
																		file_handle => file_chkpsn_messages,
																		identation => 6,
																		text => "atg drive cell: device " & to_string(element(d.pins, positive(i)).device_name) 
																			& " pin " & to_string(element(d.pins, positive(i)).device_pin_name) & row_separator_0 
																			& " cell " & type_cell_id'image(element(d.pins, positive(i)).cell_info.output_cell_id),
																		console => false);
																	
-- 																	add_to_atg_drive(
-- 																		list				=> ptr_cell_list_atg_drive,
-- 																		class_given			=> class,
-- 																		net_given			=> universal_string_type.to_bounded_string(name),
-- 																		device_given		=> d.pin(p).device_name,
-- 																		pin_given			=> d.pin(p).device_pin_name,
-- 																		cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 																		controlled_by_control_cell_given	=> false
-- 																		);

																	append(list_of_atg_drive_cells,(
																		class						=> d.class,
																		--net							=> d.name,
																		net							=> name,
																		device						=> element(d.pins, positive(i)).device_name,
																		pin							=> element(d.pins, positive(i)).device_pin_name,
																		id							=> element(d.pins, positive(i)).cell_info.output_cell_id,
																		controlled_by_control_cell	=> false));
																
																when others => -- should never happen
																	null;
-- 																	prog_position := "UC3260";
																	raise constraint_error; 
															end case;

															-- mark driver as active
															--p.cell_info.selected_as_driver := true; 
															update_element(
																container => d.pins,
																index => positive(i),
																process => set_selected_as_driver'access);
															
															driver_with_shared_control_cell_found := true;
															exit; -- no more driver search required

														end if; -- if control_cell_in_any_cell_list

													when others => -- should never happen
-- 														prog_position := "UC3270";
														raise constraint_error; 

												end case; -- class

											end if; -- if shared control cell
										end if; -- if pin has output and control cell
									end if; -- if pin is scan capable
								end loop; -- loop through pin list of given net

								-- abort if no driver with shared control cell found
-- 								prog_position := "UC3280";
								if not driver_with_shared_control_cell_found then
									put_line(standard_output,message_error & "Shared control cell conflict ! No suitable driver pin found in class " 
										--& type_net_class'image(d.class) & " net '" & to_string(d.name) & "' !.");
										& type_net_class'image(d.class) & " net '" & to_string(name) & "' !.");
									raise constraint_error;
								end if;
							end if; -- if driver_with_non_shared_control_cell_found
						end if; -- if driver without disable spec found

					when others => 
-- 						prog_position := "UC3290"; -- class EH | EL does not require searching for any driver pins
						null;
				end case; -- class

			when others =>
-- 				prog_position := "UC3300"; -- secondary nets never have any drivers enabled
				null;
		end case; -- level
	end update_cell_lists;

	
	procedure dump_net_content (
	-- From a given net name, the whole content (means all devices) is dumped into the 
	-- preliminary database.
	-- Updates cell lists.

		net		: in type_options_net;
		level 	: in type_net_level; 

		-- For secondary nets, the superordinated primary net is taken here. otherwise the default is "".
		-- This argument is required for writing cell lists, where reference to primary nets is required.
 		primary_net_is		: in type_net_name.bounded_string := type_net_name.to_bounded_string("");

		spacing_from_left 	: in positive -- CS: should read "indentation"
		) is
		n : type_net; -- for temporarily storage of a net taken from current database
-- 		p : type_pin; -- for temporarily storage of a pin of net d

		--procedure set_optimized_flag (net : in out type_net) is
		procedure set_optimized_flag (key : in type_net_name.bounded_string; net : in out type_net) is
		begin
			net.optimized := true;
		end set_optimized_flag;

		net_cursor : type_list_of_nets.cursor := find(list_of_nets, net.name);
	begin -- dump_net_content for net name given in "name"
		-- net name "name" is passed from superordinated procedure make_new_net_list when calling this procedure
		-- Marks the net as "optimized".
		-- Fetches net content from database netlist in n.
		
		--for i in 1..length(list_of_nets) loop
		--	n := element(list_of_nets, positive(i));
		
		n := element(net_cursor);

-- 			-- on match of net name: means, the net given from make_new_net_list has been found in database
-- 			if n.name = net.name then

				write_message (
					file_handle => file_chkpsn_messages,
		  			identation => 2,
					text => "writing " & type_net_level'image(level) 
						& " class " & type_net_class'image(net.class) -- class requested by given net !
						--& " net " & to_string(n.name),
						& " net " & to_string(key(net_cursor)), 
					console => false);
				
				-- mark this net as optimized by chkpsn
				-- later this net will be skipped when writing non-optimized nets into the preliminary data base
				--update_element(list_of_nets, positive(i), set_optimized_flag'access);
				update_element(container => list_of_nets, position => net_cursor, process => set_optimized_flag'access);

				-- loop through part list of the net
				-- and dump the net content like "IC301 ? XC9536 PLCC-S44 2  pb00_00 | 107 bc_1 input x | 106 bc_1 output3 x 105 0 z"
				-- into the preliminary data base
				for i in 1..length(n.pins) loop
					--  p := element(n.pins, positive(i));
					-- NOTE: element(n.pins, positive(i)) equals the particular pin
					-- dump the standard segment like "IC301 ? XC9536 PLCC-S44 2"
					put(spacing_from_left*row_separator_0 & to_string(element(n.pins, positive(i)).device_name)
						& row_separator_0 & type_device_class'image(element(n.pins, positive(i)).device_class)
						& row_separator_0 & to_string(element(n.pins, positive(i)).device_value)
						& row_separator_0 & to_string(element(n.pins, positive(i)).device_package)
						& row_separator_0 & to_string(element(n.pins, positive(i)).device_pin_name)
					);
					if element(n.pins, positive(i)).is_bscan_capable then
						-- dump the input cell segment like "| 107 bc_1 input x "
                        put(row_separator_0 & to_string(element(n.pins, positive(i)).device_port_name));

                        -- If there is an input cell is must be written. If its function is bidir we do not 
                        -- write it because it is the same as the output cell. The output cell will be dealt with
                        -- later (see below):
                        if element(n.pins, positive(i)).cell_info.input_cell_id /= -1 then
                            if element(n.pins, positive(i)).cell_info.input_cell_function /= bidir then
                                put(row_separator_1 & trim(natural'image(element(n.pins, positive(i)).cell_info.input_cell_id),left)
                                    & row_separator_0 & type_boundary_register_cell'image(element(n.pins, positive(i)).cell_info.input_cell_type)
                                    & row_separator_0 & type_cell_function'image(element(n.pins, positive(i)).cell_info.input_cell_function)
                                    & row_separator_0 & type_bit_char_class_1'image(element(n.pins, positive(i)).cell_info.input_cell_safe_value)(2)
                                   );
                            end if;
						end if;

						if element(n.pins, positive(i)).cell_info.output_cell_id /= -1 then
							-- dump the output cell segment like "| 106 bc_1 output3"
							put(row_separator_1 & trim(natural'image(element(n.pins, positive(i)).cell_info.output_cell_id),left)
								& row_separator_0 & type_boundary_register_cell'image(element(n.pins, positive(i)).cell_info.output_cell_type)
								& row_separator_0 & type_cell_function'image(element(n.pins, positive(i)).cell_info.output_cell_function)
								& row_separator_0 & type_bit_char_class_1'image(element(n.pins, positive(i)).cell_info.output_cell_safe_value)(2)
								);

							if element(n.pins, positive(i)).cell_info.control_cell_id /= -1 then
								-- dump the contol cell segment like "x 105 0 z"
								put(row_separator_0 & trim(natural'image(element(n.pins, positive(i)).cell_info.control_cell_id),left)
									& row_separator_0 & type_bit_char_class_0'image(element(n.pins, positive(i)).cell_info.disable_value)(2)
									& row_separator_0 & type_disable_result'image(element(n.pins, positive(i)).cell_info.disable_result)
									);
							end if;
						end if;
					else -- pin is not scan capable, but it might have a port name (linkage pins of bic)
						if to_string(element(n.pins, positive(i)).device_port_name) /= "" then
							put(row_separator_0 & to_string(element(n.pins, positive(i)).device_port_name));
						end if;
					end if;
					new_line; -- line finished, add line break for next line
				end loop; -- loop through part list of the net
				-- net content dumping completed

				-- Now that d contains the new modified net,
				-- the new cell list can be updated regarding this net:
				if n.bs_capable then
					case level is
						when primary =>
							update_cell_lists( 
								name => key(net_cursor),
								net => (
									class => net.class,
									level => primary,
									--name => n.name,
									pins => n.pins,
									bs_bidir_pin_count => n.bs_bidir_pin_count,
									bs_input_pin_count => n.bs_input_pin_count,
									bs_output_pin_count => n.bs_output_pin_count,
									bs_capable => n.bs_capable,
									secondary_net_names => n.secondary_net_names,
									optimized => n.optimized, -- does not matter here
									cluster => false, -- does not matter here
									cluster_id => 0 --does not matter here		
								));

						when secondary =>
							update_cell_lists( 
								name => key(net_cursor),
								net => (
									class => net.class,
									level => secondary,
									--name => n.name,
									pins => n.pins,
									bs_bidir_pin_count => n.bs_bidir_pin_count,
									bs_input_pin_count => n.bs_input_pin_count,
									bs_output_pin_count => n.bs_output_pin_count,
									bs_capable => n.bs_capable,
									name_of_primary_net => primary_net_is,
									optimized => n.optimized, -- does not matter here
									cluster => false, -- does not matter here
									cluster_id => 0 --does not matter here		
								));
					end case;
				end if;


				-- update net count statistics.
				net_count_statistics.total := net_count_statistics.total + 1;
				case net.class is
					when PU => 
						net_count_statistics.pu 			:= net_count_statistics.pu + 1;
						net_count_statistics.bs_dynamic		:= net_count_statistics.bs_dynamic + 1;
						net_count_statistics.bs_testable	:= net_count_statistics.bs_testable + 1;
					when PD => 
						net_count_statistics.pd 			:= net_count_statistics.pd + 1; 
						net_count_statistics.bs_dynamic 	:= net_count_statistics.bs_dynamic + 1;
						net_count_statistics.bs_testable 	:= net_count_statistics.bs_testable + 1;
					when DH => 
						net_count_statistics.dh 			:= net_count_statistics.dh + 1;
						net_count_statistics.bs_static 		:= net_count_statistics.bs_static + 1;
						net_count_statistics.bs_static_h 	:= net_count_statistics.bs_static_h + 1;
						net_count_statistics.bs_testable 	:= net_count_statistics.bs_testable + 1;
					when DL => 
						net_count_statistics.dl 			:= net_count_statistics.dl + 1;
						net_count_statistics.bs_static 		:= net_count_statistics.bs_static + 1;
						net_count_statistics.bs_static_l 	:= net_count_statistics.bs_static_l + 1;
						net_count_statistics.bs_testable 	:= net_count_statistics.bs_testable + 1;
					when EH => 
						net_count_statistics.eh 			:= net_count_statistics.eh + 1;
						net_count_statistics.bs_static 		:= net_count_statistics.bs_static + 1;
						net_count_statistics.bs_static_h 	:= net_count_statistics.bs_static_h + 1;
						net_count_statistics.bs_testable 	:= net_count_statistics.bs_testable + 1;
					when EL => 
						net_count_statistics.el 			:= net_count_statistics.el + 1;
						net_count_statistics.bs_static 		:= net_count_statistics.bs_static + 1;
						net_count_statistics.bs_static_l 	:= net_count_statistics.bs_static_l + 1;
						net_count_statistics.bs_testable 	:= net_count_statistics.bs_testable + 1;
					when NR => 
						net_count_statistics.nr 			:= net_count_statistics.nr + 1;
						net_count_statistics.bs_dynamic 	:= net_count_statistics.bs_dynamic + 1;
						net_count_statistics.bs_testable 	:= net_count_statistics.bs_testable + 1;
					when NA => 
						net_count_statistics.na 			:= net_count_statistics.na + 1;
				end case;

-- 				exit; -- no need to search other nets in data base
-- 			end if;
-- 
-- 		end loop;
	end dump_net_content;

	
	procedure make_new_netlist is
		-- With the two netlists list_of_nets and list_of_options_nets, a new netlist is created
		-- and appended to the preliminary database.
		-- Updates the cell lists (but does not write them in the preliminary database yet).
		-- the class requirements and secondary net dependencies from the options file are taken into account
		o	: type_options_net; -- for temporarily storage of an options net
		n 	: type_net; -- for temporarily storage of a database net

		net_cursor : type_list_of_nets.cursor;
	begin -- make_new_netlist
		-- writes a structure as shown below in the preliminary data base:

		--> header:	SubSection LED1 class NR

		--> by procedure dump_net_content:
		-- 		RN302 '?' 2k7 SIL8 4
		-- 		JP402 '?' MON1 2X20 22
		-- 		IC303 '?' SN74BCT8240ADWR SOIC24 9 y2(3) | 1 BC_1 OUTPUT3 X 16 1 Z
		-- 		D402 '?' none LED5MM K
		--> footer:	EndSubSection
		--> footer:	SubSection secondary_nets_of LED1
		-- 
		--> header: SubSection LED1_R class NR
		--> by procedure dump_net_content:
		-- 			RN302 '?' 2k7 SIL8 3
		-- 			JP402 '?' MON1 2X20 28
		-- 			IC301 '?' XC9536 PLCC-S44 3 pb00_01 | 104 BC_1 INPUT X | 103 BC_1 OUTPUT3 X 102 0 Z
		--> footer:	EndSubSection
		--> footer: EndSubSection secondary_nets_of LED1
	
		write_message (
			file_handle => file_chkpsn_messages,
			identation => 1,
			text => "making new netlist ...", 
			console => true);

		if length(list_of_options_nets) > 0 then -- we make a new netlist if there are nets in the options file
			for i in 1..length(list_of_options_nets) loop
				o := element(list_of_options_nets, positive(i));
				new_line;
				-- write primary net header like "SubSection LED0 class NR" (name and class taken from options net list)
				put_line(column_separator_0);
				put_line(row_separator_0 & section_mark.subsection & row_separator_0 & to_string(o.name) & row_separator_0 
					& text_udb_class & row_separator_0 & type_net_class'image(o.class));
				
				put_line(2 * row_separator_0 & comment_mark & m1_database.pin_legend);
				
				write_message (
					file_handle => file_chkpsn_messages,
					identation => 2,
					text => "primary net " & to_string(o.name), 
					console => false);

				dump_net_content(
					net => o,
					level => primary,
					spacing_from_left => 2
					);
				
				-- put end of primary net mark
				put_line(row_separator_0 & section_mark.endsubsection);

				-- if there are secondary nets specified in options net list, dump them one by one into the preliminary data base
				if o.has_secondaries then
					put_line(row_separator_0 & section_mark.subsection & row_separator_0 & netlist_keyword_header_secondary_nets & row_separator_0 & to_string(o.name));
					new_line;
					for s in 1..length(o.list_of_secondary_net_names) loop
						put_line(2*row_separator_0 & section_mark.subsection & row_separator_0 
							& to_string(element(o.list_of_secondary_net_names, positive(s)))
							& row_separator_0 & text_udb_class & row_separator_0 & type_net_class'image(o.class)
							);

						write_message (
							file_handle => file_chkpsn_messages,
							identation => 3,
							text => "secondary net " & to_string(element(o.list_of_secondary_net_names, positive(s))), 
							console => false);

						dump_net_content(
							net => (
								has_secondaries => false, -- because it is a secondary net
								name => element(o.list_of_secondary_net_names, positive(s)),
								class => o.class, -- because it inherits the class of the superordinated primary net
								line_number => 1 -- CS: does not matter here
								),
							level => secondary,
							primary_net_is => o.name, -- required for writing some cell lists where reference to primary net is required
							spacing_from_left => 4
							);

						put_line(2*row_separator_0 & section_mark.endsubsection);
						new_line;
					end loop;

					put_line(row_separator_0 & section_mark.endsubsection & row_separator_0 & netlist_keyword_header_secondary_nets &
							row_separator_0 & to_string(o.name));
					put_line(column_separator_0);
					new_line;
				end if;

			end loop;
		end if;

        -- Dump non-optimized nets. Non-optimized nets are nets that do not appear in the options file
        -- and thus are regarded as non-optimized.
		-- They have the "optimized" flag cleared (false) and default to level primary with class NA:

		write_message (
			file_handle => file_chkpsn_messages,
			identation => 1,
			text => "non-optimized nets:",
			console => false);

		new_line;
-- 		put_line(column_separator_0);
		put_line("-- NON-OPTIMIZED NETS");
		put_line(column_separator_0);

		net_cursor := first(list_of_nets);
		--for i in 1..length(list_of_nets) loop
		while net_cursor /= type_list_of_nets.no_element loop
			--n := element(list_of_nets, positive(i));
			n := element(net_cursor);
			if not n.optimized then -- if non-optimized
				--put_line(prog_position);
				new_line;
				-- write primary net header like "SubSection LED0 class NR" (name and class taken from options net list)
				put_line(column_separator_0);
				--put_line(row_separator_0 & section_mark.subsection & row_separator_0 & to_string(n.name) & row_separator_0
				put_line(row_separator_0 & section_mark.subsection & row_separator_0 & to_string(key(net_cursor)) & row_separator_0 
					& text_udb_class & row_separator_0 & type_net_class'image(NA));

				-- this is a primary net. it will be searched for in the net list and its content dumped into the preliminary data base

				write_message (
					file_handle => file_chkpsn_messages,
					identation => 2,
					--text => "primary net " & to_string(n.name),
					text => "primary net " & to_string(key(net_cursor)), 
					console => false);

				dump_net_content(
					net => ( -- NOTE: this is a type_options_net
						has_secondaries => false, -- because it is a lonely primary net
						--name => n.name,
						name => key(net_cursor),
						class => net_class_default,
						line_number => 1  -- does not matter here
						),
					level => primary,
					spacing_from_left => 2
					);
				
				-- put end of primary net mark
				put_line(row_separator_0 & section_mark.endsubsection);
			end if;
			next(net_cursor);
		end loop;
	end make_new_netlist;


	procedure write_new_cell_lists is
	-- Writes cell lists in preliminary database.
		a : type_static_control_cell_class_EX_NA;
--		b : type_static_control_cell_class_DX_NR;
		c : type_static_control_cell_class_PX;
		d : type_static_output_cell_class_PX;
		e : type_static_output_cell_class_DX_NR;
-- 		f : type_static_expect_cell;
-- 		g : type_atg_expect_cell;
-- 		h : type_atg_drive_cell;
-- 		i : type_input_cell_class_NA;
	begin
		write_message (
			file_handle => file_chkpsn_messages,
			identation => 1,
			text => "writing new cell lists ...",
			console => true);

		put_line("------- CELL LISTS ----------------------------------------------------------");
		new_line(2);

		--put_line("Section locked_control_cells_in_class_EH_EL_NA_nets");
		put_line(section_mark.section & row_separator_0 & section_static_control_cells_class_EX_NA);
		-- writes a cell list entry like:
		put_line("-- addresses control cells which statically disable drivers");
		put_line("-- example 1: class NA primary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0");
		put_line("-- example 2: class NA secondary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0");
		--while a /= null loop
		for cc in 1..length(list_of_static_control_cells_class_EX_NA) loop
			a := element(list_of_static_control_cells_class_EX_NA, positive(cc));
			put_line(" class " & type_net_class'image(a.class) & row_separator_0 & to_lower(type_net_level'image(a.level)) & "_net"
				& row_separator_0 & to_string(a.net) & " device"
				& row_separator_0 & to_string(a.device) & " pin"
				& row_separator_0 & to_string(a.pin) & " control_cell" & natural'image(a.id)
				& " locked_to disable_value " & type_bit_char_class_0'image(a.disable_value)(2) -- strip "'" delimiters
				);
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section locked_control_cells_in_class_DH_DL_NR_nets");
		put_line(section_mark.section & row_separator_0 & section_static_control_cells_class_DX_NR);
		-- writes a cell list entry like:
		put_line("-- addresses control cells which enable or disable static drivers");
		put_line("-- example 1: class NR primary_net LED0 device IC303 pin 10 control_cell 16 locked_to enable_value 0");
		put_line("-- example 2: class NR primary_net LED1 device IC303 pin 9 control_cell 16 locked_to enable_value 0");
		put_line("-- example 3: class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0");
		for cc in 1..length(list_of_static_control_cells_class_DX_NR) loop
			put(" class " & type_net_class'image(
					element(list_of_static_control_cells_class_DX_NR, positive(cc)).class) 
				& row_separator_0 & to_lower(type_net_level'image(
					element(list_of_static_control_cells_class_DX_NR, positive(cc)).level)) & "_net"
				& row_separator_0 & to_string(
					element(list_of_static_control_cells_class_DX_NR, positive(cc)).net) & " device"
				& row_separator_0 & to_string(
					element(list_of_static_control_cells_class_DX_NR, positive(cc)).device) & " pin"
				& row_separator_0 & to_string(
					element(list_of_static_control_cells_class_DX_NR, positive(cc)).pin) & " control_cell" 
				& natural'image(element(list_of_static_control_cells_class_DX_NR, positive(cc)).id)
				& " locked_to ");
			case element(list_of_static_control_cells_class_DX_NR, positive(cc)).locked_to_enable_state is
				when true 	=> put_line("enable_value " & type_bit_char_class_0'image(
					element(list_of_static_control_cells_class_DX_NR, positive(cc)).enable_value)(2)); -- strip "'" delimiters
				when false	=> put_line("disable_value " & type_bit_char_class_0'image(
					element(list_of_static_control_cells_class_DX_NR, positive(cc)).disable_value)(2)); -- strip "'" delimiters
			end case;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section locked_control_cells_in_class_PU_PD_nets");
		put_line(section_mark.section & row_separator_0 & section_static_control_cells_class_PX);
		-- writes a cell list entry like:
		put_line("-- addresses control cells which statically disable drivers");
		put_line("-- example 1: class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0");
		--put_line("-- example 2: class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to enable_value 0");
		put_line("-- example 2: class PD secondary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0");
-- 		while c /= null loop
		for cc in 1..length(list_of_static_control_cells_class_PX) loop
			c := element(list_of_static_control_cells_class_PX, positive(cc));
			put(" class " & type_net_class'image(c.class) & row_separator_0 & to_lower(type_net_level'image(c.level)) & "_net"
				& row_separator_0 & to_string(c.net) & " device"
				& row_separator_0 & to_string(c.device) & " pin"
				& row_separator_0 & to_string(c.pin) & " control_cell" & natural'image(c.id)
				& " locked_to ");
			put_line("disable_value " & type_bit_char_class_0'image(c.disable_value)(2)); -- strip "'" delimiters
-- 			c := c.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section locked_output_cells_in_class_PU_PD_nets");
		put_line(section_mark.section & row_separator_0 & section_static_output_cells_class_PX);
		-- writes a cell list entry like:
		put_line("-- addresses output cells which drive statically");
		put_line("-- example 1 : class PU primary_net /SYS_RESET device IC300 pin 39 output_cell 37 locked_to drive_value 0");
		put_line("-- example 2 : class PD primary_net SHUTDOWN device IC300 pin 4 output_cell 375 locked_to drive_value 1");
-- 		while d /= null loop
		for cc in 1..length(list_of_static_output_cells_class_PX) loop
			d := element(list_of_static_output_cells_class_PX, positive(cc));
			put_line(" class " & type_net_class'image(d.class) & " primary_net"
				& row_separator_0 & to_string(d.net) & " device"
				& row_separator_0 & to_string(d.device) & " pin"
				& row_separator_0 & to_string(d.pin) & " output_cell" & natural'image(d.id)
				& " locked_to drive_value " & type_bit_char_class_0'image(d.drive_value)(2));
-- 			d := d.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section locked_output_cells_in_class_DH_DL_nets");
		put_line(section_mark.section & row_separator_0 & section_static_output_cells_class_DX_NR);
		-- writes a cell list entry like:
		put_line("-- addresses output cells which drive statically");
		put_line("-- example 1 : class DL primary_net /CPU_MREQ device IC300 pin 28 output_cell 13 locked_to drive_value 0");
		put_line("-- example 2 : class DH primary_net /CPU_RD device IC300 pin 27 output_cell 10 locked_to drive_value 1");
		put_line("-- NOTE:   1 : Output cells of disabled driver pins may appear here. Don't care.");
-- 		while e /= null loop
		for cc in 1..length(list_of_static_output_cells_class_DX_NR) loop
			e := element(list_of_static_output_cells_class_DX_NR, positive(cc));
			put_line(" class " & type_net_class'image(e.class) & " primary_net"
				& row_separator_0 & to_string(e.net) & " device"
				& row_separator_0 & to_string(e.device) & " pin"
				& row_separator_0 & to_string(e.pin) & " output_cell" & natural'image(e.id)
				& " locked_to drive_value " & type_bit_char_class_0'image(e.drive_value)(2));
-- 			e := e.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section static_expect");
		put_line(section_mark.section & row_separator_0 & section_static_expect);
		-- writes a cell list entry like:
		put_line("-- addresses input cells which expect statically");
		put_line("-- example 1 : class DL primary_net /CPU_MREQ device IC300 pin 28 input_cell 14 expect_value 0");
		put_line("-- example 2 : class DH secondary_net MREQ device IC300 pin 28 input_cell 14 expect_value 1 primary_net_is MR45");
		for cc in 1..length(list_of_static_expect_cells) loop
			put(" class " & type_net_class'image(
					element(list_of_static_expect_cells, positive(cc)).class) 
				& row_separator_0 & to_lower(type_net_level'image(
					element(list_of_static_expect_cells, positive(cc)).level)) & "_net"
				& row_separator_0 & to_string(
					element(list_of_static_expect_cells, positive(cc)).net) & " device"
				& row_separator_0 & to_string(
					element(list_of_static_expect_cells, positive(cc)).device) & " pin"
				& row_separator_0 & to_string(
					element(list_of_static_expect_cells, positive(cc)).pin) 
				& " input_cell" & natural'image(
					element(list_of_static_expect_cells, positive(cc)).id)
				& " expect_value " & type_bit_char_class_0'image(
					element(list_of_static_expect_cells, positive(cc)).expect_value)(2)); -- strip "'" delimiters
			if element(list_of_static_expect_cells, positive(cc)).level = secondary then
				put_line(" primary_net_is " & to_string(
					element(list_of_static_expect_cells, positive(cc)).primary_net_is));
			else new_line;
			end if;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section atg_expect");
		put_line(section_mark.section & row_separator_0 & section_atg_expect);
		-- writes a cell list entry like:
		put_line("-- addresses input cells which expect values defined by ATG");
		put_line("-- example 1 : class PU secondary_net CT_D3 device IC303 pin 19 input_cell 11 primary_net_is D3");
		put_line("-- example 2 : class PU primary_net /CPU_WR device IC300 pin 26 input_cell 8");
		for cc in 1..length(list_of_atg_expect_cells) loop
			put(" class " & type_net_class'image(
					element(list_of_atg_expect_cells, positive(cc)).class) & row_separator_0 
				& to_lower(type_net_level'image(
					element(list_of_atg_expect_cells, positive(cc)).level)) & "_net"
				& row_separator_0 & to_string(
					element(list_of_atg_expect_cells, positive(cc)).net) & " device"
				& row_separator_0 & to_string(
					element(list_of_atg_expect_cells, positive(cc)).device) & " pin"
				& row_separator_0 & to_string(
					element(list_of_atg_expect_cells, positive(cc)).pin) 
				& " input_cell" & natural'image(
					element(list_of_atg_expect_cells, positive(cc)).id));
			case element(list_of_atg_expect_cells, positive(cc)).level is
				when secondary =>
					put_line(" primary_net_is " & to_string(
						element(list_of_atg_expect_cells, positive(cc)).primary_net_is));
				when primary =>
					new_line;
			end case;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section atg_drive");
		put_line(section_mark.section & row_separator_0 & section_atg_drive);
		-- writes a cell list entry like:
		put_line("-- addresses output and control cells which drive values defined by ATG");
		put_line("-- example 1 : class NR primary_net LED7 device IC303 pin 2 output_cell 7");
		put_line("-- example 2 : class PU primary_net /CPU_WR device IC300 pin 26 control_cell 6 inverted yes");
		put_line("-- example 3 : class PD primary_net /DRV_EN device IC301 pin 27 control_cell 9 inverted no");
		for cc in 1..length(list_of_atg_drive_cells) loop
			put(" class " & type_net_class'image(
					element(list_of_atg_drive_cells, positive(cc)).class) & " primary_net"
				& row_separator_0 & to_string(
					element(list_of_atg_drive_cells, positive(cc)).net) & " device"
				& row_separator_0 & to_string(
					element(list_of_atg_drive_cells, positive(cc)).device) & " pin"
				& row_separator_0 & to_string(
					element(list_of_atg_drive_cells, positive(cc)).pin));
			case element(list_of_atg_drive_cells, positive(cc)).controlled_by_control_cell is
				when true =>
					put(" control_cell" & natural'image(
						element(list_of_atg_drive_cells, positive(cc)).id) & " inverted ");
					if element(list_of_atg_drive_cells, positive(cc)).inverted then
						put_line("yes");
					else
						put_line("no");
					end if;
				when false =>
					put_line(" output_cell"  & natural'image(
						element(list_of_atg_drive_cells, positive(cc)).id));
			end case;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section input_cells_in_class_NA_nets");
		put_line(section_mark.section & row_separator_0 & section_input_cells_class_NA);
		-- writes a cell list entry like:
		put_line("-- addresses input cells");
		put_line("-- example 1 : class NA primary_net OSC_OUT device IC301 pin 6 input_cell 95");
		put_line("-- example 2 : class NA secondary_net LED0_R device IC301 pin 2 input_cell 107 primary_net_is LED0");
		for cc in 1..length(list_of_input_cells_class_NA) loop
			put(" class NA " & to_lower(type_net_level'image(
					element(list_of_input_cells_class_NA, positive(cc)).level)) & "_net"
				& row_separator_0 & to_string(
					element(list_of_input_cells_class_NA, positive(cc)).net) & " device"
				& row_separator_0 & to_string(
					element(list_of_input_cells_class_NA, positive(cc)).device) & " pin"
				& row_separator_0 & to_string(
					element(list_of_input_cells_class_NA, positive(cc)).pin) 
				& " input_cell" & natural'image(
					element(list_of_input_cells_class_NA, positive(cc)).id));
			case element(list_of_input_cells_class_NA, positive(cc)).level is
				when secondary =>
					put_line(" primary_net_is " & to_string(
						element(list_of_input_cells_class_NA, positive(cc)).primary_net_is));
				when primary =>
					new_line;
			end case;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line(column_separator_0);
	end write_new_cell_lists;


	procedure write_new_statistics is -- CS: use predefined statistics_indentifiers_xxx here
	-- Dumps net count statistics in preliminary database.
	-- Calculates number of ATG drivers and receivers and dumps them also.
	begin
		write_message (
			file_handle => file_chkpsn_messages,
	-- 		identation => 1,
			text => "writing statistics ...",
			console => true);
		
		put_line("------- STATISTICS ----------------------------------------------------------");
		new_line;
		put_line(section_mark.section & row_separator_0 & "statistics");
		put_line("---------------------------------------------------");
		net_count_statistics.atg_drivers := natural(length(list_of_atg_drive_cells));
		put_line(" ATG-drivers   (dynamic) :" & natural'image(net_count_statistics.atg_drivers));
		net_count_statistics.atg_receivers := natural(length(list_of_atg_expect_cells));
 		put_line(" ATG-receivers (dynamic) :" & natural'image(net_count_statistics.atg_receivers));
		put_line("---------------------------------------------------");
		put_line(" Pull-Up nets        (PU):" & natural'image(net_count_statistics.pu));
 		put_line(" Pull-Down nets      (PD):" & natural'image(net_count_statistics.pd));
 		put_line(" Drive-High nets     (DH):" & natural'image(net_count_statistics.dh));
 		put_line(" Drive-Low nets      (DL):" & natural'image(net_count_statistics.dl));
 		put_line(" Expect-High nets    (EH):" & natural'image(net_count_statistics.eh));
 		put_line(" Expect-Low nets     (EL):" & natural'image(net_count_statistics.el));
 		put_line(" unrestricted nets   (NR):" & natural'image(net_count_statistics.nr));
 		put_line(" not classified nets (NA):" & natural'image(net_count_statistics.na));
		put_line("---------------------------------------------------");
 		put_line(" total                   :" & natural'image(net_count_statistics.total));
		put_line("--------------------------------------------------");
 		put_line(" bs-nets static          :" & natural'image(net_count_statistics.bs_static));
 		put_line(" thereof :");
		put_line("   bs-nets static H      :" & natural'image(net_count_statistics.bs_static_h));
   		put_line("   bs-nets static L      :" & natural'image(net_count_statistics.bs_static_l));	
 		put_line(" bs-nets dynamic         :" & natural'image(net_count_statistics.bs_dynamic));
 		put_line(" bs-nets testable        :" & natural'image(net_count_statistics.bs_testable));
		put_line("---------------------------------------------------");
		put_line(section_mark.endsection);
	end write_new_statistics;


	procedure read_options_file is
	-- read options file
	-- Check if primary net incl. secondary nets may change class as specified in options file
	-- if class rendering allowed, add primary net with its secondary nets to options netlist.
	-- This is achieved at by procedure add_to_options_net_list
	-- list_of_options_nets is the generated options netlist
		line_of_file						: type_universal_string.bounded_string;
		line_counter 						: natural := 0;
		line_number_of_primary_net_header	: natural := 0;
		secondary_net_count					: natural := 0;	

		primary_net_section_entered			: boolean := false;		
		secondary_net_section_entered 		: boolean := false;			
		name_of_current_primary_net			: type_net_name.bounded_string;
		class_of_current_primary_net		: type_net_class := net_class_default;

	begin
		-- open options file
		prog_position := 70;
		open( 
			file => file_options,
			mode => in_file,
			name => to_string(name_file_options)
			);

		prog_position := 60;

		write_message (
			file_handle => file_chkpsn_messages,
-- 			identation => 2,
			text => "reading options file ...",
			console => true);

		set_input(file_options); -- set data source
		while not end_of_file
			loop
				line_counter := line_counter + 1;
				line_of_file := to_bounded_string(remove_comment_from_line(get_line));

				if get_field_count(to_string(line_of_file)) > 0 then -- if line contains anything

-- 					write_message (
-- 						file_handle => file_chkpsn_messages,
-- 						identation => 1,
-- 						text => to_string(line_of_file),
-- 						console => true);

					if primary_net_section_entered then
						-- we are inside primary net section

						if secondary_net_section_entered then
							-- we are inside secondary net section

							-- wait for end of secondary net section mark
							if get_field_from_line(to_string(line_of_file),1) = section_mark.endsubsection then
								secondary_net_section_entered := false;
								if secondary_net_count = 0 then
									put_line(message_warning & "Primary net '" & to_string(name_of_current_primary_net) 
										& "' has an empty secondary net subsection !");
								end if;

							-- count secondary nets and collect them in array list_of_secondary_net_names
							--if to_upper(get_field_from_line(line_of_file,1)) = type_options_net_identifier'image(net) then
							elsif get_field_from_line(to_string(line_of_file),1) = options_keyword_net then
								secondary_net_count := secondary_net_count + 1;
								--list_of_secondary_net_names(secondary_net_count) := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
								append(list_of_secondary_net_names_preliminary, to_bounded_string(get_field_from_line(to_string(line_of_file),2)));
							else
								put_line(message_error & "Keyword '" & options_keyword_net & "' or '"
									& section_mark.endsubsection & "' expected !");
								raise constraint_error;
							end if;
						else
							-- wait for end of primary net section
							if get_field_from_line(to_string(line_of_file),1) = section_mark.endsection then
								primary_net_section_entered := false;

	-- 							-- when end of primary net section reached:
	-- 							if debug_level >= 10 then
	-- 								new_line;
	-- 								put_line("primary net name    : " & extended_string.to_string(name_of_current_primary_net));
	-- 								put_line("primary net class   : " & type_net_class'image(class_of_current_primary_net));
	-- 								if secondary_net_count > 0 then
	-- 									put_line("secondary net count :" & natural'image(secondary_net_count));
	-- 									put("secondary nets      : ");
	-- 									for s in 1..secondary_net_count loop
	-- 										put(universal_string_type.to_string(list_of_secondary_net_names(s)) & row_separator_0);
	-- 									end loop;
	-- 									new_line;
	-- 								end if;
								-- 							end if;

								write_message (
									file_handle => file_chkpsn_messages,
									identation => 2,
									-- 									text => "changing net class to " & type_net_class'image(class_of_current_primary_net) & " ...",
									text => "changing net class ...",
									console => false);

								-- Ask if the primary net (incl. secondary nets) may become member of class specified in options file.
								-- If class request can be fulfilled, add net to options net list.
								if query_render_net_class ( -- CS: skip query if class is not to be changed ?
									--primary_net_name => name_of_current_primary_net,
									primary_net_cursor => find(list_of_nets, name_of_current_primary_net),
									primary_net_class => class_of_current_primary_net,
									list_of_secondary_net_names	=> list_of_secondary_net_names_preliminary
	-- 								secondary_net_count	=> secondary_net_count
									) then 
										add_to_options_net_list(
											name				=> name_of_current_primary_net,
											class				=> class_of_current_primary_net,
											line_number			=> line_number_of_primary_net_header,
											secondary_net_names	=> list_of_secondary_net_names_preliminary
										);
										
								end if;
								secondary_net_count := 0; -- reset secondary net counter for next primary net

								-- purge list_of_secondary_net_names for next spin
								list_of_secondary_net_names_preliminary := empty_list_of_secondary_net_names;

							-- if not secondary_net_section_entered yet, wait for "SubSection secondary_nets" header
							-- if "SubSection secondary_nets" found, set secondary_net_section_entered flag
							elsif get_field_from_line(to_string(line_of_file),1) = section_mark.subsection and
								get_field_from_line(to_string(line_of_file),2) = options_keyword_secondary_nets then
									secondary_net_section_entered := true;
							else
								put_line(message_error & "Keywords '" & section_mark.subsection 
									& " " & options_keyword_secondary_nets
									& "' or '" & section_mark.endsection
									& "' expected !");
								raise constraint_error;
							end if;
						end if;

					-- if primary net section not entered, wait for primary net header like "Section LED0 class NR", 
					-- then set "primary net section entered" flag
					elsif get_field_from_line(to_string(line_of_file),1) = section_mark.section then
						name_of_current_primary_net := to_bounded_string(get_field_from_line(to_string(line_of_file),2));
						if get_field_from_line(to_string(line_of_file),3) = netlist_keyword_header_class then
							class_of_current_primary_net := type_net_class'value(get_field_from_line(to_string(line_of_file),4));

							write_message (
								file_handle => file_chkpsn_messages,
								identation => 1,
								text => "primary net " & to_string(name_of_current_primary_net) & row_separator_0 &
									"class requested " & type_net_class'image(class_of_current_primary_net),
								console => false);

						else
							put_line(message_error & "Keyword '" & netlist_keyword_header_class 
								& "' expected after primary net name '"
								& to_string(name_of_current_primary_net) & "' !");
							raise constraint_error;
						end if;

						primary_net_section_entered := true;
						line_number_of_primary_net_header := line_counter; -- backup line number of net header
						-- when adding the net to the net list, this number goes into the list as well
					else
						put_line(message_error & "Keyword '" & section_mark.section & "' expected !");
						raise constraint_error;
					end if;

				end if;

			end loop;

		prog_position := 70;		
		set_input(standard_input);
		prog_position := 80;	
		close(file_options);
	end read_options_file;

	procedure copy_scanpath_configuration_and_registers is
		line_counter : natural := 0;
	begin	
		write_message (
			file_handle => file_chkpsn_messages,
			text => "rebuilding preliminary " & text_identifier_database & " ...", 
			console => true);

		write_message (
			file_handle => file_chkpsn_messages,
			identation => 1,
			text => "copying scanpath configuration and registers ...", 
			console => false);
		
		open(file => file_database, mode => in_file, name => to_string(name_file_database));

		-- Copy line per line from current database to preliminary database until 
		-- last line of section "registers" reached.

		-- Data source is current database. Data sink is preliminary database.
		while not end_of_file(file_database) loop
			line_counter := line_counter + 1;
			put_line(get_line(file_database));
			if line_counter = summary.line_number_end_of_section_registers then
				exit;
			end if;
		end loop;

		close(file_database); -- we no longer need the old database file
	end copy_scanpath_configuration_and_registers;

	procedure write_section_netlist_header is
	begin
		write_message (
			file_handle => file_chkpsn_messages,
			identation => 1,
			text => "writing netlist header ...", 
			console => false);

		new_line;
		put_line(section_mark.section & row_separator_0 & section_netlist);
		put_line(column_separator_0);
		put_line("-- modified by " & name_module_chkpsn & " version " & version);
		put_line("-- date " & date_now); 
-- 		put_line("-- number of nets" & count_type'image(length(netlist)));
		new_line;
	end write_section_netlist_header;
	
	
-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := chkpsn;

	-- create message/log file
 	write_log_header(version);
	
	put_line(to_upper(name_module_chkpsn) & " version " & version);
	put_line("=======================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages
	
	prog_position := 10;
	name_file_database := to_bounded_string(argument(1));

	write_message (
		file_handle => file_chkpsn_messages,
		text => text_identifier_database & row_separator_0 & to_string(name_file_database),
		console => true);
	
	name_file_database_backup := name_file_database; -- backup name of database. 
	-- used for overwriting database with preliminary database

	prog_position := 20;
	name_file_options := to_bounded_string(argument(2));
	write_message (
		file_handle => file_chkpsn_messages,
		text => "options file " & to_string(name_file_options),
		console => true);
	
	prog_position := 30;
	create_temp_directory;
	
	prog_position := 50;
	degree_of_database_integrity_check := light;
	read_uut_database;

	put_line("start checking primary/secondary nets ...");

	-- read options file
	prog_position := 60;
	read_options_file;
	-- options netlist ready in list_of_options_nets. 
	-- database netlist ready in list_of_nets.

	-- create premilinary data base (contining scanpath_configuration and registers)	
	prog_position := 70;
	write_message (
		file_handle => file_chkpsn_messages,
		text => "creating preliminary " & text_identifier_database 
			& row_separator_0 & name_file_database_preliminary & " ...",
		console => false);

	create( 
		file => file_database_preliminary,
		mode => out_file,
		name => name_file_database_preliminary
		);

	prog_position := 80;
	-- From now on, all messages go into file_chkpsn_messages. 
	-- Regular puts go into file_database_preliminary.
	set_output(file_database_preliminary); -- set data sink

	prog_position := 120;
	copy_scanpath_configuration_and_registers;
	
	prog_position := 130;	
	write_section_netlist_header;

	-- With the two netlists list_of_nets and list_of_options_nets, a new net list is created and appended to the
	-- preliminary data base.
	-- The class requirements and secondary net dependencies from the options file are taken into account.
	prog_position := 140;	
	make_new_netlist;

	-- write section netlist footer	
	put_line(section_mark.endsection);
	new_line(2);

	prog_position := 150;	
	write_new_cell_lists;

	prog_position := 160;
	write_new_statistics;	
	
	write_message (
		file_handle => file_chkpsn_messages,
		text => "closing preliminary " & text_identifier_database & " ...",
		console => false);
	close(file_database_preliminary);
	direct_messages; -- restore output channel for external procedures and functions


	

-- 	-- check preliminary database and obtain summary
-- 	prog_position := 170;	
-- 	write_message (
-- 		file_handle => file_chkpsn_messages,
-- 		text => "parsing preliminary " & text_identifier_database & " ...",
-- 		console => false);
-- 
-- 	-- set preliminary database as default
-- 	name_file_database := to_bounded_string(name_file_database_preliminary);
-- 	degree_of_database_integrity_check := light;
-- 	read_uut_database;
-- 	-- summary now available



	
	-- reopen preliminary database in append mode
-- 	prog_position := 175;		
-- 	write_message (
-- 		file_handle => file_chkpsn_messages,
-- 		text => "reopening preliminary " & text_identifier_database 
-- 			& row_separator_0 & to_string(name_file_database) & " ...",
-- 		console => false);
-- 
-- 	prog_position := 180;	
-- 	open( 
-- 		file => file_database_preliminary,
-- 		mode => append_file,
-- 		name => to_string(name_file_database)
-- 		);
-- 	prog_position := 190;	
-- 	set_output(file_database_preliminary);
-- 	write_new_statistics;
-- 	close(file_database_preliminary);
	
	-- overwrite now useless old data base with temporarily data base
	prog_position := 200;
	write_message (
		file_handle => file_chkpsn_messages,
		text => "copying preliminary " & text_identifier_database & " to " & to_string(name_file_database_backup),
		console => false);
 	copy_file(name_file_database_preliminary, to_string(name_file_database_backup));
	
	prog_position := 210;
	write_log_footer;
	
	exception when event: others =>
		set_exit_status(failure);

		write_message (
			file_handle => file_chkpsn_messages,
			text => message_error & "at program position " & natural'image(prog_position),
			console => true);
	
		if is_open(file_database_preliminary) then
			close(file_database_preliminary);
		end if;

		case prog_position is
			when 10 =>
				write_message (
					file_handle => file_chkpsn_messages,
					text => message_error & text_identifier_database & " file missing or insufficient access rights !",
					console => true);

				write_message (
					file_handle => file_chkpsn_messages,
					text => "       Provide " & text_identifier_database & " name as argument. Example: chkpsn my_uut.udb",
					console => true);

			when 20 =>
				write_message (
					file_handle => file_chkpsn_messages,
					text => "Options file missing or insufficient access rights !",
					console => true);

				write_message (
					file_handle => file_chkpsn_messages,
					text => "       Provide options file as argument. Example: chkpsn my_uut.udb my_options.opt",
					console => true);

			when others =>
				write_message (
					file_handle => file_chkpsn_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_chkpsn_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;
end chkpsn;
