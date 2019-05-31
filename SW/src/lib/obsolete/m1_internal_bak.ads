-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 INTERNAL COMPONENTS                        --
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
--   Mario.Blunk@blunk-electronic.de
--   or visit <http://www.blunk-electronic.de> for more contact data
--
--   history of changes:
--		2016-09-28: cleaned up, made bounded string lengths constant

with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;
with ada.text_io;				use ada.text_io;
with ada.float_text_io;			use ada.float_text_io;

with ada.containers;            use ada.containers;
with ada.containers.indefinite_vectors;

with interfaces;				use interfaces;
with ada.exceptions;

with ada.calendar;				use ada.calendar;
with ada.calendar.formatting;	use ada.calendar.formatting;
with ada.calendar.time_zones;	use ada.calendar.time_zones;

with ada.containers.ordered_sets;
with m1_firmware; 				use m1_firmware;
with m1_numbers; 				use m1_numbers;

package m1_internal is
	name_system		: constant string (1..29) := "BOUNDARY SCAN TEST SYSTEM M-1";
	name_bsc		: constant string (1..24) := "Boundary Scan Controller";

-- 	now				: time := clock;
-- 	date_now		: string (1..19) := image(now, time_zone => utc_time_offset(now));
	--debug_level		: natural := 0;

--  	universal_string_length	: constant natural := 100;
--  	package universal_string_type is new generic_bounded_length(universal_string_length); use universal_string_type;
-- 	extended_string_length	: constant natural := 20000;
-- 	package extended_string is new generic_bounded_length(extended_string_length); use extended_string;
-- 	short_string_length		: constant natural := 5;
--  	package type_short_string is new generic_bounded_length(short_string_length); use type_short_string;

	type type_language is (german, english);
	language 	: type_language := english;

	-- general variables & types

	-- OPERATOR ACTIONS
	type type_action is ( 
		--HELP,
		CONFIGURATION,
		CREATE,
		IMPORT_CAD, -- CS: update manual
		MKVMOD, -- CS: update manual
		IMPORT_BSDL, -- CS: update manual
		JOIN_NETLIST,
		MKNETS,
		CHKPSN,
		MKOPTIONS,
		GENERATE,
		COMPILE,
		LOAD,
		DUMP,
		OFF,
		CLEAR,
		RUN,
		BREAK,
		--REPORT, CS
		UDBINFO,
		STATUS,
		FIRMWARE
		);
	action			: type_action;

	-- CAD / NETLIST / PARTLIST IMPORT
	type type_format_cad is (
		EAGLE,
		ORCAD,
		PROTEL,
		ZUKEN
		);
	format_cad		: type_format_cad;
	type type_cad_import_target_module is ( main , sub );
	cad_import_target_module : type_cad_import_target_module;
	target_module_prefix : universal_string_type.bounded_string;
	

-- 	-- TEST PROFILE
-- 	type type_test_profile is ( infrastructure, interconnect, memconnect, toggle, clock );
-- 	test_profile 	: type_test_profile;


--	action			: type_action;
-- 	action_request_help		: constant string (1..4) := "help";
-- 	action_create_project	: constant string (1..6) := "create";
-- 	action_set_breakpoint	: constant string (1..5) := "break";

-- 	-- DATABASE INFO ITEMS
-- 	type type_item_udbinfo is ( 
-- 		BIC,
-- 		--REGISTER, -- CS
-- 		NET,
-- 		--PIN, -- CS
-- 		SCC -- shared control cell
-- 		);


	-- VARIABLE NAMES OF PROJECT, TEST, TARGET, PACKAGE
	name_project			: universal_string_type.bounded_string; -- name of current project/uut/target
	name_project_previous	: universal_string_type.bounded_string; -- name of previous project
	-- Required to detect when the operator changes the project. On changing the project the bsc ram must
	-- be cleared.

	name_script		: universal_string_type.bounded_string;
	name_test		: universal_string_type.bounded_string;

	target_device	: universal_string_type.bounded_string;
	target_pin		: universal_string_type.bounded_string;
	target_net		: universal_string_type.bounded_string;
    device_package	: universal_string_type.bounded_string;


	-- FREQUENTLY USED WORDS, PHRASES, ...
	text_name_cad_net_list			: constant string (1..7) := "netlist";
	text_name_cad_part_list			: constant string (1..8) := "partlist";

	bscan_standard_1				: constant string (1..10) := "IEEE1149.1";
	bscan_standard_4				: constant string (1..10) := "IEEE1149.4";
	bscan_standard_7				: constant string (1..10) := "IEEE1149.7";

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
	text_bsdl_of					: constant string (1..2)  := "of";
	text_bsdl_port_identifier		: constant string (1..4)  := "port";
	text_bsdl_bit_vector			: constant string (1..10) := "bit_vector";
	text_bsdl_to					: constant string (1..2)  := "to";
	text_bsdl_downto				: constant string (1..6)  := "downto";
	text_bsdl_bit					: constant string (1..3)  := "bit";
	text_bsdl_constant				: constant string (1..8)  := "constant";

	-- UDB keywords
	text_udb_class							: constant string (1..5) := "class";
	text_udb_option							: constant string (1..6) := "option";	
	text_udb_none							: constant string (1..4) := "none";
	text_udb_instruction_register_length 	: constant string (1..27) := "instruction_register_length";
	text_udb_boundary_register_length		: constant string (1..24) := "boundary_register_length";
	text_udb_trst_pin						: constant string (1..8) := "trst_pin";
	text_udb_available						: constant string (1..9) := "available";
	text_udb_safebits						: constant string (1..8) := "safebits";
	text_udb_opcodes						: constant string (1..19) := "instruction_opcodes";
	text_udb_port_io_map					: constant string (1..11) := "port_io_map";
	text_udb_port_pin_map					: constant string (1..12) := "port_pin_map";

	-- SKELETON keywords
	text_skeleton_section_netlist			: constant string (1..16) := "netlist_skeleton";

	skeleton_field_count_pin				: constant positive := 5; -- "RN402 ? 8x10k SIL9 6"
	
