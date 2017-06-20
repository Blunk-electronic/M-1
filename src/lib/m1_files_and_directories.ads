-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 FILES AND DIRECTORIES                      --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               S p e c                                    --
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
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.directories;			use ada.directories;

with m1_base; 					use m1_base;
with m1_firmware; 				use m1_firmware;
with m1_numbers; 				use m1_numbers;

package m1_files_and_directories is

	-- MODULE NAMES
	name_module_cli						: constant string (1..5) 	:= "bsmcl";
	name_module_gui						: constant string (1..6) 	:= "bsmgui";
	name_module_mkproject				: constant string (1..9) 	:= "mkproject";
	name_module_importer_bsdl			: constant string (1..7) 	:= "impbsdl";
	name_module_cad_importer_orcad		: constant string (1..8) 	:= "imporcad";
	name_module_cad_importer_kicad		: constant string (1..8) 	:= "impkicad";
	name_module_cad_importer_protel		: constant string (1..9) 	:= "impprotel";
	name_module_cad_importer_zuken		: constant string (1..8) 	:= "impzuken";
	name_module_cad_importer_eagle		: constant string (1..8) 	:= "impeagle";
	name_module_mknets					: constant string (1..6) 	:= "mknets";
	name_module_mkvmod					: constant string (1..6) 	:= "mkvmod";
	name_module_join_netlist			: constant string (1..11) 	:= "joinnetlist";
	name_module_mkoptions				: constant string (1..9) 	:= "mkoptions";
	name_module_chkpsn					: constant string (1..6) 	:= "chkpsn";
	name_module_mkinfra					: constant string (1..7) 	:= "mkinfra";
	name_module_mkintercon				: constant string (1..10) 	:= "mkintercon";
	name_module_mkmemcon				: constant string (1..8) 	:= "mkmemcon";
	name_module_mktoggle				: constant string (1..8) 	:= "mktoggle";
	name_module_mkclock					: constant string (1..7) 	:= "mkclock";
	name_module_compiler				: constant string (1..7) 	:= "compseq";
	name_module_database_query			: constant string (1..7) 	:= "udbinfo";

	-- kermit scripts
