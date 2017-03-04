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
--with Ada.Strings.fixed; 		use Ada.Strings.fixed;
with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.exceptions; 			use ada.exceptions;
--  
with ada.command_line;			use ada.command_line;
-- with ada.directories;			use ada.directories;

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


    procedure test_assembly_variants is
    begin
        if length(list_of_devices) > 0 then
            for d in 1..length(list_of_devices) loop
                null;
            end loop;
        else
            put_line(message_warning & "no devices found !");
        end if;
    end test_assembly_variants;
    
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

    open (file => file_cad_net_list, mode => in_file, name => universal_string_type.to_string(name_file_cad_net_list));
    set_input(file_cad_net_list);
    while not end_of_file loop
        line_counter := line_counter + 1;
        line := to_bounded_string(get_line);
        if get_field_count(to_string(line)) > 0 then -- skip empty lines
            --put_line("line:>" & to_string(line) & "<");
            
            -- READ DEVICES (NAME, PACKAGE, VALUE)
            if not device_entered then
                --put_line(to_string(line));
                if get_field(text_in => to_string(line), position => 1) = "[" then
                    --put_line("entering device...");
                    device_entered := true;
                    device_attribute_next := name;
                end if;
            else -- we are inside a device section
                put_line(to_string(line));
                if get_field(text_in => to_string(line), position => 1) = "]" then
                    device_entered := false; -- we are leaving a device section
                    put_line(to_string("device: " & device_scratch.name));
                    append(list_of_devices,device_scratch); -- add device to list

                    -- purge device contents for next spin
                    device_scratch.name := to_bounded_string(""); 
                    device_scratch.packge := to_bounded_string("");
                    device_scratch.value := to_bounded_string("");
                else
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
                if get_field(text_in => to_string(line), position => 1) = "(" then
                    net_entered := true;
                    net_item_next := name;
                end if;
            else -- we are inside a net section
                if get_field(text_in => to_string(line), position => 1) = ")" then
                    net_entered := false; -- we are leaving a net section
                    put_line(to_string("net: " & net_scratch.name));
                    type_list_of_nets.append(list_of_nets,net_scratch); -- add net to list

                    -- purge net contents for next spin
                    net_scratch.name := to_bounded_string(""); -- clear name
                    type_list_of_pins.delete(net_scratch.pins,1,type_list_of_pins.length(net_scratch.pins)); -- clear pin list
                else
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

    test_assembly_variants;
    
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
			end case;
end impprotel;
