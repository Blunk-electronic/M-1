-- ---------------------------------------------------------------------------
--                                                                          --
--                          SYSTEM M-1 IMPORT                               --
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


with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;
with ada.text_io;				use ada.text_io;
with ada.float_text_io;			use ada.float_text_io;

with ada.containers;			use ada.containers;
with ada.containers.doubly_linked_lists;

-- with ada.containers;            use ada.containers;
-- with ada.containers.vectors;
-- with ada.containers.indefinite_vectors;

with ada.directories;			use ada.directories;
with interfaces;				use interfaces;
with ada.exceptions;

with m1_files_and_directories; 	use m1_files_and_directories;
with m1_string_processing; 		use m1_string_processing;

package body m1_import is

	use type_net_name;
	use type_device_name;
	use type_package_name;
	use type_pin_name;
	use type_device_value;
	use type_list_of_nets;
	use type_list_of_pins;

	procedure put_format_cad is
	begin
		put_line(type_format_cad'image(format_cad));
	end put_format_cad;

	procedure put_message_on_failed_cad_import(format_cad : type_format_cad) is
	begin
-- 		write_message (
-- 			file_handle => file_import_cad_messages,
-- 			text => message_error & "importing " & type_format_cad'image(format_cad) 
-- 				& " CAD data failed ! " & aborting, 
-- 			console => true);		
		put_line(standard_output, message_error & "importing " & type_format_cad'image(format_cad) 
			& " CAD data failed ! " & aborting);

		raise constraint_error;
	end put_message_on_failed_cad_import;


	function read_skeleton (name_of_skeleton : in string := name_file_skeleton_default) return type_skeleton is
	-- Reads the skeleton and adds nets in container variable netlist (see m1_import.ads).

		-- backup current output channel
		previous_output	: file_type renames current_output;
		
		line_of_file 			: type_universal_string.bounded_string;
		line_counter			: natural := 0;
		section_netlist_entered	: boolean := false;
		subsection_net_entered	: boolean := false;
		pin_scratch				: type_skeleton_pin;
		pinlist					: type_skeleton_pinlist.list;
		net_scratch				: type_skeleton_net;

		section_info_entered	: boolean := false;
		
		skeleton				: type_skeleton;

	 	use type_universal_string;
		use type_net_name;
		use type_device_name;
		use type_device_value;
		use type_pin_name;
		use type_package_name;
		
		procedure put_faulty_line is
		begin
			write_message (
				file_handle => current_output,
				text => message_error & "in skeleton line" & natural'image(line_counter), 
				console => true);
		end put_faulty_line;

	begin -- read_skeleton

		-- set destination of messages according to action
		case action is
			when mknets =>
				set_output(file_mknets_messages);
			when join_netlist =>
				set_output(file_join_netlist_messages);
			when others => null;
		end case;

		write_message (
			file_handle => current_output,
			identation => 1,
			text => "reading " & name_of_skeleton & " ...", 
			console => false);
		new_line(current_output);		
		
		if not exists(name_of_skeleton) then
			write_message (
				file_handle => current_output,
				text => message_error & name_of_skeleton & " not found !", 
				console => true);
			raise constraint_error;
		end if;
		
		open(file => file_skeleton, name => name_of_skeleton, mode => in_file);
		set_input(file_skeleton);
		while not end_of_file
		loop
			line_counter := line_counter + 1;

			-- progress bar
			if (line_counter rem 400) = 0 then -- put a dot every 400 lines of skeleton
				put(standard_output,".");
			end if;
			
			line_of_file := to_bounded_string(remove_comment_from_line(get_line));

			if get_field_count(to_string(line_of_file)) > 0 then -- if line contains anything

				-- READ SECTION INFO
				if not section_info_entered then
					if get_field_from_line(to_string(line_of_file),1) = section_mark.section then
						if get_field_from_line(to_string(line_of_file),2) = text_skeleton_section_info then
							section_info_entered := true;
						end if;
					end if;
				else
					if get_field_from_line(to_string(line_of_file),1) = section_mark.endsection then
						section_info_entered := false;
					else
						append(skeleton.info, line_of_file);
					end if;
				end if;

				-- READ SECTION NETLIST
				if not section_netlist_entered then
					if get_field_from_line(to_string(line_of_file),1) = section_mark.section then
						if get_field_from_line(to_string(line_of_file),2) = text_skeleton_section_netlist then
							section_netlist_entered := true;
						end if;
					end if;
				else
					if get_field_from_line(to_string(line_of_file),1) = section_mark.endsection then
						section_netlist_entered := false;
					else
						-- process netlist content

						-- wait for net header
						if not subsection_net_entered then
							-- The net header starts with "SubSection". The 3rd field must read "class".
							if get_field_from_line(to_string(line_of_file),1) = section_mark.subsection then
								
								-- save net name
								net_scratch.name := to_bounded_string(get_field_from_line(to_string(line_of_file),2));

								write_message (
									file_handle => current_output,
									identation => 2,
									text => "net " & to_string(net_scratch.name), 
									console => false);
								
								-- check for keyword "class"
								if get_field_from_line(to_string(line_of_file),3) = text_udb_class then
									null;
									--put_line(extended_string.to_string(line_of_file));
								else
									write_message (
										file_handle => current_output,
										text => message_error & "missing keyword " & enclose_in_quotes(text_udb_class), 
										console => true);

									put_faulty_line;
									raise constraint_error;
								end if;

								-- check for default class 
								if get_field_from_line(to_string(line_of_file),4) = type_net_class'image(net_class_default) then
									--net_scratch.class := NA;
									null;
								else
									write_message (
										file_handle => current_output,
										text => message_error & "expecting default net class " & type_net_class'image(net_class_default), 
										console => true);

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
							if get_field_from_line(to_string(line_of_file),1) = section_mark.endsubsection then --net footer reached
								subsection_net_entered := false;
								net_scratch.pin_list := pinlist;

								-- check for one-pin net
								if length(pinlist) = 1 then
									write_message (
										file_handle => current_output,
										text => message_warning & "net " & to_string(net_scratch.name) & " has only one pin !", 
										console => false);
								end if;
								
								append(container => skeleton.netlist, new_item => net_scratch);
								clear(pinlist); -- clear pinlist for next net
							else
								-- net footer not reached yet -> check field count and read pins
								if get_field_count(to_string(line_of_file)) = skeleton_field_count_pin then
									-- process pins of net and add to container pin_list
									pin_scratch.device_name := to_bounded_string(get_field_from_line(to_string(line_of_file),1));
									--pin_scratch.device_class := type_device_class'value(get_field_from_line(line_of_file,2)); -- CS
									pin_scratch.device_value := to_bounded_string(get_field_from_line(to_string(line_of_file),3));
									pin_scratch.device_package := to_bounded_string(get_field_from_line(to_string(line_of_file),4));
									pin_scratch.device_pin_name := to_bounded_string(get_field_from_line(to_string(line_of_file),5));

									write_message (
										file_handle => current_output,
										identation => 3,
										text => "device/pin " & to_string(pin_scratch.device_name) & row_separator_0
											& to_string(pin_scratch.device_pin_name),
										console => false);
									
									append(container => pinlist, new_item => pin_scratch);
								else
									write_message (
										file_handle => current_output,
										text => message_error & "invalid number of fields found !", 
										console => true);

									put_faulty_line;
								end if;
							end if;

						end if;
					end if;
				end if;

			end if;
		end loop;
		set_input(standard_input);
		close(file_skeleton);
		
		write_message (
			file_handle => current_output,
			text => "", 
			console => true);

		-- restore previous output channel
		set_output(previous_output);
		return skeleton;
		
	end read_skeleton;

	
	procedure write_advise_dos2unix is
	begin
		write_message (
			file_handle => file_import_cad_messages,
			text => "Converting netlist from DOS to UNIX format might be required !",
			console => true);

		write_message (
			file_handle => file_import_cad_messages,
			text => "Example 1: dos2unix " & compose(name_directory_cad, "netlist_dos.net"),
			console => true);
		
		write_message (
			file_handle => file_import_cad_messages,
			text => "Example 2: dos2unix -n " & compose(name_directory_cad, "netlist_dos.net netlist_unix.net"),
			console => true);
	end write_advise_dos2unix;


	procedure write_skeleton (
		module_name : in string;
		module_version : in string;
		assembly_variants : in boolean) is
	-- Writes the skeleton file from the list_of_nets and list_of_devices..
		net : m1_import.type_net;
		pin : m1_import.type_pin;
		--ld 	: natural := natural(length(list_of_devices));
		use type_map_of_devices;
		use type_map_of_regular_nets;

		procedure write_statistics is
		-- Writes the statistics in the skeleton file.
		begin
			new_line(file_import_cad_messages);		
			write_message (
				file_handle => file_import_cad_messages,
				text => "writing statistics ...",
				identation => 1,			
				console => true);

			put_line(file_skeleton, " statistics:");

			put(file_skeleton, "  devices :");
			if assembly_variants then
				put_line(file_skeleton, natural'image(device_count_mounted));
			else
				put_line(file_skeleton, count_type'image(length(map_of_devices)));
			end if;

			put(file_skeleton, "  nets    :");
			if assembly_variants then
				put_line(file_skeleton, count_type'image(length(list_of_nets)));
			else
				put_line(file_skeleton, count_type'image(length(map_of_regular_nets)));
			end if;

			put(file_skeleton, "  pins    :");
			if assembly_variants then
				put_line(file_skeleton, natural'image(pin_count_mounted));
			else
				put_line(file_skeleton, natural'image(pin_count));
			end if;

	-- 		put_line(file_skeleton,section_mark.endsection);		
		end write_statistics;

		procedure write_info is
		-- Writes the section info in skeleton.
		begin
			new_line(file_import_cad_messages);
			write_message (
				file_handle => file_import_cad_messages,
				text => "writing section info ...",
				identation => 1,
				console => false);
			
			put_line(section_mark.section & row_separator_0 & text_skeleton_section_info);
			put_line(" created by " & module_name & " version " & module_version);
			put_line(" date " & date_now);
			if cad_import_target_module = m1_import.sub then
				put_line(" prefix " & to_string(target_module_prefix));
			end if;

			write_statistics;
			
			put_line(section_mark.endsection);
		end write_info;	

		function get_value_and_package(device : in type_device_name.bounded_string) return string is
		-- returns value and package of a given device in a single string.
		-- If we are dealing with assembly variants, it looks up the device in list_of_devices.
		-- Otherwise it looks up the map_of_devices.
			device_a : type_device;
			device_b : type_base_device;
		begin
			if assembly_variants then
				for d in 1..length(list_of_devices) loop
					device_a := element(list_of_devices,positive(d));
					if device_a.name = device then
						if device_a.mounted then
							return to_string(device_a.value) 
								& row_separator_0 
								& to_string(device_a.packge);
							--exit;
						end if;
					end if;
				end loop;
			else
				device_b := element(container => map_of_devices, key => device);
				return to_string(device_b.value) 
					& row_separator_0 
					& to_string(device_b.packge);
			end if;
			
			-- This code should never be reached:
			raise constraint_error;
			return "";
		end get_value_and_package;

		procedure write_nets_with_variants is
		begin
			for n in 1..length(list_of_nets) loop
				net := element(list_of_nets, positive(n)); -- load a net

				write_message (
					file_handle => file_import_cad_messages,
					text => to_string(net.name),
					identation => 2,
					console => false);
				
				-- write net header like "SubSection CORE_EXT_SRST class NA"
				put(row_separator_0 & section_mark.subsection & row_separator_0);
				if cad_import_target_module = m1_import.sub then -- insert module prefix if it is a submodule
					put(to_string(target_module_prefix) & "_");
				end if;
				put_line(to_string(net.name) & row_separator_0 
					& netlist_keyword_header_class & row_separator_0 & type_net_class'image(net_class_default));

				-- write pins in lines like "R3 ? 270K RESC1005X40N 1"
				for p in 1..length(net.pins) loop
					pin := element(net.pins, positive(p)); -- load a pin

					if pin.mounted then -- address only active assembly variants
						put("  ");
						if cad_import_target_module = m1_import.sub then -- insert module prefix if it is a submodule
							put(to_string(target_module_prefix) & "_");
						end if;
						put_line(to_string(pin.name_device) 
							& row_separator_0 & type_device_class'image(device_class_default) 
							& row_separator_0 & get_value_and_package(pin.name_device) 
							& row_separator_0 & to_string(pin.name_pin)
							);
					end if;
				end loop;

				put_line(row_separator_0 & section_mark.endsubsection); new_line;
			end loop;
		end write_nets_with_variants;
		
		procedure write_regular_nets is
		begin
			null;
		end write_regular_nets;

	begin -- write_skeleton
		new_line(file_import_cad_messages);

		-- The skeleton file is named with the standard name or
		-- with the standard name + prefix:
		case cad_import_target_module is
			when m1_import.main => 
				write_message (
					file_handle => file_import_cad_messages,
					text => "creating skeleton for main module ...",
					console => false);

				create (file => file_skeleton, mode => out_file, name => name_file_skeleton);

			when m1_import.sub => 
				write_message (
					file_handle => file_import_cad_messages,
					text => "creating skeleton for submodule " & to_string(target_module_prefix) & " ...",
					console => false);

-- 				target_module_prefix := to_bounded_string(argument(3));
-- 
-- 				name_file_skeleton_submodule := to_bounded_string(compose( name => 
-- 					base_name(name_file_skeleton) & "_" & 
-- 					to_string(target_module_prefix),
-- 					extension => file_extension_text));

				create (file => file_skeleton, mode => out_file, 
						name => type_name_file_skeleton_submodule.to_string(name_file_skeleton_submodule));
		end case;

		write_message (
			file_handle => file_import_cad_messages,
			text => "writing skeleton ...",
			console => true);

		set_output(file_skeleton);
		
		write_info;

		write_message (
			file_handle => file_import_cad_messages,
			text => "writing section netlist ...",
			identation => 1,
			console => true);
		
		new_line;
		put_line(section_mark.section & row_separator_0 & text_skeleton_section_netlist); 
		new_line;

		if assembly_variants then
			write_nets_with_variants;
		else
			write_regular_nets;
		end if;

		put_line(section_mark.endsection);
		set_output(standard_output);
		close(file_skeleton);
	end write_skeleton;


end m1_import;