-- 	name_module_kermit					: constant string (1..6) 	:= "kermit";
-- 	name_module_mem_out_dump			: constant string (1..11) 	:= "dump_outram";
-- 	name_module_mem_clear				: constant string (1..6) 	:= "clrram";
-- 	name_module_test_run				: constant string (1..7)	:= "runtest";
-- 	name_module_bsc_status				: constant string (1..4)	:= "diag";
-- 	name_module_bsc_firmware			: constant string (1..7)	:= "version";
-- 	name_module_bsc_shutdown			: constant string (1..8)	:= "stoptest";

	-- provisions by operating system
	name_module_pidof				: constant string (1..10) := ("/bin/pidof"); 
	-- CS: may not be so in all distros
	-- CS: needs variable setup by environment check

	-- FILE EXTENSIONS
	file_extension_separator		: constant string (1..1) := ".";
	file_extension_database			: constant string (1..3) := "udb";
    file_extension_options			: constant string (1..3) := "opt";
	file_extension_routing      	: constant string (1..3) := "csv";    
    file_extension_sequence			: constant string (1..3) := "seq";
	file_extension_registers		: constant string (1..3) := "reg";
	file_extension_listing			: constant string (1..3) := "lis";
	file_extension_vector			: constant string (1..3) := "vec";
	file_extension_verilog			: constant string (1..1) := "v";
	file_extension_script			: constant string (1..2) := "sh";
	file_extension_temp				: constant string (1..3) := "tmp";
	file_extension_text				: constant string (1..3) := "txt";
	file_extension_png				: constant string (1..3) := "png";
	file_extension_configuration 	: constant string (1..4) := "conf";
	file_extension_assembly_variants: constant string (1..3) := "var";	
	file_extension_csv				: constant string (1..3) := "csv";


	-- SYSTEM DIRECTORIES NAME VARIABLES
	name_environment_var_home			: constant string (1..4) := "HOME";

	directory_name_length_max : constant positive := 200; -- CS: increase if nessecary
	package type_name_directory_home is new generic_bounded_length(directory_name_length_max); use type_name_directory_home;	
	package type_name_directory_bin is new generic_bounded_length(directory_name_length_max+4); use type_name_directory_bin;
	package type_name_directory_enscript is new generic_bounded_length(directory_name_length_max); use type_name_directory_enscript;			
	name_directory_home					: type_name_directory_home.bounded_string;
	name_directory_bin					: type_name_directory_bin.bounded_string;
	name_directory_enscript				: type_name_directory_enscript.bounded_string;

	-- SYSTEM DIRECTORY CONSTANTS
	name_directory_separator			: constant string (1..1) := "/";
	name_directory_configuration		: constant string (1..4) := ".M-1";
	name_directory_configuration_images	: constant string (1..8) := compose (name_directory_configuration, "img");
	name_directory_projects_default		: constant string (1..7) := "M-1" & name_directory_separator & "uut";



	-- SYSTEM FILE NAME VARIABLES
	package type_interface_to_bsc is new generic_bounded_length(directory_name_length_max);
	interface_to_bsc					: type_interface_to_bsc.bounded_string; -- CS: udev rules for unique interface name
	scan_master_present					: boolean := false;

	-- SYSTEM FILE CONSTANTS
	name_file_configuration				: constant string (1..8)  := compose(name => "M-1", extension => file_extension_configuration);
	name_file_configuration_session		: constant string (1..12) := compose(name => "session", extension => file_extension_configuration);
	name_file_image_request_upload		: constant string (1..22) := "upload_request_startup";
	name_file_image_ready				: constant string (1..5)  := "ready";
	name_file_image_fail				: constant string (1..4)  := "fail";
	name_file_image_pass				: constant string (1..4)  := "pass";
	name_file_image_run					: constant string (1..3)  := "run";
	name_file_image_aborted				: constant string (1..7)  := "aborted";
	name_file_image_abort_failed		: constant string (1..12) := "abort_failed";

	-- SYSTEM FILE TYPES
	file_system_configuraion			: ada.text_io.file_type;


	-- KEYWORDS IN CONFIGURATION FILE
	text_language						: constant string (1..8)  := "language";
	text_directory_bin					: constant string (1..13) := "directory_bin";
	text_directory_enscript				: constant string (1..18) := "directory_enscript";
	text_interface_bsc					: constant string (1..13) := "interface_bsc";



	-- PROJECT FILE NAME VARIABLES
	file_name_length_max : constant := 100;
	package type_name_project is new generic_bounded_length(file_name_length_max);
	name_project 					: type_name_project.bounded_string; -- name of current project/uut/target
	name_project_previous			: type_name_project.bounded_string; -- name of previous project
	-- Required to detect when the operator changes the project. On changing the project the bsc ram must
	-- be cleared. CS: currently used by the GUI only. Command line operations require it as environment variable.

	package type_name_script is new generic_bounded_length(file_name_length_max); 
	name_script : type_name_script.bounded_string;
	
	package type_name_database is new generic_bounded_length(file_name_length_max); use type_name_database;
	name_file_database 				: type_name_database.bounded_string;
	package type_name_file_options is new generic_bounded_length(file_name_length_max); use type_name_file_options;
	name_file_options				: type_name_file_options.bounded_string;
	name_file_mkoptions_conf		: constant string (1..14) := "mkoptions.conf";
	package type_name_file_routing is new generic_bounded_length(file_name_length_max); use type_name_file_routing;	
	name_file_routing				: type_name_file_routing.bounded_string;    
	package type_name_file_netlist is new generic_bounded_length(file_name_length_max); use type_name_file_netlist;	
	name_file_cad_netlist			: type_name_file_netlist.bounded_string;
	package type_name_file_partlist is new generic_bounded_length(file_name_length_max); use type_name_file_partlist;
	name_file_cad_partlist			: type_name_file_partlist.bounded_string;
	package type_name_file_list_of_assembly_variants is new generic_bounded_length(file_name_length_max); use type_name_file_list_of_assembly_variants;
	name_file_list_of_assembly_variants : type_name_file_list_of_assembly_variants.bounded_string;
	--	name_file_skeleton				: universal_string_type.bounded_string;
	name_file_skeleton				: constant string (1..12) := "skeleton.txt";
	package type_name_file_skeleton_submodule is new generic_bounded_length(file_name_length_max); use type_name_file_skeleton_submodule;		
	name_file_skeleton_submodule	: type_name_file_skeleton_submodule.bounded_string;
	package type_name_file_skeleton_verilog is new generic_bounded_length(file_name_length_max); use type_name_file_skeleton_verilog;
	name_file_skeleton_verilog		: type_name_file_skeleton_verilog.bounded_string;
	package type_name_file_model_verilog is new generic_bounded_length(file_name_length_max); use type_name_file_model_verilog;
	name_file_model_verilog			: type_name_file_model_verilog.bounded_string;
	package type_name_file_model_memory is new generic_bounded_length(file_name_length_max); use type_name_file_model_memory;
	name_file_model_memory			: type_name_file_model_memory.bounded_string;

	package type_name_test is new generic_bounded_length(file_name_length_max); 
	name_test : type_name_test.bounded_string;
	package type_name_test_netlist is new generic_bounded_length(file_name_length_max); use type_name_test_netlist;
	name_test_netlist				: type_name_test_netlist.bounded_string;
	package type_name_test_registers is new generic_bounded_length(file_name_length_max); use type_name_test_registers;
	name_test_registers				: type_name_test_registers.bounded_string;
	
	-- PROJECT FILE TYPES
	file_database				: ada.text_io.file_type;
	file_database_preliminary	: ada.text_io.file_type;
    file_cad_netlist           	: ada.text_io.file_type;
	file_cad_partlist          	: ada.text_io.file_type;
	file_variants				: ada.text_io.file_type;	
	file_skeleton				: ada.text_io.file_type;	
	file_options				: ada.text_io.file_type;
    file_mkoptions				: ada.text_io.file_type;	
	file_routing				: ada.text_io.file_type;    
	file_sequence				: ada.text_io.file_type;
	file_bsdl 					: ada.text_io.file_type;

	file_cli_messages			: ada.text_io.file_type;
	file_gui_messages			: ada.text_io.file_type;		
	file_udbinfo_messages		: ada.text_io.file_type;	
	file_import_cad_messages	: ada.text_io.file_type;	
	file_import_bsdl_messages	: ada.text_io.file_type;	
	file_join_netlist_messages	: ada.text_io.file_type;
	file_mknets_messages		: ada.text_io.file_type;		
	file_chkpsn_messages		: ada.text_io.file_type;			
	file_mkoptions_messages		: ada.text_io.file_type;				
	file_mkinfra_messages		: ada.text_io.file_type;
	file_mkintercon_messages	: ada.text_io.file_type;
	file_mkmemcon_messages		: ada.text_io.file_type;
	file_mktoggle_messages		: ada.text_io.file_type;
	file_mkclock_messages		: ada.text_io.file_type;
	file_compiler_messages		: ada.text_io.file_type;
	file_model_memory			: ada.text_io.file_type;
    file_test_init_template		: ada.text_io.file_type;
    file_test_netlist      		: ada.text_io.file_type;
    -- 	package seq_io_unsigned_byte is new ada.sequential_io(unsigned_8);

	file_vector 		        : seq_io_unsigned_byte.file_type;
	file_vector_header	        : seq_io_unsigned_byte.file_type;
   	file_journal				: ada.text_io.file_type;
	file_compile_listing		: ada.text_io.file_type;


	-- PROJECT DIRECTORIES NAME CONSTANTS
	name_directory_temp		              : constant string (1..3)    := "tmp";
	name_directory_bak		              : constant string (1..3)    := "bak";
	name_directory_cad 		              : constant string (1..3)    := "cad";
	name_directory_models	              : constant string (1..6)    := "models";
	name_directory_messages	              : constant string (1..8)    := "messages";
    name_directory_setup_and_templates	  : constant string (1..5)    := "setup";

	-- PROJECT FILE NAME CONSTANTS
	name_file_database_preliminary			: constant string (1..20)	:= compose(name_directory_temp, "database_pre", file_extension_database);
	name_file_vector_header					: constant string (1..18)	:= compose(name_directory_temp, "vec_header", file_extension_temp);
	name_file_journal						: constant string (1..17)	:= compose(name_directory_setup_and_templates, "journal", file_extension_text);
    name_file_skeleton_default	            : constant string (1..12)	:= compose(name => "skeleton", extension => file_extension_text);
    name_file_test_init_template_default    : constant string (1..21)	:= compose(name => "test_init_general", extension => file_extension_text);
    name_file_test_init_template			: constant string (1..20)	:= compose(name => "test_init_custom", extension => file_extension_text);
	name_file_project_description	        : constant string (1..23)	:= compose(name => "project_description", extension => file_extension_text);
	name_file_mkoptions_configuration    	: constant string (1..14)	:= compose(name => "mkoptions", extension => file_extension_configuration);
    name_file_bsc_status					: constant string (1..name_directory_temp'last + 1 + 8) := -- length of directoy name + "/" + lenght of "diag" + ".tmp"
		compose(
			containing_directory => name_directory_temp,
			name => "diag",
			extension => file_extension_temp
			);
    name_file_bsc_firmware					: constant string (1..name_directory_temp'last + 1 + 11) := -- length of directoy name + "/" + lenght of "version" + ".tmp"
		compose(
			containing_directory => name_directory_temp,
			name => "version",
			extension => file_extension_temp
			);
	file_test_result		: ada.text_io.file_type;
	name_file_test_result	: constant string (1..15) := compose(name => "test_result", extension => file_extension_temp);

-- MESSAGE, LOG, REPORT FILES
	length_name_message_file_base : constant positive := name_directory_messages'last + 2 + file_extension_text'last; -- like "messages/xyz.txt"

	-- command line interface messages go here:
	name_file_cli_messages : constant string (1..length_name_message_file_base + name_module_cli'last) := compose(
		containing_directory => name_directory_messages, name => name_module_cli, extension => file_extension_text);

	-- GUI interface messages go here:
	name_file_gui_messages : constant string (1..length_name_message_file_base + name_module_gui'last) := compose(
		containing_directory => name_directory_messages, name => name_module_gui, extension => file_extension_text);

	-- When reading the database, messages go here:
	name_file_udbinfo_messages : constant string (1..length_name_message_file_base + name_module_database_query'last) := compose(
		containing_directory => name_directory_messages, name => name_module_database_query, extension => file_extension_text);

	-- When importing CAD data (netlist, partlists), messages go here:
	-- NOTE: The file name is independed of the cad format.
	name_file_import_cad_messages : constant string (1..length_name_message_file_base + 10) := compose(
		containing_directory => name_directory_messages, name => "import_cad", extension => file_extension_text);

	-- When importing BSDL models, messages go here:
	name_file_import_bsdl_messages : constant string (1..length_name_message_file_base + name_module_importer_bsdl'last) := compose(
		containing_directory => name_directory_messages, name => name_module_importer_bsdl, extension => file_extension_text);

	-- When joining skeletons, messages go here:
	name_file_join_netlist_messages : constant string (1..length_name_message_file_base + name_module_join_netlist'last) := compose(
		containing_directory => name_directory_messages, name => name_module_join_netlist, extension => file_extension_text);
	
	-- When making nets, messages go here:
	name_file_mknets_messages : constant string (1..length_name_message_file_base + name_module_mknets'last) := compose(
		containing_directory => name_directory_messages, name => name_module_mknets, extension => file_extension_text);

	-- When checking primary/secondary nets, messages go here:
	name_file_chkpsn_messages : constant string (1..length_name_message_file_base + name_module_chkpsn'last) := compose(
		containing_directory => name_directory_messages, name => name_module_chkpsn, extension => file_extension_text);

	-- When making options, messages go here:
	name_file_mkoptions_messages : constant string (1..length_name_message_file_base + name_module_mkoptions'last) := compose(
		containing_directory => name_directory_messages, name => name_module_mkoptions, extension => file_extension_text);

	-- When generating tests, messages go here:
	name_file_mkinfra_messages : constant string (1..length_name_message_file_base + name_module_mkinfra'last) := compose(
		containing_directory => name_directory_messages, name => name_module_mkinfra, extension => file_extension_text);
	
	name_file_mkintercon_messages : constant string (1..length_name_message_file_base + name_module_mkintercon'last) := compose(
		containing_directory => name_directory_messages, name => name_module_mkintercon, extension => file_extension_text);

	name_file_mkmemcon_messages : constant string (1..length_name_message_file_base + name_module_mkmemcon'last) := compose(
		containing_directory => name_directory_messages, name => name_module_mkmemcon, extension => file_extension_text);

	name_file_mktoggle_messages : constant string (1..length_name_message_file_base + name_module_mktoggle'last) := compose(
		containing_directory => name_directory_messages, name => name_module_mktoggle, extension => file_extension_text);

	name_file_mkclock_messages : constant string (1..length_name_message_file_base + name_module_mkclock'last) := compose(
		containing_directory => name_directory_messages, name => name_module_mkclock, extension => file_extension_text);

	-- When compiling tests, messages go here:
	name_file_compiler_messages : constant string (1..length_name_message_file_base + name_module_compiler'last) := compose(
		containing_directory => name_directory_messages, name => name_module_compiler, extension => file_extension_text);
	
	-- Inside a test directory: here a copy of the netlist a test is based on goes:
	name_file_test_netlist : constant string (1..11)    := compose(name => "netlist", extension => file_extension_text);
  

	-- KEYWORDS IN SESSION CONFIGURATION FILE
	text_project			: constant string (1..7) := "project";
	text_script				: constant string (1..6) := "script";
	text_test				: constant string (1..4) := "test";

	example_database	: constant string (1..10) := compose("my_uut", file_extension_database);
	
	
	procedure set_home_directory;
	-- sets variable name_directory_home (absolute path !)

	procedure check_environment;
	-- reads system configuration file and sets variables: name_directory_home, language, name_directory_bin, name_directory_enscript, interface_to_bsc

	function is_project_directory return boolean;
	-- checks if working directory is a project.

	procedure create_temp_directory;
	-- recreates an empty tmp directory

	procedure create_bak_directory;
	-- creates an empty bak directory if no existing already

	function strip_trailing_forward_slash (text_in	: string) return string;
	-- Trims trailing forward slash (directory separator) from a string.

	procedure make_result_file (result : string);
	-- Creates a temporarily file (in directory tmp) that contains the single word PASSED or FAILED as passed by "result".
	-- The graphical user interface reads this file in order to set the status image to FAIL or PASS.

	procedure delete_result_file;
	-- Deletes the temporarily file (created by make_result_file) (in directory tmp).

	function valid_project (name_project : in type_name_project.bounded_string) return boolean;
	-- Returns true if given project is valid.
	-- name_project is assumed as absolute path !

	function valid_script (name_script : in type_name_script.bounded_string) return boolean;
	-- Returns true if given script is valid.
	

end m1_files_and_directories;
