------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE JOINNETLIST                         --
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

 
procedure joinnetlist is

	version				: constant string (1..3) := "003";
	prog_position		: natural := 0;
	file_skeleton_temp	: ada.text_io.file_type;

	use type_name_file_skeleton_submodule;

-- 	procedure write_skeleton_file_header is
-- 	begin
-- 		set_output(file_skeleton_temp);
-- 		put_line ("-- THIS IS A SKELETON FILE. DO NOT EDIT !");
-- 		new_line;
-- 		put_line ("-- merged with submodule skeleton " & to_string(name_file_skeleton_submodule));
-- 		new_line;
-- 
-- 	end write_skeleton_file_header;

	use type_module_name;	
	skeleton_main	: type_skeleton;	
	skeleton_sub	: type_skeleton;

	procedure join_skeletons is
		use type_skeleton_info;
		use type_skeleton_netlist;
		use type_universal_string;
		use type_net_name;
		
		net_cursor 		: type_skeleton_netlist.cursor;
		net_scratch		: type_skeleton_net;
		net_counter		: positive := 1;

		procedure write_net is
			use type_skeleton_pinlist;
			use type_device_name;
			use type_device_value;
			use type_package_name;
			use type_pin_name;
			
			pin_cursor		: type_skeleton_pinlist.cursor;
			pin_scratch		: type_skeleton_pin;
			
			procedure write_pin is
			-- write the basic pin info like "R101 NA 2k7 0207/10 2"				
			begin
				put_line(2 * row_separator_0 & to_string(pin_scratch.device_name) & row_separator_0 &
						 type_device_class'image(device_class_default) & row_separator_0 &
						 to_string(pin_scratch.device_value) & row_separator_0 &
						 to_string(pin_scratch.device_package) & row_separator_0 &
						 to_string(pin_scratch.device_pin_name) & row_separator_0
				   );
			end write_pin;
			
		begin -- write_net
			-- write net header like "SubSection ex_GPIO_2 class NA"
			put_line(row_separator_0 & section_mark.subsection & row_separator_0 &
					 to_string(net_scratch.name) & row_separator_0 &
					 text_udb_class & row_separator_0 & type_net_class'image(net_class_default)
					);

			write_message (
				file_handle => file_join_netlist_messages,
				identation => 4,
				text => "net " & to_string(net_scratch.name), 
				console => false);

			if length(net_scratch.pin_list) > 0 then -- write pins if there are pins at all
				pin_cursor 	:= first(net_scratch.pin_list);
				pin_scratch	:= element(pin_cursor);
				write_pin;
				while pin_cursor /= last(net_scratch.pin_list) loop
					pin_cursor 	:= next(pin_cursor);
					pin_scratch := element(pin_cursor);
					write_pin;
				end loop;
			else
				write_message (
					file_handle => file_join_netlist_messages,
					text => message_warning & "net " & to_string(net_scratch.name) & " has no pins !", 
					console => false);
			end if;
            put_line(row_separator_0 & section_mark.endsubsection);
			new_line;
		end write_net;

		
	begin -- join_skeletons
		set_output(file_skeleton_temp);

		write_message (
			file_handle => file_join_netlist_messages,
			text => "joining skeletons ...",
			identation => 1,
			console => true);
		
		put_line(section_mark.section & row_separator_0 & text_skeleton_section_info);
		put_line (" created by " & name_module_join_netlist & " version " & version);	
		put_line (" date " & date_now);
		put_line (" --------------------------------------");
-- 		put_line (" main module " & to_string(skeleton_sub.name));
		if length(skeleton_main.info) > 0 then
			for i in 1..length(skeleton_main.info) loop
				put_line("  " & to_string(element(skeleton_main.info, positive(i))));
			end loop;
		end if;
		put_line (" --------------------------------------");

		put_line (" joined with module " & to_string(skeleton_sub.name));
		if length(skeleton_sub.info) > 0 then
			for i in 1..length(skeleton_sub.info) loop
				put_line("  " & to_string(element(skeleton_sub.info, positive(i))));
			end loop;
		end if;
		put_line(section_mark.endsection);
		new_line;

		
		write_message (
			file_handle => file_join_netlist_messages,
			text => "writing section netlist ...",
			identation => 2,
			console => false);

		-- write section header
		put_line(section_mark.section & row_separator_0 & text_skeleton_section_netlist); new_line;


		
		-- write main module
		write_message (
			file_handle => file_join_netlist_messages,
			text => "main module ...",
			identation => 3,
			lf => false,			
			console => true);

		if length(skeleton_main.netlist) > 0 then -- write main module if it has nets at all
			new_line(file_join_netlist_messages);
			net_cursor 	:= first(skeleton_main.netlist);
			net_scratch := element(net_cursor);
			write_net;
			while net_cursor /= last(skeleton_main.netlist) loop
				net_cursor 	:= next(net_cursor);
				net_scratch := element(net_cursor);

				write_net;
				net_counter := net_counter + 1;

				-- progess bar
				if (net_counter rem 100) = 0 then 
					put(standard_output,".");
				end if;
			end loop;
			new_line(standard_output);
		else
			new_line(file_join_netlist_messages);
			write_message (
				file_handle => file_join_netlist_messages,
				text => message_warning & "main module has no nets !",
				console => true);
		end if;

		
		-- write submodule
		net_counter := 1;		
		write_message (
			file_handle => file_join_netlist_messages,
			text => "submodule ...",
			identation => 3,
			lf => false,
			console => true);

		if length(skeleton_sub.netlist) > 0 then -- write submodule if it has nets at all		
			new_line(file_join_netlist_messages);
			net_cursor 	:= first(skeleton_sub.netlist);
			net_scratch := element(net_cursor);
			write_net;
			while net_cursor /= last(skeleton_sub.netlist) loop
				net_cursor 	:= next(net_cursor);
				net_scratch := element(net_cursor);

				write_net;
				net_counter := net_counter + 1;

				-- progess bar
				if (net_counter rem 100) = 0 then 
					put(standard_output,".");
				end if;
			end loop;
			new_line(standard_output);
		else
			new_line(file_join_netlist_messages);
			write_message (
				file_handle => file_join_netlist_messages,
				text => message_warning & "submodule has no nets !",
				console => true);
		end if;


		
		-- write section footer
		put_line(section_mark.endsection);

		
		set_output(standard_output);		
	end join_skeletons;
	
