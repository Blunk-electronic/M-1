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


with ada.text_io;				use ada.text_io;
-- with Ada.Integer_Text_IO;		use Ada.Integer_Text_IO;
-- with Ada.Characters.Handling; 	use Ada.Characters.Handling;

with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.unbounded;		use ada.strings.unbounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.exceptions; 			use ada.exceptions;
--  
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_base;					use m1_base;
with m1_import;					use m1_import;
with m1_database;               use m1_database;
with m1_numbers;                use m1_numbers;
with m1_files_and_directories;  use m1_files_and_directories;
with m1_string_processing;		use m1_string_processing;

procedure impprotel is

	version			: constant string (1..3) := "003";
    prog_position	: natural := 0;

    length_of_line_in_netlist : constant positive := 200;
    package type_line is new generic_bounded_length(length_of_line_in_netlist);
    use type_line;
    line_counter : natural := 0;
    line : type_line.bounded_string;

	use type_extended_string;
	use type_universal_string;
	use type_name_file_netlist;
	
	-- DEVICES
	device_count_mounted : natural := 0; -- for statistics
	
    length_of_device_name : constant positive := 10;
    package type_device_name is new generic_bounded_length(length_of_device_name);
    use type_device_name;

    length_of_package_name : constant positive := 100;
    package type_package_name is new generic_bounded_length(length_of_package_name);
    use type_package_name;

    length_of_value : constant positive := 100;
    package type_value is new generic_bounded_length(length_of_value);    
    use type_value;

    type type_device is record
        name    : type_device_name.bounded_string;
        packge  : type_package_name.bounded_string;
		value   : type_value.bounded_string;
		has_variants	: boolean := false;
		variant_id		: positive := 1;
		mounted			: boolean := false;
		processed		: boolean := false;
    end record;

    package type_list_of_devices is new vectors ( index_type => positive, element_type => type_device);
    use type_list_of_devices;
    list_of_devices : type_list_of_devices.vector;
                            
    device_entered : boolean := false;
    device_scratch : type_device;
    type type_device_attribute is (name, packge, value);
    device_attribute_next : type_device_attribute;

	-- PINS
	pin_count_mounted : natural := 0;
    length_of_pin_name : constant positive := length_of_device_name + 10; -- something like R41-1
    package type_pin_name is new generic_bounded_length(length_of_pin_name);
	use type_pin_name;
	type type_pin is record
		name_device	: type_device_name.bounded_string;
		name_pin 	: type_pin_name.bounded_string;		
		mounted 	: boolean := false;
	end record;
	pin_scratch : type_pin;
	package type_list_of_pins is new vectors ( index_type => positive, element_type => type_pin);
	use type_list_of_pins;
	
    -- NETS
    length_of_net_name : constant positive := 100;
    package type_net_name is new generic_bounded_length(length_of_net_name);
    use type_net_name;
    
    type type_net is record
        name    : type_net_name.bounded_string;
        pins    : type_list_of_pins.vector;
    end record;
    package type_list_of_nets is new vectors ( index_type => positive, element_type => type_net);
	list_of_nets : type_list_of_nets.vector;
	use type_list_of_nets;

    net_entered : boolean := false;
    net_scratch : type_net;
    type type_net_item is (name, pin);
    net_item_next : type_net_item;

	-- ASSEMBLY VARIANTS
	
	list_of_variants_created : boolean := false;
	-- Goes true if new list of assembly variants has been created.
	
	type type_assembly_variant is record
		name		: type_device_name.bounded_string;
		position	: positive := 1; -- position in file_list_of_assembly_variants
		packge		: type_package_name.bounded_string;
		value		: type_value.bounded_string; -- CS: package and value should be read and verified
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
		
		-- Once an assembly variant has been detected in the netlist, this flag goes true.
		variants_found : boolean := false; 
		
		l : natural := natural(length(list_of_devices));
		file_variants : ada.text_io.file_type;
		file_list_of_assembly_variants : unbounded_string;
		package type_pin_name is new generic_bounded_length(length_of_pin_name);
		use type_pin_name;

		procedure mark_device_as_mounted (device : in out type_device) is
		begin 
			device.mounted := true;
			device_count_mounted := device_count_mounted + 1; -- count mounted devices for statistics
		end mark_device_as_mounted;

		procedure mark_pin_as_mounted (pin : in out type_pin) is
		begin 
			pin.mounted := true; 
			pin_count_mounted := pin_count_mounted + 1; -- count pins for statistics
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
			
			open (file_variants, in_file, to_string(file_list_of_assembly_variants));
			set_input(file_variants);
			while not end_of_file loop
				line := to_bounded_string(remove_comment_from_line(get_line));
				if get_field_count(to_string(line)) > 0 then -- skip empty lines

					-- read assembly variant from a line like "R3 RESC1005X40N 12K active"
					
					assembly_variant_scratch.name := to_bounded_string(get_field_from_line(to_string(line),1));
					assembly_variant_scratch.packge := to_bounded_string(get_field_from_line(to_string(line),2));
					assembly_variant_scratch.value := to_bounded_string(get_field_from_line(to_string(line),3));
					if get_field_from_line(to_string(line),4) = keyword_assembly_variant_active then -- CS: output error when typing error ?
						assembly_variant_scratch.active := true;
					else
						assembly_variant_scratch.active := false;
					end if;

					write_message(
						file_handle => file_import_cad_messages,
						text => to_string(assembly_variant_scratch.name) & row_separator_0
							& to_string(assembly_variant_scratch.packge) & row_separator_0
							& to_string(assembly_variant_scratch.value) & row_separator_0
							& keyword_assembly_variant_active & row_separator_0 
							& boolean'image(assembly_variant_scratch.active),
						identation => 2,
						console => false);

					-- append assembly variant to list
					append(list_of_assembly_variants,assembly_variant_scratch);

					-- purge temporarly assembly variant
					assembly_variant_scratch.name := to_bounded_string("");
					assembly_variant_scratch.packge := to_bounded_string("");					
					assembly_variant_scratch.value := to_bounded_string("");
					assembly_variant_scratch.active := false; -- reset active flag for next spin
				end if;
			end loop;
			set_input(standard_input);
			close(file_variants);
		end read_assembly_variants;

		procedure get_position_of_active_variants is
		-- Assigns to active assembly variants the position where
		-- they appear in the file file_list_of_assembly_variants.
			
			l : natural := natural(length(list_of_assembly_variants));
			vp, vs : type_assembly_variant;
			p : positive := 1; -- position of variant

			procedure mark_variant_as_processed (variant : in out type_assembly_variant) is
			begin variant.processed := true; end mark_variant_as_processed;

			procedure set_position (variant : in out type_assembly_variant) is
			begin 
				variant.position := p; 

				write_message(
					file_handle => file_import_cad_messages,
					text => "active variant of " 
						& to_string(variant.name) 
						& " is number" & positive'image(p),
					identation => 2,
					console => false);

			end set_position;

			procedure write_assembly_variant (variant : in type_assembly_variant) is
			begin
				put_line(file_skeleton, row_separator_0 & natural'image(p) & row_separator_0 & to_string(variant.name) &
					row_separator_0 & to_string(variant.packge) & row_separator_0 & to_string(variant.value));
			end write_assembly_variant;
			
		begin -- get_position_of_active_variants
