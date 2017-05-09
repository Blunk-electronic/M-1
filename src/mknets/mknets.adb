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
--
--   todo:
-- 		- direct all error messages to logfile

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
with m1_import;					use m1_import;
with m1_numbers; 				use m1_numbers;
with m1_string_processing;		use m1_string_processing;
with m1_files_and_directories; 	use m1_files_and_directories;


procedure mknets is

	version			: constant string (1..3) := "046";

	prog_position	: natural := 0;

 	use type_universal_string;
	use type_name_database;
	use type_name_file_options;
	use type_net_name;
	use type_device_name;
	use type_device_value;
	use type_package_name;
	use type_pin_name;
	use type_port_name;

	function get_cell_info (
	-- Returns the cell info like "pb01_11 | 20 bc_1 input x | 19 bc_1 output3 x 18 0 z" for a given bic and pin.
	-- Even if there are no cells (e.g. linkage pins) the port will be returned.
	-- Collects data in string scratch (by appending) and returns scratch as fixed string.
		--bic : type_ptr_bscan_ic;
        bic 	: in positive;
		pin 	: in type_pin_name.bounded_string) 
		return string is -- pb01_11 | 20 bc_1 input x | 19 bc_1 output3 x 18 0 z
		scratch 	: type_universal_string.bounded_string;
		port_name 	: type_port_name.bounded_string;
		--entry_ct : natural := 0; -- used to count entries in bic.boundary_register in order to
		-- abort the loop after two entries have been found. CS: might improve performance in very large
        -- projects.
		--occurences : natural := 0;

		use type_port_pin_map;
		use type_list_of_pin_names;
		use type_list_of_bsr_bits;		
		
		b 	: type_bscan_ic := type_list_of_bics.element(list_of_bics,bic);
		pp 	: type_port_pin; -- for temporarily storage
		pi 	: type_pin_name.bounded_string; -- for temporarily storage
		bit	: type_bit_of_boundary_register; -- for temporarily storage
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
		end loop loop_port;

		-- Search in bic.boundary_register for port_name. The element(s) therein matching that port_name are
		-- cells belonging to the port.
		-- bic.boundary_register may be longer than the actual boundary register length.
		-- NOTE: There may be one or two elements for the given port in bic.boundary_register: one for 
		-- the input cell, another for the output cell. output cells may have a control cell.
		loop_bsr:
--		for b in 1..type_list_of_bics.element(list_of_bics,bic).len_bsr_description loop -- look at every element of boundary register
-- 		for r in 1..b.len_bsr_description loop -- look at every element of boundary register
		for i in 1..length(b.boundary_register) loop
			bit := element(b.boundary_register, positive(i));
--			if universal_string_type.to_string(type_list_of_bics.element(list_of_bics,bic).boundary_register(b).port) = universal_string_type.to_string(port_name) then
			-- 			if universal_string_type.to_string(b.boundary_register(r).port) = universal_string_type.to_string(port_name) then            
			if bit.port = port_name then            			
