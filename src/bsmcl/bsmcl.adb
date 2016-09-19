--t----------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE BSMCL                               --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               B o d y                                    --
--                                                                          --
--         Copyright (C) 2016 Mario Blunk, Blunk electronic                 --
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
--   todo:

with ada.text_io;				use ada.text_io;
with ada.characters.handling; 	use ada.characters.handling;
with ada.strings; 				use ada.strings;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.unbounded.text_io; use ada.strings.unbounded.text_io;
with ada.exceptions; use ada.exceptions;

 
with gnat.os_lib;   	use gnat.os_lib;
with ada.command_line;	use ada.command_line;
with ada.directories;	use ada.directories;
with ada.environment_variables;

with m1;
with m1_internal; use m1_internal;
with m1_numbers;
with m1_files_and_directories; use m1_files_and_directories;

procedure bsmcl is
	version			: constant string (1..3) := "024";

--	uut_dir			: Unbounded_String;
	action			: type_action;
	batch_file 		: Unbounded_string;
	test_profile 	: Unbounded_string; -- CS: use type_test_profile
	test_name  		: Unbounded_string;
	sequence_name 	: Unbounded_string;
	ram_addr   		: string (1..4) := "0000"; -- page address bits [23:8]
	data_base  		: Unbounded_string;

	target_device	: unbounded_string;
	device_package	: unbounded_string;
	device_model	: unbounded_string;

	algorithm		: unbounded_string;
	target_pin		: unbounded_string;	
	target_net		: unbounded_string;
	retry_count		: unbounded_string;
	retry_delay		: unbounded_string;
	low_time		: unbounded_string;
	high_time  		: unbounded_string;		
	toggle_count	: unbounded_string;	
   
	opt_file		: unbounded_string;
	cad_format		: unbounded_string;
	net_list		: unbounded_string;
	part_list		: unbounded_string;

	v_model			: unbounded_string;
	project_name	: unbounded_string;

	line			: unbounded_string;
	skeleton_sub 	: unbounded_string;

	key				: String (1..1) := "n";
	Result   		: Integer;
	prog_position	: String (1..5) := "-----";

	arg_ct			: natural;
	arg_pt			: natural := 1;

	conf_file				: Ada.Text_IO.File_Type;
	help_file				: Ada.Text_IO.File_Type;
	home_directory			: universal_string_type.bounded_string;
	conf_directory			: constant string (1..5) := ".M-1/";
	conf_file_name			: constant string (1..8) := "M-1.conf";
	help_file_name_german	: constant string (1..15) := "help_german.txt";
	help_file_name_english	: constant string (1..16) := "help_english.txt";
	directory_of_backup		: unbounded_string;
	directory_of_log		: unbounded_string;
	directory_of_binary_files	: unbounded_string;
	directory_of_enscript		: unbounded_string;
	interface_to_scan_master	: universal_string_type.bounded_string;

	vector_id_breakpoint	: type_vector_id_breakpoint;
	bit_position			: type_sxr_break_position := 0; -- in case bit_position to break at is not provided, default used

	type language_type is (german, english); -- move to m1_internal ?
	language 	: language_type := english;

	debug_mode			: natural := 0; -- default is no debug mode

	function is_project_directory return boolean is
	-- Checks if working directory is a project.
		is_project : boolean;
	begin
		if exists(project_description) then
			--put ("project        : ");  put(Containing_Directory("proj_desc.txt")); new_line;
			is_project := true;
		else
			is_project := false;
		end if; 
		return is_project;
	end is_project_directory;

	procedure check_environment is
		previous_input	: Ada.Text_IO.File_Type renames current_input;
		line			: unbounded_string;
	begin
		-- get home variable
		prog_position := "ENV00";
		if not ada.environment_variables.exists("HOME") then
			raise constraint_error;
		else
			-- compose home directory name
			home_directory := universal_string_type.to_bounded_string(ada.environment_variables.value("HOME")); -- this is the absolute path of the home directory
			--put_line(to_string(home_directory));
		end if;

		-- check if conf file exists	
		prog_position := "ENV10";
		if not exists ( universal_string_type.to_string(home_directory) & '/' & conf_directory & '/' & conf_file_name ) then 
			raise constraint_error;
		else
			-- read configuration file
			Open(
				file => conf_file,
				Mode => in_file,
				Name => ( universal_string_type.to_string(home_directory) & '/' & conf_directory & '/' & conf_file_name )
				);
			set_input(conf_file);
			while not end_of_file
			loop
				line := m1.remove_comment_from_line(get_line,"#");
				--put_line(line);

				-- get language
				if m1.get_field(line,1,' ') = "language" then 
					prog_position := "ENV20";
					language := language_type'value(m1.get_field(line,2,' '));
