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

	procedure write_skeleton_file_header is
	begin
		set_output(file_skeleton_temp);
		put_line ("-- THIS IS A SKELETON FILE. DO NOT EDIT !");
		put_line ("-- created by " & name_module_join_netlist & " version " & version);	
		put_line ("-- date " & date_now);
		new_line;
		put_line ("-- merged with submodule skeleton " & to_string(name_file_skeleton_submodule));
		new_line;
		set_output(standard_output);
	end write_skeleton_file_header;
	
	netlist_to_join : net_container.list;
	
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
	
-- 	extract_section("skeleton.txt","tmp/skeleton_brutto.tmp","Section","EndSection","netlist_skeleton");
-- 	extract_netto_from_Section("tmp/skeleton_brutto.tmp","tmp/skeleton_netto.tmp");
-- 	
-- 	extract_section(to_string(skeleton_sub),"tmp/skeleton_brutto_sub.tmp","Section","EndSection","netlist_skeleton");
-- 	extract_netto_from_Section("tmp/skeleton_brutto_sub.tmp","tmp/skeleton_netto_sub.tmp");
	
	--scratch:= ( delete(skeleton_sub,1,9) );
	--put(scratch(scratch'first .. scratch'last-1));
	
	--put (to_string(scratch)(to_string(scratch)'first+9 .. to_string(scratch)'last-4));
	--append_sub_name(to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4));
	--(to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4));

	prog_position	:= 50;	
	if exists(to_string(name_file_skeleton_submodule)) then
		write_message (
			file_handle => file_join_netlist_messages,
			text => "importing skeleton of submodule ...",
			console => true);
			  
		read_skeleton(to_string(name_file_skeleton_submodule)); -- read skeleton to be merged with default skeleton
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
	
		read_skeleton; -- read default skeleton
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
		name => compose(name_directory_temp, to_string(name_file_skeleton_submodule)));

	prog_position	:= 110;		
	write_skeleton_file_header;

	prog_position	:= 120;		
	close(file_skeleton_temp);

	
-- 	-- backup existing main module
-- 	--extract_section( (to_string(data_base)) ,"tmp/spc_seed.tmp","Section","EndSection","scanpath_configuration");
-- 	Copy_File( "skeleton.txt", Compose("bak","skeleton.txt"));
-- 	Create( OutputFile, Name => Compose("tmp","skeleton.tmp")); Close(OutputFile);
-- 	put ("NOTE           : A backup of the mainmodule skeleton can be found in directory 'bak'."); new_line;
-- 
-- 	Open( 
-- 		File => OutputFile,
-- 		Mode => Append_File,
-- 		Name => Compose("tmp","skeleton.tmp")
-- 		);
-- 	Set_Output(OutputFile);

-- 	put ("Section info"); new_line;
-- 	put ("---------------------------------------------------------------"); new_line;
-- 	put ("-- created by Netlist Joiner version " & version); new_line;
-- 	put ("-- date           : " ); put (Image(clock)); new_line; 
-- 	put ("-- UTC_Offset     : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; new_line;
-- 	put ("-- joined netlist : " & skeleton_sub); new_line;
-- 	put ("-- prefix         : " & (to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4))); new_line; -- ins V002
-- 	put ("EndSection "); new_line; new_line;
-- 	
-- 	put ("Section netlist_skeleton"); new_line; new_line;
-- 	put ("------MAINMODULE BEGIN-------------------------------------------"); new_line(2);	
-- 	append_file_open("tmp/skeleton_netto.tmp");
-- 	new_line(2);
-- 	put ("------SUBMODULE BEGIN--------------------------------------------"); new_line;
-- 	put ("-- origin         : " & skeleton_sub); new_line(2);
-- 	append_file_open("tmp/skeleton_netto_sub_ext.tmp");
-- 	put ("EndSection"); new_line; new_line;
			

--	Copy_File( "tmp/skeleton.tmp" , "skeleton.txt" );
	write_log_footer;
	
	exception when event: others =>
		set_exit_status(failure);
		set_output(standard_output);

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
