------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKOPTIONS                           --
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
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;
with ada.containers;        	use ada.containers;
with ada.containers.vectors;
with ada.containers.indefinite_vectors;

--with ada.strings.unbounded; use ada.strings.unbounded;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings; 				use ada.strings;
with ada.exceptions; 			use ada.exceptions;
 
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with csv;
with m1_base; 					use m1_base;
with m1_string_processing;		use m1_string_processing;
with m1_database;				use m1_database;
with m1_files_and_directories;	use m1_files_and_directories;

procedure mkoptions is

	use type_name_database;
	use type_name_file_options;
	use type_name_file_routing;

	use type_net_name;
	use type_device_name;
	use type_pin_name;	
	use type_list_of_pins;
	use type_list_of_nets;

	
	version				: constant string (1..3) := "030";
	
	prog_position		: natural := 0;
	
	cluster_counter		: natural := 0;
	length_of_netlist	: count_type;

-- 	type type_options_net is new type_net with record
-- 		cluster		: boolean;
-- 	end record;

	keyword_allowed		: constant string (1..7) := "allowed";
	
	-- A cluster is a group of nets with the same cluster id.
 	type type_cluster is record
-- 		ordered			: boolean := false;
		bs_capable		: boolean := false;
-- 		size			: natural := 0;
		nets			: type_list_of_nets.vector;
	end record;
	package type_list_of_clusters is new vectors (index_type => positive, element_type => type_cluster);
	use type_list_of_clusters;
	list_of_clusters : type_list_of_clusters.vector;


	procedure write_routing_file_header is
	begin
		set_output(file_routing);
		csv.put_field(text => "-- NET ROUTING TABLE"); csv.put_lf;
		csv.put_field(text => "-- created by mkoptions version: "); csv.put_field(text => version); csv.put_lf;
		csv.put_field(text => "-- date:"); csv.put_field(text => date_now);
		csv.put_lf(count => 2);
		set_output(standard_output);
	end write_routing_file_header;

	procedure write_options_file_header is
	begin
		set_output(file_options);
		put_line ("-- THIS IS AN OPTIONS FILE FOR " & to_upper(text_identifier_database) & row_separator_0 & to_string(name_file_database));
		put_line ("-- created by " & name_module_mkoptions & " version " & version);	
		put_line ("-- date " & date_now);
		put_line ("-- Please modifiy net classes and primary/secondary dependencies according to your needs."); 
		new_line;
		set_output(standard_output);
	end write_options_file_header;


--     length_of_device_name : constant positive := 100;
--     package type_device_name is new generic_bounded_length(length_of_device_name);
-- 	use type_device_name;
-- 
--     length_of_pin_name : constant positive := 10;
--     package type_pin_name is new generic_bounded_length(length_of_pin_name);
--     use type_pin_name;

	type type_side is ( A, B );
	
	length_pins_of_bridge_max : constant := 1 + 2 * pin_name_length; -- for something like "1-8" or "999-999"
	package type_pins_of_bridge is new generic_bounded_length(length_pins_of_bridge_max);
	
	type type_pin is record
		name			: type_pin_name.bounded_string;
--		processed		: boolean := false;
		connected		: boolean := false;
	end record;
	
	type type_bridge_preliminary is tagged record
		name			: type_device_name.bounded_string;
		wildcards		: boolean := false; -- true if name contains asterisks (*) or quesition marks (?)
-- 		pin_a			: type_pin;
-- 		pin_b			: type_pin;
	end record;

	separator	: constant string (1..1) := "-";
	type type_bridge_within_array is record -- like "1-8 2-7"
		pin_a			: type_pin;
		pin_b			: type_pin;
	end record;
	package type_list_of_bridges_within_array is new vectors 
		(index_type => positive, element_type => type_bridge_within_array);
	list_of_bridges_within_array_preliminary : type_list_of_bridges_within_array.vector;

	empty_list_of_bridges_within_array : type_list_of_bridges_within_array.vector; -- NOTE: do not append anything to it !	
	-- CS: reserve capacity of zero might improve performance.
	
	use type_list_of_bridges_within_array;
	
	type type_bridge ( is_array : boolean) is new type_bridge_preliminary with record
		case is_array is
			when true => list_of_bridges : type_list_of_bridges_within_array.vector;
			when false => 
				pin_a	: type_pin;
				pin_b	: type_pin;
		end case;
	end record;
	package type_list_of_bridges is new indefinite_vectors 
		( index_type => positive, element_type => type_bridge);
	use type_list_of_bridges;
	list_of_bridges : type_list_of_bridges.vector;
	length_list_of_bridges : count_type;

	type type_connector_mapping is ( one_to_one , cross_pairwise );
	connector_mapping_default : constant type_connector_mapping := one_to_one;
	package type_list_of_pin_names is new vectors ( index_type => positive, element_type => type_pin_name.bounded_string);
	use type_list_of_pin_names;
	type type_connector_pair is record
		name_a			: type_device_name.bounded_string;
 		name_b			: type_device_name.bounded_string;
		pin_ct_a		: natural := 0;
		pin_ct_b		: natural := 0;
		mapping			: type_connector_mapping := one_to_one;
		processed_pins_a: type_list_of_pin_names.vector;
		processed_pins_b: type_list_of_pin_names.vector;
-- 		exempted_pins_a	: type_list_of_pin_names.vector; -- CS: for pins used for special purposes like shielding
-- 		exempted_pins_b	: type_list_of_pin_names.vector;
	end record;
	package type_list_of_connector_pairs is new vectors ( index_type => positive, element_type => type_connector_pair);
	use type_list_of_connector_pairs;
	list_of_connector_pairs : type_list_of_connector_pairs.vector;
	length_list_of_connector_pairs : count_type;

	function has_wildcards (device : in type_device_name.bounded_string) return boolean is
		asterisks_count 		: natural := type_device_name.count(device, 1 * latin_1.asterisk);
		question_marks_count	: natural := type_device_name.count(device, 1 * latin_1.question);
		pos_asterisk			: natural := type_device_name.index(device, 1 * latin_1.asterisk);
		pos_question_mark		: natural := type_device_name.index(device, 1 * latin_1.question);		
		wildcards_found			: boolean := false;
	begin -- has_wildcards
		if asterisks_count > 0 then -- if there are asterisks
			if pos_asterisk > 1 then -- make sure the first character is not an asterisk
				wildcards_found := true;
			else
				new_line(file_mkoptions_messages);
				write_message (
					file_handle => file_mkoptions_messages,
					text => message_error & "wildcard not allowed as first character !",
					console => true);
				raise constraint_error;
			end if;
		end if;

		if question_marks_count > 0 then -- if there are questions marks
			if pos_question_mark > 1 then -- make sure the first character is not a question mark
				wildcards_found := true;
			else
				new_line(file_mkoptions_messages);
				write_message (
					file_handle => file_mkoptions_messages,
					text => message_error & "wildcard not allowed as first character !",
					console => true);
				raise constraint_error;				
			end if;
		end if;
		
		return wildcards_found;
	end has_wildcards;

	function read_bridges_of_array (
	-- Reads array pins like 1-8 or 2-7 and returns them in a list.
	-- Does not check if pins exist in netlist.
	-- Does not check if pins are connected.
		line 		: in string; -- contains something like "RN303 array 1-2 3-4 5-6 7-8"
		field_count : in positive;
		line_counter: in positive) 
		return type_list_of_bridges_within_array.vector is
		list_of_bridges : type_list_of_bridges_within_array.vector;

		use type_pins_of_bridge; 
		field : type_pins_of_bridge.bounded_string; -- something like "1-8"

		bridge 		: type_bridge_within_array;
		pos_sep 	: positive; -- position of separator "-" 
		
	begin -- read_bridges_of_array
		for i in 3..field_count loop -- we start reading in field 3 
			field := to_bounded_string(get_field_from_line(line,i));
			if type_pins_of_bridge.count(field,separator) = 1 then -- there must be a single separator
				pos_sep 			:= type_pins_of_bridge.index(field,separator); -- get position of separator

				-- get pin names left and right of separator
				bridge.pin_a.name	:= to_bounded_string(type_pins_of_bridge.slice(field, 1, pos_sep-1));
				bridge.pin_b.name	:= to_bounded_string(type_pins_of_bridge.slice(field, pos_sep+1, length(field)));

