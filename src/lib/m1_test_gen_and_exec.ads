-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 TEST GENERATION AND EXECUTION              --
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

with ada.text_io;				use ada.text_io;
with ada.strings.bounded; 		use ada.strings.bounded;
with m1_database;				use m1_database;
with m1_files_and_directories;	use m1_files_and_directories;
with m1_numbers;				use m1_numbers;
with m1_firmware;				use m1_firmware;

package m1_test_gen_and_exec is

-- TEST PROFILE
	type type_test_profile is ( 
		infrastructure,		-- verifies the scanpath integrity
		interconnect,		-- verifies interconnections and pull resistors
		memconnect,			-- verifies interconnections to memories or clusters
		toggle,				-- toggles a pin
		clock				-- verifies if a net is toggeling
		);
	test_profile 	: type_test_profile;

	text_test_name : constant string (1..9) := "test name";

-- 	test_name_length : constant natural := 200; -- CS: should be sufficient
--  	package type_test_name is new generic_bounded_length(test_name_length); use type_test_name;
-- 	test_name : type_test_name.bounded_string;
	
	type result_test_type is ( pass, fail, not_loaded, internal_error); -- CS: rename
	result_test 	: result_test_type := fail;

	type type_port_vector is
		record
			name	: type_port_name.bounded_string; -- CS: rename
			msb		: natural := 0;
			lsb		: natural := 0;
			length	: positive := 1;
			--mirrored: boolean := false; -- CS: not used yet
		end record;

	delay_max 						: constant float := 25.5;
 	delay_resolution				: constant float := 0.1; -- seconds
	subtype type_delay_value is float range 0.0..delay_max; -- CS: range 0.02..delay_max ?
	delay_set_by_operator			: type_delay_value;

	-- power monitor
	timeout_identifier				: constant string (1..7) := "timeout";
	current_max						: constant float := 4.0; -- amps
	subtype type_current_max is float range 0.1..current_max;
	current_limit_set_by_operator	: type_current_max := type_current_max'first;
	overload_timeout_max 			: constant type_delay_value := 5.0; -- seconds
	overload_timeout_min 			: constant float := 0.02; -- seconds -- CS: use type_delay_value instead of float
	overload_timeout_resolution 	: constant float := 0.02; -- seconds -- CS: use type_delay_value instead of float
	subtype type_overload_timeout is float range overload_timeout_min..overload_timeout_max; -- CS: use type_delay_value instead of float
	overload_timeout				: type_overload_timeout := type_overload_timeout'first;

	type type_sequence_instruction_set is
		record
			set 		: string (1..3) := "set";
