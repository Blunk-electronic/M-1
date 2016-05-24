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
			test_profile	: type_test_profile	:= memconnect;
			end_sdr			: type_end_sdr		:= PDR; -- pause dr  -- CS: wrong placed. this is not part of the model file !
			end_sir			: type_end_sir		:= RTI; -- run-test/idle -- CS: wrong placed. this is not part of the model file !
			value			: string (1..5) 	:= "value";
			compatibles		: string (1..11) 	:= "compatibles";
			date			: string (1..4) 	:= "date";
			version			: string (1..7) 	:= "version";
			status			: string (1..6) 	:= "status";
			author			: string (1..6) 	:= "author";
			manufacturer	: string (1..12)	:= "manufacturer";
			class			: string (1..5)  	:= "class";
			write_protect	: string (1..13) 	:= "write_protect";
			protocol		: string (1..8)  	:= "protocol";
			ram_type		: string (1..8)  	:= "ram_type";
			rom_type		: string (1..8)  	:= "rom_type";
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

			-- values that hold the number of init, read, write, disable steps
			-- will be set when reading section prog (by procedure add_to_step_list)
			step_count_init		: natural;
			step_count_write	: natural;
			step_count_read		: natural;
			step_count_disable	: natural;
			step_count_total	: natural;
		
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

	-- definition of a list of receivers
	type type_receiver;
	type type_ptr_receiver is access all type_receiver;
	type type_receiver is
		record
			next		: type_ptr_receiver;
			name_bic	: universal_string_type.bounded_string;
			id_cell		: natural;
		end record;
	ptr_receiver : type_ptr_receiver;

	-- type definition of a single pin
	-- The object of type type_pin will be added to a list later
	-- and accessed by pointer ptr_pin.
	type type_memory_pin;
	type type_ptr_memory_pin is access all type_memory_pin;
	type type_pin_class is ( data, address, control);
	type type_direction is ( input, output, inout);
	type type_memory_pin (class_pin : type_pin_class; has_receivers : boolean) is
		record
			next			: type_ptr_memory_pin;
			name_pin		: universal_string_type.bounded_string; -- like pin 75, 34, 4
			name_port		: universal_string_type.bounded_string; -- like port A13, SDA, D15
			name_net 		: universal_string_type.bounded_string; -- the net it is connected with (like CPU_WE)
			name_bic_driver				: universal_string_type.bounded_string;
			--name_pin_driver_scratch	: universal_string_type.bounded_string;
			output_cell_id				: natural; -- the id of the output cell of the bic that drives this pin
			--output_cell_value			: type_bit_char_class_0;
			drive_cell_inverted			: boolean;
			id_control_cell				: type_cell_info_cell_id; -- the id of the control cell cell of the bic that drives this pin -- if -1, no control cell available for that driver pin
			control_cell_disable_value	: type_bit_char_class_0;
			direction					: type_direction;
			index						: natural; -- like address 0, data 7
			case has_receivers is
				when false => null;
				when true =>
					receiver_list_last			: type_ptr_receiver; -- saves the pointer position of the last receiver added (required when resetting the pointer
					receiver_list				: type_ptr_receiver; -- receiver_last)
			end case;
		end record;
	ptr_memory_pin	: type_ptr_memory_pin;

	invalid_value	: boolean := false; -- used to warn operator about value given in model differing from value found in net list 
										-- set by function get_connected_net
	invalid_package	: boolean := false; -- used to warn operator about package given in model differing from package found in net list 
										-- set by function get_connected_net

	procedure gather_pin_data(
	-- adds port, pin name, direction, connected net, driver, receiver_list to pin list

	-- example 1: port D5 maps to pin 17 ( taken from -- vector inout D[7:0] 19 18 17 16 15 13 12 11)
	-- example 2: port WE maps to pin 27 ( taken from -- control in WE 	27)
		list				: in out type_ptr_memory_pin;
		pin_class_given		: in type_pin_class;
		name_pin_given		: in universal_string_type.bounded_string;
		name_port_given		: in universal_string_type.bounded_string;
		direction_given		: in type_direction;
		index_given			: in natural
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
		-- returns the name of the net connected to the pin
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
				put_line("ERROR: Target device '" & universal_string_type.to_string(ptr_target.device_name) 
					& "' pin '" & universal_string_type.to_string(name_pin_given) & "' not found in data base !");
				put_line("       Make sure target and pin exists or check spelling (case sensitive) !");
				raise constraint_error;
			end if;
			return net_name; -- send net name back
		end get_connected_net;

 		name_bic_driver_scratch		: universal_string_type.bounded_string;
 		name_pin_driver_scratch		: universal_string_type.bounded_string;
		id_cell_driver_scratch			: natural;
		id_control_cell_driver_scratch	: type_cell_info_cell_id := -1; -- by default we assume there is no control cell
		control_cell_disable_value_driver_scratch : type_bit_char_class_0;
		drive_cell_inverted_scratch	: boolean := false;
 		name_net_scratch 			: universal_string_type.bounded_string;
 		name_net_primary 			: universal_string_type.bounded_string;
 		name_net_secondary 			: universal_string_type.bounded_string;
		list_of_secondary_nets		: type_list_of_secondary_net_names;
		number_of_secondary_nets	: natural;
		has_receivers				: boolean := false;

		procedure get_bic_driver is
		-- searches in atg drive cell list for the driver of the net given in name_net_primary
		-- if the driver is not in this list, it is in a static net which does not qualify for test generation
		-- further-on: the disable value of the control cell is derived 
			c	: type_cell_list_atg_drive_ptr := ptr_cell_list_atg_drive;
			c1	: type_cell_list_locked_control_cells_in_class_DH_DL_NR_nets_ptr := ptr_cell_list_locked_control_cells_in_class_DH_DL_NR_nets;
			driver_found	: boolean := false;
		begin
			while c /= null loop -- search atg drive list
				if universal_string_type.to_string(c.net) = universal_string_type.to_string(name_net_primary) then
					driver_found := true;
					name_bic_driver_scratch := c.device; 	-- backup device name
					name_pin_driver_scratch := c.pin;		-- backup driver pin
					id_cell_driver_scratch	:= c.cell;		-- backup driver cell

					--put_line(standard_output,"test0");

					case c.class is

						-- get further information if it is a PU/PD net
						when PU | PD =>
							--put_line(standard_output,"test1");
							-- this implies that this net is controlled by a control cell
							--if c.controlled_by_control_cell then
							-- example: class PU primary_net /CPU_WR device IC300 pin 26 control_cell 6 inverted yes
							drive_cell_inverted_scratch 	:= c.inverted; -- backup inverted status
							id_control_cell_driver_scratch	:= c.cell; -- in this case the driver and control cell are the same
							control_cell_disable_value_driver_scratch := disable_value_derived_from_class_and_inverted_status(
																		class_given 	=> c.class,
																		inverted_given 	=> c.inverted);

						-- get further information if it is an NR net
						when NR =>
							--put_line(standard_output,"test2");
							-- example: if atg drive list has a: class NR primary_net LED1 device IC303 pin 9 output_cell 1
							-- then in list c1 this must be located: class NR primary_net LED1 device IC303 pin 9 control_cell 16 locked_to enable_value 0
							-- in order to obtain disable information
							-- if list c1 does not provide any information on how to disable the driver, then there is no control 
							-- cell, which leaves id_control_cell_driver_scratch at -1
							while c1 /= null loop
								if universal_string_type.to_string(c1.net) = universal_string_type.to_string(c.net) then
									if universal_string_type.to_string(c1.device) = universal_string_type.to_string(c.device) then
										if universal_string_type.to_string(c1.pin) = universal_string_type.to_string(c.pin) then
											id_control_cell_driver_scratch := c1.cell;
											case c1.locked_to_enable_state is
												when true => control_cell_disable_value_driver_scratch := negate_bit_character_class_0(c1.enable_value);
												when false => control_cell_disable_value_driver_scratch := c1.disable_value;
											end case;
											-- check for shared control cell and put warning CS: repeat this check but put error when assigning cell values
											if is_shared(c1.device,c1.cell) then
												put("WARNING: Shared control cell with ID" & natural'image(c1.cell) & " found: ");
												put("primary net: " & universal_string_type.to_string(name_net_primary));
												put(row_separator_1 & "driver: " & universal_string_type.to_string(c.device));
												put(row_separator_1 & "pin: " & universal_string_type.to_string(c.pin));
												put(row_separator_1 & "output cell:" & natural'image(c.cell));
												new_line;
												-- CS: refine output: show affected drivers and nets
											end if;
										end if;
									end if;
								end if;
								c1 := c1.next;
							end loop;

						-- other net classes are not allowed here and should not be here at all
						when others =>
							put_line("ERROR: Class of driver net '" & universal_string_type.to_string(name_net_primary) & "' invalid !");
							raise constraint_error;
					end case;

					exit; -- driver found, so no more searching required
				end if;
				c := c.next; -- advance to next entry in atg drive cell list
			end loop;
			-- if net not found in atg drive list, it does not qualify for test generation, abort:
			if not driver_found then
				put_line("ERROR: Primary net '" & universal_string_type.to_string(name_net_primary) & "' does not qualify for test generation !");
				put_line("       Check net class ! A customized data base for this test might be required.");
				raise constraint_error;
			end if;
		end get_bic_driver;


		procedure add_to_receiver_list (
		-- called by get_bic_receivers when a receiver is to be appended
			list 			: in out type_ptr_receiver;
			name_bic_given	: in universal_string_type.bounded_string;
			id_cell_given	: in natural
			) is
		begin
			list := new type_receiver'(
				next		=> list,
				name_bic	=> name_bic_given,
				id_cell		=> id_cell_given
				);
		end add_to_receiver_list;


		procedure get_bic_receivers (name_net : universal_string_type.bounded_string) is
		-- searches in atg expect list for ALL receivers if the net given in name_net
		-- and adds them one-by-one to the receiver list pointed to by ptr_receiver
		-- it adds receivers every time it gets called
			c	: type_cell_list_atg_expect_ptr 	:= ptr_cell_list_atg_expect;
		begin
			while c /= null loop
				if universal_string_type.to_string(c.net) = universal_string_type.to_string(name_net) then
					has_receivers := true;
					add_to_receiver_list( list => ptr_receiver, name_bic_given => c.device, id_cell_given => c.cell);
-- 					put_line(standard_output,universal_string_type.to_string(c.net) & row_separator_0
-- 						& universal_string_type.to_string(c.device)
-- 						& natural'image(c.cell));
					--exit;
				end if;
				c := c.next;
			end loop;
		end get_bic_receivers;

		procedure add_to_pin_list is
		-- adds a pin incl. driver to list pointed to by ptr_memory_pin
		-- if receivers present, add them also
	
			procedure add_with_receivers is
			-- the receiver_list (pointed to by ptr_receiver) is copied to pointer s, which in turn becomes a part of the pin
				subtype ptr_scratch is not null type_ptr_receiver;
				s : ptr_scratch := ptr_receiver; -- s points now to the end of the receiver_list
			begin
				s.all := ptr_receiver.all; -- copy receiver_list to s, which later will be part of the pin 

				-- in depence of the given pin class, add the given pin to the pin list
				case pin_class_given is
					when data =>
						scratch_width_data := scratch_width_data + 1;
						list := new type_memory_pin'(
							next		=> list,
							class_pin	=> data,
							name_pin	=> name_pin_given,
							name_port	=> name_port_given,
							name_net	=> name_net_scratch,
							name_bic_driver 			=> name_bic_driver_scratch,
							output_cell_id				=> id_cell_driver_scratch,
							--output_cell_value			=> '0',
							drive_cell_inverted			=> drive_cell_inverted_scratch,
							id_control_cell		 		=> id_control_cell_driver_scratch,
							control_cell_disable_value	=> control_cell_disable_value_driver_scratch,
							has_receivers		=> true,
							receiver_list_last	=> s, -- backup position of last receiver
							receiver_list		=> s,
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
							name_net	=> name_net_scratch,
							name_bic_driver 			=> name_bic_driver_scratch,
							output_cell_id				=> id_cell_driver_scratch,
							--output_cell_value			=> '0',
							drive_cell_inverted			=> drive_cell_inverted_scratch,
							id_control_cell		 		=> id_control_cell_driver_scratch,
							control_cell_disable_value 	=> control_cell_disable_value_driver_scratch,
							has_receivers		=> true,
							receiver_list_last	=> s,
							receiver_list		=> s,
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
							name_net	=> name_net_scratch,
							name_bic_driver 			=> name_bic_driver_scratch,
							output_cell_id				=> id_cell_driver_scratch,
							--output_cell_value			=> '0',
							drive_cell_inverted			=> drive_cell_inverted_scratch,
							id_control_cell		 		=> id_control_cell_driver_scratch,
							control_cell_disable_value 	=> control_cell_disable_value_driver_scratch,
							has_receivers		=> true,
							receiver_list_last	=> s,
							receiver_list		=> s,
							direction	=> direction_given,
							index		=> index_given
							);
				end case;
			end add_with_receivers;

		begin
			if has_receivers then
				add_with_receivers;
			else

				-- in depence of the given pin class, add the given pin to the pin list
				case pin_class_given is
					when data =>
						scratch_width_data := scratch_width_data + 1;
						list := new type_memory_pin'(
							next		=> list,
							class_pin	=> data,
							name_pin	=> name_pin_given,
							name_port	=> name_port_given,
							name_net	=> name_net_scratch,
							name_bic_driver 			=> name_bic_driver_scratch,
							output_cell_id				=> id_cell_driver_scratch,
							--output_cell_value			=> '0',
							drive_cell_inverted			=> drive_cell_inverted_scratch,
							id_control_cell		 		=> id_control_cell_driver_scratch,
							control_cell_disable_value	=> control_cell_disable_value_driver_scratch,
							has_receivers		=> false,
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
							name_net	=> name_net_scratch,
							name_bic_driver 			=> name_bic_driver_scratch,
							output_cell_id				=> id_cell_driver_scratch,
							--output_cell_value			=> '0',
							drive_cell_inverted			=> drive_cell_inverted_scratch,
							id_control_cell		 		=> id_control_cell_driver_scratch,
							control_cell_disable_value 	=> control_cell_disable_value_driver_scratch,
							has_receivers		=> false,
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
							name_net	=> name_net_scratch,
							name_bic_driver 			=> name_bic_driver_scratch,
							output_cell_id				=> id_cell_driver_scratch,
							--output_cell_value			=> '0',
							drive_cell_inverted			=> drive_cell_inverted_scratch,
							id_control_cell		 		=> id_control_cell_driver_scratch,
							control_cell_disable_value 	=> control_cell_disable_value_driver_scratch,
							has_receivers		=> false,
							direction	=> direction_given,
							index		=> index_given
							);
				end case;
			end if;

		end add_to_pin_list;

	begin -- gather_pin_data
		-- check if pin already in pin list of the target, thus avoiding multiple usage of the same pin
		check_if_pin_already_in_list;

		-- get the name of the net directly connected to the target pin
		name_net_scratch := get_connected_net;

		-- the net could be primary or secondary net. we need to know the name of the primary net:
		-- if name_net_scratch is a primary net, name_net_primary assumes the primary net name directly
		if is_primary(name_net_scratch) then
			name_net_primary 			:= name_net_scratch;
		else
		-- if name_net_scratch is a secondary net, the superordinated primary net is to be found and copied into name_net_primary
			name_net_primary			:= get_primary_net(name_net_scratch);
		end if;

		-- with name_net_primary the driving bic and its cell is to be found:
		get_bic_driver; -- uses the name_net_primary
		-- find all receivers of this primary net and add them to the receiver_list
		get_bic_receivers(name_net_primary);

		-- if there are secondary nets, their receivers have to be found too
		number_of_secondary_nets	:= get_number_of_secondary_nets(name_net_primary);
		if number_of_secondary_nets > 0 then
			list_of_secondary_nets	:= get_secondary_nets(name_net_primary);
			for s in 1..number_of_secondary_nets loop
				get_bic_receivers(list_of_secondary_nets(s));
			end loop;
		end if;
		
		add_to_pin_list; -- adds driver and receiver_list to pin list
		ptr_receiver := null; -- reset pointer ptr_receiver for next list of receivers (for next pin)
	end gather_pin_data;

	-- TYPES AND OBJECTS RELATED TO SECTION "PROG"
	type type_value_format is (bitwise, number);
	type type_step_operation is ( INIT, WRITE, READ, DISABLE);
	type type_step_direction is ( DRIVE, EXPECT );
	type type_step_group (width : natural := 0) is
		record
			case width is
				when 0 => null;
				when others =>
					direction		: type_step_direction;
					value_natural	: natural := 0; -- CS: limit value to (2**width) -1
					atg				: boolean := false;
					all_highz		: boolean := false; -- indicates if whole group is to drive highz
					value_string	: universal_string_type.bounded_string;
					value_format	: type_value_format := number;
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
			line_number		: positive;
		end record;
	ptr_step : type_ptr_step;


	procedure add_to_step_list(
		list				: in out type_ptr_step;
		operation_given		: type_step_operation;
		step_id_given		: positive;
		group_address_given	: type_step_group;
		group_data_given	: type_step_group;
		group_control_given	: type_step_group;
		delay_value_given	: type_delay_value;
		line_number_given	: positive
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
			delay_value		=> delay_value_given,
			line_number		=> line_number_given
			);

		-- count steps by their type of operation and update total step count
		case operation_given is
			when init 		=> ptr_target.step_count_init		:= ptr_target.step_count_init + 1;
			when write		=> ptr_target.step_count_write		:= ptr_target.step_count_write + 1;
			when read 		=> ptr_target.step_count_read		:= ptr_target.step_count_read + 1;
			when disable	=> ptr_target.step_count_disable	:= ptr_target.step_count_disable + 1;
		end case;
		ptr_target.step_count_total := 
				ptr_target.step_count_init + ptr_target.step_count_write +
				ptr_target.step_count_read + ptr_target.step_count_disable;
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
		
		scratch_control_pin_ct	: natural := 0; -- used for counting control pins and indexing them

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
		-- those temporarily objects are finally passed to procedure "add_to_step_list" which adds them to the step list

			field_ct 		: positive;
			field_ct_max	: positive := 11; -- this is the max. number of fields in such a line
			--atg_address		: boolean := false;
			--atg_data		: boolean := false;
			scratch_value_as_natural: natural; -- holds drive/expect value before being range checked
			scratch_value_as_string	: universal_string_type.bounded_string;

			-- according to bus width taken from object "target", the range for the address/data/control value is set
			-- and used to create a subtype that finally holds the value
			-- NOTE: This serves as a basical check to ensure the data, address or control value fits into the given bus !
			-- it does not check the optional specified min or max address in section port_pin_map !
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

			function check_for_bit_character (text_in : string ; search_item : type_bit_character) return boolean is
			-- returns "true" if given string contains the search_item (0,1, x, X, Z, z).
			-- CS: move to m1_internal.ads
				length_to_check	: positive := text_in'last-1; -- to exclude the trailing format indicator (b)

				-- converts given string (except trailing format indicator) to a type_string_of_bit_characters of class 2
				scratch_text	: type_string_of_bit_characters := to_binary(
									text_in => text_in(text_in'first..length_to_check),
									length	=> length_to_check,
									class	=> class_2);
				item_found		: boolean := false;
			begin
				-- examine scratch_text bit by bit and return "bitwise" on first occurence of 0
				if search_item in type_bit_character_0 then
					for b in 1..length_to_check loop
	 					if scratch_text(b) in type_bit_character_0 then
	 						item_found := true;
							exit;
	 					end if;
					end loop;
				end if;

				-- examine scratch_text bit by bit and return "bitwise" on first occurence of 1
				if search_item in type_bit_character_1 then
					for b in 1..length_to_check loop
	 					if scratch_text(b) in type_bit_character_1 then
	 						item_found := true;
							exit;
	 					end if;
					end loop;
				end if;

				-- examine scratch_text bit by bit and return "bitwise" on first occurence of x
				if search_item in type_bit_character_x then
					for b in 1..length_to_check loop
	 					if scratch_text(b) in type_bit_character_x then
	 						item_found := true;
							exit;
	 					end if;
					end loop;
				end if;

				-- examine scratch_text bit by bit and return "bitwise" on first occurence of z
				if search_item in type_bit_character_z then
					for b in 1..length_to_check loop
	 					if scratch_text(b) in type_bit_character_z then
	 						item_found := true;
							exit;
	 					end if;
					end loop;
				end if;

				if item_found then 
					return true;
				else
					return false;
				end if;

			end check_for_bit_character;

			function format_is(text_in : string ; format_indicator : type_format_indicator) return boolean is
			-- returns true if given text_in ends in a valid format indicator (like d,b,h)
			-- CS: move to m1_internal.ads
				pos_of_format_indicator	: positive := text_in'last;
			begin
				--put_line(text_in & " " & type_format_indicator'image(format_indicator)(2));
				if text_in(pos_of_format_indicator) = type_format_indicator'image(format_indicator)(2) then
					-- NOTE: delimiters must be stripped (2) from type_format_indicator'image
					return true;
				end if;
				return false;
			end format_is;

			function strip_format_indicator(text_in : string) return string is
				pos_of_format_indicator	: positive := text_in'last;
				text_out				: string (1..pos_of_format_indicator-1);
			begin
				--if type_format_indicator'value(text_in(pos_of_format_indicator)) in type_format_indicator then
				--CS: make sure the format indicator is valid
				text_out := text_in(text_in'first..pos_of_format_indicator-1);
				--end if;
				return text_out;
			end strip_format_indicator;

		begin
			-- process line like: step 1  ADDR  drive ATG  DATA drive HIGHZ  CTRL drive 011
			-- on match of "step"
			if to_lower(get_field_from_line(line_of_file,1)) = prog_identifier.step then

				-- count steps. the step id found must match step_counter
				step_counter := step_counter + 1; 
				--if step_counter = positive'value(get_field_from_line(line_of_file,2)) then
				if step_counter /= positive'value(get_field_from_line(line_of_file,2)) then
					-- to loosen the constraints on step ids, it is sufficient to output a warning CS: test possible malicious implications !
					put_line("WARNING: Line" & natural'image(line_counter) & ". Step ID invalid or already used !");
				end if;

					-- make sure the maximim field count is not exceeded
					field_ct := get_field_count(extended_string.to_string(line_of_file));
					if field_ct > field_ct_max then
						put_line("ERROR: Too many fields in line ! Line must have no more than" & positive'image(field_ct_max) & " fields !");
						put_line("       Example: step 1  ADDR  drive ATG  DATA drive Z  CTRL drive 011");
						raise constraint_error;
					else
					-- if field count ok then
						-- test fields for identifier addr, data or ctrl. 
						-- if no address, data or control ports defined by port_pin_map -> abort. if group specified yet
						-- then read subsequent fields
						for f in 3..field_ct loop

							-- READ ADDRESS GROUP
							-- if identifier address found
							if to_lower(get_field_from_line(line_of_file,f)) = prog_identifier.addr then
								if ptr_target.width_address /= 0 then -- if bus width greater zero (means if there are address pins)

									-- get direction (expect, drive) from next field
									group_address.direction := type_step_direction'value(get_field_from_line(line_of_file,f+1));

									-- get atg or value field from next field
									if to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.atg then
										case operation is
											when write | read =>
												group_address.atg := true;
											when others =>
												put_line("ERROR: '" & to_upper(prog_identifier.atg) & "' not allowed in " 
													& type_step_operation'image(operation) & " step !");
												raise constraint_error;
										end case;

									-- in case of a drive command, highz is allowed like
									-- step 5  ADDR  drive highz  DATA drive 45h  CTRL drive 11b -- all address drivers go highz
									-- step 5  ADDR  drive 001z1b  DATA drive 45h  CTRL drive 11b -- one address driver goes highz
									elsif group_address.direction = drive and to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.highz then
										group_address.all_highz := true;

									-- expect highz is not allowed:
									elsif group_address.direction = expect and to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.highz then
										put_line("ERROR: Expect 'highz' not allowed in address group !");
										raise constraint_error;
									else
										-- check if value is given bitwise (with x and z) like 001001x00zb
										-- take the value field and test if format indicator is 'b' (bitwise assigment does work with binary format only)
										-- then search for letters x and z in value. if x or z found, set group_address.value_format bit to "bitwise"
										scratch_value_as_string := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,f+2));
										if format_is(universal_string_type.to_string(scratch_value_as_string),'b') then
											-- if format is ok, ensure there is no 'z' within an expect value
											if group_address.direction = expect then
												if check_for_bit_character(universal_string_type.to_string(scratch_value_as_string),'z') then
													put_line("ERROR: Expect 'z' not allowed in address group !");
													raise constraint_error;
												end if;
											end if;
											-- if x or z occurs in value, it can be regareded as "bitwise" formated
											-- the value is to be saved in group_address.value_string
											if	check_for_bit_character(universal_string_type.to_string(scratch_value_as_string),'z') or
												check_for_bit_character(universal_string_type.to_string(scratch_value_as_string),'x') then
													group_address.value_format := bitwise; -- overwrites default "number"
													if strip_format_indicator(universal_string_type.to_string(scratch_value_as_string))'last = ptr_target.width_address then
														group_address.value_string := universal_string_type.to_bounded_string(strip_format_indicator(universal_string_type.to_string(scratch_value_as_string))); 
														-- CS: range check
														put_line("WARNING: Line" & natural'image(line_counter) & ": Address specified may be outside the allowed address range !");
													else
														put_line("ERROR: Expected" & positive'image(ptr_target.width_address) & " characters for bitwise assigment !");
														raise constraint_error;
													end if;
											end if;
										end if;

										-- if value not given bitwise, it is to be regarded as number
										-- the value might be given as hex, dec or binary number
										if group_address.value_format = number then
											scratch_value_as_natural := string_to_natural(get_field_from_line(line_of_file,f+2));
											if scratch_value_as_natural in type_value_address then

												-- if option_address_min is given (greater -1), check if scratch_value is less then option_address_min
												-- and output error message
												if ptr_target.option_address_min /= -1 then
													if scratch_value_as_natural < ptr_target.option_address_min then
														put_line("ERROR: Address must be greater than the value specified in model by '" 
															& port_pin_map_identifier.option & row_separator_0 & port_pin_map_identifier.address 
															& row_separator_0 & port_pin_map_identifier.min
															& natural'image(ptr_target.option_address_min) & " ("
															& natural_to_string(ptr_target.option_address_min,16) & ")' !");
														raise constraint_error;
													end if;
												end if;

												-- if option_address_max is given (greater -1), check if scratch_value is greater then option_address_max
												-- and output error message
												if ptr_target.option_address_max /= -1 then
													if scratch_value_as_natural > ptr_target.option_address_max then
														put_line("ERROR: Address must be less than the value specified in model by '" 
															& port_pin_map_identifier.option & row_separator_0 & port_pin_map_identifier.address 
															& row_separator_0 & port_pin_map_identifier.max
															& natural'image(ptr_target.option_address_max) & " ("
															& natural_to_string(ptr_target.option_address_max,16) & ")' !");
														raise constraint_error;
													end if;
												end if;

												--and scratch_value <= ptr_target.option_address_max then
												group_address.value_natural := string_to_natural(get_field_from_line(line_of_file,f+2));
											else
												put_line("ERROR: Address must not be greater than" 
													& natural'image(address_max) & " ("
													& natural_to_string(address_max,16) & ") !");
												raise constraint_error;
											end if;
										end if; -- if group_address.value_format = number
									end if;
								else 
									-- if group specified but no address port specified in port_pin_map abort
									put_line("ERROR: Target has no address port as specified in section '" & section_name.port_pin_map & ".");
									put_line("       Thus, no address group allowed in section '" & section_name.prog & "' !");
									raise constraint_error;
								end if;

							-- READ DATA GROUP
							elsif -- if identifier data found 
								to_lower(get_field_from_line(line_of_file,f)) = prog_identifier.data then
								if ptr_target.width_data /= 0 then -- if bus width greater zero (means if there are data pins)

									-- get direction (expect, drive) from next field
									group_data.direction := type_step_direction'value(get_field_from_line(line_of_file,f+1));

									-- get atg or value field from next field
									if to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.atg then
										case operation is
											when write | read =>
												group_data.atg := true;
											when others =>
												put_line("ERROR: '" & to_upper(prog_identifier.atg) & "' not allowed in " 
													& type_step_operation'image(operation) & " step !");
												raise constraint_error;
										end case;

									-- in case of a drive command, highz is allowed like
									-- step 5  ADDR  drive highz  DATA drive 45h  CTRL drive 11b -- all address drivers go highz
									-- step 5  ADDR  drive 001z1b  DATA drive 45h  CTRL drive 11b -- one address driver goes highz
									elsif group_data.direction = drive and to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.highz then
										group_data.all_highz := true;

									-- expect highz is not allowed:
									elsif group_data.direction = expect and to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.highz then
										put_line("ERROR: Expect 'highz' not allowed in data group !");
										raise constraint_error;
									else
										-- check if value is given bitwise (with x and z) like 001001x00zb
										-- take the value field and test if format indicator is 'b' (bitwise assigment does work with binary format only)
										-- then search for letters x and z in value. if x or z found, set group_address.value_format bit to "bitwise"
										scratch_value_as_string := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,f+2));
										if format_is(universal_string_type.to_string(scratch_value_as_string),'b') then
											-- if format is ok, ensure there is no 'z' within an expect value
											if group_data.direction = expect then
												if check_for_bit_character(universal_string_type.to_string(scratch_value_as_string),'z') then
													put_line("ERROR: Expect 'z' not allowed in data group !");
													raise constraint_error;
												end if;
											end if;
											-- if x or z occurs in value, it can be regareded as "bitwise" formated
											-- the value is to be saved in group_data.value_string
											if	check_for_bit_character(universal_string_type.to_string(scratch_value_as_string),'z') or
												check_for_bit_character(universal_string_type.to_string(scratch_value_as_string),'x') then
													group_data.value_format := bitwise; -- overwrites default "number"
													if strip_format_indicator(universal_string_type.to_string(scratch_value_as_string))'last = ptr_target.width_data then
														group_data.value_string := universal_string_type.to_bounded_string(strip_format_indicator(universal_string_type.to_string(scratch_value_as_string))); 
														-- CS: no need yet for range check or warning, as data has no upper or lower boundary
														--put_line("WARNING: Line" & natural'image(line_counter) & ": Data specified may be outside the allowed address range !");
													else
														put_line("ERROR: Expected" & positive'image(ptr_target.width_data) & " characters for bitwise assigment !");
														raise constraint_error;
													end if;
											end if;
										end if;

										-- if value not given bitwise, it is to be regarded as number
										-- the value might be given as hex, dec or binary number
										if group_data.value_format = number then

											-- the value might be given as hex, dec or binary number
											scratch_value_as_natural := string_to_natural(get_field_from_line(line_of_file,f+2));
											if scratch_value_as_natural in type_value_data then
												group_data.value_natural := string_to_natural(get_field_from_line(line_of_file,f+2));
											else
												put_line("ERROR: Data value must not be greater than" 
													& natural'image(data_max) & " or "
													& natural_to_string(data_max,16) & " !");
												raise constraint_error;
											end if;

										end if;
									end if;
								else 
									-- if group specified but no data port specified in port_pin_map abort
									put_line("ERROR: Target has no data port as specified in section '" & section_name.port_pin_map & ".");
									put_line("       Thus, no data group allowed in section '" & section_name.prog & "' !");
									raise constraint_error;
								end if;

							-- READ CONTROL GROUP
							elsif -- if identifier control found
								to_lower(get_field_from_line(line_of_file,f)) = prog_identifier.ctrl then
								if ptr_target.width_control /= 0 then -- if bus width greater zero (means if there are control pins)

									-- get direction (expect, drive) from next field
									group_control.direction := type_step_direction'value(get_field_from_line(line_of_file,f+1));

									-- ATG is not allowed in control group
									if to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.atg then
										put_line("ERROR: ATG not allowed in control group !");
										raise constraint_error;
									end if;

									-- in case of a drive command, highz is allowed like
									-- step 5  ADDR  drive highz  DATA drive 45h  CTRL drive highz -- all control drivers go highz
									-- step 5  ADDR  drive 001z1b  DATA drive 45h  CTRL drive z1b -- one control driver goes highz
									if group_control.direction = drive and to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.highz then
										group_control.all_highz := true;

									-- expect highz is not allowed:
									elsif group_control.direction = expect and to_lower(get_field_from_line(line_of_file,f+2)) = prog_identifier.highz then
										put_line("ERROR: Expect 'highz' not allowed in control group !");
										raise constraint_error;
									else
										-- check if value is given bitwise (with x and z) like 001001x00zb
										-- take the value field and test if format indicator is 'b' (bitwise assigment does work with binary format only)
										-- then search for letters x and z in value. if x or z found, set group_control.value_format bit to "bitwise"
										scratch_value_as_string := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,f+2));
										if format_is(universal_string_type.to_string(scratch_value_as_string),'b') then
											-- if format is ok, ensure there is no 'z' within an expect value
											if group_control.direction = expect then
												if check_for_bit_character(universal_string_type.to_string(scratch_value_as_string),'z') then
													put_line("ERROR: Expect 'z' not allowed in control group !");
													raise constraint_error;
												end if;
											end if;
											-- if x or z occurs in value, it can be regareded as "bitwise" formated
											-- the value is to be saved in group_control.value_string
											if	check_for_bit_character(universal_string_type.to_string(scratch_value_as_string),'z') or
												check_for_bit_character(universal_string_type.to_string(scratch_value_as_string),'x') then
													--put_line("bitwise");
													group_control.value_format := bitwise; -- overwrites default "number"
													if strip_format_indicator(universal_string_type.to_string(scratch_value_as_string))'last = ptr_target.width_control then
														group_control.value_string := universal_string_type.to_bounded_string(strip_format_indicator(universal_string_type.to_string(scratch_value_as_string))); 
														-- CS: no need yet for range check or warning, as control has no upper or lower boundary
													else
														put_line("ERROR: Expected" & positive'image(ptr_target.width_control) & " characters for bitwise assigment !");
														raise constraint_error;
													end if;
											end if;
										end if;

										-- if value not given bitwise, it is to be regarded as number
										-- the value might be given as hex, dec or binary number
										if group_control.value_format = number then
											--put_line("number");
											-- the value might be given as hex, dec or binary number
											scratch_value_as_natural := string_to_natural(get_field_from_line(line_of_file,f+2));
											if scratch_value_as_natural in type_value_control then
												group_control.value_natural := string_to_natural(get_field_from_line(line_of_file,f+2));
											else
												put_line("ERROR: Control value must not be greater than " 
													& natural_to_string(control_max,2) & " !");
												raise constraint_error;
											end if;
										end if;
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
-- 				else -- if step id invalid
-- 					put_line("ERROR: Step ID invalid or already used !");
-- 					raise constraint_error;
-- 				end if;
			end if; -- on match of "step"

			add_to_step_list(
				list				=> ptr_step,
				operation_given		=> operation,
				--step_id_given		=> step_counter,
				-- the step id found in the model is to be passed, even if it is invalid (a warning has been issued already)
				step_id_given		=> positive'value(get_field_from_line(line_of_file,2)),
				group_address_given	=> group_address,
				group_data_given	=> group_data,
				group_control_given	=> group_control,
				delay_value_given	=> delay_value,	-- if delay non-zero, this step is regarded as delay (address, data, control don't care)
				line_number_given	=> line_counter
				);
		end get_groups_from_line;


		procedure mirror_index_of_control_pins is
		-- since control pins are numbered from 1 to x (after reading the port_pin_map) the index must be mirrored
			p	: type_ptr_memory_pin := ptr_memory_pin;
		begin
			while p /= null loop -- we start with the last control pin added to the pin list
				-- the last control pin has the highest index (and equals the bus width of the control bus)
				if p.class_pin = control then -- we care for control pins only
					--put_line(standard_output,"idx old" & natural'image(p.index) & " name " & universal_string_type.to_string(p.name_port));

					-- an example of this calculation: 
					-- bus width = 5
					-- index before is 4: so (4 - bus_width) * (-1) - 1 = index after = 0
					-- index before is 1: so (1 - bus_width) * (-1) - 1 = index after = 3
					-- index before is 0: so (0 - bus_width) * (-1) - 1 = index after = 4
					p.index := (p.index - ptr_target.width_control) * (-1) - 1;
					--put_line(standard_output,"idx new" & natural'image(p.index) & " name " & universal_string_type.to_string(p.name_port));
				end if;
				p := p.next;
			end loop;
		end mirror_index_of_control_pins;

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
									step_count_init		=> 0, -- will be set later when reading section prog (by procedure add_to_step_list)
									step_count_read		=> 0, -- will be set later when reading section prog
									step_count_write	=> 0, -- will be set later when reading section prog
									step_count_disable	=> 0, -- will be set later when reading section prog
									step_count_total	=> 0, -- will be set later when reading section prog
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
									step_count_init		=> 0, -- will be set later when reading section prog (by procedure add_to_step_list)
									step_count_read		=> 0, -- will be set later when reading section prog
									step_count_write	=> 0, -- will be set later when reading section prog
									step_count_disable	=> 0, -- will be set later when reading section prog
									step_count_total	=> 0, -- will be set later when reading section prog
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
									step_count_init		=> 0, -- will be set later when reading section prog (by procedure add_to_step_list)
									step_count_read		=> 0, -- will be set later when reading section prog
									step_count_write	=> 0, -- will be set later when reading section prog
									step_count_disable	=> 0, -- will be set later when reading section prog
									step_count_total	=> 0, -- will be set later when reading section prog
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

						-- mirror index of control pins (if any)
						mirror_index_of_control_pins;

						-- update target with address options
						-- if no options found or given, default value of -1 is used, to indicate the option is not given
						ptr_target.option_address_min := scratch_option_address_min;

						-- if options_address_min given (greater -1), make sure it fits into the given bus size
						if ptr_target.option_address_min /= -1 then
							if ptr_target.option_address_min > (2**ptr_target.width_address)-1 then
								put_line("ERROR: Value specified by 'option address min' must be less than" 
									& natural'image((2**ptr_target.width_address)-1) & " (" 
									& natural_to_string((2**ptr_target.width_address)-1,16) & ")");
								raise constraint_error;
							end if;
						end if;

						ptr_target.option_address_max := scratch_option_address_max;

						-- if options_address_max given (greater -1), make sure it fits into the given bus size
						if ptr_target.option_address_max /= -1 then
							if ptr_target.option_address_max > (2**ptr_target.width_address)-1 then
								put_line("ERROR: Value specified by 'option address max' must be less than" 
									& natural'image((2**ptr_target.width_address)-1) & " (" 
									& natural_to_string((2**ptr_target.width_address)-1,16) & ")");
								raise constraint_error;
							end if;
						end if;


						-- section port_pin_map reading done.
					else
						-- PROCESSING SECTION "PORT_PIN_MAP" BEGIN
						if debug_level >= 100 then
							put_line("port_pin_map : ->" & extended_string.to_string(line_of_file) & "<-");
						end if;

						-- read pin class or option identifier from field 1

						-- example: option address min 8000

						-- if identifier is data, address or control, set scratch_pin_class
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

								-- make sure address and data are vectored, control non-vectored 
								case scratch_pin_class is
									when address | data =>
										if scratch_port_name_frac.msb = 0 and scratch_port_name_frac.lsb = 0 then
											put_line("ERROR: Discrete address or data pins not allowed ! Use vectored form like D[7:0] !");
											raise constraint_error;
										end if;
									when control =>
										if scratch_port_name_frac.msb > scratch_port_name_frac.lsb then
											put_line("ERROR: Vectored control pins not allowed ! Control pins must be specified discretely !");
											raise constraint_error;
										end if;
								end case;

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
									case scratch_pin_class is
										when address | data =>
											-- address and data port are vectored are processed here
											for p in 4..field_count loop -- start with field 4 (where the first pin name is)
												gather_pin_data(
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
										when control =>
											-- control ports are non-vectored
												gather_pin_data(
													list			=> ptr_memory_pin,
													pin_class_given	=> scratch_pin_class,
													name_pin_given	=> universal_string_type.to_bounded_string(get_field_from_line(line_of_file,4)),
													name_port_given	=> universal_string_type.to_bounded_string(get_field_from_line(line_of_file,3)),
													direction_given	=> scratch_pin_direction,
													-- derive index from scratch_control_pin_ct
													-- which is incremented on every control pin found
													-- NOTE: the index of control pins starts with 0 for the first pin found !
													index_given		=> scratch_control_pin_ct
													);
												scratch_control_pin_ct := scratch_control_pin_ct + 1;
									end case;

								else -- on mismatch of pin numbers and length of port:
									put_line("ERROR: Expected" & positive'image(scratch_port_name_frac.length) & " pin name(s) after port name !");
									raise constraint_error;
								end if;

							end if; -- read pin direction identifier from field 2
						end if; -- if identifier is data, address or control. set scratch_pin_class


						-- read options
						-- example: option address min 8000h or 3465d
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


	-- definition of a step in the lut
	type type_lut_step;
	type type_ptr_lut_step is access all type_lut_step;
	type type_lut_step is
		record
			next		: type_ptr_lut_step;
			step_id		: natural;
			address		: natural;
			data		: natural;
		end record;
	ptr_lut_step	: type_ptr_lut_step;

	procedure make_lut is
	-- generates a lut according to the given algorithm
	-- afterwards the lut can be accessed by pointer ptr_lut_step

		-- the address bus width dictates the highest address location
		address_physical_max	: natural := (2**ptr_target.width_address)-1;
		subtype type_address_physical_max is natural range 0..address_physical_max;

		-- set lower and upper address boundaries (they are inside the physical address range)
		a_logical_min	: type_address_physical_max;
		a_logical_max	: type_address_physical_max;
		a				: natural := 0; -- a scratch variable
		a_lut			: natural := 0; -- this will be written into the lut

		-- the data bus width dictates the highest data word
		data_max		: natural := (2**ptr_target.width_data)-1;	
		subtype type_data is natural range 0..data_max;
		d		: natural := 0; -- a scratch variable
		di		: natural := 0; -- the "data counter" used once the MSB has been set
		d_lut	: natural := 0; -- this will be written into the lut

		step_id	: natural := 0; -- function wide step counter

		procedure add_to_lut(
			list			: in out type_ptr_lut_step;
			address_given	: natural;
			data_given		: natural
			) is
		begin
			step_id := step_id + 1; -- on adding a step to the lut, increment step counter
			list := new type_lut_step'(
				next		=> list,
				step_id		=> step_id,
				address		=> address_given,
				data		=> data_given
				);
		end add_to_lut;

	begin -- make_lut begin
		-- if option_address_min given (in this case it is greater -1)
		-- then a_logical_min assumes this value
		-- otherwise it assumes zero
		if ptr_target.option_address_min /= -1 then
			a_logical_min := ptr_target.option_address_min;
		else
			a_logical_min := 0;
		end if;

		-- if option_address_max given (in this case it is greater -1)
		-- then a_logical_max assumes this value
		-- otherwise it assumes the max value allowed by the bus width
		if ptr_target.option_address_max /= -1 then
			a_logical_max := ptr_target.option_address_max;
		else
			a_logical_max := address_physical_max;
		end if;

		case ptr_target.algorithm is
			-- the algorithm inprinted in a standard lut is a walking "one" on the address bus
			-- we start with LSB=1 (held by variable a). by multiplying with 2 the "one" gets shifted to the left
			-- steps will be generated until the maximum address is reached
			-- the minimum address is ensured by adding a_logical_min to a (in case a is less than a_logical_min)
			-- on the data bus, a walking one is applied (starting with LSB). once the MSB is reached, it keeps high, 
			-- while on all remaining data bits a counting sequence is generated. this way a unique data pattern for every
			-- memory location is applied
			when standard =>
				a := 1; -- inital address value (LSB=1)
				d := 1; -- inital data value (LSB=1)
				while a <= a_logical_max loop -- loop inside the whole alotted address range 

					-- compute address to be placed in lut: a walking one on the address bus
					if a < a_logical_min then -- if a is below a_logical_min
						a_lut := a + a_logical_min; -- add a_logical_min to a to ensure lower address limit
					else -- if a is equal or greater a_logical_min, a_lut assumes a
						a_lut := a; 
					end if;

					-- compute data to be placed in lut: with a unique data pattern for every relevant memory location
					if d < data_max then
						d_lut := d;
					else
						di := di + 1;
						d_lut := 2**(ptr_target.width_data-1) + di;
						if d_lut > data_max then
							-- in a standard algorithm this situation rarely comes true
							put_line(standard_output,"ERROR: Maximum of dummy data reached !");
							raise constraint_error;
						end if;
					end if;
					d := d * 2; -- shift "one" one bit to the left (once MSB is set, this operation doesn't matter any more)
					a := a * 2; -- shift "one" one bit to the left

					-- for debugging
					--put_line(standard_output,natural_to_string(a_lut ,16) & row_separator_0 & natural_to_string(d_lut,16));

					-- add address and data to lut
					add_to_lut(
						list			=> ptr_lut_step,
						address_given	=> a_lut,
						data_given		=> d_lut
						);
				end loop;

			when others => null;
		end case;
	end make_lut;

	type type_get_step_from_lut_result is
		record
			valid		: boolean := false;
			address		: natural := 0;
			data		: natural := 0;
		end record;

	function get_step_from_lut (step_id_given : positive) return type_get_step_from_lut_result is
	-- fetches a step (specified by step_id_given) from the lut.
	-- returns result of composite type type_get_step_from_lut_result with valid=true if given id was valid
	-- selector "valid" serves as indicator for valid steps
		s		: type_ptr_lut_step := ptr_lut_step;
		result	: type_get_step_from_lut_result;
	begin
		while s /= null loop
			if s.step_id = step_id_given then
				result.valid	:= true;
				result.address	:= s.address;
				result.data		:= s.data;
				exit;
			end if;
			s := s.next;
		end loop;
		return result;
	end get_step_from_lut;

	procedure write_info_section is
	-- creates the sequence file,
	-- directs subsequent puts into the sequence file
	-- writes the info section into the sequence file

		colon_position : positive := 19;

		procedure write_pin_list is
			-- writes bus width of address, control and data
			-- writes the pin list
			-- writes optionally given min/max addresses
			p 	: type_ptr_memory_pin;
		begin
			put_line(" bus_width");
			put_line("  address         :" & natural'image(ptr_target.width_address));
			put_line("  data            :" & natural'image(ptr_target.width_data));
			put_line("  control         :" & natural'image(ptr_target.width_control));

			if ptr_target.option_address_min /= -1 then
				--put_line(" option addr min  :" & natural'image(ptr_target.option_address_min));
				put_line(" option_addr_min  : " & natural_to_string(
					natural_in => ptr_target.option_address_min,
					base => 16));
			end if;
			if ptr_target.option_address_max /= -1 then
				put_line(" option_addr_max  : " & natural_to_string(
					natural_in => ptr_target.option_address_max,
					base => 16));
			end if;


			put_line(" port_pin_net_map");
			put_line("  -- legend: class direction port pin net | driver cell inverted | ctrl_cell disable_val | receiver cell [receiver cell]");
			for c in 0..type_pin_class'pos( type_pin_class'last ) loop -- loop for each kind of pin class: address, data, control
				p := ptr_memory_pin; -- reset pin pointer to end of list
				while p /= null loop
	
					-- if pin class pointed to by c matches pin class in pin list
					-- write pin class, direction, port name, [index], net name
					if p.class_pin = type_pin_class'val(c) then
						put(row_separator_0 & row_separator_0 & type_pin_class'image(p.class_pin) & row_separator_0 
							& type_direction'image(p.direction) & row_separator_0 
							& universal_string_type.to_string(p.name_port));
						-- write index for address and data pins only, control pins do not have indexes
						case p.class_pin is
							when address | data =>
								put(trim(natural'image(p.index),left));
							when control =>
								null;
						end case;

						-- put driver
						put(row_separator_0 & universal_string_type.to_string(p.name_pin)
							& row_separator_0 & universal_string_type.to_string(p.name_net)
							& row_separator_1 & universal_string_type.to_string(p.name_bic_driver)
							& natural'image(p.output_cell_id)
							);
						put(row_separator_0 & boolean'image(p.drive_cell_inverted) & row_separator_1);
						put(type_cell_info_cell_id'image(p.id_control_cell) & row_separator_0
							& type_bit_char_class_0'image(p.control_cell_disable_value)(2) & row_separator_1);

						-- put receivers (if any)
						if p.has_receivers then
							p.receiver_list := p.receiver_list_last; -- reset pointer receiver_list to the end of the list
							while p.receiver_list /= null loop
								put(universal_string_type.to_string(p.receiver_list.name_bic)
									& natural'image(p.receiver_list.id_cell)
									& row_separator_0
								);
								p.receiver_list := p.receiver_list.next;
							end loop;
						end if;
						new_line;
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

		put_line(section_mark.section & row_separator_0 & test_section.info);
		put_line(" created by memory/module connections test generator version "& version);
		--put_line(" date             : " & m1.date_now);
		put_line(row_separator_0 & section_info_item.date & (colon_position-(2+section_info_item.date'last)) * row_separator_0 & ": " & m1.date_now);
		--put_line(" data_base        : " & universal_string_type.to_string(ptr_target.data_base));
		put_line(row_separator_0 & section_info_item.data_base & (colon_position-(2+section_info_item.data_base'last)) * row_separator_0 & ": " & universal_string_type.to_string(ptr_target.data_base));
		--put_line(" test_name        : " & universal_string_type.to_string(ptr_target.test_name));
		put_line(row_separator_0 & section_info_item.test_name & (colon_position-(2+section_info_item.test_name'last)) * row_separator_0 & ": " & universal_string_type.to_string(ptr_target.test_name));
		--put_line(" test_profile     : " & type_test_profile'image(info_item.test_profile));
		put_line(row_separator_0 & section_info_item.test_profile & (colon_position-(2+section_info_item.test_profile'last)) * row_separator_0 & ": " & type_test_profile'image(info_item.test_profile));
		--put_line(" end_sdr          : " & type_end_sdr'image(info_item.end_sdr));
		put_line(row_separator_0 & section_info_item.end_sdr & (colon_position-(2+section_info_item.end_sdr'last)) * row_separator_0 & ": " & type_end_sdr'image(info_item.end_sdr));
		--put_line(" end_sir          : " & type_end_sir'image(info_item.end_sir));
		put_line(row_separator_0 & section_info_item.end_sir & (colon_position-(2+section_info_item.end_sir'last)) * row_separator_0 & ": " & type_end_sir'image(info_item.end_sir));
		put_line(" target_name      : " & universal_string_type.to_string(ptr_target.device_name));
		put_line(" target_class     : " & type_target_class'image(ptr_target.class_target));
		case ptr_target.class_target is 
			when RAM | ROM =>
				put_line(" package          : " & universal_string_type.to_string(ptr_target.device_package));
				put_line(" value            : " & universal_string_type.to_string(ptr_target.value));
				put_line(" compatibles      : " & universal_string_type.to_string(ptr_target.compatibles));
				put_line(" manufacturer     : " & universal_string_type.to_string(ptr_target.manufacturer));
				put_line(" protocol         : " & type_protocol'image(ptr_target.protocol));
				put_line(" algorithm        : " & type_algorithm'image(ptr_target.algorithm));
				put_line(" write_protect    : " & type_write_protect'image(ptr_target.write_protect));
			when others => null;
		end case;
		put_line(" model_file       : " & universal_string_type.to_string(ptr_target.model_file));
		put_line(" model_version    : " & universal_string_type.to_string(ptr_target.version));
		put_line(" model_author     : " & universal_string_type.to_string(ptr_target.author));
		put_line(" model_status     : " & type_model_status'image(ptr_target.status));

		put_line(" step_count_by_model");
		put_line("  init            :" & natural'image(ptr_target.step_count_init));
		put_line("  read            :" & natural'image(ptr_target.step_count_read));
		put_line("  write           :" & natural'image(ptr_target.step_count_write));
		put_line("  disable         :" & natural'image(ptr_target.step_count_disable));
		put_line("  total           :" & natural'image(ptr_target.step_count_total));
		write_pin_list;

		put_line(section_mark.endsection); 
		new_line;
	end write_info_section;


	--type type_cell_assignment_group is (address, data, control);
	--type type_cell_assignment_direction is (drive, expect);

	procedure assign_cells(
	-- for a given pin_class (like address, data, control) writes lines like "set IC301 drv boundary 21=1 24=1 27=1 30=1 33=1 42=1 48=1 51=0"
	-- direction defines the "drv" or "exp" identifier
	-- value is the value to be assigned to the cells
	-- value_format tells whether the value comes as number or as bitwise assigment (like 001z110) WITHOUT trailing format indicator !

	-- it starts writing the cell assigment of the bic with id 1. if a bic is a driver of the group, it appears as new line
	-- like "set IC304 drv boundary 42=1 48=1 51=0"
	-- like "set IC305 drv boundary 55=1 556=1 53=0 45=0"
		pin_class	: type_pin_class;
		direction	: type_step_direction;
		value		: string;
		value_format: type_value_format;
		line_number	: positive
		) is
		b	: type_bscan_ic_ptr := ptr_bic;
		p	: type_ptr_memory_pin := ptr_memory_pin;
		value_length	: positive;
		value_natural	: natural;

		procedure read_value_bitwise is
		-- process the given value bit by bit and translate it into a cell assignment

			-- we create a value v that will hold the given value as a string of bits (0,1,z,Z)
			subtype type_string_of_bit_characters_sized is type_string_of_bit_characters (1..value_length);
			v : type_string_of_bit_characters_sized;
			bic_required_as_driver				: boolean := false; -- indicates if a bic is required for a cell assigment for driving
			bic_required_for_self_monitoring	: boolean := false; -- indicates if a bic is required self monitoring
			bic_required_as_receiver			: boolean := false; -- indicates if a bic is required as receiver

			-- FOR DETECTING SHARED CONTROL CELL CONFLICTS BEGIN
			type type_cc;
			type type_ptr_cc is access all type_cc;
			type type_cc is
				record
					next		: type_ptr_cc;
					id			: natural;		-- holds the control cell id
					value		: type_bit_char_class_0; -- holds the control cell value
					skip 		: boolean; -- indicates that this cell occured earlier and can be skipped
				end record;
			ptr_cc : type_ptr_cc; -- points to a list of control cells

			procedure add_to_record_of_control_cells(
			-- adds a control cell to a list of type_cc, accessed by ptr_cc
				list		: in out type_ptr_cc;
				id_given	: natural;
				value_given	: type_bit_char_class_0
				) is
			begin
				list := new type_cc'(
					next		=> list,
					id			=> id_given,
					value		=> value_given,
					skip		=> false
					);
			end add_to_record_of_control_cells;

			procedure evaluate_record_of_control_cells is
			-- reads the list of control cells (recorded in list pointed to by ptr_cc)
			-- tests if a control cell occurs multiple times in the control cell record
			-- all occurences (but the first one) are marked as "skip" (later, when reading the list, those entries are skipped
			-- to avoid multiple and confusing assigments)
			-- if values of cells differ, a shared control cell conflict exists -> abort
				co : type_ptr_cc := ptr_cc; -- outer loop
				ci : type_ptr_cc; -- inner loop
			begin
				-- outer loop begin
				while co /= null loop
					--	put_line(standard_output," cc id:" & natural'image(co.id) & " " & type_bit_char_class_0'image(co.value));

						-- inner loop begin
						ci := co; -- set ci where co points to (current position)
						ci := ci.next; -- advance ci by one position so that ci points to next cell after co

						while ci /= null loop -- loop in cell record and check further occurences of the same cell
							if ci.id = co.id then -- if cell found
								--put_line(standard_output," - cc id:" & natural'image(ci.id));
								if ci.value = co.value then -- if value is the same, mark cell to be skipped
									co.skip := true;
								else -- if values differ, we have a control cell conflict
									put_line(standard_output,"ERROR:"
										& "line" & positive'image(line_number) & ":"
										& " Shared control cell conflict in" 
										& row_separator_0 & type_pin_class'image(pin_class) 
										& " group !");
									-- CS: refine output by line number
									raise constraint_error;
								end if;
							end if;
							ci := ci.next; -- advance inner pointer to next cell
						end loop;
						-- inner loop end

					co := co.next; -- advance pointer in outer loop
				end loop;

				-- read list of control cells and write them in sequence file
				-- cells marked as "skip" are ignored
				co := ptr_cc; -- reset co at end of list
				while co /= null loop -- loop through control cell list
					if not co.skip then
						put(natural'image(co.id) -- write control cell id
							& sxr_assignment_operator.assign
							& type_bit_char_class_0'image(co.value)(2) -- strip delimiters of value and write value
						);
					end if;
					co := co.next; -- advance cell pointer
				end loop;

				-- clear cell list pointer for next recording
				ptr_cc := null;

			end evaluate_record_of_control_cells;
			-- FOR DETECTING SHARED CONTROL CELL CONFLICTS BEGIN

			
		begin
			-- translate the given value into a string of bit characters of (0,1,z,Z) held by variable v
			case value_format is
				when bitwise => -- if given bitwise
					v := to_binary(
							text_in 	=> value,
							length		=> value_length,
							class		=> class_2
							);
				when number => -- if given as number
					value_natural := natural'value(value); 
					--put_line(standard_output,natural'image(value_length) & " " 
					--	& natural_to_string(natural_in => value_natural, base => 2, length => value_length));
					v := to_binary(
							text_in 	=> natural_to_string(natural_in => value_natural, base => 2, length => value_length)(1..value_length),
							length		=> value_length,
							class		=> class_0
							);
			end case;

			-- start searching of affected bic with the one having the lowest id
			case direction is
				when drive =>
					-- ASSIGN DRIVE PATTERN:
					for bic_id in 1..summary.bic_ct loop -- loop in bic list pointed to by b
						b := ptr_bic;
						while b /= null loop
							if b.id = bic_id then -- on bic id match
								--put_line(standard_output,positive'image(bic_id) & " " & universal_string_type.to_string(b.name));

								-- look ahead into pin list to figure out if the current bic is used as driver for this group at all
								-- and write line header like: "set IC301 drv boundary"
								bic_required_as_driver := false; -- for the start, we assume the current bic is not required
								p := ptr_memory_pin;
								while p /= null loop
									if p.class_pin = pin_class then
										if universal_string_type.to_string(p.name_bic_driver) = universal_string_type.to_string(b.name) then
											put("  set " & universal_string_type.to_string(b.name) & " drv boundary");
											bic_required_as_driver := true; -- mark bic as used for this group
											exit; -- bic is used, so no more looking ahead requried
										end if;
									end if;
									p := p.next;
								end loop;

								-- if bic is required for cell assignment, start reading v (the actual bit pattern) bitwise
								if bic_required_as_driver then
									for i in 1..v'last loop -- do as many loops as v has bits

										p := ptr_memory_pin; -- for every bit, loop in memory pin list
										while p /= null loop -- to find the pin that matches the given pin_class (address, data, control),
															-- bic (p.name_bic_driver and b.name) and the bit position (i)

											if p.class_pin = pin_class then -- on pin_class match
												if universal_string_type.to_string(p.name_bic_driver) = universal_string_type.to_string(b.name) then -- on bic match
													if p.index = v'last - i then -- on index match (NOTE: v has MSB left, i has MSB right)

														-- the given direction of the group implies which cell it to be addressed
														-- "drive" adresses an output and/or control cell only
														-- "expect" adresses an input cell only
														case v(i) is
															-- drive z addresses control cells and assigns them their disable value
															when 'z' | 'Z' => -- CS: use types here
																-- control cells are not written right away but recorded first
																-- record control cell assigments for later detection shared control cell conflicts 
																add_to_record_of_control_cells(ptr_cc, p.id_control_cell, p.control_cell_disable_value);

															when '0' | '1' =>
															-- drive 0/1 addresses output cells and implies activating the control cells
															-- if control cell differs from output cell, then the control cell must get its enable value
															-- the enable value is to be derived from the disable value (by negating)
																if p.id_control_cell /= p.output_cell_id then
																	-- control cells are not written right away but recorded first
																	-- record control cell assigments for later detection shared control cell conflicts 
																	add_to_record_of_control_cells(ptr_cc, p.id_control_cell, negate_bit_character_class_0(p.control_cell_disable_value));
																end if;

																-- assign value to output cell, negate v(i) if drive cell is to be inverted
																put(natural'image(p.output_cell_id) & sxr_assignment_operator.assign);
																if p.drive_cell_inverted then
																	put(type_bit_char_class_2'image(negate_bit_character_class_0(v(i)))(2) -- strip delimiters
																	);
																else
																	put(type_bit_char_class_2'image(v(i))(2) -- strip delimiters
																	);
																end if;


															when 'x' | 'X' =>
															-- drive x addresses output cells and implies activating the control cells
															-- if control cell differs from output cell, then the control cell must get its enable value
																if p.id_control_cell /= p.output_cell_id then
																	-- control cells are not written right away but recorded first
																	-- record control cell assigments for later detection shared control cell conflicts 
																	add_to_record_of_control_cells(ptr_cc, p.id_control_cell, negate_bit_character_class_0(p.control_cell_disable_value));
																end if;

																-- assign zero to output cell
																put(natural'image(p.output_cell_id) 
																	& sxr_assignment_operator.assign
																	& "0"
																);
														end case;

													end if;
												end if;
											end if;

											p := p.next;
										end loop;

									end loop;

									-- now that all output cells have been written in the sequence file, the record of control cells
									-- must be evaluated in order to optimize multiple occurences of contol cells 
									-- and to detect shared control cell conflicts
									--put_line(standard_output,"bic: " & universal_string_type.to_string(b.name));
									evaluate_record_of_control_cells;
									new_line;
								end if;
							end if;
							b := b.next;
						end loop;
					end loop;
				
					-- ASSIGN EXPECT PATTERN FOR SELF MONITORING
					put_line("  -- optional self monitoring:");
					for bic_id in 1..summary.bic_ct loop -- loop in bic list pointed to by b
						b := ptr_bic;
						while b /= null loop
							if b.id = bic_id then -- on bic id match

								-- look ahead into receiver list to figure out if the current bic is used as receiver for this group at all
								-- and write line header like: "set IC301 exp boundary"
								bic_required_for_self_monitoring := false; -- for the start, we assume the current bic is not required
								l_1:
								for i in 1..v'last loop -- do as many loops as v has bits
									p := ptr_memory_pin;
									while p /= null loop
										if p.has_receivers then -- if there are receivers connected at all
											if p.class_pin = pin_class then -- on pin_class match
												if p.index = v'last - i then -- on index match (NOTE: v has MSB left, i has MSB right)
													p.receiver_list := p.receiver_list_last;
													while p.receiver_list /= null loop -- loop though receiver list
														-- on match of bic name
														if universal_string_type.to_string(p.receiver_list.name_bic) = universal_string_type.to_string(b.name) then
															bic_required_for_self_monitoring := true;
															put("  set " & universal_string_type.to_string(b.name) & " exp boundary");
															exit l_1; -- no need to search for further occurences of bic in pin list
														end if;
														p.receiver_list := p.receiver_list.next;
													end loop;
												end if;
											end if;
										end if; -- if there are receivers at all
										p := p.next;
									end loop;	
								end loop l_1;

								if bic_required_for_self_monitoring then
									for i in 1..v'last loop -- do as many loops as v has bits
										p := ptr_memory_pin;
										while p /= null loop
											if p.has_receivers then -- if there are receivers connected at all
												if p.class_pin = pin_class then -- on pin_class match
													if p.index = v'last - i then -- on index match (NOTE: v has MSB left, i has MSB right)
														p.receiver_list := p.receiver_list_last;
														while p.receiver_list /= null loop
															if universal_string_type.to_string(p.receiver_list.name_bic) = universal_string_type.to_string(b.name) then
																case v(i) is
																	when '0' | '1' =>
																		-- expect 0/1 addresses input cells
																		-- assign value to input cell
																			put(natural'image(p.receiver_list.id_cell) 
																				& sxr_assignment_operator.assign
																				& type_bit_char_class_2'image(v(i))(2) -- strip delimiters
																			);
																	when 'x' | 'X' | 'z' | 'Z' =>
																		-- expect 0/1 addresses input cells
																		-- assign value to input cell
																			put(natural'image(p.receiver_list.id_cell) 
																				& sxr_assignment_operator.assign
																				& "x"
																			);
																end case;
															end if;
															p.receiver_list := p.receiver_list.next;
														end loop;
													end if;
												end if;
											end if; -- if there are receivers at all
											p := p.next;
										end loop;	
									end loop;
									new_line;
								end if; -- if bic_required_for_self_monitoring

							end if; -- on bic id match
							b := b.next;
						end loop;
					end loop;

				when expect =>
					-- ASSIGN EXPECT PATTERN
					for bic_id in 1..summary.bic_ct loop -- loop in bic list pointed to by b
						b := ptr_bic;
						while b /= null loop
							if b.id = bic_id then -- on bic id match

								-- look ahead into receiver list to figure out if the current bic is used as receiver for this group at all
								-- and write line header like: "set IC301 exp boundary"
								bic_required_as_receiver := false; -- for the start, we assume the current bic is not required
								l_2:
								for i in 1..v'last loop -- do as many loops as v has bits
									p := ptr_memory_pin;
									while p /= null loop
										if p.has_receivers then -- if there are receivers connected at all
											if p.class_pin = pin_class then -- on pin_class match
												if p.index = v'last - i then -- on index match (NOTE: v has MSB left, i has MSB right)
													p.receiver_list := p.receiver_list_last;
													while p.receiver_list /= null loop -- loop though receiver list
														-- on match of bic name
														if universal_string_type.to_string(p.receiver_list.name_bic) = universal_string_type.to_string(b.name) then
															bic_required_as_receiver := true;
															put("  set " & universal_string_type.to_string(b.name) & " exp boundary ");
															exit l_2; -- no need to search for further occurences of bic in pin list
														end if;
														p.receiver_list := p.receiver_list.next;
													end loop;
												end if;
											end if;
										end if; -- if there are receivers connected at all
										p := p.next;
									end loop;	
								end loop l_2;

								if bic_required_as_receiver then
									for i in 1..v'last loop -- do as many loops as v has bits
										p := ptr_memory_pin;
										while p /= null loop
											if p.has_receivers then -- if there are receivers connected at all
												if p.class_pin = pin_class then -- on pin_class match
													if p.index = v'last - i then -- on index match (NOTE: v has MSB left, i has MSB right)
														p.receiver_list := p.receiver_list_last;
														while p.receiver_list /= null loop
															if universal_string_type.to_string(p.receiver_list.name_bic) = universal_string_type.to_string(b.name) then
																case v(i) is
																	when '0' | '1' =>
																		-- expect 0/1 addresses input cells
																		-- assign value to input cell
																			put(natural'image(p.receiver_list.id_cell) 
																				& sxr_assignment_operator.assign
																				& type_bit_char_class_2'image(v(i))(2) -- strip delimiters
																			);
																	when 'x' | 'X' | 'z' | 'Z' =>
																		-- expect 0/1 addresses input cells
																		-- assign value to input cell
																			put(natural'image(p.receiver_list.id_cell) 
																				& sxr_assignment_operator.assign
																				& "x"
																			);
																end case;
															end if;
															p.receiver_list := p.receiver_list.next;
														end loop;
													end if;
												end if;
											end if; -- if there are receivers connected at all
											p := p.next;
										end loop;	
									end loop;
									new_line;
								end if; -- if bic_required_as_receiver

							end if; -- on bic id match
							b := b.next;
						end loop;
					end loop;
			end case;
			new_line;
		end read_value_bitwise;
			
		

	begin
		-- derive bit count of given group from the bus width of the target
		-- example: if address group given and target bus with is 15bit, the bit count of the address group
		-- is set to 15bit too.
		case pin_class is
			when address =>
				value_length := ptr_target.width_address;
			when data =>
				value_length := ptr_target.width_data;
			when control =>
				value_length := ptr_target.width_control;
		end case;

		-- process the given value bit by bit and translate it into a cell assignment
		read_value_bitwise;
	end assign_cells;

	procedure write_operation(
		operation_given		: type_step_operation;
		atg_address_given	: natural := 0; -- if provided this will fill the ATG field (used by write and read operations only)
		atg_data_given 		: natural := 0;  -- if provided this will fill the ATG field (used by write and read operations only)
		lut_step_id_given	: positive := 1 -- if provided this will be the suffix to the model step (like model step 6.3) in order
											-- to indicate the lut step id
		) is
	-- writes the operation (as specified by operation_given) in the sequence file
	-- writes as comment the operation parameters:
	-- -- operation: INIT
	-- --  model: step xyz ADDR DRIVE 1235h | DATA DRIVE 45h | CTRL DRIVE 01b
	-- or
	-- -- operation: WRITE
	-- --  model: step xyz.abc ADDR DRIVE 1235h | DATA DRIVE 45h | CTRL DRIVE 01b

		s : type_ptr_step; -- the list of steps serves as data pool
	begin
		new_line;
		put_line("-- operation: " & type_step_operation'image(operation_given));
		-- sorting by step id can be achieved by searching the step list from start to end (even if not all steps are init or disable types)
		for i in 1..ptr_target.step_count_total loop
			s := ptr_step; -- set step pointer at end of step list
			while s /= null loop -- loop though step list and filter step types as given in operation_given
				if s.operation = operation_given then
					-- the first step id that matches i is to be output
					if s.step_id = i then 
						put(" -- model step" & positive'image(s.step_id));
						case operation_given is
						-- since init and disable are straight forward blocks (no loops or branches) their steps must be sorted by id and put in the sequence file
							when init | disable =>
								put_line(":");
							when write | read =>
								put_line("." & trim(positive'image(lut_step_id_given),left) & ":"); -- model step 6.3
						end case;

						if s.delay_value = 0.0 then -- if delay value is zero it is a regular test step (otherwise it is a delay)
							if s.group_address.width > 0 then
								put("  -- ADDR " & type_step_direction'image(s.group_address.direction));
								if s.group_address.atg then
									put_line(" ATG " & natural_to_string(atg_address_given,16));
									assign_cells(
										pin_class 		=> address,
										direction 		=> s.group_address.direction,
										value 			=> natural'image(atg_address_given),
										value_format	=> number,
										line_number		=> s.line_number
										);
								elsif s.group_address.all_highz then
									put_line(" ALL HIGHZ ");
									assign_cells(
										pin_class 		=> address,
										direction 		=> s.group_address.direction,
										value 			=> ptr_target.width_address * "Z",
										value_format	=> bitwise,
										line_number		=> s.line_number
										);
								else
									case s.group_address.value_format is
										when number =>
											put_line(row_separator_0 & natural_to_string(s.group_address.value_natural,16));
											assign_cells(
												pin_class 		=> address,
												direction 		=> s.group_address.direction,
												value 			=> natural'image(s.group_address.value_natural),
												value_format	=> number,
												line_number		=> s.line_number
												);
										when bitwise =>
											put_line(row_separator_0 & universal_string_type.to_string(s.group_address.value_string));
											assign_cells(
												pin_class 		=> address,
												direction 		=> s.group_address.direction,
												value 			=> universal_string_type.to_string(s.group_address.value_string),
												value_format	=> bitwise,
												line_number		=> s.line_number
												);
									end case;
								end if;
							end if;

							if s.group_data.width > 0 then
								put("  -- DATA " & type_step_direction'image(s.group_data.direction));
								if s.group_data.atg then
									put_line(" ATG " & natural_to_string(atg_data_given,16));
									assign_cells(
										pin_class 		=> data,
										direction 		=> s.group_data.direction,
										value 			=> natural'image(atg_data_given),
										value_format	=> number,
										line_number		=> s.line_number
										);
								elsif s.group_data.all_highz then
									put_line(" ALL HIGHZ ");
									assign_cells(
										pin_class 		=> data,
										direction 		=> s.group_data.direction,
										value 			=> ptr_target.width_data * "Z",
										value_format	=> bitwise,
										line_number		=> s.line_number
										);
								else
									case s.group_data.value_format is
										when number =>
											put_line(row_separator_0 & natural_to_string(s.group_data.value_natural,16));
											assign_cells(
												pin_class 		=> data,
												direction 		=> s.group_data.direction,
												value 			=> natural'image(s.group_data.value_natural),
												value_format	=> number,
												line_number		=> s.line_number
												);
										when bitwise =>
											put_line(row_separator_0 & universal_string_type.to_string(s.group_data.value_string));
											assign_cells(
												pin_class 		=> data,
												direction 		=> s.group_data.direction,
												value 			=> universal_string_type.to_string(s.group_data.value_string),
												value_format	=> bitwise,
												line_number		=> s.line_number
												);
									end case;
								end if;
							end if;

							if s.group_control.width > 0 then
								put("  -- CTRL " & type_step_direction'image(s.group_control.direction));
								if s.group_control.all_highz then
									put_line(" ALL HIGHZ ");
									assign_cells(
										pin_class 		=> control,
										direction 		=> s.group_control.direction,
										value 			=> ptr_target.width_control * "Z",
										value_format	=> bitwise,
										line_number		=> s.line_number
										);
								else
									case s.group_control.value_format is
										when number =>
											put_line(row_separator_0 & natural_to_string(
												natural_in 	=> s.group_control.value_natural,
												base		=> 2, -- output in binary format
												length		=> ptr_target.width_control) -- fill leading zeroes
												); 
											assign_cells(
												pin_class 		=> control,
												direction 		=> s.group_control.direction,
												value 			=> natural'image(s.group_control.value_natural),
												value_format	=> number,
												line_number		=> s.line_number
												);
										when bitwise =>
											put_line(row_separator_0 & universal_string_type.to_string(s.group_control.value_string));
											assign_cells(
												pin_class 		=> control,
												direction 		=> s.group_control.direction,
												value 			=> universal_string_type.to_string(s.group_control.value_string),
												value_format	=> bitwise,
												line_number		=> s.line_number
												);
									end case;
								end if;
							end if;

							write_sdr;
							--new_line;
						else
							--new_line;
							put_line("  " & prog_identifier.dely & type_delay_value'image(s.delay_value));
						end if;

						exit;
					end if;
				end if;
				s := s.next;
			end loop;
		end loop;
	end write_operation;


	procedure write_sequences is
		lut_step_id		: positive;
		lut_step 		: type_get_step_from_lut_result;
	begin -- write_sequences
		new_line(2);

		all_in(sample);
		write_ir_capture;
		write_sir; new_line;

		load_safe_values;
		write_sdr; new_line;
		load_safe_values;
		write_sdr; new_line;

		all_in(extest);
		write_sir; new_line;

		load_static_drive_values;
		load_static_expect_values;
		write_sdr; new_line;

		write_operation(init);
		--write_operation(write,1000,10);

		-- WRITE WRITE-STEPS BEGIN
		lut_step_id := 1; -- start with initial step number 1
		lut_step := get_step_from_lut(lut_step_id); -- fetch step 1 from lut
		while lut_step.valid loop -- fetch from lut as long as valid steps found (if step is invalid, end of lut has been reached)
			write_operation(write,lut_step.address,lut_step.data,lut_step_id);
			lut_step_id := lut_step_id + 1; -- advance to next step to be fetched from lut
			lut_step := get_step_from_lut(lut_step_id); -- fetch next step from lut
		end loop;

		-- WRITE READ-STEPS BEGIN
		lut_step_id := 1; -- start with initial step number 1
		lut_step := get_step_from_lut(lut_step_id); -- fetch step 1 from lut
		while lut_step.valid loop -- fetch from lut as long as valid steps found (if step is invalid, end of lut has been reached)
			write_operation(read,lut_step.address,lut_step.data,lut_step_id);
			lut_step_id := lut_step_id + 1; -- advance to next step to be fetched from lut
			lut_step := get_step_from_lut(lut_step_id); -- fetch next step from lut
		end loop;

		write_operation(disable);

		write_end_of_test;

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

	make_lut;

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
			set_exit_status(failure);
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