-- 				write_message (
-- 					file_handle => file_mkoptions_messages,
-- 					identation => 3,
-- 					text => "pins: " & to_string(bridge.pin_a.name) & separator & to_string(bridge.pin_b.name),
-- 					console => false);

				-- CS: check multiple occurences of pin names and bridges in mkoptions.conf

				append(list_of_bridges, bridge);
				
			else
				-- put a final linebreak at end of line in logfile
				new_line (file_mkoptions_messages);
				
				write_message (
					file_handle => file_mkoptions_messages,
					text => message_error & "in line" & positive'image(line_counter) & ": " 
						& "A single separator '" & separator & "' expected between pin names ! "
						& "Example: RN4 array 1-8 2-7 3-6 4-5",
					console => true);
				raise constraint_error;
			end if;
			
		end loop;
		return list_of_bridges;
	end read_bridges_of_array;


	function set_bridge_pins (bridge_in : in type_bridge_preliminary) return type_bridge is
	-- Assigns the pin names a and b to the given single 2-pin bridge device.
	-- In the order the bridge device occurs in the netlist the pin names a and b are assigned.
	-- Raises an error if bridge device occurs more than twice.
	-- The bridge returned is a type_bridge as a single two-pin bridge.
		net					: type_net;
		pin					: m1_database.type_pin;
		length_of_pinlist	: count_type; -- CS: we assume there are no zero-pin nets
		occurences			: natural := 0;

		bridge_out			: type_bridge := (bridge_in with
								is_array => false,
								pin_a => ( name => to_bounded_string(""), -- to be overwritten later
-- 										   processed => false, -- CS: anoying default
										   connected => false -- CS: anoying default
										 ), 
								pin_b => ( name => to_bounded_string(""), -- to be overwritten later
-- 										   processed => false, -- CS: anoying default 
										   connected => false -- CS: anoying default
										 ));
	begin -- set_bridge_pins
		-- We search the database netlist until the given bridge_in found.
		-- We count the matches and assign the pin names a and b.

		write_message (
			file_handle => file_mkoptions_messages,
-- 			identation => 3,
			text => " with pins ",
			lf => false,
			console => false);
		
		loop_netlist:
		for i in 1..length(list_of_nets) loop -- loop in netlist
			net := element(list_of_nets, positive(i)); -- load a net
			length_of_pinlist := length(net.pins); -- load number of pins in the net
			for i in 1..length_of_pinlist loop -- loop in pinlist
				pin := element(net.pins, positive(i)); -- load a pin
				if pin.device_name = bridge_in.name then -- on device name match

					-- Count occurences. The first occurence is pin a. The second pin b.
					-- Further occurences cause an error depending on degree_of_database_integrity_check.
					occurences := occurences + 1;

					case occurences is
						when 1 =>
							bridge_out.pin_a.name := pin.device_pin_name;
							
							write_message (
								file_handle => file_mkoptions_messages,
								text => to_string(pin.device_pin_name) & row_separator_0,
								lf => false,
								console => false);
							
						when 2 =>
							bridge_out.pin_b.name := pin.device_pin_name;

							-- make sure pin a and b do have different names
							if bridge_out.pin_a.name = bridge_out.pin_b.name then
								new_line(file_mkoptions_messages);
								write_message (
									file_handle => file_mkoptions_messages,
									text => message_error & "pin " & to_string(pin.device_pin_name)
										& " occurs more than once !",
									console => true);
								raise constraint_error;
							end if;
								

							write_message (
								file_handle => file_mkoptions_messages,
								text => to_string(pin.device_pin_name) & row_separator_0,
								console => false);
							
							-- CS: With a light integrity check it is ok to exit after pin b.
-- 							if degree_of_database_integrity_check < medium then
-- 								exit loop_netlist;
-- 							end if;
							
						when others =>
							new_line(file_mkoptions_messages);
							write_message (
								file_handle => file_mkoptions_messages,
								text => message_error & "bridge device " & to_string(bridge_in.name)
									& " has more than 2 pins !",
								console => true);
							raise constraint_error;
					end case;
				end if;
			end loop;
		end loop loop_netlist;

		-- write a warning if bridge has only one pin connected
		if occurences = 1 then
			new_line(file_mkoptions_messages);
			write_message (
				file_handle => file_mkoptions_messages,
				text => message_warning & "bridge device " & to_string(bridge_in.name)
					& " has only one connected pin !",
				console => false);
		end if;
		
		return bridge_out;
	end set_bridge_pins;

	-- CS: move this function to m1_datbase
	function device_occurences_in_netlist( 
	-- Returns the number of occurences of the given device within the database netlist.
	-- If wildcards is true, wildcards such as asterisk and question marks in device are respected.
		device 		: in type_device_name.bounded_string;
		wildcards	: in boolean := false ) return natural is

		net					: type_net;
		pin					: m1_database.type_pin;
		length_of_pinlist	: count_type; -- CS: we assume there are no zero-pin nets
		occurences			: natural := 0;
	begin -- device_occurences_in_netlist
		for i in 1..length(list_of_nets) loop -- loop in netlist
			net := element(list_of_nets, positive(i)); -- load a net
			length_of_pinlist := length(net.pins); -- load number of pins in the net
			for i in 1..length_of_pinlist loop -- loop in pinlist
				pin := element(net.pins, positive(i)); -- load a pin
				if wildcards then
					if wildcard_match(
						text_with_wildcards => to_string(device), -- the device being inquired for
						text_exact => to_string(pin.device_name)) then -- on device name match, count matches
							occurences := occurences + 1;
					end if;
				else
					if pin.device_name = device then -- on device name match, count matches
						occurences := occurences + 1;
					end if;
				end if;
			end loop;
		end loop;
		return occurences;
	end device_occurences_in_netlist;


	procedure verify_array_pins ( 
	-- Checks if the pins of the given array device exist in netlist.
	-- Checks if the given array device occurs in netlist more often than pins have been specified in mkoptions.conf.
		name	: in type_device_name.bounded_string;
		bridges	: in type_list_of_bridges_within_array.vector) is

		bridge_count	: positive := positive(length(bridges)); -- number of bridges within array
		bridge			: type_bridge_within_array; -- a single bridge within array

		procedure message_warning_on_missing_pin (
			device 	: in type_device_name.bounded_string;
			pin		: in type_pin_name.bounded_string) is
		begin
			-- new_line(file_mkoptions_messages);
			write_message (
				file_handle => file_mkoptions_messages,
				text => message_warning & "device " & to_string(device) & " pin/pad " & to_string(pin) & " not found !",
				console => false);
		end message_warning_on_missing_pin;
		
	begin -- verify_array_pins
		write_message (
			file_handle => file_mkoptions_messages,
			lf => false,
			text => " is array with pins ",
			console => false);

		-- write pins in logfile		
		for i in 1..bridge_count loop
			bridge := element(bridges, i);
			write_message (
				file_handle => file_mkoptions_messages,
				lf => false,
				text => to_string(bridge.pin_a.name) & separator & to_string(bridge.pin_b.name) & row_separator_0,
				console => false);
		end loop;
		new_line(file_mkoptions_messages);

		-- Send warning if pin a or b does not exist in netlist					
		for i in 1..bridge_count loop
			bridge := element(bridges, i);

			if occurences_of_pin (device_name => name, pin_name => bridge.pin_a.name) = 0 then
				message_warning_on_missing_pin(device => name, pin => bridge.pin_a.name);
			end if;

			if occurences_of_pin (device_name => name, pin_name => bridge.pin_b.name) = 0 then
				message_warning_on_missing_pin(device => name, pin => bridge.pin_b.name);
			end if;
		end loop;

		-- Send warning if a bridge device has more pins than specified in mkoptions.conf
		if device_occurences_in_netlist(name) > bridge_count*2 then -- bridge_count *2 because a bridge has 2 pins
			write_message (
				file_handle => file_mkoptions_messages,
				text => message_warning & "device " & to_string(name) 
					& " has more pins/pads than specified here !",
				console => false);
		end if;

	end verify_array_pins;
	
	procedure read_mkoptions_configuration is
	-- Reads mkoptions.conf, checks if connectors and bridge devices exist.
	-- Collects connector pairs in list_of_connector_pairs.
	-- Collects bridges in list_of_bridges.
		type_line_length_max		: constant natural := 1000;
		package type_line_of_file is new generic_bounded_length(type_line_length_max); use type_line_of_file;
		line						: type_line_of_file.bounded_string;
		line_counter				: natural := 0;
		field_count					: natural;
		section_connectors_entered	: boolean := false;
		section_bridges_entered 	: boolean := false;
		
		conpair_preliminary 		: type_connector_pair;
		bridge_preliminary			: type_bridge_preliminary;
		bridge_is_array				: boolean := false;

		bridge_valid				: boolean := false; -- Set to false if mkoptions.conf contains a bridge device
														-- that does exist in database netlist.
														-- If bridge device is not valid, it will not be added
														-- to list_of_bridges.

		procedure append_bridge is
		-- Depending on the flag bridge_is_array we either append a bridge device with a list of sub-bridges (like 1-8, 2-7)
		-- or a single 2-pin bridge device.
		begin
			case bridge_is_array is

				when true =>
					-- Before appending, the array pins must be checked.
					verify_array_pins(bridge_preliminary.name, list_of_bridges_within_array_preliminary);
					append(list_of_bridges, (bridge_preliminary with 
												is_array => true, 
												list_of_bridges => list_of_bridges_within_array_preliminary));

				when false =>
					-- Before appending, the pins of the single 2-pin bridge must be set.
					-- mkoptions.conf does not provide pin names of a single bridge device.
					-- set_bridge_pins elaborates the pin names and returns a type_bridge.
					append(list_of_bridges, set_bridge_pins(bridge_preliminary));

			end case;
		end append_bridge;

		function bridge_is_listed return boolean is
		-- Returns true is bridge device already in list_of_bridges.
			is_listed : boolean := false;
		begin
			for i in 1..length(list_of_bridges) loop
				if element(list_of_bridges, positive(i)).name = bridge_preliminary.name then
					is_listed := true;
					exit;
				end if;
			end loop;
			return is_listed;
		end bridge_is_listed;
		
		procedure add_bridges_matching_wildcard_to_list_of_bridges is
		-- Searches in netlist for bridge devices that match the preliminary bridge name 
		-- (The preliminary bridge name contains wildcards.)
		-- and appends them to the list_of_bridges.
			net		: type_net;
			pin		: m1_database.type_pin;
			scratch	: type_device_name.bounded_string;
		begin -- add_bridges_matching_wildcard_to_list_of_bridges

			loop_netlist:
			for i in 1..length_of_netlist loop
				net := element(list_of_nets, positive(i)); -- load a net
				for i in 1..length(net.pins) loop
					pin := element(net.pins, positive(i)); -- load a pin

