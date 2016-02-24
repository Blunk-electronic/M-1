------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE CHKPSN                              --
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


-- V 4.1
-- in procedure check_class bugfix: - it is sufficient if PD/PD prim. nets have at least one bidir or output3 pin, 
--									- disable value and result are don't care
--									- no need to check bidir or output3 pin for non-self-controlling output cell

with Ada.Text_IO;			use Ada.Text_IO;
--with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
--with Ada.Float_Text_IO;		use Ada.Float_Text_IO;
with Ada.Characters.Handling; use Ada.Characters.Handling;

--with System.OS_Lib;   use System.OS_Lib;
--with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Bounded; 	use Ada.Strings.Bounded;
with Ada.Strings.Fixed; 	use Ada.Strings.Fixed;
with Ada.Strings; 			use Ada.Strings;
with Ada.Numerics;			use Ada.Numerics;
--with Ada.Numerics.Elementary_Functions;	use Ada.Numerics.Elementary_Functions;

--with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
--with Ada.Task_Identification;  use Ada.Task_Identification;
with Ada.Exceptions; use Ada.Exceptions;
 
with GNAT.OS_Lib;   	use GNAT.OS_Lib;
with Ada.Command_Line;	use Ada.Command_Line;
with Ada.Directories;	use Ada.Directories;

with m1;
with m1_internal; use m1_internal;

procedure chkpsn is

	version			: String (1..3) := "043";
	prog_position	: string (1..6) := "------";
	line_of_file	: extended_string.bounded_string;
	line_counter	: natural := 0;
	debug_level		: natural := 0;
	udb_summary		: type_udb_summary;
