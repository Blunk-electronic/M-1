------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKMEMCON                            --
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

		with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Ada.Text_IO;				use Ada.Text_IO;
with Ada.Integer_Text_IO;		use Ada.Integer_Text_IO;
with Ada.Characters.Handling; 	use Ada.Characters.Handling;

with Ada.Strings; 				use Ada.Strings;
with Ada.Strings.Bounded; 		use Ada.Strings.Bounded;
with Ada.Strings.fixed; 		use Ada.Strings.fixed;
with Ada.Exceptions; 			use Ada.Exceptions;
 
with Ada.Command_Line;			use Ada.Command_Line;
with Ada.Directories;			use Ada.Directories;

with m1;
with m1_internal; use m1_internal;



procedure mkmemcon is

	version			: String (1..3) := "032";
	prog_position	: natural := 0;
	type type_algorithm is ( standard );
	algorithm 		: type_algorithm;
	line_counter 	: natural := 0; -- counts lines in model file

	type type_section_name is
		record
			info			: string (1..4)  := "info";
			port_pin_map	: string (1..12) := "port_pin_map";
			prog			: string (1..4)  := "prog";
		end record;
	section_name : type_section_name;

	type type_prog_subsection_name is
		record
			init		: string (1..4)		:= "init";
			write		: string (1..5)		:= "write";
			read		: string (1..4)		:= "read";
			disable		: string (1..7)		:= "disable";
		end record;
	prog_subsection_name : type_prog_subsection_name;

	type type_prog_identifier is
		record
			step		: string (1..4)		:= "step";
			addr		: string (1..4)		:= "addr";
			data		: string (1..4)		:= "data";
			ctrl		: string (1..4)		:= "ctrl";
			drive		: string (1..5)		:= "drive";
			expect		: string (1..6)		:= "expect";
			atg			: string (1..3)		:= "atg";
			highz		: string (1..5)		:= "highz";
			dely		: string (1..5)		:= "delay";
		end record;
	prog_identifier : type_prog_identifier;

	type type_model_section_entered is
		record
			info			: boolean := false;
			port_pin_map	: boolean := false;
			prog		 	: boolean := false;
		end record;
	model_section_entered : type_model_section_entered;

	type type_model_section_processed is
		record
			info			: boolean := false;
			port_pin_map	: boolean := false;
			prog		 	: boolean := false;
		end record;
	model_section_processed : type_model_section_processed;

	type type_prog_subsection_entered is
		record
			init			: boolean := false;
			write 			: boolean := false;
			read  			: boolean := false;
			disable			: boolean := false;
		end record;
	prog_subsection_entered : type_prog_subsection_entered;

	type type_prog_subsection_processed is
		record
			init			: boolean := false;
			write 			: boolean := false;
			read  			: boolean := false;
			disable			: boolean := false;
		end record;
	prog_subsection_processed : type_prog_subsection_processed;




	type type_port_pin_map_identifier is
		record
			data		: string (1..4) := "data";
			address		: string (1..7) := "address";
			control		: string (1..7) := "control";
			input		: string (1..2) := "in";
			output		: string (1..3) := "out";
			inout		: string (1..5) := "inout";
			option		: string (1..6) := "option";
			min			: string (1..3) := "min";
			max			: string (1..3) := "max";
		end record;
	port_pin_map_identifier : type_port_pin_map_identifier;

	-- items to be found in section "info" of memory model
	type type_info_item is
		record
			value			: string (1..5)  := "value";
			compatibles		: string (1..11) := "compatibles";
			date			: string (1..4)  := "date";
			version			: string (1..7)  := "version";
			status			: string (1..6)  := "status";
			author			: string (1..6)  := "author";
			manufacturer	: string (1..12) := "manufacturer";
			class			: string (1..5)  := "class";
			write_protect	: string (1..13) := "write_protect";
			protocol		: string (1..8)  := "protocol";
			ram_type		: string (1..8)  := "ram_type";
			rom_type		: string (1..8)  := "rom_type";
		end record;
	info_item : type_info_item;

	type type_model_status is ( experimental, verified );
	type type_target_class is ( UNKNOWN, ROM, RAM, CLUSTER );
	type type_type_ram is ( UNKNOWN, SRAM, SDRAM, DRAM, DDR, DDR2 );
	type type_type_rom is ( UNKNOWN, MAP, OTP, FLASH );
	type type_protocol is ( UNKNOWN, PARALLEL, I2C, SPI );
	type type_write_protect	is new boolean;

	--type type_option_address is ( none, address_min, address_max );
	subtype type_option_address_min is integer range -1..integer'last; -- -1 if option not given
	subtype type_option_address_max is integer range -1..integer'last; -- -1 if option not given

	-- global variables to count address, data and control pins
	-- on leaving secion port_pin_map they are copied into the target
	scratch_width_address	: natural := 0;
	scratch_width_data		: natural := 0;
	scratch_width_control	: natural := 0;

	type type_target;
	type type_ptr_target is access all type_target;
	type type_target (class_target : type_target_class := ram) is
		record
			date			: universal_string_type.bounded_string;
			author			: universal_string_type.bounded_string;
			status			: type_model_status;
			version			: universal_string_type.bounded_string;
			device_name		: universal_string_type.bounded_string; -- like IC202
			data_base		: universal_string_type.bounded_string;
			test_name		: universal_string_type.bounded_string; -- like my_sram_test
			model_file		: universal_string_type.bounded_string; -- like models/U256D.txt

			-- values that hold the number of address, data, control pins
			-- serves to indicate whether target has address, data or control pins
			width_address	: natural;
			width_data		: natural;
			width_control	: natural;
		
			option_address_min	: type_option_address_min;
			option_address_max	: type_option_address_max;

			case class_target is
				when RAM | ROM =>
					value			: universal_string_type.bounded_string;
					compatibles		: universal_string_type.bounded_string;
					manufacturer	: universal_string_type.bounded_string;
					device_package	: universal_string_type.bounded_string;
					protocol 		: type_protocol;
					algorithm		: type_algorithm;
					write_protect	: type_write_protect;
					case class_target is
						when RAM => 
							ram_type		: type_type_ram;
						when ROM =>
							rom_type		: type_type_rom;
						when others => null;
					end case;
				when CLUSTER =>
					null;
				when others =>
					null;
			end case;
		end record;
	ptr_target : type_ptr_target;

	-- type definition of a single pin
	-- The object of type type_pin will be added to a list later
	-- and accessed by pointer ptr_pin.
	type type_memory_pin;
	type type_ptr_memory_pin is access all type_memory_pin;
	type type_pin_class is ( data, address, control);
	type type_direction is ( input, output, inout);
	type type_memory_pin (class_pin : type_pin_class) is
		record
			next			: type_ptr_memory_pin;
			name_pin		: universal_string_type.bounded_string; -- like pin 75, 34, 4
			name_port		: universal_string_type.bounded_string; -- like port A13, SDA, D15
			name_net 		: universal_string_type.bounded_string; -- the net it is connected with like CPU_WE
			direction		: type_direction;
			-- indexing is required for address or data ports only
			case class_pin is
				when data | address =>
					index		: natural; -- like address 0, data 7
				when others => -- like CE, WE
					null;
			end case;
		end record;
	ptr_memory_pin	: type_ptr_memory_pin;

	invalid_value	: boolean := false; -- used to warn operator about value given in model differing from value found in net list 
										-- set by function get_connected_net
	invalid_package	: boolean := false; -- used to warn operator about package given in model differing from package found in net list 
										-- set by function get_connected_net

	procedure add_to_pin_list(
	-- adds a port and its pin name to pin list: 
	-- example 1: port D5 maps to pin 17 ( taken from -- vector inout D[7:0] 19 18 17 16 15 13 12 11)
	-- example 2: port WE maps to pin 27 ( taken from -- control in WE 	27)
		list				: in out type_ptr_memory_pin;
		pin_class_given		: in type_pin_class;
		name_pin_given		: in universal_string_type.bounded_string;
		name_port_given		: in universal_string_type.bounded_string;
		direction_given		: in type_direction;
		index_given			: in natural := 0 -- default in case it is not required. 
											-- single port names do not have an index (like CE)
		) is

		procedure check_if_pin_already_in_list is
		-- searches name_pin_given and name_port_given in pin list (accessed by ptr_memory_pin)
		-- if pin or port already used, abort
			p	: type_ptr_memory_pin := ptr_memory_pin;
		begin
			while p /= null loop -- loop through pin list

				-- CHECK OCCURENCE OF PORT NAME
				--  on port name match
				if universal_string_type.to_string(p.name_port) = universal_string_type.to_string(name_port_given) then

					-- if data or address port, check index
					if p.class_pin = data or p.class_pin = address then
						if p.index = index_given then -- on index match
							put_line("ERROR: Port '" 
								& universal_string_type.to_string(name_port_given)
								& trim(natural'image(index_given),left)
								& "' already used !");
							raise constraint_error;
						end if;
					else -- other ports like "control" do not have any indexes, so it is sufficient to have the port name checked
						put_line("ERROR: Port '" 
							& universal_string_type.to_string(name_port_given)
							& "' already used !");
						raise constraint_error;
					end if;
				end if;

				-- CHECK OCCURENCE OF PIN NAME
				--  on pin name match
				if universal_string_type.to_string(p.name_pin) = universal_string_type.to_string(name_pin_given) then
					put_line("ERROR: Pin '" & universal_string_type.to_string(name_pin_given) & "' already used !");
					raise constraint_error;
				end if;

				p := p.next; -- advance to next pin
			end loop;
			-- if this point is reached, the pin is not used already -> fine
		end check_if_pin_already_in_list;

		function get_connected_net return universal_string_type.bounded_string is
		-- from object "target" (created after processing section "info"), accessed by ptr_target we
		-- get the device name, value and package (ptr_target.device_name, ptr_target.device_value and ptr_target.device_package)
		-- now the net list (from data base) is searched for a net that contains the target device with name_pin_given
			n			: type_net_ptr := ptr_net;
			net_name	: universal_string_type.bounded_string;
			net_found	: boolean := false; -- indicates whether a net has been found
		begin
			loop_through_net_list:
			while n /= null loop
				for p in 1..n.part_ct loop -- loop through pins of net pointed to by n

					-- to speed up the process, only non-scan pins are adressed
					if not n.pin(p).is_bscan_capable then

						-- on device name match
						if universal_string_type.to_string(n.pin(p).device_name) = universal_string_type.to_string(ptr_target.device_name) then

							-- on pin name match, the net connected to the given pin has been found
							if universal_string_type.to_string(n.pin(p).device_pin_name) = universal_string_type.to_string(name_pin_given) then
								net_name := n.name; -- save net name
								if debug_level >= 100 then
									put_line("net : " & universal_string_type.to_string(n.name));
								end if;

								-- do a net class check in connection with pin direction
								case n.class is
									-- class NA | EL | EH nets can not be used to drive data into the target
									when NA | EL | EH =>
										case direction_given is
											when input =>
												put("ERROR: Input pin '" & universal_string_type.to_string(name_pin_given)
													& "' port '" & universal_string_type.to_string(name_port_given));
												if pin_class_given /= control then
													put(trim(natural'image(index_given),left));
												end if;
												put_line("' of '" & universal_string_type.to_string(ptr_target.device_name) 
													& "' is connected to net '"
													& universal_string_type.to_string(net_name) & "' which is in class '" 
													& type_net_class'image(n.class) & "' !");
												put_line("       In nets of this class, no drivers become active !");
												raise constraint_error;
											when inout =>
												put("WARNING: Bidir pin '" & universal_string_type.to_string(name_pin_given)
													& "' port '" & universal_string_type.to_string(name_port_given));
												if pin_class_given /= control then
													put(trim(natural'image(index_given),left));
												end if;
												put_line("' of '" & universal_string_type.to_string(ptr_target.device_name) 
													& "' is connected to net '"
													& universal_string_type.to_string(net_name) & "' which is in class '" 
													& type_net_class'image(n.class) & "' !");
												put_line("         In nets of this class, no drivers become active !");
											when output =>
												null; -- CS: put warning ?
										end case; -- direction_given
									when others => 
										null;
										-- CS: more class checking ?
								end case; -- class

								-- verify value of target, but do this only once
								-- the global flag invalid_value is used to ensure this message comes up only once
								if not invalid_value then
									if universal_string_type.to_string(n.pin(p).device_value) /= universal_string_type.to_string(ptr_target.value) then
										invalid_value := true;
										put_line("WARNING: Target value mismatch !");
										put_line("         value given in model     : " & universal_string_type.to_string(ptr_target.value));
										put_line("         value found in data base : " & universal_string_type.to_string(n.pin(p).device_value));
									end if;
								end if;

								-- verify package, but do this only once
								-- the global flag invalid_package is used to ensure this message comes up only once
								if not invalid_package then
									if universal_string_type.to_string(n.pin(p).device_package) /= universal_string_type.to_string(ptr_target.device_package) then
										invalid_package := true;
										put_line("WARNING: Target package mismatch !");
										put_line("         package given as parameter : " & universal_string_type.to_string(ptr_target.device_package));
										put_line("         package found in data base : " & universal_string_type.to_string(n.pin(p).device_package));
									end if;
								end if;

								-- now, a connected net has been found
								net_found := true;

								-- abort searching net list here
								exit loop_through_net_list;
							end if; -- on pin name match

						end if; -- on device name match
					end if; -- pin must not be scan capable
				end loop;
				n := n.next; -- advance to next net
			end loop loop_through_net_list;

			-- if net not found after searching the uut net list, abort
			if not net_found then
				put_line("ERROR: Target device '" & universal_string_type.to_string(ptr_target.device_name) & "' not found in data base !");
				put_line("       Make sure device exists or check spelling (case sensitive) !");
				raise constraint_error;
			end if;
			return net_name; -- send net name back
		end get_connected_net;

	begin -- add_to_pin_list
		-- check if pin already in list
		check_if_pin_already_in_list;

		-- in depence of the given pin class, add the given pin to the pin list
		case pin_class_given is
			when data =>
				scratch_width_data := scratch_width_data + 1;
				list := new type_memory_pin'(
					next		=> list,
					class_pin	=> data,
					name_pin	=> name_pin_given,
					name_port	=> name_port_given,
					name_net	=> get_connected_net, -- find connected net
					direction	=> direction_given,
					index		=> index_given
					);
			when address =>
				scratch_width_address := scratch_width_address + 1;
				list := new type_memory_pin'(
					next		=> list,
					class_pin	=> address,
					name_pin	=> name_pin_given,
					name_port	=> name_port_given,
					name_net	=> get_connected_net, -- find connected net
					direction	=> direction_given,
					index		=> index_given
					);
			when control =>
				scratch_width_control := scratch_width_control + 1;
				list := new type_memory_pin'(
					next		=> list,
					class_pin	=> control,
					name_pin	=> name_pin_given,
					name_port	=> name_port_given,
					name_net	=> get_connected_net, -- find connected net
					direction	=> direction_given
					);
		end case;
	end add_to_pin_list;

	-- TYPES AND OBJECTS RELATED TO SECTION "PROG"
	type type_step_operation is ( INIT, WRITE, READ, DISABLE);
	type type_step_direction is ( DRIVE, EXPECT );
	type type_step_group (width : natural := 0) is
		record
			case width is
				when 0 => null;
				when others =>
					direction	: type_step_direction;
					value		: natural := 0; -- CS: limit value to (2**width) -1
					atg			: boolean := false;
					highz		: boolean := false;
			end case;
		end record;

	type type_step;
	type type_ptr_step is access all type_step;
	-- step 1	ADDR	drive FFFF |	DATA drive FF	|	CTRL drive 111
	-- step 4	ADDR	drive ATG	|	DATA drive ATG	|	CTRL drive 010
	type type_step is 
		record
			next			: type_ptr_step;
			operation		: type_step_operation;
			step_id			: positive;
			group_address	: type_step_group;
			group_data		: type_step_group;
			group_control	: type_step_group;
			delay_value		: type_delay_value;
		end record;
	ptr_step : type_ptr_step;


	procedure add_to_step_list(
		list			: in out type_ptr_step;
		operation_given	: type_step_operation;
		step_id_given	: positive;
		group_address_given	: type_step_group;
		group_data_given	: type_step_group;
		group_control_given	: type_step_group;
		delay_value_given	: type_delay_value
		) is
	begin -- add_to_step_list
		-- check if step already in list ?
		list := new type_step'(
			next			=> list,
			operation		=> operation_given,
			step_id			=> step_id_given,
			group_address	=> group_address_given,
			group_data		=> group_data_given,
			group_control	=> group_control_given,
			delay_value		=> delay_value_given
			);
	end add_to_step_list;


	procedure read_memory_model is
	-- reads the given memory model file section by section
	-- the sections are based on each other in the follwing order: info, port_pin_map, prog
	-- if a section is missing, subsequent sections can not be processed
		line_of_file	: extended_string.bounded_string;
		field_count		: natural;

		-- model properties specified in section "info". if a property is missing in sectin "info" a default is used
		scratch_value			: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_compatibles		: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_manufacturer	: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_date			: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_version			: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_status			: type_model_status := experimental;
		scratch_author			: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_protocol 		: type_protocol := unknown;
		scratch_write_protect	: type_write_protect := true; -- safety measure
		scratch_target_class	: type_target_class := unknown;
		scratch_ram_type		: type_type_ram := unknown;
		scratch_rom_type		: type_type_rom := unknown;

		-- model properties specified in section "port_pin_map"
		-- example: data inout D[7:0] 19 18 17 16 15 13 12 11
		-- example: control in OE 22
		scratch_pin_class		: type_pin_class; -- like address, data, control
		scratch_pin_direction	: type_direction; -- like input, output, inout 
		scratch_port_name		: universal_string_type.bounded_string; -- like D or OE
		scratch_port_name_frac	: type_port_vector; -- like [7:0]

		scratch_option_address_min	: type_option_address_min := -1;
		scratch_option_address_max	: type_option_address_max := -1;

		step_counter	: natural := 0;

		procedure get_groups_from_line (operation : type_step_operation) is
		-- extracts address, data, control groups from a line like:
		-- step 1  ADDR  drive ATG  DATA drive HIGHZ  CTRL drive 011
		-- the address group would be: ADDR  drive ATG
		-- the data group would be: DATA drive HIGHZ
		-- the control group would be: CTRL drive 011

		-- creates temporarily objects group_address/data/control with discriminant "width_address/data/control"
		-- "width_address/data/control" is taken from object "target"
		-- those temporarily objects are finally passed to procedure "add_to_step_list" to be added to step list

			field_ct 		: positive;
			field_ct_max	: positive := 11;
			atg_address		: boolean := false;
			atg_data		: boolean := false;
			scratch_value	: natural; -- holds drive/expect value before being range checked

			-- according to bus width taken from object "target", the range for the address/data/control value is set
			-- and used to create a subtype that finally holds the value
			address_max		: natural := (2**ptr_target.width_address)-1;
			data_max		: natural := (2**ptr_target.width_data)-1;	
			control_max		: natural := (2**ptr_target.width_control)-1;
			subtype type_value_address	is natural range 0..address_max;
			subtype type_value_data 	is natural range 0..data_max;
			subtype type_value_control	is natural range 0..control_max;
			value_address	: type_value_address := 0;
			value_data		: type_value_data := 0;
			value_control	: type_value_control := 0;

			-- create temporarily objects group_address/data/control with discriminant "width_address/data/control"
			group_address	: type_step_group(ptr_target.width_address);
			group_data		: type_step_group(ptr_target.width_data);
			group_control	: type_step_group(ptr_target.width_control);

			-- as long as no delay commmand found, the delay defaults to zero
			delay_value		: type_delay_value := 0.0;

		begin
			-- process line like: step 1  ADDR  drive ATG  DATA drive HIGHZ  CTRL drive 011
			-- on match of "step"
			if to_lower(get_field_from_line(line_of_file,1)) = prog_identifier.step then

				-- count steps. the step id found must match step_counter
				step_counter := step_counter + 1; 
				if step_counter = positive'value(get_field_from_line(line_of_file,2)) then

					-- make sure the maximim field count is not exceeded
					field_ct := get_field_count(extended_string.to_string(line_of_file));
					if field_ct > field_ct_max then
						put_line("ERROR: Too many fields in line ! Line must have no more than" & positive'image(field_ct_max) & " fields !");
						put_line("       Example: step 1  ADDR  drive ATG  DATA drive Z  CTRL drive 011");
						raise constraint_error;
					else
					-- if field count ok then
						-- test fields for identifier addr, data or ctrl. 
						-- if no address, data or control ports defined by port_pin_map abort if group specified yet
						-- then read subsequent fields
						for f in 3..field_ct loop

							-- if identifier address found
							if to_lower(get_field_from_line(line_of_file,f)) = prog_identifier.addr then
								if ptr_target.width_address /= 0 then -- if bus width greater zero (means if there are address pins)

									-- get direction (expect, drive) from next field
									group_address.direction := type_step_direction'value(get_field_from_line(line_of_file,f+1));

									-- if direction is "expect" the drivers must be disabled
									if group_address.direction = expect then
										group_address.highz := true;
									end if;

									-- get atg or value field from next field
									if to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.atg then
										group_address.atg := true;

									-- in case of a drive command, highz is allowed like
									-- step 5  ADDR  drive highz  DATA drive 45h  CTRL drive 11b
									-- NOTE: highz applies for the whole group. bitwise assignment not supported yet CS
									elsif group_address.direction = drive and to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.highz then
										group_address.highz := true;
									else
										-- the value might be given as hex, dec or binary number
										scratch_value := string_to_natural(get_field_from_line(line_of_file,f+2));
										if scratch_value in type_value_address then
											group_address.value := string_to_natural(get_field_from_line(line_of_file,f+2));
										else
											put_line("ERROR: Address value must not be greater than" 
												& natural'image(address_max) & " or "
												& natural_to_string(address_max,16) & " !");
											raise constraint_error;
										end if;
									end if;
								else 
									-- if group specified but no address port specified in port_pin_map abort
									put_line("ERROR: Target has no address port as specified in section '" & section_name.port_pin_map & ".");
									put_line("       Thus, no address group allowed in section '" & section_name.prog & "' !");
									raise constraint_error;
								end if;


							elsif -- if identifier data found 
								to_lower(get_field_from_line(line_of_file,f)) = prog_identifier.data then
								if ptr_target.width_data /= 0 then -- if bus width greater zero (means if there are data pins)

									-- get direction (expect, drive) from next field
									group_data.direction := type_step_direction'value(get_field_from_line(line_of_file,f+1));

									-- if direction is "expect" the drivers must be disabled
									if group_data.direction = expect then
										group_data.highz := true;
									end if;

									-- get atg or value field from next field
									if to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.atg then
										group_data.atg := true;

									-- in case of a drive command, highz is allowed like
									-- step 5  ADDR  drive ATG  DATA drive HIGHZ  CTRL drive 11b
									-- NOTE: highz applies for the whole group. bitwise assignment not supported yet CS
									elsif group_data.direction = drive and to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.highz then
										group_data.highz := true;
									else
										-- the value might be given as hex, dec or binary number
										scratch_value := string_to_natural(get_field_from_line(line_of_file,f+2));
										if scratch_value in type_value_address then
											group_data.value := string_to_natural(get_field_from_line(line_of_file,f+2));
										else
											put_line("ERROR: Data value must not be greater than" 
												& natural'image(data_max) & " or "
												& natural_to_string(data_max,16) & " !");
											raise constraint_error;
										end if;
									end if;
								else 
									-- if group specified but no data port specified in port_pin_map abort
									put_line("ERROR: Target has no data port as specified in section '" & section_name.port_pin_map & ".");
									put_line("       Thus, no data group allowed in section '" & section_name.prog & "' !");
									raise constraint_error;
								end if;


							elsif -- if identifier control found
								to_lower(get_field_from_line(line_of_file,f)) = prog_identifier.ctrl then
								if ptr_target.width_control /= 0 then -- if bus width greater zero (means if there are control pins)

									-- get direction (expect, drive) from next field
									group_control.direction := type_step_direction'value(get_field_from_line(line_of_file,f+1));

									-- CS: if direction is "expect" the drivers must be disabled
-- 									if direction_control = expect then
-- 										highz_control := true;
-- 									end if;

									-- get value field from next field
									-- NOTE: ATG not available for control pins (CS: could be useful in the future)
									-- NOTE: HIGHZ not available for control pins (CS: could be useful in the future)
									-- the value might be given as hex, dec or binary number
										scratch_value := string_to_natural(get_field_from_line(line_of_file,f+2));
										if scratch_value in type_value_control then
											group_control.value := string_to_natural(get_field_from_line(line_of_file,f+2));
										else
											put_line("ERROR: Control value must not be greater than " 
												& natural_to_string(control_max,2) & " !");
											raise constraint_error;
										end if;
								else 
									-- if group specified but no control port specified in port_pin_map abort
									put_line("ERROR: Target has no control port as specified in section '" & section_name.port_pin_map & ".");
									put_line("       Thus, no control group allowed in section '" & section_name.prog & "' !");
									raise constraint_error;
								end if;

							elsif -- if identifier delay found (example: step 5 delay 1.5)
								to_lower(get_field_from_line(line_of_file,f)) = prog_identifier.dely then
									delay_value := type_delay_value'value(get_field_from_line(line_of_file,f+1));
									-- CS: refine error output via exception handler
									exit; -- no more reading of fields required

-- 							else -- CS: other commands are ignored, put warning or abort instead
-- 								-- if unknown command
-- 								put_line("ERROR: Invalid command found !");
-- 								raise constraint_error;

							end if; -- if identifier address/data/control found
						end loop;
					end if;
				else -- if step id invalid
					put_line("ERROR: Step ID invalid or already used !");
					raise constraint_error;
				end if;
			end if; -- on match of "step"

			add_to_step_list(
				list				=> ptr_step,
				operation_given		=> operation,
				step_id_given		=> step_counter,
				group_address_given	=> group_address,
				group_data_given	=> group_data,
				group_control_given	=> group_control,
				delay_value_given	=> delay_value	-- if delay non-zero, this step is regarded as delay (address, data, control don't care)
				);
		end get_groups_from_line;

	begin -- read memory model
		put_line("reading memory/module model file ...");

		-- open model file as given via command line argument
		open(
			file => model, 
			name => universal_string_type.to_string(model_file),
			mode => in_file
			);
		set_input(model); -- all input comes from the model file from now on

		while not end_of_file loop -- read model file
			line_counter := line_counter + 1; -- count lines in model file
			line_of_file := extended_string.to_bounded_string(get_line); -- get a line from the model
			line_of_file := remove_comment_from_line(line_of_file); -- remove comment from line

			field_count := get_field_count(extended_string.to_string(line_of_file)); -- get number of fields (separated by space)

			if field_count > 0 then -- if line contains anything useful. empty lines are skipped
				if debug_level >= 110 then
					put_line("line read : ->" & extended_string.to_string(line_of_file) & "<-");
				end if;

				-- SECTION "INFO" RELATED BEGIN
				if model_section_entered.info then

					-- once inside section "info", wait for end of section mark
					if get_field_from_line(line_of_file,1) = section_mark.endsection then -- when endsection found
						model_section_entered.info := false; -- reset section entered flag
						model_section_processed.info := true; -- mark section "info" as processed so that subsequent sections can be read

						-- SECTION "INFO" READING DONE. NOW CHECK FOR MISSING PARAMETERS IN THAT SECTION
						-- (if a parameter has not been specified in "info" section, the default as defined above is still there)
						-- then create object "target" pointed to by pointer ptr_target
	
						-- check if protocl not specified
						if scratch_protocol = unknown then
							put_line("ERROR: Protocol not specified in section info !");
							raise constraint_error;
						end if;

						-- in dependence of the target class check parameters
						prog_position := 1000;
						case scratch_target_class is
							-- a ROM must have write protection enabled/disabled
							when ROM =>
								if scratch_write_protect = false then -- by default this options is enabled (true)
									prog_position := 1010; -- otherwise warn operator
									put_line("WARNING: WRITE PROTECTION DISABLED !");
								end if;
								if scratch_rom_type = unknown then
									prog_position := 1020;
									put_line("ERROR: ROM type not specified in section info !");
									raise constraint_error;
								end if;
							when RAM =>
								if scratch_ram_type = unknown then
									prog_position := 1030;
									put_line("ERROR: RAM type not specified in section info !");
									raise constraint_error;
								end if;
							when CLUSTER => null;
							when UNKNOWN =>
								prog_position := 1040;
								put_line("ERROR: Target class not specified in section info !");
						end case;

						-- create target object pointed to by ptr_target
						-- the object subtype depends on discriminant "class"
						-- variables with prefix "scratch_" are derived from section "info"
						-- others come from parameters given via command line
						prog_position := 1200;
						case scratch_target_class is
							when RAM =>
								prog_position := 1210;
								ptr_target := new type_target'(
									class_target	=> RAM,
									value			=> scratch_value,
									compatibles		=> scratch_compatibles,
									manufacturer	=> scratch_manufacturer,
									data_base		=> data_base,  -- derived from cmd line argument
									test_name		=> test_name, --  derived from cmd line argument
									model_file		=> model_file,  -- derived from cmd line argument
									device_name		=> target_device, -- derived from cmd line argument
									device_package	=> device_package,  -- derived from cmd line argument
									date			=> scratch_date,
									version			=> scratch_version,
									status			=> scratch_status,
									author			=> scratch_author,
									protocol		=> scratch_protocol,
									width_address	=> 0,
									width_data		=> 0,
									width_control	=> 0,
									option_address_min	=> -1,
									option_address_max	=> -1,
									algorithm		=> algorithm, -- currently fixed when collecting command line arguments
									write_protect	=> scratch_write_protect,
									ram_type		=> scratch_ram_type
									);
							when ROM =>
								prog_position := 1220;
								ptr_target := new type_target'(
									class_target	=> ROM,
									value			=> scratch_value,
									compatibles		=> scratch_compatibles,
									manufacturer	=> scratch_manufacturer,
									data_base		=> data_base,  -- derived from cmd line argument
									test_name		=> test_name, --  derived from cmd line argument
									model_file		=> model_file,  -- derived from cmd line argument
									device_name		=> target_device,  -- derived from cmd line argument
									device_package	=> device_package,  -- derived from cmd line argument
									date			=> scratch_date,
									version			=> scratch_version,
									status			=> scratch_status,
									author			=> scratch_author,
									protocol		=> scratch_protocol,
									width_address	=> 0,
									width_data		=> 0,
									width_control	=> 0,
									option_address_min	=> -1,
									option_address_max	=> -1,
									algorithm		=> algorithm, -- currently fixed when collecting command line arguments
									write_protect	=> scratch_write_protect,
									rom_type		=> scratch_rom_type
									);
							when CLUSTER =>
								prog_position := 1230;
								ptr_target := new type_target'(
									class_target	=> CLUSTER,
									data_base		=> data_base,  -- derived from cmd line argument
									test_name		=> test_name, --  derived from cmd line argument
									model_file		=> model_file,  -- derived from cmd line argument
									device_name		=> target_device,  -- derived from cmd line argument
									date			=> scratch_date,
									version			=> scratch_version,
									status			=> scratch_status,
									author			=> scratch_author,
									width_address	=> 0,
									width_data		=> 0,
									width_control	=> 0,
									option_address_min	=> -1,
									option_address_max	=> -1
									);
							when others =>
								prog_position := 1240;
								put_line("ERROR: Target class not specified in section info !");
								raise constraint_error;
						end case;

					else
						-- PROCESSING "INFO" SECTION BEGIN
						-- collect all info items in scratch variables
						-- scratch variables will be used to create an object of type type_targt pointed to by ptr_target
						if debug_level >= 100 then
							put_line("info : ->" & extended_string.to_string(line_of_file) & "<-");
						end if;

						prog_position := 1310;
						if get_field_from_line(line_of_file,1) = info_item.value then
							scratch_value := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1320;
						if get_field_from_line(line_of_file,1) = info_item.compatibles then
							scratch_compatibles := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1330;
						if get_field_from_line(line_of_file,1) = info_item.date then
							scratch_date := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1340;
						if get_field_from_line(line_of_file,1) = info_item.version then
							scratch_version := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1350;
						if get_field_from_line(line_of_file,1) = info_item.status then
							scratch_status := type_model_status'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1360;
						if get_field_from_line(line_of_file,1) = info_item.author then
							scratch_author := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1370;
						if get_field_from_line(line_of_file,1) = info_item.class then
							scratch_target_class := type_target_class'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1380;
						if get_field_from_line(line_of_file,1) = info_item.manufacturer then
							scratch_manufacturer := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1390;
						if get_field_from_line(line_of_file,1) = info_item.write_protect then
							scratch_write_protect := type_write_protect'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1400;
						if get_field_from_line(line_of_file,1) = info_item.protocol then
							scratch_protocol :=type_protocol'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1410;
						if get_field_from_line(line_of_file,1) = info_item.ram_type then
							scratch_ram_type := type_type_ram'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1420;
						if get_field_from_line(line_of_file,1) = info_item.rom_type then
							scratch_rom_type := type_type_rom'value(get_field_from_line(line_of_file,2));
						end if;

					end if;

				else
					-- wait for section "info" begin mark
					if get_field_from_line(line_of_file,1) = section_mark.section then
						if get_field_from_line(line_of_file,2) = section_name.info then
							model_section_entered.info := true; -- set section enterd "flag"
						end if;
					end if;
				end if;
				-- SECTION "INFO" RELATED END


				-- SECTION "PORT_PIN_MAP" RELATED BEGIN
				if model_section_entered.port_pin_map then
					prog_position := 2000;

					-- once inside section "port_pin_map", wait for end of section mark
					if get_field_from_line(line_of_file,1) = section_mark.endsection then
						model_section_entered.port_pin_map := false; -- clear section entered flag
						model_section_processed.port_pin_map := true; -- mark section as processed

						-- update bus width in target object as counted in scratch_widt_address/data/control
						-- if no address, data or control pins counted, the bus with in target object remains zero
						ptr_target.width_address := scratch_width_address;
						ptr_target.width_data := scratch_width_data;
						ptr_target.width_control := scratch_width_control;

						-- update target with address options
						-- if no options found or given default value of -1 is used, to indicate the option is not given
						ptr_target.option_address_min := scratch_option_address_min;
						ptr_target.option_address_max := scratch_option_address_max;

						-- section port_pin_map reading done.
					else
						-- PROCESSING SECTION "PORT_PIN_MAP" BEGIN
						if debug_level >= 100 then
							put_line("port_pin_map : ->" & extended_string.to_string(line_of_file) & "<-");
						end if;

						-- read pin class or option identifier from field 1

						-- example: option address min 8000

						-- if identifier is data, address or control. set scratch_pin_class
						-- example: data inout D[7:0] 19 18 17 16 15 13 12 11
						prog_position := 2100;
						if get_field_from_line(line_of_file,1) = port_pin_map_identifier.data or
							get_field_from_line(line_of_file,1) = port_pin_map_identifier.address or
							get_field_from_line(line_of_file,1) = port_pin_map_identifier.control then
							prog_position := 2110;
							scratch_pin_class := type_pin_class'value(get_field_from_line(line_of_file,1));

							-- read pin direction identifier from field 2
							-- depending on the identifier (input, inout, output) set scratch_pin_direction
							prog_position := 2120;
							if get_field_from_line(line_of_file,2) = port_pin_map_identifier.input or
								get_field_from_line(line_of_file,2) = port_pin_map_identifier.output or
								get_field_from_line(line_of_file,2) = port_pin_map_identifier.inout then
								prog_position := 2130;
								if get_field_from_line(line_of_file,2) = port_pin_map_identifier.input then
									scratch_pin_direction := input;
								elsif get_field_from_line(line_of_file,2) = port_pin_map_identifier.output then
									scratch_pin_direction := output;
								elsif get_field_from_line(line_of_file,2) = port_pin_map_identifier.inout then
									scratch_pin_direction := inout;
								end if;

								-- read port name (like A[14:0]) from field 3
								-- break down port name into name, msb, lsb and length as defined by type type_port_vector
								prog_position := 2140;
								scratch_port_name := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,3));
								prog_position := 2150;
								scratch_port_name_frac := fraction_port_name(universal_string_type.to_string(scratch_port_name));

								if debug_level >= 100 then
									prog_position := 2160;
									put("port: " & universal_string_type.to_string(scratch_port_name_frac.name));
									if scratch_port_name_frac.length > 1 then
										put(" msb" & positive'image(scratch_port_name_frac.msb));
										put(" lsb" & natural'image(scratch_port_name_frac.lsb));
										put(" length" & natural'image(scratch_port_name_frac.length));
									end if;
									new_line;
								end if;

								-- vector length must match number of pins given after port name
								-- example: data inout D[7:0] 19 18 17 16 15 13 12 20 -- 11 fields
								-- vector length is 8, number of pins given is 8
								-- add pin by pin to pin list pointed to by ptr_memory_pin
								prog_position := 2170;
								if scratch_port_name_frac.length = field_count - 3 then
									for p in 4..field_count loop -- start with field 4 (where the first pin name is)
										add_to_pin_list(
											list			=> ptr_memory_pin,
											pin_class_given	=> scratch_pin_class,
											name_pin_given	=> universal_string_type.to_bounded_string(get_field_from_line(line_of_file,p)),
											name_port_given	=> scratch_port_name_frac.name,
											direction_given	=> scratch_pin_direction,
											-- calculate index: example: port D index 7 maps to pin 19. ,  port D index 0 maps to pin 20.
											-- pin names start in field 4
											index_given		=> scratch_port_name_frac.length - 1 - (p - 4)
											);
									end loop; 
									-- all pins have been added to pin list now

								else -- on mismatch of pin numbers and length of port:
									put_line("ERROR: Expected" & positive'image(scratch_port_name_frac.length) & " pin name(s) after port name !");
									raise constraint_error;
								end if;

							end if; -- read pin direction identifier from field 2
						end if; -- if identifier is data, address or control. set scratch_pin_class


						-- read options -- CS: read hex numbers
						-- example: option address min 8000
						prog_position := 2300;
						-- read option identifier
						if get_field_from_line(line_of_file,1) = port_pin_map_identifier.option then
							prog_position := 2310;
							-- read address identifier
							if get_field_from_line(line_of_file,2) = port_pin_map_identifier.address then
								prog_position := 2320;
								-- read min max identifier
								if get_field_from_line(line_of_file,3) = port_pin_map_identifier.min then
									prog_position := 2330;
									scratch_option_address_min := string_to_natural(get_field_from_line(line_of_file,4));

								elsif get_field_from_line(line_of_file,3) = port_pin_map_identifier.max then
									prog_position := 2340;
									scratch_option_address_max := string_to_natural(get_field_from_line(line_of_file,4));

								else
									put_line("ERROR: Expected keyword '" & port_pin_map_identifier.min
										& "' or '" & port_pin_map_identifier.max & "' after option '"
										& port_pin_map_identifier.address & "' !");
									raise constraint_error;
								end if;
							else
								put_line("ERROR: Unknown option ! Supported options are: "
									& port_pin_map_identifier.address);
								raise constraint_error;
							end if;
						end if; -- read option identifier

		
						prog_position := 2500;

					end if;
					-- PROCESSING SECTION "PORT_PIN_MAP" END

				else
					-- wait for section begin mark like "Section port_pin_map NDIP28"
					-- this only makes sense if "info" section has been processed before
					if model_section_processed.info then 
						if get_field_from_line(line_of_file,1) = section_mark.section then -- on match of "Section"
							if get_field_from_line(line_of_file,2) = section_name.port_pin_map then -- on match of "port_pin_map"

								-- if target is a cluster, no need to check the package name
								if ptr_target.class_target = cluster then
									model_section_entered.port_pin_map := true;
								else
								-- if target is class RAM or ROM, check name of package in field 3
									if get_field_from_line(line_of_file,3) = universal_string_type.to_string(ptr_target.device_package) then
										model_section_entered.port_pin_map := true;
									end if;
								end if;
							end if;
						end if;
					end if;
				end if;
				-- SECTION "PORT_PIN_MAP" RELATED END


				-- SECTION "PROG" RELATED BEGIN
				if model_section_entered.prog then
					-- once inside section "prog", wait for end of section mark
					if get_field_from_line(line_of_file,1) = section_mark.endsection then
						model_section_entered.prog := false; -- clear section entered flag
						model_section_processed.prog := true; -- mark section as processed

						-- check for non-processed subsections
						if not prog_subsection_processed.init then
							put_line("WARNING: Section '" & prog_subsection_name.init & "' missing or incomplete !");
						end if;
						if not prog_subsection_processed.write then
							put_line("WARNING: Section '" & prog_subsection_name.write & "' missing or incomplete !");
						end if;
						if not prog_subsection_processed.read then
							put_line("WARNING: Section '" & prog_subsection_name.read & "' missing or incomplete !");
						end if;
						if not prog_subsection_processed.disable then
							put_line("WARNING: Section '" & prog_subsection_name.disable & "' missing or incomplete !");
						end if;

						-- CS: do what is required on finishing section prog
						-- section prog reading done.
					else
						-- PROCESSING SECTION "PROG" BEGIN
-- 						if debug_level >= 100 then
-- 							put_line("prog : ->" & extended_string.to_string(line_of_file) & "<-");
-- 						end if;

						---SUBSECTION INIT RELATED BEGIN----------------------------------------------------------------------
						if prog_subsection_entered.init then
							-- once inside subsection "init", wait for end of subsection mark
							if get_field_from_line(line_of_file,1) = section_mark.endsubsection then
								prog_subsection_entered.init	:= false;
								prog_subsection_processed.init	:= true;

								-- CS: do what is required on finishing subsection init
								-- subsection init reading done.
							else
								-- PROCESSING SUBSECTION INIT BEGIN
								if debug_level >= 100 then
									put_line("init : ->" & extended_string.to_string(line_of_file) & "<-");
								end if;

								get_groups_from_line(operation => init);

								-- PROCESSING SUBSECTION INIT END
							end if;
						else

						-- wait for subsection begin mark like "subsection init"
							if get_field_from_line(line_of_file,1) = section_mark.subsection then
								if get_field_from_line(line_of_file,2) = prog_subsection_name.init then -- on match of "init"
									prog_subsection_entered.init := true; -- set section entered flag
								end if;
							end if;
						end if;
						---SUBSECTION INIT RELATED END------------------------------------------------------------------------

						---SUBSECTION WRITE RELATED BEGIN----------------------------------------------------------------------
						if prog_subsection_entered.write then
							-- once inside subsection "write", wait for end of subsection mark
							if get_field_from_line(line_of_file,1) = section_mark.endsubsection then
								prog_subsection_entered.write	:= false;
								prog_subsection_processed.write	:= true;

								-- CS: do what is required on finishing subsection write
								-- subsection write reading done.
							else
								-- PROCESSING SUBSECTION WRITE BEGIN
								if debug_level >= 100 then
									put_line("write : ->" & extended_string.to_string(line_of_file) & "<-");
								end if;

								get_groups_from_line(operation => write);

								-- PROCESSING SUBSECTION WRITE END
							end if;
						else

						-- wait for subsection begin mark like "subsection write"
							if get_field_from_line(line_of_file,1) = section_mark.subsection then
								if get_field_from_line(line_of_file,2) = prog_subsection_name.write then -- on match of "write"
									prog_subsection_entered.write := true; -- set section entered flag
								end if;
							end if;
						end if;
						---SUBSECTION WRITE RELATED END------------------------------------------------------------------------

						---SUBSECTION READ RELATED BEGIN----------------------------------------------------------------------
						if prog_subsection_entered.read then
							-- once inside subsection "read", wait for end of subsection mark
							if get_field_from_line(line_of_file,1) = section_mark.endsubsection then
								prog_subsection_entered.read	:= false;
								prog_subsection_processed.read	:= true;

								-- CS: do what is required on finishing subsection read
								-- subsection read reading done.
							else
								-- PROCESSING SUBSECTION READ BEGIN
								if debug_level >= 100 then
									put_line("read : ->" & extended_string.to_string(line_of_file) & "<-");
								end if;

								get_groups_from_line(operation => read);

								-- PROCESSING SUBSECTION READ END
							end if;
						else

						-- wait for subsection begin mark like "subsection read"
							if get_field_from_line(line_of_file,1) = section_mark.subsection then
								if get_field_from_line(line_of_file,2) = prog_subsection_name.read then -- on match of "read"
									prog_subsection_entered.read := true; -- set section entered flag
								end if;
							end if;
						end if;
						---SUBSECTION WRITE RELATED END------------------------------------------------------------------------

						---SUBSECTION DISABLE RELATED BEGIN----------------------------------------------------------------------
						if prog_subsection_entered.disable then
							-- once inside subsection "disable", wait for end of subsection mark
							if get_field_from_line(line_of_file,1) = section_mark.endsubsection then
								prog_subsection_entered.disable		:= false;
								prog_subsection_processed.disable	:= true;

								-- CS: do what is required on finishing subsection disable
								-- subsection disable reading done.
							else
								-- PROCESSING SUBSECTION DISABLE BEGIN
								if debug_level >= 100 then
									put_line("disable : ->" & extended_string.to_string(line_of_file) & "<-");
								end if;

								get_groups_from_line(operation => disable);

								-- PROCESSING SUBSECTION DISABLE END
							end if;
						else

						-- wait for subsection begin mark like "subsection disable"
							if get_field_from_line(line_of_file,1) = section_mark.subsection then
								if get_field_from_line(line_of_file,2) = prog_subsection_name.disable then -- on match of "disable"
									prog_subsection_entered.disable := true; -- set section entered flag
								end if;
							end if;
						end if;
						---SUBSECTION DISABLE RELATED END------------------------------------------------------------------------


					end if;
					-- PROCESSING SECTION "PROG" END

				else
					-- wait for section begin mark like "Section prog"
					-- this only makes sense if "port_pin_map" section has been processed before
					if model_section_processed.port_pin_map then 
						if get_field_from_line(line_of_file,1) = section_mark.section then -- on match of "Section"
							if get_field_from_line(line_of_file,2) = section_name.prog then -- on match of "prog"
								model_section_entered.prog := true;
							end if;
						end if;
					end if;
				end if;
				-- SECTION "PROG" RELATED END

			end if; -- if line contains anything
		end loop; -- read model file


		-- CHECK FOR NON-PROCESSED SECTIONS
		if not model_section_processed.info then
			put_line("ERROR: Section 'info' not found or incomplete !");
			raise constraint_error;
		end if;
		if not model_section_processed.port_pin_map then
			put_line("ERROR: No port_pin_map for given package '" & universal_string_type.to_string(ptr_target.device_package) & "' found in device model !");
			put_line("       Check spelling (case sensitive) and try again.");
			raise constraint_error;
		end if;
		if not model_section_processed.prog then
			put_line("ERROR: Section 'prog' not found or incomplete !");
			raise constraint_error;
		end if;

	end read_memory_model; 


	procedure write_info_section is
	-- creates the sequence file,
	-- directs subsequent puts into the sequence file
	-- writes the info section into the sequence file
		procedure write_pin_list is
			-- writes bus width of address, control and data
			-- writes the pin list
			-- writes optionally given min/max addresses
			p 	: type_ptr_memory_pin;
		begin
			put_line(" bus width");
			put_line("  address         :" & natural'image(ptr_target.width_address));
			put_line("  data            :" & natural'image(ptr_target.width_data));
			put_line("  control         :" & natural'image(ptr_target.width_control));

			if ptr_target.option_address_min /= -1 then
				--put_line(" option addr min  :" & natural'image(ptr_target.option_address_min));
				put_line(" option addr min  : " & natural_to_string(
					natural_in => ptr_target.option_address_min,
					base => 16));
			end if;
			if ptr_target.option_address_max /= -1 then
				put_line(" option addr max  : " & natural_to_string(
					natural_in => ptr_target.option_address_max,
					base => 16));
			end if;


			put_line(" port-pin-net mapping");
			put_line("  -- legend: class direction port pin net");
			for c in 0..type_pin_class'pos( type_pin_class'last ) loop -- loop for each kind of pin class: address, data, control
				p := ptr_memory_pin; -- reset pin pointer to end of list
				while p /= null loop
	
					-- if pin class pointed to by c matches pin class in pin list
					-- write pin class, direction, port name, [index], net name
					if p.class_pin = type_pin_class'val(c) then
						put(row_separator_0 & row_separator_0 & type_pin_class'image(p.class_pin) & row_separator_0 
							& type_direction'image(p.direction) & row_separator_0 
							& universal_string_type.to_string(p.name_port));
						-- write index for address and data pins only, contro pins do not have indexes
						case p.class_pin is
							when address | data =>
								put(trim(natural'image(p.index),left));
							when control =>
								null;
						end case;
						put_line(row_separator_0 & universal_string_type.to_string(p.name_pin)
							& row_separator_0 & universal_string_type.to_string(p.name_net)
							);
					end if;
					p := p.next;
				end loop;

			end loop;
		end write_pin_list;

	begin -- write_info_section
		-- create sequence file
		create( sequence_file, 
			name => (compose (universal_string_type.to_string(test_name), universal_string_type.to_string(test_name), "seq")));
		set_output(sequence_file); -- set data sink

		put_line("Section " & section_name.info);
		put_line(" created by memory/module connections test generator version "& version);
		put_line(" date             : " & m1.date_now);
		put_line(" data base        : " & universal_string_type.to_string(ptr_target.data_base));
		put_line(" test name        : " & universal_string_type.to_string(ptr_target.test_name));
		put_line(" target name      : " & universal_string_type.to_string(ptr_target.device_name));
		put_line(" target class     : " & type_target_class'image(ptr_target.class_target));
		case ptr_target.class_target is 
			when RAM | ROM =>
				put_line(" package          : " & universal_string_type.to_string(ptr_target.device_package));
				put_line(" value            : " & universal_string_type.to_string(ptr_target.value));
				put_line(" compatibles      : " & universal_string_type.to_string(ptr_target.compatibles));
				put_line(" manufacturer     : " & universal_string_type.to_string(ptr_target.manufacturer));
				put_line(" protocol         : " & type_protocol'image(ptr_target.protocol));
				put_line(" algorithm        : " & type_algorithm'image(ptr_target.algorithm));
				put_line(" write protect    : " & type_write_protect'image(ptr_target.write_protect));
			when others => null;
		end case;
		put_line(" model file       : " & universal_string_type.to_string(ptr_target.model_file));
		put_line(" model version    : " & universal_string_type.to_string(ptr_target.version));
		put_line(" model author     : " & universal_string_type.to_string(ptr_target.author));
		put_line(" model status     : " & type_model_status'image(ptr_target.status));

		write_pin_list;

		put_line("EndSection"); 
		new_line;
	end write_info_section;


	procedure write_sequences is

	begin -- write_sequences
		new_line(2);

		all_in(sample);
		write_ir_capture;
		load_safe_values;
		all_in(extest);

	end write_sequences;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	put_line("memory/module interconnect test generator version "& Version);
	put_line("=====================================================");

	-- ALL COMMAND LINE ARGUMENTS WILL BE PASSED WHEN CREATING OBJECT "TARGET" POINTED TO BY PTR_TARGET
	prog_position	:= 10;
 	data_base:= universal_string_type.to_bounded_string(Argument(1));
 	put_line ("data base      : " & universal_string_type.to_string(data_base));
 
	prog_position	:= 20;
 	test_name:= universal_string_type.to_bounded_string(Argument(2));
 	put_line ("test name      : " & universal_string_type.to_string(test_name));
 
	prog_position	:= 30;
 	target_device := universal_string_type.to_bounded_string(Argument(3));
 	put_line ("target device  : " & universal_string_type.to_string(target_device));
 
	prog_position	:= 40;
 	model_file := universal_string_type.to_bounded_string(Argument(4));
 	put_line ("model file     : " & universal_string_type.to_string(model_file));
 
	prog_position	:= 50;
 	device_package := universal_string_type.to_bounded_string(Argument(5));
 	put_line ("device package : " & universal_string_type.to_string(device_package));

	prog_position	:= 55;
	if argument_count = 6 then
		debug_level := natural'value(argument(6));
		put_line("debug level    :" & natural'image(debug_level));
	end if;
	-- COMMAND LINE ARGUMENTS COLLECTING DONE

	-- CS: get algorithm as argument
	-- for the time being it is fixed
	algorithm := standard;

	prog_position	:= 60;
	read_data_base;
	prog_position	:= 65;
	read_memory_model;

	prog_position	:= 70;
 	create_temp_directory;

	-- create test directory
	prog_position	:= 80;
	create_test_directory(
		test_name 			=> universal_string_type.to_string(test_name),
		warnings_enabled 	=> false
		);

	prog_position	:= 90; 
	write_info_section;
	prog_position	:= 100;
	write_test_section_options;

	prog_position	:= 110;
	write_test_init;

	prog_position	:= 120;
	write_sequences;

	prog_position	:= 130;
	set_output(standard_output);

	prog_position	:= 140;
	close(sequence_file);


	exception
		when event: others =>
			set_output(standard_output);
			case prog_position is
				when 10 =>
					put_line("ERROR: Data base file missing or insufficient access rights !");
					put_line("       Provide data base name as argument. Example: mkmemcon my_uut.udb");
				when 20 =>
					put_line("ERROR: Test name missing !");
					put_line("       Provide test name as argument ! Example: mkmemcon my_uut.udb my_memory_test");
				when 30 =>
					put_line("ERROR: Target device missing !");
					put_line("       Provide target device as argument ! Example: mkmemcon my_uut.udb my_memory_test IC22");
				when 40 =>
					put_line("ERROR: Device model missing !");
					put_line("       Provide device model as argument ! Example: mkmemcon my_uut.udb my_memory_test IC22 models/sdram.txt");
				when 50 =>
					put_line("ERROR: Device package missing !");
					put_line("       Provide device package as argument ! Example: mkmemcon my_uut.udb my_memory_test IC22 models/sdram.txt SOP24");
					put_line("       Use dummy package for cluster/module test. Example: mkmemcon my_uut.udb my_module_test X39 models/module.txt dummy");
				when 55 =>
					put_line("ERROR: Invalid argument for debug level. Debug level must be provided as natural number !");


				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("error in model file in line :" & natural'image(line_counter));
					put_line("program error at position " & natural'image(prog_position));
			end case;

end mkmemcon;