-- 					write_message (
-- 						file_handle => file_mkoptions_messages,
-- 						identation => 3,
-- 						text => to_string(pin.device_name),
-- 						console => true);
					
					if wildcard_match( -- test if bridge device name matches preliminary bridge name
						text_exact			=> to_string(pin.device_name),
						text_with_wildcards	=> to_string(bridge_preliminary.name) ) 
					then
						-- On match, overwrite preliminary name with exact name.
						scratch := bridge_preliminary.name; -- backup preliminary name
						bridge_preliminary.name := pin.device_name;

-- 						write_message (
-- 							file_handle => file_mkoptions_messages,
-- 							identation => 3,
-- 							text => to_string(bridge_preliminary.name),
-- 							console => false);
						
						-- if bridge not already in list
						if not bridge_is_listed then
						
							-- report exact bridge name in logfile
							write_message (
								file_handle => file_mkoptions_messages,
								identation => 3,
								text => to_string(bridge_preliminary.name),
								lf => false,
								console => false);
							
							-- Now the bridge name is definite and we can append it to the list_of_bridges.
							append_bridge;
							
						end if;
						
						bridge_preliminary.name := scratch; -- restore preliminary name
					end if;
				end loop;
			end loop loop_netlist;
		end add_bridges_matching_wildcard_to_list_of_bridges;
		
	begin -- read_mkoptions_configuration
		write_message (
			file_handle => file_mkoptions_messages,
			text => "reading file " & name_file_mkoptions_conf & "...",
			console => true);
		
		open (file => file_mkoptions, mode => in_file, name => name_file_mkoptions_conf);
		set_input(file_mkoptions);
		while not end_of_file loop
			line 			:= to_bounded_string(remove_comment_from_line(get_line));
			line_counter	:= line_counter + 1;
			field_count		:= get_field_count(to_string(line));
			if field_count > 0 then -- skip empty lines
				--				put_line(extended_string.to_string(line));

				-- READ CONNECTORS
				if not section_connectors_entered then -- we are outside section connectors
					-- search for header of section connectors
					if get_field_from_line(to_string(line),1) = section_mark.section and
					   get_field_from_line(to_string(line),2) = options_keyword_connectors then
						section_connectors_entered := true;

						write_message (
							file_handle => file_mkoptions_messages,
							identation => 1,
							text => "connector pairs ...",
							console => true);

					end if;
				else -- we are inside section connectors

					-- search for footer of section connectors
					if get_field_from_line(to_string(line),1) = section_mark.endsection then -- we are leaving section connectors
						section_connectors_entered := false; 
						append(list_of_connector_pairs,conpair_preliminary);
					else
						-- Read names of connectors.
						-- There must be at least 2 fields per line (for connector A and B and mapping)
						if field_count > 1 then 
							conpair_preliminary.name_a	:= to_bounded_string(get_field_from_line(to_string(line),1));
							conpair_preliminary.name_b	:= to_bounded_string(get_field_from_line(to_string(line),2));

							-- report names in logfile
							write_message (
								file_handle => file_mkoptions_messages,
								identation => 2, 
								text => type_side'image(A) & row_separator_0 
									& to_string(conpair_preliminary.name_a) 
									& row_separator_0 & type_side'image(B) 
									& row_separator_0 & to_string(conpair_preliminary.name_b),
								lf => false,
								console => false);

							-- Make sure the connector devices A and B occur netlist:
							if device_occurences_in_netlist(conpair_preliminary.name_a) = 0 then
								new_line(file_mkoptions_messages);
								write_message (
									file_handle => file_mkoptions_messages,
									text => message_error & "connector device " & to_string(conpair_preliminary.name_a)
										& " does not exist in " & text_identifier_database & " !",
										console => true);
									raise constraint_error;
							end if;
							if device_occurences_in_netlist(conpair_preliminary.name_b) = 0 then
								new_line(file_mkoptions_messages);
								write_message (
									file_handle => file_mkoptions_messages,
									text => message_error & "connector device " & to_string(conpair_preliminary.name_b)
										& " does not exist in " & text_identifier_database & " !",
										console => true);
									raise constraint_error;
							end if;

							
							-- If mapping provided in a 3rd field, read it and report in logfile. 
							-- If not provided, assume default mapping.
							if field_count > 2 then
								conpair_preliminary.mapping	:= type_connector_mapping'value(get_field_from_line(to_string(line),3));
								-- CS: helpful message when invalid mapping
							else
								conpair_preliminary.mapping := connector_mapping_default;
							end if;

							write_message (
								file_handle => file_mkoptions_messages,
								identation => 1, 
								text => "mapping " & type_connector_mapping'image(conpair_preliminary.mapping),
								console => false);
						else
							-- put a final linebreak at end of line in logfile
							new_line (file_mkoptions_messages);
							
							write_message (
								file_handle => file_mkoptions_messages,
								text => message_error & "in line" & positive'image(line_counter) & ": " 
									& "Connector pair expected ! "
									& "Example: main_X1 sub_X1",
								console => true);
							raise constraint_error;

						end if;
					end if;
				end if;

				-- READ BRIDGES
				if not section_bridges_entered then -- we are outside sectin bridges
					-- search for header of section bridges
					if get_field_from_line(to_string(line),1) = section_mark.section and
					   get_field_from_line(to_string(line),2) = options_keyword_bridges then
						section_bridges_entered := true;

						write_message (
							file_handle => file_mkoptions_messages,
							identation => 1,
							text => "bridges ...",
							console => true);

					end if;
				else -- we are inside section bridges

					-- search for footer of section bridges
					if get_field_from_line(to_string(line),1) = section_mark.endsection then 
						-- we are leaving section bridges
						section_bridges_entered := false; 
					else
						-- read bridges like:
						--  R4
						--  R11*
						--  RN303 array 1-2 3-4 5-6 7-8

						-- read name of bridge and check if name contains wildcards
						bridge_preliminary.name := to_bounded_string(get_field_from_line(to_string(line),1));

						-- report bridge in logfile
						write_message (
							file_handle => file_mkoptions_messages,
							identation => 2,
							text => to_string(bridge_preliminary.name),
							lf => false,
							console => false);

						bridge_preliminary.wildcards := has_wildcards(bridge_preliminary.name);

						-- If bridge name contains wildcards, count matches. Write a warning if
						-- no device in netlist matches bridge name and regard bridge as invalid.
						if bridge_preliminary.wildcards then
							
							if device_occurences_in_netlist(device => bridge_preliminary.name, wildcards => true) = 0 then
								bridge_valid := false;
								new_line(file_mkoptions_messages);
								write_message (
									file_handle => file_mkoptions_messages,
									text => message_warning & to_string(bridge_preliminary.name)
										& " matches no devices in " & text_identifier_database & " !",
										console => false);
							else
								bridge_valid := true;

								write_message (
									file_handle => file_mkoptions_messages,
									identation => 1,
									text => "includes:",
									lf => true,
									console => false);
							end if;
							
						else
							-- No wildcards used in bridge device name.

							-- Make sure the bridge device occurs netlist at all,
							-- If device does not exist, the flag bridge_valid is set false, which results in
							-- the bridge not beeing appended to list_of_bridges.
							-- With an integrity check greater "light" this step wil be performed.
							-- CS: ?? if degree_of_database_integrity_check >= light then
								if device_occurences_in_netlist(bridge_preliminary.name) = 0 then
									bridge_valid := false;
									new_line(file_mkoptions_messages);
									write_message (
										file_handle => file_mkoptions_messages,
										text => message_warning & "device " & to_string(bridge_preliminary.name)
											& " does not exist in " & text_identifier_database & " !",
											console => false);
								else
									bridge_valid := true;
								end if;
							--end if;
						end if;

						
						if bridge_valid then -- non-existing bridge devices are ignored furhter-on

							-- Field #2 may indicate that this is an array. In this case
							-- list_of_bridges_within_array_preliminary will be filled with the 
							-- bridges within the array.
							-- We read from field 2 on. Stuff like "array 1-2 3-4 5-6 7-8"
							if field_count > 1 then
								if get_field_from_line(to_string(line),2) = options_keyword_array then
									bridge_is_array := true;

