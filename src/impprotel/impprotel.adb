------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE IMPPROTEL                           --
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
--   Mario.Blunk@blunk-electronic.de
--   or visit <http://www.blunk-electronic.de> for more contact data
--
--   history of changes:
--
--	 todo: apply dos2unix on protel netlist

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

procedure impprotel is

	version			: constant string (1..3) := "001";
    prog_position	: natural := 0;

    length_of_line_in_netlist : constant positive := 200; -- CS: increase if neccesary
    package type_line is new generic_bounded_length(length_of_line_in_netlist);
    use type_line;
    line_counter : natural := 0;
    line : type_line.bounded_string;

	use type_extended_string;
	use type_universal_string;
	use type_name_file_netlist;
	use type_name_file_list_of_assembly_variants;
	use type_name_file_skeleton_submodule;
	use type_net_name;
	use type_device_name;
	use type_pin_name;
	use type_device_value;
	use type_package_name;
	use type_list_of_devices_with_variants;	
	use type_map_of_devices;	
	
	use m1_import.type_list_of_pins;
	use type_list_of_pins_of_variants;

	use type_list_of_nets_with_variants;
	use type_map_of_nets;

	
	device_pin_separator : constant string (1..1) := "-";

	function split_device_pin (text_in : type_line.bounded_string) return m1_import.type_pin_of_variant is
		pin : m1_import.type_pin_of_variant;
		ifs_position : positive := index(text_in,device_pin_separator);
	begin
 		pin.name_device := to_bounded_string(slice(text_in,1,ifs_position-1));
		pin.name_pin    := to_bounded_string(slice(text_in,ifs_position+1,length(text_in)));
		return pin;
	end split_device_pin;

	-- ASSEMBLY VARIANTS
	list_of_variants_created : boolean := false;
	-- Goes true if new list of assembly variants has been created.
	
	type type_assembly_variant is record
		name		: type_device_name.bounded_string; -- the device it is about
		position	: positive := 1; -- position in file_list_of_assembly_variants
		packge		: type_package_name.bounded_string;
		value		: type_device_value.bounded_string; -- CS: package and value should be read and verified
		active		: boolean := false;
		processed	: boolean := false;
	end record;

	package type_list_of_assembly_variants is new vectors (positive, type_assembly_variant);
	use type_list_of_assembly_variants;
	list_of_assembly_variants : type_list_of_assembly_variants.vector;

	procedure manage_assembly_variants is
	-- Detects assembly variants in netlist.
	-- If there are any, it creates file_list_of_assembly_variants. 
	-- The operator must edit the file in order to select active variants.
	-- If variants are set active in file_list_of_assembly_variants they are applied
	-- to the list_of_nets and list_of_devices.
		length_list_of_devices	: natural := natural(length(list_of_devices_with_variants));
		device_scratch 			: type_device_with_variants;
		
		function detect_assembly_variants return boolean is
		-- Returns true if design has assembly variants.
			variants_found : boolean := false;

			procedure mark_as_having_variants (device : in out type_device_with_variants) is
			begin device.has_variants := true; end mark_as_having_variants;
			
			procedure mark_as_processed (device : in out type_device_with_variants) is
			begin device.processed := true; end mark_as_processed;

			variant_id : positive := 1;
			procedure set_variant_id ( device : in out type_device_with_variants) is
			begin 
				device.variant_id := variant_id;
			end set_variant_id;

		begin -- detect_assembly_variants
			write_message (
				file_handle => file_import_cad_messages,
				text => "detecting assembly variants ...",
				identation => 1,
				console => true);

			-- Search in list_of_devices for multiple occurences of devices.
			-- If a device occurs more than once, it has variants.
			-- Sets the flag variants_found once any device occurs more than once.
			-- Sets the flag has_variants of a device if it occurs more than once.
			-- Sets the variant_id of a device according to the occurence of the same device in the list_of_devices.
			if length_list_of_devices > 0 then -- do that if there are devices at all
				for dp in 1..length_list_of_devices loop
					device_scratch := element(list_of_devices_with_variants, dp); -- load an initial device
					if not device_scratch.processed then -- skip already processed devices
						variant_id := 1; -- reset variant id
						-- incremented on each occurence of device_scratch

						-- Search for same device further down the list_of_devices.
						for ds in dp+1..length_list_of_devices loop 
							if element(list_of_devices_with_variants, ds).name = device_scratch.name then
								variant_id := variant_id + 1;
								update_element(list_of_devices_with_variants, ds,set_variant_id'access);
								update_element(list_of_devices_with_variants, ds,mark_as_having_variants'access);
								update_element(list_of_devices_with_variants, ds,mark_as_processed'access);
							end if;
						end loop;

						-- If initial device occured more than once, mark it as "having variants".
						if variant_id > 1 then
							update_element(list_of_devices_with_variants, dp, mark_as_having_variants'access);
							
							write_message (
								file_handle => file_import_cad_messages,
								text => message_warning & "device " 
									& to_string(device_scratch.name) 
									& " has" & positive'image(variant_id) & " variants !",
								identation => 2,
								console => false);

							variants_found := true;
						end if;
					end if;
				end loop;
			else
				write_message (
					file_handle => file_import_cad_messages,
					text => message_warning & " no devices found !",
					console => true);
				write_advise_dos2unix;
			end if;
			
			return variants_found;
		end detect_assembly_variants;
		
		procedure mark_device_as_mounted (device : in out type_device_with_variants) is
		begin 
			device.mounted := true;
		end mark_device_as_mounted;

		procedure mark_pin_as_mounted (pin : in out type_pin_of_variant) is
		begin 
			pin.mounted := true; 
		end mark_pin_as_mounted;

		procedure read_assembly_variants is
		-- Reads assembly variants from file_list_of_assembly_variants in list_of_assembly_variants.
		-- The variant with the trailing keyword "active" get the flag "active" set.
			line_counter 				: natural := 0;
			line 						: type_extended_string.bounded_string;
			assembly_variant_scratch	: type_assembly_variant;
		begin

			write_message(
				file_handle => file_import_cad_messages,
				text => "reading list of assembly variants ...",
				identation => 1,
				console => false);
			
			open (file_variants, in_file, to_string(name_file_list_of_assembly_variants));
			set_input(file_variants);
			while not end_of_file loop
				line := to_bounded_string(remove_comment_from_line(get_line));
				line_counter := line_counter + 1;
				if get_field_count(to_string(line)) > 0 then -- skip empty lines

					-- read assembly variant from a line like "R3 12K RESC1005X40N active"
					
					assembly_variant_scratch.name := to_bounded_string(get_field_from_line(to_string(line),1));
					assembly_variant_scratch.value := to_bounded_string(get_field_from_line(to_string(line),2));
					assembly_variant_scratch.packge := to_bounded_string(get_field_from_line(to_string(line),3));

					-- If there is a 4rd field, it must read "active". Otherwise this variant is considered as not active.
					if get_field_count(to_string(line)) > 3 then
						-- Test if 4rd field contains "active". Throw error message on typing error.
						if get_field_from_line(to_string(line),4) = keyword_assembly_variant_active then
							assembly_variant_scratch.active := true;
						else
							write_message(
								file_handle => file_import_cad_messages,
								text => message_error & "in file " 
									& to_string(name_file_list_of_assembly_variants)
									& " line" & natural'image(line_counter)
									& ": expected keyword '" & keyword_assembly_variant_active & "' !",
								console => true);
							raise constraint_error;
						end if;
					else -- no 4rd field found. variant is not active
						assembly_variant_scratch.active := false;
					end if;

					write_message(
						file_handle => file_import_cad_messages,
						text => to_string(assembly_variant_scratch.name) & row_separator_0
							& to_string(assembly_variant_scratch.value) & row_separator_0
							& to_string(assembly_variant_scratch.packge) & row_separator_0
							& keyword_assembly_variant_active & row_separator_0 
							& boolean'image(assembly_variant_scratch.active),
						identation => 2,
						console => false);

					-- append assembly variant to list
					append(list_of_assembly_variants,assembly_variant_scratch);

					-- purge temporarly assembly variant
					assembly_variant_scratch.name := to_bounded_string("");
					assembly_variant_scratch.value := to_bounded_string("");
					assembly_variant_scratch.packge := to_bounded_string("");
					assembly_variant_scratch.active := false; -- reset active flag for next spin
				end if;
			end loop;
			set_input(standard_input);
			close(file_variants);
		end read_assembly_variants;

		procedure set_position_of_variants is
		-- Assigns to assembly variants the position where
		-- they appear in the file file_list_of_assembly_variants.
			
			l : natural := natural(length(list_of_assembly_variants));
			vp, vs : type_assembly_variant;
			p : positive := 1; -- position of variant

			procedure set_position (variant : in out type_assembly_variant) is
			-- Assigns the position currently held in p to the variant being processed.
			-- Marks the current variant as processed.
			begin 
				variant.position := p;
				variant.processed := true;
			end set_position;
			
		begin -- get_position_of_variants
			write_message(
				file_handle => file_import_cad_messages,
				text => "setting position of variants ...",
				identation => 1,
				console => false);
			
			for ap in 1..l loop -- loop in list of assembly variants
				vp := element(list_of_assembly_variants,ap); -- load variant
				if not vp.processed then -- skip already processed variants
					p := 1; -- reset position

					for as in ap+1..l loop -- serach for further occurences of same name down the list
						vs := element(list_of_assembly_variants,as);
						if vp.name = vs.name then -- on name match
							p := p + 1; -- increment position on match
							--update_element(list_of_assembly_variants,as,mark_variant_as_processed'access);
							update_element(list_of_assembly_variants,as,set_position'access);
						end if;
					end loop;
				end if; -- if not vp.processed
			end loop;
		end set_position_of_variants;

		procedure apply_assembly_variants_on_device_list is
		-- Sets the flag "mounted" of a device in list_of_devices.
			la						: positive := natural(length(list_of_assembly_variants));
			v						: type_assembly_variant;			
			active_variant_found	: boolean := false;
			device_scratch			: type_device_with_variants;
		begin -- apply_assembly_variants_on_device_list
			write_message(
				file_handle => file_import_cad_messages,
				text => "applying assembly variants on device list ...",
				identation => 1,
				console => false);
			
			for d in 1..length_list_of_devices loop -- loop in device list
				device_scratch := element(list_of_devices_with_variants, d); -- load a device
				if device_scratch.has_variants then -- if device has variants, search in variants list for that device

					-- search current device in list_of_assembly_variants
					for a in 1..la loop
						v := element(list_of_assembly_variants,a); -- load an assembly variant

-- 						write_message(
-- 							file_handle => file_import_cad_messages,
-- 							text => to_string(v.name) & " pos." & positive'image(v.position),
-- 							identation => 3,
-- 							console => false);
						
						-- if variant matches in device name, package, value, id and if it is active, 
						-- then the active assembly variant has been found -> the devive is to be mounted
						if  to_string(device_scratch.name)   = to_string(v.name) and 
							to_string(device_scratch.packge) = to_string(v.packge) and
							to_string(device_scratch.value)  = to_string(v.value) and
							device_scratch.variant_id = v.position and
							v.active then -- active variant found, abort search (there is only one active variant)

								write_message(
									file_handle => file_import_cad_messages,
									identation => 2,
									text => to_string(device_scratch.name) & " variant #" & trim(positive'image(device_scratch.variant_id),left),
									console => false);

								active_variant_found := true;
								-- put_line(file_skeleton,to_string(device_scratch.name)); -- dbg
								update_element(list_of_devices_with_variants, d, mark_device_as_mounted'access);
								exit;
						end if;
					end loop;

					-- CS ???
					--safety measure;
-- 					if not active_variant_found then
-- 						write_message(
-- 							file_handle => file_import_cad_messages,
-- 							text => message_error & "No active variant found for device " 
-- 								& to_string(device_scratch.name) & " !",
-- 							console => true);
-- 
-- 						raise constraint_error;
-- 					end if;
				else
					-- no variants, device is to be mounted
					update_element(list_of_devices_with_variants, d, mark_device_as_mounted'access);
				end if;
			end loop;
		end apply_assembly_variants_on_device_list;


		procedure apply_assembly_variants_on_netlist is
		-- Sets the flag "mounted" of pins.
		-- Loads net by net. If a device/pin has no assembly variants it gets marked as "mounted".
			
		-- If a device/pin has assembly variants, the position X of the active variant in list_of_assembly_variants
		-- serves to mark the Xth occurence of the device/pin (in the net) as "mounted".
		-- If device/pin has assembly variants but none is active, it will NOT be marked as "mounted".
			ln : positive := natural(length(list_of_nets_with_variants));
			active_variant_position : natural;
			pin_occurence : positive;
			
			net_scratch : type_net_with_variants;
			pin_scratch : m1_import.type_pin_of_variant;

			function device_has_variants ( device : in type_device_name.bounded_string) return boolean is
			-- Returns true if given device has assembly variants.
			begin
				-- It is sufficent to look in the list_of_assembly_variants whether the given device
				-- is listed therein:
				for v in 1..length(list_of_assembly_variants) loop
					if element(list_of_assembly_variants, positive(v)).name = device then
						return true;
					end if;
				end loop;
			
				return false;
			end device_has_variants;
			
			function active_variant_position_of (name : in type_device_name.bounded_string) return natural is
			-- Returns the position of the active variant of the given device. 
			-- If device has no active variants, return zero.
				position	: natural := 0;
			begin
				for v in 1..length(list_of_assembly_variants) loop
					if element(list_of_assembly_variants, positive(v)).name = name then
						if element(list_of_assembly_variants, positive(v)).active then
							position := element(list_of_assembly_variants, positive(v)).position;
							exit; -- no more search required
						end if;
					end if;
				end loop;
				return position;
			end active_variant_position_of;


			function pin_occurence_in_net (
			-- Returns the occurence of a pin of an assembly variant of given
			-- device name within the given net.
				net		: in m1_import.type_net_with_variants; -- the net of interest
				pin_id	: in positive; -- the position of the given pin in the pinlist
				device	: in type_device_name.bounded_string -- the device of interest
				) return positive is 
				
				occurence 	: natural := 0; -- counts the occurences of the given device
				lp 			: positive := positive(length(net.pins)); -- length of pinlist
				scratch		: type_device_name.bounded_string;

				-- safety measure: used to verify that the variant has been found
				pin_found	: boolean := false;
			begin
				-- Loop in pinlist of the given net.
				-- Count occurences of given device device. 
				-- Abort when given pin_id reached and return occurence.
				for pp in 1..lp loop -- loop in pinlist of given net
					scratch := element(net.pins,pp).name_device; -- load device name of pin
					if scratch = device then -- first occurence of given device
						occurence := occurence + 1; -- count occurences
						if pp = pin_id then -- given pin_id reached
							pin_found := true;
							exit;
						end if;
					end if;
				end loop;

				-- safety measure:
				if not pin_found then
					write_message(
						file_handle => file_import_cad_messages,
						text => message_error & "No variant for device " 
							& to_string(device) 
							& " found in net " & to_string(net.name) & " !",
						console => true);
					raise constraint_error;
				end if;

				return occurence;
			end pin_occurence_in_net;

		begin -- apply_assembly_variants_on_netlist
			write_message(
				file_handle => file_import_cad_messages,
				text => "applying assembly variants on netlist ...",
				identation => 1,
				console => false);
			
			for n in 1..ln loop -- loop in netlist
				net_scratch := element(list_of_nets_with_variants, n); -- load a net

				write_message(
					file_handle => file_import_cad_messages,
					text => "net " & to_string(net_scratch.name),
					identation => 2,
					console => false);
				
				-- In the current net: mark device/pins to be mounted (as specified by assembly variants)
				for p in 1..length(net_scratch.pins) loop -- loop in pinlist of that net
					pin_scratch := element(net_scratch.pins,positive(p)); -- load a pin
					if device_has_variants(pin_scratch.name_device) then
						
						-- get active variant position of device
						active_variant_position := active_variant_position_of(pin_scratch.name_device); 
						if active_variant_position > 0 then 
							-- Device has an active variant.
							-- Now we have: a net in net_scratch, a pin position in p and a device name.
							-- Get occurence of device with pin in that net. 
							-- If it equals the active_variant_position the pin is to be marked as "mounted".
							
							pin_occurence := pin_occurence_in_net(
												net_scratch,
												positive(p),
												pin_scratch.name_device); 

							if pin_occurence = active_variant_position then -- pin is to be "mounted"
								update_element(net_scratch.pins,positive(p),mark_pin_as_mounted'access);
							end if;
						else 
							-- If no active variant DO NOT mount device.
							null;
						end if;
						
					else -- no variants, pin is to be "mounted"
						update_element(net_scratch.pins,positive(p),mark_pin_as_mounted'access);
					end if;
				end loop;

				-- write modified net back in list_of_nets
				replace_element(list_of_nets_with_variants, n, net_scratch);
			end loop;

		end apply_assembly_variants_on_netlist;
		

		procedure mark_all_devices_as_mounted is
		begin
			for i in 1..length(list_of_devices_with_variants) loop
				update_element(list_of_devices_with_variants, positive(i), mark_device_as_mounted'access);
			end loop;
		end mark_all_devices_as_mounted;
		
		procedure mark_all_pins_as_mounted is
			ln	: count_type := length(list_of_nets_with_variants);
			lp 	: count_type;
			net	: m1_import.type_net_with_variants;
		begin
			for n in 1..ln loop -- loop in netlist
				net := element(list_of_nets_with_variants, positive(n)); -- load a net
				lp := length( net.pins ); -- set number of pins
				if lp > 0 then -- if there are pins in the net
					
					for p in 1..lp loop -- loop in pinlist
						update_element(
							net.pins, 		-- the pinlist of the net at position n
							positive(p),	-- the pin at position p
							mark_pin_as_mounted'access);
					end loop;
					
				end if; -- if there are pins in the net
				replace_element(list_of_nets_with_variants, positive(n), net);
			end loop;
		end mark_all_pins_as_mounted;
		
		
	begin -- manage_assembly_variants
		-- If there are variants: Write them in a file_list_of_assembly_variants.
		-- The operator has to mark active assembly variants in this file.
		-- If file_list_of_assembly_variants already exists, read its content and
		-- apply it to list_of_devices and list_of_nets.

		new_line(file_import_cad_messages);
		write_message (
			file_handle => file_import_cad_messages,
			text => "managing assembly variants ...",
			console => true);

		if detect_assembly_variants then
			
			write_message(
				 file_handle => file_import_cad_messages,
				 text => message_warning & "Design has assembly variants !",
				 console => true);

			-- build the name of file_list_of_assembly_variants from the given netlist file
			name_file_list_of_assembly_variants := to_bounded_string( compose(
							containing_directory => name_directory_cad, 
							name => simple_name(to_string(name_file_cad_netlist)),
							extension => file_extension_assembly_variants));

			if not exists(to_string(name_file_list_of_assembly_variants)) then -- create file_list_of_assembly_variants anew

				write_message(
					file_handle => file_import_cad_messages,
					text => "creating list of assembly variants in " & to_string(name_file_list_of_assembly_variants),
					console => false,
					identation => 1);

				create (file_variants, out_file, to_string(name_file_list_of_assembly_variants));
				
				put_line(file_variants," -- assembly variants of netlist '" & simple_name(to_string(name_file_cad_netlist)) & "'");
				put_line(file_variants," -- created by impprotel version " & version);
				put_line(file_variants," -- date " & date_now);
				put_line(file_variants,row_separator_0 & column_separator_0);
				put_line(file_variants," -- Mark variants as active by writing the word '" 
					& keyword_assembly_variant_active & "' in the last column !");
				put_line(file_variants," -- NOTE: Only one variant of a device can be active !");
				new_line(file_variants);
				put_line(file_variants," -- device name | value | package | [" & keyword_assembly_variant_active & "]");

				-- write assembly variants in file_list_of_assembly_variants 
				for d in 1..length_list_of_devices loop
					device_scratch := element(list_of_devices_with_variants, d);
					if device_scratch.has_variants then

						put_line(file_variants, 2 * row_separator_0
							& to_string(device_scratch.name) & row_separator_0 
							& to_string(device_scratch.value) & row_separator_0 
							& to_string(device_scratch.packge));
						
						write_message(file_handle => file_import_cad_messages, 
							text => to_string(device_scratch.name) & row_separator_0 &
									to_string(device_scratch.value) & row_separator_0 &
									to_string(device_scratch.packge),
							console => false, 
							identation => 3);

					end if;
				end loop;
				put_line(file_variants," -- end of variants");
				close(file_variants);

				put_line("IMPORTANT: Mark active assembly variants in " 
					& to_string(name_file_list_of_assembly_variants) & " !");
				put_line("           Then run the import again !");

				list_of_variants_created := true; -- This means to skip writing the skeleton and exit prematurely.
				
			else -- file_list_of_assembly_variants exists, so read it and apply active assembly variants

				write_message(
					file_handle => file_import_cad_messages,
					text => "applying active assembly variants from " & to_string(name_file_list_of_assembly_variants),
					console => true,
					identation => 1);
				
				read_assembly_variants; -- read them from file_list_of_assembly_variants in list_of_assembly_variants
				-- CS: check assembly variants (make sure only one of them is active)
				-- CS: check if assembly variants are valid (devices, packages, values exist in netlist)
				set_position_of_variants; -- set position of assembly variants (as found in list_of_assembly_variants)
				apply_assembly_variants_on_device_list; -- mark mounted devices
				apply_assembly_variants_on_netlist; -- mark mounted pins 
			end if;	

		else -- no variants found
			-- All devices are mounted. All pins are "mounted".
			write_message(
				 file_handle => file_import_cad_messages,
				 text => "design has no assembly variants -> all devices mounted !",
				 console => true,
				 identation => 1);

			mark_all_devices_as_mounted;
			mark_all_pins_as_mounted;
		end if;
    end manage_assembly_variants;


	procedure read_netlist is
	-- Appends devices to list_of_devices (even multiple occurences which are assembly variants).
	-- Appends nets to list_of_nets. Each net has a list of pins.
		pin_scratch		: type_pin_of_variant;
		device_entered	: boolean := false;
		device_scratch	: type_device_with_variants;

	    type type_device_attribute is (name, packge, value);
		device_attribute_next : type_device_attribute;

		net_entered : boolean := false;
		net_scratch : m1_import.type_net_with_variants;
		
		type type_net_item is (name, pin);
		net_item_next : type_net_item;
		
	begin
		write_message (
			file_handle => file_import_cad_messages,
			text => "reading protel netlist file ...",
			console => true);

		open (file => file_cad_netlist, mode => in_file, name => to_string(name_file_cad_netlist));
		set_input(file_cad_netlist);

		while not end_of_file loop
			line_counter := line_counter + 1;
			line := to_bounded_string(get_line);
			if get_field_count(to_string(line)) > 0 then -- skip empty lines
				
				-- READ DEVICES (NAME, PACKAGE, VALUE)
-- 				write_message (
-- 					file_handle => file_import_cad_messages,
-- 					identation => 1,
-- 					text => "reading devices:",
-- 					console => true);

				if not device_entered then
					if get_field_from_line(text_in => to_string(line), position => 1) = "[" then
						device_entered := true;
						device_attribute_next := name;
					end if;
				else -- we are inside a device section
					if get_field_from_line(text_in => to_string(line), position => 1) = "]" then
						device_entered := false; -- we are leaving a device section

						write_message (
							file_handle => file_import_cad_messages,
							identation => 1,
							text => "device " & to_string(device_scratch.name)
								& " value " & to_string(device_scratch.value)
								& " package " & to_string(device_scratch.packge),
							console => false);

						-- add device to list_of_devices (even if it occurs more than once, which indicates an assembly variant)
						append(list_of_devices_with_variants, device_scratch); 

						-- purge device contents for next spin
						device_scratch.name := to_bounded_string(""); 
						device_scratch.packge := to_bounded_string("");
						device_scratch.value := to_bounded_string("");
					else
						case device_attribute_next is
							when name => 
								device_scratch.name := to_bounded_string(
									get_field_from_line(text_in => to_string(line), position => 1));
								device_attribute_next := packge;
							when packge =>
								device_scratch.packge := to_bounded_string(
									get_field_from_line(text_in => to_string(line), position => 1));
								device_attribute_next := value;
							when value =>
								device_scratch.value := to_bounded_string(
									get_field_from_line(text_in => to_string(line), position => 1));                        
						end case;
					end if;
				end if;

				-- READ NETS (NAME, PINS)
				if not net_entered then
					if get_field_from_line(text_in => to_string(line), position => 1) = "(" then
						net_entered := true;
						net_item_next := name;
					end if;
				else -- we are inside a net section
					if get_field_from_line(text_in => to_string(line), position => 1) = ")" then
						net_entered := false; -- we are leaving a net section

						write_message (
							file_handle => file_import_cad_messages,
							identation => 1,
							text => "net " & to_string(net_scratch.name)
								& " with:",
							console => false);

						-- If net has pins, write them in logfile. Otherwise write warning.
						if length(net_scratch.pins) > 0 then
							for i in 1..length(net_scratch.pins) loop
								write_message (
									file_handle => file_import_cad_messages,
									identation => 2,
									text => "device " & to_string(element(net_scratch.pins, positive(i)).name_device)
										& " pin " & to_string(element(net_scratch.pins, positive(i)).name_pin),
									console => false);
							end loop;
						else
							write_message (
								file_handle => file_import_cad_messages,
								identation => 1,
								text => message_warning & "net " & to_string(net_scratch.name)
									& " has no pins/pads connected !",
								console => false);
						end if;
						
						append(list_of_nets_with_variants, net_scratch); -- add net to list

						-- purge net contents for next spin
						net_scratch.name := to_bounded_string(""); -- clear name
						delete(net_scratch.pins,1,length(net_scratch.pins)); -- clear pin list
					else
						case net_item_next is
							when name => -- read net name from a line like "motor_on"
								net_scratch.name := to_bounded_string(
									get_field_from_line(text_in => to_string(line), position => 1));                        
								net_item_next := pin;
							when pin => -- read pin nme from a line like "C37-2"
								pin_scratch := split_device_pin(line); --to_bounded_string(get_field(text_in => to_string(line), position => 1)));
								append(net_scratch.pins, pin_scratch);
						end case;
					end if;
				end if;
			end if;
		end loop;
		set_input(standard_input);
		close(file_cad_netlist);

-- 		write_message (
-- 			file_handle => file_import_cad_messages,
-- 			text => message_error & "in netlist line" & natural'image(line_counter),
-- 			console => true);

	end read_netlist;

	procedure make_device_map is
	-- Copies mounted devices from list_of_devices to map_of_devices.
		device : type_device_with_variants;
	begin
		put_line(" making device map ...");
		if length(list_of_devices_with_variants) > 0 then -- we do that if there a devices at all
			for i in 1..positive(length(list_of_devices_with_variants)) loop
				device := element(list_of_devices_with_variants, i);
				if device.mounted then
					insert(
						container	=> map_of_devices, 
						key			=> device.name, 
						new_item	=> ( packge => device.packge, value => device.value)
						);
				end if;
			end loop;
		end if;
	end make_device_map;

	procedure make_net_map is
	-- Copies nets with mounted pins from list_of_nets to map_of_regular_nets.
		net_in : m1_import.type_net_with_variants;
		pin_in : m1_import.type_pin_of_variant;

		net_out : m1_import.type_net;
		
	begin
		put_line(" making net map ...");	
		if length(list_of_nets_with_variants) > 0 then -- we do that if there are nets at all
			for i in 1..positive(length(list_of_nets_with_variants)) loop
				net_in := element(list_of_nets_with_variants, i); -- load a net from list_of_nets

				-- copy mounted pins:
				if length(net_in.pins) > 0 then -- if the net has pins at all
					for k in 1..positive(length(net_in.pins)) loop
						pin_in := element(net_in.pins, k); -- load a pin of net from list_of_nets
						if pin_in.mounted then -- if the pin belongs to a mounted device
							append( -- build a new pin and append it to the pinlist of net_b
								container	=> net_out.pins,
								new_item	=> (
									name_device	=> pin_in.name_device,
									name_pin 	=> pin_in.name_pin
									));

							-- count pins for statistics
							pin_count := pin_count + 1;
						end if;
					end loop;
				end if;

				-- insert the new net_out in map_of_regular_nets
				insert(
					container	=> map_of_nets,
					key 		=> net_in.name,
					new_item	=> net_out
					);

				-- clear pinlist of net_out for next spin
				net_out.pins := m1_import.type_list_of_pins.empty_vector;
			end loop;
		end if;
	end make_net_map;
	
-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := import_cad;

	-- create message/log file	
	format_cad := protel;
	write_log_header(version);
	
	put_line(to_upper(name_module_cad_importer_protel) & " version " & version);
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

	prog_position	:= 60;	
    manage_assembly_variants;

	-- If a list of assembly variants has been created, we remove the stale (and confusing) skeleton.
	-- If there was a list already, we create a new skeleton.
	prog_position	:= 70;	
	if list_of_variants_created then

		-- depending on the cad_import_target_module delete the skeleton of main or submodule
		case cad_import_target_module is
			when m1_import.main =>
				prog_position	:= 80;
				if exists(name_file_skeleton) then

					write_message (
						file_handle => file_import_cad_messages,
						text => "deleting stale " & name_file_skeleton & " ...",
						console => true);

					delete_file(name_file_skeleton);
				end if;

			when m1_import.sub =>
				prog_position	:= 85;
				if exists(to_string(name_file_skeleton_submodule)) then

					write_message (
						file_handle => file_import_cad_messages,
						text => "deleting stale " & to_string(name_file_skeleton_submodule) & " ...",
						console => true);
					
					delete_file(to_string(name_file_skeleton_submodule));
				end if;
		end case;
				
		set_exit_status(failure);
	else
		prog_position	:= 90;

		-- prepare writing skeleton:
		make_device_map; 
		make_net_map;
		
		write_skeleton (
			module_name => name_module_cad_importer_protel,
			module_version => version
			);
	end if;

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
end impprotel;
