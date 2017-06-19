------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE IMPZUKEN                            --
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
--   NOTE: This importer has been tested with CR5000 format.

--   history of changes:
--


with ada.text_io;				use ada.text_io;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;

with ada.strings;				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.exceptions; 			use ada.exceptions;

with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_base;					use m1_base;
with m1_import;					use m1_import;
with m1_database;               use m1_database;
with m1_numbers;                use m1_numbers;
with m1_files_and_directories;  use m1_files_and_directories;
with m1_string_processing;		use m1_string_processing;


procedure impzuken is

	version			: constant string (1..3) := "001";
    prog_position	: natural := 0;

	use type_net_name;
	use type_device_name;
	use type_device_value;
	use type_package_name;
	use type_pin_name;
	use type_map_of_nets;
	use m1_import.type_list_of_pins;
	use type_map_of_devices;

	use type_name_file_netlist;
	use type_universal_string;
	use type_name_file_skeleton_submodule;
	
	

	line_counter : natural := 0; -- the line number in the given zuken netlist file

	-- Every line in the netlist file stands for a pin.
	-- example: 
	-- "GND" : GROUND: "SN74HC00" : "SN74HC00" : "U700" : "7" : UNFIXED  : "7.cmp169" : "2" : PACKAGESYMBOL;
	-- Sometimes such an entry is broken into fragments and spread over more than one line like:

	-- "GND" : GROUND: "SN74HC00" 
	-- : "SN74HC00" : "U700" : "7" : UNFIXED  : "7.cmp169" : "2" 
	-- : PACKAGESYMBOL;

	-- If the first field (the name field) is emtpy, the pin is not connected.
	-- We create a virtual net attached to this pin. It will later be addressed by the test generators.
	-- For such cases the line number of the first field of the entry (the net name) is stored in line_number for 
	-- log messages.
	
	-- this is the upper limit of fields in a line in the netlist file:
	maximum_field_count_per_line : constant count_type := 10; 

	-- This type specifies an entry in the zuken netlist.
	type type_entry_in_zuken_netlist is record		
		net			: type_net_name.bounded_string;		-- the net name (CAUTION: may be empty)
		device		: type_device_name.bounded_string;	-- the device name like IC45
		value		: type_device_value.bounded_string;	-- the value like SN74HC00
		packge 		: type_package_name.bounded_string;	-- the package of the device like SO14
		pin  		: type_pin_name.bounded_string;		-- the pin name like 4 or E34
		line_number	: positive;							-- the line number of the net name field
		-- CS: other elements ?
		processed	: Boolean := false; -- used to mark a processed line
	end record;

	-- Entries of the zuken netlist are stored in a vector named zuken_netlist.
	package type_zuken_netlist is new vectors ( 
		element_type => type_entry_in_zuken_netlist,
		index_type => positive);
	use type_zuken_netlist;
	zuken_netlist : type_zuken_netlist.vector; -- when reading the netlist file, everything goes here




	procedure read_netlist is
	-- Reads the given netlist file and stores it in vector zuken_netlist
		pin_entry 				: type_fields_of_line; -- every entry represents a pin
		pin_entry_bak			: type_fields_of_line;
		last_entry_was_complete	: boolean := true; -- goes false once an incomplete entry was found
		line_number_bak 		: positive;

		procedure log_line (number : in positive) is begin
		-- Every complete line represents a pin:
			put_line(" line" & positive'image(number) & ": " & to_string(pin_entry));
		end log_line;

	begin -- read_netlist
		write_message (
			file_handle => file_import_cad_messages,
			text => "reading zuken netlist file ...",
			console => true);

		open (file => file_cad_netlist, mode => in_file, name => to_string(name_file_cad_netlist));
		set_input(file_cad_netlist);

		-- CS: reserve_capacity(line.fields, maximum_field_count_per_line);

		while not end_of_file loop
			line_counter := line_counter + 1;

			-- progrss bar
			if (line_counter rem 200) = 0 then
				put(standard_output,'.');
			end if;

			-- Read a line from the netlist file in variable pin_entry.
			-- The fields of an entry are separated by colon:
			pin_entry := read_line(get_line, latin_1.colon);

			-- Empty lines are skipped.
			-- Lines with maximum_field_count_per_line contain all required fields and can be appended to zuken_netlist right away.
			-- Lines with less fields are concatenated until maximum_field_count_per_line is reached and then
			-- appended to zuken_netlist.
			-- The line number where an entry starts (the line holding the net name field) is stored along with the actual fields.
			case pin_entry.field_count is
				when 0 => null; -- empty line. nothing to do
				
				when maximum_field_count_per_line => 
					-- Entry complete. Alle fields can be appended to netlist right away:

					log_line(line_counter);
					
					append(zuken_netlist, ( 
						net => 		to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 1),both))),
						value =>	to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 3),both))),
						packge =>	to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 4),both))),
						device =>	to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 5),both))),
						pin =>		to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 6),both))),
						line_number => line_counter,
						processed => false -- will be later used when sorting the zuken_netlist.
						));
				
				when 1..9 => 
					-- This entry is incomplete. last_entry_was_complete goes false.
					-- We store what we have got so far in line_bak and append the fields of next line to line_bak
					-- until maximum_field_count_per_line reached.
					if last_entry_was_complete then
						pin_entry_bak := pin_entry;
						last_entry_was_complete := false;
						line_number_bak := line_counter; -- backup line number where entry starts
						
					else
						pin_entry := append(pin_entry_bak,pin_entry); 

						-- If all fields read, append entry to zuken_netlist.
						if pin_entry.field_count = maximum_field_count_per_line then

							-- CS: test if last field ends with semicolon
														
							last_entry_was_complete := true;

							log_line(line_number_bak);
							
							-- Append the complete entry to the zuken_netlist (use line number where the entry had started):
							append(zuken_netlist, ( 
								net => 		to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 1),both))),
								value =>	to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 3),both))),
								packge =>	to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 4),both))),
								device =>	to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 5),both))),
								pin =>		to_bounded_string(strip_quotes(trim(get_field_from_line(pin_entry, 6),both))),
								line_number => line_number_bak,
								processed => false
								));
							
						else
							-- if entry still not complete save what we have got in pin_entry__bak
							pin_entry_bak := pin_entry;
						end if;
					end if;

				when others => -- If entry contains more than maximum_field_count_per_line we have a corrupted netlist.
					write_message (
						file_handle => file_import_cad_messages,
						text => message_error & "too many fields in line " & natural'image(line_counter) & " !",
						console => true);
					raise constraint_error;
			end case;

		end loop;
		new_line(standard_output); -- finishes the progress bar

		-- Finally last_entry_was_complete must be found true.
		if not last_entry_was_complete then
			write_message (
				file_handle => file_import_cad_messages,
				text => message_error & "too less fields in line" & natural'image(line_counter) & " !" 
					& " Netlist incomplete !",
				console => true);
			raise constraint_error;
		end if;

	end read_netlist;


	procedure sort_netlist is
	-- Reads the zuken_netlist and builds the map_of_nets. 
	-- map_of_nets is required by procedure write_skeleton.
		entry_a		: type_entry_in_zuken_netlist; -- an entry in zuken_netlist. we call it the primary entry.
		entry_b		: type_entry_in_zuken_netlist; -- an entry in zuken_netlist. we call it the secondary entry.
		net 		: m1_import.type_net; -- scratch place to assemble a net before inserting in map_of_nets
		net_name	: type_net_name.bounded_string;

		nc_pin		: boolean; -- goes true if entry has an empty net name
	
		procedure set_processed_flag (e : in out type_entry_in_zuken_netlist) is
		begin
			e.processed := true;
		end set_processed_flag;
		
	begin -- sort_netlist
		write_message (
			file_handle => file_import_cad_messages,
			text => "sorting netlist ...",
			console => true);

		-- Every entry in zuken_netlist represents a pin.
		-- Search for equal net names in zuken_netlist and collect pins in scratch variable "net.pins".
		-- Processed entries are crossed out by setting flag "processed".
		for a in 1..positive(length(zuken_netlist)) loop
			entry_a := element(zuken_netlist, a); -- load the primary entry

			if not entry_a.processed then -- care for non-processed entries only
				net_name := entry_a.net; -- derive the name of the net to be assembled from the primary entry

				-- Create virtual nets for unconnected pins (net name is empty).
				if length(net_name) = 0 then
					net_name := virtual_net_name(device => entry_a.device, pin => entry_a.pin);
					put_line(" line" & positive'image(entry_a.line_number)
						& ": unconnected pin -> create virtual net " 
						& to_string(net_name)); 
					nc_pin := true;
				else
					put_line(" net " & to_string(net_name) & " with pins: ");
					put_line("  " & to_string(entry_a.device) & row_separator_0 & to_string(entry_a.pin));
					nc_pin := false;
				end if;

				-- append the device and pin name to scratch net
				append(net.pins, (
					name_device	=> entry_a.device,
					name_pin	=> entry_a.pin
					));

				-- count pins for statistics
				pin_count := pin_count + 1;

				if not nc_pin then
					-- search further down the zuken_netlist for other pins with the same net_name
					for b in a+1 .. positive(length(zuken_netlist)) loop
						entry_b := element(zuken_netlist, b); -- load a secondary entry
						--if entry_b.net = net_name then -- net found
						if entry_b.net = entry_a.net then -- net found

							-- append device an pin name to scrach net
							append(net.pins, (
								name_device	=> entry_b.device,
								name_pin 	=> entry_b.pin
								));

							-- count pins for statistics
							pin_count := pin_count + 1;

							-- for the logs:
							put_line("  " & to_string(entry_b.device) & row_separator_0 & to_string(entry_b.pin));

							-- mark line of zuken_netlist as processed so that further spins can ignore it
							update_element(zuken_netlist, b, set_processed_flag'access);
						end if;
					end loop;
				end if;
				
				-- Now all pins of the net have been collected. net is ready for insertion in map_of_nets.
				-- (We use the net_name as key in case it has been named with default_name_for_noname_nets.)
				insert(container => map_of_nets, key => net_name, new_item => net);

				-- clear pinlist for next spin
				net.pins := m1_import.type_list_of_pins.empty_vector;
			end if;
		end loop;
		
	end sort_netlist;
	
	procedure make_map_of_devices is
	-- reads the zuken_netlist and builds the map_of_devices
		line : type_entry_in_zuken_netlist; -- this is an entry within list "zuken_netlist"
		inserted : boolean;
		cursor : type_map_of_devices.cursor;
	begin
		write_message (
			file_handle => file_import_cad_messages,
			text => "building device map ...",
			console => true);

		for i in 1..positive(length(zuken_netlist)) loop
			line := element(zuken_netlist, i); -- load line

			-- insert device in map_of_devices
			type_map_of_devices.insert(
				container	=> map_of_devices,
				key			=> line.device,
				position	=> cursor,
				new_item	=> (packge => line.packge, value => line.value),
				inserted	=> inserted);

			if inserted then
				put_line(row_separator_0 & to_string(line.device));
			end if;
		end loop;

	end make_map_of_devices;


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := import_cad;

	-- create message/log file	
	format_cad := zuken;
	write_log_header(version);
	
	put_line(to_upper(name_module_cad_importer_zuken) & " version " & version);
	put_line("======================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages
	
	prog_position	:= 10;
	name_file_cad_netlist:= to_bounded_string(argument(1));
	
	write_message (
		file_handle => file_import_cad_messages,
		text => "netlist " & to_string(name_file_cad_netlist),
		console => true);

	prog_position	:= 20;		
	cad_import_target_module := type_cad_import_target_module'value(argument(2));
	write_message (
		file_handle => file_import_cad_messages,
		text => "target module " & type_cad_import_target_module'image(cad_import_target_module),
		console => true);
	
	prog_position	:= 30;
	if cad_import_target_module = m1_import.sub then
		target_module_prefix := to_bounded_string(argument(3));

		write_message (
			file_handle => file_import_cad_messages,
			text => "prefix " & to_string(target_module_prefix),
			console => true);
		
		name_file_skeleton_submodule := to_bounded_string(compose( name => 
			base_name(name_file_skeleton) & "_" & 
			to_string(target_module_prefix),
			extension => file_extension_text));
	end if;
	
	prog_position	:= 50;	
	read_netlist;

	sort_netlist;
	make_map_of_devices;

	write_skeleton (name_module_cad_importer_zuken, version);

	prog_position	:= 100;
	write_log_footer;	
	
	exception when event: others =>
		set_exit_status(failure);

		write_message (
			file_handle => file_import_cad_messages,
			text => message_error & "at program position " & natural'image(prog_position),
			console => true);
	
		if is_open(file_skeleton) then
			close(file_skeleton);
		end if;

		if is_open(file_cad_netlist) then
			close(file_cad_netlist);
		end if;

		case prog_position is
			when others =>
				write_message (
					file_handle => file_import_cad_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_import_cad_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;


end impzuken;
