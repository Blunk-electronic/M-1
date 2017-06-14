-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 DATABASE COMPONENTS                        --
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

-- with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;
with ada.text_io;				use ada.text_io;
with ada.float_text_io;			use ada.float_text_io;

with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.containers.indefinite_vectors;
with ada.containers.ordered_maps;

-- with interfaces;				use interfaces;
-- with ada.exceptions;

with m1_firmware; 				use m1_firmware;
with m1_numbers; 				use m1_numbers;
with m1_string_processing;		use m1_string_processing;

package m1_database is

	-- whenever we refer to a UUT database we use this:
	text_identifier_database : constant string (1..8) := "database";
	

	port_name_length : constant natural := 200;
 	package type_port_name is new generic_bounded_length(port_name_length); use type_port_name;

	-- database items
	type type_object_type_in_database is ( 
		BIC,
		--REGISTER, -- CS
		NET,
		--PIN, -- CS
		SCC -- shared control cell
		);
 	object_type_in_database	: type_object_type_in_database;
	object_name_in_database : type_universal_string.bounded_string;


	type type_bic_option is (REMOVE_PIN_PREFIX);

	type type_logic_level_as_word is (LOW, HIGH);	
	type type_fault is ( OPEN, SHORT );	
	type type_device_class is (NA, R, C, L, X, J, T, D, LED, IC, RN , S, TF);
	device_class_default : constant type_device_class := NA;
	
	type type_net_level is (PRIMARY, SECONDARY);
	type type_net_class is ( NA, NR, DH, DL, PD, PU, EH, EL );
	net_class_default : constant type_net_class := NA;

	current_primary_net_class : type_net_class;
	net_class_preliminary : type_net_class;
	
	type type_bic_instruction is ( 
		BYPASS, 
		SAMPLE, 
		PRELOAD, 
		IDCODE, 
		USERCODE, 
		EXTEST, 
		INTEST, 
		HIGHZ, 
		CLAMP
		);
	
	subtype type_bic_instruction_for_infra_structure is type_bic_instruction range BYPASS .. EXTEST;
	type type_bic_data_register is ( BYPASS, BOUNDARY, IDCODE, USERCODE );
	type type_bic_instruction_register is ( IR );
	
	-- CS: obsolete ?
	type type_bic_optional_register_present is ( no, none, false );
	bic_trst_present : boolean;
	
	type type_boundary_register_cell is ( BC_0, BC_1, BC_2, BC_3, BC_4, BC_5, BC_6, BC_7, BC_8, BC_9, BC_10 );
	type type_cell_function is (
		INTERNAL,
		INPUT,
		OUTPUT2,
		OUTPUT3,
		CONTROL,
		CONTROLR,
		CLOCK,
		BIDIR,
		OBSERVE_ONLY
		);

	type type_disable_result is (
		Z,
		WEAK0,
		WEAK1,
		PULL0,
		PULL1,
		KEEPER
		);

	vector_length_max		: constant positive := (2**16)-1; -- CS: machine dependend and limited here to a reasonable value
	subtype type_cell_id is natural range 0..vector_length_max;
	subtype type_register_length is integer range 1..vector_length_max; -- a register is at least one bit long
	subtype type_control_cell_id is integer range -1..vector_length_max; -- if -1, no control cell connected to the particular cell (mostly an ouput cell)

	-- port indexes should have a reasonable maximum
	port_index_max			: constant positive := 255; -- CS: assumed that larger ports are not used. increase if nessecary
	subtype type_port_index is integer range -1..port_index_max; -- if -1, port is not indexed
	
	type type_bit_of_boundary_register is
		record
			id					: type_cell_id; -- a cell can appear once or twice
			appears_in_net_list	: boolean := false;
			cell_type			: type_boundary_register_cell; -- like BC_1;
			port				: type_port_name.bounded_string; -- like Y2(4)
			cell_function		: type_cell_function; -- like INTERNAL or output3
			cell_safe_value		: type_bit_char_class_1; -- 'x'
			control_cell_id		: type_control_cell_id; -- may also be -1 which means: no control cell assigned to a particular cell
			-- CS: control_cell_shared : boolean; -- this would speed up the shared control cell check in function shared_control_cell
			disable_value		: type_bit_char_class_0; -- := '1';
			disable_result		: type_disable_result;
		end record;
	package type_list_of_bsr_bits is new vectors (index_type => positive, element_type => type_bit_of_boundary_register);
	use type_list_of_bsr_bits; -- CS: rename to type_bsr_description
	bic_bsr_description_preliminary : type_list_of_bsr_bits.vector; -- for temporarily storage
	
	port_direction_in		: constant string (1..2) := "in";
	port_direction_out		: constant string (1..3) := "out";
	port_direction_inout	: constant string (1..5) := "inout";
	port_direction_linkage	: constant string (1..7) := "linkage";
	--CS :port_direction_buffer	: string (1..7) := "buffer";
	type type_port_direction is ( INPUT, OUTPUT, INOUT, LINKAGE ); -- CS: BUFFER ?
	type type_vector_orientation is (TO, DOWNTO);
	port_ifs 				: constant string (1..1) := ":";
	
	type type_port is record -- this is the port_io_map
		-- CS: verify the port has not been used yet
		name				: type_port_name.bounded_string; -- the port name like PB01_04
		direction			: type_port_direction;
		is_vector			: boolean; -- when false, the follwing properties are don't care:
		index_start			: natural; -- start is always the number found before (do/downto) !
		index_end			: natural; -- end   is always the number found after  (do/downto) !
		vector_length		: positive;
		vector_orientation	: type_vector_orientation;  -- like "to" or "downto"
	end record;
	package type_port_io_map is new vectors (index_type => positive, element_type => type_port);
	use type_port_io_map;
	bic_port_io_map_preliminary : type_port_io_map.vector; -- for temporarily storage -- CS: purge befor reading a new bic

	pin_name_length		: constant natural := 100; -- some netlists store device and pin in one string like IC44-2. in case
													-- type_pin_name is used to hold such strings this size seems sufficient.
	package type_pin_name is new generic_bounded_length(pin_name_length); use type_pin_name;
	device_pin : type_pin_name.bounded_string; -- used for general pin name handling
	package type_list_of_pin_names is new vectors (index_type => positive, element_type => type_pin_name.bounded_string);  -- for temporarily storage
	use type_list_of_pin_names;

	type type_port_pin is record
		port_name				: type_port_name.bounded_string;
		pin_names				: type_list_of_pin_names.vector;
	end record;
	package type_port_pin_map is new vectors (index_type => positive, element_type => type_port_pin);
	use type_port_pin_map;
	bic_port_pin_map_preliminary : type_port_pin_map.vector;  -- for temporarily storage

	-- device name (something like IC400 or LED69)
	device_name_length		: constant natural := 100;
	package type_device_name is new generic_bounded_length(device_name_length); use type_device_name;
	device_name				: type_device_name.bounded_string; -- used for general device name handling
	bic_name_preliminary	: type_device_name.bounded_string;	

	-- device package (the housing of an electronic component)
	package_name_length		: constant natural := 100;
 	package type_package_name is new generic_bounded_length(package_name_length); use type_package_name; -- CS: rename to type_device_package
	device_package : type_package_name.bounded_string; -- used for general device package handling
	
	model_file_name_length	: constant natural := 100;
 	package type_model_file_name is new generic_bounded_length(model_file_name_length); use type_model_file_name;

	bic_options_length		: constant natural := 100;
 	package type_bic_options is new generic_bounded_length(bic_options_length); use type_bic_options;

	device_value_length		: constant natural := 100;
 	package type_device_value is new generic_bounded_length(device_value_length); use type_device_value;
	bic_value_preliminary	: type_device_value.bounded_string;

	device_manufacturer_length : constant natural := 100;
 	package type_device_manufacturer is new generic_bounded_length(device_manufacturer_length);
	
	instruction_register_length_max : constant := 100;
	package type_preliminary_opcode is new generic_bounded_length(instruction_register_length_max); use type_preliminary_opcode;
	type type_preliminary_opcodes_by_standard is record
		bypass, extest, sample, preload, idcode, usercode, highz, clamp, intest	: type_preliminary_opcode.bounded_string;
	end record;
	bic_opcodes_preliminary : type_preliminary_opcodes_by_standard;
	-- To purge temporarily used opcodes we need a clean record of opcodes.
	bic_opcodes_init : constant type_preliminary_opcodes_by_standard := (others => to_bounded_string("")); 
	bic_len_ir_preliminary	: type_register_length;
	
	package type_preliminary_ir_capture is new generic_bounded_length(instruction_register_length_max); use type_preliminary_ir_capture;
	bic_capture_ir_preliminary : type_preliminary_ir_capture.bounded_string;

	boundary_register_length_max : constant type_register_length := 10000;
	package type_preliminary_safebits is new generic_bounded_length(boundary_register_length_max); use type_preliminary_safebits;
	bic_safebits_preliminary : type_preliminary_safebits.bounded_string;
	bic_len_bsr_preliminary	: type_register_length;
	
	bic_idcode_register_length : constant type_register_length := 32;
	package type_preliminary_idcode is new generic_bounded_length(bic_idcode_register_length); use type_preliminary_idcode;
	bic_idcode_preliminary	: type_preliminary_idcode.bounded_string;
	
	bic_usercode_register_length : constant type_register_length := 32;
	package type_preliminary_usercode is new generic_bounded_length(bic_usercode_register_length); use type_preliminary_usercode;
	bic_usercode_preliminary : type_preliminary_usercode.bounded_string;		
	
 	type type_bscan_ic_pre is record