-- 			sdr 		: string (1..3) := "sdr";
-- 			sir 		: string (1..3) := "sir";
			dely		: string (1..5) := "delay";
			power		: string (1..5) := "power";
			imax		: string (1..4) := "imax";
			connect 	: string (1..7)  := "connect";
			disconnect	: string (1..10) := "disconnect";
			trst 		: string (1..4) := "trst";
			strst 		: string (1..5) := "strst";
			htrst 		: string (1..5) := "htrst";
			tap_state 	: string (1..9) := "tap_state";
		end record;
	sequence_instruction_set : type_sequence_instruction_set;

	type type_sxr_option is
		record
			option		: string (1..6) := "option";
			retry		: string (1..5) := "retry";
			dely		: string (1..5) := "delay";
		end record;
	sxr_option : type_sxr_option;

	-- sxr option "retry" -- example: sdr id 4 option retry 10 delay 1
	sxr_retries_max : constant positive := 100;
	subtype type_sxr_retries is positive range 1..sxr_retries_max;
	retry_count : type_sxr_retries;
	retry_delay : type_delay_value;

	type type_cycle_count is new positive;
	cycle_count : type_cycle_count;

	low_time, high_time : type_delay_value;

	type type_tap_state is
		record
			test_logic_reset	: string (1..16) := "test-logic-reset";
			run_test_idle		: string (1..13) := "run-test/idle";
			pause_dr			: string (1..8)  := "pause-dr";
			pause_ir			: string (1..8)  := "pause-ir";
		end record;
	tap_state : type_tap_state;

	type type_sxr_io_identifier is
		record
			drive	: string (1..3) := "drv";
			expect	: string (1..3) := "exp";
		end record;
	sxr_io_identifier : type_sxr_io_identifier;

	type type_sir_target_register is
		record
			ir		: string (1..2) := "ir";
		end record;
	sir_target_register : type_sir_target_register;

	type type_sdr_target_register is
		record
			bypass		: string (1..6) := "bypass";
			boundary	: string (1..8) := "boundary";
			idcode		: string (1..6) := "idcode";
			usercode	: string (1..8) := "usercode";
		end record;
	sdr_target_register : type_sdr_target_register;

	type type_sxr_vector_orientation is
		record
			to			: string (1..2) := "to";
			downto		: string (1..6) := "downto";
		end record;
	sxr_vector_orientation : type_sxr_vector_orientation;

	type type_scanport_identifier is
		record
			port		: string (1..4) := "port";
		end record;
	scanport_identifier	: type_scanport_identifier;

	type type_power_cycle_identifier is
		record
			up			: string (1..2) := "up";
			down		: string (1..4) := "down";
		end record;
	power_cycle_identifier	: type_power_cycle_identifier;

	-- power monitor
	power_channel_ct: constant positive := 3; -- number of available power monitor channels
	subtype type_power_channel_id is positive range 1..power_channel_ct;
	type type_power_channel_name is
		record
			all_channels	: string (1..3) := "all";
			gnd				: string (1..3) := "gnd";
			id				: type_power_channel_id;
		end record;
	power_channel_name : type_power_channel_name;

	type type_sxr_assignment_operator is
		record
			assign		: string (1..1) := "="; -- CS: change to ":="
		end record;
	sxr_assignment_operator : type_sxr_assignment_operator;

	type type_sxr_id_identifier is
		record
			id			: string (1..3) := " id";
		end record;
	sxr_id_identifier : type_sxr_id_identifier;

	comment : string (1..2) := "--";

	type type_end_sir is ( RTI , PIR);
	type type_end_sdr is ( RTI , PDR);
	
	type type_step_mode is (off, sxr, tck);
	step_mode_count	: natural := type_step_mode'pos((type_step_mode'last)); -- number of allowed step modi
	step_mode	  	: type_step_mode := off;

    tap_test_logic_reset            	: constant string (1..16) := "Test-Logic-Reset";
    tap_run_test_idle               	: constant string (1..13) := "Run-Test/Idle";
    tap_select_dr_scan              	: constant string (1..14) := "Select-DR-Scan";
    tap_capture_dr          	        : constant string (1..10) := "Capture-DR";
    tap_shift_dr                    	: constant string (1..8)  := "Shift-DR";
	tap_exit1_dr 	                   	: constant string (1..8)  := "Exit1-DR";
    tap_pause_dr                    	: constant string (1..8)  := "Pause-DR";
    tap_exit2_dr                    	: constant string (1..8)  := "Exit2-DR";
    tap_update_dr                   	: constant string (1..9)  := "Update-DR";   
    tap_select_ir_scan              	: constant string (1..14) := "Select-IR-Scan";
    tap_capture_ir                  	: constant string (1..10) := "Capture-IR";
    tap_shift_ir                    	: constant string (1..8)  := "Shift-IR";
    tap_exit1_ir                    	: constant string (1..8)  := "Exit1-IR";
    tap_pause_ir                    	: constant string (1..8)  := "Pause-IR";
    tap_exit2_ir                    	: constant string (1..8)  := "Exit2-IR";
    tap_update_ir                   	: constant string (1..9)  := "Update-IR";
	
	vector_count_max		: constant positive := (2**16)-1;
	subtype type_vector_id is positive range 1..vector_count_max;
	sxr_ct : type_vector_id := 1; -- CS: might become obsolete when container used to store sxr
	subtype type_vector_id_breakpoint is natural range 0..vector_count_max; -- zero included (required when clearing the breakpoint)
	break_sxr_position	: type_vector_id_breakpoint;	
	
	subtype type_vector_length is positive range 1..vector_length_max;
	subtype type_sxr_fail_position is natural range 0..vector_length_max-1; -- zero-based
	subtype type_sxr_break_position is natural range 0..vector_length_max-1; -- zero-based
	break_bit_position : type_sxr_break_position := 0; -- in case bit_position to break at is not provided, default used
	sequence_count_max	: constant positive := 1;