--	Previous_Output	: File_Type renames Current_Output;

	name_of_current_primary_net			: extended_string.bounded_string;
	class_of_current_primary_net		: type_net_class := NA;
	primary_net_section_entered			: boolean := false;
	secondary_net_section_entered 		: boolean := false;	

	secondary_net_count					: natural := 0;
	list_of_secondary_net_names			: type_list_of_secondary_net_names;

	total_options_net_count				: natural := 0;

	procedure read_data_base is
	begin
		udb_summary := read_uut_data_base(
			name_of_data_base_file => universal_string_type.to_string(data_base),
			debug_level => 0
			); --.net_count_statistics.total > 0 then null; 
	end read_data_base;


	procedure add_to_options_net_list(
		-- this procedure adds a primary net (incl. secondary nets) to the options net list
		-- multiple occurencs of nets in options file will be checked
		list								: in out type_options_net_ptr;
		name_given							: in string;
		class_given							: in type_net_class;
		secondary_net_ct_given				: in natural;
		list_of_secondary_net_names_given	: in type_list_of_secondary_net_names
		) is

		procedure verify_primary_net_appears_only_once (name : string) is
			n	: type_options_net_ptr := options_net_ptr;
		begin
			prog_position := "OP3000";
			while n /= null loop
				if debug_level >= 30 then
					put_line("searching primary net : " & universal_string_type.to_string(n.name) & " ...");
				end if;

				-- if primary net already specified as primary net:
				if universal_string_type.to_string(n.name) = name then
					prog_position := "OP3100";
					put_line("ERROR: Net '" & name & "' already specified as primary net !");
					raise constraint_error;
				end if;

				-- if primary net already specified as secondary net:
				if n.has_secondaries then
					for s in 1..n.secondary_net_count loop
						if universal_string_type.to_string(n.list_of_secondary_net_names(s)) = name then
							prog_position := "OP3200";
							put_line("ERROR: Net '" & name & "' already specified as secondary net of primary net '" 
								& universal_string_type.to_string(n.name) & "' !");
							raise constraint_error;
						end if;
					end loop;
				end if;
				n := n.next;
			end loop;
		end verify_primary_net_appears_only_once;

		procedure verify_secondary_net_appears_only_once (name : string) is
		-- checks if secondary net appears only once in options file
			n	: type_options_net_ptr := options_net_ptr;
		begin
			prog_position := "OP4000";
			while n /= null loop
				if debug_level >= 30 then
					put_line("searching secondary net in primary net : " & universal_string_type.to_string(n.name) & " ...");
				end if;


				-- if secondary net already specified as primary net:
				if universal_string_type.to_string(n.name) = name then
					prog_position := "OP4100";
					put_line("ERROR: Net '" & name & "' already specified as primary net !");
					raise constraint_error;
				end if;

				-- if secondary net already specified as secondary net:
				if n.has_secondaries then
					for s in 1..n.secondary_net_count loop
						if universal_string_type.to_string(n.list_of_secondary_net_names(s)) = name then
							prog_position := "OP4200";
							put_line("ERROR: Net '" & name & "' already specified as secondary net of primary net '" 
								& universal_string_type.to_string(n.name) & "' !");
							raise constraint_error;
						end if;
					end loop;
				end if;
				n := n.next;
			end loop;
		end verify_secondary_net_appears_only_once;


	begin
		verify_primary_net_appears_only_once(name_given); -- checks other primary nets and their secondary nets in options file

		if debug_level >= 20 then
			put_line("adding to options net list : " & name_given);
		end if;

		prog_position := "OP2000";
		case secondary_net_ct_given is
			when 0 => 
				-- if no secondary nets present, the object to create does not have a list of secondary nets
				list := new type_options_net'(
					next => list,
					name					=> universal_string_type.to_bounded_string(name_given),
					class					=> class_given,
					has_secondaries			=> false,
					secondary_net_count		=> 0
					);

			when others =>
				-- if secondary nets present, the object to create does have a list of secondary nets which needs checking:
				for s in 1..secondary_net_ct_given loop
					if debug_level >= 30 then
						put_line("checking secondary net : " & universal_string_type.to_string(list_of_secondary_net_names_given(s)) 
							& "' for multiple occurences ...");
					end if;

					-- make sure the list of secondary nets does contain unique net names (means no multiple occurences of secondary nets within
					-- the same primary net
					for i in s+1..secondary_net_ct_given loop
						if universal_string_type.to_string(list_of_secondary_net_names_given(s)) = universal_string_type.to_string(list_of_secondary_net_names_given(i)) then
							prog_position := "OP2100";
							put_line("ERROR: Net '" & universal_string_type.to_string(list_of_secondary_net_names_given(s)) & "' must be specified only once as secondary net of this primary net !");
							raise constraint_error;
						end if;
					end loop;

					-- check if current secondary net occurs in other primary and secondary nets
					verify_secondary_net_appears_only_once(universal_string_type.to_string(list_of_secondary_net_names_given(s)));
				end loop;

				list := new type_options_net'(
					next => list,
					name					=> universal_string_type.to_bounded_string(name_given),
					class					=> class_given,
					has_secondaries			=> true,
					secondary_net_count		=> secondary_net_ct_given,
					list_of_secondary_net_names	=> list_of_secondary_net_names_given
					);
		end case;

		-- update net counter of options file by: one primary net + number of attached secondaries
		total_options_net_count := total_options_net_count + 1 + secondary_net_count;

	end add_to_options_net_list;


	procedure make_new_net_list is
		-- with the two net lists pointed to by net_ptr and options_net_ptr, a new net list is created and appended to the
		-- preliminary data base
		-- the class requirements and secondary net dependencies from the options file are taken into account
		o	: type_options_net_ptr 	:= options_net_ptr;

		procedure dump_net_content (
		-- from a given net name, the whole content (means all devices) is dumped into the preliminary data base
			name 				: string; 
			level 				: type_net_level; 

			-- for secondary nets, the superordinated primary net is taken here. otherwise the default is ""
			-- this argument is required for writing cell lists, where reference to primary nets is required
			primary_net_is		: universal_string_type.bounded_string := universal_string_type.to_bounded_string("");

			class 				: type_net_class; 
			spacing_from_left 	: positive
			) is
			d : type_net_ptr := net_ptr;


			procedure update_cell_lists( d : type_net_ptr ) is
			-- updates cell lists by the net where d points to (in data base net list)
				--c : type_net_ptr := d;
				drivers_without_disable_spec_ct 			: natural := 0;
				driver_with_non_shared_control_cell_found 	: boolean := true;

				procedure add_to_locked_control_cells_in_class_EH_EL_NA_nets(
					-- prepares writing a cell list entry like:
					-- class NA primary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0
					-- class NA secondary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0
					list				: in out type_cell_list_locked_control_cells_in_class_EH_EL_NA_nets_ptr;
					class_given			: type_net_class;
					level_given			: type_net_level;
					net_given			: universal_string_type.bounded_string;
					device_given		: universal_string_type.bounded_string;
					pin_given			: universal_string_type.bounded_string;
					cell_given			: natural;
					disable_value_given	: type_bit_char_class_0
					) is
				begin
					list := new type_cell_list_locked_control_cells_in_class_EH_EL_NA_nets'(
						next 			=> list,
						class			=> class_given,
						level			=> level_given,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given,
						disable_value	=> disable_value_given
						);
				end add_to_locked_control_cells_in_class_EH_EL_NA_nets;

				procedure add_to_locked_control_cells_in_class_DH_DL_NR_nets(
					-- prepares writing a cell list entry like:
					-- class NR primary_net LED0 device IC303 pin 10 control_cell 16 locked_to enable_value 0
					-- class NR primary_net LED1 device IC303 pin 9 control_cell 16 locked_to enable_value 0
					-- class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0
					list				: in out type_cell_list_locked_control_cells_in_class_DH_DL_NR_nets_ptr;
					class_given			: type_net_class;
					level_given			: type_net_level;
					net_given			: universal_string_type.bounded_string;
					device_given		: universal_string_type.bounded_string;
					pin_given			: universal_string_type.bounded_string;
					cell_given			: natural;
					locked_to_enable_state_given	: boolean;
					enable_value_given				: type_bit_char_class_0 := '0';
					disable_value_given				: type_bit_char_class_0 := '0'
					) is
				begin
					case locked_to_enable_state_given is
						when true =>
							list := new type_cell_list_locked_control_cells_in_class_DH_DL_NR_nets'(
								next 			=> list,
								class			=> class_given,
								level			=> level_given,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given,
								locked_to_enable_state	=> true,
								enable_value			=> enable_value_given
								);
						when false =>
							list := new type_cell_list_locked_control_cells_in_class_DH_DL_NR_nets'(
								next 			=> list,
								class			=> class_given,
								level			=> level_given,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given,
								locked_to_enable_state	=> false,
								disable_value			=> disable_value_given
								);
					end case;
				end add_to_locked_control_cells_in_class_DH_DL_NR_nets;

				procedure add_to_locked_control_cells_in_class_PU_PD_nets(
					-- prepares writing a cell list entry like:
					-- class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
					-- class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to enable_value 0
					-- class PD secondary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
					list				: in out type_cell_list_locked_control_cells_in_class_PU_PD_nets_ptr;
					class_given			: type_net_class;
					level_given			: type_net_level;
					net_given			: universal_string_type.bounded_string;
					device_given		: universal_string_type.bounded_string;
					pin_given			: universal_string_type.bounded_string;
					cell_given			: natural;
					locked_to_enable_state_given	: boolean;
					enable_value_given				: type_bit_char_class_0 := '0';
					disable_value_given				: type_bit_char_class_0 := '0'
					) is
				begin
					case locked_to_enable_state_given is
						when true =>
							list := new type_cell_list_locked_control_cells_in_class_PU_PD_nets'(
								next 			=> list,
								class			=> class_given,
								level			=> level_given,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given,
								locked_to_enable_state	=> true,
								enable_value			=> enable_value_given
								);
						when false =>
							list := new type_cell_list_locked_control_cells_in_class_PU_PD_nets'(
								next 			=> list,
								class			=> class_given,
								level			=> level_given,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given,
								locked_to_enable_state	=> false,
								disable_value			=> disable_value_given
								);
					end case;
				end add_to_locked_control_cells_in_class_PU_PD_nets;

				procedure add_to_locked_output_cells_in_class_PU_PD_nets(
					-- prepares writing a cell list entry like:
					-- class PU primary_net /SYS_RESET device IC300 pin 39 output_cell 37 locked_to drive_value 0
					list				: in out type_cell_list_locked_output_cells_in_class_PU_PD_nets_ptr;
					class_given			: type_net_class;
					--level_given			: type_net_level := primary; -- because this is always a primary net
					net_given			: universal_string_type.bounded_string;
					device_given		: universal_string_type.bounded_string;
					pin_given			: universal_string_type.bounded_string;
					cell_given			: natural;
					drive_value_given	: type_bit_char_class_0
					) is
				begin
					list := new type_cell_list_locked_output_cells_in_class_PU_PD_nets'(
						next 			=> list,
						class			=> class_given,
						--level			=> level_given,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given,
						drive_value		=> drive_value_given
						);
				end add_to_locked_output_cells_in_class_PU_PD_nets;

				procedure add_to_locked_output_cells_in_class_DH_DL_nets(
					-- prepares writing a cell list entry like:
					-- class DL primary_net /CPU_MREQ device IC300 pin 28 output_cell 13 locked_to drive_value 0
					-- class DH primary_net /CPU_RD device IC300 pin 27 output_cell 10 locked_to drive_value 1
					list				: in out type_cell_list_locked_output_cells_in_class_DH_DL_nets_ptr;
					class_given			: type_net_class;
					--level_given			: type_net_level := primary; -- because this is always a primary net
					net_given			: universal_string_type.bounded_string;
					device_given		: universal_string_type.bounded_string;
					pin_given			: universal_string_type.bounded_string;
					cell_given			: natural;
					drive_value_given	: type_bit_char_class_0
					) is
				begin
					list := new type_cell_list_locked_output_cells_in_class_DH_DL_nets'(
						next 			=> list,
						class			=> class_given,
						--level			=> level_given,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given,
						drive_value		=> drive_value_given
						);
				end add_to_locked_output_cells_in_class_DH_DL_nets;

				procedure add_to_static_expect(
					-- prepares writing a cell list entry like:
					-- class DL primary_net /CPU_MREQ device IC300 pin 28 input_cell 14 expect_value 0
					-- class DL secondary_net /CPU_MREQ device IC300 pin 28 input_cell 14 expect_value 0
					list				: in out type_cell_list_static_expect_ptr;
					class_given			: type_net_class;
					level_given			: type_net_level;
					net_given			: universal_string_type.bounded_string;
					device_given		: universal_string_type.bounded_string;
					pin_given			: universal_string_type.bounded_string;
					cell_given			: natural;
					expect_value_given	: type_bit_char_class_0
					) is
				begin
					list := new type_cell_list_static_expect'(
						next 			=> list,
						class			=> class_given,
						level			=> level_given,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given,
						expect_value	=> expect_value_given
						);
				end add_to_static_expect;

				procedure add_to_atg_expect(
					-- prepares writing a cell list entry like:
					-- class PU secondary_net CT_D3 device IC303 pin 19 input_cell 11 primary_net_is D3
					-- class PU primary_net /CPU_WR device IC300 pin 26 input_cell 8
 					list				: in out type_cell_list_atg_expect_ptr;
					class_given			: type_net_class;
					level_given			: type_net_level;
					net_given			: universal_string_type.bounded_string;
					device_given		: universal_string_type.bounded_string;
					pin_given			: universal_string_type.bounded_string;
					cell_given			: natural;
					primary_net_is_given: universal_string_type.bounded_string
					) is
				begin
					case level_given is
						when primary =>
							list := new type_cell_list_atg_expect'(
								next 			=> list,
								class			=> class_given,
								level			=> primary,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given
								);
						when secondary =>
							list := new type_cell_list_atg_expect'(
								next 			=> list,
								class			=> class_given,
								level			=> secondary,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given,
								primary_net_is	=> primary_net_is_given -- reference to primary net required here
								);
					end case;
				end add_to_atg_expect;

				procedure add_to_atg_drive(
					-- prepares writing a cell list entry like:
					-- class NR primary_net LED7 device IC303 pin 2 output_cell 7
					-- class PU primary_net /CPU_WR device IC300 pin 26 control_cell 6 inverted yes
					-- class PD primary_net /DRV_EN device IC301 pin 27 control_cell 9 inverted no
					list				: in out type_cell_list_atg_drive_ptr;
					class_given			: type_net_class;
					--level_given			: type_net_level := primary; -- because this is always a primary net
					net_given			: universal_string_type.bounded_string;
					device_given		: universal_string_type.bounded_string;
					pin_given			: universal_string_type.bounded_string;
					cell_given			: natural;
					controlled_by_control_cell_given	: boolean; -- if controlled by output cell -> false
					control_cell_inverted_given			: boolean := false -- default in case it is not required
					) is
				begin
					case controlled_by_control_cell_given is
						when true =>
							list := new type_cell_list_atg_drive'(
								next 			=> list,
								class			=> class_given,
								--level			=> secondary,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given,
								controlled_by_control_cell	=> true,
								inverted					=> control_cell_inverted_given
								);
						when false =>
							list := new type_cell_list_atg_drive'(
								next 			=> list,
								class			=> class_given,
								--level			=> secondary,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given,
								controlled_by_control_cell	=> false
								);
					end case;
				end add_to_atg_drive;

				procedure add_to_input_cells_in_class_NA_nets(
					-- prepares writing a cell list entry like:
					-- class NA primary_net OSC_OUT device IC301 pin 6 input_cell 95
					-- class NA secondary_net LED0_R device IC301 pin 2 input_cell 107 primary_net_is LED0
					list				: in out type_cell_list_input_cells_in_class_NA_nets_ptr;
					--class_given			: type_net_class := NA; -- because this is always a class NA net
					level_given			: type_net_level;
					net_given			: universal_string_type.bounded_string;
					device_given		: universal_string_type.bounded_string;
					pin_given			: universal_string_type.bounded_string;
					cell_given			: natural;
					primary_net_is_given: universal_string_type.bounded_string
					) is
				begin
					case level_given is
						when primary =>
							list := new type_cell_list_input_cells_in_class_NA_nets'(
								next 			=> list,
								--class			=> NA,
								level			=> primary,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given
								);
						when secondary =>
							list := new type_cell_list_input_cells_in_class_NA_nets'(
								next 			=> list,
								--class			=> NA,
								level			=> secondary,
								net				=> net_given,
								device			=> device_given,
								pin				=> pin_given,
								cell			=> cell_given,
								primary_net_is	=> primary_net_is_given -- reference to primary net required here
								);
					end case;
				end add_to_input_cells_in_class_NA_nets;


			begin -- update_cell_lists
				-- d is a net pointer and points to the net being processed

				-- FIND INPUT CELLS AND CONTROL CELLS TO BE DISABLED:
				for p in 1..d.part_ct loop -- loop through pin list of given net

					if d.pin(p).is_bscan_capable then -- care for scan capable pins only

						-- THIS IS ABOUT INPUT CELLS:
						-- add all input cells of static and dynamic (atg) nets to cell list "static_expect" and "atg_expect"
						-- since all input cells are listening, the net level (primary/secondary) does not matter
						-- here and will not be evaluated
						if d.pin(p).cell_info.input_cell_id /= -1 then -- if pin does have an input cell
							case class is
								when EH | DH =>
									add_to_static_expect(
										list			=> cell_list_static_expect_ptr,
										class_given		=> class,
										level_given		=> level,
										net_given		=> universal_string_type.to_bounded_string(name),
										device_given	=> d.pin(p).device_name,
										pin_given		=> d.pin(p).device_pin_name,
										cell_given		=> d.pin(p).cell_info.input_cell_id,
										expect_value_given	=> '1'
									);
								when EL | DL =>
									add_to_static_expect(
										list			=> cell_list_static_expect_ptr,
										class_given		=> class,
										level_given		=> level,
										net_given		=> universal_string_type.to_bounded_string(name),
										device_given	=> d.pin(p).device_name,
										pin_given		=> d.pin(p).device_pin_name,
										cell_given		=> d.pin(p).cell_info.input_cell_id,
										expect_value_given	=> '0'
									);
								when NR | PU | PD =>
									add_to_atg_expect(
										list			=> cell_list_atg_expect_ptr,
										class_given		=> class,
										level_given		=> level, 
										-- if secondary net, the argument "primary_net_is" will be evaluated
										primary_net_is_given	=> primary_net_is,
										net_given		=> universal_string_type.to_bounded_string(name),
										device_given	=> d.pin(p).device_name,
										pin_given		=> d.pin(p).device_pin_name,
										cell_given		=> d.pin(p).cell_info.input_cell_id
										);
								when NA =>
									add_to_input_cells_in_class_NA_nets(
										list			=> cell_list_input_cells_in_class_NA_nets_ptr,
										--class_given		=> class, -- no need, class NA set inside add_to_input_cells_in_class_NA_nets
										level_given		=> level, 
										-- if secondary net, the argument "primary_net_is" will be evaluated
										primary_net_is_given	=> primary_net_is,
										net_given		=> universal_string_type.to_bounded_string(name),
										device_given	=> d.pin(p).device_name,
										pin_given		=> d.pin(p).device_pin_name,
										cell_given		=> d.pin(p).cell_info.input_cell_id
										);
							end case; -- class
						end if;

						-- THIS IS ABOUT CONTROL CELLS:
						-- in nets of class EH, EL or NA, all control cells must be in disable state, regardless of net level
						if d.pin(p).cell_info.control_cell_id /= -1 then -- if pin has disable spec. (means: a control cell)
							case class is
								when EL | EH | NA =>
								-- all control cells of those nets must be in disable state (don't care about net level)
									add_to_locked_control_cells_in_class_EH_EL_NA_nets(
										list				=> cell_list_locked_control_cells_in_class_EH_EL_NA_nets_ptr,
										class_given			=> class,
										level_given			=> level,
										net_given			=> universal_string_type.to_bounded_string(name),
										device_given		=> d.pin(p).device_name,
										pin_given			=> d.pin(p).device_pin_name,
										cell_given			=> d.pin(p).cell_info.control_cell_id,
										disable_value_given	=> d.pin(p).cell_info.disable_value
										);
								when others => null;
							end case;
						end if;


						-- THIS IS ABOUT CONTROL CELLS in secondary nets:
						case level is
							when secondary =>
								-- all control cells in secondary nets must be in disable state
								if d.pin(p).cell_info.control_cell_id /= -1 then -- if pin has a control cell
									case class is
										when EL | EH | NA =>
											add_to_locked_control_cells_in_class_EH_EL_NA_nets(
												list				=> cell_list_locked_control_cells_in_class_EH_EL_NA_nets_ptr,
												class_given			=> class,
												level_given			=> level,
												net_given			=> universal_string_type.to_bounded_string(name),
												device_given		=> d.pin(p).device_name,
												pin_given			=> d.pin(p).device_pin_name,
												cell_given			=> d.pin(p).cell_info.control_cell_id,
												disable_value_given	=> d.pin(p).cell_info.disable_value
												);
										when DH | DL | NR =>
											add_to_locked_control_cells_in_class_DH_DL_NR_nets(
												list				=> cell_list_locked_control_cells_in_class_DH_DL_NR_nets_ptr,
												class_given			=> class,
												level_given			=> level,
												net_given			=> universal_string_type.to_bounded_string(name),
												device_given		=> d.pin(p).device_name,
												pin_given			=> d.pin(p).device_pin_name,
												cell_given			=> d.pin(p).cell_info.control_cell_id,
												locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
																						-- must be in disable state
												disable_value_given				=> d.pin(p).cell_info.disable_value
												);
										when PU | PD =>
											add_to_locked_control_cells_in_class_PU_PD_nets(
												list				=> cell_list_locked_control_cells_in_class_PU_PD_nets_ptr,
												class_given			=> class,
												level_given			=> level,
												net_given			=> universal_string_type.to_bounded_string(name),
												device_given		=> d.pin(p).device_name,
												pin_given			=> d.pin(p).device_pin_name,
												cell_given			=> d.pin(p).cell_info.control_cell_id,
												locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
																						-- must be in disable state
												disable_value_given				=> d.pin(p).cell_info.disable_value
												);
									end case;
								end if;
							when others => null;
						end case;

					end if; -- if pin is scan capable
				end loop;

				-- FIND SUITABLE DRIVER PIN BEGIN:
				case level is
					when primary =>
						case class is
							when DH | DL =>
								-- FIND OUTPUT PIN WITHOUT DISABLE SPEC
								-- if there is such a pin, it is to be preferred over other drivers
								drivers_without_disable_spec_ct := 0; -- reset counter for drivers without disable spec
								for p in 1..d.part_ct loop -- loop through pin list of given net
									if d.pin(p).is_bscan_capable then -- care for scan capable pins only
										-- if pin has no disable spec. (means: no control cell)
										if d.pin(p).cell_info.output_cell_id /= -1 and d.pin(p).cell_info.control_cell_id = -1 then
											add_to_locked_output_cells_in_class_DH_DL_nets(
												list				=> cell_list_locked_output_cells_in_class_DH_DL_nets_ptr,
												class_given			=> class,
												net_given			=> universal_string_type.to_bounded_string(name),
												device_given		=> d.pin(p).device_name,
												pin_given			=> d.pin(p).device_pin_name,
												cell_given			=> d.pin(p).cell_info.control_cell_id,
												drive_value_given	=> drive_value_derived_from_class(class)
												);
											d.pin(p).cell_info.selected_as_driver := true; -- mark driver as active
											-- CS: CAUTION ! MAKE SURE ATG SYNCRONIZES THOSE DRIVERS !
											drivers_without_disable_spec_ct := drivers_without_disable_spec_ct + 1;
										end if;
 									end if; -- if pin is scan capable
								end loop; -- loop through pin list of given net

								-- if output pin without disable spec found, other drivers must be found and disabled
								if drivers_without_disable_spec_ct > 0 then
									null;
									-- disable remaining drivers
								else -- no output pin without disable spec found -> other drivers must be found:

									-- FIND DRIVER WITH NON-SHARED CONTROL CELL
									for p in 1..d.part_ct loop -- loop through pin list of given net
										if d.pin(p).is_bscan_capable then -- care for scan capable pins only
											-- if pin has output cell with disable spec. (means: there is a control cell)
											if d.pin(p).cell_info.output_cell_id /= -1 and d.pin(p).cell_info.control_cell_id /= -1 then

												-- prefer non-shared control cells
												if not d.pin(p).cell_info.control_cell_shared then

													-- add control cell to list
													add_to_locked_control_cells_in_class_DH_DL_NR_nets(
														list				=> cell_list_locked_control_cells_in_class_DH_DL_NR_nets_ptr,
														class_given			=> class,
														level_given			=> level,
														net_given			=> universal_string_type.to_bounded_string(name),
														device_given		=> d.pin(p).device_name,
														pin_given			=> d.pin(p).device_pin_name,
														cell_given			=> d.pin(p).cell_info.control_cell_id,
														locked_to_enable_state_given	=> true,
														enable_value_given				=> negate_bit_character_class_0(d.pin(p).cell_info.disable_value)
														);

													-- add output cell to list
													add_to_locked_output_cells_in_class_DH_DL_nets(
														list				=> cell_list_locked_output_cells_in_class_DH_DL_nets_ptr,
														class_given			=> class,
														net_given			=> universal_string_type.to_bounded_string(name),
														device_given		=> d.pin(p).device_name,
														pin_given			=> d.pin(p).device_pin_name,
														cell_given			=> d.pin(p).cell_info.output_cell_id,
														drive_value_given	=> drive_value_derived_from_class(class)
														);

														d.pin(p).cell_info.selected_as_driver := true; -- mark driver as active
														driver_with_non_shared_control_cell_found := true;
														exit; -- no more driver search required
												end if; -- if non-shared control cell

											end if; -- if pin has output and control cell
										end if; -- if pin is scan capable
									end loop; -- loop through pin list of given net

									if driver_with_non_shared_control_cell_found then
										null;
										-- disable remaining drivers
									else
										-- FIND DRIVER WITH SHARED CONTROL CELL
										for p in 1..d.part_ct loop -- loop through pin list of given net
											if d.pin(p).is_bscan_capable then -- care for scan capable pins only
												-- if pin has output cell with disable spec. (means: there is a control cell)
												if d.pin(p).cell_info.output_cell_id /= -1 and d.pin(p).cell_info.control_cell_id /= -1 then

													-- care for shared control cells only
													if d.pin(p).cell_info.control_cell_shared then
														null;

														-- CS: TO BE DONE
														-- add output cell to list
-- 														add_to_locked_output_cells_in_class_DH_DL_nets(
-- 															list				=> cell_list_locked_output_cells_in_class_DH_DL_nets_ptr,
-- 															class_given			=> class,
-- 															net_given			=> universal_string_type.to_bounded_string(name),
-- 															device_given		=> d.pin(p).device_name,
-- 															pin_given			=> d.pin(p).device_pin_name,
-- 															cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 															drive_value_given	=> drive_value_derived_from_class(class)
-- 															);
-- 
-- 															d.pin(p).cell_info.selected_as_driver := true; -- mark driver as active
-- 															driver_with_shared_control_cell_found := true;
-- 															exit; -- no more driver search required
													end if; -- if non-shared control cell

												end if; -- if pin has output and control cell
											end if; -- if pin is scan capable
										end loop; -- loop through pin list of given net

									end if; -- if driver_with_non_shared_control_cell_found
								end if; -- if drivers_witout_disable_spec_ct > 0


							when others => null;
						end case; -- class
					when others => null; -- secondary nets never have any drivers enabled
				end case;
			end update_cell_lists;

		begin -- dump_net_content
			while d /= null loop
				if universal_string_type.to_string(d.name) = name then
					-- IC301 ? XC9536 PLCC-S44 2  pb00_00 | 107 bc_1 input x | 106 bc_1 output3 x 105 0 z
					for p in 1..d.part_ct loop
						put(spacing_from_left*row_separator_0 & universal_string_type.to_string(d.pin(p).device_name)
							& row_separator_0 & type_device_class'image(d.pin(p).device_class)
							& row_separator_0 & universal_string_type.to_string(d.pin(p).device_value)
							& row_separator_0 & universal_string_type.to_string(d.pin(p).device_package)
							& row_separator_0 & universal_string_type.to_string(d.pin(p).device_pin_name)
						);
						if d.pin(p).is_bscan_capable then
							put(row_separator_0 & universal_string_type.to_string(d.pin(p).device_port_name));
							if d.pin(p).cell_info.input_cell_id /= -1 then
								put(row_separator_1 & trim(natural'image(d.pin(p).cell_info.input_cell_id),left)
									& row_separator_0 & type_boundary_register_cell'image(d.pin(p).cell_info.input_cell_type)
									& row_separator_0 & type_cell_function'image(d.pin(p).cell_info.input_cell_function)
									& row_separator_0 & type_bit_char_class_1'image(d.pin(p).cell_info.input_cell_safe_value)(2)
									);
							end if;

							if d.pin(p).cell_info.output_cell_id /= -1 then
								put(row_separator_1 & trim(natural'image(d.pin(p).cell_info.output_cell_id),left)
									& row_separator_0 & type_boundary_register_cell'image(d.pin(p).cell_info.output_cell_type)
									& row_separator_0 & type_cell_function'image(d.pin(p).cell_info.output_cell_function)
									& row_separator_0 & type_bit_char_class_1'image(d.pin(p).cell_info.output_cell_safe_value)(2)
									);

								if d.pin(p).cell_info.control_cell_id /= -1 then
									put(row_separator_0 & trim(natural'image(d.pin(p).cell_info.control_cell_id),left)
										& row_separator_0 & type_bit_char_class_0'image(d.pin(p).cell_info.disable_value)(2)
										& row_separator_0 & type_disable_result'image(d.pin(p).cell_info.disable_result)
										);
								end if;
							end if;

							-- now that d points to the net in data base net list, the new cell list can be updated regarding this net
							update_cell_lists( d ); -- so we pass pointer d

						end if;
						new_line;
					end loop;
					exit;
				end if;
				d := d.next;
			end loop;
		end dump_net_content;

	begin -- make_new_net_list
		while o /= null loop
			new_line;
			-- write primary net header like "SubSection LED0 class NR" (name and class taken from options net list)
			put_line(column_separator_0);
			put_line(row_separator_0 & "SubSection" & row_separator_0 & universal_string_type.to_string(o.name) & row_separator_0 
				& "class" & row_separator_0 & type_net_class'image(o.class));

			-- this is a primary net. it will be searched for in the net list and its content dumped into the preliminary data base
			dump_net_content(
				name => universal_string_type.to_string(o.name), 
				level => primary,
				class => o.class,
				spacing_from_left => 2
				);

			-- put end of primary net mark
			put_line(row_separator_0 & "EndSubSection");

			-- if there are secondary nets specified in options net list, dump them one by one into the preliminary data base
			if o.has_secondaries then
				put_line(row_separator_0 & "SubSection secondary_nets_of" & row_separator_0 & universal_string_type.to_string(o.name));
				new_line;
				for s in 1..o.secondary_net_count loop
					put_line(2*row_separator_0 & "SubSection" & row_separator_0 & universal_string_type.to_string(o.list_of_secondary_net_names(s)));
					dump_net_content(
						name => universal_string_type.to_string(o.list_of_secondary_net_names(s)),
						level => secondary,
						primary_net_is => o.name, -- required for writing some cell lists where reference to primary net is required
						class => o.class, 
						spacing_from_left => 4
						);
					put_line(2*row_separator_0 & "EndSubSection");
					new_line;
				end loop;
				put_line(row_separator_0 & "EndSubSection secondary_nets_of" & row_separator_0 & universal_string_type.to_string(o.name));
				put_line(column_separator_0);
				new_line;
			end if;

			o := o.next;
		end loop;
	end make_new_net_list;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin


	new_line;
	put("primary/secondary/class builder "& version); new_line;

	data_base := universal_string_type.to_bounded_string(Argument(1));
	put_line ("data base      : " & universal_string_type.to_string(data_base));

	options_file := universal_string_type.to_bounded_string(Argument(2));
	put_line ("options file   : " & universal_string_type.to_string(options_file));

	if argument_count = 3 then
		debug_level := natural'value(argument(3));
		put_line ("debug level    :" & natural'image(debug_level));
	end if;

	-- make backup of given udb
	
	-- recreate an empty tmp directory
	m1.clean_up_tmp_dir;

	read_data_base;
	

	-- open options file
	open( 
		file => opt_file,
		mode => in_file,
		name => universal_string_type.to_string(options_file)
		);

	-- find primary net in options file	
	put_line("reading options file ...");
	Set_Input(opt_file); -- set data source
	while not end_of_file
		loop
			prog_position := "OP5000";
			line_counter := line_counter + 1;
			line_of_file := extended_string.to_bounded_string(get_line);
			line_of_file := remove_comment_from_line(line_of_file);

			if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything
				if debug_level >= 40 then
					put_line(extended_string.to_string(line_of_file));
				end if;

				if primary_net_section_entered then
					-- we are inside primary net section

					if secondary_net_section_entered then
						-- we are inside secondary net section

						-- wait for end of secondary net section mark
						if to_upper(get_field_from_line(line_of_file,1)) = type_end_of_subsection_mark'image(EndSubSection) then
							secondary_net_section_entered := false;
							if secondary_net_count = 0 then
								put_line("WARNING: Primary net '" & extended_string.to_string(name_of_current_primary_net) 
									& "' has an empty secondary net subsection !");
							end if;

						-- count secondary nets and collect them in array list_of_secondary_net_names
						--if to_upper(get_field_from_line(line_of_file,1)) = type_options_net_identifier'image(net) then
						elsif to_upper(get_field_from_line(line_of_file,1)) = type_options_net_identifier'image(net) then
							secondary_net_count := secondary_net_count + 1;
							list_of_secondary_net_names(secondary_net_count) := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						else
							prog_position := "OP5100";
 							put_line("ERROR: Keyword '" & type_secondary_net_name_identifier'image(net) & "' or '"
								& type_end_of_subsection_mark'image(EndSubSection) & "' expected !");
 							raise constraint_error;
						end if;
					else
						-- wait for end of primary net section
						if to_upper(get_field_from_line(line_of_file,1)) = type_end_of_section_mark'image(EndSection) then
							primary_net_section_entered := false;

							-- when end of primary net section reached:
							if debug_level >= 10 then
								new_line;
								put_line("primary net name    : " & extended_string.to_string(name_of_current_primary_net));
								put_line("primary net class   : " & type_net_class'image(class_of_current_primary_net));
								if secondary_net_count > 0 then
									put_line("secondary net count :" & natural'image(secondary_net_count));
									put("secondary nets      : ");
									for s in 1..secondary_net_count loop
										put(universal_string_type.to_string(list_of_secondary_net_names(s)) & row_separator_0);
									end loop;
									new_line;
								end if;
							end if;

							-- ask if the primary net (incl. secondary nets) may become member of class specified in options file
							-- if class request can be fulfilled, add net to options net list
							prog_position := "OP5200";
							if m1_internal.query_render_net_class (
								primary_net_name => extended_string.to_string(name_of_current_primary_net),
								primary_net_class => class_of_current_primary_net,
								list_of_secondary_net_names	=> list_of_secondary_net_names,
								secondary_net_count	=> secondary_net_count
								) then 
									prog_position := "OP5300";
									add_to_options_net_list(
										list 								=> options_net_ptr,
										name_given							=> extended_string.to_string(name_of_current_primary_net),
										class_given							=> class_of_current_primary_net,
										secondary_net_ct_given				=> secondary_net_count,
										list_of_secondary_net_names_given	=> list_of_secondary_net_names
									);
									
							end if;
							secondary_net_count := 0; -- reset secondary net counter for next primary net

						-- if not secondary_net_section_entered yet, wait for "SubSection secondary_nets" header
						-- if "SubSection secondary_nets" found, set secondary_net_section_entered flag
						elsif to_upper(get_field_from_line(line_of_file,1)) = type_start_of_subsection_mark'image(SubSection) and
							to_upper(get_field_from_line(line_of_file,2)) = type_secondary_nets_section_identifier'image(secondary_nets) then
								secondary_net_section_entered := true;
						else
							prog_position := "OP5400";
 							put_line("ERROR: Keywords '" & type_start_of_subsection_mark'image(SubSection) 
								& " " & type_secondary_nets_section_identifier'image(secondary_nets)
								& "' or '" & type_end_of_section_mark'image(EndSection)
								& "' expected !");
 							raise constraint_error;
						end if;
					end if;


				-- if primary net section not entered, wait for primary net header like "Section LED0 class NR", 
				-- then set "primary net section entered" flag
				elsif to_upper(get_field_from_line(line_of_file,1)) = type_start_of_section_mark'image(Section) then
					name_of_current_primary_net := extended_string.to_bounded_string(get_field_from_line(line_of_file,2));
					if to_upper(get_field_from_line(line_of_file,3)) = type_options_class_identifier'image(class) then
						null; -- fine
					else
						prog_position := "OP5500";
						put_line("ERROR: Identifier '" & type_options_class_identifier'image(class) & "' expected after primary net name !");
						raise constraint_error;
					end if;
					class_of_current_primary_net := type_net_class'value(get_field_from_line(line_of_file,4));
					primary_net_section_entered := true;
				else
					prog_position := "OP5600";
					put_line("ERROR: Keyword '" & type_start_of_section_mark'image(Section) & "' expected !");
					raise constraint_error;
				end if;

			end if;

		end loop;

	set_input(standard_input);
	close(opt_file);
	-- options net list ready. pointer options_net_ptr points to list !
	-- data base net list ready, pointer net_ptr points to list !

-- CS: compare net numbers ?
--	put_line("comparing net count");
--	if total_options_net_count < udb_summary.net_count_statistics.total then
--		put_line("WARNING: Number of nets found in options file differs from number those in data base !");
		put_line("options net count   : " & natural'image(total_options_net_count));
		put_line("data base net count : " & natural'image(udb_summary.net_count_statistics.bs_testable));
--	end if;

	-- extract from current udb the sections "scanpath_configuration" and "registers" in preliminary data base
	prog_position := "EX0000";
	--create( data_base_file_preliminary, name => "tmp/" & universal_string_type.to_string(data_base) );
	create( data_base_file_preliminary, name => "tmp/test.udb" );
	--set_output( data_base_file_preliminary); -- set data sink

	-- open data base file
	prog_position := "EX0500";
	open( 
		file => data_base_file,
		mode => in_file,
		name => universal_string_type.to_string(data_base)
		);

	set_input(data_base_file); -- set data source
	set_output(data_base_file_preliminary); -- set data sink
	prog_position := "EX1000";
	line_counter := 0;
	while line_counter <= udb_summary.line_number_end_of_section_registers
		loop
			prog_position := "EX2000";
			line_counter := line_counter + 1;
			line_of_file := extended_string.to_bounded_string(get_line);
			prog_position := "EX2100";
			put_line(extended_string.to_string(line_of_file));
		end loop;
	prog_position := "EX2200";
	set_input(standard_input);
	close(data_base_file);


	put_line("Section netlist");
	put_line(column_separator_0);
	put_line("-- modified by primary/secondary/class builder version " & version);
	put_line("-- date: " & date_now & " (YYYY-MM-DD HH:MM:SS)");
	new_line(2);

	make_new_net_list;


	close(data_base_file_preliminary);

	exception
		when others =>
			put_line("ERROR in options file in line :" & natural'image(line_counter));
--			put_line("affected line reads        : " & trim(to_string(line_of_file),both));
			put_line("ERROR at program position     : " & prog_position);

end chkpsn;
