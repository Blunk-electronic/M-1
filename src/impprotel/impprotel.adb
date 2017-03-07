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
--with Ada.Strings.fixed; 		use Ada.Strings.fixed;
with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.exceptions; 			use ada.exceptions;
--  
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

--with m1;
with m1_internal;               use m1_internal;
with m1_numbers;                use m1_numbers;
with m1_files_and_directories;  use m1_files_and_directories;

procedure impprotel is

	version			: String (1..3) := "002";
    prog_position	: natural := 0;

    length_of_line_in_netlist : constant positive := 200;
    package type_line is new generic_bounded_length(length_of_line_in_netlist);
    use type_line;
    line_counter : natural := 0;
    line : type_line.bounded_string;

    -- DEVICES
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
		--		number_of_variants	: positive := 1;
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
    length_of_pin_name : constant positive := length_of_device_name + 10; -- something like R41-1
    package type_pin_name is new generic_bounded_length(length_of_pin_name);
    use type_pin_name;
    package type_list_of_pins is new vectors ( index_type => positive, element_type => type_pin_name.bounded_string);

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

    net_entered : boolean := false;
    net_scratch : type_net;
    type type_net_item is (name, pin);
    net_item_next : type_net_item;

	-- ASSEMBLY VARIANTS
	type type_assembly_variant is record
		name		: type_device_name.bounded_string;
		id			: positive;
		packge		: type_package_name.bounded_string;
		value		: type_value.bounded_string; -- CS: package and value should be read and verified
		active		: boolean := false;
		processed	: boolean := false;
	end record;

	package type_list_of_assembly_variants is new vectors (positive, type_assembly_variant);
	use type_list_of_assembly_variants;
	list_of_assembly_variants : type_list_of_assembly_variants.vector;
		

	procedure manage_assembly_variants is
		l : natural := natural(length(list_of_devices));
