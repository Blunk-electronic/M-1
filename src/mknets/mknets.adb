------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKNETS                              --
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
--	 todo: send warnings in msg/mknets_warnings.txt

with ada.text_io;				use ada.text_io;
with ada.characters.handling;   use ada.characters.handling;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.strings; 				use ada.strings;
with ada.strings.maps;			use ada.strings.maps;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
with ada.containers;			use ada.containers;
with ada.containers.doubly_linked_lists;

with gnat.os_lib;   			use gnat.os_lib;
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_base; 					use m1_base;
with m1_database;				use m1_database;
with m1_numbers; 				use m1_numbers;
with m1_string_processing;		use m1_string_processing;
with m1_files_and_directories; 	use m1_files_and_directories;


procedure mknets is

	version			: constant string (1..3) := "046";

	prog_position	: natural := 0;

-- 	use type_universal_string;
	use type_name_database;
	use type_name_file_options;
	use type_net_name;
	use type_device_name;
	use type_device_value;
	use type_package_name;
	use type_pin_name;
	use type_port_name;

	type type_skeleton_pin is record
			device_name			: type_device_name.bounded_string;
			device_class		: type_device_class := '?'; -- default is an unknown device
			device_value		: type_device_value.bounded_string;
			device_package		: type_package_name.bounded_string;
			device_pin_name		: type_pin_name.bounded_string;
		end record;
	package pin_container is new doubly_linked_lists(element_type => type_skeleton_pin);
	use pin_container;
	
	type type_skeleton_net is record
			name			: type_net_name.bounded_string;
			--class			: type_net_class;
			--pin_count		: positive;
			pin_list		: pin_container.list;
			--pin_cursor		: pin_container.cursor;
		end record;
	package net_container is new doubly_linked_lists(element_type => type_skeleton_net);
	use net_container;
	netlist : net_container.list;

	procedure read_skeleton is
	-- Reads the skeleton and adds nets in container netlist.
		line_of_file 			: type_universal_string.bounded_string;
		line_counter			: natural := 0;
		section_netlist_entered	: boolean := false;
		subsection_net_entered	: boolean := false;
		pin_scratch				: type_skeleton_pin;
		pinlist					: pin_container.list;
		net_scratch				: type_skeleton_net;

		procedure put_faulty_line is
		begin
			put_line(message_error & "in skeleton line" & natural'image(line_counter));
		end put_faulty_line;
		
	begin -- read_skeleton
		put("reading skeleton ... ");
		open(file => file_skeleton, name => name_file_skeleton_default, mode => in_file);
		set_input(file_skeleton);
		while not end_of_file
		loop
			prog_position := 1000;
			line_counter := line_counter + 1;
			if (line_counter rem 400) = 0 then -- put a dot every 400 lines of skeleton
				put(".");
			end if;
			line_of_file := to_bounded_string(remove_comment_from_line(get_line));

			if get_field_count(to_string(line_of_file)) > 0 then -- if line contains anything
				if not section_netlist_entered then
					if get_field_from_line(line_of_file,1) = section_mark.section then
						if get_field_from_line(line_of_file,2) = text_skeleton_section_netlist then
							section_netlist_entered := true;
						end if;
					end if;
				else
					if get_field_from_line(line_of_file,1) = section_mark.endsection then
						section_netlist_entered := false;
					else
						-- process netlist content

						-- wait for net header
						if not subsection_net_entered then
							-- The net header starts with "SubSection". The 3rd field must read "class".
							if get_field_from_line(line_of_file,1) = section_mark.subsection then
								-- save net name
								net_scratch.name := to_bounded_string(get_field_from_line(line_of_file,2));

								-- check for keyword "class"
								if get_field_from_line(line_of_file,3) = text_udb_class then
									null;
									--put_line(extended_string.to_string(line_of_file));
								else
									put_line(message_error & "missing keyword " & enclose_in_quotes(text_udb_class));
									put_faulty_line;
									raise constraint_error;
								end if;

								-- check for default class 
								if get_field_from_line(line_of_file,4) = type_net_class'image(NA) then
									--net_scratch.class := NA;
									null;
								else
									put_line(message_error & "expecting default net class " & type_net_class'image(NA));
									put_faulty_line;
									raise constraint_error;
								end if;

								subsection_net_entered := true;
							end if;
						else -- Read pins untile net footer reached. The net footer is "EndSubSection".
							-- When net footer reached:
							-- 1. save pinlist in net_scratch.pin_list
							-- 2. check for one-pin nets
							-- 3. append net_scratch to container netlist
							if get_field_from_line(line_of_file,1) = section_mark.endsubsection then --net footer reached
								subsection_net_entered := false;
								net_scratch.pin_list := pinlist;
								if length(pinlist) = 1 then
									--new_line;
									put_line(message_warning & "net " & to_string(net_scratch.name) & " has only one pin !");
								end if;
								append(container => netlist, new_item => net_scratch);
								clear(pinlist); -- clear pinlist for next net
							else
								-- net footer not reached yet -> check field count and read pins
								if get_field_count(to_string(line_of_file)) = skeleton_field_count_pin then
									-- process pins of net and add to container pin_list
									pin_scratch.device_name := to_bounded_string(get_field_from_line(line_of_file,1));
									--pin_scratch.device_class := type_device_class'value(get_field_from_line(line_of_file,2)); -- CS
									pin_scratch.device_value := to_bounded_string(get_field_from_line(line_of_file,3));
									pin_scratch.device_package := to_bounded_string(get_field_from_line(line_of_file,4));
									pin_scratch.device_pin_name := to_bounded_string(get_field_from_line(line_of_file,5));
									append(container => pinlist, new_item => pin_scratch);
								else
									put_line(message_error & "invalid number of fields found !");
									put_faulty_line;
								end if;
							end if;

						end if;
					end if;
				end if;

			end if;
		end loop;
		new_line;
	end read_skeleton;
	

	function get_cell_info (
	-- Returns the cell info like "pb01_11 | 20 bc_1 input x | 19 bc_1 output3 x 18 0 z" for a given bic and pin.
	-- Even if there are no cells (e.g. linkage pins) the port will be returned.
	-- Collects data in string scratch (by appending) and returns scratch as fixed string.
		--bic : type_ptr_bscan_ic;
        bic : in positive;
		pin : in type_pin_name.bounded_string) 
		return string is -- pb01_11 | 20 bc_1 input x | 19 bc_1 output3 x 18 0 z
		scratch : type_universal_string.bounded_string;
		port_name : type_port_name.bounded_string;
		--entry_ct : natural := 0; -- used to count entries in bic.boundary_register in order to
		-- abort the loop after two entries have been found. CS: might improve performance in very large
        -- projects.
		--occurences : natural := 0;
		
		b : type_bscan_ic := type_list_of_bics.element(list_of_bics,bic);
		pp : type_port_pin; -- for temporarily storage
		pi : type_pin_name.bounded_string; -- for temporarily storage
    begin
        --put(standard_output,".");
		-- Find given pin in bic.port_pin_map and append its port name to scratch.
		-- The port_name afterward serves as key in order to find cells belonging to that port.
		loop_port:
        --for port in 1..bic.len_port_pin_map loop -- look at every port of the targeted bic
--         for port in 1..b.len_port_pin_map loop -- look at every port of the targeted bic          
		for i in 1..length(b.port_pin_map) loop -- look at every port of the targeted bic
			pp := element(b.port_pin_map, positive(i)); -- load a port_pin from port_pin_map
            --put(standard_output,"p");
-- 			for p in 1..list_of_pin_names'last loop -- look at every pin of that port
			for i in 1..length(pp.pin_names) loop -- look at every pin of that port
			-- p points to a pin in array bic.port_pin_map(port).pin_names
			-- p indirectly is the index in case the port is indexed.
				pi := element(pp.pin_names, positive(i)); -- load a pin from list of pin names
				
-- 				if type_short_string.to_string(b.port_pin_map(port).pin_names(p)) = pin then
				if pi = pin then

                    --put(standard_output,"i");
                    
					scratch := append(
						left => scratch, 
-- 						right => type_list_of_bics.element(list_of_bics,bic).port_pin_map(port).port_name
						right => to_bounded_string(to_string(pp.port_name))
						);	

					-- append index if port has more than one pin
-- 					if type_list_of_bics.element(list_of_bics,bic).port_pin_map(port).pin_count > 1 then
					if length(pp.pin_names) > 1 then					
						scratch := append(
							left => scratch, 
							-- 							right => latin_1.left_parenthesis & trim(positive'image(p),left) & latin_1.right_parenthesis
							right => latin_1.left_parenthesis 
								& trim(count_type'image(i),left) 
								& latin_1.right_parenthesis
							);	
					end if;

					port_name := to_bounded_string(to_string(scratch)); -- save port name (incl index) e.g. Y3(5)
					
					exit loop_port; -- no more searching required
				end if;
			end loop;
		end loop label_loop_port;

		-- Search in bic.boundary_register for port_name. The element(s) therein matching that port_name are
		-- cells belonging to the port.
		-- bic.boundary_register may be longer than the actual boundary register length.
		-- NOTE: There may be one or two elements for the given port in bic.boundary_register: one for 
		-- the input cell, another for the output cell. output cells may have a control cell.
		loop_bsr:
--		for b in 1..type_list_of_bics.element(list_of_bics,bic).len_bsr_description loop -- look at every element of boundary register
		for r in 1..b.len_bsr_description loop -- look at every element of boundary register         
            --			if universal_string_type.to_string(type_list_of_bics.element(list_of_bics,bic).boundary_register(b).port) = universal_string_type.to_string(port_name) then
			if universal_string_type.to_string(b.boundary_register(r).port) = universal_string_type.to_string(port_name) then            
-- 				-- pb01_11 | 20 bc_1 input x | 19 bc_1 output3 x 18 0 z
 
				-- append cell id
				scratch := universal_string_type.append(
						left => scratch, 
						right => row_separator_1 & trim( type_cell_id'image(b.boundary_register(r).id),left )
						);	
 
				-- append cell type (like BC_1)
				scratch := universal_string_type.append(
						left => scratch, 
						right => row_separator_0 & type_boundary_register_cell'image(b.boundary_register(r).cell_type )
						);	
 
				-- append cell function (like internal or output2)
				scratch := universal_string_type.append(
						left => scratch, 
						right => row_separator_0 & type_cell_function'image(b.boundary_register(r).cell_function )
						);	

				-- append cell safe value (strip apostrophes as they come with the image of type_bit_char_class_1)
				scratch := universal_string_type.append(
						left => scratch, 
						right => row_separator_0 & type_bit_char_class_1'image(b.boundary_register(r).cell_safe_value)(2)
						);	

				-- append control cell properties if control cell provided (control cell id greater -1)
				if b.boundary_register(r).control_cell_id /= type_control_cell_id'first then
					-- append control cell id
					scratch := universal_string_type.append(
							left => scratch, 
							right => row_separator_0 & trim( type_cell_id'image(b.boundary_register(r).control_cell_id),left )
							);

					-- append control cell disable value (strip apostrophes as they come with the image of type_bit_char_class_0)
					scratch := universal_string_type.append(
							left => scratch, 
							right => row_separator_0 & type_bit_char_class_0'image(b.boundary_register(r).disable_value)(2)
							);

					-- append control cell disable result
					scratch := universal_string_type.append(
							left => scratch, 
							right => row_separator_0 & type_disable_result'image(b.boundary_register(r).disable_result)
							);
				end if;

-- 				entry_ct := entry_ct + 1;
-- 				if entry_ct = 2 then
-- 					exit label_loop_bsr;
-- 				end if;
							
 			end if;
		end loop label_loop_bsr;
		
		return universal_string_type.to_string(scratch);
	end get_cell_info;
	
	procedure write_netlist is
	-- Unpacks the items of container netlist.
		net_cursor 		: net_container.cursor;		
		net_scratch		: type_skeleton_net;
		net_counter		: natural := 0;

		procedure write_net is
			pin_cursor		: pin_container.cursor;
			pin_scratch		: type_skeleton_pin;
            --bic 			: type_ptr_bscan_ic;
			procedure write_pin is
			begin
				put(2 * row_separator_0 & universal_string_type.to_string(pin_scratch.device_name) & row_separator_0 &
						 "?" & row_separator_0 & -- CS: device class
						 universal_string_type.to_string(pin_scratch.device_value) & row_separator_0 &
						 universal_string_type.to_string(pin_scratch.device_package) & row_separator_0 &
						 universal_string_type.to_string(pin_scratch.device_pin_name) & row_separator_0
                   );
				--bic := ptr_bic;
                --while bic /= null loop
                for b in 1..type_list_of_bics.length(list_of_bics) loop
                    --if universal_string_type.to_string(bic.name) = universal_string_type.to_string(pin_scratch.device_name) then
                    if universal_string_type.to_string(type_list_of_bics.element(list_of_bics,positive(b)).name) = 
                        universal_string_type.to_string(pin_scratch.device_name) then
						put(get_cell_info(bic => positive(b), pin => universal_string_type.to_string(pin_scratch.device_pin_name)));
					end if;
					--bic := bic.next;
				end loop;

				new_line;
			end write_pin;
			
		begin -- write_net
			-- write net header like "SubSection ex_GPIO_2 class NA"
            --put_line(standard_output, universal_string_type.to_string( net_scratch.name));
            
			put_line(row_separator_0 & section_mark.subsection & row_separator_0 &
					 universal_string_type.to_string(net_scratch.name) & row_separator_0 &
					 text_udb_class & row_separator_0 & type_net_class'image(NA)
					);
			pin_cursor := first(net_scratch.pin_list);
			pin_scratch := element(pin_cursor);
            write_pin;
			while pin_cursor /= last(net_scratch.pin_list) loop
				pin_cursor := next(pin_cursor);
				pin_scratch := element(pin_cursor);
				write_pin;
			end loop;
            put_line(row_separator_0 & section_mark.endsubsection);
            --put(standard_output,".");
			new_line;
		end write_net;
		
	begin -- write_netlist
		put(standard_output,"writing netlist ");
		net_cursor := first(netlist);
		net_scratch := element(net_cursor);
        --		put_line(standard_output, universal_string_type.to_string( net_scratch.name));
		write_net;
		while net_cursor /= last(netlist) loop
			net_cursor := next(net_cursor);
			net_scratch := element(net_cursor);
			--put_line(standard_output, universal_string_type.to_string( net_scratch.name));
			write_net;

			net_counter := net_counter + 1;
			if (net_counter rem 100) = 0 then 
				put(standard_output,".");
			end if;
			
		end loop;
		new_line(standard_output);
	end write_netlist;




-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin

	new_line;
	put_line("NET MAKER VERSION "& version);
	put_line("===============================");
	prog_position	:= 10;
 	name_file_data_base:= universal_string_type.to_bounded_string(argument(1));
 	put_line("data base      : " & universal_string_type.to_string(name_file_data_base));

	prog_position	:= 30;
	create_temp_directory;
	prog_position	:= 40;
	create_bak_directory;

	-- create premilinary data base (contining scanpath_configuration and registers)
	prog_position	:= 60;
	extract_section( 
		input_file => universal_string_type.to_string(name_file_data_base),
		output_file => name_file_data_base_preliminary,
		section_begin_1 => section_mark.section,
		section_end_1 => section_mark.endsection,
		section_begin_2 => section_scanpath_configuration
		);
	prog_position	:= 70;
	extract_section( 
		input_file => universal_string_type.to_string(name_file_data_base),
		output_file => name_file_data_base_preliminary,
		append => true,
		section_begin_1 => section_mark.section,
		section_end_1 => section_mark.endsection,
		section_begin_2 => section_registers
		);

	-- read premilinary data base
	prog_position	:= 80;
	udb_summary := read_uut_data_base(name_file_data_base_preliminary);
	put_line (" number of BICs" & natural'image(udb_summary.bic_ct));

	-- read skeleton
 	prog_position := 90;
	read_skeleton;

	-- open premilinary data base again and start writing bsld information
	prog_position	:= 100;
	open( 
		file => file_data_base_preliminary,
		mode => append_file,
		name => name_file_data_base_preliminary
		);

	-- write netlist in data base	
	prog_position	:= 110;
	set_output(file_data_base_preliminary);
	new_line;
	put_line (section_mark.section & row_separator_0 & section_netlist);
	put_line (column_separator_0);
	put_line ("-- created by " & name_module_mknets & " version " & version);
	put_line ("-- date " & date_now); 
	new_line;
	write_netlist;
	put_line (section_mark.endsection);
	new_line (file_data_base_preliminary);
	prog_position := 200;
	close(file_data_base_preliminary);
	copy_file(name_file_data_base_preliminary, universal_string_type.to_string(name_file_data_base));

	exception
		when event: others =>
			set_output(standard_output);
			set_exit_status(failure);
			case prog_position is
-- 				when 10 =>
-- 					put_line("ERROR: Data base file missing or insufficient access rights !");
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
	
end mknets;
