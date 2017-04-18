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
with ada.characters.handling; 	use ada.characters.handling;
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


-- 	type cluster is
-- 		record
-- 			ordered			: boolean := false;
-- 			bs				: boolean := false; -- bs capable flag
-- 			size			: natural := 0;
-- 			members			: unbounded_string;
-- 		end record;
-- 	type cluster_list_type is array (natural range <>) of cluster;


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
		processed		: boolean := false;
		connected		: boolean := false;
	end record;
	
	type type_bridge_preliminary is tagged record
		name			: type_device_name.bounded_string;
		wildcards		: boolean := false; -- true if name contains asterisks (*) or quesition marks (?)
		pin_a			: type_pin;
		pin_b			: type_pin;
	end record;

	type type_bridge_within_array is record -- like "1-8 2-7"
		pin_a			: type_pin;
		pin_b			: type_pin;
	end record;
	package type_list_of_bridges_within_array is new vectors 
		(index_type => positive, element_type => type_bridge_within_array);
	list_of_bridges_within_array_preliminary : type_list_of_bridges_within_array.vector;
	use type_list_of_bridges_within_array;
	
	type type_bridge ( is_array : boolean) is new type_bridge_preliminary with record
		case is_array is
			when true => list_of_bridges : type_list_of_bridges_within_array.vector;
			when false => null;
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
	end record;
	package type_list_of_connector_pairs is new vectors ( index_type => positive, element_type => type_connector_pair);
	use type_list_of_connector_pairs;
	list_of_connector_pairs : type_list_of_connector_pairs.vector;
	length_list_of_connector_pairs : count_type;

	function has_wildcards (device : in type_device_name.bounded_string) return boolean is
		asterisks_count 		: natural := type_device_name.count(device,"*");
		question_marks_count	: natural := type_device_name.count(device,"?");
		wildcards_found			: boolean := false;
	begin
		if asterisks_count > 0 then
			wildcards_found := true;
		end if;

		if question_marks_count > 0 then
			wildcards_found := true;
		end if;
		
		return wildcards_found;
	end has_wildcards;

	function read_bridges_of_array (
		line 		: in string; -- contains something like "RN303 array 1-2 3-4 5-6 7-8"
		field_count : in positive;
		line_counter: in positive) 
		return type_list_of_bridges_within_array.vector is
		list_of_bridges : type_list_of_bridges_within_array.vector;

		use type_pins_of_bridge; 
		field : type_pins_of_bridge.bounded_string; -- something like "1-8"

		bridge 		: type_bridge_within_array;
		separator	: constant string (1..1) := "-";
 		pos_sep 	: positive; -- position of separator "-" 
	begin -- read_bridges_of_array
		for i in 3..field_count loop -- we start reading in field 3 
			field := to_bounded_string(get_field_from_line(line,i));
			if type_pins_of_bridge.count(field,separator) = 1 then -- there must be a single separator
				pos_sep 			:= type_pins_of_bridge.index(field,separator); -- get position of separator

				-- get pin names left and right of separator
				bridge.pin_a.name	:= to_bounded_string(type_pins_of_bridge.slice(field, 1, pos_sep-1));
				bridge.pin_b.name	:= to_bounded_string(type_pins_of_bridge.slice(field, pos_sep+1, length(field)));

				write_message (
					file_handle => file_mkoptions_messages,
					identation => 3,
					text => "pins: " & to_string(bridge.pin_a.name) & separator & to_string(bridge.pin_b.name),
					console => false);

				-- CS: check multiple occurences of pin names and bridges in mkoptions.conf
				-- CS: check bridge exists in netlist.
				-- CS: check pins exists only once in netlist.
				
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

	function device_occurences_in_netlist( device : in type_device_name.bounded_string) return natural is
	-- Returns the number of occurences of the given device within the database netlist.
		net					: type_net;
		pin					: m1_database.type_pin;
		length_of_pinlist	: count_type; -- CS: we assume there are no zero-pin nets
		occurences			: natural := 0;
	begin
		for i in 1..length(list_of_nets) loop -- loop in netlist
			net := element(list_of_nets, positive(i)); -- load a net
			length_of_pinlist := length(net.pins); -- load number of pins in the net
			for i in 1..length_of_pinlist loop -- loop in pinlist
				pin := element(net.pins, positive(i)); -- load a pin
				if pin.device_name = device then -- on device name match count matches
					occurences := occurences + 1;
				end if;
			end loop;
		end loop;
		return occurences;
	end device_occurences_in_netlist;
	
	procedure read_mkoptions_configuration is
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
								text => strip_quotes(type_side'image(A)) & row_separator_0 
									& to_string(conpair_preliminary.name_a) 
									& row_separator_0 & strip_quotes(type_side'image(B)) 
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
							end if;
							if device_occurences_in_netlist(conpair_preliminary.name_b) = 0 then
								new_line(file_mkoptions_messages);
								write_message (
									file_handle => file_mkoptions_messages,
									text => message_error & "connector device " & to_string(conpair_preliminary.name_b)
										& " does not exist in " & text_identifier_database & " !",
										console => true);
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
					if get_field_from_line(to_string(line),1) = section_mark.endsection then -- we are leaving section bridges
						section_bridges_entered := false; 

						case bridge_is_array is
							when false =>
								append(list_of_bridges, (bridge_preliminary with is_array => false));
							when true =>
								-- CS: test if bridge occurs in netlist.
								-- CS: write warning if pin does not exist in netlist
								-- CS: error if pin occurs more than once
								append(list_of_bridges, (bridge_preliminary with 
															is_array => true, 
															list_of_bridges => list_of_bridges_within_array_preliminary));
						end case;
						
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
						if bridge_preliminary.wildcards then
							write_message (
								file_handle => file_mkoptions_messages,
								identation => 1,
								text => "has wildcards",
								lf => false,
								console => false);

							-- CS: warning if bridge name has no matches in netlist
						else
							-- No wildcards used. Make sure the bridge device occurs netlist:
							if device_occurences_in_netlist(bridge_preliminary.name) = 0 then
								new_line(file_mkoptions_messages);
								write_message (
									file_handle => file_mkoptions_messages,
									text => message_warning & "bridge device " & to_string(bridge_preliminary.name)
										& " does not exist in " & text_identifier_database & " !",
										console => false);
							end if;
-- 								when 1 =>
-- 									new_line(file_mkoptions_messages);
-- 									write_message (
-- 										file_handle => file_mkoptions_messages,
-- 										text => message_warning & "bridge device " & to_string(bridge_preliminary.name)
-- 											& " has only one connected pin !",
-- 										console => false);
-- 								when 0 =>
-- 									new_line(file_mkoptions_messages);
-- 									write_message (
-- 										file_handle => file_mkoptions_messages,
-- 										text => message_warning & "bridge device " & to_string(bridge_preliminary.name)
-- 											& " does not exist in " & text_identifier_database & " !",
-- 										console => false);
-- 
-- 							end case;
						end if;
						
						-- Field #2 may indicate that this is an array.
						if field_count > 1 then
							if get_field_from_line(to_string(line),2) = options_keyword_array then
								bridge_is_array := true;

								write_message (
									file_handle => file_mkoptions_messages,
									identation => 1,
									text => "is array",
									console => false);

								-- build a preliminary list of bridges from fields after "array"
								if field_count > 2 then
									list_of_bridges_within_array_preliminary := read_bridges_of_array(
										line 			=> to_string(line),
										field_count 	=> field_count,
										line_counter	=> line_counter);
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
								-- put a final linebreak at end of line in logfile
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

							-- CS: get pin names 
							
-- 							-- Purge preliminary list of bridges within array for next spin.							
-- 							if length(list_of_bridges_within_array_preliminary) > 0 then
-- 								delete(list_of_bridges_within_array_preliminary,1,length(list_of_bridges_within_array_preliminary));
-- 							end if;

						end if;

						-- put a final linebreak at end of line in logfile
						new_line (file_mkoptions_messages);

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
	result_of_bridge_query : type_result_of_bridge_query;

	function is_pin_of_bridge (pin : in m1_database.type_pin) return type_result_of_bridge_query is
	-- Returns true if pin is part of a bridge.
	-- When true, the return contains the pin of the opposide pin of the bridge.
		bp : type_bridge_preliminary;
		result : type_result_of_bridge_query;
	begin
		if length_list_of_bridges > 0 then -- do this test if there are bridges at all
			for i in 1..length_list_of_bridges loop
				bp := type_bridge_preliminary(element(list_of_bridges, positive(i)));

				-- If device name matches we know the given pin is part of a bridge.
				-- In addition we also need the pin name of the other side of the bridge.
				-- This could be a pin of an array or a pin of something simple like a single 2-pin resistor.
				if pin.device_name = bp.name then 

					if element(list_of_bridges, positive(i)).is_array then
						null;
						-- get pin name from array of bridges
					else
						null;
						-- get pin name from a single two-pin device
					end if;

				end if;
			end loop;
		end if;
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
	result_of_connector_query : type_result_of_connector_query;
	
	function is_pin_of_connector (pin : in m1_database.type_pin) return type_result_of_connector_query is
	-- Returns true if pin is part of a connector pair.
	-- When true, the return contains the device and pin of the opposide connector of the pair.
		cp : type_connector_pair;
	begin
		if length_list_of_connector_pairs > 0 then -- do this test if there are connector pairs at all
			for i in 1..length_list_of_connector_pairs loop
				cp := element(list_of_connector_pairs, positive(i));
				if pin.device_name = cp.name_a then
					return (
						is_connector_pin 	=> true,
						side				=> B,
						device_name			=> cp.name_b,
						device_pin_name		=> pin.device_pin_name -- CS: provide a function for other mappings
						);
				end if;
				
				if pin.device_name = cp.name_b then
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

	function opposide_of( side : in type_side ) return type_side is
	begin
		case side is
			when A => return B;
			when B => return A;
		end case;
	end opposide_of;
	
	procedure mark_connector_pin_as_processed ( 
		device	: in type_device_name.bounded_string;
		pin 	: in type_pin_name.bounded_string;
		side	: in type_side
		) is
		cp : type_connector_pair;

		procedure update_processed_pins_a ( connector_pair : in out type_connector_pair) is
		begin
			connector_pair.processed_pins_a := cp.processed_pins_a;

			write_message (
				file_handle => file_mkoptions_messages,
				identation => 3,
				text => "processed device " & to_string(device) & row_separator_0
					& "pin " & to_string(pin),
				console => false);

		end update_processed_pins_a;

		procedure update_processed_pins_b ( connector_pair : in out type_connector_pair) is
		begin
			connector_pair.processed_pins_b := cp.processed_pins_b;

			write_message (
				file_handle => file_mkoptions_messages,
				identation => 3,
				text => "processed device " & to_string(device) & row_separator_0
					& "pin " & to_string(pin),
				console => false);
			
		end update_processed_pins_b;
		
	begin
		for i in 1..length_list_of_connector_pairs loop
			cp := element(list_of_connector_pairs, positive(i)); -- load a connector pair
			case side is
				when A =>
					if cp.name_a = device then -- connector A found 
						append(cp.processed_pins_a, pin);
						update_element(list_of_connector_pairs, positive(i), update_processed_pins_a'access);
					end if;
				when B =>
					if cp.name_a = device then -- connector B found 
						append(cp.processed_pins_b, pin);
						update_element(list_of_connector_pairs, positive(i), update_processed_pins_b'access);
					end if;
			end case;
		end loop;
	end mark_connector_pin_as_processed;
	
	function is_pin_of_bridge (pin : in m1_database.type_pin) return boolean is
	-- Returns true if pin is part of a bridge.
		name_of_bridge 			: type_device_name.bounded_string;
		bridge_has_wildcards 	: boolean := false;
		pin_of_bridge 			: boolean := false;
	begin
		if length_list_of_bridges > 0 then -- do this test if there are bridges at all
			for i in 1..length_list_of_bridges loop
				name_of_bridge			:= element(list_of_bridges, positive(i)).name; -- load name of bridge
				bridge_has_wildcards	:= element(list_of_bridges, positive(i)).wildcards; -- load wildcards flag of bridge
				
				-- check for exact match of pin name and bridge name
				if pin.device_name = name_of_bridge then
					pin_of_bridge := true;
					exit;
				end if;

				-- check for match with wildcard (R99* or R4?0)
				if bridge_has_wildcards then
					null;
					-- CS
				end if;

			end loop;
			-- no bridge with suitable name found
		end if;
		
		return pin_of_bridge;
	end is_pin_of_bridge;

	procedure set_cluster_id (net : in out type_net) is
	begin
		put(standard_output,natural'image(cluster_counter) & ascii.cr); -- CS: progress bar instead ?

		write_message (
			file_handle => file_mkoptions_messages,
			identation => 2,
			text => "cluster " & positive'image(cluster_counter) 
				& " net " & to_string(net.name),
			console => false);

		net.cluster_id := cluster_counter;			
	end set_cluster_id;	

	function pin_processed (pin : in m1_database.type_pin) return boolean is
		processed			: boolean := false;
		cp 					: type_connector_pair;
		pin_scratch			: type_pin_name.bounded_string;
		length_of_pinlist	: count_type;		
	begin
		if length_list_of_connector_pairs > 0 then -- do this test if there are connector pairs at all
			loop_connector_pairs:
			for i in 1..length_list_of_connector_pairs loop
				cp := element(list_of_connector_pairs, positive(i)); -- load a connector pair
				if pin.device_name = cp.name_a then -- if pin belongs to sida A connector

					-- load number of processed pins of side A connector 
					length_of_pinlist := length(cp.processed_pins_a); 
					
					-- Search for given pin among processed pins of side A connector.
					-- If found exit loop and return true.
					for p in 1..length_of_pinlist loop
						pin_scratch := element(cp.processed_pins_a, positive(p));
						if pin_scratch = pin.device_pin_name then
							processed := true;
							exit loop_connector_pairs;
						end if;
					end loop;
				end if;
			end loop loop_connector_pairs;
		end if;
		return processed;
	end pin_processed;


	-- Prespecification only:
	procedure find_net_by_device_and_pin( -- FN
	-- Locates the net connected to device and pin.
		net_of_origin	: in type_net_name.bounded_string; -- CS: probably not required, see below
		device			: in type_device_name.bounded_string;
		pin				: in type_pin_name.bounded_string );

	
	procedure find_device_by_net( -- FP
		net_name : in type_net_name.bounded_string) is
		part_found			: boolean := false;
		length_of_pinlist	: count_type;
		pin					: m1_database.type_pin;		
		net 				: type_net;
		result				: type_result_of_connector_query;
	begin
		--put_line("FP");
		--put_line(standard_output,"FP : " & natural'image(net_id_given));

-- 			for net_pt in 1..net_ct	-- search net by given net_id -- FP1
-- 			loop
		loop_netlist:
		for i in 1..length_of_netlist loop
			net := element(list_of_nets, positive(i));

-- 				if netlist(net_pt).net_id = net_id_given then -- if net found
			if net.name = net_name then
-- 				for p in 1..netlist(net_pt).part_ct	-- find conpair or bridge in net
-- 				loop
				length_of_pinlist := length(net.pins);
					for p in 1..length_of_pinlist loop
						pin := element(net.pins, positive(p)); -- load a pin

						-- check if pin belongs to a connector pair -- FP2
						-- if con_pair_list(c).name_a = part or con_pair_list(c).name_b = part then -- part A or B found
						result := is_pin_of_connector(pin);
						if result.is_connector_pin then
							part_found := true; -- FP10
 							-- if pin_processed(con_pair_list(c).pins_processed,pin) = false then -- if pin not processed yet -- FP4
							if not pin_processed(pin) then

								--con_pair_list(c).pins_processed := con_pair_list(c).pins_processed & " " & pin; -- mark pin as processed
								mark_connector_pin_as_processed(
									device => pin.device_name,
									pin => pin.device_pin_name,
									side => opposide_of(result.side)
									);

-- 									if con_pair_list(c).name_a = part then -- if part A found
-- 										--put_line(standard_output,"     con  " & part & " pin " & pin); 
-- 										if find_net_by_part_and_pin
-- 											(
-- 											net_id_origin => netlist(net_pt).net_id,
-- 											part_given => con_pair_list(c).name_b, -- part A has been found, so part B must be passed
-- 											pin_given => pin
-- 											)
-- 										then null;
-- 										end if;
-- 										exit; -- test
-- 									end if; -- if part A found

								-- Result provides the device and pin name of the
								-- connector on the other side of the pair.
								-- Now we transit to the other side of the connector pair:
								find_net_by_device_and_pin(
									net_of_origin => net.name, -- CS: probably not required
									device => result_of_connector_query.device_name,
									pin => result_of_connector_query.device_pin_name);
-- 
-- 									if con_pair_list(c).name_b = part then -- if part B found
-- 										--put_line(standard_output,"     con  " & part & " pin " & pin);
-- 										if find_net_by_part_and_pin
-- 											(
-- 											net_id_origin => netlist(net_pt).net_id,
-- 											part_given => con_pair_list(c).name_a, -- part B has been found, so part A must be passed
-- 											pin_given => pin
-- 											)
-- 										then null;
-- 										end if;
-- 										exit; -- test
-- 									end if; -- if part B found
							end if; -- if pin not processed yet
						end if;


-- 						-- check if part is a bridge
-- 						for b in 1..bridge_ct
-- 						loop
-- 							if bridge_list(b).name = part then -- PF3 -- bridge found
-- 								part_found := true; -- FP10
-- 								if bridge_list(b).pin_a = pin then -- pin A found
-- 									-- this pin is connected with a net, so we mark this pin as "connected" now
-- 									bridge_list(b).pin_a_connected := true; -- ins v027
-- 									if bridge_list(b).pin_a_processed = false then -- if pin A not processed yet -- FP5
-- 										bridge_list(b).pin_b_processed := true; -- mark counter pin B as processed -- FP6
-- 										--put_line(part & " counter pin " & bridge_list(b).pin_b);  -- CS: early exit ?
-- 										if find_net_by_part_and_pin
-- 											(
-- 											net_id_origin => netlist(net_pt).net_id,
-- 											part_given => part,
-- 											pin_given => bridge_list(b).pin_b -- pin A has been found, so pin B must be passed
-- 											)
-- 											then null;
-- 										end if;
-- 									end if;
-- 
-- 								elsif bridge_list(b).pin_b = pin then -- pin B found
-- 									-- this pin is connected with a net, so we mark this pin as "connected" now
-- 									bridge_list(b).pin_b_connected := true; -- ins v027
-- 									if bridge_list(b).pin_b_processed = false then -- if pin B not processed yet -- FP5
-- 										bridge_list(b).pin_a_processed := true;	--  mark counter pin A as processed -- FP6
-- 										--put_line(part & " counter pin " & bridge_list(b).pin_a);  -- CS: early exit ?
-- 										if find_net_by_part_and_pin
-- 											(
-- 											net_id_origin => netlist(net_pt).net_id,
-- 											part_given => part,
-- 											pin_given => bridge_list(b).pin_a -- pin B has been found, so pin A must be passed
-- 											)
-- 											then null;
-- 										end if;
-- 									end if; -- if pin B not processed yet
-- 								else null; -- CS: should we do something here ? (bridge found but not pin found)
-- 								-- is this case a resistor of a resistor array has been found, but the pin does not match
-- 								-- so another looping is required to find the pin -- ins v027
-- 								end if;
-- 							end if; -- FP3 -- bridge found
-- 						end loop; -- search in bridge list


					end loop; -- search in pinlist of net
					
-- 					if part_found then return true; -- FP11
-- 					else return false; -- implies an early exit if no conpair or bridge in net found, so no further nets will be searched in
-- 					end if;
			end if; -- if net found
		end loop loop_netlist;

-- 		return false; -- if no part found
	end find_device_by_net;

	
	procedure find_net_by_device_and_pin( -- FN
	-- Locates the net connected to device and pin.
		net_of_origin	: in type_net_name.bounded_string; -- CS: probably not required, see below
		device			: in type_device_name.bounded_string;
		pin				: in type_pin_name.bounded_string ) is

		net					: type_net;
		length_of_pinlist	: count_type;
		pin_scratch			: m1_database.type_pin;
	begin
		loop_netlist:
		for i in 1..length_of_netlist loop
			net := element(list_of_nets, positive(i));

			-- the net must be a non-processed cluster net -- FN9
			if net.cluster and net.cluster_id = 0 then -- FN2

				-- the net must not be the origin net
				if net.name /= net_of_origin then -- FN3 -- CS: probably not required

					length_of_pinlist := length(net.pins);
					for p in 1..length_of_pinlist loop
						pin_scratch := element(net.pins, positive(p)); -- load a pin

						if pin_scratch.device_name = device and pin_scratch.device_pin_name = pin then -- FN4 / FN5
							-- if netlist(net_pt).cluster_id = 0 then -- net found has not been processed yet -- FN9
							-- put_line(standard_output,"    sub net  : " & netlist(net_pt).name);
							-- netlist(net_pt).cluster_id := cluster_ct; -- FN6
							update_element(list_of_nets, positive(i), set_cluster_id'access);

							write_message (
								file_handle => file_mkoptions_messages,
								identation => 3,
								text => "transit to net " & to_string(net.name),
								console => false);
							
							find_device_by_net(net_name => net.name);
							exit loop_netlist;
						end if;
					end loop;
				end if;
			end if;
		end loop loop_netlist;
	end find_net_by_device_and_pin;

	
	procedure make_netlist is

-- 		use type_net_name;
-- 		use type_list_of_nets;
-- 		length_of_netlist	: count_type := length(list_of_nets);
		net					: type_net; -- for temporarily usage
		
		length_of_pinlist	: count_type;
		pin					: m1_database.type_pin; -- for temporarily usage		
		
-- 		procedure find_non_cluster_bs_nets is
-- 		begin
-- 				for n in 1..net_ct
-- 				loop
-- 					if netlist(n).cluster_id = 0 then
-- 						if netlist(n).bs_driver_ct > 0 or netlist(n).bs_input_ct > 0 then
-- 							put("Section " & netlist(n).name & " class NA   -- single bs-net");
-- 							if netlist(n).bs_driver_ct = 0 then put("  -- allowed class : EH , EL"); end if;
-- 							if netlist(n).bs_input_ct = 0 then put("  -- allowed class : NR , DH , DL"); end if;
-- 							new_line;
-- 							put_line(netlist(n).content & "EndSection"); new_line;	
-- 							new_line;
-- 						end if;
-- 					end if;
-- 				end loop;
-- 			end find_non_cluster_bs_nets;
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
-- 		procedure order_clusters is
-- 
-- 		subtype cluster_list_sized is cluster_list_type (1..cluster_ct);
-- 		cluster_list	: cluster_list_sized;
-- 
-- 			procedure order_bs_cluster
-- 				(
-- 				size	: natural;
-- 				members	: unbounded_string -- holds ids of cluster nets, separated by space
-- 				) is
-- 				primary_net_found	: boolean := false;
-- 				begin
-- 					put("Section ");
-- 	
-- 					-- search for a "must be" primary net (with output2 drivers)
-- 					loop_i1: 
-- 					for i in 1..size
-- 					loop
-- 						for n in 1..net_ct
-- 						loop
-- 							if netlist(n).processed = false then
-- 								if netlist(n).net_id = natural'value(get_field(members,i)) then -- member net found
-- 
-- 									if netlist(n).primary_net then
-- 										netlist(n).processed := true;
-- 										put_line(netlist(n).name & " class NA  -- allowed DH, DL, NR");
-- 										csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
-- 										put(netlist(n).content);
-- 										primary_net_found := true;
-- 										exit loop_i1;
-- 									end if;
-- 								end if;
-- 							end if;
-- 						end loop;
-- 					end loop loop_i1;
-- 
-- 					if primary_net_found = false then	
-- 						-- search for a primary net with normal outputs (output3, bidir)
-- 						loop_i2: 
-- 						for i in 1..size
-- 						loop
-- 							for n in 1..net_ct
-- 							loop
-- 								if netlist(n).processed = false then
-- 									if netlist(n).net_id = natural'value(get_field(members,i)) then -- member net found
-- 
-- 										if netlist(n).bs_driver_ct > 0 then
-- 											netlist(n).processed := true;
-- 											put_line(netlist(n).name & " class NA");
-- 											csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
-- 											put(netlist(n).content);
-- 											primary_net_found := true;
-- 											exit loop_i2;
-- 										end if;
-- 
-- 									end if;
-- 								end if;
-- 							end loop;
-- 						end loop loop_i2;
-- 					end if;
-- 
-- 
-- 					if primary_net_found = false then	
-- 						-- search for a primary net with inputs
-- 						loop_i3: 
-- 						for i in 1..size
-- 						loop
-- 							for n in 1..net_ct
-- 							loop
-- 								if netlist(n).processed = false then
-- 									if netlist(n).net_id = natural'value(get_field(members,i)) then -- member net found
-- 
-- 										if netlist(n).bs_input_ct > 0 then
-- 											netlist(n).processed := true;
-- 											put_line(netlist(n).name & " class NA  -- allowed class: EH , EL");
-- 											csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
-- 											put(netlist(n).content);
-- 											primary_net_found := true;
-- 											exit loop_i3;
-- 										end if;
-- 
-- 									end if;
-- 								end if;
-- 							end loop;
-- 						end loop loop_i3;
-- 					end if;
-- 
-- 					-- CS: check if primary_net_found here ?
-- 
-- 					--put_line(" Subsection secondary_nets"); -- rm v026
-- 					put_line(" SubSection secondary_nets"); -- ins v026
-- 
-- 						-- search for secondary nets
-- 						for i in 1..size
-- 						loop
-- 							for n in 1..net_ct
-- 							loop
-- 								if netlist(n).processed = false then
-- 									if netlist(n).net_id = natural'value(get_field(members,i)) then -- member net found
-- 										netlist(n).processed := true;
-- 										put_line("  Net " & netlist(n).name);
-- 										csv.put_field(routing_file,to_string(netlist(n).name)); -- in v028
-- 										put(netlist(n).content);
-- 									end if;
-- 									-- CS: what if no secondary net found ? this may happen if a bridge has open pins
-- 								end if;
-- 							end loop;
-- 						end loop;
-- 
-- 					put_line(" EndSubSection");
-- 					put_line("EndSection");
-- 					new_line(2);
-- 					csv.put_lf(routing_file); -- in v028
-- 				end order_bs_cluster;
-- 
-- 
-- 			begin
-- 				-- make cluster_list
-- 				for c in 1..cluster_ct
-- 				loop
-- 					for n in 1..net_ct
-- 					loop
-- 						if netlist(n).cluster_id = c then -- find nets belonging to the cluster
-- 							cluster_list(c).size := cluster_list(c).size + 1; -- update cluster size
-- 							cluster_list(c).members := cluster_list(c).members & " " & natural'image(netlist(n).net_id); -- collect net ids
-- 					
-- 							-- if any net of this cluster has bs input or output, mark cluster as bs capable
-- 							if netlist(n).bs_driver_ct > 0 or netlist(n).bs_input_ct > 0 then cluster_list(c).bs := true; end if;
-- 						end if;
-- 					end loop;
-- 				end loop;
-- 
-- 
-- 				-- find bs-cluster
-- 				for c in 1..cluster_ct
-- 				loop
-- 					if cluster_list(c).ordered = false then
-- 						if cluster_list(c).bs then
-- 							--put_line("-- bs cluster size : " & natural'image(cluster_list(c).size));					
-- 	--						put_line("-- bs-cluster :");
-- 							order_bs_cluster(cluster_list(c).size,cluster_list(c).members);
-- 							cluster_list(c).ordered := true;
-- 						end if;
-- 
-- 					end if;
-- 				end loop;
-- 
-- 				-- find non-cluster bs nets
-- 				find_non_cluster_bs_nets;
-- 
-- 				-- find non-bs clusters
-- 				for c in 1..cluster_ct
-- 				loop
-- 					if cluster_list(c).ordered = false then
-- 						if cluster_list(c).bs = false then
-- 							--put_line("-- cluster size : " & natural'image(cluster_list(c).size));
-- 							for i in 1..cluster_list(c).size -- i points to cluster member net_id 
-- 							loop
-- 								for n in 1..net_ct
-- 								loop
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
-- 						end if;
-- 					end if;
-- 				end loop;
-- 
-- 
-- 				find_non_cluster_non_bs_nets;
-- 
-- 			end order_clusters;
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

-- 		procedure set_cluster_id (net : in out type_net) is
-- 		begin
-- 			put(standard_output,natural'image(cluster_counter) & ascii.cr); -- CS: progress bar instead ?
-- 
-- 			write_message (
-- 				file_handle => file_mkoptions_messages,
-- 				identation => 2,
-- 				text => "net " & to_string(net.name),
-- 				console => false);
-- 
-- 			net.cluster_id := cluster_counter;			
-- 		end set_cluster_id;
			
	begin -- make_netlist

		write_message (
			file_handle => file_mkoptions_messages,
			identation => 1,
			text => "marking cluster nets ...",
			console => true);

		-- Search in list_of_nets for a pin with same name as a connector or a bridge.
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
				if is_pin_of_bridge(pin) then
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

			-- if net is a cluster and if it has not been assigned a cluster id yet
			if net.cluster and net.cluster_id = 0 then
				cluster_counter := cluster_counter + 1;

				-- assign cluster id 
				--netlist(net_pt).cluster_id := cluster_ct;				
				update_element(list_of_nets, positive(i), set_cluster_id'access);

				length_of_pinlist := length(net.pins);
				for p in 1..length_of_pinlist loop
					pin := element(net.pins, positive(p)); -- load a pin

					-- Test if pin belongs to a connector. 
					-- If it is pin of a connector mark it as processed.
					result_of_connector_query := is_pin_of_connector(pin);
					if result_of_connector_query.is_connector_pin then
						mark_connector_pin_as_processed(
							device => pin.device_name,
							pin => pin.device_pin_name,
							side => opposide_of(result_of_connector_query.side)
							);

						-- Result_of_connector_query provides the device and pin name of the
						-- connector on the other side of the pair.

						-- Now we transit to the other side of the connector pair:
						find_net_by_device_and_pin(
							net_of_origin => net.name, -- CS: probably not required
							device => result_of_connector_query.device_name,
							pin => result_of_connector_query.device_pin_name);
					end if;

--					-- check if part is a bridge
-- 						for b in 1..bridge_ct
-- 						loop
-- 							if bridge_list(b).name = part then -- AC2
-- 								if bridge_list(b).pin_a = pin then -- pin A found
-- 									-- this pin is connected with a net, so we mark this pin as "connected" now
-- 									bridge_list(b).pin_a_connected := true; -- ins v027
-- 									bridge_list(b).pin_b_processed := true; --AC3
-- 									--put_line(part & " counter pin " & bridge_list(b).pin_b);  -- CS: early exit ?
-- 									--put_line(standard_output,"     bridge " & part & " pin " & pin); 
-- 									if find_net_by_part_and_pin
-- 										(
-- 										net_id_origin => netlist(net_pt).net_id,
-- 										part_given => part,
-- 										pin_given => bridge_list(b).pin_b -- pin A has been found, so pin B must be passed
-- 										)
-- 										then null;
-- 									end if;
-- 									exit; -- test
-- 
-- 								elsif bridge_list(b).pin_b = pin then -- pin B found -- AC4
-- 									-- this pin is connected with a net, so we mark this pin as "connected" now
-- 									bridge_list(b).pin_b_connected := true; -- ins v027
-- 									bridge_list(b).pin_a_processed := true;	-- AC5
-- 									--put_line(part & " counter pin " & bridge_list(b).pin_a);  -- CS: early exit ?
-- 									--put_line(standard_output,"     bridge " & part & " pin " & pin); 
-- 									if find_net_by_part_and_pin
-- 										(
-- 										net_id_origin => netlist(net_pt).net_id,
-- 										part_given => part,
-- 										pin_given => bridge_list(b).pin_a -- pin B has been found, so pin A must be passed
-- 										)
-- 										then null;
-- 									end if;
-- 									exit; -- test
-- 
-- 								else null; -- CS: should we do something here ?
-- 									-- in this case, a resistor of an array has been found, but the pin names do not match
-- 									-- so in the next looping another path of the array is to be examined -- ins v027
-- 								end if;
-- 							end if;
-- 						end loop;
-- 
-- 
				end loop;
-- 					--new_line;
-- 
			end if;
		end loop;
-- 
-- 			new_line(standard_output);
-- 
-- 
-- 			-- ins v027 begin
-- 			-- check for open bridge array pins
-- -- 			prog_position := "OP1";
-- 			if bridge_ct > 0 then
-- 				for b in 1..bridge_ct
-- 				loop
-- 					if bridge_list(b).part_of_array = true then -- search in bridges for unconnected pins
-- 						if bridge_list(b).pin_a_connected = false then
-- 							put_line("-- WARNING : Bridge " & bridge_list(b).name & " has unconnected pin " & bridge_list(b).pin_a & " !");
-- 							put_line("-- Check array declaration in mkoptions.conf file !"); new_line;
-- 						end if;
-- 						if bridge_list(b).pin_b_connected = false then
-- 							put_line("-- WARNING : Bridge " & bridge_list(b).name & " has unconnected pin " & bridge_list(b).pin_b & " !"); 
-- 							put_line("-- Check array declaration in mkoptions.conf file !"); new_line; 
-- 						end if;
-- 					end if;
-- 				end loop;
-- 			end if;
-- 
-- 			new_line; put_line("-- NETLIST -----------------------------------------------------------"); new_line; -- ins v027
-- 			-- ins v027 end
-- 
-- 
-- 			if cluster_ct > 0 then 
-- 				-- order net clusters
-- 				put_line(standard_output,"ordering clusters ...");
-- 				order_clusters;
-- 			else
-- 				find_non_cluster_bs_nets;
-- 				find_non_cluster_non_bs_nets;
-- 			end if;
-- 
-- 			return true;
	end make_netlist;	

	
-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := mkoptions;
	degree_of_database_integrity_check := light; -- CS: for testing only	
	
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
    read_database;
    
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

	length_of_netlist := length(list_of_nets);
	make_netlist;

	

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
