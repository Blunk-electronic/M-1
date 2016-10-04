------------------------------------------------------------------------------
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
--		procedure check_environment moved to m1_internal.adb
--
--   todo: - switch to turn of advises

with ada.text_io;				use ada.text_io;
with ada.characters.handling; 	use ada.characters.handling;
with ada.strings; 				use ada.strings;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.unbounded.text_io; use ada.strings.unbounded.text_io;
with ada.exceptions; 			use ada.exceptions;

 
with gnat.os_lib;   			use gnat.os_lib;
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;
with ada.environment_variables;

with m1_internal; 				use m1_internal;
with m1_numbers;				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;
with m1_firmware;				use m1_firmware;

procedure bsmcl is
	version			: constant string (1..3) := "025";
	prog_position	: string (1..5) := "-----";

	item_udb_class	: type_item_udbinfo;
	item_udb_name	: universal_string_type.bounded_string;

	retry_count		: type_sxr_retries;
	retry_delay		: type_delay_value;

	cycle_count		: positive; -- CS: use type_cycle_count as specified in mktoggle.adb
	low_time		: type_delay_value;
	high_time		: type_delay_value;

	result   		: integer; -- the return code of external programs

	arg_ct			: natural;
	arg_pt			: positive := 1;

	vector_id_breakpoint	: type_vector_id_breakpoint;
	bit_position			: type_sxr_break_position := 0; -- in case bit_position to break at is not provided, default used


	function exists_netlist (netlist : universal_string_type.bounded_string) return boolean is
	-- verifies if given netlist exists
		file_exists : boolean := false;	
	begin
		prog_position := "NLE00";	
		--put_line(text_name_cad_net_list & "        : " & universal_string_type.to_string(netlist));
		
		if exists (universal_string_type.to_string(netlist)) then
			file_exists := true;
		else
			put_line(message_error & text_name_cad_net_list & row_separator_0 & quote_single &
				universal_string_type.to_string(netlist) & quote_single & " not found !"); 
			raise constraint_error;
		end if;
		return file_exists;
	end exists_netlist;


	function exists_partlist (partlist : universal_string_type.bounded_string) return boolean is
	-- verifies if given partlist exists
		file_exists : boolean := false;
	begin
		prog_position := "PLE00";	
		--put_line(text_name_cad_part_list & "       : " & universal_string_type.to_string(partlist));
		
		if exists(universal_string_type.to_string(partlist)) then
			file_exists := true;
		else
			put_line(message_error & text_name_cad_net_list & row_separator_0 & quote_single &
				universal_string_type.to_string(partlist) & quote_single & " not found !"); 
			raise constraint_error;
		end if;
		return file_exists;
	end exists_partlist;



	function exists_database(database : string) return boolean is
		file_exists : boolean := false;
	begin
		--put ("database       : ");	put(database); new_line;
		if exists (database) then
			file_exists := true;
		else
			put_line(message_error & "Database " & quote_single & database & quote_single &
				" does not exist" & exclamation & row_separator_0 & aborting);
		end if;
		return file_exists;
	end exists_database;


	-- ADVISE MESSAGES BEGIN

	procedure advise_next_step_cad_import is
		begin
		put_line(done);
		put_line("Recommended next steps:");
		put_line("  1. Read header of file" & row_separator_0 & quote_single & name_file_skeleton_default & quote_single & row_separator_0 &
			"for warnings and notes with a text editor.");
		put_line("     If you have imported CAD data of a submodule, please also look into file" & row_separator_0 &
			quote_single & "skeleton_your_submodule." & file_extension_text & quote_single & dot);
		put_line("  2. Create boundary scan nets with command:" & row_separator_0 & quote_single & name_module_cli & row_separator_0 &
			name_module_mknets & quote_single);
		end advise_next_step_cad_import;

	procedure advise_next_step_generate is
	begin
		put_line(done);
		put_line("Recommended next steps:");
		ada.text_io.put_line("  1. Compile generated test using command " & quote_single & name_module_cli & row_separator_0 &
			to_lower(type_action'image(compile)) &
			row_separator_0 & universal_string_type.to_string(name_file_data_base) & row_separator_0 & 
			universal_string_type.to_string(name_test) & quote_single);
		put_line("Following steps are optional for fine tuning:");
		put_line("  2. Edit generated sequence file " & quote_single & universal_string_type.to_string(name_test) & dot & file_extension_sequence &
			quote_single & " with a text editor.");
		put_line(message_note & "On automatic test generation the sequence file will be overwritten" & exclamation);
		put_line("  3. Compile modified test sequence file.");
	end advise_next_step_generate;

	procedure advise_next_step_compile is
	begin
		put_line(done);
		put_line("Recommended next steps:");
		ada.text_io.put_line("  1. Upload compiled test to" & row_separator_0 & name_bsc & row_separator_0 & "with command " &
			quote_single & name_module_cli & row_separator_0 &
			to_lower(type_action'image(load)) & row_separator_0 &
			universal_string_type.to_string(name_test) & quote_single);
	end advise_next_step_compile;

	procedure advise_next_step_load is
	begin
		put_line(done);
		put_line("Recommended next steps:");
		ada.text_io.put_line("  1. Start test with command" & row_separator_0 &
			quote_single & name_module_cli & row_separator_0 &
			to_lower(type_action'image(run)) & row_separator_0 &
			universal_string_type.to_string(name_test) & quote_single);
	end advise_next_step_load;

	-- ADVISE MESSAGES END



	procedure write_error_no_project is
	begin
		put_line("ERROR: The current working directory is no " & name_system & " project !");
		raise constraint_error;
	end write_error_no_project;

	procedure put_format_cad is
	begin
		put_line(type_format_cad'image(format_cad));
	end put_format_cad;

	procedure put_message_on_failed_cad_import(format_cad : type_format_cad) is
	begin
		put_line(message_error & "Importing " & type_format_cad'image(format_cad) & " CAD data failed " &
			exclamation & row_separator_0 & aborting);
		raise constraint_error;
	end put_message_on_failed_cad_import;

	function launch_mknets return natural is
		result	: natural;
	begin
		spawn 
			(  
			program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_mknets),
			args                   => 	(
										1=> new string'(universal_string_type.to_string(name_file_data_base))
										),
			output_file_descriptor => standout,
			return_code            => result
			);
		return result;
	end launch_mknets;

	procedure advise_on_bsc_error is
	begin
		put_line("Measures : - Check cable connection between PC and" & row_separator_0 & name_bsc & exclamation);
		put_line("           - Make sure" & row_separator_0 & name_bsc & row_separator_0 & "is powered on" & dot);
		put_line("           - Push YELLOW reset button on front panel of" & row_separator_0 & name_bsc & row_separator_0 & "then try again !");
	end advise_on_bsc_error;


begin

	new_line;
	put_line(name_system & " Command Line Interface Version "& version);
	put_line(column_separator_2);
	check_environment;
		
	prog_position := "CRT00";
	arg_ct :=  argument_count;

	action := type_action'value(argument(1));
	put_line ("action         : " & type_action'image(action));

	case action is

		when configuration =>
			-- DISPLAY CONFIGURATION
			prog_position := "CNF00";
			put_line("directory home     : " & universal_string_type.to_string(name_directory_home));
			put_line("language           : " & type_language'image(language));
			put_line("directory bin      : " & universal_string_type.to_string(name_directory_bin));
			put_line("directory enscript : " & universal_string_type.to_string(name_directory_enscript));
			put_line("interface bsc      : " & universal_string_type.to_string(interface_to_bsc));

		when create =>
			-- MAKE PROJECT BEGIN
			prog_position := "CRT05";
			if is_project_directory then
				put_line(message_error & "The current working directory is a project already !");
				ada.text_io.put_line(message_error'length * row_separator_0 &
					"Nesting projects is not supported. Change into a valid project directory !");
				raise constraint_error;
			else
				prog_position := "PJN00";
				name_project := universal_string_type.to_bounded_string(argument(2));
				new_line;
					
				-- launch project maker
				spawn 
					(  
					program_name           => compose( universal_string_type.to_string(name_directory_bin), name_module_mkproject),
					args                   => 	(
												1=> new string'(universal_string_type.to_string(name_project))
												),
					output_file_descriptor => standout,
					return_code            => result
					);

				-- evaluate result
				case result is
					when 0 => -- then set_directory(to_string(project_name)); -- cd into project directory -- CS: does not work
						put_line(done); new_line;
						put_line("Recommended next steps :"); new_line;
						put_line("  1. Change into project directory " & quote_single & universal_string_type.to_string(name_project) & quote_single & dot);
						put_line("  2. Edit project database " & quote_single & universal_string_type.to_string(name_project) & file_extension_separator 
							& file_extension_database & "' according to your needs with a text editor.");
						put_line("  3. Import BSDL model files using command: " & quote_single & name_module_cli & row_separator_0 &
							to_lower(type_action'image(import_bsdl)) & row_separator_0 & universal_string_type.to_string(name_project) &
							file_extension_separator & file_extension_database & quote_single & dot);
					when 1 => 
						put_line(message_error & " Malfunction while creating new project " & quote_single &
							universal_string_type.to_string(name_project) & quote_single &
							row_separator_0 & exclamation & row_separator_0 & aborting);
						raise constraint_error;
					when others => 
						null;
				end case;

			end if;
			-- MAKE PROJECT END


		when import_cad =>
			-- CAD IMPORT BEGIN
			prog_position := "ICD00";
			format_cad := type_format_cad'value(argument(2));
			if is_project_directory then

				put ("CAD format     : "); put_format_cad;

				prog_position := "INE00";
				name_file_cad_net_list := universal_string_type.to_bounded_string(argument(3));

				case format_cad is
					when orcad =>
						if exists_netlist(name_file_cad_net_list) then
						
							-- launch ORCAD importer
							new_line;
							spawn 
								(  
								program_name           => compose( universal_string_type.to_string(name_directory_bin), name_module_cad_importer_orcad),
								args                   => 	(
															1=> new string'(universal_string_type.to_string(name_file_cad_net_list))
															),
								output_file_descriptor => standout,
								return_code            => result
								);

							if result = 0 then
								advise_next_step_cad_import;
							else
								put_message_on_failed_cad_import(format_cad);
							end if;
						end if;

					when altium =>
						if exists_netlist(name_file_cad_net_list) then

							-- launch ALTIUM importer
							new_line;
							spawn 
								(  
								program_name           => compose( universal_string_type.to_string(name_directory_bin), name_module_cad_importer_altium),
								args                   => 	(
															1=> new string'(universal_string_type.to_string(name_file_cad_net_list))
															),
								output_file_descriptor => standout,
								return_code            => result
								);

							if result = 0 then
								advise_next_step_cad_import;
							else
								put_message_on_failed_cad_import(format_cad);
							end if;
						end if;

					when zuken =>
						if exists_netlist(name_file_cad_net_list) then
					
							-- launch ZUKEN importer
							new_line;
							Spawn 
								(  
								program_name           => compose( universal_string_type.to_string(name_directory_bin), name_module_cad_importer_zuken),
								Args                   => 	(
															1=> new String'(universal_string_type.to_string(name_file_cad_net_list))
															),
								Output_File_Descriptor => Standout,
								Return_Code            => Result
								);

							if result = 0 then
								advise_next_step_cad_import;
							else
								put_message_on_failed_cad_import(format_cad);
							end if;
						end if;


					when eagle =>
						if exists_netlist(name_file_cad_net_list) then
							prog_position := "IPA00";
							name_file_cad_part_list := universal_string_type.to_bounded_string(argument(4));
							if exists_partlist(name_file_cad_part_list) then

								-- launch EAGLE importer
								new_line;
								spawn 
									(  
									program_name           => compose( universal_string_type.to_string(name_directory_bin), name_module_cad_importer_eagle),
									args                   => 	(
																1=> new string'(universal_string_type.to_string(name_file_cad_net_list)),
																2=> new string'(universal_string_type.to_string(name_file_cad_part_list))
																),
									output_file_descriptor => standout,
									return_code            => result
									);

								if result = 0 then
									advise_next_step_cad_import;
								else
									put_message_on_failed_cad_import(format_cad);
								end if;
							end if;
						end if;

				end case;

			else
				write_error_no_project;
			end if;
			-- CAD IMPORT END


		when mkvmod =>
			-- MAKE VERILOG MODEL BEGIN
			if is_project_directory then

				prog_position := "ACV00";
				name_file_skeleton := universal_string_type.to_bounded_string(argument(2));
				name_file_model_verilog := universal_string_type.to_bounded_string(argument(3));
										
				-- LAUNCH VERILOG MODEL MAKER
				spawn 
					(  
					program_name           => compose( universal_string_type.to_string(name_directory_bin), name_module_mkvmod),
					args                   => 	(
												1=> new string'(universal_string_type.to_string(name_file_skeleton)),
												2=> new string'(universal_string_type.to_string(name_file_model_verilog))
												),
					output_file_descriptor => standout,
					return_code            => result
					);

				if result = 0 then
					put_line(done);
					put_line("Recommended next step : Edit Verilog Model according to your needs.");
				else
					put_line(message_error & "Writing Verilog model file failed" & exclamation & row_separator_0 & aborting);
					raise constraint_error;
				end if;
			else
				write_error_no_project;
			end if;
			-- MAKE VERILOG MODEL END


		when join_netlist =>
			-- JOIN NETLIST BEGIN
			if is_project_directory then

				prog_position := "JSM00";
				name_file_skeleton_submodule := universal_string_type.to_bounded_string(argument(2));

				if not exists(universal_string_type.to_string(name_file_skeleton_submodule)) then
					prog_position := "JSN00";
					put_line(message_error & "Skeleton of submodule " & quote_single &
						universal_string_type.to_string(name_file_skeleton_submodule) & quote_single & " does not exist " & exclamation);
					raise constraint_error;
				else
					null;
					--put_line("submodule      : " & universal_string_type.to_string(name_file_skeleton_submodule));
				end if;
										
				-- check if skeleton main file exists
				if not exists("skeleton.txt") then
					put_line(message_error & "No main module " & quote_single & name_file_skeleton_default & quote_single & " found " & exclamation);
					ada.text_io.put_line(message_error'last * row_separator_0 & "It appears you have not imported any CAD data yet. Please import CAD data now.");
					ada.text_io.put_line(message_error'last * row_separator_0 & message_example & row_separator_0 & name_module_cli & row_separator_0 & 
						to_lower(type_action'image(import_cad)) & " format_cad netlist [partlist]");
					prog_position := "SMN00";
					raise constraint_error;
				end if;
										
				-- launch netlist joiner
				spawn 
					(  
					program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_join_netlist),
					args                   => 	(
												1=> new string'(universal_string_type.to_string(name_file_skeleton_submodule))
												),
					output_file_descriptor => standout,
					return_code            => result
					);

				if result = 0 then
					put_line(done);
					put_line("Recommended next step :");
					put_line("  1. Create boundary scan nets using command: " & quote_single & name_module_cli & row_separator_0
						& name_module_mknets & quote_single);
				else
					put_line(message_error & "Joining netlists failed" & exclamation & aborting);
					raise constraint_error;
				end if;

			else
				write_error_no_project;
			end if;
		-- JOIN NETLIST END 


		when import_bsdl =>
		-- BSDL IMPORT BEGIN
			if is_project_directory then

				prog_position := "IBL00";
				name_file_data_base := universal_string_type.to_bounded_string(argument(2));

				-- check if udb file exists
				prog_position := "IBL10";
				if not exists_database(universal_string_type.to_string(name_file_data_base)) then
					raise constraint_error;
				end if;
									
				-- launch BSDL importer
				spawn 
					(  
					program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_importer_bsdl),
					args                   => 	(
												1=> new string'(universal_string_type.to_string(name_file_data_base))
												),
					output_file_descriptor => standout,
					return_code            => result
					);

				if result = 0 then
					put_line(done);
					put_line("Recommended next step :");
					put_line("  1. Import CAD data files using command: " & quote_single & name_module_cli & row_separator_0
						& to_lower(type_action'image(import_cad)) & " format_cad" & quote_single);
				else
					put_line(message_error & "Importing BSDL files failed" & exclamation & row_separator_0 & aborting);
					raise constraint_error;
				end if;

			else
				write_error_no_project;
			end if;
		-- BSDL IMPORT END


		when mknets =>
		-- MKNETS BEGIN
			if is_project_directory then
				prog_position := "MKN00";
				name_file_data_base := universal_string_type.to_bounded_string(argument(2));

				-- check if udb file exists
				prog_position := "MKN10";
				if not exists_database(universal_string_type.to_string(name_file_data_base)) then
					raise constraint_error;
				end if;

				-- launch MKNETS
				if launch_mknets = 0 then
					put_line(done);
					put_line("Recommended next step:");
					put_line("  1. Edit configuration file " & quote_single & name_file_mkoptions_configuration & quote_single);
					put_line("  2. Create options file for database " & quote_single &
						universal_string_type.to_string(name_file_data_base) & quote_single & " using command " &
						quote_single & name_module_cli & row_separator_0 & to_lower(type_action'image(mkoptions)) & row_separator_0 &
						universal_string_type.to_string(name_file_data_base) & row_separator_0 &
						compose(name => "[options_file", extension => file_extension_options) & "]" & quote_single);
						--put("  2. Edit options file according to your needs using a text editor."); new_line;
						--put("  3. Import BSDL model files using command: 'bsmcl impbsdl " & project_name & ".udb'"); new_line;
				else
					put_line(message_error & "Building bscan nets failed" & exclamation & row_separator_0 & aborting);
					raise constraint_error;
				end if;
			else
				write_error_no_project;
			end if;
		-- MKNETS END


		when mkoptions =>
		-- MKOPTIONS BEGIN
			if is_project_directory then
				prog_position := "MKO00";
				name_file_data_base := universal_string_type.to_bounded_string(argument(2));

				-- check if udb file exists
				prog_position := "MKO10";
				if not exists_database(universal_string_type.to_string(name_file_data_base)) then
					raise constraint_error;
				end if;

				-- If the name of the options file not specified by operator, use default name.
				if arg_ct = 2 then
					name_file_options := universal_string_type.to_bounded_string
						(
						compose(
							name 		=> base_name(universal_string_type.to_string(name_file_data_base)),
							extension 	=> file_extension_options
							)
						);
				else
					name_file_options := universal_string_type.to_bounded_string(argument(3)); 
					-- NOTE: the opt file given will be created by mkoptions
				end if;

				-- relaunch MKNETS (resets udb to inital state equal to the state after BSDL importing)
				put_line("relaunching " & name_module_mknets & "...");
				if launch_mknets = 0 then
					put_line(done);
				else
					put_line(message_error & "Building bscan nets failed" & exclamation & row_separator_0 & aborting);
					raise constraint_error;
				end if;

				-- launch MKOPTIONS
				spawn 
					(  
					program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_mkoptions),
					args                   => 	(
												1=> new string'(universal_string_type.to_string(name_file_data_base)),
												2=> new String'(universal_string_type.to_string(name_file_options))
												),
					output_file_descriptor => standout,
					return_code            => result
					);

				if result = 0 then
					put_line(done);
					put_line("Recommended next step:");
					put_line(" 1. Edit options file" & row_separator_0 & quote_single & universal_string_type.to_string(name_file_options) &
						quote_single & " according to your needs with a text editor.");
					put_line(" 2. Check primary/secondary dependencies and net classes using command " & quote_single & name_module_cli &
						row_separator_0 & to_lower(type_action'image(chkpsn)) & row_separator_0 & universal_string_type.to_string(name_file_data_base) &
						row_separator_0 & universal_string_type.to_string(name_file_options) & quote_single);
				else
					put_line(message_error & "Creating options file failed" & exclamation & row_separator_0 & aborting);
					raise constraint_error;
				end if;

			else
				write_error_no_project;
			end if;
		-- MKOPTIONS END


		when chkpsn =>
		-- CHKPSN BEGIN
			if is_project_directory then

				prog_position := "CP100";
				name_file_data_base := universal_string_type.to_bounded_string(argument(2));

				-- check if udb file exists
				prog_position := "CPO10";
				if not exists_database(universal_string_type.to_string(name_file_data_base)) then
					raise constraint_error;
				end if;

				-- derive name of options file from given database
				prog_position := "CPO20";
				name_file_options := universal_string_type.to_bounded_string
					(
					compose
						(
						name 		=> base_name(universal_string_type.to_string(name_file_data_base)),
						extension	=> file_extension_options
						)
					); 

				-- check if options file exists
				if not exists(universal_string_type.to_string(name_file_options)) then
					put_line(message_error & "Options file " & quote_single &
						universal_string_type.to_string(name_file_options) & quote_single & " does not exist " & exclamation);
					raise constraint_error;
				end if;

				-- relaunch MKNETS
				put_line("relaunching " & name_module_mknets & "...");
				if launch_mknets = 0 then
					put_line(done);
				else
					put_line(message_error & "Building bscan nets failed" & exclamation & row_separator_0 & aborting);
					raise constraint_error;
				end if;

				-- launch CHKPSN
				spawn 
					(  
					program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_chkpsn),
					args                   => 	(
												1=> new string'(universal_string_type.to_string(name_file_data_base)),
												2=> new String'(universal_string_type.to_string(name_file_options))
												),
					output_file_descriptor => standout,
					return_code            => result
					);

				if result = 0 then
					put_line(done);
					put_line("Recommended next steps:");
					put_line("  1. Edit file '" & name_directory_setup_and_templates & name_directory_separator & name_file_test_init_template & "' with a text editor.");
					put_line("     to prepare your test init sequence.");
					put_line("  2. Generate tests using command " & quote_single & name_module_cli & 
						row_separator_0 & to_lower(type_action'image(generate)) & row_separator_0 
						& universal_string_type.to_string(name_file_data_base) & quote_single);
				else
					put_line(message_error & "Checking net classes and dependencies failed" & exclamation & row_separator_0 & aborting);
					raise constraint_error;
				end if;
			else
				write_error_no_project;
			end if;
		-- CHKPSN END

		when udbinfo =>
		-- QUERY UUT DATA BASE ITEM BEGIN
			if is_project_directory then
				prog_position := "UDQ00";
				name_file_data_base := universal_string_type.to_bounded_string(argument(2));

				-- check if udb file exists
				prog_position := "UDQ10";
				if not exists_database(universal_string_type.to_string(name_file_data_base)) then
					raise constraint_error;
				end if;

				prog_position := "UDQ20";
				item_udb_class := type_item_udbinfo'value(argument(3));

				prog_position := "UDQ30";
				item_udb_name := universal_string_type.to_bounded_string(argument(4));

				spawn 
					(  
					program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_data_base_query),
					args                   => 	(
												1=> new string'(universal_string_type.to_string(name_file_data_base)),
												2=> new string'(type_item_udbinfo'image(item_udb_class)),
												3=> new string'(universal_string_type.to_string(item_udb_name))
												),
					output_file_descriptor => standout,
					return_code            => result
					);

				case result is
					when 0 => null; -- item found, everything is fine
					when 2 => put_line(message_error & "Item not found" & exclamation & row_separator_0 &
						"Check spelling and capitalization !"); 
					when others =>
						put_line(message_error & "Data base query failed" & exclamation);
						raise constraint_error;
				end case;

			end if;
		-- QUERY UUT DATA BASE ITEM END


		when generate =>
		-- TEST GENERATION BEGIN
			if is_project_directory then
				prog_position := "GEN00";
				name_file_data_base := universal_string_type.to_bounded_string(argument(2));

				-- check if udb file exists
				prog_position := "GEN10";
				if not exists_database(universal_string_type.to_string(name_file_data_base)) then
					raise constraint_error;
				end if;

				prog_position := "GEN20";
				test_profile := type_test_profile'value(argument(3));
				put_line("test profile   : " & type_test_profile'image(test_profile)); new_line;

				prog_position := "GEN30";
				name_test :=  universal_string_type.to_bounded_string(strip_trailing_forward_slash(argument(4)));

				case test_profile is
					when infrastructure =>
						-- launch INFRASTRUCTURE TEST GENERATOR
						spawn 
							(  
							program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_mkinfra),
							args                   => 	(
														1=> new string'(universal_string_type.to_string(name_file_data_base)),
														2=> new String'(universal_string_type.to_string(name_test))
														),
							output_file_descriptor => standout,
							return_code            => result
							);

						if result = 0 then 
							advise_next_step_generate;							
						else
							put_line(message_error & "Generating test failed" & exclamation & row_separator_0 & aborting);
							raise constraint_error;
						end if;

					when interconnect =>
						-- launch INTERCONNECT TEST GENERATOR
						spawn 
							(  
							program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_mkintercon),
							args                   => 	(
														1=> new string'(universal_string_type.to_string(name_file_data_base)),
														2=> new String'(universal_string_type.to_string(name_test))
														),
							output_file_descriptor => standout,
							return_code            => result
							);

						if result = 0 then 
							advise_next_step_generate;							
						else
							put_line(message_error & "Generating test failed" & exclamation & row_separator_0 & aborting);
							raise constraint_error;
						end if;
				
					when memconnect =>
						prog_position := "TDV00";
						target_device := universal_string_type.to_bounded_string(argument(5));
						
						prog_position := "DVM00";
						name_file_model_memory := universal_string_type.to_bounded_string(argument(6));
						
						-- check if model file exists
						prog_position := "DVM10";
						if not exists(universal_string_type.to_string(name_file_model_memory)) then
							put_line(message_error & "Model file " & quote_single &
								universal_string_type.to_string(name_file_model_memory) & quote_single & " does not exist " & exclamation);
							raise constraint_error;
						end if;
						
						prog_position := "DPC00";
						device_package := universal_string_type.to_bounded_string(argument(7));

						-- launch memconnect generator
						prog_position := "LMC00"; -- ins v018

						-- launch MEMCONNECT TEST GENERATOR
						spawn 
							(  
							program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_mkmemcon),
							args                   => 	(
														1=> new string'(universal_string_type.to_string(name_file_data_base)),
														2=> new string'(universal_string_type.to_string(name_test)),
														3=> new string'(universal_string_type.to_string(target_device)),
														4=> new string'(universal_string_type.to_string(name_file_model_memory)),
														5=> new string'(universal_string_type.to_string(device_package))
														),
							output_file_descriptor => standout,
							return_code            => result
							);

						if result = 0 then 
							advise_next_step_generate;
						else
							put_line(message_error & "Generating test failed" & exclamation & row_separator_0 & aborting);
							raise constraint_error;
						end if;


					when clock =>
						prog_position := "TDV00";					
						target_device := universal_string_type.to_bounded_string(argument(5));
						
						prog_position := "TPI00";
						target_pin := universal_string_type.to_bounded_string(argument(6));
						
						prog_position := "RYC00";
						retry_count := type_sxr_retries'value(argument(7));

						prog_position := "RDY00";				
						retry_delay := type_delay_value'value(argument(8));

						-- launch CLOCK SAMPLING GENERATOR
						spawn 
							(  
							program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_mkclock),
							args                   => 	(
														1=> new string'(universal_string_type.to_string(name_file_data_base)),
														2=> new string'(universal_string_type.to_string(name_test)),
														3=> new string'("non_intrusive"), -- CS: global type_algorithm ? so far every test has its own type
														4=> new string'(universal_string_type.to_string(target_device)),
														5=> new string'(universal_string_type.to_string(target_pin)),
														6=> new string'(type_sxr_retries'image(retry_count)),
														7=> new string'(type_delay_value'image(retry_delay))
														),
							output_file_descriptor => standout,
							return_code            => result
							);

						if result = 0 then
							advise_next_step_generate;
						else
							put_line(message_error & "Generating test failed" & exclamation & row_separator_0 & aborting);
							raise constraint_error;
						end if;


					when toggle =>
						prog_position := "TON00";
						target_net := universal_string_type.to_bounded_string(argument(5));
						
						prog_position := "TOC00";
						cycle_count:= positive'value(argument(6));
						
						prog_position := "TLT00";				
						low_time:= type_delay_value'value(argument(7));

						prog_position := "THT00";				
						high_time:= type_delay_value'value(argument(8));

						-- launch PIN TOGGLE GENERATOR
						spawn 
							(  
							program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_mktoggle),
							args                   => 	(
														1=> new string'(universal_string_type.to_string(name_file_data_base)),
														2=> new string'(universal_string_type.to_string(name_test)),
														3=> new string'(universal_string_type.to_string(target_net)),
														4=> new string'(positive'image(cycle_count)),
														5=> new string'(type_delay_value'image(low_time)),
														6=> new string'(type_delay_value'image(high_time))
														),
							output_file_descriptor => standout,
							return_code            => result
							);

						if result = 0 then
							advise_next_step_generate;
						else
							put_line(message_error & "Generating test failed" & exclamation & row_separator_0 & aborting);
							raise constraint_error;	
						end if;

				end case;

			else
				write_error_no_project;
			end if;
		-- TEST GENERATION END


		when compile =>
		-- TEST COMPILATION BEGIN
			if is_project_directory then
				prog_position := "CMP00";
				name_file_data_base := universal_string_type.to_bounded_string(argument(2));
				-- CS: derive database name from sequence file info section

				-- check if udb file exists
				prog_position := "CMP10";
				if not exists_database(universal_string_type.to_string(name_file_data_base)) then
					raise constraint_error;
				end if;
							
				prog_position := "CMP20";
				name_test := universal_string_type.to_bounded_string(strip_trailing_forward_slash(argument(3)));

				prog_position := "CMP30";
				-- check if test directory containing the seq file exists
				if exists
					(
					compose
						(
						universal_string_type.to_string(name_test), -- test directory
						universal_string_type.to_string(name_test), -- sequence file
						file_extension_sequence	-- sequence file extension
						)
					) then

					-- launch COMPILER
						spawn 
							(  
							program_name           => compose ( universal_string_type.to_string(name_directory_bin), name_module_compiler),
							args                   => 	(
														1=> new string'(universal_string_type.to_string(name_file_data_base)),
														2=> new string'(universal_string_type.to_string(name_test))
													),
						output_file_descriptor => standout,
						return_code            => result
						);

					if result = 0 then 
						advise_next_step_compile;
					else
						put_line(message_error & "Compiling test failed" & exclamation & row_separator_0 & aborting);
						raise constraint_error;	
					end if;

				else
					put_line(message_error & "Test " & quote_single & universal_string_type.to_string(name_test) & quote_single &
						" incomplete or does not exist !");
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
				name_test := universal_string_type.to_bounded_string(strip_trailing_forward_slash(argument(2)));

				prog_position := "LD105";
				-- check if test directory containing the compiled sequence file (vec) exists
				if exists
					(
					compose
						(
						universal_string_type.to_string(name_test), -- test directory
						universal_string_type.to_string(name_test), -- sequence file
						file_extension_vector	-- sequence file extension
						)
					) then

					if load_test 
						(
						test_name					=> universal_string_type.to_string(name_test),
						interface_to_scan_master	=> universal_string_type.to_string(interface_to_bsc),
						directory_of_binary_files	=> universal_string_type.to_string(name_directory_bin)
						) then
						advise_next_step_load;
					else
						prog_position := "LD120";
						put_line(message_error & "Test upload to" & row_separator_0 & name_bsc &
							row_separator_0 & "failed" & exclamation);
						advise_on_bsc_error;
						raise constraint_error;
					end if;

				else
					put_line(message_error & "Test " & quote_single & universal_string_type.to_string(name_test) & quote_single &
						" not compiled yet or does not exist !");
					raise constraint_error;
				end if;
			else
				write_error_no_project;
			end if;
		-- TEST LOADING END


		when dump =>
		-- RAM DUMP BEGIN
			prog_position := "DP100";
			mem_address_page := string_to_natural(argument(2)); -- page address bits [23:8]

			if dump_ram
				(
				interface_to_scan_master 	=> universal_string_type.to_string(interface_to_bsc),
				directory_of_binary_files	=> universal_string_type.to_string(name_directory_bin),
				mem_addr_page				=> mem_address_page
				) then
				null;
			else
				put_line(message_error & "Test upload to" & row_separator_0 & name_bsc & row_separator_0 & "failed" & exclamation);
				advise_on_bsc_error;
				raise constraint_error;
			end if;
		-- RAM DUMP END


		when clear =>
		-- RAM CLEAR BEGIN
			prog_position := "CLR10";
			if clear_ram
				(
				interface_to_scan_master 	=> universal_string_type.to_string(interface_to_bsc),
				directory_of_binary_files	=> universal_string_type.to_string(name_directory_bin)
				) then
				put_line(name_bsc & " memory cleared. Please upload compiled tests now.");
			else
				put_line(message_error & "Clearing memory failed" & exclamation);
				advise_on_bsc_error;
				raise constraint_error;
			end if;
		-- RAM CLEAR END


		when run =>
		-- TEST/STEP EXECUTION BEGIN
			if is_project_directory then
				prog_position := "RU100";
				name_test := universal_string_type.to_bounded_string(strip_trailing_forward_slash(argument(2)));

				-- optionally the step mode is given:
				if arg_ct = 3 then
					prog_position := "RU400";
					step_mode := type_step_mode'value(argument(3));
				end if;
				
				-- Remove stale result file (in temp directory) from previous runs.
				delete_result_file;

				-- check if test exists
				prog_position := "RU110";
				if exists
					(
					compose
						(
						universal_string_type.to_string(name_test), -- test directory
						universal_string_type.to_string(name_test), -- sequence file
						file_extension_vector	-- sequence file extension
						)
					) then

					-- launch test
					prog_position := "RU300";
					case execute_test
						(
						test_name 					=> universal_string_type.to_string(name_test),
						interface_to_scan_master 	=> universal_string_type.to_string(interface_to_bsc),
						directory_of_binary_files	=> universal_string_type.to_string(name_directory_bin),
						step_mode					=> step_mode

						) is
						-- CS: distinguish between executed step and test !

						-- Depending on the test result (fail or pass) a temp file is created that holds the single word PASSED or FAILED.
						-- The gui needs this file in order to updae the status image to PASS or FAIL
						when pass =>
							new_line;
							put_line("Test/Step" & row_separator_0 & universal_string_type.to_string(name_test) & row_separator_0 & passed);
							make_result_file(passed);
						when fail =>
							new_line;
							put_line("Test/Step" & row_separator_0 & universal_string_type.to_string(name_test) & row_separator_0 & failed);
							make_result_file(failed);
							set_exit_status(failure);
						when not_loaded =>
							put_line(message_error & "Test data invalid or not uploaded yet. Please upload test.");
							make_result_file(failed);
							set_exit_status(failure);
						when others =>
							put_line(message_error & "Internal malfunction" & exclamation);
							put_line("Test/Step" & row_separator_0 & universal_string_type.to_string(name_test) & row_separator_0 & failed);
							advise_on_bsc_error;
							make_result_file(failed);
							set_exit_status(failure);
					end case;

				else 
					put_line(message_error & "Test" & row_separator_0 & quote_single & universal_string_type.to_string(name_test) & quote_single &
						row_separator_0 & "does not exist" & exclamation);
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

				-- If vector_id_breakpoint greater zero, a breakpoint is to set. In this case a third argument may be 
				-- given if a certain bit position is to halt after. Otherwise bit_position assumes zero.
				if vector_id_breakpoint /= 0 then
					if arg_ct = 3 then
						bit_position := type_sxr_break_position'value(argument(3));
					end if;
				end if;

				prog_position := "BP300";
				case set_breakpoint
					(
					interface_to_scan_master 	=> universal_string_type.to_string(interface_to_bsc),
					directory_of_binary_files	=> universal_string_type.to_string(name_directory_bin),
					vector_id_breakpoint		=> vector_id_breakpoint,
					bit_position				=> bit_position
					) is
					when true => -- setting breakpoint successful:
						case vector_id_breakpoint is
							when 0 => 
								put_line("breakpoint removed");
							when others =>
								put_line("breakpoint set after ");
								put_line("sxr id         : " & trim(type_vector_id_breakpoint'image(vector_id_breakpoint),left));
								if bit_position /= 0 then
									put_line ("bit position   : " & trim(type_sxr_break_position'image(bit_position),left));
								end if;
						end case;

					when others =>
						put_line(message_error & "Setting breakpoint failed" & exclamation);
						advise_on_bsc_error;
						raise constraint_error;
				end case;
			else
				write_error_no_project;
			end if;
		-- SET BREAKPOINT END


		-- test start begin
		-- DOES NOT WAIT FOR TEST END
		-- CS: CURRENTLY THERE IS NO NEED TO DO SUCH A THING !!!


		when status =>
		-- QUERY BSC STATUS BEGIN
			prog_position := "QS100";
			-- status can be inquired anytime anywhere
			case query_status
				(
				interface_to_scan_master 	=> universal_string_type.to_string(interface_to_bsc),
				directory_of_binary_files	=> universal_string_type.to_string(name_directory_bin)
				) is
				when false => 
					put_line(message_error & name_bsc & " status query failed" & exclamation);
					advise_on_bsc_error;
					raise constraint_error;
				when others => null;
			end case;
		-- QUERY BSC STATUS END

		when firmware =>
		-- QUERY FIRMWARE BEGIN
			prog_position := "FW000";
			case show_firmware
				(
				interface_to_scan_master	=> universal_string_type.to_string(interface_to_bsc),
				directory_of_binary_files	=> universal_string_type.to_string(name_directory_bin)
				) is
				when false => 
					put_line(message_error & name_bsc & " firmware query failed" & exclamation);
					advise_on_bsc_error;
					raise constraint_error;
				when others => null;
			end case;
		-- QUERY FIRMWARE END

		when off =>
		-- UUT POWER DOWN BEGIN
			prog_position := "SDN01";
			delete_result_file; -- Remove stale result file (in temp directory) from previous runs.
			case shutdown
				(
				interface_to_scan_master 	=> universal_string_type.to_string(interface_to_bsc),
				directory_of_binary_files	=> universal_string_type.to_string(name_directory_bin)
				) is
				when false =>
					new_line;
					put_line(message_error & "   UUT SHUTDOWN FAILED" & exclamation);
					put_line(message_warning & " UUT NOT POWERED OFF" & exclamation);
					advise_on_bsc_error;
					raise constraint_error;
				when true =>
					new_line;
					put_line("UUT has been shut down ! Scanports disconnected !");
					put_line("Test" & row_separator_0 & failed);
					make_result_file(failed); -- Create temp file that holds the single word FAILED.
						-- The gui needs this file in order to updae the status image to FAIL.

			end case;
		-- UUT POWER DOWN END


-- 		when report => CS:
-- 		-- VIEW TEST REPORT BEGIN
-- 			if is_project_directory then
-- 				prog_position := "-----";
-- 				
-- 				-- check if test exists
-- 				if exists ("test_sequence_report.txt") then
-- 					--put ("creating PDF test report of "); new_line;
-- 					put ("PDF file name  : ");	put(Containing_Directory("proj_desc.txt") & "/test_sequence_report.pdf"); new_line;
-- 					
-- 					-- convert report txt file to pdf
-- 					Spawn 
-- 						(  
-- 						Program_Name           => to_string(directory_of_enscript) & "/enscript", -- -p last_run.pdf last_run.txt",
-- 						Args                   => 	(
-- 													1=> new String'("-p"),
-- 													2=> new String'("test_sequence_report.pdf"),
-- 													3=> new String'("test_sequence_report.txt")
-- 													),
-- 						Output_File_Descriptor => Standout,
-- 						Return_Code            => Result
-- 						);
-- 					-- evaluate result
-- 					if 
-- 						Result = 0 then put("done"); new_line;
-- 					elsif
-- 						Result = 1 then put("FAILED !"); new_line;
-- 						Set_Exit_Status(Failure);
-- 					else
-- 						prog_position := "-----";					
-- 	-- 					put("ERROR    : Malfunction while executing test '"& test_name &"' ! Aborting ..."); new_line;
-- 	-- 					put("code     :"); put(Result); new_line; 
-- 						raise constraint_error;
-- 					end if;
-- 
-- 
-- 					-- open pdf report
-- 					Spawn 
-- 						(  
-- 						Program_Name           => 	to_string(directory_of_binary_files) & "/open_report", -- "/usr/bin/okular", -- -p last_run.pdf last_run.txt",
-- 						Args                   => 	(
-- 													1=> new String'("test_sequence_report.pdf")
-- 													--2=> new String'("1>/dev/null") -- CS: suppress useless output of okular
-- 													--3=> new String'("last_run.txt")
-- 													),
-- 						Output_File_Descriptor => Standout,
-- 						Return_Code            => Result
-- 						);
-- 					-- evaluate result
-- 					if 
-- 						Result = 0 then put("done"); new_line;
-- 					elsif
-- 						Result = 1 then put("FAILED !"); new_line;
-- 						Set_Exit_Status(Failure);
-- 					else
-- 						prog_position := "-----";					
-- 	-- 					put("ERROR    : Malfunction while executing test '"& test_name &"' ! Aborting ..."); new_line;
-- 	-- 					put("code     :"); put(Result); new_line; 
-- 						raise constraint_error;
-- 					end if;
-- 
-- 
-- 				else 
-- 					prog_position := "-----";
-- 					raise constraint_error;
-- 				end if;
-- 			else
-- 				write_error_no_project;
-- 			end if;
-- 		-- VIEW TEST REPORT END

	end case;
   

	exception
		when event: 
			others =>
				set_exit_status(failure);
				set_output(standard_output);

				if prog_position = "ENV10" then
					put_line(message_error & "No configuration file " & quote_single & name_file_configuration & quote_single &
					" found" & exclamation);

				elsif prog_position = "CRT00" then
					put_line(message_error & "Action missing or invalid" & exclamation & row_separator_0 & "What do you want to do ? Actions available:");
					for a in 0..type_action'pos(type_action'last) loop
						put(to_lower(type_action'image(type_action'val(a))));
						-- CS: add line break after 5 items
						if a < type_action'pos(type_action'last) then put(" , "); end if;
					end loop;
-- 
-- 										put ("        - create       (set up a new project)"); new_line;
-- 										put ("        - import_cad   (import net and part lists from CAD system)"); new_line;
-- 										put ("        - join_netlist (merge submodule with mainmodule after CAD import)"); new_line;									
-- 										put ("        - import_bsdl  (import BSDL models)"); new_line;
-- 										put ("        - mknets       (make boundary scan nets)"); new_line;
-- 										put ("        - mkoptions    (generate options file template)"); new_line;									
-- 										put ("        - chkpsn       (check entries made by operator in options file)"); new_line;
-- 										put ("        - generate     (generate a test with a certain profile)"); new_line;
-- 										put ("        - compile      (compile a test)"); new_line;
-- 										put ("        - load         (load a compiled test into the Boundary Scan Controller)"); new_line;
-- 										put ("        - clear        (clear entire RAM of the Boundary Scan Controller)"); new_line;
-- 										put ("        - dump         (view a RAM section of the Boundary Scan Controller (use for debugging only !))"); new_line;
-- 										put ("        - run          (run a test/step on your UUT/target and WAIT until test done)"); new_line;
-- 										put ("        - break        (set break point at step ID and bit position)"); new_line;
-- 										put ("        - off          (immediately stop a running test, shut down UUT power and disconnect TAP signals)"); new_line;
-- 										put ("        - status       (query Boundary Scan Controller status)"); new_line;
-- 										--put ("        - report       (view the latest sequence execution results)"); new_line;	
-- 										put ("        - mkvmod       (create verilog model port list from main module skeleton.txt)"); new_line;
-- 										put ("        - help         (get examples and assistance)"); new_line;
-- 										put ("        - udbinfo      (get firmware versions)"); new_line;
-- 										--put ("        Example: bsmcl" & action_set_breakpoint); new_line;
									
				elsif prog_position = "UDQ00" then
						put_line(message_error & "No database specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(udbinfo)) & row_separator_0 &
							compose(name => "your_database", extension => file_extension_database));

				elsif prog_position = "UDQ20" then
						put_line(message_error & "Invalid item specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(udbinfo)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 & 
							to_lower(type_item_udbinfo'image(bic)));
						ada.text_io.put(message_error'last * row_separator_0 & "Items to inquire for are:" & row_separator_0);

						-- show available items to inqure for
						for i in 0..type_item_udbinfo'pos( type_item_udbinfo'last) loop
							put(type_item_udbinfo'image(type_item_udbinfo'val(i)));
							if i < type_item_udbinfo'pos( type_item_udbinfo'last) then put(" , "); end if;
						end loop;

				elsif prog_position = "UDQ30" then
						put_line(message_error & "Item name not specified" & exclamation);
						ada.text_io.put(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(udbinfo)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 & 
							to_lower(type_item_udbinfo'image(item_udb_class)) & row_separator_0);
						case item_udb_class is
							when BIC => 		put_line("IC303");
							--when REGISTER =>	put_line("IC303");
							when NET =>			put_line("OSC_OUT");
							--when PIN =>			put_line("IC303#3");
							when SCC =>			put_line("IC303#4");
						end case;
						
				elsif prog_position = "IBL00" then
						put_line(message_error & "No database specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(import_bsdl)) & row_separator_0 &
							compose(name => "your_database", extension => file_extension_database));
	
				elsif prog_position = "MKN00" then
						put_line(message_error & "No database specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(mknets)) & row_separator_0 &
							compose(name => "your_database", extension => file_extension_database));
	
				elsif prog_position = "JSM00" then
					put_line(message_error & "No submodule specified !");
					ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli &
						row_separator_0 & to_lower(type_action'image(join_netlist)) & row_separator_0 &
						compose(name => "skeleton_submodule", extension => file_extension_text));
	
				elsif prog_position = "MKO00" then
						put_line(message_error & "No database specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(mkoptions)) & row_separator_0 &
							compose(name => "your_database", extension => file_extension_database) & row_separator_0 &
							compose(name => "[options_file", extension => file_extension_options) & "]");
	
				elsif prog_position = "CP100" then
						put_line(message_error & "No database specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(chkpsn)) & row_separator_0 &
							compose(name => "your_database", extension => file_extension_database));
	
				elsif prog_position = "GEN00" then
						put_line(message_error & "No database specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							compose(name => "your_database", extension => file_extension_database));
					
				elsif prog_position = "ICD00" then
						new_line;									
						put_line(message_error & "CAD format not supported or missing" & exclamation & row_separator_0 & "Supported formats are :");
						for f in 0..type_format_cad'pos(type_format_cad'last) loop
							put(to_lower(type_format_cad'image(type_format_cad'val(f))));
							-- CS: add line break after 5 items
							if f < type_format_cad'pos(type_format_cad'last) then put(" , "); end if;
						end loop;
						new_line;
						put_line(message_example & name_module_cli &
							row_separator_0 & to_lower(type_action'image(import_cad)) & row_separator_0 & 
							to_lower(type_format_cad'image(zuken)));
	
				elsif prog_position = "INE00" then
						put_line(message_error & text_name_cad_net_list & " not specified " & exclamation);
						ada.text_io.put_line(message_error'length * row_separator_0 & message_example & name_module_cli &
							row_separator_0 & to_lower(type_action'image(import_cad)) & row_separator_0 & 
							to_lower(type_format_cad'image(format_cad)) & row_separator_0 &
							compose(containing_directory => name_directory_cad, name => "board", extension => "net"));

				elsif prog_position = "IPA00" then
						put_line(message_error & text_name_cad_part_list & " not specified " & exclamation);
						ada.text_io.put_line(message_error'length * row_separator_0 & message_example & name_module_cli &
							row_separator_0 & to_lower(type_action'image(import_cad)) & row_separator_0 & 
							to_lower(type_format_cad'image(format_cad)) & row_separator_0 &
							compose(
								containing_directory => containing_directory(universal_string_type.to_string(name_file_cad_net_list)),
								--containing_directory => name_directory_cad,
								name => base_name(universal_string_type.to_string(name_file_cad_net_list)),
								extension => extension(universal_string_type.to_string(name_file_cad_net_list))
								) &
							row_separator_0 & -- we assume the partlist lives in the same directory as the netlist:
							compose(
								containing_directory => containing_directory(universal_string_type.to_string(name_file_cad_net_list)),
								name => "board", extension => "part"
								)
							);

				elsif prog_position = "GEN20" then
						new_line;
						put_line(message_error & "Test profile not supported or missing" & exclamation & row_separator_0 & "Supported profiles are :");
						for p in 0..type_test_profile'pos(type_test_profile'last) loop
							put(to_lower(type_test_profile'image(type_test_profile'val(p))));
							-- CS: add line break after 5 items
							if p < type_test_profile'pos(type_test_profile'last) then put(" , "); end if;
						end loop;
						new_line(2);
						put_line(message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(infrastructure))
							);
	
				elsif prog_position = "GEN30" then
						put_line(message_error & "Name of test not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & "name_of_your_test"
							);

				elsif prog_position = "TDV00" then
						put_line(message_error & "Target device not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & "IC3"
							);

				elsif prog_position = "DVM00" then
						put_line(message_error & "Device model not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & universal_string_type.to_string(target_device) & row_separator_0 &
							compose(name_directory_models, "MC256", file_extension_text)
							);

				elsif prog_position = "DPC00" then
						put_line(message_error & "Device model not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & universal_string_type.to_string(target_device) & row_separator_0 &
							compose(name_directory_models, "MC256", file_extension_text) & row_separator_0 & "TSSOP48"
							);

				elsif prog_position = "TPI00" then
						put_line(message_error & "Receiver pin not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & universal_string_type.to_string(target_device) & row_separator_0 & "71"
							);

				elsif prog_position = "TON00" then
						put_line(message_error & "Target net not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & "COUNTER_INPUT"
							);

				elsif prog_position = "TOC00" then
						put_line(message_error & "Cycle count not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & universal_string_type.to_string(target_net) & row_separator_0 & "10"
							);


				elsif prog_position = "RYC00" then
						put_line(message_error & "Max. retry count not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & universal_string_type.to_string(target_device) & row_separator_0 & 
							universal_string_type.to_string(target_pin) & row_separator_0 & "10"
							);

				elsif prog_position = "RDY00" then
						put_line(message_error & "Retry delay not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & universal_string_type.to_string(target_device) & row_separator_0 & 
							universal_string_type.to_string(target_pin) &
							type_sxr_retries'image(retry_count) & row_separator_0 & "0.1"
							);

				elsif prog_position = "TLT00" then
						put_line(message_error & "Low time (unit is sec) not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & universal_string_type.to_string(target_net) &
							type_sxr_retries'image(cycle_count) & row_separator_0 & "2"
							);

				elsif prog_position = "THT00" then
						put_line(message_error & "High time (unit is sec) not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(generate)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							to_lower(type_test_profile'image(test_profile)) & row_separator_0 & universal_string_type.to_string(name_test) &
							row_separator_0 & universal_string_type.to_string(target_net) &
							type_sxr_retries'image(cycle_count) &
							type_delay_value'image(low_time) & row_separator_0 & "0.2"
							);

				elsif prog_position = "PJN00" then
						put_line(message_error & "Project name not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(create)) & row_separator_0 & "your_new_project"
							);

				elsif prog_position = "CMP00" then
						put_line(message_error & "No database specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(compile)) & row_separator_0 &
							compose(name => "your_database", extension => file_extension_database));

				elsif prog_position = "CMP20" then
						put_line(message_error & "Test name not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(compile)) & row_separator_0 &
							universal_string_type.to_string(name_file_data_base) & row_separator_0 &
							"your_test");

				elsif prog_position = "LD100" then
						put_line(message_error & "Test name not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(load)) & row_separator_0 &
							"your_test");

				elsif prog_position = "DP100" then
						put_line(message_error & "Specified page address invalid or out of range" & exclamation & 
							row_separator_0 & "(radix missing (d/h/b) ?)");

						ada.text_io.put_line(message_error'last * row_separator_0 & "Range (dec):" & row_separator_0 &
							trim(type_mem_address_page'image(type_mem_address_page'first),left) & ".." &
							trim(type_mem_address_page'image(type_mem_address_page'last),left) & dot);

						ada.text_io.put_line(message_error'last * row_separator_0 & "Range (hex):" & row_separator_0 &
							natural_to_string(natural_in => type_mem_address_page'first, base => 16) & ".." &
							natural_to_string(natural_in => type_mem_address_page'last, base => 16) & dot);


				elsif prog_position = "RU100" then
						put_line(message_error & "Test name not specified" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(run)) & row_separator_0 &
							"your_test");

				elsif prog_position = "RU400" then
						put_line(message_error & "Step mode not supported or invalid" & exclamation);
						ada.text_io.put_line(message_error'last * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							to_lower(type_action'image(run)) & row_separator_0 &
							universal_string_type.to_string(name_test) & row_separator_0 & "[step_mode]");
						ada.text_io.put(message_error'last * row_separator_0 & "Supported step modes: ");
						for p in 0..step_mode_count
						loop
							put(type_step_mode'image(type_step_mode'val(p)));
							if p < step_mode_count then put(" , "); end if;
						end loop;
						new_line;

				elsif prog_position = "ACV00" then
						new_line;
						put_line(message_error & "Too little arguments specified !");
						ada.text_io.put_line(message_error'length * row_separator_0 & message_example & name_module_cli & row_separator_0 &
							name_module_mkvmod & row_separator_0 & name_file_skeleton_default & row_separator_0 &
							"your_verilog_module (without extension");  

				elsif prog_position = "BP100" then
						new_line;
						put_line(message_error & "Breakpoint coordinates missing or out of range !");
						ada.text_io.put(message_error'last * row_separator_0 & "Example command to set breakpoint after sxr 6 bit 715:");
						put_line(row_separator_0 & name_module_cli & row_separator_0 &
							to_lower(type_action'image(break)) & row_separator_0 & "6 715");
						ada.text_io.put_line(message_error'last * row_separator_0 & "Allowed ranges:");
						ada.text_io.put_line(message_error'last * row_separator_0 & "sxr id      :" &
							type_vector_id_breakpoint'image(type_vector_id_breakpoint'first) &
							".." & trim(type_vector_id_breakpoint'image(type_vector_id_breakpoint'last),left));
						ada.text_io.put_line(message_error'last * row_separator_0 & "bit position:" &
							type_sxr_break_position'image(type_sxr_break_position'first) &
							".." & trim(type_sxr_break_position'image(type_sxr_break_position'last),left));
						new_line;
						ada.text_io.put_line(message_error'last * row_separator_0 & "To delete the breakpoint type command: " &
							name_module_cli & row_separator_0 & to_lower(type_action'image(break)) & row_separator_0 & "0");
				else
   
					--put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & prog_position);
				end if;

end bsmcl;
