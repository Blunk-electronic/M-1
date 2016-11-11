------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKNETS                              --
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

with Ada.Text_IO;			use Ada.Text_IO;
with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
with Ada.Float_Text_IO;		use Ada.Float_Text_IO;
with Ada.Characters.Handling;
use Ada.Characters.Handling;

--with System.OS_Lib;   use System.OS_Lib;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Bounded; 	use Ada.Strings.Bounded;
with Ada.Strings.Fixed; 	use Ada.Strings.Fixed;
with Ada.Numerics;			use Ada.Numerics;
with Ada.Numerics.Elementary_Functions;	use Ada.Numerics.Elementary_Functions;

with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
with Ada.Task_Identification;  use Ada.Task_Identification;
with Ada.Exceptions; use Ada.Exceptions;
 
with GNAT.OS_Lib;   	use GNAT.OS_Lib;
with Ada.Command_Line;	use Ada.Command_Line;
with Ada.Directories;	use Ada.Directories;
 
with Ada.Calendar;				use Ada.Calendar;
with Ada.Calendar.Formatting;	use Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;	use Ada.Calendar.Time_Zones;

with m1_internal; 				use m1_internal;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;


procedure mknets is

	version			: constant string (1..3) := "044";
	udb_summary		: type_udb_summary;
	prog_position	: natural := 0;



	type port_pin_extended is
		record				
			port		: Unbounded_String;
			field_ct	: Natural := 0;
			vectored	: Boolean := false;
			match		: Boolean := false;
			position	: Natural := 0;
		end record;

	type port_io_extended is
		record				
			port_name_full	: Unbounded_String;
			match			: Boolean := false;
			bs_port			: Boolean := false;
		end record;

	type cells_extended is
		record				
			cells	: Unbounded_String;
			match	: Boolean := false;
		end record;







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

	-- create premilinary data base (contining scanpath_configuration)
	prog_position	:= 60;
	extract_section( 
		universal_string_type.to_string(name_file_data_base),
		name_file_data_base_preliminary,
		section_mark.section,
		section_mark.endsection,
		section_scanpath_configuration
		);

	-- create premilinary data base (contining scanpath_configuration)
-- 	prog_position	:= 60;
-- 	extract_section( 
-- 		universal_string_type.to_string(name_file_data_base),
-- 		name_file_data_base_preliminary,
-- 		section_mark.section,
-- 		section_mark.endsection,
-- 		section_registers
-- 		);
	

-- 	-- append scanpath_configuration and registers to backup udb
-- 	prog_position := "APS0"; --ins v043
-- 	extract_section( (to_string(data_base)) ,"tmp/spc.tmp","Section","EndSection","scanpath_configuration");
-- 	extract_section( (to_string(data_base)) ,"tmp/registers.tmp","Section","EndSection","registers");
-- 
-- 	prog_position := "BAK0"; --ins v043
-- 	Create( OutputFile, Name => Compose("bak",to_string(data_base) & "_registers")); Close(OutputFile);
-- 	Open( 
-- 		File => udb_bak,
-- 		Mode => Append_File,
-- 		Name => Compose("bak",to_string(data_base) & "_registers")
-- 		);
-- 	Set_Output(udb_bak);
-- 
-- 	prog_position := "APS1"; --ins v043
-- 	append_file_open("tmp/spc.tmp"); new_line;
-- 	append_file_open("tmp/registers.tmp"); new_line;
-- 	Close(udb_bak);
-- 
-- 	prog_position := "APS2"; --ins v043
-- 	Set_Output(Standard_Output);
-- 	remove_comments_from_file (Compose("bak",to_string(data_base) & "_registers"),"tmp/udb_no_comments.tmp");
-- 
-- 	-- read spc section (former tmp/spc.tmp will be overwritten)
-- 	prog_position := "APS3"; --ins v043
-- 	extract_section("tmp/udb_no_comments.tmp","tmp/spc.tmp","Section","EndSection","scanpath_configuration");
-- 	extract_section("tmp/spc.tmp","tmp/chain.tmp","SubSection","EndSubSection","chain");
-- 	extract_netto_from_SubSection("tmp/chain.tmp" , "tmp/members.tmp");
-- 
-- 	-- count chain members
-- 	prog_position := "CCM1"; --ins v043
-- 	count_members := (count_chain_members("tmp/members.tmp"));
-- 
-- 	Open( 
-- 		File => member_list,
-- 		Mode => In_File,
-- 		Name => "tmp/members.tmp"
-- 		);
-- 	Set_Input(member_list);