-- 									write_message (
-- 										file_handle => file_mkoptions_messages,
-- 										identation => 1,
-- 										text => "is array",
-- 										console => false);

									-- build a preliminary list of bridges from fields after "array"
									if field_count > 2 then
										list_of_bridges_within_array_preliminary := read_bridges_of_array(
											line 			=> to_string(line),
											field_count 	=> field_count,
											line_counter	=> line_counter);
										-- read_bridges_of_array does not check for existing or not connected pins !
									else
										-- put a final linebreak at end of line in logfile
	-- 									new_line (file_mkoptions_messages);
										
										write_message (
											file_handle => file_mkoptions_messages,
											text => message_error & "in line" & positive'image(line_counter) & ": " 
												& "Bridges within array expected ! Example: RN4 array 1-8 2-7 3-6 4-5",
											console => true);
										raise constraint_error;
									end if;
									
								else
									new_line (file_mkoptions_messages);
									write_message (
										file_handle => file_mkoptions_messages,
										text => message_error & "in line" & positive'image(line_counter) & ": " 
											& "Keyword '" & options_keyword_array & "' expected after device name ! "
											& "Example: RN4 array 1-8 2-7 3-6 4-5",
										console => true);
									raise constraint_error;
								end if;
							else 
								-- It is not an array of bridges but a single two-pin device
								bridge_is_array := false;
							end if;

							if bridge_preliminary.wildcards then 
								--new_line (file_mkoptions_messages);

								-- So far we only have the name of a bridge with wildcards.
								-- In order to add all matching devices, this procedure does the job:
								add_bridges_matching_wildcard_to_list_of_bridges;
							else
								-- The bridge name is definitive. So we append the bridge to the
								-- list_of_bridges right away.
								append_bridge;
							end if;
						end if; -- bridge_valid
						
					end if;
				end if;

			end if;
		end loop;

		-- set global length of connector and bridge lists (so that other operatons do not need to recalculate them anew)
		length_list_of_bridges 			:= length(list_of_bridges);
		length_list_of_connector_pairs 	:= length(list_of_connector_pairs);
		
		close(file_mkoptions);
	end read_mkoptions_configuration;
		
	procedure write_statistics is
	begin