--					if debug_mode = 1 then 
--						put_line("language        : " & language_type'image(language));
--					end if;
				end if;

				-- get bin directory
				if m1.get_field(line,1,' ') = "directory_of_binary_files" then 
					prog_position := "ENV30";
					if m1.get_field(line,2,' ')(1) /= '/' then -- if no heading /, take this as relative to home directory
						directory_of_binary_files := to_unbounded_string(universal_string_type.to_string(home_directory)) & '/' &
							to_unbounded_string(m1.get_field(line,2,' '));
					else -- otherwise take this as an absolute path
						directory_of_binary_files := to_unbounded_string(m1.get_field(line,2,' '));
					end if;

--					if debug_mode = 1 then 
--						put_line("directory_of_binary_files : " & to_string(directory_of_binary_files));
--					end if;
				end if;

				-- get enscript directory
				if m1.get_field(line,1,' ') = "directory_of_enscript" then 
					prog_position := "ENV40";
					if m1.get_field(line,2,' ')(1) /= '/' then -- if no heading /, take this as relative to home directory
						directory_of_enscript := to_unbounded_string(universal_string_type.to_string(home_directory)) & '/' &
							to_unbounded_string(m1.get_field(line,2,' '));
					else -- otherwise take this as an absolute path
						directory_of_enscript := to_unbounded_string(m1.get_field(line,2,' '));
					end if;

--					if debug_mode = 1 then 
--						put_line("directory_of_enscript : " & to_string(directory_of_enscript));
--					end if;
				end if;

				-- get interface_to_scan_master
				if m1.get_field(line,1,' ') = "interface_to_scan_master" then 
					prog_position := "ENV50";
					interface_to_scan_master := universal_string_type.to_bounded_string(m1.get_field(line,2,' ')); -- this must be an absolute path
--					if debug_mode = 1 then 
--						put_line("interface_to_scan_master : " & to_string(interface_to_scan_master));
--					end if;
				end if;


			end loop;
			close(conf_file);
		end if;

		-- check if help file exists	
		prog_position := "ENV90";
		case language is
			when german => 
				if not exists ( universal_string_type.to_string(home_directory) & "/" & conf_directory & help_file_name_german ) then 
					put_line("ERROR : German help file missing !");
				end if;
			when english =>
				if not exists ( universal_string_type.to_string(home_directory) & "/" & conf_directory & help_file_name_english ) then 
					put_line("ERROR : English help file missing !");
				end if;
			when others =>
				put_line("ERROR : Help file missing !");
		end case;

		if debug_mode = 1 then
			put_line(column_separator_0);
		end if;
		set_input(previous_input);
	end check_environment;



		function exists_netlist
			(
			-- version 1.0 / MBL
			-- verifies if given netlist exists
			netlist	: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("netlist        : ");	put(netlist); new_line;				
				
				if exists (netlist) then
					file_exists := true;
				else
					new_line;
					put("ERROR ! Netlist '"& netlist &"' not found !"); 
					new_line;
					--put ("PROGRAM ABORTED !"); new_line; new_line;
					--Abort_Task (Current_Task); -- CS: not safe
				end if;
				return file_exists;
				
			end exists_netlist;


		function exists_partlist
			(
			-- version 1.0 / MBL
			-- verifies if given partlist exists
			partlist	: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("partlist       : ");	put(partlist); new_line;				
				
				if exists (partlist) then
					file_exists := true;
				else
					new_line;
					put("ERROR ! Partlist '"& partlist &"' not found !"); 
					new_line;
					--put ("PROGRAM ABORTED !"); new_line; new_line;
					--Abort_Task (Current_Task); -- CS: not safe
				end if;
				return file_exists;
				
			end exists_partlist;



		function exists_database
			(
			-- version 1.0 / MBL
			-- verifies if given database exists
			database	: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("database       : ");	put(database); new_line;				
				
				if exists (database) then
					file_exists := true;
				else
					new_line;
					--put ("ERROR ! Database '"& database &"' not found !"); 
					put ("ERROR ! Database '"& data_base &"' does not exist ! Aborting ..."); 					
					--new_line;
					--put ("PROGRAM ABORTED !"); new_line; new_line;
					--Abort_Task (Current_Task); -- CS: not safe
				end if;
				return file_exists;
				
			end exists_database;





		function exists_optfile
			(
			-- version 1.0 / MBL
			-- verifies if given optfile exists
			optfile		: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("options file   : ");	put(optfile); new_line;				
				
				if exists (optfile) then
					file_exists := true;
				else
					new_line;
					put ("ERROR ! Options file '"& optfile &"' does not exist ! Aborting ..."); 					
				end if;
				return file_exists;
				
			end exists_optfile;




		function exists_model
			(
			-- version 1.0 / MBL
			-- verifies if given model file exists
			modelfile		: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("model file     : ");	put(modelfile); new_line;				
				
				if exists (modelfile) then
					file_exists := true;
				else
					new_line;
					put ("ERROR ! Model file '"& modelfile &"' does not exist ! Aborting ..."); 					
				end if;
				return file_exists;
				
			end exists_model;



		function exists_skeleton
			(
			-- version 1.0 / MBL
			-- verifies if given skeleton file exists
			skeleton_file : string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("submodule      : ");	put(skeleton_file); new_line;				
				
				if exists (skeleton_file) then
					file_exists := true;
				else
					new_line;
					put ("ERROR ! Submodule '"& skeleton_file &"' does not exist ! Aborting ..."); 					
				end if;
				return file_exists;
				
			end exists_skeleton;



		procedure advise_next_step_cadimport
			-- version 1.0 / MBL
			(
			dummy : Boolean
			) is
			begin
				put("... done"); new_line (2);
				put("Recommended next steps :"); new_line (2);
				put("  1. Read header of file 'skeleton.txt' for warnings and import notes using a text editor."); new_line;
				put("     If you have imported CAD data of a submodule, please also look into file 'skeleton_your_submodule.txt'."); new_line;				
				put("  2. Create boundary scan nets using command: 'bsmcl mknets'"); new_line;
			end advise_next_step_cadimport;


		procedure advise_next_step_generate
			-- version 1.0 / MBL
			(
			database : String;
			testname : String
			) is
			begin
				put("... done"); new_line (2);
				put("Recommended next steps :"); new_line (2);
				put("  1. Compile generated test using command 'bsmcl compile " & database & " " & testname & "'."); new_line(2);
				put("     Following steps are optional for fine tuning:"); new_line(2);				
				put("  2. Edit generated sequence file '" & testname & "/" & testname & ".seq' with a text editor."); new_line;				
				put("     NOTE: On automatic test generation the sequence file will be overwritten !"); new_line;
				put("  3. Compile modified test using command 'bsmcl compile " & database & " " & testname & "'."); new_line;				
			end advise_next_step_generate;


		procedure advise_next_step_compile
			-- version 1.0 / MBL
			(
			--database : String;
			testname : String
			) is
			begin
				put("... done"); new_line (2);
				put("Recommended next steps :"); new_line (2);
				put("  1. Load compiled test into BSC using command 'bsmcl load " & testname & "'."); new_line;
				--put("     If you have imported CAD data of a submodule, please also look into file 'skeleton_your_submodule.txt'."); new_line;				
				--put("  2. Create boundary scan nets using command: 'bsmcl mknets'"); new_line;
			end advise_next_step_compile;


		procedure advise_next_step_load
			-- version 1.0 / MBL
			(
			--database : String;
			testname : String
			) is
			begin
				put("... done"); new_line (2);
				--put("Test '"& testname &"' ready for launch !"); new_line;
				put("Recommended next steps :"); new_line (2);
				put("  1. Launch loaded test using command 'bsmcl run " & testname & "'."); new_line;
				--put("     If you have imported CAD data of a submodule, please also look into file 'skeleton_your_submodule.txt'."); new_line;				
				--put("  2. Create boundary scan nets using command: 'bsmcl mknets'"); new_line;
			end advise_next_step_load;



	procedure write_error_no_project is
	begin
		put_line("ERROR: The current working directory is no " & system_name_m1 & " project !");
		raise constraint_error;
	end write_error_no_project;


begin

	new_line;
	put("M-1 Command Line Interface Version "& version); new_line;
	put_line(column_separator_2);
	check_environment;

		
	prog_position := "CRT00";
	arg_ct :=  argument_count;

	action := type_action'value(argument(1));
	put_line ("action         : " & type_action'image(action));

	case action is
			
		when create =>

			-- MAKE PROJECT BEGIN
			prog_position := "CRT05";
			if is_project_directory then
				put_line(message_warning & "The current working directory is a " & system_name_m1 & " project already !");
				ada.text_io.put_line(message_warning'length * row_separator_0 &
					"Nesting projects is not supported. Change into a valid project directory !");
				raise constraint_error;
			else
				prog_position := "PJN00";
				project_name:=to_unbounded_string(argument(2));
				new_line;
					
				-- launch project maker
				spawn 
					(  
					program_name           => to_string(directory_of_binary_files) & "/mkproject",
					args                   => 	(
												1=> new string'(to_string(project_name))
												-- 2=> new string'(to_string(opt_file)) 
												),
					output_file_descriptor => standout,
					return_code            => result
					);
				-- evaluate result
				case result is
					when 0 => -- then set_directory(to_string(project_name)); -- cd into project directory -- CS: does not work
						put_line(done); new_line;
						put_line("Recommended next steps :"); new_line;
						put_line("  1. Change into project directory " & quote_single & project_name & quote_single & dot);
						put_line("  2. Edit project database " & quote_single & project_name & file_extension_separator 
							& file_extension_database & "' according to your needs with a text editor.");
						put_line("  3. Import BSDL model files using command: " & quote_single & module_name_cli & row_separator_0 &
							to_lower(type_action'image(import_bsdl)) & row_separator_0 & project_name &
							file_extension_separator & file_extension_database & quote_single & dot);
					when 1 => 
						put_line(message_error & " Malfunction while creating new project " & quote_single & project_name & quote_single 
							& row_separator_0 & exclamation & row_separator_0 & aborting);
						raise constraint_error;
					when others => 
						null;
				end case;

			end if;
			-- MAKE PROJECT END

		when help =>

			-- HELP BEGIN
			case language is
				when german => 
					open(
						file => help_file,
						mode => in_file,
						name => universal_string_type.to_string(home_directory) & "/" & conf_directory & help_file_name_german
						);
				when others =>
					open(
						file => help_file,
						mode => in_file,
						name => universal_string_type.to_string(home_directory) & "/" & conf_directory & help_file_name_english
						);
			end case;
			set_input(help_file);

			while not end_of_file
			loop
				line := get_line;
				put_line(line);
			end loop;
			close(help_file);
			-- HELP END



		when import_cad =>
			-- CAD IMPORT BEGIN
			prog_position := "ICD00";			
			cad_format:=to_unbounded_string(Argument(2));
			if is_project_directory then

				if cad_format = "orcad" then
					put ("CAD format     : ");	put(cad_format); new_line;
					
					-- check if netlist file exists
					prog_position := "INE00";							
					if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
					else 
						prog_position := "NLE00";	
						raise Constraint_Error;
					end if;
					
					-- launch ORCAD importer
					new_line;
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/imporcad",
						Args                   => 	(
													1=> new String'(Argument(3))
	--												2=> new String'(Argument(4))
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then advise_next_step_cadimport(true);
					else
						put("ERROR   while importing ORCAD CAD data ! Aborting ..."); new_line;
						prog_position := "-----";		
						raise Constraint_Error;
					end if;


				elsif cad_format = "altium" then
					put ("CAD format     : ");	put(cad_format); new_line;
					
					-- check if netlist file exists
					prog_position := "INE00";							
					if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
					else 
						prog_position := "NLE00";	
						raise Constraint_Error;
					end if;
					
					-- launch ALTIUM importer
					new_line;
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/impaltium",
						Args                   => 	(
													1=> new String'(Argument(3))
	--												2=> new String'(Argument(4))
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then advise_next_step_cadimport(true);
					else
						put("ERROR   while importing ALTIUM CAD data ! Aborting ..."); new_line;
						prog_position := "-----";		
						raise Constraint_Error;
					end if;




				elsif cad_format = "zuken" then
					put ("CAD format     : ");	put(cad_format); new_line;
					
					-- check if netlist file exists
					prog_position := "INE00";							
					if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
					else 
						prog_position := "NLE00";	
						raise Constraint_Error;
					end if;
					
					-- launch ZUKEN importer
					new_line;
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/impzuken",
						Args                   => 	(
													1=> new String'(Argument(3))
	--												2=> new String'(Argument(4))
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then advise_next_step_cadimport(true);
					else
						put("ERROR   while importing ZUKEN CAD data ! Aborting ..."); new_line;
						prog_position := "-----";		
						raise Constraint_Error;
					end if;




				elsif cad_format = "eagle6" then
					put ("CAD format     : ");	put(cad_format); new_line;
					
					-- check if netlist file exists
					prog_position := "INE00";							
					if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
					else 
						prog_position := "NLE00";	
						raise Constraint_Error;
					end if;
					
					-- check if partlist file exists
					prog_position := "IPA00";				
					if exists_partlist(Argument(4)) then null; -- raises exception if partlist not given 
					else 
						prog_position := "PLE00";	
						raise Constraint_Error;
					end if;


					-- launch EAGLE V6 importer
					new_line;
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/impeagle6x",
						Args                   => 	(
													1=> new String'(Argument(3)),
													2=> new String'(Argument(4))
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then advise_next_step_cadimport(true);
					else
						put("ERROR while importing EAGLE CAD data ! Aborting ..."); new_line;
						prog_position := "-----";		
						raise Constraint_Error;
				
						--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
					end if;


	--			elsif cad_format = "conti1" then
	--				put ("CAD format     : ");	put(cad_format); put(" (IPC-D-356A) "); new_line;					
					
					-- check if netlist file exists
	--				prog_position := "INE";							
	--				if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
	--				else 
	--					prog_position := "NLE";	
	--					raise Constraint_Error;
	--				end if;
					
	--				begin
	--					part_list:=to_unbounded_string(Argument(4)); -- raises exception if partlist not given 
	-- 
	-- 					exception 
	-- 						when Constraint_Error => 
	-- 							begin
	-- 								new_line; Put("WARNING : Partlist not specified ! Proceed anyway ? (y/n) "); Get(key);
	-- 								--new_line;
	-- 								if key = "y" then 
	-- 									partlist_given := false;
	-- 									--else Abort_Task (Current_Task); -- CS: not safe
	-- 								else 
	-- 									prog_position := "OAT"; -- program cancelled by operator
	-- 									raise Constraint_Error;
	-- 								end if;
	-- 							end;
	-- 							
	-- 				end;
	-- 
	-- 				begin
	-- 
	-- 
	-- 					-- if part_list has been given, check if part_list file exists
	-- 					if partlist_given = true then
	-- 						
	-- 						-- check if partlist file exists
	-- 						prog_position := "IPA";				
	-- 						if exists_partlist(Argument(4)) then null; -- raises exception if partlist not given 
	-- 						else 
	-- 							prog_position := "PLE";	
	-- 							raise Constraint_Error;
	-- 						end if;
	-- 						
	-- 		
	-- 						-- launch IPC-D-356A importer with net- and partlist
	-- 						new_line;
	-- 						Spawn 
	-- 							(  
	-- 							Program_Name           => "/home/bsadmin/bin/bsx/impconti1",
	-- 							Args                   => 	(
	-- 														1=> new String'(Argument(3)),
	-- 														2=> new String'(Argument(4))
	-- 														),
	-- 							Output_File_Descriptor => Standout,
	-- 							Return_Code            => Result
	-- 							);
	-- 					else
	-- 						-- launch IPC-D-356A importer without partlist
	-- 						new_line;
	-- 						Spawn 
	-- 							(  
	-- 							Program_Name           => "/home/bsadmin/bin/bsx/impconti1",
	-- 							Args                   => 	(
	-- 														1=> new String'(Argument(3))
	-- 														--2=> new String'(to_string(part_list))
	-- 														),
	-- 							Output_File_Descriptor => Standout,
	-- 							Return_Code            => Result
	-- 							);
	-- 					end if;
	-- 
	-- 					-- evaluate result
	-- 					if 
	-- 						Result = 0 then advise_next_step_cadimport(true);
	-- 					else
	-- 						put("ERROR   while importing Conti1 IPC-D-356A CAD data ! Aborting ..."); new_line;
	-- 					end if;
	-- 				end;
					
					
					
				else	-- if unknown CAD format
					put ("CAD format     : ");	put(cad_format); new_line;					
					prog_position := "NCF00";
					raise Constraint_Error;
				end if;
			else
				write_error_no_project;
			end if;
			-- CAD IMPORT END



		when mkvmod =>
			-- MAKE VERILOG MODEL BEGIN

			if is_project_directory then
				-- do an agrument count check only, mkvmod will do the rest
				prog_position := "ACV00";
				if argument_count /= 3 then	-- bsmcl mkvmod skeleton.txt verilog_file
					raise Constraint_Error;
				end if;
										
					-- launch verilog model maker
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/mkvmod",
						Args                   => 	(
													1=> new String'(argument(2)),
													2=> new String'(argument(3))
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then
							new_line;
							put("... done"); new_line(2);
							put("Recommended next step :"); new_line (2);
							put("  1. Edit Verilog Model according to your needs."); new_line;

					else
						put("ERROR while writing Verilog model file ! Aborting ..."); new_line;
						prog_position := "-----";		
						raise Constraint_Error;
						
						--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
					end if;

			else
				write_error_no_project;
			end if;
			-- MAKE VERILOG MODEL END


		when join_netlist =>
		-- JOIN NETLIST BEGIN
			if is_project_directory then

				prog_position := "JSM00";
				skeleton_sub:=to_unbounded_string(Argument(2)); -- raises exception if skeleton submodule not given

				-- check if skeleton submodule file exists
				if exists_skeleton(Argument(2)) then null; -- raises exception if skeleton not given 
				else 
					prog_position := "JSN00";
					raise Constraint_Error;
				end if;
										
				-- check if skeleton main file exists
				if exists("skeleton.txt") then null; -- raises exception if skeleton main not present
				else 
					prog_position := "SMN00";
					raise Constraint_Error;
				end if;
										
										
				-- launch netlist joiner
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/joinnetlist",
					Args                   => 	(
												1=> new String'(to_string(skeleton_sub))
												--2=> new String'(to_string(skeleton_sub))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then
						new_line;
						put("... done"); new_line(2);
						put("Recommended next step :"); new_line (2);
						put("  1. Create boundary scan nets using command: 'bsmcl mknets'"); new_line;

				else
					put("ERROR while joining netlists ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;

			else
				write_error_no_project;
			end if;
		-- JOIN NETLIST END 


		when import_bsdl =>
		-- BSDL IMPORT BEGIN
			if is_project_directory then

				prog_position := "IBL00";
				data_base:=to_unbounded_string(Argument(2)); -- raises exception if udb not given

				-- check if udb file exists
				if exists_database(Argument(2)) then null; -- raises exception if udb not given 
				else 
					prog_position := "DBE00";		
					raise Constraint_Error;
				end if;
									
				-- launch BSDL importer
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/impbsdl",
					Args                   => 	(
												1=> new String'(to_string(data_base))
												-- 2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then
						new_line;
						put("... done"); new_line(2);
						put("Recommended next step :"); new_line (2);
						put("     Import CAD data files using command: 'bsmcl impcad cad_format'"); new_line;

				else
					put("ERROR   while importing BSDL files ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
				
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;

			else
				write_error_no_project;
			end if;
		-- BSDL IMPORT END



		when mknets =>
		-- MKNETS BEGIN
			if is_project_directory then
				prog_position := "MKN00";
				data_base:=to_unbounded_string(Argument(2)); -- raises exception if udb not given

				-- check if udb file exists
				if exists_database(Argument(2)) then null; -- raises exception if udb not given 
				else 
					prog_position := "DBE00";		
					raise Constraint_Error;
				end if;

				-- launch mknets
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mknets",
					Args                   => 	(
												1=> new String'(to_string(data_base))
												-- 2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if 
					Result = 0 then 
						put("... done"); new_line(2);
						put("Recommended next steps :"); new_line (2);
						put("     Create options file for database '" & data_base & "' using command 'bsmcl mkoptions " & data_base & " your_target_options_file.opt'"); new_line;
						--put("  2. Edit options file according to your needs using a text editor."); new_line;
						--put("  3. Import BSDL model files using command: 'bsmcl impbsdl " & project_name & ".udb'"); new_line;
						
				else
					put("ERROR   while building bscan nets ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;
			else
				write_error_no_project;
			end if;
		-- MKNETS END




		when mkoptions =>
		-- MKOPTIONS BEGIN
			if is_project_directory then
				prog_position := "MKO00";
				data_base:=to_unbounded_string(Argument(2)); -- raises exception if udb not given

				-- check if udb file exists
				if exists_database(Argument(2)) then null; -- raises exception if udb not given 
				else 
					prog_position := "DBE00";		
					raise Constraint_Error;
				end if;

				prog_position := "OP200";
				-- ins v021 begin
				if arg_ct = 2 then
					opt_file := to_unbounded_string(base_name(to_string(data_base)) & ".opt");
				else
					opt_file:=to_unbounded_string(Argument(3)); -- NOTE: the opt file given will be created by mkoptions
				end if;

				-- relaunch mknets
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mknets",
					Args                   => 	(
												1=> new String'(to_string(data_base))
												-- 2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if 
					Result = 0 then
 						put("... done"); new_line(2);
-- 						put("Recommended next steps :"); new_line (2);
-- 						put("     Create options file for database '" & data_base & "' using command 'bsmcl mkoptions " & data_base & " your_target_options_file.opt'"); new_line;
						--put("  2. Edit options file according to your needs using a text editor."); new_line;
						--put("  3. Import BSDL model files using command: 'bsmcl impbsdl " & project_name & ".udb'"); new_line;
						
				else
					put("ERROR   while building bscan nets ! Aborting ..."); new_line;
					--prog_position := "---";		
					raise Constraint_Error;
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;


				-- launch mkoptions
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mkoptions",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
												2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if 
					Result = 0 then
						put("... done"); new_line(2);
						put("Recommended next steps :"); new_line (2);
						put("  1. Edit options file '" & opt_file & "' according to your needs using a text editor."); new_line;
						put("  2. Check primary/secondary dependencies and net classes using command 'bsmcl chkpsn " & data_base & " " & opt_file & "'"); new_line;

				else
					put("ERROR while writing options file ! Aborting ..."); new_line;
					prog_position := "OP300";		
					raise Constraint_Error;
					
				end if;

			else
				write_error_no_project;
			end if;
		-- MKOPTIONS END



		when chkpsn =>
		-- CHKPSN BEGIN
			if is_project_directory then

				prog_position := "CP100";
				data_base:=to_unbounded_string(Argument(2));

				-- check if udb file exists
				if exists_database(Argument(2)) then null; -- raises exception if udb not given 
				else 
					prog_position := "DBE00";		
					raise Constraint_Error;
				end if;

				prog_position := "OP100";
				opt_file:=to_unbounded_string(Argument(3));

				-- check if opt_file file exists
				if exists_optfile(Argument(3)) then null; -- raises exception if opt file not given 
				else 
					prog_position := "OPE00";		
					raise Constraint_Error;
				end if;

				-- relaunch mknets
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mknets",
					Args                   => 	(
												1=> new String'(to_string(data_base))
												-- 2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then put("... done"); new_line;
				else
					put("ERROR while building bscan nets ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					--Abort_Task (Current_Task); -- CS: not safe
				end if;

				--put_line("checking classes ...");

				-- launch chkpsn  
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/chkpsn",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
												2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then 
					put("... done"); new_line (2);
					put("Recommended next steps :"); new_line (2);
					put("  1. Now edit file '" & setup_and_templates_directory & test_init_template & "' with a text editor."); new_line;
					put("     to prepare your test init sequence."); new_line (2);
					put("  2. Generate tests using command 'bsmcl generate " & data_base & "'."); new_line;
					
				else
					put("ERROR while checking classes of primary and secondary nets ! Aborting ..."); new_line;
					prog_position := "CP200";		
					raise Constraint_Error;
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;
			else
				write_error_no_project;
			end if;
		-- CHKPSN END



		when generate =>
		-- TEST GENERATION BEGIN
			if is_project_directory then
				prog_position := "GEN00";
				data_base:=to_unbounded_string(Argument(2));

				-- check if udb file exists
				if exists_database(Argument(2)) then null; -- raises exception if udb not given 
				else 
					prog_position := "DBE00";		
					raise Constraint_Error;
				end if;
				
				prog_position := "TPR00";
				put ("test profile   : ");
				test_profile:=to_unbounded_string(Argument(3));
				put(test_profile); new_line;
					
				if test_profile = "infrastructure" then
					prog_position := "TNA00";			
					test_name:=to_unbounded_string(Argument(4));
					put ("test name      : ");	put(test_name); new_line; new_line;
				
					-- launch infra generator
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/mkinfra",
						Args                   => 	(
													1=> new String'(to_string(data_base)),
													2=> new String'(to_string(test_name)) -- pass test name to bsm
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then advise_next_step_generate(to_string(data_base),to_string(test_name));
						
					else
						put("ERROR while generating test "& test_name &" ! Aborting ..."); new_line;
						prog_position := "-----";		
						raise Constraint_Error;
						--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
					end if;

				elsif test_profile = "interconnect" then
					prog_position := "TNA00";			
					test_name:=to_unbounded_string(Argument(4));
					put ("test name      : ");	put(test_name); new_line; new_line;
					-- launch interconnect generator
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/mkintercon",
						Args                   => 	(
													1=> new String'(to_string(data_base)),
													2=> new String'(to_string(test_name)) -- pass test name to bsm
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then advise_next_step_generate(to_string(data_base),to_string(test_name));
				
					else
						put("ERROR   while generating test '"& test_name &"' ! Aborting ..."); new_line;
						prog_position := "-----";		
						raise Constraint_Error;
						--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
					end if;
				

				elsif test_profile = "memconnect" then
					prog_position := "TNA00";			
					test_name:=to_unbounded_string(Argument(4));
					put ("test name      : ");	put(test_name); new_line;
					
					prog_position := "TDV00";				
					target_device:=to_unbounded_string(Argument(5));
					put ("target device  : ");	put(target_device); new_line;
					
					prog_position := "DVM00";
					device_model:=to_unbounded_string(Argument(6));
					
					-- check if model file exists
					if exists_model(Argument(6)) then null; -- raises exception if model file not given 
						else 
							prog_position := "DMN00";		
							raise Constraint_Error;
					end if;
					
					prog_position := "DPC00";
					device_package:=to_unbounded_string(Argument(7));
					put ("package        : ");	put(device_package); new_line; new_line;

					-- launch memconnect generator
					prog_position := "LMC00"; -- ins v018
					--put_line( bin_dir & "mkmemcon"); -- ins v018

					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/mkmemcon",
						Args                   => 	(
													1=> new String'(to_string(data_base)),
													2=> new String'(to_string(test_name)), -- pass test name to bsm
													3=> new String'(to_string(target_device)),
													4=> new String'(to_string(device_model)),
													5=> new String'(to_string(device_package))
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					--put_line(integer'image(result));
	
					-- evaluate result
					if Result = 0 then 
						prog_position := "LM000";	-- ins v018
						advise_next_step_generate(to_string(data_base),to_string(test_name));

					else
						prog_position := "LM100";	-- ins v018
						put("ERROR   while generating test "& test_name &" ! Aborting ..."); new_line;
						prog_position := "MC000";	-- mod v018
						raise Constraint_Error;
						--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
					end if;



				elsif test_profile = "clock" then
					prog_position := "TNA00";			
					test_name:=to_unbounded_string(Argument(4));
					put ("test name      : ");	put(test_name); new_line;
					
					prog_position := "TDV00";					
					target_device:=to_unbounded_string(Argument(5));
					put ("target device  : ");	put(target_device); new_line;
					
					prog_position := "TPI00";				
					target_pin:=to_unbounded_string(Argument(6));
					put ("pin            : ");	put(target_pin); new_line;
					
					prog_position := "RYC00";									
					retry_count:=to_unbounded_string(Argument(7));
					put ("retry count    : ");	put(retry_count); new_line; --new_line;
					
					prog_position := "RDY00";				
					retry_delay:=to_unbounded_string(Argument(8));
					put ("retry delay    : ");	put(retry_delay); new_line; new_line;

					-- launch clock sampling generator
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/mkclock",
						Args                   => 	(
													1=> new String'(to_string(data_base)),
													2=> new String'(to_string(test_name)), -- pass test name to bsm
													3=> new String'("non_intrusive"),
													4=> new String'(to_string(target_device)),
													5=> new String'(to_string(target_pin)),
													6=> new String'(to_string(retry_count)),
													7=> new String'(to_string(retry_delay))
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then advise_next_step_generate(to_string(data_base),to_string(test_name));
					
					else
						put("ERROR: While generating test "& test_name &" ! Aborting ..."); new_line;
						prog_position := "-----";		
						raise Constraint_Error;
						
						--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
					end if;



				elsif test_profile = "toggle" then
					prog_position := "TNA00";			
					test_name:=to_unbounded_string(Argument(4));
					put ("test name      : ");	put(test_name); new_line;
					
					prog_position := "TON00";				
					target_net:=to_unbounded_string(Argument(5));
					put ("target net     : ");	put(target_net); new_line;
					
					prog_position := "TCT00";									
					toggle_count:=to_unbounded_string(Argument(6));
					put ("cycle count    : ");	put(toggle_count); new_line; --new_line;
					
					prog_position := "TLT00";				
					low_time:=to_unbounded_string(Argument(7));
					put ("low time       : ");	put(low_time); new_line;

					prog_position := "THT00";				
					high_time:=to_unbounded_string(Argument(8));
					put ("high time      : ");	put(high_time); new_line; new_line;

					-- launch pin toggle generator
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/mktoggle",
						Args                   => 	(
													1=> new String'(to_string(data_base)),
													2=> new String'(to_string(test_name)),
													-- 3=> new String'(to_string(target_device)),
													3=> new String'(to_string(target_net)),
													4=> new String'(to_string(toggle_count)),
													5=> new String'(to_string(low_time)),
													6=> new String'(to_string(high_time))
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then advise_next_step_generate(to_string(data_base),to_string(test_name));
					
					else
						put("ERROR: While generating test "& test_name &" ! Aborting ..."); new_line;
						prog_position := "TOG01";
						raise Constraint_Error;
						
						--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
					end if;


				-- if test profile not supported
				else 
					raise constraint_error;
				end if;

			else
				write_error_no_project;
			end if;
		-- TEST GENERATION END




		when compile =>
		-- TEST COMPILATION BEGIN
			if is_project_directory then
				prog_position := "CMP00";
				data_base:=to_unbounded_string(Argument(2));

				-- check if udb file exists
				if exists_database(Argument(2)) then null; -- raises exception if udb not given 
				else 
					prog_position := "DBE00";		
					raise Constraint_Error;
				end if;
							
				prog_position := "CTN00";			
				--test_name:=to_unbounded_string(Argument(3)); -- rm v020
				test_name:=to_unbounded_string(m1.strip_trailing_forward_slash(Argument(3))); -- mod v020

				put ("test name      : ");	put(test_name); new_line(2);

				-- check if test directory containing the seq file exists
				if exists (compose (to_string(test_name),to_string(test_name), "seq")) then

					-- launch compiler
					Spawn 
						(  
						Program_Name           => to_string(directory_of_binary_files) & "/compseq",
						Args                   => 	(
													1=> new String'(to_string(data_base)),
													2=> new String'(to_string(test_name)) -- pass test name to bsm
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if Result = 0 then advise_next_step_compile(to_string(test_name));
					else
						put("ERROR   while compiling test "& test_name &" ! Aborting ..."); new_line;
						prog_position := "-----";		
						raise Constraint_Error;
						
						--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
					end if;

				else
					prog_position := "CNE00"; 
					raise constraint_error;
				end if;

			else
				write_error_no_project;
			end if;
		-- TEST COMPILATION END





		when load =>
		-- TEST LOADING BEGIN
			if is_project_directory then
				prog_position := "LD100";			
				if load_test 
					(
					test_name					=> m1.strip_trailing_forward_slash(Argument(2)),
					interface_to_scan_master	=> universal_string_type.to_string(interface_to_scan_master),
					directory_of_binary_files	=> to_string(directory_of_binary_files)
					) then
					prog_position := "LD110";
				else
					prog_position := "LD120";
					set_exit_status(failure);
				end if;
			else
				write_error_no_project;
			end if;
		-- TEST LOADING END



		when dump =>
		-- RAM DUMP BEGIN
			if is_project_directory then
				prog_position := "DP100";			
				ram_addr:= Argument(2); -- page address bits [23:8]

				if dump_ram
					(
					interface_to_scan_master 	=> universal_string_type.to_string(interface_to_scan_master),
					directory_of_binary_files	=> to_string(directory_of_binary_files),
					ram_addr					=> ram_addr -- page address bits [23:8]
					) then
					prog_position := "DP110";
				else
					prog_position := "DP120";
					set_exit_status(failure);
				end if;
			else
				write_error_no_project;
			end if;
		-- RAM DUMP END


		when clear =>
		-- RAM CLEAR BEGIN
			if is_project_directory then
				prog_position := "CLR10";
				
				if clear_ram
					(
					interface_to_scan_master 	=> universal_string_type.to_string(interface_to_scan_master),
					directory_of_binary_files	=> to_string(directory_of_binary_files)
					) then
					prog_position := "CLR20";
					put_line("Please upload compiled tests now.");
				else
					prog_position := "CLR30";
					set_exit_status(failure);
				end if;
			else
				write_error_no_project;
			end if;
		-- RAM CLEAR END



		when run =>
		-- TEST/STEP EXECUTION BEGIN
			if is_project_directory then
				prog_position := "RU100";
				test_name:=to_unbounded_string(m1.strip_trailing_forward_slash(Argument(2)));
				if arg_ct = 3 then
					prog_position := "RU400";
					m1_internal.step_mode:= m1_internal.type_step_mode'value(Argument(3));
				end if;
				
				-- check if test exists
				if exists (compose (to_string(test_name),to_string(test_name), "vec")) then
					put_line ("test name      : " & test_name);
					put_line ("step mode      : " & type_step_mode'image(m1_internal.step_mode)); new_line;

					--bsm --run $run_mode $name  #launch single test/ISP
					-- launch test
					prog_position := "RU300";
					case execute_test
						(
						test_name 					=> to_string(test_name),
						interface_to_scan_master 	=> universal_string_type.to_string(interface_to_scan_master),
						directory_of_binary_files	=> to_string(directory_of_binary_files),
						step_mode					=> step_mode
						--execute_item				=> test
						) is
						-- CS: distinguish between executed step and test !
						when pass =>
							prog_position := "RU310";
							new_line;
							put_line("Test/Step '"& test_name &"' PASSED !");
						when fail =>
							prog_position := "RU320";
							new_line;
							put_line("Test/Step '"& test_name &"' FAILED !");
							set_exit_status(failure);
						when not_loaded =>
							prog_position := "RU330";
							new_line;
							put_line("ERROR : Test data invalid or not loaded yet. Please upload test. Then try again.");
							set_exit_status(failure);
						when others =>
							prog_position := "RU340";
							new_line;
							put_line("ERROR: Internal malfunction !");
							put_line("Test/Step '"& test_name &"' FAILED !");
							set_exit_status(failure);
					end case;

				else 
					prog_position := "RU200";
					put_line("ERROR    : Test '"& test_name &"' does not exist !");
					raise constraint_error;
				end if;
			else
				write_error_no_project;
			end if;
		-- TEST EXECUTION END


		when break =>
		-- SET BREAK POINT BEGIN
			if is_project_directory then
				prog_position := "BP100";
				vector_id_breakpoint := type_vector_id_breakpoint'value(argument(2));

				if vector_id_breakpoint = 0 then
					put_line("breakpoint removed");
				else
					put_line("breakpoint set after");
					put_line ("sxr id         : " & trim(type_vector_id_breakpoint'image(vector_id_breakpoint),left));
					if arg_ct = 3 then
						--prog_position := "BP200";
						bit_position := type_sxr_break_position'value(argument(3));
						put_line ("bit position   : " & trim(type_sxr_break_position'image(bit_position),left));
					end if;
				end if;

				prog_position := "BP300";
				case set_breakpoint
					(
					interface_to_scan_master 	=> universal_string_type.to_string(interface_to_scan_master),
					directory_of_binary_files	=> to_string(directory_of_binary_files),
					vector_id_breakpoint		=> vector_id_breakpoint,
					bit_position				=> bit_position
					) is
					when true =>
						prog_position := "BP310";
					when others =>
						prog_position := "BP320";
						new_line;
						put_line("ERROR: Internal malfunction !");
						raise constraint_error;
				end case;
			else
				write_error_no_project;
			end if;
		-- SET BREAKPOINT END


		-- test step execution begin
-- 		elsif action = "step" then
-- 			prog_position := "ST100";
-- 			test_name:=to_unbounded_string(m1.strip_trailing_forward_slash(Argument(2)));
-- 			if arg_ct = 3 then
-- 				prog_position := "ST400";
-- 				m1_internal.step_mode:= m1_internal.type_step_mode'value(Argument(3));
-- 			end if;
-- 			
-- 			-- check if test exists
-- 			if exists (compose (to_string(test_name),to_string(test_name), "vec")) then
-- 				put_line ("test name      : " & test_name);
-- 				put_line ("step mode      : " & type_step_mode'image(m1_internal.step_mode)); new_line;
-- 
-- 				prog_position := "ST300";
-- 				case execute_test
-- 					(
-- 					test_name 					=> to_string(test_name),
-- 					interface_to_scan_master 	=> to_string(interface_to_scan_master),
-- 					directory_of_binary_files	=> to_string(directory_of_binary_files),
-- 					step_mode					=> step_mode,
-- 					execute_item				=> step
-- 					) is
-- 					when pass =>
-- 						prog_position := "ST310";
-- 						new_line;
-- 						put_line("Test STEP of '"& test_name &"' PASSED !");
-- 					when fail =>
-- 						prog_position := "ST320";
-- 						new_line;
-- 						put_line("Test STEP of '"& test_name &"' FAILED !");
-- 						set_exit_status(failure);
-- 					when not_loaded =>
-- 						prog_position := "ST330";
-- 						new_line;
-- 						put_line("ERROR : Test not loaded yet. Please upload test. Then try again.");
-- 						set_exit_status(failure);
-- 					when others =>
-- 						prog_position := "ST340";
-- 						new_line;
-- 						put_line("ERROR: Internal malfunction !");
-- 						put_line("Test '"& test_name &"' FAILED !");
-- 						set_exit_status(failure);
-- 				end case;
-- 
-- 			else 
-- 				prog_position := "ST200";
-- 				put_line("ERROR    : Test '"& test_name &"' does not exist !");
-- 				raise constraint_error;
-- 			end if;
-- 		-- test step execution end


		-- test start begin
		-- DOES NOT WAIT FOR TEST END
		-- CS: CURRENTLY THERE IS NO NEED TO DO SUCH A THING !!!
-- 		elsif action = "start" then
-- 			prog_position := "-----";
-- 			--test_name:=to_unbounded_string(Argument(2)); -- rm v020
-- 			test_name:=to_unbounded_string(m1.strip_trailing_forward_slash(Argument(2))); -- mod v020
-- 			
-- 			-- check if test exists
-- 			if exists (compose (to_string(test_name),to_string(test_name), "vec")) then
-- 				put ("running        : ");	put(test_name); new_line;
-- 				put ("mode           : ");	put("production"); new_line; --put(run_mode); new_line;
-- 				--bsm --run $run_mode $name  #launch single test/ISP
-- 				-- launch test
-- 				Spawn 
-- 					(  
-- 					Program_Name           => to_string(directory_of_binary_files) & "/bsm",
-- 					Args                   => 	(
-- 												1=> new String'("--start"),
-- 												2=> new String'("production"), --(to_string(run_mode)), -- pass run mode to bsm
-- 												3=> new String'(to_string(test_name)) -- pass test name to bsm
-- 												),
-- 					Output_File_Descriptor => Standout,
-- 					Return_Code            => Result
-- 					);
-- 				-- evaluate result
-- 				if 
-- 					Result = 0 then put("Test '"& test_name &"' is RUNNING !"); new_line;
-- 				elsif
-- 					Result = 2 then put("Test '"& test_name &"' start FAILED !"); new_line;
-- 					Set_Exit_Status(Failure);
-- 				else
-- 					prog_position := "-----";					
-- 					put("ERROR    : Malfunction while starting test '"& test_name &"' ! Aborting ..."); new_line;
-- 					put("code     :"); put(Result); new_line; 
-- 					raise constraint_error;
-- 				end if;
-- 
-- 			else 
-- 				prog_position := "RU200";
-- 				raise constraint_error;
-- 			end if;
		-- test start end


		when status =>
		-- QUERY BSC STATUS BEGIN
			prog_position := "QS100";
			--prog_position := "RU1";
			--test_name:=to_unbounded_string(Argument(2));

			if query_status
				(
				interface_to_scan_master 	=> universal_string_type.to_string(interface_to_scan_master),
				directory_of_binary_files	=> to_string(directory_of_binary_files)
				) then
				prog_position := "QS120";
			else
				prog_position := "QS130";
				set_exit_status(failure);
			end if;
		-- QUERY BSC STATUS END

		when firmware =>
		-- SHOW FIRMWARE BEGIN
			prog_position := "FW000";
			if show_firmware
				(
				interface_to_scan_master	=> universal_string_type.to_string(interface_to_scan_master),
				directory_of_binary_files	=> to_string(directory_of_binary_files)
				) then
				prog_position := "FW100";
			else
				prog_position := "FW200";
				set_exit_status(failure);
			end if;
		-- SHOW FIRMWARE END

		when off =>
		-- UUT POWER DOWN BEGIN
			prog_position := "SDN01";
			if shutdown
				(
				interface_to_scan_master 	=> universal_string_type.to_string(interface_to_scan_master),
				directory_of_binary_files	=> to_string(directory_of_binary_files)
				) then
				prog_position := "SDN10";
			else
				prog_position := "SDN20";
				set_exit_status(failure);
			end if;
		-- UUT POWER DOWN END

		when report =>
		-- VIEW TEST REPORT BEGIN
			if is_project_directory then
				prog_position := "-----";
				
				-- check if test exists
				if exists ("test_sequence_report.txt") then
					--put ("creating PDF test report of "); new_line;
					put ("PDF file name  : ");	put(Containing_Directory("proj_desc.txt") & "/test_sequence_report.pdf"); new_line;
					
					-- convert report txt file to pdf
					Spawn 
						(  
						Program_Name           => to_string(directory_of_enscript) & "/enscript", -- -p last_run.pdf last_run.txt",
						Args                   => 	(
													1=> new String'("-p"),
													2=> new String'("test_sequence_report.pdf"),
													3=> new String'("test_sequence_report.txt")
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if 
						Result = 0 then put("done"); new_line;
					elsif
						Result = 1 then put("FAILED !"); new_line;
						Set_Exit_Status(Failure);
					else
						prog_position := "-----";					
	-- 					put("ERROR    : Malfunction while executing test '"& test_name &"' ! Aborting ..."); new_line;
	-- 					put("code     :"); put(Result); new_line; 
						raise constraint_error;
					end if;


					-- open pdf report
					Spawn 
						(  
						Program_Name           => 	to_string(directory_of_binary_files) & "/open_report", -- "/usr/bin/okular", -- -p last_run.pdf last_run.txt",
						Args                   => 	(
													1=> new String'("test_sequence_report.pdf")
													--2=> new String'("1>/dev/null") -- CS: suppress useless output of okular
													--3=> new String'("last_run.txt")
													),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);
					-- evaluate result
					if 
						Result = 0 then put("done"); new_line;
					elsif
						Result = 1 then put("FAILED !"); new_line;
						Set_Exit_Status(Failure);
					else
						prog_position := "-----";					
	-- 					put("ERROR    : Malfunction while executing test '"& test_name &"' ! Aborting ..."); new_line;
	-- 					put("code     :"); put(Result); new_line; 
						raise constraint_error;
					end if;


				else 
					prog_position := "-----";
					raise constraint_error;
				end if;
			else
				write_error_no_project;
			end if;
		-- VIEW TEST REPORT END




		when others =>
         	new_line;
			put_line ("ERROR : Action not supported !");
			put_line ("        For a list of available actions run command 'bsmcl' !");
			prog_position := "-----";
			raise constraint_error;



	end case;
   
   new_line;

	exception
		when event: 
			others =>
				set_exit_status(failure);
				set_output(standard_output);

				if prog_position = "ENV10" then
					put_line("ERROR ! No configuration file '" & conf_directory & conf_file_name & "' found in home directory.");

				elsif prog_position = "CRT00" then
										--new_line; -- CS: loop through type_action
										put ("ERROR ! No action specified ! What do you want to do ?"); new_line; 
										put ("        Actions available are :");new_line;
										put ("        - create       (set up a new project)"); new_line;
										put ("        - import_cad   (import net and part lists from CAD system)"); new_line;
										put ("        - join_netlist (merge submodule with mainmodule after CAD import)"); new_line;									
										put ("        - import_bsdl  (import BSDL models)"); new_line;
										put ("        - mknets       (make boundary scan nets)"); new_line;
										put ("        - mkoptions    (generate options file template)"); new_line;									
										put ("        - chkpsn       (check entries made by operator in options file)"); new_line;
										put ("        - generate     (generate a test with a certain profile)"); new_line;
										put ("        - compile      (compile a test)"); new_line;
										put ("        - load         (load a compiled test into the Boundary Scan Controller)"); new_line;
										put ("        - clear        (clear entire RAM of the Boundary Scan Controller)"); new_line;
										put ("        - dump         (view a RAM section of the Boundary Scan Controller (use for debugging only !))"); new_line;
										put ("        - run          (run a test/step on your UUT/target and WAIT until test done)"); new_line;
										put ("        - break        (set break point at step ID and bit position)"); new_line;
										put ("        - off          (immediately stop a running test, shut down UUT power and disconnect TAP signals)"); new_line;
										put ("        - status       (query Boundary Scan Controller status)"); new_line;
										put ("        - report       (view the latest sequence execution results)"); new_line;	
										put ("        - mkvmod       (create verilog model port list from main module skeleton.txt)"); new_line;
										put ("        - help         (get examples and assistance)"); new_line;
										put ("        - udbinfo      (get firmware versions)"); new_line;
										--put ("        Example: bsmcl" & action_set_breakpoint); new_line;
									
				elsif prog_position = "PDS00" then
						put ("ERROR : No project data found in current working directory !"); new_line;
						put ("        A project directory must contain at least a file named 'proj_desc.txt' !"); new_line;									
						
				elsif prog_position = "IBL00" then
						new_line;									
						put ("ERROR ! No database specified !"); new_line; 
						--put ("        Actions available are : impcad, impbsdl, mknets, chkpsn, generate, compile, load, run"); new_line;
						put ("        Example: bsmcl impbsdl MMU.udb"); new_line;
	
				elsif prog_position = "MKN00" then
						new_line;									
						put ("ERROR ! No database specified !"); new_line; 
						--put ("        Actions available are : impcad, impbsdl, mknets, chkpsn, generate, compile, load, run"); new_line;
						put ("        Example: bsmcl mknets MMU.udb"); new_line;
	
				elsif prog_position = "JSM00" then
						new_line;									
						put ("ERROR ! No submodule specified !"); new_line; 
						--put ("        Actions available are : impcad, impbsdl, mknets, chkpsn, generate, compile, load, run"); new_line;
						put ("        Run command 'ls *.txt' to get a list of available skeleton files !"); new_line; 									 																		
						put ("        Then try example: bsmcl join skeleton_my_submodule.txt"); new_line;

	
				elsif prog_position = "JSN00" then
						new_line;
						put ("        Make sure path and name of skeleton submodule are correct !"); new_line;
						put ("        Run command 'ls *.txt' to get a list of available skeleton files !"); new_line; 									 
	
				elsif prog_position = "SMN00" then
						new_line;
						put ("ERROR ! No main module 'skeleton.txt' found. !"); new_line;
						put ("        It appears you have not imported any CAD data yet. Please import CAD data now."); new_line;
						put ("        Example: bsmcl impcad cad_format net_list [partlist]"); new_line; 									 
	
				elsif prog_position = "MKO00" then
						new_line;									
						put ("ERROR ! No database specified !"); new_line; 
						put ("        Example: bsmcl mkoptions MMU.udb"); new_line;
	
				elsif prog_position = "CPS00" then
						new_line;									
						put ("ERROR ! No database specified !"); new_line; 
						--put ("        Actions available are : impcad, impbsdl, mknets, chkpsn, generate, compile, load, run"); new_line;
						put ("        Example: bsmcl chkpsn MMU.udb"); new_line;
	
				elsif prog_position = "GEN00" then
						new_line;									
						put ("ERROR ! No database specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb"); new_line;
	
				elsif prog_position = "OP100" then
						new_line;									
						put ("ERROR ! No options file specified !"); new_line; 
						put ("        Example: bsmcl chkpsn MMU.udb options_file.opt"); new_line;
	
				elsif prog_position = "OP200" then
						new_line;									
						put ("ERROR ! No options file specified !"); new_line; 
						put ("        Example: bsmcl mkoptions MMU.udb options_file.opt"); new_line;
	
				elsif prog_position = "OPE00" then
						new_line;									
						put ("        Make sure path and options file name are correct !"); new_line; 
						put ("        Example: bsmcl chkpsn MMU.udb options_file.opt"); new_line;
					
				elsif prog_position = "DBE00" then
						new_line;
						put ("        Make sure path and database file name are correct !"); new_line; 
	
				elsif prog_position = "ICD00" then
						new_line;									
						put ("ERROR ! No CAD format specified !"); new_line; 
						put ("        Formats available are :"); new_line;
						--put ("        - eagle4"); new_line; 
						put ("        - altium"); new_line;
						put ("        - eagle6"); new_line;									
						put ("        - orcad"); new_line;
						put ("        - zuken"); new_line;
						put ("        Example: bsmcl impcad eagle5"); new_line;
	
				elsif prog_position = "NCF00" then
						new_line;									
						put ("ERROR ! Unsupported CAD format specified !"); new_line; 
						put ("        Formats available are :"); new_line;
						--put ("        - eagle4"); new_line; 
						put ("        - altium"); new_line;
						put ("        - eagle6"); new_line;									
						put ("        - orcad"); new_line;
						put ("        - zuken"); new_line;
						put ("        Example: bsmcl impcad eagle5"); new_line;
	
				elsif prog_position = "INE00" then
						new_line;									
						put ("ERROR ! Netlist not specified !"); new_line; 
						--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
						put ("        Example: bsmcl impcad format cad/board.net"); new_line;

				elsif prog_position = "NLE00" then
						new_line;									
						put ("        Make sure path and netlist file name are correct !"); new_line; 
						--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
						put ("        Example: bsmcl impcad format cad/board.net"); new_line;

				elsif prog_position = "PLE00" then
						new_line;									
						put ("        Make sure path and partlist file name are correct !"); new_line; 
						--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
						put ("        Example: bsmcl impcad format cad/board.net cad/board.part"); new_line;

				elsif prog_position = "IPA00" then
						new_line;									
						put ("ERROR ! Partlist not specified !"); new_line; 
						--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
						put ("        Example: bsmcl impcad format cad/board.net cad/board.part"); new_line;

				elsif prog_position = "OAT00" then
						new_line;									
						put ("CANCELLED by operator !"); new_line;
						--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
						--put ("        Example: bsmcl impcad eagle5 cad/board.net cad/board.part"); new_line;

				elsif prog_position = "TPR00" then --or if prog_position = "TPN" then
						new_line(2);									
						--if prog_position "TPR" then put ("ERROR ! Test profile not specified !"); new_line; 
						--else put("ERROR : Specified test profile not supported !"); 
						put("ERROR : Test profile either not specified or not supported !"); new_line;
						put ("        Profiles available are : "); new_line;
						put ("        - infrastructure"); new_line;
						put ("        - interconnect"); new_line;									
						put ("        - memconnect"); new_line;									
						put ("        - clock"); new_line;
						put ("        - toggle"); new_line;									
						put ("        Example: bsmcl generate MMU.udb infrastructure"); new_line;
	
				elsif prog_position = "TNA00" then
						new_line;									
						put ("ERROR ! Test name not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb profile my_test_name"); new_line;

				elsif prog_position = "TDV00" then
						new_line;									
						put ("ERROR ! Target device not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb memconnect my_test_name IC202"); new_line;

				--elsif prog_position = "TOD" then
				--		new_line;									
				--		put ("ERROR ! Target device not specified !"); new_line; 
				--		put ("        Example: bsmcl generate MMU.udb toggle my_test_name IC3"); new_line;

				elsif prog_position = "DVM00" then
						new_line;									
						put ("ERROR ! Device model not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb memconnect my_test_name RAM_IC202 models/U62256.txt"); new_line;

				elsif prog_position = "DMN00" then
						new_line;									
						put ("        Make sure path and model file name are correct !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb memconnect my_test_name RAM_IC202 models/U62256.txt"); new_line;

				elsif prog_position = "DPC00" then
						new_line;									
						put ("ERROR ! Device package not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb memconnect my_test_name RAM_IC202 models/U62256.txt NDIP28"); new_line;

				elsif prog_position = "TPI00" then
						new_line;									
						put ("ERROR ! Receiver pin not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb clock my_test_name IC7 56"); new_line;

				elsif prog_position = "TON00" then
						new_line;									
						put ("ERROR ! Target net not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb toggle my_test_name SIO_CLK"); new_line;

				elsif prog_position = "RYC00" then
						new_line;									
						put ("ERROR ! Max retry count not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb clock my_test_name IC7 56 10"); new_line;

				elsif prog_position = "RDY00" then
						new_line;									
						put ("ERROR ! Retry delay (unit is sec) not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb clock my_test_name IC7 56 1 "); new_line;

				elsif prog_position = "TCT00" then
						new_line;									
						put ("ERROR ! Cycle count not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb toggle my_test_name SIO_CLK 10"); new_line;

				elsif prog_position = "TLT00" then
						new_line;									
						put ("ERROR ! Low time (unit is sec) not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb toggle my_test_name SIO_CLK 10 2"); new_line;

				elsif prog_position = "THT00" then
						new_line;									
						put ("ERROR ! High time (unit is sec) not specified !"); new_line; 
						put ("        Example: bsmcl generate MMU.udb toggle my_test_name SIO_CLK 10 2 0.5"); new_line;

				elsif prog_position = "PJN00" then
						new_line;									
						put ("ERROR ! Project name not specified !"); new_line; 
						put ("        Example: bsmcl create new_project_name"); new_line;

				elsif prog_position = "CMP00" then
						new_line;									
						put ("ERROR ! No database specified !"); new_line; 
						put ("        Example: bsmcl compile MMU.udb"); new_line;

				elsif prog_position = "CTN00" then
						new_line;									
						put ("ERROR ! Test name not specified !"); new_line; 
						put ("        Example: bsmcl compile MMU.udb my_test_name"); new_line;


				elsif prog_position = "CNE00" then
						new_line;									
						put ("ERROR : Test '"& test_name &"' has not been generated yet !"); new_line;
						put ("        Please generate test, then try again."); new_line;

				elsif prog_position = "LD100" then
						new_line;									
						put ("ERROR : Test name not specified !"); new_line;
						put ("        Example: bsmcl load my_test_name"); new_line;

				elsif prog_position = "LD200" or prog_position = "RU2" then
						new_line;									
						put ("ERROR : Test '"& test_name &"' either does not exist or has not been compiled yet !"); new_line;
						put ("        Please generate/compile test, then try again."); new_line;

				elsif prog_position = "RU100" then
						new_line;									
						put ("ERROR : Test name not specified !"); new_line;
						put ("        Example: bsmcl run my_test_name"); new_line;

				elsif prog_position = "RU400" then
						new_line;									
						put ("ERROR : Step mode not supported or invalid !"); new_line;
						put ("        Example: bsmcl run my_test_name [step_mode]"); new_line;
						put ("        Supported step modes are: ");
						for p in 0..m1_internal.step_mode_count
						loop
							put(m1_internal.type_step_mode'image(m1_internal.type_step_mode'val(p)));
							if p < m1_internal.step_mode_count then put(" , "); end if;
						end loop;
						new_line;


				elsif prog_position = "LD300" or prog_position = "RU3" or prog_position = "BP320" then
						new_line;									
						put("Measures : - Check cable connection between PC and BSC !"); new_line;
						put("           - Make sure BSC is powered on (RED 'FAIL' LED flashes) !"); new_line;					
						put("           - Push YELLOW reset button on BSC, then try again !"); new_line;															

				elsif prog_position = "ACV00" then
						new_line;
						put ("ERROR ! Too little arguments specified !"); new_line;
						put ("        Example: bsmcl mkvmod skeleton.txt your_verilog_module (without .v extension)"); new_line;  

				elsif prog_position = "BP100" then
						new_line;
						put_line ("ERROR ! Breakpoint coordinates missing or out of range !");
						put_line ("        Example to set breakpoint after sxr 6 bit 715: bsmcl break 6 715 ");
						put_line ("        Allowed ranges:");
						put_line ("           sxr id      :" & type_vector_id_breakpoint'image(type_vector_id_breakpoint'first) &
							".." & trim(type_vector_id_breakpoint'image(type_vector_id_breakpoint'last),left));
						put_line ("           bit position:" & type_sxr_break_position'image(type_sxr_break_position'first) &
							".." & trim(type_sxr_break_position'image(type_sxr_break_position'last),left));
						put_line ("        To delete the breakpoint type: bsmcl break 0");
				else
   
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & prog_position);
				end if;

-- 				new_line;
-- 				put ("PROGRAM ABORTED !"); new_line; 
-- 				put_line(prog_position);
-- 				new_line;
--				Set_Exit_Status(Failure);

end bsmcl;
