-- ---------------------------------------------------------------------------
--                                                                          --
--                          SYSTEM M-1 IMPORT                               --
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


with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;
with ada.text_io;				use ada.text_io;
with ada.float_text_io;			use ada.float_text_io;

with ada.containers;			use ada.containers;
with ada.containers.vectors;
with ada.containers.ordered_maps;
with ada.containers.doubly_linked_lists;



with ada.exceptions;


--with ada.containers.ordered_sets;
with m1_base; 					use m1_base;
with m1_database;				use m1_database;
with m1_string_processing;		use m1_string_processing;
with m1_files_and_directories; 	use m1_files_and_directories;

package m1_import is

	
	-- CAD / NETLIST / PARTLIST IMPORT 
	type type_format_cad is (
		EAGLE,
		ORCAD,
		PROTEL,
		ZUKEN
		);
	format_cad		: type_format_cad;
	
	type type_cad_import_target_module is ( main , sub );

	text_skeleton_section_info			: constant string (1..4) := "info";


	
	type type_skeleton_pin is record
			device_name			: type_device_name.bounded_string;
			device_class		: type_device_class := device_class_default;
			device_value		: type_device_value.bounded_string;
			device_package		: type_package_name.bounded_string;
			device_pin_name		: type_pin_name.bounded_string;
		end record;
	package type_skeleton_pinlist is new doubly_linked_lists(element_type => type_skeleton_pin);
	use type_skeleton_pinlist;
	
	type type_skeleton_net is record
			name			: type_net_name.bounded_string;
			--class			: type_net_class;
			--pin_count		: positive;
			pin_list		: type_skeleton_pinlist.list;
			--pin_cursor		: pin_container.cursor;
		end record;
	package type_skeleton_netlist is new doubly_linked_lists(element_type => type_skeleton_net);
	use type_skeleton_netlist;
-- 	netlist : net_container.list;

	use type_universal_string;
	package type_skeleton_info is new vectors (element_type => type_universal_string.bounded_string, index_type => positive);
	use type_skeleton_info;

	module_name_length_max : constant positive := 100;
	package type_module_name is new generic_bounded_length(module_name_length_max); 

	type type_skeleton is record
		name	: type_module_name.bounded_string;
		info	: type_skeleton_info.vector;
		netlist	: type_skeleton_netlist.list;
	end record;

	
	-- 	procedure read_skeleton (name_of_skeleton : in string := name_file_skeleton_default);
	function read_skeleton (name_of_skeleton : in string := name_file_skeleton_default) return type_skeleton;
	-- Reads the skeleton and adds nets in container netlist.



	
	
	cad_import_target_module 			: type_cad_import_target_module;
	target_module_prefix 				: type_universal_string.bounded_string;
	
	keyword_assembly_variant_active		: constant string (1..6) := "active";
	
	text_identifier_cad_netlist			: constant string (1..7) := "netlist";
	text_identifier_cad_partlist		: constant string (1..8) := "partlist";
	text_skeleton_section_netlist		: constant string (1..16) := "netlist_skeleton";
	skeleton_field_count_pin			: constant positive := 5; -- "RN402 ? 8x10k SIL9 6"

	procedure put_format_cad;

	procedure put_message_on_failed_cad_import(format_cad : in type_format_cad);

	procedure write_advise_dos2unix;

--	procedure write_statistics (device_count : in natural; net_count : in natural; pin_count : in natural);	

-- 	procedure write_info (
-- 		module_name : in string;
-- 		module_version : in string;
-- 		device_count : in natural;
-- 		net_count : in natural;
-- 		pin_count : in natural);

	-- PINS
	pin_count_mounted : natural := 0; -- for statistics
	type type_pin is record
		name_device	: type_device_name.bounded_string;
		name_pin 	: type_pin_name.bounded_string;		
		mounted 	: boolean := false;
	end record;
	package type_list_of_pins is new vectors ( index_type => positive, element_type => type_pin);

	-- DEVICES
	device_count_mounted : natural := 0; -- for statistics

	-- Regular devices (without assembly variants) are stored in a map and accessed by their name:
    type type_base_device is tagged record
        packge  : type_package_name.bounded_string;
		value   : type_device_value.bounded_string;
    end record;
	use type_device_name;
	package type_map_of_devices is new ordered_maps ( 
		key_type => type_device_name.bounded_string,
		element_type => type_base_device);
	map_of_devices : type_map_of_devices.map;

	-- Devices which have assembly variants are stored in a vector and accessed by a positive:	
	type type_device is new type_base_device with record
        name    : type_device_name.bounded_string;
		has_variants	: boolean 	:= false; 	-- set by manage_assembly_variants as first action
		variant_id		: positive 	:= 1;		-- the variant number
		mounted			: boolean	:= false;
		processed		: boolean	:= false;
    end record;
	package type_list_of_devices is new vectors ( 
		index_type => positive,
		element_type => type_device);
    use type_list_of_devices;
	list_of_devices : type_list_of_devices.vector;


	-- NETS
    type type_net is record
        name    : type_net_name.bounded_string;
        pins    : type_list_of_pins.vector;
    end record;
    package type_list_of_nets is new vectors ( index_type => positive, element_type => type_net); -- CS: map ?
	list_of_nets : type_list_of_nets.vector; -- here we collect all nets of the design

	procedure write_skeleton (module_name : in string; module_version : in string);
	-- writes the skeleton file from list_of_nets and list_of_devices
	
end m1_import;