-- 		conpair_ct := count_connector_pairs;
-- 		put ("-- connector pairs  :" & Natural'Image(conpair_ct)); new_line;	
-- 
-- 		bridge_ct := count_bridges;
-- 		--put ("-- bridges         :" & Natural'Image(bridge_ct)); new_line;	
-- 
-- 		net_ct := count_nets;
-- 		put ("-- net count total  :" & Natural'Image(net_ct) & " (incl. non-bs nets)"); new_line;
-- 		put ("--                    NOTE: Non-bs nets are commented and shown as supplementary information only."); new_line; 
-- 		put ("--                          Don't waste your time editing their net classes !"); new_line;
-- 
-- 		new_line(standard_output);		
-- 		if make_netlist
-- 			(
-- 			con_pair_list_in => make_conpair_list,
-- 			bridge_list_in => make_bridge_list
-- 			)
		-- 		then null; end if;

-- 
-- 			--write_summary
-- 			if conpair_ct > 0 then
-- 				new_line; put_line("-- CONNECTOR PAIRS ---------------------------------------------------"); new_line;
-- 				for c in 1..conpair_ct
-- 				loop
-- 					new_line;
-- 					--put_line("-- pair id       : " & trim(natural'image(c),left));
-- 					put_line("--   name A      : " & con_pair_list(c).name_a);
-- 					put_line("--   pin count A : " & trim(natural'image(con_pair_list(c).pin_ct_a),left));
-- 					put_line("--   name B      : " & con_pair_list(c).name_b);
-- 					put_line("--   pin count B : " & trim(natural'image(con_pair_list(c).pin_ct_b),left));
-- 					if con_pair_list(c).pin_ct_a = 0 then 
-- 						put_line("-- WARNING : No nets found on " & con_pair_list(c).name_a & " !"); end if;
-- 					if con_pair_list(c).pin_ct_b = 0 then 
-- 						put_line("-- WARNING : No nets found on " & con_pair_list(c).name_b & " !"); end if;
-- 					if con_pair_list(c).pin_ct_a /= con_pair_list(c).pin_ct_b then 
-- 						put_line("-- WARNING : pin count of " & con_pair_list(c).name_a & " differs from pin count of " & con_pair_list(c).name_b & " ."); end if;
-- 				end loop;	
-- 			end if;
-- 
-- 			if bridge_ct > 0 then
-- 				new_line; put_line("-- BRIDGE LIST -------------------------------------------------------"); new_line;
-- 				put_line("--   name  pin_A - pin_B "); new_line;
-- 				for b in 1..bridge_ct
-- 				loop
-- 					put_line("--   " & bridge_list(b).name & " " & bridge_list(b).pin_a & "-" & bridge_list(b).pin_b);
-- 					if bridge_list(b).part_of_array = false then -- ins v027 -- output warnings for single bridges only
-- 						-- CS: output warnings for unconnected array pins too
-- 						if bridge_list(b).pin_ct = 0 then
-- 							put("-- WARNING : No nets found on " & bridge_list(b).name ); 
-- 							put_line(". Check bridge declaration in file mkoptions.conf !");
-- 							put_line("--           " & bridge_list(b).name & " may not exist in design."); new_line; 
-- 							-- CS: should we abort the program here  with an error message ?
-- 						end if; -- mod v027
-- 						if bridge_list(b).pin_ct = 1 then
-- 							put_line("-- WARNING : Only one net found on " & bridge_list(b).name & " ! Check design !"); new_line; 
-- 						end if;
-- 
-- 					end if; -- ins v027
-- 				end loop;	
-- 			end if;

		
		null;
	end write_statistics;

	type type_result_of_bridge_query (is_bridge_pin : boolean := false) is record
		case is_bridge_pin is
			when true =>
				side			: type_side;
				device_pin_name	: type_pin_name.bounded_string;				
			when false => null;
		end case;
	end record;

	function is_pin_of_bridge (pin : in m1_database.type_pin) return type_result_of_bridge_query is
	-- Returns true if given pin belongs to a bridge.
	-- When true, the return contains the side and pin of the opposide of the bridge.
		bp 					: type_bridge_preliminary; -- a scratch variable
		pin_name_scratch	: type_pin_name.bounded_string;				
		name_a				: type_pin_name.bounded_string;
		name_b				: type_pin_name.bounded_string;
		bridge				: type_bridge := ( 
								is_array => true,
								name => to_bounded_string(""), -- anoying default
								wildcards => false, -- anoying default
								list_of_bridges => empty_list_of_bridges_within_array -- anoying default
								);
		
		number_of_bridges_in_array	: count_type;
		bridge_within_array			: type_bridge_within_array;
	begin -- is_pin_of_bridge
		if length_list_of_bridges > 0 then -- do this test if there are bridges at all

			-- search in list of bridges 
			for i in 1..length_list_of_bridges loop 
				bp := type_bridge_preliminary(element(list_of_bridges, positive(i))); -- load a bridge

				-- If device name matches we know the given pin is part of a bridge.
				-- In addition we also need the pin name of the other side of the bridge.
				-- This could be a pin of an array or a pin of something simple like a single 2-pin resistor.
				if pin.device_name = bp.name then -- device names match

					if element(list_of_bridges, positive(i)).is_array then -- something like "RN4 1-8 2-7"
						-- Search for given pin in array of bridges.
						
						-- load a device with bridges therein
						bridge := element(list_of_bridges, positive(i));

						-- load number of bridges within array (with the example above, we get 2 bridges)
						number_of_bridges_in_array := length(element(list_of_bridges, positive(i)).list_of_bridges);

						-- loop in list of bridges of array. 
						-- On match return side and pin name.
						for i in 1..number_of_bridges_in_array loop
							-- load a bridge from array, like "1-8", and save the pin names in name_a and name_b
							bridge_within_array := element(bridge.list_of_bridges, positive(i));
							name_a := bridge_within_array.pin_a.name;
							name_b := bridge_within_array.pin_b.name;

							-- if we are on side a, return name of side b
							if name_a = pin.device_pin_name then 
								return ( is_bridge_pin => true, side => B, device_pin_name => name_b);

							-- if we are on side b, return name of side a
							elsif name_b = pin.device_pin_name then
								return ( is_bridge_pin => true, side => A, device_pin_name => name_a);
							end if;
						end loop;

						-- No matching pin found.
						-- CS: this case should never occur the given pin must match one pin within
						-- the array.
						new_line(file_mkoptions_messages);
						write_message (
							file_handle => file_mkoptions_messages,
							text => message_error & " pin " & to_string(pin.device_pin_name) & " of " 
								& to_string(pin.device_name) & " invalid !",
							console => true);
						raise constraint_error;

						
					else
						-- Get pin names of a single two-pin bridge from list_of_bridges.
						name_a := element(list_of_bridges, positive(i)).pin_a.name;
						name_b := element(list_of_bridges, positive(i)).pin_b.name;

						-- if we are on side a, return name of side b
						if name_a = pin.device_pin_name then 
							return ( is_bridge_pin => true, side => B, device_pin_name => name_b);

						-- if we are on side b, return name of side a
						elsif name_b = pin.device_pin_name then
							return ( is_bridge_pin => true, side => A, device_pin_name => name_a);
							
						-- CS: this case should never occur the given pin must match either 
						-- the name of pin a or pin b.
						else 
							new_line(file_mkoptions_messages);
							write_message (
								file_handle => file_mkoptions_messages,
								text => message_error & " pin " & to_string(pin.device_pin_name) & " of " 
									& to_string(pin.device_name) & " invalid !",
								console => true);
							raise constraint_error;
						end if;
					end if;

				end if;
			end loop;
		end if;

		-- no bridge found with given pin
		return ( is_bridge_pin => false);
	end is_pin_of_bridge;
	
	type type_result_of_connector_query (is_connector_pin : boolean := false) is record
		case is_connector_pin is
			when true =>
				side 			: type_side;
				device_name 	: type_device_name.bounded_string;
				device_pin_name	: type_pin_name.bounded_string;				
			when false => null;
		end case;
	end record;
	
	function is_pin_of_connector (pin : in m1_database.type_pin) return type_result_of_connector_query is
	-- Returns true if pin is part of a connector pair.
	-- When true, the return contains the device and pin of the opposide connector of the pair.
		cp : type_connector_pair;
	begin
		if length_list_of_connector_pairs > 0 then -- do this test if there are connector pairs at all
			for i in 1..length_list_of_connector_pairs loop
				cp := element(list_of_connector_pairs, positive(i));
				if pin.device_name = cp.name_a then
					-- CS: pin must not be list of exempted_pins_a/b. see type spec of type_connector_pair
					return (
						is_connector_pin 	=> true,
						side				=> B,
						device_name			=> cp.name_b,
						device_pin_name		=> pin.device_pin_name -- CS: provide a function for other mappings
						);
				end if;
				
				if pin.device_name = cp.name_b then
					-- CS: pin must not be list of exempted_pins_a/b. see type spec of type_connector_pair					
					return (
						is_connector_pin 	=> true,
						side				=> A,
						device_name			=> cp.name_a,
						device_pin_name		=> pin.device_pin_name -- CS: provide a function for other mappings
						);
				end if;
			end loop;
		end if;
		return ( is_connector_pin => false);
	end is_pin_of_connector;

	procedure set_cluster_id (net : in out type_net) is
	-- Assigns the current cluster id to the given net.
	-- Cluster id is just a copy of the global cluster_counter.
	begin
		put(standard_output,natural'image(cluster_counter) & ascii.cr); -- CS: progress bar instead ?

		write_message (
			file_handle => file_mkoptions_messages,
			identation => 3,
			text => --"cluster " & positive'image(cluster_counter) 
				"net " & to_string(net.name),
			console => false);

		net.cluster_id := cluster_counter;			
	end set_cluster_id;	

	-- Prespecification only:
	procedure find_net( -- FN
	-- Locates the net connected to given device and pin and assigns it the current cluster id.
		device			: in type_device_name.bounded_string;
		pin				: in type_pin_name.bounded_string );
	
	procedure find_pin( -- FP
	-- Locates a device/pin of a connector-pair or bridge within the given net.
	-- If requested the pin by which we have entered the net is ignored.
		net					: in type_net; -- the net to search in
		ignore_entry_pin	: boolean; -- if entry pin is to be ignored or not
		entry_pin			: in m1_database.type_pin_base := ( -- the pin itself
									device_name => to_bounded_string(""),
									device_pin_name => to_bounded_string(""))
		) is
		length_of_pinlist	: count_type;
		pin					: m1_database.type_pin;		
		
		result_of_connector_query	: type_result_of_connector_query;
		result_of_bridge_query		: type_result_of_bridge_query;
	begin -- find_pin

		length_of_pinlist := length(net.pins);
		for p in 1..length_of_pinlist loop -- search in pinlist of given net
			pin := element(net.pins, positive(p)); -- load a pin

			-- If requested, the entry pin is ignored.
			if ignore_entry_pin and type_pin_base(pin) = entry_pin then
				null;
			else
				-- Test if pin belongs to a connector pair -- FP2
				result_of_connector_query := is_pin_of_connector(pin);
				if result_of_connector_query.is_connector_pin then

					-- Result_of_connector_query contains the device and pin
					-- of the opposide connector of the pair.

					write_message (
						file_handle => file_mkoptions_messages,
						identation => 4,
						text => "via connector " 
							& to_string(pin.device_name) 
							& " pin " & to_string(pin.device_pin_name) & " -> "
							& to_string(result_of_connector_query.device_name)
							& " pin " & to_string(result_of_connector_query.device_pin_name)
							& " transit to ",
						console => false);
								
					-- Now we transit to the other side of the connector pair:
					find_net(
						device => result_of_connector_query.device_name, -- device on the other side
						pin => result_of_connector_query.device_pin_name);  -- pin on the other side

				else

					-- Test if pin belongs to a bridge
					result_of_bridge_query := is_pin_of_bridge(pin);
					if result_of_bridge_query.is_bridge_pin then

						write_message (
							file_handle => file_mkoptions_messages,
							identation => 4,
							text => "via bridge " 
								& to_string(pin.device_name) 
								& " pin " & to_string(pin.device_pin_name) & " -> "
								& "pin " & to_string(result_of_bridge_query.device_pin_name)
								& " transit to ",
							console => false);

						find_net(
							device => pin.device_name,
							pin => result_of_bridge_query.device_pin_name);
					end if;
					
				end if;
				
			end if;  -- skip pin of entry
		end loop; -- search in pinlist of given net
	end find_pin;

	
	procedure find_net( -- FN
	-- Locates the net connected to given device and pin and assigns it the current cluster id.
	-- If no net found, the procedure ends without doing anything with the unconnected pin.
		device			: in type_device_name.bounded_string;
		pin				: in type_pin_name.bounded_string ) is

		net					: type_net;
		length_of_pinlist	: count_type;
		pin_scratch			: m1_database.type_pin;
-- 		net_found			: boolean := false; -- True once a net has been found. when unchanged
-- 												-- a warning about an unconnected pin is generated.
	begin -- find_net
		loop_netlist:
		for i in 1..length_of_netlist loop
			net := element(list_of_nets, positive(i));

			-- The net must be a non-processed cluster net. -- FN9
			-- This test just speeds up the search. It would be a waste of time
			-- to search in non-cluster nets or in nets already processed (where cluster id is greater zero).
			if net.cluster and net.cluster_id = 0 then -- FN2

				length_of_pinlist := length(net.pins);
				for p in 1..length_of_pinlist loop
					pin_scratch := element(net.pins, positive(p)); -- load a pin

					if pin_scratch.device_name = device and pin_scratch.device_pin_name = pin then -- FN4 / FN5
-- 						net_found := true;
						update_element(list_of_nets, positive(i), set_cluster_id'access);

						-- Find a connector or bridge pin in this net:
						find_pin(	 
							net => net, -- the current net we are in
							ignore_entry_pin => true, -- the current entry pin must be ignored
							entry_pin => type_pin_base(pin_scratch) -- the current entry pin itself
							);
						
						exit loop_netlist;
					end if;
				end loop;
			end if;
		end loop loop_netlist;

-- 		-- If the netlist has been searched without finding a net connected to the given pin.
-- 		-- Send a warning in logfile.
-- 		if not net_found then
-- 			new_line(file_mkoptions_messages);
-- 			write_message (
-- 				file_handle => file_mkoptions_messages,
-- 				text => message_warning
-- 					& "device " & to_string(device) 
-- 					& " pin " & to_string(pin)
-- 					& " is not connected !",
-- 				console => false);
-- 		end if;
		
	end find_net;

	
	procedure make_netlist is
		net					: type_net; -- for temporarily usage
		
		length_of_pinlist	: count_type;
		pin					: m1_database.type_pin; -- for temporarily usage		

		result_of_connector_query	: type_result_of_connector_query;
		result_of_bridge_query		: type_result_of_bridge_query;

		
-- 
-- 		procedure find_non_cluster_non_bs_nets is
-- 		begin
-- 			-- find non-cluster non-bs nets
-- 			for n in 1..net_ct
-- 			loop
-- 				if netlist(n).cluster_id = 0 then
-- 					if netlist(n).bs_driver_ct = 0 and netlist(n).bs_input_ct = 0 then
-- 						put_line("-- Section " & netlist(n).name & " class NA   -- single non-bs net");
-- 						--put_line(netlist(n).name);
-- 						put(netlist(n).content);
-- 						put_line("-- EndSection");
-- 						new_line;
-- 					end if;
-- 				end if;
-- 			end loop;
-- 		end find_non_cluster_non_bs_nets;
-- 
-- 
-- 
-- 
-- 

		procedure set_cluster_flag (net : in out type_net) is
		begin
			net.cluster := true;

			write_message (
				file_handle => file_mkoptions_messages,
				identation => 2,
				text => to_string(net.name),
				console => false);
		
		end set_cluster_flag;

			
	begin -- make_netlist

		write_message (
			file_handle => file_mkoptions_messages,
			identation => 1,
			text => "marking cluster nets ...",
			console => true);

		-- Search in list_of_nets for a device with same name as a connector or a bridge.
		-- If found, set the flag "cluster" of that net.
		for i in 1..length_of_netlist loop
			net := element(list_of_nets, positive(i)); -- load a net

			length_of_pinlist := length(net.pins);
			for p in 1..length_of_pinlist loop
				pin := element(net.pins, positive(p)); -- load a pin

				-- test if pin belongs to a connector
				if is_pin_of_connector(pin).is_connector_pin then
					update_element(list_of_nets, positive(i), set_cluster_flag'access);
					exit; 	-- Skip testing remaining pins
							-- as net is already marked as member of a cluster
				end if;

				-- test if pin belongs to a bridge
				if is_pin_of_bridge(pin).is_bridge_pin then
					update_element(list_of_nets, positive(i), set_cluster_flag'access);
					exit; 	-- Skip testing remaining pins
							-- as net is already marked as member of a cluster
				end if;

				-- mark net as primary net -- CS: no need. is primary by default
-- 				if is_field(Line,"output2",field_pt) then
-- 					netlist(scratch).primary_net := true;
-- 				end if;

			end loop;
		end loop;

		-- search cluster nets (action AC1)
		write_message (
			file_handle => file_mkoptions_messages,
			identation => 1,
			text => "examining cluster nets ...",
			console => true);

		for i in 1..length_of_netlist loop
			net := element(list_of_nets, positive(i)); -- load a net

			-- Care for cluster nets only:
			-- If net is a cluster and if it has not been assigned a cluster id yet
			if net.cluster and net.cluster_id = 0 then
				cluster_counter := cluster_counter + 1;

				write_message (
					file_handle => file_mkoptions_messages,
					identation => 2,
					text => "cluster" & positive'image(cluster_counter),
					console => false);
				
				-- assign cluster id 
				update_element(list_of_nets, positive(i), set_cluster_id'access);

				-- Find a connector or bridge pin in the net. Since there is no entry pin
				-- at this stage, there is no entry pin to be ignored.
				find_pin(net => net, ignore_entry_pin => true);
				
			end if;
		end loop;

	end make_netlist;	


	procedure make_cluster_lists is
	-- Collects all nets with the same cluster_id in a cluster.
	-- A cluster is a group of nets with the same cluster id.
	-- Appends cluster to list_of_clusters.
		net		: type_net;
		cluster	: type_cluster; -- for temporarily usage before appended to list_of_clusters
	begin -- make_cluster_lists
		
		write_message (
			file_handle => file_mkoptions_messages,
			identation => 1,
			text => "making cluster lists ...",
			console => false);

		-- loop in clusters
		for c_id in 1..cluster_counter loop

			write_message (
				file_handle => file_mkoptions_messages,
				identation => 2,
				text => "cluster" & natural'image(c_id) & " with nets:",
				console => false);

			-- loop in netlist
			for i in 1..length_of_netlist loop

				-- Load a net. test if it is part of a cluster and if cluster id matches c_id.
				-- On match, add the net to the list of nets of cluster.
				-- If any net of the cluster is scan capable, mark the whole cluster as scan capable.
				net := element(list_of_nets, positive(i));
				if net.cluster and net.cluster_id = c_id then

					write_message (
						file_handle => file_mkoptions_messages,
						identation => 3,
						text => to_string(net.name),
						console => false);

					append(cluster.nets, net);

					if net.bs_capable then
						cluster.bs_capable := true;
					end if;
					
				end if;	-- if cluster id matches
				
			end loop; -- loop in netlist

			if cluster.bs_capable then
				write_message (
					file_handle => file_mkoptions_messages,
					identation => 4,
					text => "... is scan capable",
					console => false);
			end if;
			
			-- All nets of current cluster found.
			append(list_of_clusters, cluster);
			delete(cluster.nets, 1, length(cluster.nets)); -- purge netlist of temporarily cluster
			
		end loop; -- loop in clusters

	end make_cluster_lists;
	


	procedure write_net_content( net : in type_net) is
	-- Writes the pins of the given net in options file.
		procedure write_pin ( pin : in m1_database.type_pin) is
-- 			bic : type_bscan_ic;
			use type_device_value;
			use type_package_name;
			use type_list_of_bics;
		begin
			-- write the basic pin info as comment like "-- R101 ? 2k7 0207/10 2"
			put(2 * row_separator_0 & comment_mark & to_string(pin.device_name) & row_separator_0 &
				type_device_class'image(device_class_default)(2) & row_separator_0 &
				to_string(pin.device_value) & row_separator_0 &
				to_string(pin.device_package) & row_separator_0 &
				to_string(pin.device_pin_name) & row_separator_0
			);

			-- CS:
			-- If pin belongs to a bic, additionally write
			-- port and cell info like "SOIC24 2 Y1(1) | 7 BC_1 OUTPUT3 X 17 1 Z"
-- 			for i in 1..type_list_of_bics.length(list_of_bics) loop
-- 				bic := element(list_of_bics, positive(i));
-- 				if bic.name = pin.device_name then
-- 					put(get_cell_info(
-- 						bic => positive(i),
-- 						pin => pin.device_pin_name));
-- 				end if;
-- 			end loop;

			new_line;
		end write_pin;
		
	begin -- write_net_content
		-- loop in pinlist of given net and write one pin after another
		for i in 1..length(net.pins) loop
			write_pin(element(net.pins, positive(i)));
		end loop;
	end write_net_content;
	
	procedure sort_bs_clusters is
		cluster : type_cluster;
		net 	: type_net;		
		pin		: m1_database.type_pin;

		primary_net_found	: boolean := false;
		name_of_primary_net	: type_net_name.bounded_string;
	begin
		write_message (
			file_handle => file_mkoptions_messages,
			identation => 1,
			text => "sorting scan capable clusters ...",
			console => false);
		
		for i in 1..length(list_of_clusters) loop

			write_message (
				file_handle => file_mkoptions_messages,
				identation => 2,
				text => "elaborating primary net ...",
				console => false);
			
			cluster := element(list_of_clusters, positive(i)); -- load a cluster
			primary_net_found := false; -- initally we assume there has no primary net been found yet
			
			if cluster.bs_capable then

				write_message (
					file_handle => file_mkoptions_messages,
					identation => 3,
					text => "cluster" & count_type'image(i),
					console => false);
				
				-- Search for a primary net with an output2 driver
				write_message (
					file_handle => file_mkoptions_messages,
					identation => 4,
					text => "searching driver pin WITHOUT disable specification ...",
					console => false);
				
				loop_nets_output2:
				for i in 1..length(cluster.nets) loop
					net := element(cluster.nets, positive(i));

					write_message (
						file_handle => file_mkoptions_messages,
						identation => 5,
						text => "in net " & to_string(net.name) & " ...",
						console => false);
					
					if net.bs_output_pin_count > 0 then
						for p in 1..length(net.pins) loop
							pin := element(net.pins, positive(p));
							if pin.is_bscan_capable then

								-- If pin is an output2 driver
								if 	pin.cell_info.output_cell_id /= cell_not_available and -- has output cell
									pin.cell_info.control_cell_id = cell_not_available then -- has no control cell
									-- we have an output2 pin

									write_message (
										file_handle => file_mkoptions_messages,
										identation => 6,
										text => "pin " & to_string(pin.device_name) & row_separator_0 & to_string(pin.device_pin_name),
										console => false);

									-- Save name of primary net. Required for sorting secondary nets.
									name_of_primary_net := net.name;
									
		-- 							if netlist(n).processed = false then
-- 									if netlist(n).primary_net then
-- 										netlist(n).processed := true;
									put_line(section_mark.section & row_separator_0 & to_string(net.name) & row_separator_0 
										& netlist_keyword_header_class & row_separator_0
										& type_net_class'image(net_class_default) -- CS: automatic class setting could be invoked here
										& comment_mark & keyword_allowed & row_separator_0
										& type_net_class'image(DH) & row_separator_0
										& type_net_class'image(DL) & row_separator_0
										& type_net_class'image(NR));

-- 										csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
									write_net_content(net);
									primary_net_found := true;
									exit loop_nets_output2; -- CS: do not exit if more output2 pins are to be found
								end if;
							end if;
						end loop;
					end if;
				end loop loop_nets_output2;

				-- Search for a primary net with a driver with disable specification
				if not primary_net_found then

					write_message (
						file_handle => file_mkoptions_messages,
						identation => 4,
						text => "... none found. Searching driver pin WITH disable specification ...",
						console => false);

					loop_nets_disable_spec:
					for i in 1..length(cluster.nets) loop
						net := element(cluster.nets, positive(i));

						write_message (
							file_handle => file_mkoptions_messages,
							identation => 5,
							text => "in net " & to_string(net.name) & " ...",
							console => false);
						
						if net.bs_output_pin_count > 0 or net.bs_bidir_pin_count > 0 then
							for p in 1..length(net.pins) loop
								pin := element(net.pins, positive(p));
								if pin.is_bscan_capable then

									-- If pin is a driver with disable spec:
									if 	pin.cell_info.output_cell_id /= cell_not_available and -- has output cell
										pin.cell_info.control_cell_id /= cell_not_available then -- has control cell
										-- we have an output pin with disable spec

										write_message (
											file_handle => file_mkoptions_messages,
											identation => 6,
											text => "pin " & to_string(pin.device_name) & row_separator_0 & to_string(pin.device_pin_name),
											console => false);

										-- Save name of primary net. Required for sorting secondary nets.
										name_of_primary_net := net.name;
										
			-- 							if netlist(n).processed = false then
	-- 									if netlist(n).primary_net then
	-- 										netlist(n).processed := true;
										put_line(section_mark.section & row_separator_0 & to_string(net.name) & row_separator_0 
											& netlist_keyword_header_class & row_separator_0
											& type_net_class'image(net_class_default) -- CS: automatic class setting could be invoked here
											);

-- 										csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
										write_net_content(net);
										primary_net_found := true;
										exit loop_nets_disable_spec;
									end if;
								end if;
							end loop;
						end if;
					end loop loop_nets_disable_spec;

				end if;

				-- As a last resort, search for a primary net with receiver pins:
				if not primary_net_found then

					write_message (
						file_handle => file_mkoptions_messages,
						identation => 4,
						text => "... none found. Searching receiver pin ...",
						console => false);

					loop_nets_receiver:
					for i in 1..length(cluster.nets) loop
						net := element(cluster.nets, positive(i));

						write_message (
							file_handle => file_mkoptions_messages,
							identation => 5,
							text => "in net " & to_string(net.name) & " ...",
							console => false);
						
						if net.bs_input_pin_count > 0 then
							for p in 1..length(net.pins) loop
								pin := element(net.pins, positive(p));
								if pin.is_bscan_capable then

									-- If pin is a driver with disable spec:
									if 	pin.cell_info.input_cell_id /= cell_not_available then -- has input cell
										-- we have receiver pin

										write_message (
											file_handle => file_mkoptions_messages,
											identation => 6,
											text => "pin " & to_string(pin.device_name) & row_separator_0 & to_string(pin.device_pin_name),
											console => false);

										-- Save name of primary net. Required for sorting secondary nets.
										name_of_primary_net := net.name;

			-- 							if netlist(n).processed = false then
	-- 									if netlist(n).primary_net then
	-- 										netlist(n).processed := true;
										put_line(section_mark.section & row_separator_0 & to_string(net.name) & row_separator_0 
											& netlist_keyword_header_class & row_separator_0
											& type_net_class'image(net_class_default) -- CS: automatic class setting could be invoked here
											& comment_mark & keyword_allowed & row_separator_0
											& type_net_class'image(EH) & row_separator_0
											& type_net_class'image(EL));

-- 										csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
										write_net_content(net);
										primary_net_found := true;
										exit loop_nets_receiver;
									end if;
								end if;
							end loop;
						end if;
					end loop loop_nets_receiver;

				end if;
				
				-- No suitable primary net found. CS: This should never happen. 
				if not primary_net_found then
					write_message (
						file_handle => file_mkoptions_messages,
						text => message_error & "No suitable primary net found in cluster !",
						console => true);
					raise constraint_error;
				end if;
				

				-- If the cluster has more than one net, write remaining nets a secondary nets:
				if length(cluster.nets) > 1 then

					write_message (
						file_handle => file_mkoptions_messages,
						identation => 2,
						text => "writing secondary nets ...",
						console => false);
					
					-- write header of section secondary nets
					put_line(row_separator_0 & section_mark.subsection 
							& row_separator_0 & netlist_keyword_header_secondary_nets);

					for i in 1..length(cluster.nets) loop
						net := element(cluster.nets, positive(i));
						if net.name /= name_of_primary_net then

							write_message (
								file_handle => file_mkoptions_messages,
								identation => 3,
								text => to_string(net.name),
								console => false);
							
							put_line(2*row_separator_0 & options_keyword_net & row_separator_0 & to_string(net.name));
							-- csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
							write_net_content(net);
							-- csv.put_lf(routing_file); -- in v028
						end if;
					end loop;

					-- write footer of section seconary nets
					put_line(row_separator_0 & section_mark.endsubsection);
				end if;
				
				-- write footer of primary net
				put_line(section_mark.endsection);
				new_line;

			end if; -- if cluster is bs_capable
				
		end loop;
	end sort_bs_clusters;

	procedure write_single_bs_nets is
		net 	: type_net;
		text_single_bs_net : constant string (1..13) := "single bs-net";
	begin
		write_message (
			file_handle => file_mkoptions_messages,
			identation => 1,
			text => "writing single bs nets ...",
			console => false);
		
		for i in 1..length(list_of_nets) loop
			net := element(list_of_nets, positive(i));
			if not net.cluster and net.bs_capable then

				write_message (
					file_handle => file_mkoptions_messages,
					identation => 2,
					text => to_string(net.name),
					console => false);

				put(section_mark.section & row_separator_0 & to_string(net.name) & row_separator_0 
					& netlist_keyword_header_class & row_separator_0
					& type_net_class'image(net_class_default) -- CS: automatic class setting could be invoked here
					& row_separator_0 & comment_mark & text_single_bs_net);

				if net.bs_bidir_pin_count = 0 then
					if net.bs_output_pin_count = 0 then
						put(row_separator_0 & keyword_allowed & row_separator_0 
							& netlist_keyword_header_class & row_separator_0
							& type_net_class'image(EH) & row_separator_0 
							& type_net_class'image(EL));
					end if;

					if net.bs_input_pin_count = 0 then
						put(row_separator_0 & keyword_allowed & row_separator_0 
							& netlist_keyword_header_class & row_separator_0
							& type_net_class'image(DH) & row_separator_0 
							& type_net_class'image(DL) & row_separator_0
							& type_net_class'image(NR));
					end if;
				end if;
				
				new_line;
				write_net_content(net);
				
				-- write primary net footer
				put_line(section_mark.endsection);
				new_line;

			end if;
		end loop;

	end write_single_bs_nets;


	procedure write_non_bs_clusters is
		cluster	: type_cluster;
		net 	: type_net;
	begin
		write_message (
			file_handle => file_mkoptions_messages,
			identation => 1,
			text => "writing non-bs clusters ...",
			console => false);
		
		for i in 1..length(list_of_clusters) loop
			
			cluster := element(list_of_clusters, positive(i)); -- load a cluster
			if not cluster.bs_capable then
				for i in 1..length(cluster.nets) loop
					net := element(cluster.nets, positive(i));
					
-- 									if netlist(n).net_id = natural'value(get_field(cluster_list(c).members,i)) then -- member net found
-- 										--if netlist(n).bs_driver_ct > 0 then
-- 										--netlist(n).ordered := true;
-- 										if i = 1 then
-- 											put_line("-- Section " & netlist(n).name & " class NA  -- non-bs cluster");
-- 											csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
-- 											put(netlist(n).content);
-- 											put_line(" -- SubSection secondary_nets");
-- 										else
-- 											put_line("  -- Net " & netlist(n).name);
-- 											csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
-- 											put(netlist(n).content);
-- 										end if;
-- 									end if;
-- 								end loop;
-- 							end loop;
-- 							put_line("--  EndSubSection");
-- 							put_line("-- EndSection");
-- 							new_line(2);
-- 							csv.put_lf(routing_file); -- in v028
-- 							cluster_list(c).ordered := true;
				end loop;
			end if;
		end loop;
	end write_non_bs_clusters;
	
	
	procedure write_netlist is
		
	begin
		set_output(file_options);
		put_line("-- NETLIST -----------------------------------------------------------");
		
		-- if there are clusters write them first
		if cluster_counter > 0 then

			make_cluster_lists;
			sort_bs_clusters;

-- 				find_non_cluster_non_bs_nets;
					
			
-- 				sort_clusters;
-- 			else
-- 				find_non_cluster_bs_nets;
-- 				find_non_cluster_non_bs_nets;
-- 			end if;
-- 
-- 			return true;

		end if; -- if cluster counter > 0

		write_single_bs_nets;

		if cluster_counter > 0 then
			write_non_bs_clusters;
		end if;
		
	end write_netlist;
	
-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := mkoptions;
--	degree_of_database_integrity_check := light; -- CS: for testing only	
	
	new_line;
	put_line(to_upper(name_module_mkoptions) & " version " & version);
	put_line("===============================");
	prog_position	:= 10;
 	name_file_database := to_bounded_string(argument(1));
 	put_line(text_identifier_database & "       : " & to_string(name_file_database));

	prog_position	:= 20;
	name_file_options:= to_bounded_string(argument(2));
	put_line ("options file   : " & to_string(name_file_options));
          
	prog_position	:= 25;
	read_uut_database;
	length_of_netlist := length(list_of_nets); -- CS: should be in read_uut_database
	
	-- recreate an empty tmp directory
	prog_position	:= 30;
	create_temp_directory;
-- 	prog_position	:= 40;
-- 	create_bak_directory;

	-- create message/log file
	prog_position	:= 40;
 	write_log_header(version);

	-- write name of database in logfile
	put_line(file_mkoptions_messages, text_identifier_database 
		 & row_separator_0
		 & to_string(name_file_database));

	write_message (
		file_handle => file_mkoptions_messages,
-- 		identation => 3,
		text => "number of nets in " & text_identifier_database & ":" & count_type'image(length_of_netlist),
		console => true);
	
	-- write name of options file in logfile
	put_line(file_mkoptions_messages, "options file"
		 & row_separator_0
		 & to_string(name_file_options));
	
	
	-- if opt file already exists, backup old opt file
-- 	if exists(universal_string_type.to_string(name_file_options)) then
-- 		put_line("WARNING : Target options file '" & universal_string_type.to_string(name_file_options) & "' already exists.");
-- 		put_line("          If you choose to overwrite it, a backup will be created in directory 'bak'."); new_line;
-- 		put     ("          Do you really want to overwrite existing options file '" & universal_string_type.to_string(name_file_options) & "' ? (y/n) "); get(key);
-- 		if key = "y" then       
-- 			-- backup old options file
-- 			copy_file(universal_string_type.to_string(name_file_options),"bak/" & universal_string_type.to_string(name_file_options));		
-- 		else		
--             -- user abort
-- 			prog_position := 100; 
-- 			raise constraint_error;
-- 		end if;
-- 	end if;

	-- create options file
	prog_position	:= 50;
	write_message (
		file_handle => file_mkoptions_messages,
-- 		identation => 1,
		text => "creating options file " & to_string(name_file_options) & "...",
		console => false);
	create( file => file_options, mode => out_file, name => type_name_file_options.to_string(name_file_options));

	-- create routing file
	prog_position	:= 60;
    name_file_routing := to_bounded_string (compose ( 
						name => base_name(type_name_database.to_string(name_file_database)),
						extension => file_extension_routing));
	write_message (
		file_handle => file_mkoptions_messages,
-- 		identation => 1,
		text => "creating routing table " & to_string(name_file_routing) & "...",
		console => false);
	create( file => file_routing, mode => out_file, name => to_string(name_file_routing));

	prog_position	:= 70;
	write_routing_file_header;

	prog_position	:= 80;
	write_options_file_header;
	

	-- check if mkoptions.conf exists
	prog_position	:= 90;	
	if not exists (name_file_mkoptions_conf) then

		write_message (
			file_handle => file_mkoptions_messages,
	-- 		identation => 1,
			text => message_error & "No configuration file '" & name_file_mkoptions_conf & "' found !",
			console => true);
		raise constraint_error;
	end if;
	
	read_mkoptions_configuration;
-- CS:	write_statistics;

	make_netlist;

	write_netlist;

	close(file_options);

	csv.put_field(file_routing,"-- END OF TABLE");
	close(file_routing);

	write_log_footer;

	exception when event: others =>
		set_exit_status(failure);
		set_output(standard_output);

		write_message (
			file_handle => file_mkoptions_messages,
			text => message_error & " at program position " & natural'image(prog_position),
			console => true);
	
		if is_open(file_options) then
			close(file_options);
		end if;

		case prog_position is
			when 10 =>
				write_message (
					file_handle => file_mkoptions_messages,
					text => message_error & text_identifier_database & " file missing or insufficient access rights !",
					console => true);

				write_message (
					file_handle => file_mkoptions_messages,
					text => "       Provide " & text_identifier_database & " name as argument. Example: mkoptions my_uut.udb",
					console => true);

			when 20 =>
				write_message (
					file_handle => file_mkoptions_messages,
					text => "Options file missing or insufficient access rights !",
					console => true);

				write_message (
					file_handle => file_mkoptions_messages,
					text => "       Provide options file as argument. Example: chkpsn my_uut.udb my_options.opt",
					console => true);

			when others =>
				write_message (
					file_handle => file_mkoptions_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_mkoptions_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;

			
end mkoptions;