-- 			put_line(file_skeleton, " active variants: ");
-- 			put_line(file_skeleton, "  # | device | package | value");
-- 			put_line(file_skeleton, "  " & column_separator_0);

			write_message(
				file_handle => file_import_cad_messages,
				text => "getting position of active variants ...",
				identation => 1,
				console => false);
			
			for ap in 1..l loop -- loop in list of assembly variants
				vp := element(list_of_assembly_variants,ap); -- load variant
				if not vp.processed then
					p := 1; -- reset position
					if vp.active then

						write_message(
							file_handle => file_import_cad_messages,
							text => "first position" & positive'image(p),
							identation => 2,
							console => false);
						
						update_element(list_of_assembly_variants,ap,set_position'access);
					else
	-- 				if not vp.processed then -- skip already processed variants
	-- 					if vp.active then -- if first variant active, set position as proposed by p
	-- 						update_element(list_of_assembly_variants,ap,set_position'access);
	-- 						--write_assembly_variant(vp);
	-- 						for as in ap+1..l loop -- serach for further occurences and mark them as processed
	-- 							vs := element(list_of_assembly_variants,as);
	-- 							if vp.name = vs.name then -- on name match
	-- 								-- mark this variant as processed
	-- 								update_element(list_of_assembly_variants,as,mark_variant_as_processed'access);
	-- 							end if;
	-- 						end loop;
	-- 					else -- first variant not active
	-- 						for as in ap+1..l loop -- serach for further occurences
	-- 							vs := element(list_of_assembly_variants,as);
	-- 							if vp.name = vs.name then -- on name match
	-- 								p := p + 1; -- increment position on match
	-- 								if vs.active then -- if variant active, set position as proposed by p
	-- 									update_element(list_of_assembly_variants,as,set_position'access);
	-- 									--write_assembly_variant(vs);
	-- 								end if;
	-- 								-- mark this variant and all others as processed
	-- 								update_element(list_of_assembly_variants,as,mark_variant_as_processed'access);
	-- 							end if;
	-- 						end loop;
	-- 					end if;

						for as in ap+1..l loop -- serach for further occurences and mark them as processed
							vs := element(list_of_assembly_variants,as);
							if vp.name = vs.name then -- on name match
								p := p + 1; -- increment position on match
								update_element(list_of_assembly_variants,as,mark_variant_as_processed'access);
								if vs.active then

									write_message(
										file_handle => file_import_cad_messages,
										text => "position" & positive'image(p),
										identation => 2,
										console => false);
									
									update_element(list_of_assembly_variants,as,set_position'access);
									--exit;
								end if;
							end if;
						end loop;
						
					end if;
				end if; -- if not vp.processed
			end loop;

			
		end get_position_of_active_variants;

		procedure apply_assembly_variants_on_device_list is
		-- Sets the flag "mounted" in list_of_devices of an active assembly variant.
			la : positive := natural(length(list_of_assembly_variants));
			active_variant_found : boolean := false;
			v : type_assembly_variant;
			device_scratch : type_device;
			
		begin -- apply_assembly_variants_on_device_list
			write_message(
				file_handle => file_import_cad_messages,
				text => "applying assembly variants on device list ...",
				identation => 1,
				console => false);
			
			for d in 1..l loop -- loop in device list
				device_scratch := element(list_of_devices,d); -- save element temporarly in device_scratch
				if device_scratch.has_variants then -- if device has variants, search in variants list for that device

					write_message(
						file_handle => file_import_cad_messages,
						text => to_string(device_scratch.name),
						identation => 2,
						console => false);
					
					-- search current device in variant list
					for a in 1..la loop
						v := element(list_of_assembly_variants,a); -- save current variant temporarly in v

						write_message(
							file_handle => file_import_cad_messages,
							text => to_string(v.name) & " pos." & positive'image(v.position),
							identation => 3,
							console => false);
						
						-- if variant matches in device name, package, value, id and if it is active, 
						-- then the active assembly variant has been found -> the devive is to be mounted
						if  to_string(device_scratch.name)   = to_string(v.name) and 
							to_string(device_scratch.packge) = to_string(v.packge) and
							to_string(device_scratch.value)  = to_string(v.value) and
							device_scratch.variant_id = v.position and
							v.active then -- active variant found, abort search (there is only one active variant)
								active_variant_found := true;
								-- put_line(file_skeleton,to_string(device_scratch.name)); -- dbg
								update_element(list_of_devices,d,mark_device_as_mounted'access);
								exit;
						end if;
					end loop;

					-- safety measure;
					if not active_variant_found then
						write_message(
							file_handle => file_import_cad_messages,
							text => message_error & "No active variant found for device " 
								& to_string(device_scratch.name) & " !",
							console => true);

						raise constraint_error;
					end if;
				else
					-- no variants, device is to be mounted
					update_element(list_of_devices,d,mark_device_as_mounted'access);
				end if;
			end loop;
		end apply_assembly_variants_on_device_list;


		procedure apply_assembly_variants_on_netlist is
		-- Sets the flag "mounted" of pins.
			ln : positive := natural(length(list_of_nets));
			variant_position : natural;
			pin_occurence : positive;
			
			net_scratch : type_net;
			pin_scratch : type_pin;

			function variant_position_of (name_device : in type_device_name.bounded_string) return natural is
			-- returns the position of the active variant of the given device. if no variants, return zero.
				variant_position : natural := 0;
				device_scratch : type_device;
			begin
				for d in 1..l loop -- loop in device list
					device_scratch := element(list_of_devices,d); -- load a device
					if device_scratch.name = name_device then -- on name match
						if device_scratch.has_variants then -- if variants defined
							variant_position := device_scratch.variant_id; -- get variant id of that device
							exit; -- no more search required
						end if;
					end if;
				end loop;
				return variant_position;
			end variant_position_of;


			function pin_occurence_in_net ( net : in type_net; -- the net of interest
											pin_id : in positive; -- the position of the given pin in the pin list
											device_name_given : in type_device_name.bounded_string) -- the device of interest
			-- returns the occurence of a pin with device_name_given within the given net.
				return positive is
				occurence 				: natural := 0; -- counts the occurences of the given device
				position 				: natural := 0; -- points to the pin being processed
				lp 						: positive := positive(length(net.pins)); -- length of pin list
				device_name_scratch		: type_device_name.bounded_string;
				active_variant_found	: boolean := false; -- safety measure: used to verify that the variant has been found
			begin -- pin_occurence_in_net
				-- Loop in pin list. Advance position after fetching a pin. Search for a pin with same device
				-- further down the list. Count occurences of same device. 
				-- Abort when given pin_id reached and return occurence.
				loop_1:
				for pp in 1..lp loop -- loop in pin list of given net
					device_name_scratch := element(net.pins,pp).name_device; -- load device name of pin
					position := position + 1;					
					if device_name_scratch = device_name_given then -- first occurence of given device
--						occurence := 1;

						-- If the device is the first occurence in the pin list, abort search:
-- 						if position = pin_id then -- given pin_id reached
-- 							active_variant_found := true;
-- 							exit loop_1;
-- 						end if;
						
						-- Search down the list for further occurences of the given device name
--						for ps in pp+1..lp loop 
						for ps in pp..lp loop 						
							if element(net.pins,ps).name_device = device_name_given then -- further occurence
								occurence := occurence + 1; -- count occurences
								if position = pin_id then -- given pin_id reached
									active_variant_found := true;
									exit loop_1;
								end if;
							end if;
						end loop;
					end if;
				end loop loop_1;

				-- safety measure:
				if not active_variant_found then
	
					write_message(
						file_handle => file_import_cad_messages,
						text => message_error & "No active variant for device " 
							& to_string(device_name_given) 
							& " found in net " & to_string(net.name) & " !",
						console => true);
					
					raise constraint_error;
				end if;
				return occurence;
			end pin_occurence_in_net;

		begin -- apply_assembly_variants_on_netlist
			for n in 1..ln loop -- loop in netlist
				net_scratch := element(list_of_nets,n); -- load a net

				-- In the current net: mark device/pins to be mounted (as specified by assembly variants)
				for p in 1..length(net_scratch.pins) loop -- loop in pin list of that net
					pin_scratch := element(net_scratch.pins,positive(p)); -- load a pin
					variant_position := variant_position_of(pin_scratch.name_device); -- get active variant position of device
					if variant_position > 0 then -- device has variants
						-- now we have: a net in net_scratch, a pin id in p, device name
						-- get occurence of device with pin in that net. if it equals the variant position the pin is to be "mounted"

-- 						put_line(standard_output,"net " & to_string(net_scratch.name) &
-- 								 " dev. " & to_string(pin_scratch.name_device) &
-- 								 " pos. " & positive'image(positive(p)) &
-- 								" var. " & positive'image(variant_position));
						
						pin_occurence := pin_occurence_in_net(net_scratch, positive(p), pin_scratch.name_device); 
						if pin_occurence = variant_position then -- pin is to be "mounted"
--							put_line(standard_output,"mount");
-- 							put_line(standard_output,"net " & to_string(net_scratch.name) &
-- 									 " dev. " & to_string(pin_scratch.name_device) &
-- 									" pos. " & positive'image(positive(p)));

							
							update_element(net_scratch.pins,positive(p),mark_pin_as_mounted'access);
						end if;
						
					else -- no variants, pin is to be "mounted"
						update_element(net_scratch.pins,positive(p),mark_pin_as_mounted'access);
					end if;
				end loop;

				-- write modified net back in list_of_nets
				replace_element(list_of_nets,n,net_scratch);
			end loop;

		end apply_assembly_variants_on_netlist;
		
		procedure mark_as_having_variants (device : in out type_device) is
		begin device.has_variants := true; end mark_as_having_variants;
		
		procedure mark_as_processed (device : in out type_device) is
		begin device.processed := true; end mark_as_processed;

		variant_id : positive := 1;		
		procedure set_variant_id ( device : in out type_device) is
		begin device.variant_id := variant_id; end set_variant_id;

		device_scratch : type_device;

		procedure mark_all_devices_as_mounted is
		begin
			for i in 1..length(list_of_devices) loop
				update_element(list_of_devices, positive(i), mark_device_as_mounted'access);
			end loop;
		end mark_all_devices_as_mounted;
		
		procedure mark_all_pins_as_mounted is
			ln	: count_type := length(list_of_nets);
			lp 	: count_type;
			net	: type_net;
		begin
			for n in 1..ln loop -- loop in netlist
				net := element(list_of_nets, positive(n)); -- load a net
				lp := length( net.pins ); -- set number of pins
				if lp > 0 then -- if there are pins in the net
					
					for p in 1..lp loop -- loop in pinlist
						update_element(
							net.pins, 		-- the pinlist of the net at position n
							positive(p),	-- the pin at position p
							mark_pin_as_mounted'access);
					end loop;
					
				end if; -- if there are pins in the net
				replace_element(list_of_nets, positive(n), net);
			end loop;
		end mark_all_pins_as_mounted;
		
		
	begin -- manage_assembly_variants
		-- Search in list_of_devicest for multiple occurences. If a device occurs more than once, it has variants.
		-- If there are variants: Write them in a file_list_of_assembly_variants. If file_list_of_assembly_variants already
		-- exists, read its content.

		new_line(file_import_cad_messages);
		write_message (
			file_handle => file_import_cad_messages,
			--identation => 1,
			text => "managing assembly variants ...",
			console => true);

		-- Search for multiple occurences of devices:
		-- Sets the flag variants_found once any device occurs more than once.
        if l > 0 then -- do that if there are devices at all
			for dp in 1..l loop
				device_scratch := element(list_of_devices,dp);
				if not device_scratch.processed then -- skip already processed devices
					variant_id := 1; -- reset variant id
					update_element(list_of_devices,dp,set_variant_id'access);
					for ds in dp+1..l loop -- search for same name down the device list
						if element(list_of_devices,ds).name = device_scratch.name then
							variants_found := true;
							
							update_element(list_of_devices,dp,mark_as_having_variants'access);
							
							update_element(list_of_devices,ds,mark_as_having_variants'access);
							update_element(list_of_devices,ds,mark_as_processed'access);
							variant_id := variant_id + 1;
							update_element(list_of_devices,ds,set_variant_id'access);
						end if;
					end loop;
				end if;
            end loop;
        else
			write_message (
				file_handle => file_import_cad_messages,
				text => message_warning & " no devices found !",
				console => true,
				identation => 1);
		end if;

		if variants_found then
			write_message(
				 file_handle => file_import_cad_messages,
				 text => message_warning & "Design has assembly variants !",
				 console => true);

			-- build the name of file_list_of_assembly_variants from the given netlist file
			file_list_of_assembly_variants := to_unbounded_string( compose(
							containing_directory => name_directory_cad, 
							name => simple_name(to_string(name_file_cad_netlist)),
							extension => file_extension_assembly_variants));

			if not exists(to_string(file_list_of_assembly_variants)) then -- create file_list_of_assembly_variants anew

				write_message(
					file_handle => file_import_cad_messages,
					text => "creating list of assembly variants in " & to_string(file_list_of_assembly_variants),
					console => false,
					identation => 1);

				create (file_variants, out_file, to_string(file_list_of_assembly_variants));
				
				put_line(file_variants," -- assembly variants of netlist '" & simple_name(to_string(name_file_cad_netlist)) & "'");
				put_line(file_variants," -- created by impprotel version " & version);
				put_line(file_variants," -- date " & date_now);
				put_line(file_variants,row_separator_0 & column_separator_0);
				put_line(file_variants," -- device name | package | value | [" & keyword_assembly_variant_active & "]");

				-- write assembly variants in file_list_of_assembly_variants 
				for d in 1..l loop
					device_scratch := element(list_of_devices,d);
					if device_scratch.has_variants then
-- 						write_message(file_handle => file_skeleton, -- CS: ?
-- 							text => "device: " & to_string(device_scratch.name) &
-- 									" package: " & to_string(device_scratch.packge) &
-- 									" value: " & to_string(device_scratch.value),
-- 							console => true, identation => 2);

						put_line(file_variants, 2 * row_separator_0
							& to_string(device_scratch.name) & row_separator_0 
							& to_string(device_scratch.packge) & row_separator_0 
							& to_string(device_scratch.value));
						
						write_message(file_handle => file_import_cad_messages, 
							text => to_string(device_scratch.name) & row_separator_0 &
									to_string(device_scratch.packge) & row_separator_0 &
									to_string(device_scratch.value),
							console => false, 
							identation => 3);

					end if;
				end loop;
				put_line(file_variants," -- end of variants");
				close(file_variants);

				put_line("IMPORTANT: Mark active assembly variants in " & to_string(file_list_of_assembly_variants) & " !");
				put_line("           Then run the import again !");

				list_of_variants_created := true; -- This means to skip writing the skeleton and exit prematurely.
				
			else -- file_list_of_assembly_variants exists, so read it and apply active assembly variants

				write_message(
					file_handle => file_import_cad_messages,
					text => "applying active assembly variants from " & to_string(file_list_of_assembly_variants),
					console => true,
					identation => 1);
				
-- 				write_message( -- CS: ?
-- 					file_handle => file_skeleton, text => "as specified in file " & to_string(file_list_of_assembly_variants), identation => 1);

				read_assembly_variants; -- read them from file_list_of_assembly_variants
				-- CS: check assembly variants (make sure only one of them is active)
				get_position_of_active_variants; -- set id in assembly variant
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

	function split_device_pin (text_in : type_line.bounded_string) return type_pin is
		pin : type_pin;
		ifs_position : positive := index(text_in,"-");
	begin
 		pin.name_device := to_bounded_string(slice(text_in,1,ifs_position-1));
		pin.name_pin    := to_bounded_string(slice(text_in,ifs_position+1,length(text_in)));
		--put_line(standard_output,"device: " & to_string(pin.name_device) & " pin " & to_string(pin.name_pin));
		return pin;
	end split_device_pin;


	procedure write_statistics is
	begin
		new_line(file_import_cad_messages);		
		write_message (
			file_handle => file_import_cad_messages,
			text => "writing statistics ...",
			console => true);

		put_line(file_skeleton, " statistics:");

		-- The device_count_mounted was computed when a device was marked as "mounted" 
		-- by procedure mark_device_as_mounted.
		put_line(file_skeleton, "  devices :" & natural'image(device_count_mounted));

		-- The number of nets can be taken directly from the list_of_nets.
		put_line(file_skeleton, "  nets    :" & count_type'image(length(list_of_nets)));

		-- The pin_count_mounted was computed when a pin was marked as "mounted"
		-- by procdure mark_pin_as_mounted.
		put_line(file_skeleton, "  pins    :" & natural'image(pin_count_mounted));
		
-- 		put_line(file_skeleton,section_mark.endsection);		
	end write_statistics;

	procedure write_info is
	begin
-- 		set_output(file_skeleton);

		new_line(file_import_cad_messages);
		write_message (
			file_handle => file_import_cad_messages,
			text => "writing info section ...",
			console => false);
		
		put_line(section_mark.section & row_separator_0 & text_skeleton_section_info);
-- 		put_line(" netlist skeleton");
		put_line(" created by " & name_module_cad_importer_protel & " version " & version);
		put_line(" date " & date_now);

		write_statistics;
		
		put_line(file_skeleton,section_mark.endsection);
-- 		set_output(standard_output);
	end write_info;
	
	procedure write_skeleton is
	-- Writes the skeleton file from the list_of_nets.
	-- Reads the global flag variants_found in order to care for the "mounted" flag of pins or not.
		net : type_net;
		pin : type_pin;
		ld 	: natural := natural(length(list_of_devices));
		
		function get_value_and_package(device : in type_device_name.bounded_string) return string is
		-- returns value and package of a given device
			device_scratch : type_device;
		begin
			for d in 1..ld loop
				device_scratch := element(list_of_devices,positive(d));
				if device_scratch.name = device then
					if device_scratch.mounted then
						exit;
					end if;
				end if;
			end loop;
			
			return to_string(device_scratch.value) & row_separator_0 & to_string(device_scratch.packge);
		end get_value_and_package;
		
	begin -- write_skeleton
		new_line(file_import_cad_messages);

		-- The skeleton file is named with the standard name or
		-- with the standard name + prefix:
		case cad_import_target_module is
			when main => 
				write_message (
					file_handle => file_import_cad_messages,
					text => "creating skeleton for main module ...",
					console => false);

				create (file => file_skeleton, mode => out_file, name => name_file_skeleton);

			when sub => 
				write_message (
					file_handle => file_import_cad_messages,
					text => "creating skeleton for submodule " & to_string(target_module_prefix) & " ...",
					console => false);

				target_module_prefix := to_bounded_string(argument(3));
				put_line("prefix        : " & to_string(target_module_prefix));
				create (file => file_skeleton, mode => out_file, name => compose( 
							name => base_name(name_file_skeleton) & "_" & 
									to_string(target_module_prefix),
							extension => file_extension_text)
						);
		end case;

		write_message (
			file_handle => file_import_cad_messages,
			text => "writing skeleton ...",
			console => true);

		set_output(file_skeleton);
		
		write_info;
		
		new_line;
		put_line(section_mark.section & row_separator_0 & text_skeleton_section_netlist); new_line;
		
		for n in 1..length(list_of_nets) loop
			net := element(list_of_nets, positive(n)); -- load a net

			write_message (
				file_handle => file_import_cad_messages,
				text => "net " & to_string(net.name),
				identation => 1,
				console => false);
			
			-- write net header like "SubSection CORE_EXT_SRST class NA"
			put_line(row_separator_0 & section_mark.subsection & row_separator_0 & to_string(net.name) & row_separator_0 &
				netlist_keyword_header_class & row_separator_0 & type_net_class'image(net_class_default));

			-- write pins in lines like "R3 ? 270K RESC1005X40N 1"
			for p in 1..length(net.pins) loop
				pin := element(net.pins, positive(p)); -- load a pin

				if pin.mounted then -- address only active assembly variants
					-- CS: write a procedure for this in m1_import:
					put_line("  " & to_string(pin.name_device) 
						& row_separator_0 & type_device_class'image(device_class_default) 
						& row_separator_0 & get_value_and_package(pin.name_device) 
						& row_separator_0 & to_string(pin.name_pin)
						);
				end if;
			end loop;

			put_line(row_separator_0 & section_mark.endsubsection); new_line;
		end loop;
		
		put_line(section_mark.endsection);
		set_output(standard_output);
		close(file_skeleton);
	end write_skeleton;

	procedure read_netlist is
	-- Appends devices to list_of_devices.
	-- Appends nets to list_of_nets. Each net has a list of pins.
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
-- 				put_line("line:>" & to_string(line) & "<");
				
				-- READ DEVICES (NAME, PACKAGE, VALUE)
-- 				write_message (
-- 					file_handle => file_import_cad_messages,
-- 					identation => 1,
-- 					text => "reading devices:",
-- 					console => true);

				if not device_entered then
					prog_position	:= 70;
					--put_line(to_string(line)); -- dbg
					if get_field_from_line(text_in => to_string(line), position => 1) = "[" then
						--put_line("entering device...");
						device_entered := true;
						device_attribute_next := name;
					end if;
				else -- we are inside a device section
					--put_line(to_string(line));
					if get_field_from_line(text_in => to_string(line), position => 1) = "]" then
						prog_position	:= 50;
						device_entered := false; -- we are leaving a device section
						--put_line("device: " & to_string(device_scratch.name)); -- dbg

						write_message (
							file_handle => file_import_cad_messages,
							identation => 1,
							text => "device " & to_string(device_scratch.name)
								& " value " & to_string(device_scratch.value)
								& " package " & to_string(device_scratch.packge),
							console => false);
						
						append(list_of_devices,device_scratch); -- add device to list

						-- purge device contents for next spin
						device_scratch.name := to_bounded_string(""); 
						device_scratch.packge := to_bounded_string("");
						device_scratch.value := to_bounded_string("");
					else
						prog_position	:= 60;
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
					prog_position	:= 80;
					if get_field_from_line(text_in => to_string(line), position => 1) = "(" then
						net_entered := true;
						net_item_next := name;
					end if;
				else -- we are inside a net section
					prog_position	:= 90;				
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
						
						append(list_of_nets,net_scratch); -- add net to list

						-- purge net contents for next spin
						net_scratch.name := to_bounded_string(""); -- clear name
						delete(net_scratch.pins,1,length(net_scratch.pins)); -- clear pin list
					else
						prog_position	:= 100;
						--put_line("line:>" & to_string(line) & "<");
						case net_item_next is
							when name => -- read net name from a line like "motor_on"
								net_scratch.name := to_bounded_string(
									get_field_from_line(text_in => to_string(line), position => 1));                        
								net_item_next := pin;
							when pin => -- read pin nme from a line like "C37-2"
								--put_line("line:>" & to_string(line) & "<"); -- dbg

								pin_scratch := split_device_pin(line); --to_bounded_string(get_field(text_in => to_string(line), position => 1)));
								append(net_scratch.pins, pin_scratch);
						end case;
					end if;
				end if;
			end if;
		end loop;
		set_input(standard_input);
		close(file_cad_netlist);
	end read_netlist;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := import_cad;
	format_cad := protel;

	new_line;
	put_line("PROTEL CAD IMPORTER VERSION "& version);
	put_line("======================================");

	prog_position	:= 10;
 	name_file_cad_netlist:= to_bounded_string(argument(1));
	put_line("netlist       : " & to_string(name_file_cad_netlist));
	cad_import_target_module := type_cad_import_target_module'value(argument(2));
	put_line("target module : " & type_cad_import_target_module'image(cad_import_target_module));
	
-- 	prog_position	:= 30;
-- 	if argument_count = 3 then
-- 		debug_level := natural'value(argument(3));
-- 		put_line("debug level    :" & natural'image(debug_level));
-- 	end if;

	prog_position	:= 40;
 	write_log_header(version);

-- 	write_info;

	read_netlist;

    manage_assembly_variants;

	-- If a list of assembly variants has been created, we remove the stale (and confusing) skeleton.
	-- If there was a list already, we create a new skeleton.
	if list_of_variants_created then
		if exists(name_file_skeleton) then
			
			write_message (
				file_handle => file_import_cad_messages,
				text => "deleting stale skeleton ...",
				console => false);

			delete_file(name_file_skeleton);
		end if;
	else
		write_skeleton;
	end if;

	
	write_log_footer;	
	
	exception when event: others =>
		set_exit_status(failure);
		set_output(standard_output);

		write_message (
			file_handle => file_import_cad_messages,
			text => message_error & " at program position " & natural'image(prog_position),
			console => true);

		write_message (
			file_handle => file_import_cad_messages,
			text => message_error & "in netlist line" & natural'image(line_counter),
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
