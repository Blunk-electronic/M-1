------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKTOGGLE                            --
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
with Ada.Strings; 			use Ada.Strings;
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

with m1; use m1;

procedure mktoggle is

	Version			: String (1..3) := "003";
	test_name  		: Unbounded_string;	
	data_base  		: Unbounded_string;
	--target_device	: Unbounded_string;
	target_net		: Unbounded_string;	
	cycle_count		: Natural := 1;
	low_time		: Float := 1.0;
	high_time		: Float := 1.0;	
	frequency		: Float;
	
	--algorithm		: unbounded_string;
	prog_position	: String (1..3) := "---";
	InputFile 		: Ada.Text_IO.File_Type;
	InputFile2 		: Ada.Text_IO.File_Type;
	OutputFile 		: Ada.Text_IO.File_Type;
	RegFile			: Ada.Text_IO.File_Type;
	SeqFile			: Ada.Text_IO.File_Type;
	key				: String (1..1) := "n";
	scratch			: Unbounded_string;
	Line			: Unbounded_string;
	count_members	: Natural := 0; -- holds number of chain members
	dummy			: Integer;

	type single_member is
		record				
			device		: Unbounded_String;
			value		: Unbounded_String;
			chain		: Natural := 0;
			position	: Natural := 0;
			ir_length	: Natural := 0;
			ir_capture	: Unbounded_String;
			usr_capture	: Unbounded_String;
			id_capture	: Unbounded_String;
			opc_bypass	: Unbounded_String;
			opc_extest	: Unbounded_String;
			opc_sample	: Unbounded_String;
			opc_preload	: Unbounded_String;
			opc_clamp	: Unbounded_String;
			opc_highz	: Unbounded_String;
			opc_idcode	: Unbounded_String;
			opc_usrcode	: Unbounded_String;
			bsr_length	: Natural := 0;
			safebits	: Unbounded_String;
			bsr_drive	: Unbounded_String;
			bsr_expect	: Unbounded_String;
			bsr_expect_length : Natural;
			trst_pin	: Boolean := false;
		end record;

	type members is array (Natural range <>) of single_member; --unbounded_string;

	vector_ct		: Natural := 0;


	

	procedure fraction_data_base (dummy : integer := 0) is
		begin
			remove_comments_from_file(to_string(data_base),"tmp/udb_no_comments.tmp");
			-- remove_emtpy_lines_from_file ?
			extract_section("tmp/udb_no_comments.tmp", "tmp/spc.tmp", "Section" , "EndSection" , "scanpath_configuration");
			extract_section("tmp/spc.tmp", "tmp/chain.tmp", "SubSection" , "EndSubSection" , "chain" ); -- #CS: How to handle multiple scan paths ?
			extract_netto_from_SubSection("tmp/chain.tmp" , "tmp/members.tmp");
			extract_section("tmp/udb_no_comments.tmp", "tmp/registers.tmp", "Section" , "EndSection" , "registers");
			extract_section("tmp/udb_no_comments.tmp", compose(to_string(test_name),"netlist.txt"), "Section" , "EndSection" , "netlist");
		end;




	procedure write_info_section
			(
			dummy : integer := 0 --target_file	: string
			)
			is

		Previous_Output	: File_Type renames Current_Output;
		--Previous_Input	: File_Type renames Current_Input;
			
		begin
			-- create sequence file
			Create( OutputFile, Name => (compose (to_string(test_name),to_string(test_name), "seq")));

			Set_Output(OutputFile); -- set data sink

			put ("Section info"); new_line;
			put (" created by pin toggle generator version "& version); new_line;
			put (" date          : " ); put (Image(clock)); new_line; 
			put (" UTC_Offset    : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; 
			put (" database      : " & data_base); new_line;
			put (" target net    : "); put(target_net); new_line;
			put (" cycle count   :" & Integer'Image(cycle_count)); new_line;
			put (" low time      :"); put (low_time, fore=> 2, aft =>1, exp => 0); put(" sec"); new_line;
			put (" high time     :"); put (high_time, fore=> 2, aft =>1, exp => 0); put(" sec"); new_line;
			put (" frequency     :"); put (frequency, fore=> 2, aft =>2, exp => 0); put(" Hz"); new_line;			
			put ("EndSection"); new_line; new_line;

			Close(OutputFile); --Close(InputFile);
			Set_Output(Previous_Output); --Set_Input(Previous_Input);

		end;




	procedure write_options_section (
									dummy : integer := 0
									) is

		Previous_Output	: File_Type renames Current_Output;
		Previous_Input	: File_Type renames Current_Input;

		begin

		-- #read electrical parameters
		extract_section("tmp/spc.tmp", "tmp/options.tmp" , "SubSection" , "EndSubSection" , "options" );
	
		Open( 
			File => OutputFile,
			Mode => Append_File,
			Name => compose (to_string(test_name),to_string(test_name), "seq")
			);
		Set_Output(OutputFile); -- set data sink

		-- open input_file
		Open( 
			File => InputFile,
			Mode => In_File,
			Name => "tmp/options.tmp"
			);
		Set_Input(InputFile); -- set data souce

		while not End_Of_File 
			loop
				Line:=Get_Line;
				if Is_Field(Line,"SubSection",1) = true then put("Section options"); new_line; end if;
				if Is_Field(Line,"on_fail",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"frequency",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"trailer_ir",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"trailer_dr",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"voltage_out_port_1",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"voltage_out_port_2",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"tck_driver_port_1",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"tck_driver_port_2",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"tms_driver_port_1",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"tms_driver_port_2",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"tdo_driver_port_1",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"tdo_driver_port_2",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"trst_driver_port_1",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"trst_driver_port_2",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"threshold_tdi_port_1",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"threshold_tdi_port_2",1) = true then put(" "& Line); new_line; end if;
				if Is_Field(Line,"EndSubSection",1) = true then put("EndSection"); new_line; new_line; end if; 
			end loop;
	
		put("Section sequence 1");

		Close(OutputFile); Close(InputFile);
		Set_Output(Previous_Output); Set_Input(Previous_Input);
		end;




	procedure append_file 
						(
						source_file : string;
						target_file	: string
						) 
						is

		Previous_Output	: File_Type renames Current_Output;
		Previous_Input	: File_Type renames Current_Input;

		begin

			Open( 
				File => OutputFile,
				Mode => Append_File,
				Name => target_file
				);
			Set_Output(Outputfile); -- set data sink

			-- open input_file
			Open( 
				File => InputFile,
				Mode => In_File,
				Name => source_file
				);
			Set_Input(InputFile); -- set data source

			-- append line by line to target file
			while not End_Of_File
				loop
					Line:=Get_Line;
					Put(Line); new_line;
				end loop;
			Close(InputFile); Close(OutputFile);
			Set_Output(Previous_Output); Set_Input(Previous_Input);
		end;


	function count_chain_members
					(
					-- version 1.0 / MBL
					input_file : string
					)
					return Natural is

		count_members	: Natural := 0;
		CountInputFile 	: Ada.Text_IO.File_Type;
		Previous_Input	: File_Type renames Current_Input;

		begin
			-- open input_file
			Open( 
				File => CountInputFile,
				Mode => In_File,
				Name => input_file
				);
			Set_Input(CountInputFile); -- set data source
	
			-- count chain members
			while not End_Of_File
				loop
					Line:=Get_Line;
					if Get_Field_Count(Line) > 0 then 
						count_members:=count_members+1;

						-- create individual register file for each member 
						extract_section	(
										"tmp/registers.tmp", 
										compose("tmp", Get_Field(Line,1) &"_registers.tmp"),
										"SubSection",
										"EndSubSection",
										Get_Field(Line,1),
										Get_Field(Line,1)
										);
						--Set_Input(CountInputFile);
					end if;
				end loop;
			Close(CountInputFile);
			Set_Input(Previous_Input);
			return count_members;
		end;



	function query_member_register
					(
					-- version 1.0 / MBL
					member_name		: string;
					registers_entry	: string
					)
					return string is
	
		--value			: unbounded_string;
		InputFile 		: Ada.Text_IO.File_Type;
		Previous_Input	: File_Type renames Current_Input;
		Line			: unbounded_string;

		begin
			--put (member_name); new_line;

			-- open input_file
			Open( 
				File => InputFile,
				Mode => In_File,
				Name => compose ("tmp", (member_name &"_registers.tmp") ) 
				);
			Set_Input(InputFile); -- set data source

			--put ("--"); new_line;

			while not End_Of_File
				loop
					Line:=Get_Line;
					if Get_Field_Count(Line) > 0 then 
						if Is_Field ( Line, registers_entry , 1) = true then
							Close(InputFile);
							Set_Input(Previous_Input);
							return Get_Field ( Line, 2);
						end if;
					end if;
				end loop;
			Close(InputFile);
			Set_Input(Previous_Input);
			return "undefined";
		end;


	function identify_chain_members
						(
						count_members	: Natural
						--input_file		: string
						)
						return members is

		subtype members_sized is members(1..count_members);
		m	: members_sized;

		IdentInputFile 		: Ada.Text_IO.File_Type;
		Previous_Input		: File_Type renames Current_Input;
		ct					: Natural := 0;

		begin
			-- open input_file
			Open( 
				File => IdentInputFile,
				Mode => In_File,
				Name => "tmp/members.tmp"
				);
			Set_Input(IdentInputFile); -- set data source
			Set_Output(Standard_Output);

			-- identify chain members
			while not End_Of_File
				loop
					Line:=Get_Line; --(IdentInputFile);
					if Get_Field_Count(Line) > 0 then 
						ct := ct+1;
						--put (ct);
						m(ct).device	:= to_unbounded_string ( Get_Field(Line,1)); -- IC301

						m(ct).value			:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"value") ); -- XC9536 := (IC301,value)
						m(ct).ir_length		:= Natural'Value ( query_member_register (Get_Field(Line,1),"instruction_register_length") );
						m(ct).bsr_length	:= Natural'Value ( query_member_register (Get_Field(Line,1),"boundary_register_length") );
						m(ct).safebits		:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"safebits") ); -- XC9536 := (IC301,value)

						m(ct).ir_capture	:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"instruction_capture") );
						m(ct).usr_capture	:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"usercode_register") );
						m(ct).id_capture	:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"idcode_register") );

						-- CS: SubSection instruction_opcodes should be extracted before reading opcodes
						m(ct).opc_bypass	:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"bypass") );
						m(ct).opc_extest	:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"extest") );
						m(ct).opc_sample	:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"sample") );
						m(ct).opc_preload	:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"preload") );
						m(ct).opc_clamp		:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"clamp") );
						m(ct).opc_highz		:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"highz") );
						m(ct).opc_idcode	:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"idcode") );
						m(ct).opc_usrcode	:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"usercode") );

						if query_member_register (Get_Field(Line,1),"trst_pin") = "none" then m(ct).trst_pin := false; else m(ct).trst_pin := true; end if;

					end if;
				end loop;
			Close(IdentInputFile);
			Set_Input(Previous_Input);
			return m;
		end;




	procedure write_safebits_preload
							( 
							 -- version 1.0 / MBL
							count_members 	: Natural;
							m 				: members
							) is

		Previous_Output	: File_Type renames Current_Output;
		ct				: Natural := 0;

		begin
			Open( 
				File => OutputFile,
				Mode => Append_File,
				Name => compose (to_string(test_name),to_string(test_name), "seq")
				);
			Set_Output(Outputfile); -- set data sink
			new_line; put (" -- set devices in sample/preload mode"); new_line;
			--put (m(3).safebits);

			while ct < count_members
				loop
					ct := ct + 1;
					
					--write device name in sequence file
					put (" set " & m(ct).device & " drv ir" & Integer'Image(m(ct).ir_length - 1) & " downto 0 = ");
					--put (m(ct).opc_idcode);
					if m(ct).opc_sample /= "undefined" then put ((m(ct).opc_sample) & " sample"); new_line;
					elsif m(ct).opc_preload /= "undefined" then put ((m(ct).opc_preload) & " preload"); new_line;
					elsif m(ct).opc_extest /= "undefined" then 
						put ((m(ct).opc_extest) & " extest"); new_line;
						new_line;
						put (" -- WARNING ! Device "& m(ct).device & " neither supports SAMPLE nor PRELOAD mode !"); new_line;
						put (" -- WARNING ! Device "& m(ct).device & " will be operated in EXTEST mode at test startup !"); new_line;
						new_line;
					else
						Set_Output(Standard_Output);
						put ("ERROR ! Device "& m(ct).device & " neither supports SAMPLE nor PRELOAD nor EXTEST mode !"); new_line;
						Abort_Task (Current_Task); -- CS: not safe
					end if;
				end loop;
			Close(OutputFile);
			Set_Output(Previous_Output);
			return;
		end;





	procedure write_capture_ir_values
							( 
							 -- version 1.0 / MBL
							count_members 	: Natural;
							m 				: members
							) is

		Previous_Output	: File_Type renames Current_Output;
		ct				: Natural := 0;

		begin
			Open( 
				File => OutputFile,
				Mode => Append_File,
				Name => compose (to_string(test_name),to_string(test_name), "seq")
				);
			Set_Output(Outputfile); -- set data sink
			new_line; put (" -- expect capture ir values"); new_line;

			while ct < count_members
				loop
					ct := ct + 1;
					put (" set " & m(ct).device & " exp ir" & Integer'Image(m(ct).ir_length - 1) & " downto 0 = " & m(ct).ir_capture & " instruction_capture" ); new_line;
				end loop;
			Close(OutputFile);
			Set_Output(Previous_Output);
			return;
		end;




	function write_sxr
					(
					-- version 1.0 / MBL
					vector_ct	: Natural;
					vector_type	: Natural
					)
					return Natural is

		Previous_Output	: File_Type renames Current_Output;
		scratch			: Natural;

		begin
			
			Open( 
				File => OutputFile,
				Mode => Append_File,
				Name => compose (to_string(test_name),to_string(test_name), "seq")
				);
			Set_Output(Outputfile); -- set data sink

			scratch := vector_ct;
			scratch := scratch + 1;
			if 		vector_type = 0 then put (" sdr id" & Integer'Image(scratch)); new_line;
			elsif 	vector_type = 1 then put (" sir id" & Integer'Image(scratch)); new_line;
			end if;

			Close(OutputFile);
			Set_Output(Previous_Output);
			return scratch;
		end;



	function write_sxr_file_open
					(
					-- version 1.0 / MBL
					vector_ct	: Natural;
					vector_type	: Natural
					)
					return Natural is

		--Previous_Output	: File_Type renames Current_Output;
		scratch			: Natural;

		begin
			
			--Open( 
			--	File => OutputFile,
			--	Mode => Append_File,
			--	Name => compose (to_string(test_name),to_string(test_name), "seq")
			--	);
			--Set_Output(Outputfile); -- set data sink

			scratch := vector_ct;
			scratch := scratch + 1;
			if 		vector_type = 0 then put (" sdr id" & Integer'Image(scratch)); new_line;
			elsif 	vector_type = 1 then put (" sir id" & Integer'Image(scratch)); new_line;
			end if;

			--Close(OutputFile);
			--Set_Output(Previous_Output);
			return scratch;
		end;




	procedure write_safebits_data
							( 
							 -- version 1.0 / MBL
							count_members 	: Natural;
							m 				: members
							) is

		Previous_Output	: File_Type renames Current_Output;
		ct				: Natural := 0;

		begin
			Open( 
				File => OutputFile,
				Mode => Append_File,
				Name => compose (to_string(test_name),to_string(test_name), "seq")
				);
			Set_Output(Outputfile); -- set data sink
			new_line; put (" -- safebits loading"); new_line;

			while ct < count_members
				loop
					ct := ct + 1;
					put (" set " & m(ct).device & " drv boundary" & Integer'Image(m(ct).bsr_length - 1) & " downto 0 = " & m(ct).safebits & " safebits"); new_line;
				end loop;

			put (" -- nothing meaningful to expect here"); new_line;
			ct := 0;
			while ct < count_members
				loop
					ct := ct + 1;
					put (" set " & m(ct).device & " exp boundary" & Integer'Image(m(ct).bsr_length - 1) & " downto 0 = x"); new_line;
				end loop;

			Close(OutputFile);
			Set_Output(Previous_Output);
			return;
		end;




	procedure write_all_extest
							( 
							 -- version 1.0 / MBL
							count_members 	: Natural;
							m 				: members
							) is

		Previous_Output	: File_Type renames Current_Output;
		ct				: Natural := 0;

		begin
			Open( 
				File => OutputFile,
				Mode => Append_File,
				Name => compose (to_string(test_name),to_string(test_name), "seq")
				);
			Set_Output(Outputfile); -- set data sink
			new_line; put (" -- set devices in extest mode"); new_line;

			while ct < count_members
				loop
					ct := ct + 1;
					
					if m(ct).opc_extest /= "undefined" then
						put (" set " & m(ct).device & " drv ir" & Integer'Image(m(ct).ir_length - 1) & " downto 0 = " & m(ct).opc_extest & " extest");
						new_line;
					else
						Set_Output(Standard_Output);
						put ("ERROR ! Device "& m(ct).device & " does not support EXTEST mode !"); new_line;
						Abort_Task (Current_Task); -- CS: not safe
					end if;
				end loop;
			Close(OutputFile);
			Set_Output(Previous_Output);
			return;
		end;




	procedure write_static_drive_values
							( 
							 -- version 1.0 / MBL
							count_members 	: Natural;
							m 				: members
							) is

		Previous_Output	: File_Type renames Current_Output;
		Previous_Input	: File_Type renames Current_Input;
		InputFile 		: Ada.Text_IO.File_Type;
		OutputFile 		: Ada.Text_IO.File_Type;
		ct				: Natural := 0;
		Line			: unbounded_string;
		device_found	: Boolean := false;
		last_cell		: Integer := -1;

		begin
			extract_section("tmp/udb_no_comments.tmp","tmp/cells1.tmp","Section","EndSection","locked_control_cells_in_class_EH_EL_NA_nets");
			extract_section("tmp/udb_no_comments.tmp","tmp/cells2.tmp","Section","EndSection","locked_control_cells_in_class_DH_DL_NR_nets");
			extract_section("tmp/udb_no_comments.tmp","tmp/cells3.tmp","Section","EndSection","locked_control_cells_in_class_PU_PD_nets");
			extract_section("tmp/udb_no_comments.tmp","tmp/cells4.tmp","Section","EndSection","locked_output_cells_in_class_PU_PD_nets");
			extract_section("tmp/udb_no_comments.tmp","tmp/cells5.tmp","Section","EndSection","locked_output_cells_in_class_DH_DL_nets");

			append_file("tmp/cells5.tmp","tmp/cells4.tmp");
			append_file("tmp/cells4.tmp","tmp/cells3.tmp");
			append_file("tmp/cells3.tmp","tmp/cells2.tmp");
			append_file("tmp/cells2.tmp","tmp/cells1.tmp");

			rename("tmp/cells1.tmp","tmp/cells_static_drive.tmp");

			Open( 
				File => OutputFile,
				Mode => Append_File,
				Name => compose (to_string(test_name),to_string(test_name), "seq")
				);
			Set_Output(Outputfile); -- set data sink

			-- open input_file
			Open( 
				File => InputFile,
				Mode => In_File,
				Name => "tmp/cells_static_drive.tmp"
				);
			Set_Input(InputFile); -- set data source

			new_line; put (" -- load static drive values"); new_line;

			while ct < count_members
				loop
					ct := ct + 1;
					while not End_Of_File
						loop
							Line:=Get_Line; -- from InputFile
							if (Get_Field_Count(Line) > 0) and ( m(ct).device = Get_Field(Line,6) ) then 
								if (device_found = false) then 
									device_found := true;
									put (" set " & m(ct).device & " drv boundary");
									put (" " & Get_Field(Line,10) & "=" & Get_Field(Line,13));
								else 
									put (" " & Get_Field(Line,10) & "=" & Get_Field(Line,13));
									--CS: last_cell := Integer'Value(Get_Field(Line,10)); -- CS: avoid writing the same cell multiple times
								end if;
							end if;
						end loop;
					new_line;
					Reset(InputFile);
					device_found := false;
				end loop;
			Close(InputFile); Close(OutputFile);
			Set_Output(Previous_Output); Set_Input(Previous_Input);
			return;
		end;



	procedure write_static_expect_values
							( 
							 -- version 1.0 / MBL
							count_members 	: Natural;
							m 				: members
							) is

		Previous_Output	: File_Type renames Current_Output;
		Previous_Input	: File_Type renames Current_Input;
		InputFile 		: Ada.Text_IO.File_Type;
		OutputFile 		: Ada.Text_IO.File_Type;
		ct				: Natural := 0;
		Line			: unbounded_string;
		device_found	: Boolean := false;
		last_cell		: Integer := -1;

		begin
			extract_section("tmp/udb_no_comments.tmp","tmp/cells_static_expect.tmp","Section","EndSection","static_expect");

			Open( 
				File => OutputFile,
				Mode => Append_File,
				Name => compose (to_string(test_name),to_string(test_name), "seq")
				);
			Set_Output(Outputfile); -- set data sink

			-- open input_file
			Open( 
				File => InputFile,
				Mode => In_File,
				Name => "tmp/cells_static_expect.tmp"
				);
			Set_Input(InputFile); -- set data source

			new_line; put (" -- expect static values"); new_line;

			while ct < count_members
				loop
					ct := ct + 1;
					while not End_Of_File
						loop
							Line:=Get_Line; -- from InputFile
							if (Get_Field_Count(Line) > 0) and ( m(ct).device = Get_Field(Line,6) ) then 
								if (device_found = false) then 
									device_found := true;
									put (" set " & m(ct).device & " exp boundary"); 
									put (" " & Get_Field(Line,10) & "=" & Get_Field(Line,12));
								else 
									put (" " & Get_Field(Line,10) & "=" & Get_Field(Line,12));
									--CS: last_cell := Integer'Value(Get_Field(Line,10)); -- CS: avoid writing the same cell multiple times
								end if;
							end if;
						end loop;
					new_line;
					Reset(InputFile);
					device_found := false;
				end loop;
			Close(InputFile); Close(OutputFile);
			Set_Output(Previous_Output); Set_Input(Previous_Input);
			return;
		end;



	function atg_mktoggle
				(
				-- version 1.0 / MBL
				count_members	: Natural;
				m				: members;
				--target_device	: String;
				target_net   	: String;
				vector_ct 		: Natural;
				test_name		: String;
				toggle_ct		: Natural;
				low_time		: Float;
				high_time		: Float
				)
				return Boolean is

		Previous_Output	: File_Type renames Current_Output;
		Previous_Input	: File_Type renames Current_Input;
		InputFile 		: Ada.Text_IO.File_Type;
		OutputFile 		: Ada.Text_IO.File_Type;
		vector_ct_tmp	: Natural := vector_ct;
		Line			: unbounded_string;
		scratch			: unbounded_string;		
		drv_value     	: string (1..1) := "1";	
		net_found		: Boolean := false;

		toggle_ct_tmp	: Natural := toggle_ct;
		low_time_tmp	: Float := low_time;
		high_time_tmp	: Float := high_time;

		begin
			-- open input_file
			Open( 
				File => InputFile,
				Mode => In_File,
				Name => "tmp/cells_atg_drive.tmp"
				);
			Set_Input(InputFile); -- set data source

			-- create and open seq file
			--Create( OutputFile, Name => (compose (test_name,test_name,"seq")) ); Close(OutputFile);
			Open( 
				File => OutputFile,
				Mode => Append_File,
				Name => compose (test_name,test_name,"seq")
				);
			Set_Output(OutputFile);
			
			-- search in cell list
			while not End_Of_File
				loop
					Line:=Get_Line; -- from InputFile
					if (Get_Field_Count(Line) > 0) then 
						--if Is_Field(Line,"Section",1) then -- section header found
						--	section_name := to_unbounded_string(Get_Field(Line,2)); 
						--end if;
						
						-- if target cell is type output (NR Net)
						if (Get_Field_Count(Line) = 10) and is_field(Line,"NR",2) then
						
							if Get_Field(Line,4) = target_net then -- on net name match
											
								net_found := true;
								-- CS: get init value from safebits
								--drv_value := 
								new_line;
								put (" -- toggle " & Line); new_line;	
								put (" --" & Natural'Image(toggle_ct) & " cycles of LH follow ..."); new_line;			
								put (" ----------------------------------------------------------------------------------------- "); new_line(2);
																
								for toggle_ct_tmp in 1..toggle_ct
									loop
										put (" -- cycle " & Natural'Image(toggle_ct_tmp)); new_line(2);
										
										put (" -- toggle L"); new_line;
										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=0"); new_line;
										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
										put (" delay "); put(low_time, fore=> 2, aft =>1, exp => 0); new_line(2);
																				
										put (" -- toggle H"); new_line;
										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=1"); new_line;
										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
										put (" delay "); put(high_time, fore=> 2, aft =>1, exp => 0); new_line(2);
										put (" ----------------------------- "); new_line;
									
									end loop;
							end if;
						end if;				
					
					 	-- if target cell is type control (PU, PD Net)
						if (Get_Field_Count(Line) = 12) and ( is_field(Line,"PU",2) or is_field(Line,"PD",2) ) then
						
							-- if net name matches and if no negation required
							if Get_Field(Line,4) = target_net and is_field(Line,"no",12) then 
								net_found := true;
								
								-- CS: get init value from safebits
								--drv_value := 
								new_line;
								put (" -- toggle " & Line); new_line;	
								put (" --" & Natural'Image(toggle_ct) & " cycles of LH follow ..."); new_line;			
								put (" ----------------------------------------------------------------------------------------- "); new_line(2);
																
								for toggle_ct_tmp in 1..toggle_ct
									loop
										put (" -- cycle " & Natural'Image(toggle_ct_tmp)); new_line(2);
										
										put (" -- toggle L"); new_line;
										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=0"); new_line;
										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
										put (" delay "); put(low_time, fore=> 2, aft =>1, exp => 0); new_line(2);
																				
										put (" -- toggle H"); new_line;
										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=1"); new_line;
										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
										put (" delay "); put(high_time, fore=> 2, aft =>1, exp => 0); new_line(2);
										put (" ----------------------------- "); new_line;
									
									end loop;
							end if; -- if net name matches and if no negation required

							-- if net name matches and if negation is required
							if Get_Field(Line,4) = target_net and is_field(Line,"yes",12) then 
								net_found := true;
								
								-- CS: get init value from safebits
								--drv_value := 
								new_line;
								put (" -- toggle " & Line); new_line;	
								put (" --" & Natural'Image(toggle_ct) & " cycles of LH follow ..."); new_line;			
								put (" ----------------------------------------------------------------------------------------- "); new_line(2);
																
								for toggle_ct_tmp in 1..toggle_ct
									loop
										put (" -- cycle " & Natural'Image(toggle_ct_tmp)); new_line(2);
										
										put (" -- toggle L"); new_line;
										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=1"); new_line;
										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
										put (" delay "); put(low_time, fore=> 2, aft =>1, exp => 0); new_line(2);
																				
										put (" -- toggle H"); new_line;
										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=0"); new_line;
										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
										put (" delay "); put(high_time, fore=> 2, aft =>1, exp => 0); new_line(2);
										put (" ----------------------------- "); new_line;
									
									end loop;
							end if;	-- if net name matches and if negation is required


						end if;				
					
					
					end if;				
				end loop;
				
			-- target net found ?
			if net_found = false then
				Set_Output(Standard_Output);
				--put("ERROR : Target device '" & target_device & "' does not have pin '" & driver_pin & "' !"); new_line;
				put("ERROR : Target net '" & target_net & "' search failed !"); new_line(2);
				put("        Troubleshooting: Please verify that"); new_line (2);
				put("        1. target net is a primary net !"); new_line;
				put("        2. target net is in class NR, PU or PD !"); new_line;
				--put("        3. driver pin '" & driver_pin & "' is in a primary net !"); new_line;				
				return false;  -- exit to mainline program -> ABORT
			end if;			
			
			new_line;
			put (" trst  -- comment out this line if necessary "); new_line; new_line;
			put ("EndSection"); new_line;
			
			Close(InputFile); --Close(OutputFile);
			--Set_Output(Previous_Output); 
			Set_Input(Previous_Input);
			new_line;
			return true;
		
		
		end atg_mktoggle;




		function umask( mask : integer ) return integer;
		pragma import( c, umask );


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin

	put("pin toggle generator version "& Version); new_line;

	data_base:=to_unbounded_string(Argument(1));
	put ("database       : ");	put(data_base); new_line;

	test_name:=to_unbounded_string(Argument(2));
	put ("test name      : ");	put(test_name); new_line;

	target_net:=to_unbounded_string(Argument(3));
	put ("target net     : "); put(target_net); new_line;
	
	prog_position := "TCT";	
	cycle_count:=Natural'Value(Argument(4));
	put ("cycle count    :" & Integer'Image(cycle_count)); new_line;
	if cycle_count > 50 or cycle_count < 1 then raise constraint_error; end if; 
	
	prog_position := "TLT";		
	low_time:=Float'Value(Argument(5));
	put ("low time       :"); put (low_time, fore=> 2, aft =>1, exp => 0); put(" sec"); new_line;
	if low_time > 25.0 or low_time < 0.1 then raise constraint_error; end if; 
	
	prog_position := "THT";		
	high_time:=Float'Value(Argument(6));
	put ("high time      :"); put (high_time, fore=> 2, aft =>1, exp => 0); put(" sec"); new_line;
	if high_time > 25.0 or high_time < 0.1 then raise constraint_error; end if; 	
	
	frequency := 1.0/(high_time + low_time);
	put ("freqency       :"); put (frequency, fore=> 2, aft =>2, exp => 0); put(" Hz"); new_line(2); -- & Float'Image(frequency)); new_line (2);	
	-- CS : frequency calculation ?
	
	dummy := umask ( 003 );

	-- rm v002 begin
	-- check if test exists and request user to confirm
-- 	if exists (compose (to_string(test_name),to_string(test_name), "seq")) then
-- 		put ("WARNING ! Net toggle test '"); put (test_name); put("' already exists. Overwrite ? (y/n) "); 
-- 		get (key); new_line;
-- 		if key = "n" then
-- 			prog_position := "OWR";
-- 			raise constraint_error;
-- 		else -- if answer is not "n" create test directory
-- 			Delete_Tree (to_string(test_name));
-- 		--	Create_Directory (to_string(test_name));
-- 		end if;
-- 	end if;
	-- rm v002 end

	-- ins v002 begin
	-- check if test exists and delete it
 	if exists (compose (to_string(test_name),to_string(test_name), "seq")) then
		Delete_Tree (to_string(test_name));
 	end if;
	-- ins v002 end

	


	-- recreate an empty tmp directory
	if exists ("tmp") then 
		Delete_Tree("tmp");
		Create_Directory("tmp");
	else Create_Directory("tmp");
	end if;

	--put ("reading database ..."); new_line;

	-- create description file
	Create_Directory(to_string(test_name));
	Create( OutputFile, Name => (compose (to_string(test_name),"exe_desc.txt")) );
	put (OutputFile,"Test description: write your info here ... ");
	Close(OutputFile);

	write_info_section; -- creates testname/testname.seq

	fraction_data_base;

	write_options_section; --  appends options to testname/testname.seq


	append_file ("setup/test_init_custom.txt", (compose (to_string(test_name),to_string(test_name), "seq")));


	-- count and identify chain members
	count_members := (count_chain_members("tmp/members.tmp"));

	--put (count_members); new_line;

	-- preset vector counter
	vector_ct := 0;

	-- safebit preloading
	
	-- write instructions in seq. file
	
	write_safebits_preload ( count_members, identify_chain_members(count_members) ); -- sets all members to sample/preload/extest
	write_capture_ir_values ( count_members, identify_chain_members(count_members) );
	vector_ct := write_sxr(vector_ct,1); -- 0 -> sdr , 1 -> s1r

	write_safebits_data ( count_members, identify_chain_members(count_members) ); -- loads safebits in bsr of all members
	vector_ct := write_sxr(vector_ct,0); -- 0 -> sdr , 1 -> s1r

	write_all_extest ( count_members, identify_chain_members(count_members) ); -- sets all members to extest
	vector_ct := write_sxr(vector_ct,1); -- 0 -> sdr , 1 -> s1r

	write_static_drive_values ( count_members, identify_chain_members(count_members) );
	vector_ct := write_sxr(vector_ct,0); -- 0 -> sdr , 1 -> sir

	write_static_expect_values ( count_members, identify_chain_members(count_members) );
	vector_ct := write_sxr(vector_ct,0); -- 0 -> sdr , 1 -> sir

	
	extract_section("tmp/udb_no_comments.tmp","tmp/cells_atg_drive.tmp","Section","EndSection","atg_drive");
--	Create( OutputFile, Name => (compose ("tmp","out_cells.tmp")) ); Close(OutputFile);
--	append_file("tmp/cells_static_drive.tmp","tmp/out_cells.tmp");	
--	append_file("tmp/cells_atg_drive.tmp","tmp/out_cells.tmp");
	
	-- ATG pin toggle test
	prog_position := "---";
	if atg_mktoggle
		(
		count_members, 
		identify_chain_members(count_members),
		--to_string(target_device), 
		to_string(target_net), 
		vector_ct,
		to_string(test_name),
		cycle_count,
		low_time,
		high_time
		) = false then raise constraint_error; end if;




--	vector_ct := write_sxr(vector_ct,0); -- 0 -> sdr , 1 -> sir

	exception
		when CONSTRAINT_ERROR => 
			if prog_position = "OWR" then
				new_line;									
				--put ("ERROR : Test generator aborted !"); new_line;
							
			elsif prog_position = "TCT" then
				new_line;									
				put ("ERROR : Cycle count must be a natural number between 1 and 50 !");
							
			elsif prog_position = "TLT" then
				new_line;									
				put ("ERROR : Low time must be in range 0.1 ... 25 sec. !");
							
			elsif prog_position = "THT" then
				new_line;									
				put ("ERROR : High time must be in range 0.1 ... 25 sec. !");
			
			end if;
			
			new_line (2);									
			put ("PROGRAM ABORTED !"); new_line;
			set_exit_status(1);
			-- new_line;
			--	put ("PROGRAM ABORTED !"); new_line; new_line;

			
end mktoggle;