-- 	quote_single		: constant string (1..1) := "'";
-- 	dot					: constant string (1..1) := ".";
-- 	exclamation			: constant string (1..1) := "!";
-- 	done				: constant string (1..7) := "...done";
-- 	aborting			: constant string (1..11) := "Aborting...";
-- 	message_error		: constant string (1..7) := "ERROR: ";
-- 	message_warning		: constant string (1..9) := "WARNING: ";
-- 	message_note		: constant string (1..6) := "NOTE: ";
-- 	message_example		: constant string (1..9) := "Example: ";
-- 	passed				: constant string (1..6) := "PASSED";
-- 	failed				: constant string (1..6) := "FAILED";
-- 	successful			: constant string (1..10):= "successful";
-- 	running				: constant string (1..7) := "RUNNING";
-- 	aborted				: constant string (1..7) := "ABORTED";
-- 	--quote_double		: constant string (1..1) := """;
-- 	row_separator_0		: constant string (1..1) := " ";
-- 	row_separator_1		: constant string (1..3) := " | ";
-- 	row_separator_1a	: constant string (1..1) := "|";
-- 	column_separator_0	: constant string (1..100) := (100 * "-");
-- 	column_separator_1	: constant string (1..100) := ("--" & 98 * "=");
-- 	column_separator_2	: constant string (1..100) := (100 * "=");

-- 	type type_bic_option is (REMOVE_PIN_PREFIX);
-- 
-- 	type type_device_class is ('?', R, C, L, X, J, T, D, LED, IC, RN , S, TF);
-- 	device_class_default : constant type_device_class := '?';
-- 	type type_net_level is (PRIMARY, SECONDARY);
-- 	type type_net_class is ( NA, NR, DH, DL, PD, PU, EH, EL );
-- 	net_class_default : constant type_net_class := NA;
-- 	type type_logic_level_as_word is (LOW, HIGH);

-- 	package binary_io_class_0 is new ada.text_io.enumeration_io (enum => type_bit_char_class_0);
-- 	package binary_io_class_1 is new ada.text_io.enumeration_io (enum => type_bit_char_class_1);
-- 	package binary_io_class_2 is new ada.text_io.enumeration_io (enum => type_bit_char_class_2);

-- 	vector_count_max		: constant positive := (2**16)-1;
-- 	subtype type_vector_id is positive range 1..vector_count_max;
-- 	subtype type_vector_id_breakpoint is natural range 0..vector_count_max; -- zero included (required when clearing the breakpoint)
-- 
-- 	vector_length_max		: constant positive := (2**16)-1; -- CS: machine dependend and limited here to a reasonable value
-- 	subtype type_vector_length is positive range 1..vector_length_max;
-- 	subtype type_sxr_fail_position is natural range 0..vector_length_max-1; -- zero-based
-- 	subtype type_sxr_break_position is natural range 0..vector_length_max-1; -- zero-based

-- 	subtype type_cell_id is natural range 0..vector_length_max;
-- 	subtype type_register_length is integer range 1..vector_length_max; -- a register is at least one bit long
-- 	subtype type_control_cell_id is integer range -1..vector_length_max; -- if -1, no control cell connected to the particular cell (mostly an ouput cell)
-- 	port_index_max			: constant positive := 255; -- CS: assumed that larger ports are not used. increase if nessecary
-- 	subtype type_port_index is integer range -1..port_index_max; -- if -1, port is not indexed


-- 	bic_count_max 					: constant natural := 20; -- should be sufficient for most uuts
-- 	bic_idcode_register_length 		: constant type_register_length := 32; -- defined by standard
-- 	bic_usercode_register_length 	: constant type_register_length := 32; -- defined by standard
-- 	bic_bypass_register_length 		: constant type_register_length := 1; -- defined by standard
-- 	type type_bic_instruction is ( BYPASS, SAMPLE, PRELOAD, IDCODE, USERCODE, EXTEST, INTEST, HIGHZ, CLAMP);
-- 	subtype type_bic_instruction_for_infra_structure is type_bic_instruction range BYPASS .. EXTEST;
-- 	type type_bic_data_register is ( BYPASS, BOUNDARY, IDCODE, USERCODE );
-- 	type type_bic_optional_register_present is ( no, none, false );

-- 	subtype type_bic_idcode is type_string_of_bit_characters_class_1 (1..bic_idcode_register_length);
-- 	bic_idcode : type_bic_idcode := (others => 'x');
-- 	subtype type_bic_usercode is type_string_of_bit_characters_class_1 (1..bic_usercode_register_length);
-- 	bic_usercode : type_bic_usercode := (others => 'x');
-- 	type type_trst_pin_present is (none, no, false, yes, true, present, available);
-- 	bic_trst_present : boolean;

-- 	type type_boundary_register_cell is ( BC_0, BC_1, BC_2, BC_3, BC_4, BC_5, BC_6, BC_7, BC_8, BC_9, BC_10 );
-- 	type type_cell_function is (INTERNAL, INPUT, OUTPUT2, OUTPUT3, CONTROL, CONTROLR, CLOCK, BIDIR, OBSERVE_ONLY);
-- 	type type_disable_result is (Z, WEAK0, WEAK1, PULL0, PULL1, KEEPER);

-- 	type type_bit_of_boundary_register;
-- 	type type_ptr_bit_of_boundary_register is access all type_bit_of_boundary_register;
-- 	type type_bit_of_boundary_register is
-- 		record
-- 			next			: type_ptr_bit_of_boundary_register;
-- 			id				: type_cell_id;
-- 			appears_in_net_list : boolean := false;
-- 			cell_type		: type_boundary_register_cell; -- like BC_1;
-- 			port			: universal_string_type.bounded_string; -- like Y2(4)
-- 			cell_function	: type_cell_function; -- like INTERNAL or output3
-- 			cell_safe_value	: type_bit_char_class_1; -- 'x'
-- 			control_cell_id	: type_control_cell_id; -- may also be -1 which means: no control cell assigned to a particular cell
-- 			-- CS: control_cell_shared : boolean; -- this would speed up the shared control cell check in function shared_control_cell
-- 			disable_value	: type_bit_char_class_0; -- := '1';
-- 			disable_result	: type_disable_result;
-- 		end record;
-- 	ptr_bsr : type_ptr_bit_of_boundary_register;

-- 	port_direction_in		: constant string (1..2) := "in";
-- 	port_direction_out		: constant string (1..3) := "out";
-- 	port_direction_inout	: constant string (1..5) := "inout";
-- 	port_direction_linkage	: constant string (1..7) := "linkage";
-- 	--CS :port_direction_buffer	: string (1..7) := "buffer";
-- 	type type_port_direction is ( INPUT, OUTPUT, INOUT, LINKAGE ); -- CS: BUFFER ?
-- 	type type_vector_orientation is (TO, DOWNTO);
-- 	port_ifs 				: constant string (1..1) := ":";

-- 	type type_port;
-- 	type type_ptr_port is access all type_port;
-- 	type type_port is -- this is the port_io_map
-- 		-- CS: verify the port has not been used yet
-- 		record
-- 			next				: type_ptr_port;
-- 			name				: universal_string_type.bounded_string; -- the port name like PB01_04
-- 			direction			: type_port_direction;
-- 			index_start			: natural; -- start is always the number found before (do/downto) !
-- 			index_end			: natural; -- end   is always the number found after  (do/downto) !
-- 			vector_length		: positive;
-- 			is_vector			: boolean;
-- 			vector_orientation	: type_vector_orientation;  -- like "to" or "downto"
-- 		end record;
-- 	ptr_bic_port_io_map : type_ptr_port;
-- 
-- 	type type_port_pin; -- this is the port_pin_map
-- 	type type_ptr_port_pin is access all type_port_pin;
-- 	
-- 	type type_list_of_pin_names is array (natural range <>) of type_short_string.bounded_string; -- CS: change to a smaller string
-- 	port_vector_size_max : constant positive := 200; -- CS: increase in case a port vector is greater than 200
-- 	subtype list_of_pin_names is type_list_of_pin_names (1..port_vector_size_max);
-- 	type type_port_pin is
-- 		record
-- 			next					: type_ptr_port_pin;
-- 			port_name				: universal_string_type.bounded_string;
-- 			pin_count				: positive;
-- 			pin_names				: list_of_pin_names; -- this is an array of pin names
-- 		end record;
-- 	ptr_bic_port_pin_map : type_ptr_port_pin;
-- 
-- --  	type type_bscan_ic_pre;
-- --  	type type_ptr_bscan_ic_pre is access all type_bscan_ic_pre;
--  	type type_bscan_ic_pre is
--  		record
-- --			next				: type_ptr_bscan_ic_pre;
-- 			name				: universal_string_type.bounded_string;
-- 			housing				: universal_string_type.bounded_string;
-- 			model_file			: extended_string.bounded_string;
-- 			options				: universal_string_type.bounded_string;
-- 			position			: positive;
-- 			chain 				: positive;
--  		end record;
-- --	ptr_bic_pre : type_ptr_bscan_ic_pre;
--     package type_list_of_bics_pre is new indefinite_vectors (
--         index_type => positive,
--         element_type => type_bscan_ic_pre);
--     use type_list_of_bics_pre;
--     list_of_bics_pre : type_list_of_bics_pre.vector;
--     
-- 
-- 	type type_boundary_register_description is array (natural range <>) of type_bit_of_boundary_register;
-- 
-- 	type type_port_io_map is array (natural range <>) of type_port;
-- 	type type_port_pin_map is array (natural range <>) of type_port_pin;
-- 	-- NOTE: the port name is the primary key between port_io_map and port_pin_map !
-- 
-- --  	type type_bscan_ic;
-- --  	type type_ptr_bscan_ic is access all type_bscan_ic;
--     type type_bscan_ic(len_ir, len_bsr: type_register_length; len_bsr_description, len_port_io_map, len_port_pin_map : positive) is
-- --     type type_bscan_ic(len_ir : type_register_length := 1;
-- --                        len_bsr: type_register_length := 1;
-- --                        len_bsr_description : positive := 1;
-- --                        len_port_io_map : positive := 1;
-- --                        len_port_pin_map : positive := 1) is    
--  		record
-- --			next				: type_ptr_bscan_ic;
-- --			id					: positive;
-- 			name				: universal_string_type.bounded_string;
-- 			housing				: universal_string_type.bounded_string;
-- 			model_file			: extended_string.bounded_string;
-- 			options				: universal_string_type.bounded_string;
-- 			value				: universal_string_type.bounded_string;
-- 			position			: positive;
-- 			chain 				: positive;
-- 			capture_ir			: type_string_of_bit_characters_class_1(1..len_ir);
--  			idcode				: type_bic_idcode;
--  			usercode			: type_bic_usercode;
-- 			opc_bypass, opc_extest, opc_sample, opc_preload, opc_highz, opc_clamp,
-- 			opc_idcode, opc_usercode, opc_intest : type_string_of_bit_characters_class_1(1..len_ir);
-- 			capture_bypass			: type_bit_char_class_0 := '0';
--  			safebits				: type_string_of_bit_characters_class_1(1..len_bsr);
-- 			trst_pin				: boolean;
-- 			boundary_register		: type_boundary_register_description(1..len_bsr_description);
-- 			port_io_map				: type_port_io_map(1..len_port_io_map);
-- 			port_pin_map			: type_port_pin_map(1..len_port_pin_map); -- indexed ports like A1..A4 comprise a single element here
-- 
-- 			-- flags used when generating static drive and expect values (by ATG)
-- 			has_static_drive_cell	: boolean := false; -- is set when processing cell lists by procedure mark_bic_as_having_static_drive_cell
-- 			has_static_expect_cell	: boolean := false; -- is set when processing cell lists by procedure mark_bic_as_having_static_expect_cell
-- 
-- 			-- flags used when generating dynamic drive and expect values (by ATG)
-- 			has_dynamic_drive_cell	: boolean := false; -- is set when processing cell lists by procedure mark_bic_as_having_dynamic_drive_cell
-- 			has_dynamic_expect_cell	: boolean := false; -- is set when processing cell lists by procedure mark_bic_as_having_dynamic_expect_cell
-- 
-- 			-- this is compiler related. when creating the object, we assign default values. 
-- 			-- compseq will overwrite them if addressed in sequence file
-- 			-- supposed read-only registers also get written, in order to test if they are read-only
-- 			-- MSB is on the left (position 1)
--  			pattern_last_ir_drive		: type_string_of_bit_characters_class_0(1..len_ir);
--  			pattern_last_ir_expect		: type_string_of_bit_characters_class_0(1..len_ir);
-- 			pattern_last_ir_mask		: type_string_of_bit_characters_class_0(1..len_ir);
--  			pattern_last_boundary_drive	: type_string_of_bit_characters_class_0(1..len_bsr);
--  			pattern_last_boundary_expect: type_string_of_bit_characters_class_0(1..len_bsr);
--  			pattern_last_boundary_mask	: type_string_of_bit_characters_class_0(1..len_bsr);
--  			pattern_last_bypass_drive	: type_string_of_bit_characters_class_0(1..bic_bypass_register_length);
--  			pattern_last_bypass_expect	: type_string_of_bit_characters_class_0(1..bic_bypass_register_length);
--  			pattern_last_bypass_mask	: type_string_of_bit_characters_class_0(1..bic_bypass_register_length);
--  			pattern_last_idcode_drive	: type_string_of_bit_characters_class_0(1..bic_idcode_register_length);
--  			pattern_last_idcode_expect	: type_string_of_bit_characters_class_0(1..bic_idcode_register_length);
--  			pattern_last_idcode_mask	: type_string_of_bit_characters_class_0(1..bic_idcode_register_length);
--  			pattern_last_usercode_drive	: type_string_of_bit_characters_class_0(1..bic_usercode_register_length);
--  			pattern_last_usercode_expect: type_string_of_bit_characters_class_0(1..bic_usercode_register_length);
--  			pattern_last_usercode_mask	: type_string_of_bit_characters_class_0(1..bic_usercode_register_length);
-- 
--  		end record;
-- --    ptr_bic : type_ptr_bscan_ic;
--     
--     package type_list_of_bics is new indefinite_vectors (
--         index_type => positive,
--         element_type => type_bscan_ic);
--     use type_list_of_bics;
--     list_of_bics : type_list_of_bics.vector;

    

-- 	cell_info_ifs 				: constant string (1..1) := "|";
-- 	subtype type_cell_info_cell_id is integer range -1 .. integer'last; -- if -1, no cell present
-- 	type type_pin_cell_info is
-- 		record
-- 			input_cell_id						: type_cell_info_cell_id := -1; -- -1 means no input cell present
-- 			input_cell_type						: type_boundary_register_cell; -- like BC_1, BC_7
-- 			input_cell_function					: type_cell_function; -- expected to be INPUT, CLOCK, OBSERVE_ONLY
-- 			input_cell_safe_value				: type_bit_char_class_1;
-- 			input_cell_expect_static			: type_bit_char_class_1;
-- 			input_cell_expect_atg				: boolean := false; -- true if atg expects something here
-- 			input_cell_appears_in_cell_list		: boolean := false;
-- 
-- 			output_cell_id						: type_cell_info_cell_id := -1; -- -1 means no output cell present
-- 			output_cell_type					: type_boundary_register_cell; -- like BC_1, BC_7
-- 			output_cell_function				: type_cell_function; -- expected to be OUTPUT2, OUTPUT3, BIDIR
-- 			output_cell_safe_value				: type_bit_char_class_1;
-- 			output_cell_drive_static			: type_bit_char_class_0; -- CS: should there be a default for unused output cells like ? := '0';
-- 			output_cell_drive_atg				: boolean := false; -- true if atg drives something here
-- 			output_cell_appears_in_cell_list	: boolean := false;
-- 
-- 			control_cell_id						: type_cell_info_cell_id := -1; -- -1 means no control cell present
-- 			--control_cell_safe_value			: type_bit_char_class_1; -- CS: not provided here
-- 			--control_cell_type					: type_boundary_register_cell; -- CS: not evaluated and not provided currently
-- 			disable_value						: type_bit_char_class_0;
-- 			disable_result						: type_disable_result;
-- 			control_cell_drive_static			: type_bit_char_class_0;
-- 			control_cell_drive_atg				: boolean := false; -- true if atg drives something here
-- 			control_cell_inverted				: boolean := false; -- true if cell content to load is to be inverted
-- 			control_cell_shared					: boolean := false; -- true if control cell used by other pins
-- 			control_cell_in_journal				: boolean := false; -- procedure make_shared_control_cell_journal sets true once processed
-- 			control_cell_appears_in_cell_list	: boolean := false;
-- 			
-- 			selected_as_driver					: boolean := false; -- marker for selected drivers (set by chkpsn)
-- 		end record;
-- 	pin_cell_info_default : type_pin_cell_info; -- will be used as default for non-bscan pins
-- 
-- 	type type_pin;
-- 	type type_ptr_pin is access all type_pin;
-- 	type type_pin is
-- 		record
-- 			next				: type_ptr_pin;
-- 			device_name			: universal_string_type.bounded_string;
-- 			device_class		: type_device_class := '?'; -- default is an unknown device
-- 			device_value		: universal_string_type.bounded_string;
-- 			device_package		: universal_string_type.bounded_string;
-- 			device_pin_name		: universal_string_type.bounded_string;
-- 			pin_checked			: boolean; -- CS: set default to false ?
-- 			device_port_name	: universal_string_type.bounded_string; -- used with bics only
-- 			is_bscan_capable	: boolean := false; -- true if pin has any cells
-- 			cell_info			: type_pin_cell_info;
-- 		end record;
-- 	ptr_pin : type_ptr_pin;
-- 
-- 	secondary_net_count_max		: constant positive := 100; -- CS: maximum of secondary nets a primary net can posess, increase if nessecary
-- 	type type_list_of_secondary_net_names is array (positive range 1..secondary_net_count_max) of universal_string_type.bounded_string;
-- 
-- 	type type_pins_of_net is array (natural range <>) of type_pin;
-- 	type type_net;
-- 	type type_ptr_net is access all type_net;
-- 	type type_net (part_ct : positive; level : type_net_level) is
-- 		record
-- 			next						: type_ptr_net;
-- 			name						: universal_string_type.bounded_string;
-- 			class						: type_net_class;
-- 			bs_bidir_pin_count			: natural := 0; -- pins that have bot input and output cell provided 
-- 			bs_input_pin_count			: natural := 0;
-- 			bs_output_pin_count			: natural := 0;
-- 			bs_capable					: boolean := false;
-- 			optimized					: boolean := false; -- true after processed by chkpsn
-- 			pin		 					: type_pins_of_net(1..part_ct);
-- 			case level is
-- 				when primary =>
-- 					secondary_net_ct			: natural := 0;
-- 					list_of_secondary_net_names	: type_list_of_secondary_net_names;
-- 				when secondary =>
-- 					name_of_primary_net			: universal_string_type.bounded_string;
-- 			end case;
-- 		end record;
-- 	ptr_net : type_ptr_net;

-- 	type type_start_of_section_mark is (Section); -- CS: remove and replace by type_section_mark.section
-- 	type type_end_of_section_mark is (EndSection); -- CS: remove and replace by type_section_mark.endsection
-- 	type type_section_mark is
-- 		record
-- 			section			: string (1..7)  := "Section";
-- 			endsection		: string (1..10) := "EndSection";
-- 			subsection		: string (1..10) := "SubSection";
-- 			endsubsection	: string (1..13) := "EndSubSection";
-- 		end record;
-- 	section_mark : type_section_mark;

-- 	type type_start_of_subsection_mark is (SubSection); -- CS: remove and replace by type_section_mark.subsection
-- 	type type_end_of_subsection_mark is (EndSubSection); -- CS: remove and replace by type_section_mark.endsubsection
-- 	type type_secondary_net_identifier is (secondary_nets);
-- 	type type_secondary_nets_section_identifier is (secondary_nets);
-- 	type type_secondary_net_name_identifier is (net);


-- 	type type_cell_list_class_identifier is ( CLASS );
-- 	type type_cell_list_net_level is ( SECONDARY_NET , PRIMARY_NET );
-- 	type type_cell_list_device_identifier is ( DEVICE );
-- 	type type_cell_list_pin_identifier is ( PIN );
-- 	type type_cell_list_control_cell_identifier is ( CONTROL_CELL );
-- 	type type_cell_list_output_cell_identifier is ( OUTPUT_CELL );
-- 	type type_cell_list_input_cell_identifier is ( INPUT_CELL ); 
-- 	type type_cell_list_locked_to_identifier is ( LOCKED_TO );
-- 	type type_cell_list_disable_value_identifier is ( DISABLE_VALUE );
-- 	type type_cell_list_enable_value_identifier is ( ENABLE_VALUE );
-- 	type type_cell_list_drive_value_identifier is ( DRIVE_VALUE );
-- 	type type_cell_list_expect_value_identifier is ( EXPECT_VALUE );
-- 	type type_cell_list_primary_net_is_identifier is ( PRIMARY_NET_IS );
-- 	type type_cell_list_control_cell_inverted_identifier is ( INVERTED );
-- 	type type_cell_list_control_cell_inverted is ( YES, NO , TRUE, FALSE);

-- 	-- DATABASE SECTIONS
-- 	section_registers							: constant string (1..9) 	:= "registers";
-- 	section_netlist								: constant string (1..7) 	:= "netlist";
-- 	section_scanpath_configuration				: constant string (1..22)	:= "scanpath_configuration";
-- 	subsection_scanpath							: constant string (1..5)	:= "chain"; -- CS: not used yet, change to scanpath
-- 	section_static_output_cells_class_DX_NR		: constant string (1..31)	:= "static_output_cells_class_DX_NR";
-- 	section_atg_drive							: constant string (1..9) 	:= "atg_drive";
-- 	section_atg_expect							: constant string (1..10) 	:= "atg_expect";
-- 	section_static_expect						: constant string (1..13) 	:= "static_expect";
-- 	section_input_cells_class_NA				: constant string (1..20)	:= "input_cells_class_NA";
-- 	section_static_output_cells_class_PX		: constant string (1..28)	:= "static_output_cells_class_PX";
-- 	section_static_control_cells_class_PX		: constant string (1..29)	:= "static_control_cells_class_PX";
-- 	section_static_control_cells_class_DX_NR	: constant string (1..32)	:= "static_control_cells_class_DX_NR";
-- 	section_static_control_cells_class_EX_NA	: constant string (1..32)	:= "static_control_cells_class_EX_NA";
-- 	section_statistics							: constant string (1..10)	:= "statistics";

-- 	statistics_colon					: constant string (1..1)  := ":";
-- 	statistics_identifier_nets			: constant string (1..4)  := "nets";
-- 	statistics_identifier_pull_up		: constant string (1..7)  := "Pull-Up";
-- 	statistics_identifier_pull_down		: constant string (1..9)  := "Pull-Down";
-- 	statistics_identifier_drive_high	: constant string (1..10) := "Drive-High";
-- 	statistics_identifier_drive_low		: constant string (1..9)  := "Drive-Low";
-- 	statistics_identifier_expect_high	: constant string (1..11) := "Expect-High";
-- 	statistics_identifier_expect_low	: constant string (1..10) := "Expect-Low";
-- 	statistics_identifier_unrestricted	: constant string (1..12) := "unrestricted";
-- 	statistics_identifier_not			: constant string (1..3)  := "not";
--  	statistics_identifier_classified	: constant string (1..10) := "classified";
-- 	statistics_identifier_total			: constant string (1..5)  := "total";
-- 	statistics_identifier_bs_nets		: constant string (1..7)  := "bs-nets";
--  	statistics_identifier_static 		: constant string (1..6)  := "static";
-- 	statistics_identifier_thereof		: constant string (1..7)  := "thereof";
-- 	statistics_identifier_L				: constant string (1..1)  := "L";
-- 	statistics_identifier_H				: constant string (1..1)  := "H";
-- 	statistics_identifier_dynamic		: constant string (1..7)  := "dynamic";
-- 	statistics_identifier_testable		: constant string (1..8)  := "testable";

-- 	-- scan path options keywords
-- 	type type_scan_path_option is (
-- 			on_fail,
-- 			frequency,
-- 			trailer_ir, 
-- 			trailer_dr,
-- 			voltage_out_port_1,
-- 			tck_driver_port_1,
-- 			tms_driver_port_1,
-- 			tdo_driver_port_1,
-- 			trst_driver_port_1,
-- 			threshold_tdi_port_1,
-- 			voltage_out_port_2,
-- 			tck_driver_port_2,
-- 			tms_driver_port_2,
-- 			tdo_driver_port_2,
-- 			trst_driver_port_2,
-- 			threshold_tdi_port_2);

-- 	type type_fault is ( OPEN, SHORT );

-- 	type type_on_fail_action is (power_down, hstrst); -- CS: add "finish_test"
-- 	--type type_tck_frequency is new natural range 0..4; -- zero will cause the compile to default to 33.33khz
-- -- 	type type_tck_frequency is new float range 0.0000001..12.0; -- unit is MHz
-- -- 	tck_frequency_default : constant type_tck_frequency := 0.05;
-- 	--type type_trailer_sxr is new natural range 0..255;
-- 	trailer_length : constant positive := 8;
-- 	trailer_default : constant string (1..trailer_length) := "01010010"; -- equals 52h (proven good for debugging)
-- 	subtype type_trailer_sxr is type_string_of_bit_characters_class_0 (1..trailer_length);
-- 
-- 	type type_scanport_options_global is
-- 		record
-- 			on_fail_action 					: type_on_fail_action := power_down;
-- 			tck_frequency					: type_tck_frequency := tck_frequency_default;
-- 			trailer_sdr						: type_trailer_sxr;-- := type_trailer_sxr'value("8#52"); -- equals 52h
-- 			trailer_sir						: type_trailer_sxr;-- := type_trailer_sxr'value("8#52"); -- equals 52h
-- 		end record;
-- 	scanport_options_global : type_scanport_options_global;

-- 	scratch_vout1, scratch_vout2	: type_voltage_out := 1.8;
-- 	scratch_vtrh1, scratch_vtrh2	: type_threshold_tdi := 0.8;
-- 	scratch_ch_tck1, scratch_ch_tms1, scratch_ch_tdo1, scratch_ch_trst1	: type_driver_characteristic := push_pull;
-- 	scratch_ch_tck2, scratch_ch_tms2, scratch_ch_tdo2, scratch_ch_trst2	: type_driver_characteristic := push_pull;

-- 	scanport_count_max : constant positive := 2; -- CS: currently max 2 ports supported -- moved to m1_firmware.ads
-- 	subtype type_scanport_id is positive range 1 .. scanport_count_max;
-- 	type scanport;
-- 	type type_ptr_scanport is access all scanport;
--  	type scanport is
--  		record
-- 			next						: type_ptr_scanport;
-- 			id							: type_scanport_id;
-- 			active						: boolean;
-- 			voltage_out					: type_voltage_out; -- CS: default ?
-- 			voltage_threshold_tdi		: type_threshold_tdi; -- CS: default ?
-- 			characteristic_tck_driver	: type_driver_characteristic; -- CS: default ?
-- 			characteristic_tms_driver	: type_driver_characteristic; -- CS: default ?
-- 			characteristic_tdo_driver	: type_driver_characteristic; -- CS: default ?
-- 			characteristic_trst_driver	: type_driver_characteristic; -- CS: default ?
--  		end record;
-- 	ptr_sp : type_ptr_scanport;


-- 	type type_net_count_statistics is
-- 		record
-- 			pu			: natural := 0;
-- 			pd			: natural := 0;
-- 			dh			: natural := 0;
-- 			dl			: natural := 0;
-- 			eh			: natural := 0;
-- 			el			: natural := 0;
-- 			nr			: natural := 0;
-- 			na			: natural := 0;
-- 			total		: natural := 0;
-- 			bs_static	: natural := 0;
-- 			bs_static_l	: natural := 0;
-- 			bs_static_h	: natural := 0;
-- 			bs_dynamic	: natural := 0;
-- 			bs_testable	: natural := 0;
-- 
-- 			atg_drivers		: natural := 0;
-- 			atg_receivers	: natural := 0;
-- 		end record;
			

-- 	type type_udb_section_processed is
-- 		record
-- 			section_scanpath_configuration				: boolean := false;
-- 			section_registers							: boolean := false;
-- 			section_netlist								: boolean := false;
-- 			section_static_control_cells_class_EX_NA	: boolean := false;
-- 			section_static_control_cells_class_DX_NR	: boolean := false;
-- 			section_static_control_cells_class_PX		: boolean := false;
-- 			section_static_output_cells_class_PX		: boolean := false;
-- 			section_static_output_cells_class_DX_NR		: boolean := false;
-- 			section_static_expect						: boolean := false;
-- 			section_atg_expect							: boolean := false;
-- 			section_atg_drive							: boolean := false;
-- 			section_input_cells_class_NA				: boolean := false;
-- 			section_statistics							: boolean := false;
-- 			all_sections								: boolean := false;
-- 		end record;
-- 
-- 	type type_udb_summary is
-- 		record
-- 			net_count_statistics								: type_net_count_statistics;
-- 			sections_processed									: type_udb_section_processed;
-- 			line_number_end_of_section_scanpath_configuration 	: positive;
-- 			line_number_end_of_section_registers				: positive;
-- 			line_number_end_of_section_netlist					: positive;
-- 			scanpath_ct											: type_scanport_id;
-- 			bic_ct												: natural;
-- 		end record;
-- 
-- 	summary : type_udb_summary;
	-- fills summary with udb statistics
-- 	procedure read_data_base;

-- 	procedure put_warning_on_too_many_parameters(line_number : positive);

-- ----- OPTIONS FILE RELATED BEGIN----------------------------------------------------------------------
-- 	type type_options_class_identifier is ( CLASS );
-- 	type type_options_net_identifier is ( NET );
-- 	type type_options_net_has_secondary_nets is new boolean; -- := false;
-- 	type type_options_net;
-- 	type type_ptr_options_net is access all type_options_net;
-- 	type type_options_net (has_secondaries : type_options_net_has_secondary_nets; secondary_net_count : natural) is
-- 		record
-- 			next						: type_ptr_options_net;
-- 			name						: universal_string_type.bounded_string;
-- 			class						: type_net_class;
-- 			line_number					: positive;
-- 			case has_secondaries is
-- 				when true =>
-- 					list_of_secondary_net_names	: type_list_of_secondary_net_names.vector;
-- 				when false =>
-- 					null;
-- 			end case;
-- 		end record;
-- 	ptr_options_net : type_ptr_options_net;

-- 	-- cell lists entries begin ------------------------------------------------------
-- 
-- 	type type_cell_list_static_control_cells_class_EX_NA;
-- 	type type_ptr_cell_list_static_control_cells_class_EX_NA is access all type_cell_list_static_control_cells_class_EX_NA;
-- 	type type_cell_list_static_control_cells_class_EX_NA is
-- 		record
-- 		-- class NA primary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0
-- 		-- class NA secondary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0
-- 			next			: type_ptr_cell_list_static_control_cells_class_EX_NA;
-- 			class			: type_net_class;
-- 			level			: type_net_level;
-- 			net				: universal_string_type.bounded_string;
-- 			device			: universal_string_type.bounded_string;
-- 			pin				: universal_string_type.bounded_string;
-- 			cell			: type_cell_id;
-- 			disable_value	: type_bit_char_class_0;
-- 		end record;
-- 	ptr_cell_list_static_control_cells_class_EX_NA : type_ptr_cell_list_static_control_cells_class_EX_NA;
-- 	
--  	type type_cell_list_static_control_cells_class_DX_NR;
-- 	type type_ptr_cell_list_static_control_cells_class_DX_NR is access all type_cell_list_static_control_cells_class_DX_NR;
-- 	type type_cell_list_static_control_cells_class_DX_NR ( locked_to_enable_state : boolean) is
-- 		record
-- 		-- class NR primary_net LED0 device IC303 pin 10 control_cell 16 locked_to enable_value 0
-- 		-- class NR primary_net LED1 device IC303 pin 9 control_cell 16 locked_to enable_value 0
-- 		-- class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0
-- 			next			: type_ptr_cell_list_static_control_cells_class_DX_NR;
-- 			class			: type_net_class;
-- 			level			: type_net_level;
-- 			net				: universal_string_type.bounded_string;
-- 			device			: universal_string_type.bounded_string;
-- 			pin				: universal_string_type.bounded_string;
-- 			cell			: type_cell_id;
-- 			case locked_to_enable_state is
-- 				when true =>
-- 					enable_value	: type_bit_char_class_0;
-- 				when false =>
-- 					disable_value	: type_bit_char_class_0;
-- 			end case;
-- 		end record;
-- 	ptr_cell_list_static_control_cells_class_DX_NR : type_ptr_cell_list_static_control_cells_class_DX_NR;
-- 
--  	type type_cell_list_static_control_cells_class_PX;
-- 	type type_ptr_cell_list_static_control_cells_class_PX is access all type_cell_list_static_control_cells_class_PX;
-- 	type type_cell_list_static_control_cells_class_PX is
-- 		record
-- 			next			: type_ptr_cell_list_static_control_cells_class_PX;
-- 			class			: type_net_class;
-- 			level			: type_net_level;
-- 			net				: universal_string_type.bounded_string;
-- 			device			: universal_string_type.bounded_string;
-- 			pin				: universal_string_type.bounded_string;
-- 			cell			: type_cell_id;
-- 			disable_value	: type_bit_char_class_0;
-- 		end record;
-- 	ptr_cell_list_static_control_cells_class_PX : type_ptr_cell_list_static_control_cells_class_PX;
-- 
--  	type type_cell_list_static_output_cells_class_PX;
-- 	type type_ptr_cell_list_static_output_cells_class_PX is access all type_cell_list_static_output_cells_class_PX;
-- 	type type_cell_list_static_output_cells_class_PX is
-- 		record
-- 			next			: type_ptr_cell_list_static_output_cells_class_PX;
-- 			class			: type_net_class;
-- 			--level			: type_net_level := primary; -- because this is always a primary net
-- 			net				: universal_string_type.bounded_string;
-- 			device			: universal_string_type.bounded_string;
-- 			pin				: universal_string_type.bounded_string;
-- 			cell			: type_cell_id;
-- 			drive_value		: type_bit_char_class_0;
-- 		end record;
-- 	ptr_cell_list_static_output_cells_class_PX :	type_ptr_cell_list_static_output_cells_class_PX;
-- 
--  	type type_cell_list_static_output_cells_class_DX_NR;
-- 	type type_ptr_cell_list_static_output_cells_class_DX_NR is access all type_cell_list_static_output_cells_class_DX_NR;
-- 	type type_cell_list_static_output_cells_class_DX_NR is
-- 		record
-- 			next			: type_ptr_cell_list_static_output_cells_class_DX_NR;
-- 			class			: type_net_class;
-- 			--level			: type_net_level := primary; -- because this is always a primary net
-- 			net				: universal_string_type.bounded_string;
-- 			device			: universal_string_type.bounded_string;
-- 			pin				: universal_string_type.bounded_string;
-- 			cell			: type_cell_id;
-- 			drive_value		: type_bit_char_class_0;
-- 		end record;
-- 	ptr_cell_list_static_output_cells_class_DX_NR : type_ptr_cell_list_static_output_cells_class_DX_NR;
-- 
--  	type type_cell_list_static_expect;
-- 	type type_ptr_cell_list_static_expect is access all type_cell_list_static_expect;
-- 	type type_cell_list_static_expect ( level : type_net_level) is
-- 		record
-- 			next			: type_ptr_cell_list_static_expect;
-- 			class			: type_net_class;
-- 			net				: universal_string_type.bounded_string;
-- 			device			: universal_string_type.bounded_string;
-- 			pin				: universal_string_type.bounded_string;
-- 			cell			: type_cell_id;
-- 			expect_value	: type_bit_char_class_0;
-- 			case level is
-- 				when secondary =>
-- 					primary_net_is	: universal_string_type.bounded_string;
-- 				when primary => null;
-- 			end case;
-- 		end record;
-- 	ptr_cell_list_static_expect : type_ptr_cell_list_static_expect;
-- 
--  	type type_cell_list_atg_expect;
-- 	type type_ptr_cell_list_atg_expect is access all type_cell_list_atg_expect;
-- 	type type_cell_list_atg_expect ( level : type_net_level) is
-- 		record
-- 			next			: type_ptr_cell_list_atg_expect;
-- 			class			: type_net_class;
-- 			net				: universal_string_type.bounded_string;
-- 			device			: universal_string_type.bounded_string;
-- 			pin				: universal_string_type.bounded_string;
-- 			cell			: type_cell_id;
-- 			case level is
-- 				when secondary =>
-- 					primary_net_is	: universal_string_type.bounded_string;
-- 				when primary => null;
-- 			end case;
-- 		end record;
-- 	ptr_cell_list_atg_expect : type_ptr_cell_list_atg_expect;
-- 
--  	type type_cell_list_atg_drive;
-- 	type type_ptr_cell_list_atg_drive is access all type_cell_list_atg_drive;
-- 	type type_cell_list_atg_drive (controlled_by_control_cell : boolean) is
-- 		record
-- 			next			: type_ptr_cell_list_atg_drive;
-- 			class			: type_net_class;
-- 			net				: universal_string_type.bounded_string;
-- 			device			: universal_string_type.bounded_string;
-- 			pin				: universal_string_type.bounded_string;
-- 			cell			: type_cell_id;
-- 			case controlled_by_control_cell is
-- 				when true =>
-- 					inverted	: boolean;
-- 				when others => null;
-- 			end case;
-- 		end record;
-- 	ptr_cell_list_atg_drive : type_ptr_cell_list_atg_drive;
-- 
--  	type type_cell_list_input_cells_class_NA;
-- 	type type_ptr_cell_list_input_cells_class_NA is access all type_cell_list_input_cells_class_NA;
-- 	type type_cell_list_input_cells_class_NA ( level : type_net_level) is
-- 		record
-- 			next			: type_ptr_cell_list_input_cells_class_NA;
-- 			net				: universal_string_type.bounded_string;
-- 			device			: universal_string_type.bounded_string;
-- 			pin				: universal_string_type.bounded_string;
-- 			cell			: type_cell_id;
-- 			case level is
-- 				when secondary =>
-- 					primary_net_is	: universal_string_type.bounded_string;
-- 				when primary => null;
-- 			end case;
-- 		end record;
-- 	ptr_cell_list_input_cells_class_NA : type_ptr_cell_list_input_cells_class_NA;
-- 
-- 	-- cell lists entries end --------------------------------------------------------

-- 	type type_list_of_nets_with_shared_control_cell;
-- 	type type_ptr_list_of_nets_with_shared_control_cell is access all type_list_of_nets_with_shared_control_cell;
-- 	type type_list_of_nets_with_shared_control_cell is
--  		record
-- 			next		: type_ptr_list_of_nets_with_shared_control_cell;
--  			net_name	: universal_string_type.bounded_string;
-- 			net_level	: type_net_level;
-- 			net_class	: type_net_class;
--  		end record;
-- 	ptr_list_of_nets_with_shared_control_cell : type_ptr_list_of_nets_with_shared_control_cell;
-- 
-- 	type type_shared_control_cell_with_nets;
-- 	type type_ptr_shared_control_cell_with_nets is access all type_shared_control_cell_with_nets;
-- 	type type_shared_control_cell_with_nets is
-- 		record
-- 			next			: type_ptr_shared_control_cell_with_nets;
-- 			cell_id			: type_cell_id;
-- 			ptr_net			: type_ptr_list_of_nets_with_shared_control_cell;
-- 			ptr_net_last	: type_ptr_list_of_nets_with_shared_control_cell;
-- 		end record;
-- 	ptr_shared_control_cell_with_nets : type_ptr_shared_control_cell_with_nets;
-- 
-- 	type type_shared_control_cell_journal;
-- 	type type_ptr_shared_control_cell_journal is access all type_shared_control_cell_journal;
-- 	type type_shared_control_cell_journal is
-- 		record
-- 			next			: type_ptr_shared_control_cell_journal;
-- 			bic_name		: universal_string_type.bounded_string;
-- 			cell_ptr		: type_ptr_shared_control_cell_with_nets;
-- 			ptr_cell_last	: type_ptr_shared_control_cell_with_nets;
-- 		end record;
-- 	ptr_shared_control_cell_journal : type_ptr_shared_control_cell_journal;

----- OPTIONS FILE RELATED END------------------------------------------------------------------------


----- TEST EXECUTION RELATED BEGIN -------------------------------------------------------------------
	--type type_execute_item is (test, step);
-- 	type type_step_mode is (off, sxr, tck);
-- 	step_mode_count	: natural := type_step_mode'pos((type_step_mode'last)); -- number of allowed step modi
-- 	step_mode	  	: type_step_mode := off;
-- 
--     tap_test_logic_reset            	: constant string (1..16) := "Test-Logic-Reset";
--     tap_run_test_idle               	: constant string (1..13) := "Run-Test/Idle";
--     tap_select_dr_scan              	: constant string (1..14) := "Select-DR-Scan";
--     tap_capture_dr          	        : constant string (1..10) := "Capture-DR";
--     tap_shift_dr                    	: constant string (1..8)  := "Shift-DR";
-- 	tap_exit1_dr 	                   	: constant string (1..8)  := "Exit1-DR";
--     tap_pause_dr                    	: constant string (1..8)  := "Pause-DR";
--     tap_exit2_dr                    	: constant string (1..8)  := "Exit2-DR";
--     tap_update_dr                   	: constant string (1..9)  := "Update-DR";   
--     tap_select_ir_scan              	: constant string (1..14) := "Select-IR-Scan";
--     tap_capture_ir                  	: constant string (1..10) := "Capture-IR";
--     tap_shift_ir                    	: constant string (1..8)  := "Shift-IR";
--     tap_exit1_ir                    	: constant string (1..8)  := "Exit1-IR";
--     tap_pause_ir                    	: constant string (1..8)  := "Pause-IR";
--     tap_exit2_ir                    	: constant string (1..8)  := "Exit2-IR";
--     tap_update_ir                   	: constant string (1..9)  := "Update-IR";

----- TEST EXECUTION RELATED END ---------------------------------------------------------------------

-- 	type result_test_type is ( pass, fail, not_loaded, internal_error);
-- 	result_test 	: result_test_type := fail;
-- 
-- 	type type_port_vector is
-- 		record
-- 			name	: universal_string_type.bounded_string;
-- 			msb		: natural := 0;
-- 			lsb		: natural := 0;
-- 			length	: positive := 1;
-- 			--mirrored: boolean := false; -- CS: not used yet
-- 		end record;

-- 	function fraction_port_name(port_name_given : string) return type_port_vector;
-- 	-- breaks down something line A[14:0] into the components name=A, msb=14, lsb=0 and length=15
-- 	-- if a single port given like 'CE', the components are name=CE, msb=0, lsb=0 and length=1


-- 	function instruction_present(instruction_in : type_string_of_bit_characters_class_1) return boolean;
-- 	-- returns false if given instruction opcode contains no 1 and no 0

-- 	function negate_bit_character_class_0 (character_given : type_bit_char_class_0) return type_bit_char_class_0;
-- 	function drive_value_derived_from_class (class_given : type_net_class) return type_bit_char_class_0;
-- 	function inverted_status_derived_from_class_and_disable_value (
-- 		class_given : type_net_class;
-- 		disable_value_given : type_bit_char_class_0) return boolean;
-- 
-- 	function disable_value_derived_from_class_and_inverted_status(
-- 		class_given : type_net_class;
-- 		inverted_given : boolean) return type_bit_char_class_0;

-- 	procedure print_bic_info (bic_name : string);
-- 	procedure print_net_info (net_name : string);
--	procedure print_scc_info (bic_name : string; control_cell_id : type_cell_id);

-- 	function is_shared (bic_name : universal_string_type.bounded_string; control_cell_id : type_cell_id) return boolean;
-- 	-- returns true if given bic exists and control cell is shared

-- 	function is_primary (name_net : universal_string_type.bounded_string) return boolean;
-- 	-- returns true if given net is a primary net

-- 	function get_primary_net (name_net : universal_string_type.bounded_string) return universal_string_type.bounded_string;
-- 	-- returns the name of the superordinated primary net.
-- 	-- if given net is a primary net, the same name will be returned

-- 	function get_secondary_nets (name_net : universal_string_type.bounded_string) return type_list_of_secondary_net_names;
-- 	-- returns a list of secondary nets connected to the given primary net
-- 	-- if there are no secondary nets or if the given net itself is a secondary net, an empty list is returned

-- 	function get_number_of_secondary_nets (name_net : universal_string_type.bounded_string) return natural;
-- 	-- returns the number of secondary nets connected to the given primary net

-- 	function remove_comment_from_line(text_in : string) return string;

-- 	function get_field_count (text_in : string) return natural;
-- 
-- 	function get_field_from_line (text_in : string; position : positive; ifs : character := ' ') return string;

-- 	function query_render_net_class (
-- 		primary_net_name 					: string;
-- 		primary_net_class					: type_net_class;
-- 		list_of_secondary_net_names			: type_list_of_secondary_net_names;
-- 		secondary_net_count					: natural
-- 		) return boolean; -- returns true if class rendering allowed


-- 	function read_uut_data_base
-- 	-- creates a list of objects of type type_net indicated by pointer ptr_net
-- 	-- creates a list of objects of type type_bscan_ic_pre indicated by pointer ptr_bic_pre
-- 	-- creates a list of objects of type type_bscan_ic indicated by pointer ptr_bic
-- 	-- creates a list of objects of type type_shared_control_cell_journal indicated by pointer ptr_shared_control_cell_journal
--   		(
--   		name_of_data_base_file : string;
-- 		debug_level	: natural := 0
-- -- 		dedicated_action : boolean := false;
-- -- 		action : type_action := import_bsdl
--  		) return type_udb_summary;

-- 	function test_compiled (name_test : string) return boolean;
-- 	-- Returns true if given test directory contains a vector file.
-- 	-- name_test is assumed as absolute path !

-- 	function valid_script (name_script : string) return boolean;
-- 	-- Returns true if given script is valid.

-- 	function valid_project (name_project : string) return boolean;
-- 	-- Returns true if given project is valid.
-- 	-- name_project is assumed as absolute path !

----- TEST GENERATION RELATED BEGIN ------------------------------------------------------------------

-- 	sequence_count_max	: constant positive := 1;

-- 	procedure create_test_directory
-- 		-- version 002 / MBL
-- 		-- checks if test directory already exists
-- 		-- asks user for confirmation to overwrite existing files residing therein
-- 		-- creates test directory with readme.txt
-- 		(
-- 		test_name			: string;
-- 		warnings_enabled	: boolean := true
-- 		);

-- 	procedure write_diagnosis_netlist
-- 		-- Creates a netlist file in test directory.
-- 		-- The fail diagnosis bases on this netlist.
-- 		(
-- 		data_base : string;
-- 		test_name : string
-- 		);
		

-- 	type type_delay is delta 0.1 digits 3; -- from 0.0 to 25.5 sec
-- 	delay_max : type_delay := 25.5; -- CS: currently the BSC does not support more delay
-- 	type type_delay_value is new type_delay range 0.0 .. delay_max;

-- 	delay_max 						: constant float := 25.5;
--  	delay_resolution				: constant float := 0.1; -- seconds
-- 	subtype type_delay_value is float range 0.0..delay_max; -- CS: range 0.02..delay_max ?
-- 	delay_set_by_operator			: type_delay_value;
-- 
-- 
-- 	-- power monitor
-- 	timeout_identifier				: constant string (1..7) := "timeout";
-- 	current_max						: constant float := 4.0; -- amps
-- 	subtype type_current_max is float range 0.1..current_max;
-- 	current_limit_set_by_operator	: type_current_max := type_current_max'first;
-- 	overload_timeout_max 			: constant type_delay_value := 5.0; -- seconds
-- 	overload_timeout_min 			: constant float := 0.02; -- seconds -- CS: use type_delay_value instead of float
-- 	overload_timeout_resolution 	: constant float := 0.02; -- seconds -- CS: use type_delay_value instead of float
-- 	subtype type_overload_timeout is float range overload_timeout_min..overload_timeout_max; -- CS: use type_delay_value instead of float
-- 	overload_timeout				: type_overload_timeout := type_overload_timeout'first;


-- 
-- 	procedure write_test_section_options;
-- 	-- writes section for options of test
-- 
-- 	procedure write_test_init;
-- 	-- append test init template file line by line to seq file

	--sequence_instruction_set := string (1..3) := "set";
	--sequence_instruction_set := string (1..3) := "set";
-- 	type type_sequence_instruction_set is
-- 		record
-- 			set 	: string (1..3) := "set";
-- 			sdr 	: string (1..3) := "sdr";
-- 			sir 	: string (1..3) := "sir";
-- 			dely	: string (1..5) := "delay";
-- 			power	: string (1..5) := "power";
-- 			imax	: string (1..4) := "imax";
-- 			connect 	: string (1..7)  := "connect";
-- 			disconnect	: string (1..10) := "disconnect";
-- 			trst 		: string (1..4) := "trst";
-- 			strst 		: string (1..5) := "strst";
-- 			htrst 		: string (1..5) := "htrst";
-- 			tap_state 	: string (1..9) := "tap_state";
-- 		end record;
-- 	sequence_instruction_set : type_sequence_instruction_set;
-- 
-- 	type type_sxr_option is
-- 		record
-- 			option		: string (1..6) := "option";
-- 			retry		: string (1..5) := "retry";
-- 			dely		: string (1..5) := "delay";
-- 		end record;
-- 	sxr_option : type_sxr_option;

-- 	-- sxr option "retry" -- example: sdr id 4 option retry 10 delay 1
-- 	sxr_retries_max : constant positive := 100;
-- 	subtype type_sxr_retries is positive range 1..sxr_retries_max;
-- 
-- 	type type_tap_state is
-- 		record
-- 			test_logic_reset	: string (1..16) := "test-logic-reset";
-- 			run_test_idle		: string (1..13) := "run-test/idle";
-- 			pause_dr			: string (1..8)  := "pause-dr";
-- 			pause_ir			: string (1..8)  := "pause-ir";
-- 		end record;
-- 	tap_state : type_tap_state;
-- 
-- 	type type_sxr_io_identifier is
-- 		record
-- 			drive	: string (1..3) := "drv";
-- 			expect	: string (1..3) := "exp";
-- 		end record;
-- 	sxr_io_identifier : type_sxr_io_identifier;
-- 
-- 	type type_sir_target_register is
-- 		record
-- 			ir		: string (1..2) := "ir";
-- 		end record;
-- 	sir_target_register : type_sir_target_register;
-- 
-- 	type type_sdr_target_register is
-- 		record
-- 			bypass		: string (1..6) := "bypass";
-- 			boundary	: string (1..8) := "boundary";
-- 			idcode		: string (1..6) := "idcode";
-- 			usercode	: string (1..8) := "usercode";
-- 		end record;
-- 	sdr_target_register : type_sdr_target_register;
-- 
-- 	type type_sxr_vector_orientation is
-- 		record
-- 			to			: string (1..2) := "to";
-- 			downto		: string (1..6) := "downto";
-- 		end record;
-- 	sxr_vector_orientation : type_sxr_vector_orientation;
-- 
-- 	type type_scanport_identifier is
-- 		record
-- 			port		: string (1..4) := "port";
-- 		end record;
-- 	scanport_identifier	: type_scanport_identifier;
-- 
-- 	type type_power_cycle_identifier is
-- 		record
-- 			up			: string (1..2) := "up";
-- 			down		: string (1..4) := "down";
-- 		end record;
-- 	power_cycle_identifier	: type_power_cycle_identifier;
-- 
-- 	-- power monitor
-- 	power_channel_ct: constant positive := 3; -- number of available power monitor channels
-- 	subtype type_power_channel_id is positive range 1..power_channel_ct;
-- 	type type_power_channel_name is
-- 		record
-- 			all_channels	: string (1..3) := "all";
-- 			gnd				: string (1..3) := "gnd";
-- 			id				: type_power_channel_id;
-- 		end record;
-- 	power_channel_name : type_power_channel_name;
-- 
-- 	type type_sxr_assignment_operator is
-- 		record
-- 			assign		: string (1..1) := "="; -- CS: change to ":="
-- 		end record;
-- 	sxr_assignment_operator : type_sxr_assignment_operator;
-- 
-- 	type type_sxr_id_identifier is
-- 		record
-- 			id			: string (1..3) := " id";
-- 		end record;
-- 	sxr_id_identifier : type_sxr_id_identifier;
-- 
-- 	comment : string (1..2) := "--";
-- 
-- 	sxr_ct : type_vector_id := 1;

-- 	procedure write_sir(with_new_line : boolean := true);
-- 	-- writes something like "sir id 6", increments sxr_ct, by default adds a line break
-- 
-- 	procedure write_sdr(with_new_line : boolean := true);
-- 	-- writes something like "sdr id 6", increments sxr_ct, by default adds a line break
-- 
-- 	procedure all_in(instruction : type_bic_instruction);
-- 	-- writes something like "set IC301 drv ir 7 downto 0 = 00000001 sample" for all bics
-- 
-- 	procedure write_ir_capture;
-- 	-- writes something like "set IC301 exp ir 7 downto 0 = 000XXX01" for all bics
-- 
-- 	procedure load_safe_values;
-- 	-- writes something like "set IC303 drv boundary 17 downto 0 = X1XXXXXXXXXXXXXXXX"
-- 
-- 	procedure load_static_drive_values;
-- 	-- writes something like "set IC303 drv boundary 16=0 16=0 16=0 16=0 17=0 17=0 17=0 17=0"
-- 
-- 	procedure load_static_expect_values;
-- 	-- writes something like " set IC300 exp boundary 14=0 11=1 5=0"

-- 	procedure write_end_of_test;

-- 	type type_end_sir is ( RTI , PIR);
-- 	type type_end_sdr is ( RTI , PDR);

----------------------------------------------------------------------------------------------------------
-- -- COMPILER RELATED BEGIN
-- 
-- 	register_file_prefix	: string (1..8) := "members_";
-- 	register_file_suffix	: string (1..4) := ".reg";
-- 
-- 	vector_header_file_name	: string (1..14) := "vec_header.tmp";
-- 	journal				: string (1..17) := "setup/journal.txt";
-- 	file_journal		: ada.text_io.file_type;
-- 
-- 	compile_listing		: ada.text_io.file_type;
-- 
-- 	type type_section_info_item is -- also used by test generators when writing "section info"
-- 		record
-- 			date			: string (1..4)  := "date";
-- 			data_base		: string (1..9)  := "data_base";
-- 			test_name		: string (1..9)  := "test_name";
-- 			test_profile	: string (1..12) := "test_profile";
-- 			end_sdr			: string (1..7)  := "end_sdr";
-- 			end_sir			: string (1..7)  := "end_sir";
-- 			target_net		: string (1..10) := "target_net";
-- 			cycle_count		: string (1..11) := "cycle_count";
-- 			high_time		: string (1..9)  := "high_time";
-- 			low_time		: string (1..8)  := "low_time";
-- 			frequency		: string (1..9)  := "frequency";
-- 			target_device	: string (1..13) := "target_device";
-- 			target_pin		: string (1..10) := "target_pin";
-- 			retry_count		: string (1..11) := "retry_count";
-- 			retry_delay		: string (1..11) := "retry_delay";
-- 		end record;
-- 	section_info_item : type_section_info_item;
-- 
-- 	type type_section_scanpath_options_item is -- CS: make use of it when reading data base in function read_uut_data_base
-- 		record
-- 			on_fail		: string (1..7)  := "on_fail";
-- 			frequency	: string (1..9)  := "frequency";
-- 			trailer_dr	: string (1..10) := "trailer_dr";
-- 			trailer_ir	: string (1..10) := "trailer_ir";
-- 
-- 			voltage_out_port_1	: string (1..18) := "voltage_out_port_1";
-- 			tck_driver_port_1	: string (1..17) := "tck_driver_port_1";
-- 			tms_driver_port_1	: string (1..17) := "tms_driver_port_1";
-- 			tdo_driver_port_1	: string (1..17) := "tdo_driver_port_1";
-- 			trst_driver_port_1	: string (1..18) := "trst_driver_port_1";
-- 			threshold_tdi_port_1: string (1..20) := "threshold_tdi_port_1";
-- 
-- 			voltage_out_port_2	: string (1..18) := "voltage_out_port_2";
-- 			tck_driver_port_2	: string (1..17) := "tck_driver_port_2";
-- 			tms_driver_port_2	: string (1..17) := "tms_driver_port_2";
-- 			tdo_driver_port_2	: string (1..17) := "tdo_driver_port_2";
-- 			trst_driver_port_2	: string (1..18) := "trst_driver_port_2";
-- 			threshold_tdi_port_2: string (1..20) := "threshold_tdi_port_2";
-- 		end record;
-- 	section_scanpath_options_item : type_section_scanpath_options_item;
-- 
-- 	type type_test_info is
-- 		record
-- 			test_name		: universal_string_type.bounded_string;
-- 			test_name_valid	: boolean := false;
-- 			data_base		: universal_string_type.bounded_string;
-- 			data_base_valid	: boolean := false;
-- 			end_sdr			: type_end_sdr := RTI;
-- 			end_sir			: type_end_sir := RTI;
-- 		end record;

-- 	type type_scanpath_options is -- CS: make use of it when reading data base in function read_uut_data_base
-- 		record
-- 			on_fail							: type_on_fail_action := POWER_DOWN;
-- 			frequency						: type_tck_frequency := tck_frequency_default;
-- 
-- 			-- CS: depends on firmware executor -- eqals 2x500 delay ticks -> appr. 50khz @ 50Mhz master clock
-- 			-- high nibble is multiplier, low nibble is exponent (10^exponent)
-- 			frequency_prescaler_unsigned_8	: unsigned_8 := 16#52#; 
-- 			trailer_dr						: type_trailer_sxr := to_binary_class_0(
-- 													binary_in	=> to_binary(
-- 															text_in		=> trailer_default,
-- 															length		=> trailer_length,
-- 															class		=> class_0
-- 															)
-- 													);
-- 
-- 			trailer_ir						: type_trailer_sxr := to_binary_class_0(
-- 													binary_in	=> to_binary(
-- 															text_in		=> trailer_default,
-- 															length		=> trailer_length,
-- 															class		=> class_0
-- 															)
-- 													);
-- 
-- 			voltage_out_port_1				: type_voltage_out := type_voltage_out'first;
-- 			voltage_out_port_1_unsigned_8	: unsigned_8;
-- 			tck_driver_port_1				: type_driver_characteristic := push_pull;
-- 			tck_driver_port_1_unsigned_8	: unsigned_8;
-- 			tms_driver_port_1				: type_driver_characteristic := push_pull;
-- 			tms_driver_port_1_unsigned_8	: unsigned_8;
-- 			tdo_driver_port_1				: type_driver_characteristic := push_pull;
-- 			tdo_driver_port_1_unsigned_8	: unsigned_8;
-- 			trst_driver_port_1				: type_driver_characteristic := push_pull;
-- 			trst_driver_port_1_unsigned_8	: unsigned_8;
-- 			threshold_tdi_port_1			: type_threshold_tdi := threshold_tdi_default;
-- 			threshold_tdi_port_1_unsigned_8	: unsigned_8;
-- 
-- 			voltage_out_port_2				: type_voltage_out := type_voltage_out'first;
-- 			voltage_out_port_2_unsigned_8 	: unsigned_8;
-- 			tck_driver_port_2				: type_driver_characteristic := push_pull;
-- 			tck_driver_port_2_unsigned_8	: unsigned_8;
-- 			tms_driver_port_2				: type_driver_characteristic := push_pull;
-- 			tms_driver_port_2_unsigned_8	: unsigned_8;
-- 			tdo_driver_port_2				: type_driver_characteristic := push_pull;
-- 			tdo_driver_port_2_unsigned_8	: unsigned_8;
-- 			trst_driver_port_2				: type_driver_characteristic := push_pull;
-- 			trst_driver_port_2_unsigned_8	: unsigned_8;
-- 			threshold_tdi_port_2			: type_threshold_tdi := threshold_tdi_default;
-- 			threshold_tdi_port_2_unsigned_8	: unsigned_8;
-- 		end record;

-- 	type type_test_section is
-- 		record
-- 			info		: string (1..4)  := "info";
-- 			options		: string (1..7)  := "options";
-- 			sequence	: string (1..8)  := "sequence";
-- 		end record;
-- 	test_section : type_test_section;

-- 	function is_scanport_active (id : type_scanport_id) return boolean;
-- 	-- returns true if scanport with given id is maked active

-- 	type type_bic_coordinates is -- CS: not required any more ?
-- 		record
-- 			present		: boolean := false; -- indicates whether the bic is part of any scanpath
-- 			scanpath	: type_scanport_id; -- indicates the scanpath the bic is part of
-- 			position	: positive; -- indicates the position of the bic in the scanpath
-- 									--position 1 is closest to BSC TDO !
-- 			--len_ir		: natural;
-- 			--len_bsr		: natural;
-- 		end record;

	--function get_bic_coordinates (bic_name : universal_string_type.bounded_string) return type_ptr_bscan_ic;
    -- returns a pointer to the bic (pointer is null, if given bic does not exist)
--     function get_bic_coordinates (bic_name : universal_string_type.bounded_string) return natural;
--     -- returns the bic id. returns zero if bic does not exist.
   

-- 	type type_scan is ( SIR, SDR );
-- 
-- 	type type_set_direction is ( DRV, EXP );
-- 	type type_set_target_register is ( IR, BOUNDARY, BYPASS, IDCODE, USERCODE );
-- 	type type_set_assigment_method is ( BIT_WISE, REGISTER_WISE);
-- 	type type_set_vector_orientation is ( downto, to );

-- 	type type_set_cell_assignment is
-- 		record
-- 			cell_id		: type_cell_id;
-- 			value		: type_bit_char_class_1;
-- 		end record;
-- 	function get_cell_assignment (text_in : string) return type_set_cell_assignment;
-- 	-- fractions a given string like 102=1 into cell id and value

-----------------------------------------------------------------------------------------


-- 	function get_test_base_address 
-- 		-- version 001 / MBL
-- 		( test_name : string) return string;


-- 	function set_breakpoint
-- 		(
-- 		interface_to_scan_master	: string;
-- 		vector_id_breakpoint		: type_vector_id_breakpoint;
-- 		bit_position				: type_sxr_break_position
-- 		) return boolean;

-- 	function execute_test
-- 		(
-- 		test_name					: string;
-- 		interface_to_scan_master	: string;
-- 		step_mode					: type_step_mode
-- 		) return result_test_type;

-- 	function load_test
-- 	-- Uploads a given test (vector file) in the BSC. Returns true if successful.
-- 	-- Uses the page write mode when transferring the actual data.
-- 		(
-- 		test_name					: string;
-- 		interface_to_scan_master	: string
-- 		) return boolean;

-- 	function dump_ram
-- 		(
-- 		interface_to_scan_master	: string;
-- 		mem_addr					: type_mem_address_byte
-- 		) return boolean;
-- 
-- 	function clear_ram
-- 		(
-- 		interface_to_scan_master	: string
-- 		) return boolean;

-- 	function show_firmware
-- 		(
-- 		interface_to_scan_master	: string
-- 		) return boolean;

-- 	procedure read_bsc_status_registers (interface_to_scan_master : string; display : boolean := false);
-- 	-- reads all bsc status registers
	
-- 	function query_status
-- 		(
-- 		interface_to_scan_master	: string
-- 		) return boolean;

-- 	function shutdown
-- 		(
-- 		interface_to_scan_master	: string
-- 		) return boolean;

	-- string processing
-- 	function get_field
-- 	-- Extracts a field separated by ifs at position. If trailer is true, the trailing content untiil trailer_to is also returned.
-- 			(
-- 			text_in 	: in string;
-- 			position 	: in positive;
-- 			ifs 		: in character := latin_1.space;
-- 			trailer 	: boolean := false;
-- 			trailer_to 	: in character := latin_1.semicolon
-- 			) return string;

-- 	function strip_quotes (text_in : in string) return string;
-- 	-- removes heading and trailing quotation from given string
-- 
-- 	function enclose_in_quotes (text_in : in string; quote : in character := latin_1.apostrophe) return string;
-- 	-- Adds heading and trailing quotate to given string.
	
-- 	function trim_space_in_string (text_in : in string) return string;
-- 	-- shrinks successive space characters to a single one in given string

-- 	function Is_Field	
-- 		(
-- 		Line	: unbounded_string;  	-- given line to examine
-- 		Value 	: String ; 				-- given value to be tested for
-- 		Field	: Natural				-- field number to expect value in
-- 		) return Boolean;

	
-- 	procedure extract_section (
-- 		input_file		: in string;
-- 		output_file		: in string;
-- 		append			: in boolean := false;
-- 		section_begin_1	: in string; -- "Section"
-- 		section_end_1	: in string; -- "EndSection", 
-- 		section_begin_2	: in string := ""; -- optionals follow
-- 		section_end_2 	: in string := "";
-- 		section_begin_3	: in string := "";
-- 		section_end_3 	: in string := "" 
-- 		);

	
-- 	-- MESSAGES
-- 	procedure write_message (
-- 		file_handle : in ada.text_io.file_type;
-- 		identation : in natural := 0;
-- 		text : in string; 
-- 		lf   : in boolean := true;		
-- 		file : in boolean := true;
-- 		console : in boolean := false);
	
	
end m1_internal;