-- 		name				: type_device_name.bounded_string := to_bounded_string("");
		housing				: type_package_name.bounded_string := to_bounded_string("");
		model_file			: type_model_file_name.bounded_string := to_bounded_string("");
		options				: type_bic_options.bounded_string := to_bounded_string("");
		position			: positive := 1; -- position within the scanpath. the device on top of the scanpath has position 1
		chain 				: positive := 1;
	end record;
	bic_pre_preliminary 	: type_bscan_ic_pre;
--     package type_list_of_bics_pre is new indefinite_vectors ( index_type => positive, element_type => type_bscan_ic_pre);
	--use type_list_of_bics_pre;
    --list_of_bics_pre : type_list_of_bics_pre.vector;

	package type_list_of_bics_pre is new ordered_maps ( 
		key_type => type_device_name.bounded_string,
		element_type => type_bscan_ic_pre);
	use type_list_of_bics_pre;
	list_of_bics_pre : type_list_of_bics_pre.map;



	subtype type_bic_idcode is type_string_of_bit_characters_class_1 (1..bic_idcode_register_length);
	bic_idcode_default : type_bic_idcode := (others => 'x'); -- in case bic has no idcode

	subtype type_bic_usercode is type_string_of_bit_characters_class_1 (1..bic_usercode_register_length);
	bic_usercode_default : type_bic_usercode := (others => 'x'); -- in case bic has no usercode

	bic_bypass_register_length 		: constant type_register_length := 1; -- defined by standard

	type type_trst_availability is (none, available);
	bic_trst_pin_preliminary : type_trst_availability;

	subtype type_scanport_id is positive range 1 .. scanport_count_max;	

	type type_bscan_ic(len_ir, len_bsr: type_register_length := type_register_length'first ) is record
-- 		name					: type_device_name.bounded_string;
		housing					: type_package_name.bounded_string;
		model_file				: type_model_file_name.bounded_string;
		options					: type_bic_options.bounded_string;
		value					: type_device_value.bounded_string;
		position				: positive; -- position within the scanpath. the device on top of the scanpath has position 1
		chain 					: type_scanport_id; -- CS rename to scanpath
		capture_ir				: type_string_of_bit_characters_class_1(1..len_ir);
		idcode					: type_bic_idcode := bic_idcode_default;
		usercode				: type_bic_usercode := bic_usercode_default;
		opc_bypass, opc_extest, opc_sample, opc_preload, opc_highz, opc_clamp,
		opc_idcode, opc_usercode, opc_intest : type_string_of_bit_characters_class_1(1..len_ir);
		capture_bypass			: type_bit_char_class_0 := '0';
		safebits				: type_string_of_bit_characters_class_1(1..len_bsr);
		trst_pin				: type_trst_availability;
		boundary_register		: type_list_of_bsr_bits.vector; -- CS: type_bsr_description
		port_io_map				: type_port_io_map.vector;
		port_pin_map			: type_port_pin_map.vector; -- indexed ports like A1..A4 comprise a single element here

		-- flags used when generating static drive and expect values (by ATG)
		has_static_drive_cell	: boolean := false; -- is set when processing cell lists by procedure mark_bic_as_having_static_drive_cell
		has_static_expect_cell	: boolean := false; -- is set when processing cell lists by procedure mark_bic_as_having_static_expect_cell

		-- flags used when generating dynamic drive and expect values (by ATG)
		has_dynamic_drive_cell	: boolean := false; -- is set when processing cell lists by procedure mark_bic_as_having_dynamic_drive_cell
		has_dynamic_expect_cell	: boolean := false; -- is set when processing cell lists by procedure mark_bic_as_having_dynamic_expect_cell

		-- this is compiler related. when creating the object, we assign default values. 
		-- compseq will overwrite them if addressed in sequence file
		-- supposed read-only registers also get written, in order to test if they are read-only
		-- MSB is on the left (position 1)
		pattern_last_ir_drive		: type_string_of_bit_characters_class_0(1..len_ir);
		pattern_last_ir_expect		: type_string_of_bit_characters_class_0(1..len_ir);
		pattern_last_ir_mask		: type_string_of_bit_characters_class_0(1..len_ir);
		pattern_last_boundary_drive	: type_string_of_bit_characters_class_0(1..len_bsr);
		pattern_last_boundary_expect: type_string_of_bit_characters_class_0(1..len_bsr);
		pattern_last_boundary_mask	: type_string_of_bit_characters_class_0(1..len_bsr);
		pattern_last_bypass_drive	: type_string_of_bit_characters_class_0(1..bic_bypass_register_length);
		pattern_last_bypass_expect	: type_string_of_bit_characters_class_0(1..bic_bypass_register_length);
		pattern_last_bypass_mask	: type_string_of_bit_characters_class_0(1..bic_bypass_register_length);
		pattern_last_idcode_drive	: type_string_of_bit_characters_class_0(1..bic_idcode_register_length);
		pattern_last_idcode_expect	: type_string_of_bit_characters_class_0(1..bic_idcode_register_length);
		pattern_last_idcode_mask	: type_string_of_bit_characters_class_0(1..bic_idcode_register_length);
		pattern_last_usercode_drive	: type_string_of_bit_characters_class_0(1..bic_usercode_register_length);
		pattern_last_usercode_expect: type_string_of_bit_characters_class_0(1..bic_usercode_register_length);
		pattern_last_usercode_mask	: type_string_of_bit_characters_class_0(1..bic_usercode_register_length);
	end record;
--     package type_list_of_bics is new indefinite_vectors ( index_type => positive, element_type => type_bscan_ic);
--     use type_list_of_bics;
--     list_of_bics : type_list_of_bics.vector;

	package type_list_of_bics is new ordered_maps (
		key_type => type_device_name.bounded_string,
		element_type => type_bscan_ic);
	use type_list_of_bics;
	list_of_bics : type_list_of_bics.map;
	
	cell_info_ifs 				: constant string (1..1) := "|";
	subtype type_cell_info_cell_id is integer range -1 .. integer'last; -- if -1, no cell present
	cell_not_available : constant type_cell_info_cell_id := type_cell_info_cell_id'first;
	
	type type_pin_cell_info is record
		input_cell_id						: type_cell_info_cell_id := cell_not_available; -- -1 means no input cell present
		input_cell_type						: type_boundary_register_cell; -- like BC_1, BC_7
		input_cell_function					: type_cell_function; -- expected to be INPUT, CLOCK, OBSERVE_ONLY, BIDIR
		input_cell_safe_value				: type_bit_char_class_1;
		input_cell_expect_static			: type_bit_char_class_1;
		input_cell_expect_atg				: boolean := false; -- true if atg expects something here
		input_cell_appears_in_cell_list		: boolean := false;

		output_cell_id						: type_cell_info_cell_id := cell_not_available; -- -1 means no output cell present
		output_cell_type					: type_boundary_register_cell; -- like BC_1, BC_7
		output_cell_function				: type_cell_function; -- expected to be OUTPUT2, OUTPUT3, BIDIR
		output_cell_safe_value				: type_bit_char_class_1;
		output_cell_drive_static			: type_bit_char_class_0; -- CS: should there be a default for unused output cells like ? := '0';
		output_cell_drive_atg				: boolean := false; -- true if atg drives something here
		output_cell_appears_in_cell_list	: boolean := false;

		control_cell_id						: type_cell_info_cell_id := cell_not_available; -- -1 means no control cell present
		--control_cell_safe_value			: type_bit_char_class_1; -- CS: not provided here
		--control_cell_type					: type_boundary_register_cell; -- CS: not evaluated and not provided currently
		disable_value						: type_bit_char_class_0;
		disable_result						: type_disable_result;
		control_cell_drive_static			: type_bit_char_class_0;
		control_cell_drive_atg				: boolean := false; -- true if atg drives something here
		control_cell_inverted				: boolean := false; -- true if cell content to load is to be inverted
		control_cell_shared					: boolean := false; -- true if control cell used by other pins
		control_cell_in_journal				: boolean := false; -- procedure make_shared_control_cell_journal sets true once processed
		control_cell_appears_in_cell_list	: boolean := false;
		
		selected_as_driver					: boolean := false; -- marker for selected drivers (set by chkpsn)
	end record;
	pin_cell_info_default : type_pin_cell_info; -- will be used as default for non-bscan pins

	type type_pin_base is tagged record
		device_name			: type_device_name.bounded_string;
		device_pin_name		: type_pin_name.bounded_string;
	end record;

	pin_legend : constant string (1..87) := "name class value package pin [ port | cell type func safe [ ctrl_cell disable result ]]";
	type type_pin (is_bscan_capable : boolean) is new type_pin_base with record
		device_class		: type_device_class := device_class_default; -- default is an unknown device
		device_value		: type_device_value.bounded_string;
		device_package		: type_package_name.bounded_string;
		device_port_name	: type_port_name.bounded_string; -- used with bics only
		case is_bscan_capable is
			when true =>
				cell_info	: type_pin_cell_info;
			when false =>
				null;
		end case;
	end record;

	package type_list_of_pins is new indefinite_vectors ( index_type => positive, element_type => type_pin);
	use type_list_of_pins;  
	pin_list_preliminary : type_list_of_pins.vector;  -- for temporarily storage -- CS: purge before reading a new net	

	net_name_length		: constant natural := 100;
	package type_net_name is new generic_bounded_length(net_name_length); use type_net_name;
	net_name : type_net_name.bounded_string; -- used for general net name handling
	current_primary_net_name	: type_net_name.bounded_string := to_bounded_string("");
	net_name_preliminary 		: type_net_name.bounded_string := to_bounded_string("");
	
	package type_list_of_secondary_net_names is new vectors ( index_type => positive, element_type => type_net_name.bounded_string);
	use type_list_of_secondary_net_names;
	empty_list_of_secondary_net_names : type_list_of_secondary_net_names.vector;
	list_of_secondary_net_names_preliminary : type_list_of_secondary_net_names.vector; -- for temporarily storage -- CS: purge before reading a net

-- 	type type_net_base is tagged record
-- 		name						: type_net_name.bounded_string;
-- 		class						: type_net_class := net_class_default;
-- 		bs_bidir_pin_count			: natural := 0; -- pins that have bot input and output cell provided 
-- 		bs_input_pin_count			: natural := 0;
-- 		bs_output_pin_count			: natural := 0;
-- 		bs_capable					: boolean := false;
-- 		pins	 					: type_list_of_pins.vector;
-- 	end record;
	
	type type_net (level : type_net_level := primary) is record
-- 	type type_net (level : type_net_level) is new type_net_base with record	
-- 		name						: type_net_name.bounded_string;
		class						: type_net_class := net_class_default;
		bs_bidir_pin_count			: natural := 0; -- pins that have bot input and output cell provided 
		bs_input_pin_count			: natural := 0;
		bs_output_pin_count			: natural := 0;
		bs_capable					: boolean := false;
		optimized					: boolean := false; -- true after processed by chkpsn
		cluster						: boolean := false; -- used by mkoptions
		cluster_id					: natural := 0; -- used by mkoptions		
		pins	 					: type_list_of_pins.vector;
		case level is
			when primary =>
				secondary_net_names	: type_list_of_secondary_net_names.vector;
			when secondary =>
				name_of_primary_net	: type_net_name.bounded_string;
		end case;
	end record;
-- 	package type_list_of_nets is new indefinite_vectors ( index_type => positive, element_type => type_net);
-- 	use type_list_of_nets;
-- 	list_of_nets : type_list_of_nets.vector;
	package type_list_of_nets is new ordered_maps (
		key_type => type_net_name.bounded_string,
		element_type => type_net);
	use type_list_of_nets;
	list_of_nets : type_list_of_nets.map;

	type type_on_fail_action is (power_down, hstrst); -- CS: add "finish_test"
	trailer_length : constant positive := 8;
	trailer_default : constant string (1..trailer_length) := "01010010"; -- equals 52h (proven good for debugging)
	subtype type_trailer_sxr is type_string_of_bit_characters_class_0 (1..trailer_length);

	type type_scanport_options_global is record
		on_fail_action 					: type_on_fail_action := power_down;
		tck_frequency					: type_tck_frequency := tck_frequency_default;
		trailer_sdr						: type_trailer_sxr;-- := type_trailer_sxr'value("8#52"); -- equals 52h
		trailer_sir						: type_trailer_sxr;-- := type_trailer_sxr'value("8#52"); -- equals 52h
	end record;
	scanport_options_global : type_scanport_options_global;

 	type type_scanport is record
		active						: boolean := false;
		voltage_out					: type_voltage_out := type_voltage_out'first;
		voltage_threshold_tdi		: type_threshold_tdi := type_threshold_tdi'first;
		characteristic_tck_driver	: type_driver_characteristic := highz; -- CS: good idea ?
		characteristic_tms_driver	: type_driver_characteristic := highz; -- CS: good idea ?
		characteristic_tdo_driver	: type_driver_characteristic := highz; -- CS: good idea ?
		characteristic_trst_driver	: type_driver_characteristic := highz; -- CS: good idea ?
	end record;
	scanport_1_preliminary	: type_scanport;
	scanport_2_preliminary	: type_scanport;
	package type_list_of_scanports is new vectors ( index_type => type_scanport_id, element_type => type_scanport);
	use type_list_of_scanports;
	list_of_scanports : type_list_of_scanports.vector;

	

	type type_udb_section_processed is record
		section_scanpath_configuration				: boolean := false;
		section_registers							: boolean := false;
		section_netlist								: boolean := false;
		section_static_control_cells_class_EX_NA	: boolean := false;
		section_static_control_cells_class_DX_NR	: boolean := false;
		section_static_control_cells_class_PX		: boolean := false;
		section_static_output_cells_class_PX		: boolean := false;
		section_static_output_cells_class_DX_NR		: boolean := false;
		section_static_expect						: boolean := false;
		section_atg_expect							: boolean := false;
		section_atg_drive							: boolean := false;
		section_input_cells_class_NA				: boolean := false;
		section_statistics							: boolean := false;
	end record;

	statistics_colon					: constant string (1..1)  := ":";
	statistics_identifier_atg_drivers	: constant string (1..11) := "ATG-drivers";	
	statistics_identifier_atg_receivers	: constant string (1..13) := "ATG-receivers";
	statistics_identifier_nets			: constant string (1..4)  := "nets";
	statistics_identifier_pull_up		: constant string (1..7)  := "Pull-Up";
	statistics_identifier_pull_down		: constant string (1..9)  := "Pull-Down";
	statistics_identifier_drive_high	: constant string (1..10) := "Drive-High";
	statistics_identifier_drive_low		: constant string (1..9)  := "Drive-Low";
	statistics_identifier_expect_high	: constant string (1..11) := "Expect-High";
	statistics_identifier_expect_low	: constant string (1..10) := "Expect-Low";
	statistics_identifier_unrestricted	: constant string (1..12) := "unrestricted";
	statistics_identifier_not			: constant string (1..3)  := "not";
 	statistics_identifier_classified	: constant string (1..10) := "classified";
	statistics_identifier_total			: constant string (1..5)  := "total";
	statistics_identifier_bs_nets		: constant string (1..7)  := "bs-nets";
 	statistics_identifier_static 		: constant string (1..6)  := "static";
	statistics_identifier_thereof		: constant string (1..7)  := "thereof";
	statistics_identifier_L				: constant string (1..1)  := "L";
	statistics_identifier_H				: constant string (1..1)  := "H";
	statistics_identifier_dynamic		: constant string (1..7)  := "dynamic";
	statistics_identifier_testable		: constant string (1..8)  := "testable";
	
	type type_udb_summary is record
		sections_processed									: type_udb_section_processed;
		line_number_end_of_section_scanpath_configuration 	: positive := 1;
		line_number_end_of_section_registers				: positive := 1;
		line_number_end_of_section_netlist					: positive := 1;
	end record;
	summary : type_udb_summary;
	
	type type_net_with_shared_control_cell is
 		record
 			name	: type_net_name.bounded_string;
			level	: type_net_level;
			class	: type_net_class;
 		end record;
	package type_list_of_nets_with_shared_control_cell is new vectors (
			index_type => positive, element_type => type_net_with_shared_control_cell);

	type type_shared_control_cell_with_nets is
		record
			cell_id			: type_cell_id;
			nets			: type_list_of_nets_with_shared_control_cell.vector;
		end record;
	package type_list_of_shared_control_cells is new vectors (
			index_type => positive, element_type => type_shared_control_cell_with_nets);
	
	type type_bic_with_shared_control_cell is
		record
			name			: type_device_name.bounded_string;
			cells			: type_list_of_shared_control_cells.vector;
		end record;
	package type_shared_control_cell_journal is new vectors (
		index_type => positive, element_type => type_bic_with_shared_control_cell);
	use type_shared_control_cell_journal;
	shared_control_cell_journal : type_shared_control_cell_journal.vector;
	

	-- DATABASE SECTIONS
	section_registers							: constant string (1..9) 	:= "registers";
	subsection_registers_safebits				: constant string (1..8)	:= "safebits";
	section_netlist								: constant string (1..7) 	:= "netlist";
	section_scanpath_configuration				: constant string (1..22)	:= "scanpath_configuration";
	subsection_scanpath_configuration_options	: constant string (1..7)	:= "options";	
	subsection_scanpath_configuration_scanpath	: constant string (1..5)	:= "chain"; -- CS: not used yet, change to scanpath
	section_static_output_cells_class_DX_NR		: constant string (1..31)	:= "static_output_cells_class_DX_NR";
	section_atg_drive							: constant string (1..9) 	:= "atg_drive";
	section_atg_expect							: constant string (1..10) 	:= "atg_expect";
	section_static_expect						: constant string (1..13) 	:= "static_expect";
	section_input_cells_class_NA				: constant string (1..20)	:= "input_cells_class_NA";
	section_static_output_cells_class_PX		: constant string (1..28)	:= "static_output_cells_class_PX";
	section_static_control_cells_class_PX		: constant string (1..29)	:= "static_control_cells_class_PX";
	section_static_control_cells_class_DX_NR	: constant string (1..32)	:= "static_control_cells_class_DX_NR";
	section_static_control_cells_class_EX_NA	: constant string (1..32)	:= "static_control_cells_class_EX_NA";
	section_statistics							: constant string (1..10)	:= "statistics";

	-- scan path options keywords
	type type_scanpath_option is (
			on_fail,
			frequency,
			trailer_ir, 
			trailer_dr,
			voltage_out_port_1,
			tck_driver_port_1,
			tms_driver_port_1,
			tdo_driver_port_1,
			trst_driver_port_1,
			threshold_tdi_port_1,
			voltage_out_port_2,
			tck_driver_port_2,
			tms_driver_port_2,
			tdo_driver_port_2,
			trst_driver_port_2,
			threshold_tdi_port_2);

	type type_register_keywords is (
		value,
		instruction_register_length,
		instruction_capture,
		boundary_register_length,
		idcode_register,
		usercode_register,
		trst_pin,
		subsection
		);

	register_not_available : constant string (1..4) := "none";

	type type_register_subsection is (
		safebits,
		instruction_opcodes,
		boundary_register,
		port_io_map,
		port_pin_map
		);
	
	type type_safebits_keywords is ( safebits, total);
	netlist_keyword_header_class 			: constant string (1..5) := "class";
	netlist_keyword_header_secondary_nets 	: constant string (1..17) := "secondary_nets_of";

	-- cell lists entries begin ------------------------------------------------------
	cell_list_keyword_class					: constant string (1..5) := "class";
	cell_list_keyword_device				: constant string (1..6) := "device";
	cell_list_keyword_pin					: constant string (1..3) := "pin";
	cell_list_keyword_control_cell			: constant string (1..12):= "control_cell";
	cell_list_keyword_locked_to				: constant string (1..9) := "locked_to";
	cell_list_keyword_disable_value			: constant string (1..13):= "disable_value";
	cell_list_keyword_enable_value			: constant string (1..12):= "enable_value";	
	cell_list_keyword_output_cell			: constant string (1..11):= "output_cell";
	cell_list_keyword_drive_value			: constant string (1..11):= "drive_value";
	cell_list_keyword_input_cell			: constant string (1..10):= "input_cell";	
	cell_list_keyword_expect_value			: constant string (1..12):= "expect_value";	
	cell_list_keyword_primary_net_is		: constant string (1..14):= "primary_net_is";
	cell_list_keyword_control_cell_inverted	: constant string (1..8) := "inverted";
	cell_list_keyword_yes					: constant string (1..3) := "yes";
	cell_list_keyword_no					: constant string (1..2) := "no";
	
	type type_cell_list_net_level is ( primary_net, secondary_net );

	-- this our base type for a cell in a cell list
	type type_cell_of_cell_list is tagged record
		class			: type_net_class;
		net				: type_net_name.bounded_string;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		id				: type_cell_id;
	end record;
	
	type type_static_control_cell_class_EX_NA is new type_cell_of_cell_list with record
	-- class NA primary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0
	-- class NA secondary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0
		level			: type_net_level;
		disable_value	: type_bit_char_class_0;
	end record;
	package type_list_of_static_control_cells_class_EX_NA is new vectors 
		(index_type => positive, element_type => type_static_control_cell_class_EX_NA);
	list_of_static_control_cells_class_EX_NA : type_list_of_static_control_cells_class_EX_NA.vector;
	
	type type_static_control_cell_class_DX_NR ( locked_to_enable_state : boolean) is new type_cell_of_cell_list with record
	-- class NR primary_net LED0 device IC303 pin 10 control_cell 16 locked_to enable_value 0
	-- class NR primary_net LED1 device IC303 pin 9 control_cell 16 locked_to enable_value 0
	-- class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0
		level			: type_net_level;
		case locked_to_enable_state is
			when true =>
				enable_value	: type_bit_char_class_0;
			when false =>
				disable_value	: type_bit_char_class_0;
		end case;
	end record;
	package type_list_of_static_control_cells_class_DX_NR is new indefinite_vectors
		(index_type => positive, element_type => type_static_control_cell_class_DX_NR);
	list_of_static_control_cells_class_DX_NR : type_list_of_static_control_cells_class_DX_NR.vector;

	type type_static_control_cell_class_PX is new type_cell_of_cell_list with record
		level			: type_net_level;
		disable_value	: type_bit_char_class_0;
	end record;
	package type_list_of_static_control_cells_class_PX is new vectors
		(index_type => positive, element_type => type_static_control_cell_class_PX);
	list_of_static_control_cells_class_PX : type_list_of_static_control_cells_class_PX.vector;

	type type_static_output_cell_class_PX is new type_cell_of_cell_list with record
		drive_value		: type_bit_char_class_0;
	end record;
	package type_list_of_static_output_cells_class_PX is new vectors
		(index_type => positive, element_type => type_static_output_cell_class_PX);
	list_of_static_output_cells_class_PX : type_list_of_static_output_cells_class_PX.vector;

	type type_static_output_cell_class_DX_NR is new type_cell_of_cell_list with record
		drive_value		: type_bit_char_class_0;
	end record;
	package type_list_of_static_output_cells_class_DX_NR is new vectors
		(index_type => positive, element_type => type_static_output_cell_class_DX_NR);
	list_of_static_output_cells_class_DX_NR : type_list_of_static_output_cells_class_DX_NR.vector;

	type type_static_expect_cell ( level : type_net_level) is new type_cell_of_cell_list with record
		expect_value	: type_bit_char_class_0;
		case level is
			when secondary =>
				primary_net_is	: type_net_name.bounded_string;
			when primary => null;
		end case;
	end record;
	package type_list_of_static_expect_cells is new indefinite_vectors
		(index_type => positive, element_type => type_static_expect_cell);
	list_of_static_expect_cells : type_list_of_static_expect_cells.vector;

	type type_atg_expect_cell ( level : type_net_level) is new type_cell_of_cell_list with record
		case level is
			when secondary =>
				primary_net_is	: type_net_name.bounded_string;
			when primary => null;
		end case;
	end record;
	package type_list_of_atg_expect_cells is new indefinite_vectors
		(index_type => positive, element_type => type_atg_expect_cell);
	list_of_atg_expect_cells : type_list_of_atg_expect_cells.vector;

	type type_atg_drive_cell (controlled_by_control_cell : boolean) is new type_cell_of_cell_list with record
		case controlled_by_control_cell is
			when true =>
				inverted	: boolean;
			when others => null;
		end case;
	end record;
	package type_list_of_atg_drive_cells is new indefinite_vectors
		(index_type => positive, element_type => type_atg_drive_cell);
	list_of_atg_drive_cells : type_list_of_atg_drive_cells.vector;

	type type_input_cell_class_NA ( level : type_net_level) is new type_cell_of_cell_list with record
		case level is
			when secondary =>
				primary_net_is	: type_net_name.bounded_string;
			when primary => null;
		end case;
	end record;
	package type_list_of_input_cells_class_NA is new indefinite_vectors
		(index_type => positive, element_type => type_input_cell_class_NA);
	list_of_input_cells_class_NA : type_list_of_input_cells_class_NA.vector;

	-- cell lists entries end --------------------------------------------------------


	
	-- FUNCTIONS AND PROCEDURES

	type type_degree_of_database_integrity_check is ( none, light, medium, full);
	degree_of_database_integrity_check : type_degree_of_database_integrity_check := medium;
	-- The degree here is a default. It may be overwritten by the calling unit.
	-- At medium and higher degree those checks are made when reading the database:
	--  verify_pin_appears_only_once_in_net_list
	--  verify_cell
	--  verify_net_appears_only_once_in_net_list
	
	procedure read_uut_database;
	
	
	----- OPTIONS FILE RELATED BEGIN----------------------------------------------------------------------
	options_keyword_net					: constant string (1..3)  := "Net"; 
	-- marks a secondary net in options file.
		
	options_keyword_secondary_nets		: constant string (1..14) := "secondary_nets"; 
	-- used in header seccondary net section

	options_keyword_connectors			: constant string (1..10) := "connectors";
	options_keyword_bridges				: constant string (1..7)  := "bridges";
	options_keyword_array				: constant string (1..5)  := "array";
	-- useed in mkoptions.conf


-- 	type type_options_class_identifier is ( CLASS );
-- 	type type_options_net_identifier is ( NET );
-- 	type type_options_net_has_secondary_nets is new boolean; -- := false;
-- 	type type_options_net (has_secondaries : type_options_net_has_secondary_nets; secondary_net_count : natural) is
-- 		record
-- 			name						: type_net_name.bounded_string;
-- 			class						: type_net_class;
-- 			line_number					: positive;
-- 			case has_secondaries is
-- 				when true =>
-- 					list_of_secondary_net_names	: type_list_of_secondary_net_names.vector;
-- 				when false =>
-- 					null;
-- 			end case;
-- 		end record;
-- 	package type_list_of_options_nets is new indefinite_vectors ( index_type => positive, element_type => type_options_net);
-- 	use type_list_of_options_nets;


-- FUNCTIONS AND PROCEDURES
	function get_secondary_nets (name_net : type_net_name.bounded_string) return type_list_of_secondary_net_names.vector;
	-- returns a list of secondary nets connected to the given primary net
	-- if there are no secondary nets or if the given net itself is a secondary net, an empty list is returned

	function query_render_net_class (
	-- returns true if class rendering allowed
	--primary_net_name 					: in type_net_name.bounded_string;
		primary_net_cursor 					: in type_list_of_nets.cursor; -- the net it is about
		primary_net_class					: in type_net_class;
		list_of_secondary_net_names			: in type_list_of_secondary_net_names.vector
		) return boolean; 
	
	function instruction_present(instruction_in : type_string_of_bit_characters_class_1) return boolean;
	-- returns false if given instruction opcode contains no 1 and no 0

	function drive_value_derived_from_class (class_given : type_net_class) return type_bit_char_class_0;
	function expect_value_derived_from_class (class_given : type_net_class) return type_bit_char_class_0;

	function inverted_status_derived_from_class_and_disable_value (
		class			: in type_net_class;
		disable_value	: in type_bit_char_class_0) return boolean;

	function disable_value_derived_from_class_and_inverted_status(
		class_given : type_net_class;
		inverted_given : boolean) return type_bit_char_class_0;

	procedure print_bic_info (bic_name : in type_device_name.bounded_string);
	procedure print_net_info (net_name : in type_net_name.bounded_string);	
	procedure print_scc_info (bic_name : in type_device_name.bounded_string; control_cell_id : in type_cell_id);

	function is_scanport_active (id : in type_scanport_id) return boolean;
	-- returns true if scanport with given id is maked active

	function number_of_active_scanports return natural;
	-- returns the number of active scanpaths

    function is_bic (name_of_ic_given: in type_device_name.bounded_string) return boolean;
    -- Returns true if given device is a bic (as listed in section scanpath configuration)
    
	function is_shared (bic_name : in  type_device_name.bounded_string; control_cell_id : type_cell_id) return boolean;
	-- returns true if given bic exists and control cell is shared

	function is_primary (name_net : in type_net_name.bounded_string) return boolean;
	-- returns true if given net is a primary net

	function get_primary_net (name_net : in type_net_name.bounded_string) return type_net_name.bounded_string;
	-- returns the name of the superordinated primary net.
	-- if given net is a primary net, the same name will be returned
	
	function get_number_of_secondary_nets (name_net : in type_net_name.bounded_string) return natural;
	-- returns the number of secondary nets connected to the given primary net

    function get_bic (bic_name : in type_device_name.bounded_string) return type_bscan_ic;
    -- returns a full bic as type_bscan_ic
    
	function occurences_of_pin (
	-- Returns the number of occurences of a device pin in the database netlist.
		device_name				: in type_device_name.bounded_string; 	-- the device name
		pin_name				: in type_pin_name.bounded_string;		-- the pin name
		quit_on_first_occurence	: in boolean := true					-- return after first occurence
		) return natural;
	
	
end m1_database;