-- 	prog_position := "CCM2"; --ins v043
-- 	while not End_Of_File -- read from member_list
-- 		loop
-- 			Line_member:=Get_Line;
-- 			if Get_Field_Count(Line_member) > 0 then 
-- 				device := to_unbounded_string(Get_Field(Line_member,1)); 
-- 				--put (to_string(device)); new_line;
-- 				--Set_Input(udb);
-- 				--Reset(udb);
-- 
-- 				-- get general information of device being examined
-- 				extract_section("tmp/udb_no_comments.tmp",Compose("tmp",to_string(device) & "_all.tmp"),"SubSection","EndSubSection",to_string(device),to_string(device));
-- 
-- 				--  get port-i/o map of device being examined
-- 				extract_section(Compose("tmp",to_string(device) & "_all.tmp"),Compose("tmp",to_string(device) & "_port_io_map.tmp"),"SubSection","EndSubSection","port_io_map");
-- 
-- 				--  get boundary register of device being examined
-- 				extract_section(Compose("tmp",to_string(device) & "_all.tmp"),Compose("tmp",to_string(device) & "_boundary_register.tmp"),"SubSection","EndSubSection","boundary_register");
-- 
-- 				--  get port-pin-map of device being examined
-- 				extract_section(Compose("tmp",to_string(device) & "_all.tmp"),Compose("tmp",to_string(device) & "_port_pin_map.tmp"),"SubSection","EndSubSection","port_pin_map");
-- 
-- 
-- 			end if;
-- 		end loop; -- read from member_list

	-- read premilinary data base
	prog_position	:= 65;
--	udb_summary := read_uut_data_base(name_file_data_base_preliminary);
--	put_line (file_data_base_preliminary,"-- number of BICs" & natural'image(udb_summary.bic_ct));


-- 	-- read netlist from skeleton
-- 	prog_position := "NSK0"; --ins v043
-- 	extract_section("skeleton.txt","tmp/netlist_skeleton.tmp","Section","EndSection","netlist_skeleton");
-- 
-- 	Open( 
-- 		File => skeleton,
-- 		Mode => In_File,
-- 		Name => "tmp/netlist_skeleton.tmp"
-- 		);
-- 	Set_Input(skeleton);
-- 	Close(member_list);
-- 
-- 	prog_position := "NSK1"; --ins v043
-- 	Create( OutputFile, Name => "tmp/netlist_plus_cells.tmp"); Close(OutputFile);
-- 	Open( 
-- 		File => netlist_plus_cells,
-- 		Mode => Out_File,
-- 		Name => "tmp/netlist_plus_cells.tmp"
-- 		);
-- 	Set_Output(netlist_plus_cells);
-- 
-- 	-- NOTE: skeleton must be set as input file, netlist_plus_cells as output file
-- 	prog_position := "NSK2"; --ins v043
-- 	process_skeleton(count_members,identify_chain_members(count_members)); 
-- 	new_line(warnings); -- ins V042
-- 	close(warnings); -- ins V042
-- 
-- -------
-- 
-- 	-- overwrite current udb with bak/${udb}_registers to remove old netlist section from current udb
-- 	prog_position := "NSK3"; --ins v043
-- 	Copy_File( Compose("bak",to_string(data_base) & "_registers"), to_string(data_base));
-- 
-- 	-- append formated tmp/netlist_plus_cells.tmp to udb
-- 	Open( 
-- 		File => data_base_new,
-- 		Mode => Append_File,
-- 		Name => to_string(data_base)
-- 		);
-- 	Set_Output(data_base_new);
-- 	Close(netlist_plus_cells);
-- 	--append_file_open("tmp/netlist_plus_cells.tmp");
-- 
-- 	new_line;
-- 
-- 	put ("Section netlist"); new_line;
-- 	put ("--------------------------------------------"); new_line;
-- 	put ("-- created by netmaker version " & version); new_line;
-- 	put ("-- date       : " ); put (Image(clock)); new_line; 
-- 	put ("-- UTC_Offset : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; new_line;
-- 
-- 	append_file_open("tmp/warnings.tmp"); -- ins V042
-- 
-- 	Open( 
-- 		File => netlist_plus_cells,
-- 		Mode => In_File,
-- 		Name => "tmp/netlist_plus_cells.tmp"
-- 		);
-- 	Set_Input(netlist_plus_cells);
-- 
-- 	while not End_Of_File
-- 		loop
-- 
-- 			Line_netlist := Get_Line;
-- 				if Is_Field(Line_netlist,"SubSection",1) or Is_Field(Line_netlist,"EndSubSection",1) then 
-- 				--		[ "${line[0]}" = "SubSection" ] && echo ' '${line[*]} >> $udb
-- 				--		[ "${line[0]}" = "EndSubSection" ] && echo ' '${line[*]} >> $udb
-- 					put (Line_netlist); new_line; 
-- 
-- 				elsif Is_Field(Line_netlist,"EndSection",1) then 
-- 				--		[ "${line[0]}" = "EndSection" ] && echo ${line[*]} >> $udb
-- 					put (Line_netlist); new_line; 
-- 
-- 				elsif Get_Field(Line_netlist,1) /= "Section" then 
-- 				--		[ "${line[0]}" != "Section" ] && [ "${line[0]}" != "EndSection" ] && [ "${line[0]}" != "SubSection" ] && [ "${line[0]}" != "EndSubSection" ] && echo '  '${line[*]} >> $udb
-- 					put (Line_netlist); new_line; 
-- 				end if;
-- 
-- 		end loop;
-- 
-- 	Set_Input(Standard_Input);
-- 	Set_Output(Standard_Output);
-- 	close(netlist_plus_cells);
-- 	close(data_base_new);
-- 
-- 	new_line(standard_output);
-- 	put_line(standard_output,"CAUTION : READ WARNINGS ISSUED IN DATA BASE FILE: " & data_base & " section netlist or in tmp/warnings.tmp");
-- 	--Abort_Task (Current_Task);

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