-- 				-- pb01_11 | 20 bc_1 input x | 19 bc_1 output3 x 18 0 z
 
				-- append cell id
				scratch := append(
						left => scratch, 
-- 						right => row_separator_1 & trim( type_cell_id'image(b.boundary_register(r).id),left )
 						right => row_separator_1 & trim( type_cell_id'image(bit.id),left )
						);	
 
				-- append cell type (like BC_1)
				scratch := append(
						left => scratch, 
						-- 						right => row_separator_0 & type_boundary_register_cell'image(b.boundary_register(r).cell_type )
						right => row_separator_0 & type_boundary_register_cell'image(bit.cell_type)
						);	
 
				-- append cell function (like internal or output2)
				scratch := append(
						left => scratch, 
-- 						right => row_separator_0 & type_cell_function'image(b.boundary_register(r).cell_function )
						right => row_separator_0 & type_cell_function'image(bit.cell_function)
						);	

				-- append cell safe value (strip apostrophes as they come with the image of type_bit_char_class_1)
				scratch := append(
						left => scratch, 
-- 						right => row_separator_0 & type_bit_char_class_1'image(b.boundary_register(r).cell_safe_value)(2)
						right => row_separator_0 & type_bit_char_class_1'image(bit.cell_safe_value)(2) -- quotes must be removed
						);	

				-- append control cell properties if control cell provided (control cell id greater -1)
-- 				if b.boundary_register(r).control_cell_id /= type_control_cell_id'first then
				if bit.control_cell_id /= type_control_cell_id'first then
					-- append control cell id
					scratch := append(
							left => scratch, 
-- 							right => row_separator_0 & trim( type_cell_id'image(b.boundary_register(r).control_cell_id),left )
							right => row_separator_0 & trim( type_cell_id'image(bit.control_cell_id),left )
							);

					-- append control cell disable value (strip apostrophes as they come with the image of type_bit_char_class_0)
					scratch := append(
							left => scratch, 
-- 							right => row_separator_0 & type_bit_char_class_0'image(b.boundary_register(r).disable_value)(2)
							right => row_separator_0 & type_bit_char_class_0'image(bit.disable_value)(2)
							);

					-- append control cell disable result
					scratch := append(
							left => scratch, 
-- 							right => row_separator_0 & type_disable_result'image(b.boundary_register(r).disable_result)
							right => row_separator_0 & type_disable_result'image(bit.disable_result)
							);
				end if;

-- 				entry_ct := entry_ct + 1;
-- 				if entry_ct = 2 then
-- 					exit label_loop_bsr;
-- 				end if;
							
 			end if;
		end loop loop_bsr;
		
		return to_string(scratch);
	end get_cell_info;
	
	procedure write_netlist (skeleton : in type_skeleton) is
	-- Writes the netlist of given skeleton in (currently open) skeleton file.

		use type_skeleton_netlist;
		
		net_cursor 		: type_skeleton_netlist.cursor;		
		net_scratch		: type_skeleton_net;
		net_counter		: natural := 0;

		procedure write_net is
			use type_skeleton_pinlist;
			pin_cursor		: type_skeleton_pinlist.cursor;
			pin_scratch		: type_skeleton_pin;
			bic 			: type_bscan_ic;
			
			procedure write_pin is
			-- writes something like: IC303 NA SN74BCT8240ADWR SOIC24 2 Y1(1) | 7 BC_1 OUTPUT3 X 17 1 Z
				use type_list_of_bics;
			begin
				-- write the basic pin info like "R101 NA 2k7 0207/10 2"
				put(2 * row_separator_0 & to_string(pin_scratch.device_name) & row_separator_0 &
						 type_device_class'image(device_class_default) & row_separator_0 &
						 to_string(pin_scratch.device_value) & row_separator_0 &
						 to_string(pin_scratch.device_package) & row_separator_0 &
						 to_string(pin_scratch.device_pin_name) & row_separator_0
				   );

				-- if pin belongs to a bic, additionally write 
				-- port and cell info like "SOIC24 2 Y1(1) | 7 BC_1 OUTPUT3 X 17 1 Z"
				for i in 1..type_list_of_bics.length(list_of_bics) loop
					bic := element(list_of_bics, positive(i));
                    if bic.name = pin_scratch.device_name then
						put(get_cell_info(
							bic => positive(i),
							pin => pin_scratch.device_pin_name));
					end if;
				end loop;

				new_line;
			end write_pin;
			
		begin -- write_net
			-- write net header like "SubSection ex_GPIO_2 class NA"
			put_line(row_separator_0 & section_mark.subsection & row_separator_0 &
					 to_string(net_scratch.name) & row_separator_0 &
					 text_udb_class & row_separator_0 & type_net_class'image(net_class_default)
					);

			put_line(2 * row_separator_0 & comment_mark & m1_database.pin_legend);
			
			write_message (
				file_handle => file_mknets_messages,
				identation => 2,
				text => "net " & to_string(net_scratch.name), 
				console => false);
			
			pin_cursor 	:= first(net_scratch.pin_list);
			pin_scratch	:= element(pin_cursor);
            write_pin;
			while pin_cursor /= last(net_scratch.pin_list) loop
				pin_cursor 	:= next(pin_cursor);
				pin_scratch := element(pin_cursor);
				write_pin;
			end loop;
            put_line(row_separator_0 & section_mark.endsubsection);
            --put(standard_output,".");
			new_line;
		end write_net;
		
	begin -- write_netlist
		write_message (
			file_handle => file_mknets_messages,
			identation => 1,
			text => "writing netlist ...", 
			lf => false,
			console => true);
		new_line(file_mknets_messages);
		
		net_cursor 	:= first(skeleton.netlist);
		net_scratch := element(net_cursor);

		write_net;
		while net_cursor /= last(skeleton.netlist) loop
			net_cursor 	:= next(net_cursor);
			net_scratch := element(net_cursor);

			write_net;
			net_counter := net_counter + 1;

			-- progess bar
			if (net_counter rem 100) = 0 then 
				put(standard_output,".");
			end if;
			
		end loop;

		write_message (
			file_handle => file_mknets_messages,
			text => "", 
			console => true);
		
	end write_netlist;


	procedure copy_scanpath_configuration_and_registers is
		line_counter : natural := 0;
	begin	
		write_message (
			file_handle => file_mknets_messages,
			text => "rebuilding " & text_identifier_database & " ...", 
			console => true);

		write_message (
			file_handle => file_mknets_messages,
			identation => 1,
			text => "copying scanpath configuration and registers ...", 
			console => false);
		
		open(file => file_database, mode => in_file, name => to_string(name_file_database));

		-- Copy line per line from current database to preliminary database until 
		-- last line of section "registers" reached.

		-- Data source is current database. Data sink is preliminary database.
		while not end_of_file(file_database) loop
			line_counter := line_counter + 1;
			put_line(get_line(file_database));
			if line_counter = summary.line_number_end_of_section_registers then
				exit;
			end if;
		end loop;

		close(file_database);
	end copy_scanpath_configuration_and_registers;

	procedure write_section_netlist_header (skeleton : in type_skeleton) is
		use type_skeleton_netlist;
	begin
		new_line;
		put_line(section_mark.section & row_separator_0 & section_netlist);
		put_line(column_separator_0);
		put_line("-- created by " & name_module_mknets & " version " & version);
		put_line("-- date " & date_now); 
		put_line("-- number of nets" & count_type'image(length(skeleton.netlist)));
		new_line;
	end write_section_netlist_header;

	skeleton : type_skeleton;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	-- this causes the database parser to stop after section "registers"
	action := mknets;

	new_line;
	put_line(to_upper(name_module_mknets) & " version " & version);
	put_line("===============================");
	prog_position	:= 10;
 	name_file_database := to_bounded_string(argument(1));
 	put_line(text_identifier_database & "       : " & to_string(name_file_database));

	prog_position	:= 30;
	create_temp_directory;

	-- create message/log file
	prog_position	:= 40;
 	write_log_header(version);

	-- write name of database in logfile
	put_line(file_mknets_messages, text_identifier_database 
		 & row_separator_0
		 & to_string(name_file_database));
	
	prog_position	:= 50;
	read_uut_database;
	
	-- create premilinary data base (contining scanpath_configuration and registers)
	prog_position	:= 70;
	create( 
		file => file_database_preliminary,
		mode => out_file,
		name => name_file_database_preliminary
		);

	prog_position	:= 80;	
	set_output(file_database_preliminary);
	
	prog_position	:= 90;		
	copy_scanpath_configuration_and_registers;

	prog_position	:= 100;
	skeleton := read_skeleton;

 	prog_position 	:= 110;
	write_section_netlist_header(skeleton);
	
 	prog_position 	:= 120;	
	write_netlist(skeleton);

	-- write section netlist footer
	put_line (section_mark.endsection); new_line;
	
	prog_position 	:= 130;
	close(file_database_preliminary);
	set_output(standard_output);
	
	prog_position	:= 140;	
	write_message (
		file_handle => file_mknets_messages,
		text => "copying preliminary " & text_identifier_database & " to " & to_string(name_file_database),
		console => false);
	copy_file(name_file_database_preliminary, to_string(name_file_database));

	prog_position	:= 150;	
	write_log_footer;
	
	exception when event: others =>
		set_exit_status(failure);
		set_output(standard_output);

		write_message (
			file_handle => file_mknets_messages,
			text => message_error & " at program position " & natural'image(prog_position),
			console => true);

		if is_open(file_database_preliminary) then
			close(file_database_preliminary);
		end if;
		
		case prog_position is
			when 10 =>
				write_message (
					file_handle => file_mknets_messages,
					text => message_error & text_identifier_database & " file missing or insufficient access rights !",
					console => true);

				write_message (
					file_handle => file_mknets_messages,
					text => "       Provide " & text_identifier_database & " name as argument. Example: mknets my_uut.udb",
					console => true);

			when others =>
				write_message (
					file_handle => file_mknets_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_mknets_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;
end mknets;
