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
		KICAD,
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



-- STATISTICS
	pin_count : natural := 0;
	-- NOTE: device and net count is to be taken from length of map_of_devices and type_map_of_regular_nets

-- PINS
	-- This type specifies a regular pin. Pins are stored in a vector type_list_of_pins:.
	type type_pin is tagged record
		name_device	: type_device_name.bounded_string;
		name_pin 	: type_pin_name.bounded_string;		
	end record;
	package type_list_of_pins is new vectors ( index_type => positive, element_type => type_pin);	

	-- If we deal with assembly variants, a pin has the additional "mounted"-flag.
	-- Those pins are stored in a vector type_list_of_pins_of_variants:
	type type_pin_of_variant is new type_pin with record
		mounted 	: boolean := false;
	end record;
	package type_list_of_pins_of_variants is new vectors (
		index_type => positive,
		element_type => type_pin_of_variant);

-- NETS
	-- The basic net is specified as:
	-- By default all nets in a CAE-netlist are realworld things.
	-- Some CAE vendors (like Zuken) write unconnected pins in the netlist (which is a good idea)
	-- If unconnected pins are encountered, they may get connected to a virtual net.
	-- The purpose of a virtual net is to address unconnected pins in later test generation,
	-- thus increasing test converage.
	-- When writing the skeleton file, the statistics function uses the virtual-flag to distiguish
	-- between real and virtual nets.
	type type_net_base is tagged record
		virtual : boolean := false; 
	end record;
	
	-- This type specifies a regular net.
	-- We store those nets in map_of_nets:
	type type_net is new type_net_base with record
        pins    : type_list_of_pins.vector;
    end record;
	use type_net_name;
    package type_map_of_nets is new ordered_maps ( key_type => type_net_name.bounded_string, element_type => type_net);
	map_of_nets : type_map_of_nets.map;

	-- If we deal with assembly variants, a net has pins with the "mounted"-flag:
	-- We store those nets in a map.
	type type_net_with_variants is new type_net_base with record
        pins    : type_list_of_pins_of_variants.vector;
    end record;
	package type_map_of_nets_with_variants is new ordered_maps ( 
		key_type => type_net_name.bounded_string,
		element_type => type_net_with_variants);
	map_of_nets_with_variants : type_map_of_nets_with_variants.map;

	
-- DEVICES
	-- This type specifies a regular device.
	-- Regular devices are stored in a map and accessed by their name:
    type type_device is tagged record
        packge  : type_package_name.bounded_string;
		value   : type_device_value.bounded_string;
    end record;
	use type_device_name;
	package type_map_of_devices is new ordered_maps ( 
		key_type => type_device_name.bounded_string,
		element_type => type_device);
	map_of_devices : type_map_of_devices.map;

	-- Devices which have assembly variants are stored in a vector and are accessed by a positive.
	-- This type should be used when devices occure multiple times within the CAD netlist (like protel)
	type type_device_with_variants is new type_device with record
        name    		: type_device_name.bounded_string;
		has_variants	: boolean 	:= false;
		variant_id		: positive 	:= 1;		-- the variant number in the order of appearance in netlist
		mounted			: boolean	:= false;
		processed		: boolean	:= false;
    end record;
	package type_list_of_devices_with_variants is new vectors ( 
		index_type => positive,
		element_type => type_device_with_variants);
    use type_list_of_devices_with_variants;
	list_of_devices_with_variants : type_list_of_devices_with_variants.vector;


	
	procedure write_skeleton (
	-- writes the skeleton file based on map_of_devices and map_of_nets
		module_name : in string;
		module_version : in string);


	function virtual_net_name (
	-- builds from a given device and pin name something like "virtual_net_on_device_IC300_pin_P77"
		device	: in type_device_name.bounded_string; -- like IC300
		pin		: in type_pin_name.bounded_string) -- like 5, P77 or AM54
		return type_net_name.bounded_string;



-- GENERICS
	
	generic
		max : positive;
		type item is private;
	package stack_lifo is
		procedure push (x : item);
		function pop return item;
		function depth return natural;
		procedure init;
	end stack_lifo;

	
end m1_import;