--		np : type_device_name.bounded_string;
		variants_found : boolean := false;
		file_variants : ada.text_io.file_type;
		file_list_of_assembly_variants : unbounded_string;
		package type_pin_name is new generic_bounded_length(length_of_pin_name);
		use type_pin_name;
		package type_list_of_pins is new vectors ( index_type => positive, element_type => type_pin_name.bounded_string);
		
		procedure read_assembly_variants is
		-- reads assembly variants in a list
			--package type_line_of_assembly_variants is new generic_bounded_length(300); use type_line_of_assembly_variants;
			line_counter : natural := 0;
			line : extended_string.bounded_string;
			assembly_variant_scratch : type_assembly_variant;
		begin
			open (file_variants, in_file, to_string(file_list_of_assembly_variants));
			set_input(file_variants);
			while not end_of_file loop
				line := extended_string.to_bounded_string(get_line);
				line := remove_comment_from_line(line);
				if get_field_count(extended_string.to_string(line)) > 0 then -- skip empty lines

					-- read assembly variant from a line like "R3 RESC1005X40N 12K active"
					assembly_variant_scratch.name := to_bounded_string(get_field(extended_string.to_string(line),1));
					assembly_variant_scratch.packge := to_bounded_string(get_field(extended_string.to_string(line),2));
					assembly_variant_scratch.value := to_bounded_string(get_field(extended_string.to_string(line),3));
					if get_field(extended_string.to_string(line),4) = "active" then -- CS: output error when typing error ?
						assembly_variant_scratch.active := true;
					else
						assembly_variant_scratch.active := false;
					end if;

					-- append assembly variant to list
					append(list_of_assembly_variants,assembly_variant_scratch);

					-- purge temporarly assembly variant
					assembly_variant_scratch.name := to_bounded_string("");
					assembly_variant_scratch.packge := to_bounded_string("");					
					assembly_variant_scratch.value := to_bounded_string("");					
				end if;
			end loop;
			set_input(standard_input);
			close(file_variants);
		end read_assembly_variants;

		procedure get_position_of_active_variants is
		-- assigns an active assembly variant the posittion 
			l : natural := natural(length(list_of_assembly_variants));
			vp, vs : type_assembly_variant;
			p : positive := 1; -- position of variant

			procedure mark_variant_as_processed (variant : in out type_assembly_variant) is
			begin variant.processed := true; end mark_variant_as_processed;

			procedure set_position (variant : in out type_assembly_variant) is
			begin variant.id := p; end set_position;

			procedure write_assembly_variant (variant : in type_assembly_variant) is
			begin
				put_line(file_skeleton, " " & natural'image(p) & " " & to_string(variant.name) &
					" " & to_string(variant.packge) & " " & to_string(variant.value));
			end write_assembly_variant;
			
		begin -- get_position_of_active_variants
			put_line(file_skeleton, " active variants: ");
			put_line(file_skeleton, "  pos. | device | package | value");
			put_line(file_skeleton, "  " & column_separator_0);
			for ap in 1..l loop
				vp := element(list_of_assembly_variants,ap); -- first occurence
				p := 1; -- reset position
				if not vp.processed then -- skip already processed variants
					if vp.active then -- if first variant active, set position as proposed by p
						update_element(list_of_assembly_variants,ap,set_position'access);
						write_assembly_variant(vp);
						for as in ap+1..l loop -- serach for further occurences and mark them as processed
							vs := element(list_of_assembly_variants,as);
							if vp.name = vs.name then -- on name match
								-- mark this variant as processed
								update_element(list_of_assembly_variants,as,mark_variant_as_processed'access);
							end if;
						end loop;
					else -- first variant not active
						for as in ap+1..l loop -- serach for further occurences
							vs := element(list_of_assembly_variants,as);
							if vp.name = vs.name then -- on name match
								p := p + 1; -- increment position on match
								if vs.active then -- if variant active, set position as proposed by p
									update_element(list_of_assembly_variants,as,set_position'access);
									write_assembly_variant(vs);
								end if;
								-- mark this variant and all others as processed
								update_element(list_of_assembly_variants,as,mark_variant_as_processed'access);
							end if;
						end loop;
					end if;
				end if;
			end loop;
		end get_position_of_active_variants;

		procedure apply_assembly_variants is
			la : positive := natural(length(list_of_assembly_variants));
			active_variant_found : boolean := false;
			v : type_assembly_variant;
			device_scratch : type_device;

			procedure mark_device_as_mounted (device : in out type_device) is
			begin device.mounted := true; end mark_device_as_mounted;
			
		begin 
			for d in 1..l loop -- loop in device list
				device_scratch := element(list_of_devices,d); -- save element temporarly in device_scratch
				if device_scratch.has_variants then -- if device has variants, search in variants list for that device

					-- search current device in variant list
					for a in 1..la loop
						v := element(list_of_assembly_variants,a); -- save current variant temporarly in v

						-- if variant matches in device name, package, value, id and if it is active, 
						-- then the active assembly variant has been found -> the devive is to be mounted
						if  to_string(device_scratch.name)   = to_string(v.name) and 
							to_string(device_scratch.packge) = to_string(v.packge) and
							to_string(device_scratch.value)  = to_string(v.value) and
							device_scratch.variant_id = v.id and
							v.active then -- active variant found, abort search (there is only one active variant)
								active_variant_found := true;
								-- put_line(file_skeleton,to_string(device_scratch.name)); -- dbg
								update_element(list_of_devices,d,mark_device_as_mounted'access);
								exit;
						end if;
					end loop;
					if not active_variant_found then
						put_line(standard_output,message_error & "No active variant found for device '" & 
							type_device_name.to_string(device_scratch.name) & "' !");
						raise constraint_error;
					end if;
				else
					-- no variants, device is to be mounted
					update_element(list_of_devices,d,mark_device_as_mounted'access);
				end if;
			end loop;
		end apply_assembly_variants;


		procedure mark_as_having_variants (device : in out type_device) is
		begin device.has_variants := true; end mark_as_having_variants;
		
		procedure mark_as_processed (device : in out type_device) is
		begin device.processed := true; end mark_as_processed;

		variant_id : positive := 1;		
		procedure set_variant_id ( device : in out type_device) is
		begin device.variant_id := variant_id; end set_variant_id;

		device_scratch : type_device;

		
	begin -- manage_assembly_variants
		-- Search in device list for multiple occurences. If a device occurs more than once, it has variants.
		-- If there are variants: Write them in a file_list_of_assembly_variants. If file_list_of_assembly_variants already
		-- exists, read its content.
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
			write_message(
				file_handle => file_skeleton, text => message_warning & " no devices found !", console => true, identation => 1);
		end if;

		if variants_found then
			write_message(
				 file_handle => file_skeleton, text => message_warning & "Design has assembly variants:", console => true, identation => 1);

			-- build the name of file_list_of_assembly_variants from the given netlist file
			file_list_of_assembly_variants := to_unbounded_string( compose(
							containing_directory => name_directory_cad, 
							name => simple_name(universal_string_type.to_string(name_file_cad_net_list)),
							extension => file_extension_assembly_variants));

			if not exists(to_string(file_list_of_assembly_variants)) then -- create file_list_of_assembly_variants anew
				put_line(standard_output,"Creating list of assembly variants in " & to_string(file_list_of_assembly_variants));
				create (file_variants, out_file, to_string(file_list_of_assembly_variants));
				
				put_line(file_variants," -- assembly variants of netlist '" & simple_name(universal_string_type.to_string(name_file_cad_net_list)) & "'");
				put_line(file_variants," -- created by impprotel version " & version);
				put_line(file_variants," -- date " & date_now);
				put_line(file_variants," " & column_separator_0);
				put_line(file_variants," -- device name | package | value");

				-- write assembly variants both in the skeleton and in file_list_of_assembly_variants 
				for d in 1..l loop
					device_scratch := element(list_of_devices,d);
					if device_scratch.has_variants then
						write_message(file_handle => file_skeleton, 
							text => "device: " & to_string(device_scratch.name) &
									" package: " & to_string(device_scratch.packge) &
									" value: " & to_string(device_scratch.value),
							console => true, identation => 2);

						write_message(file_handle => file_variants, 
							text => to_string(device_scratch.name) & " " &
									to_string(device_scratch.packge) & " " &
									to_string(device_scratch.value),
							console => false, identation => 2);
					end if;
				end loop;
				put_line(file_variants," -- end of variants");
				close(file_variants);
			else -- file_list_of_assembly_variants exists, so read it and apply active assembly variants
				put_line(standard_output,"Applying active assembly variants from " & to_string(file_list_of_assembly_variants));
				write_message(
					file_handle => file_skeleton, text => "as specified in file " & to_string(file_list_of_assembly_variants), identation => 1);

				read_assembly_variants; -- read them from file_list_of_assembly_variants
				get_position_of_active_variants; -- set id in assembly variant
				apply_assembly_variants; -- mark mounted devices
			end if;	
		end if;
    end manage_assembly_variants;


	procedure write_skeleton is
	begin
		set_output(file_skeleton);
		
	end write_skeleton;
	
-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	new_line;
	put_line("PROTEL CAD IMPORTER VERSION "& version);
	put_line("======================================");

	prog_position	:= 10;
 	name_file_cad_net_list:= universal_string_type.to_bounded_string(argument(1));
 	put_line("netlist      : " & universal_string_type.to_string(name_file_cad_net_list));

	prog_position	:= 30;
	if argument_count = 2 then
		debug_level := natural'value(argument(2));
		put_line("debug level    :" & natural'image(debug_level));
	end if;

	prog_position	:= 40;

	create (file => file_skeleton, mode => out_file, name => name_file_skeleton);
	set_output(file_skeleton);
	put_line(section_mark.section & " info");
	put_line(" -- netlist skeleton");
	put_line(" -- created by impprotel version " & version);
	put_line(" -- date " & date_now);
	put_line(row_separator_0);
	set_output(standard_output);

    open (file => file_cad_net_list, mode => in_file, name => universal_string_type.to_string(name_file_cad_net_list));
    set_input(file_cad_net_list);
    while not end_of_file loop
        line_counter := line_counter + 1;
        line := to_bounded_string(get_line);
        if get_field_count(to_string(line)) > 0 then -- skip empty lines
            --put_line("line:>" & to_string(line) & "<");
            
            -- READ DEVICES (NAME, PACKAGE, VALUE)
			if not device_entered then
				prog_position	:= 70;
                --put_line(to_string(line)); -- dbg
                if get_field(text_in => to_string(line), position => 1) = "[" then
                    --put_line("entering device...");
                    device_entered := true;
                    device_attribute_next := name;
                end if;
            else -- we are inside a device section
                --put_line(to_string(line));
				if get_field(text_in => to_string(line), position => 1) = "]" then
					prog_position	:= 50;
                    device_entered := false; -- we are leaving a device section
                    --put_line("device: " & to_string(device_scratch.name)); -- dbg
                    append(list_of_devices,device_scratch); -- add device to list

                    -- purge device contents for next spin
                    device_scratch.name := to_bounded_string(""); 
                    device_scratch.packge := to_bounded_string("");
                    device_scratch.value := to_bounded_string("");
				else
					prog_position	:= 60;
                    case device_attribute_next is
                        when name => 
                            device_scratch.name := to_bounded_string(get_field(text_in => to_string(line), position => 1));
                            device_attribute_next := packge;
                        when packge =>
                            device_scratch.packge := to_bounded_string(get_field(text_in => to_string(line), position => 1));
                            device_attribute_next := value;
                        when value =>
                            device_scratch.value := to_bounded_string(get_field(text_in => to_string(line), position => 1));                        
                    end case;
                end if;
            end if;

            -- READ NETS (NAME, PINS)
			if not net_entered then
				prog_position	:= 80;
                if get_field(text_in => to_string(line), position => 1) = "(" then
                    net_entered := true;
                    net_item_next := name;
                end if;
			else -- we are inside a net section
				prog_position	:= 90;				
                if get_field(text_in => to_string(line), position => 1) = ")" then
                    net_entered := false; -- we are leaving a net section
                    --put_line("net: " & to_string(net_scratch.name)); -- dbg
                    type_list_of_nets.append(list_of_nets,net_scratch); -- add net to list

                    -- purge net contents for next spin
                    net_scratch.name := to_bounded_string(""); -- clear name
                    type_list_of_pins.delete(net_scratch.pins,1,type_list_of_pins.length(net_scratch.pins)); -- clear pin list
				else
					prog_position	:= 100;
                    case net_item_next is
                        when name => 
                            net_scratch.name := to_bounded_string(get_field(text_in => to_string(line), position => 1));                        
                        when pin =>
                            type_list_of_pins.append(net_scratch.pins, to_bounded_string(get_field(text_in => to_string(line), position => 1)));
                    end case;
                end if;
            end if;
        end if;
    end loop;
	set_input(standard_input);
	close(file_cad_net_list);

    manage_assembly_variants;

--	set_output(file_skeleton);
	put_line(file_skeleton,section_mark.endsection);

	-- write section netlist_skeleton
	write_skeleton;

	close(file_skeleton);
	
	
	exception
-- 		when constraint_error => 

		when event: others =>
			set_exit_status(failure);
			case prog_position is
-- 				when 10 =>
-- 					put_line(message_error & "ERROR: Data base file missing or insufficient access rights !");
-- 					put_line("       Provide data base name as argument. Example: mkinfra my_uut.udb");
-- 				when 20 =>
-- 					put_line("ERROR: Test name missing !");
-- 					put_line("       Provide test name as argument ! Example: mkinfra my_uut.udb my_infrastructure_test");
-- 				when 30 =>
-- 					put_line("ERROR: Invalid argument for debug level. Debug level must be provided as natural number !");


				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & natural'image(prog_position));
					put_line("line in netlist" & natural'image(line_counter));
			end case;
end impprotel;