begin
	action := join_netlist;

	new_line;
	put_line(to_upper(name_module_join_netlist) & " version " & version);
	put_line("===============================");
	prog_position	:= 10;	
	name_file_skeleton_submodule := to_bounded_string(argument(1));
	put_line("submodule      : " & to_string(name_file_skeleton_submodule));

	
	-- recreate an empty tmp directory
	prog_position	:= 30;	
	create_temp_directory;

	-- create message/log file
	prog_position	:= 40;	
 	write_log_header(version);
	
	prog_position	:= 50;	
	if exists(to_string(name_file_skeleton_submodule)) then
		write_message (
			file_handle => file_join_netlist_messages,
			text => "importing skeleton of submodule ...",
			console => true);
			  
		skeleton_sub := read_skeleton(to_string(name_file_skeleton_submodule)); -- read skeleton to be merged with default skeleton
		skeleton_sub.name := to_bounded_string(to_string(name_file_skeleton_submodule)); -- CS: extract the prefix instead of using the whole name
	else
		write_message (
			file_handle => file_join_netlist_messages,
			text => message_error & to_string(name_file_skeleton_submodule)
				& " does not exist. Please import netlist first !",
			console => true);
	end if;


	prog_position	:= 60;	
	if exists(name_file_skeleton) then
		write_message (
			file_handle => file_join_netlist_messages,
			text => "importing skeleton of main module ...",
			console => true);
	
		skeleton_main := read_skeleton; -- read default skeleton

	else
		write_message (
			file_handle => file_join_netlist_messages,
			text => message_error & name_file_skeleton
				& " does not exist. Please import netlist first !",
			console => true);
	end if;


	prog_position	:= 100;	
	create( -- this is going to be the new skeleton
		file => file_skeleton_temp, 
		mode => out_file,
		name => compose(name_directory_temp, name_file_skeleton));

	prog_position	:= 110;		
	join_skeletons;
	
	prog_position	:= 120;		
	close(file_skeleton_temp);


	prog_position	:= 130;
	write_message (
		file_handle => file_join_netlist_messages,
		text => "copying preliminary skeleton to " & name_file_skeleton,
		console => false);
	copy_file( compose(name_directory_temp, name_file_skeleton) , name_file_skeleton );

	prog_position	:= 140;	
	write_log_footer;
	
	exception when event: others =>
		set_exit_status(failure);
		set_output(standard_output);

		new_line;
		new_line(file_join_netlist_messages);
		write_message (
			file_handle => file_join_netlist_messages,
			text => message_error & " at program position " & natural'image(prog_position),
			console => true);

		if is_open(file_skeleton) then
			close(file_skeleton);
		end if;

		if is_open(file_skeleton_temp) then
			close(file_skeleton_temp);
		end if;
		
-- 		case prog_position is
-- 			when 10 =>
-- 				write_message (
-- 					file_handle => file_mknets_messages,
-- 					text => message_error & text_identifier_database & " file missing or insufficient access rights !",
-- 					console => true);
-- 
-- 				write_message (
-- 					file_handle => file_mknets_messages,
-- 					text => "       Provide " & text_identifier_database & " name as argument. Example: mknets my_uut.udb",
-- 					console => true);
-- 
-- 			when others =>
-- 				write_message (
-- 					file_handle => file_mknets_messages,
-- 					text => "exception name: " & exception_name(event),
-- 					console => true);
-- 
-- 				write_message (
-- 					file_handle => file_mknets_messages,
-- 					text => "exception message: " & exception_message(event),
-- 					console => true);
-- 		end case;

		write_log_footer;

end joinnetlist;