-- COMPILER RELATED BEGIN

-- 	register_file_prefix	: string (1..8) := "members_";
-- 	register_file_suffix	: string (1..4) := ".reg";


	type type_section_info_item is -- also used by test generators when writing "section info"
		record
			date			: string (1..4)  := "date";
			database		: string (1..8)  := "database";
			name_test		: string (1..9)  := "test_name";
			test_profile	: string (1..12) := "test_profile";
			end_sdr			: string (1..7)  := "end_sdr";
			end_sir			: string (1..7)  := "end_sir";
			target_net		: string (1..10) := "target_net";
			cycle_count		: string (1..11) := "cycle_count";
			high_time		: string (1..9)  := "high_time";
			low_time		: string (1..8)  := "low_time";
			frequency		: string (1..9)  := "frequency";
			target_device	: string (1..13) := "target_device";
			target_pin		: string (1..10) := "target_pin";
			retry_count		: string (1..11) := "retry_count";
			retry_delay		: string (1..11) := "retry_delay";
		end record;
	section_info_item : type_section_info_item;

	type type_section_scanpath_options_item is -- CS: make use of it when reading data base in function read_uut_data_base
		record
			on_fail		: string (1..7)  := "on_fail";
			frequency	: string (1..9)  := "frequency";
			trailer_dr	: string (1..10) := "trailer_dr";
			trailer_ir	: string (1..10) := "trailer_ir";

			voltage_out_port_1	: string (1..18) := "voltage_out_port_1";
			tck_driver_port_1	: string (1..17) := "tck_driver_port_1";
			tms_driver_port_1	: string (1..17) := "tms_driver_port_1";
			tdo_driver_port_1	: string (1..17) := "tdo_driver_port_1";
			trst_driver_port_1	: string (1..18) := "trst_driver_port_1";
			threshold_tdi_port_1: string (1..20) := "threshold_tdi_port_1";

			voltage_out_port_2	: string (1..18) := "voltage_out_port_2";
			tck_driver_port_2	: string (1..17) := "tck_driver_port_2";
			tms_driver_port_2	: string (1..17) := "tms_driver_port_2";
			tdo_driver_port_2	: string (1..17) := "tdo_driver_port_2";
			trst_driver_port_2	: string (1..18) := "trst_driver_port_2";
			threshold_tdi_port_2: string (1..20) := "threshold_tdi_port_2";
		end record;
	section_scanpath_options_item : type_section_scanpath_options_item;

	type type_test_info is
		record
			test_name		: type_name_test.bounded_string;
			test_name_valid	: boolean := false;
			database		: type_name_database.bounded_string;
			database_valid	: boolean := false;
			end_sdr			: type_end_sdr := RTI;
			end_sir			: type_end_sir := RTI;
		end record;

	type type_test_section is
		record
			info		: string (1..4)  := "info";
			options		: string (1..7)  := "options";
			sequence	: string (1..8)  := "sequence";
		end record;
	test_section : type_test_section;
	
	type type_scan is ( SIR, SDR );

	type type_set_direction is ( DRV, EXP );
	type type_set_target_register is ( IR, BOUNDARY, BYPASS, IDCODE, USERCODE );
	type type_set_assigment_method is ( BIT_WISE, REGISTER_WISE);
	type type_set_vector_orientation is ( downto, to );

	
-- ATG memory connect
	function fraction_port_name(port_name_given : string) return type_port_vector;
	-- breaks down something line A[14:0] into the components name=A, msb=14, lsb=0 and length=15
	-- if a single port given like 'CE', the components are name=CE, msb=0, lsb=0 and length=1

-- TEST STATUS
	function test_compiled (name_test : string) return boolean;
	-- Returns true if given test directory contains a vector file.
	-- name_test is assumed as absolute path !

	function valid_script (name_script : string) return boolean;
	-- Returns true if given script is valid.

	function valid_project (name_project : string) return boolean;
	-- Returns true if given project is valid.
	-- name_project is assumed as absolute path !

	procedure create_test_directory (test_name : in type_name_test.bounded_string);

	procedure write_diagnosis_netlist
		-- Creates a netlist file in test directory.
		-- The fail diagnosis bases on this netlist.
		(
		database	: type_name_database.bounded_string;
		test		: type_name_test.bounded_string
		);

	procedure write_test_section_options;
	-- writes section for options of test

	procedure write_test_init;
	-- append test init template file line by line to seq file

	procedure write_end_of_test;

	procedure write_sir(with_new_line : boolean := true);
	-- writes something like "sir id 6", increments sxr_ct, by default adds a line break

	procedure write_sdr(with_new_line : boolean := true);
	-- writes something like "sdr id 6", increments sxr_ct, by default adds a line break

	procedure all_in(instruction : type_bic_instruction);
	-- writes something like "set IC301 drv ir 7 downto 0 = 00000001 sample" for all bics

	procedure write_ir_capture;
	-- writes something like "set IC301 exp ir 7 downto 0 = 000XXX01" for all bics

	procedure load_safe_values;
	-- writes something like "set IC303 drv boundary 17 downto 0 = X1XXXXXXXXXXXXXXXX"

	procedure load_static_drive_values;
	-- writes something like "set IC303 drv boundary 16=0 16=0 16=0 16=0 17=0 17=0 17=0 17=0"

	procedure load_static_expect_values;
	-- writes something like " set IC300 exp boundary 14=0 11=1 5=0"
	
	procedure put_warning_on_too_many_parameters(line_number : positive);

	type type_set_cell_assignment is
		record
			cell_id		: type_cell_id;
			value		: type_bit_char_class_1;
		end record;
	
	function get_cell_assignment (text_in : string) return type_set_cell_assignment;
	-- fractions a given string like 102=1 into cell id and value

	function get_test_base_address (test_name : type_name_test.bounded_string) return string;

	function set_breakpoint
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string;
		vector_id_breakpoint		: in type_vector_id_breakpoint;
		bit_position				: in type_sxr_break_position
		) return boolean;
	
	function execute_test
		(
		test_name					: in type_name_test.bounded_string;
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string;
		step_mode					: in type_step_mode
		) return result_test_type;

	function load_test
	-- Uploads a given test (vector file) in the BSC. Returns true if successful.
	-- Uses the page write mode when transferring the actual data.
		(
		test_name					: in type_name_test.bounded_string;
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string
		) return boolean;
	
	function dump_ram
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string;
		mem_addr					: in type_mem_address_byte
		) return boolean;

	function clear_ram
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string
		) return boolean;

	function show_firmware
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string
		) return boolean;

	procedure read_bsc_status_registers
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string;
		display 					: in boolean := false
		);
	-- reads all bsc status registers

	function query_status
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string
		) return boolean;

	function shutdown
		(
		interface_to_scan_master	: in type_interface_to_bsc.bounded_string
		) return boolean;

	function test_compiled (name_test : in type_name_test.bounded_string) return boolean;
	-- Returns true if given test directory contains a vector file.
	-- name_test is assumed as absolute path !
	
end m1_test_gen_and_exec;
