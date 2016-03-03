------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKINTERCON                          --
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


-- V3.3
-- user confirmation skipped
-- V3.4
-- bugfix: delete test directory if already there

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

procedure mkintercon is

	Version			: String (1..3) := "035";
	test_name  		: Unbounded_string;	
	data_base  		: Unbounded_string;

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




	function remove_comment_from_line	
						(
						-- version 1.0 / MBL
						Line	: unbounded_string  	-- given line to remove comment from
						)
						return unbounded_string is

		line_without_comment	: unbounded_string;

		line_length	:	Natural;					-- length of given line
		char_pt		:	Natural := 1;				-- charcter pointer (points to character being processed inside the given line)
		char_current:	Character;					-- holds current character being processed
		char_last	:	Character := ' ';			-- holds character processed previous to char_current

		begin
			line_length:=(Length(Line));
			while char_pt <= line_length
				loop
					char_current:=(To_String(Line)(char_pt));
					if (char_last = '-' and char_current = '-') then --comment found
						-- cut comment
						line_without_comment := to_unbounded_string(to_string(line_without_comment)(1..length(line_without_comment)-1));
						return line_without_comment;
					else -- proceed processing line
						line_without_comment := line_without_comment & char_current; -- append current charcter to line_without_comment
					end if;
						
					-- save last character
					char_last:=char_current;

					-- advance character pointer by one
					char_pt:=char_pt+1; 

					--put (char_current); put (" --"); new_line;
				end loop;
			return line_without_comment;
		end;
							



	function Is_Field	(
						-- version 1.0 / MBL
						Line	: unbounded_string;  	-- given line to examine
						Value 	: String ; 				-- given value to be tested for
						Field	: Natural				-- field number to expect value in
						) 
						return Boolean is 

		R			: 	Boolean := false; 			-- on match return true, else return false
		line_length	:	Natural;					-- length of given line
		char_pt		:	Natural := 1;				-- charcter pointer (points to character being processed inside the given line)
		value_length:	Natural;					-- length of given value
		IFS1		: 	constant Character := ' '; 				-- field separator space
		IFS2		: 	constant Character := Character'Val(9); -- field separator tabulator
		field_ct	:	Natural := 0;				-- field counter (the first field found gets number 1 assigned)
		field_pt	:	Natural := 1;				-- field pointer (points to the charcter being processed inside the current field)
		inside_field:	Boolean := true;			-- true if char_pt points inside a field
		char_current:	Character;					-- holds current character being processed
		char_last	:	Character := ' ';			-- holds character processed previous to char_current

		begin
			--put ("line  : "& Line); new_line;
			--put ("field : "); put (Field); new_line;
			--put ("value : "& Value); new_line;
			line_length:=(Length(Line));
			value_length:=(Length(To_Unbounded_String(Value)));
			while char_pt <= line_length
				loop
					--put (char_pt);
					char_current:=(To_String(Line)(char_pt)); 
					if char_current = IFS1 or char_current = IFS2 then
						inside_field := false;
					else
						inside_field := true;
					end if;
	
					-- count fields if character other than IFS found
					if ((char_last = IFS1 or char_last = IFS2) and (char_current /= IFS1 and char_current /= IFS2)) then
						field_ct:=field_ct+1;
					end if;

					if (Field = field_ct) then
						--put ("target field found"); new_line;
						if (inside_field = true) then -- if field entered
							--put ("target field entered"); 

							-- if Value is too short (to avoid constraint error at runtime)
							if field_pt > value_length then
								R := false;
								return R;
							end if;

							-- if character in value matches
							if Value(field_pt) = char_current then
								--put (field_pt); put (Value(field_pt)); new_line;
								field_pt:=field_pt+1;
							else
								-- on first mismatch exit
								--put ("mismatch"); new_line;
								R := false;
								return R;
							end if;

							-- in case the last field matches
							if char_pt = line_length then
								if (field_pt-1) = value_length then
									--put ("match at line end"); new_line;
									R := true;
									return R;
								end if;
							end if;

						else -- once field is left
							if (field_pt-1) = value_length then
								--put ("field left"); new_line;
								R := true;
								return R;
							end if;
						end if;
					end if;
						
					-- save last character
					char_last:=char_current;

					-- advance character pointer by one
					char_pt:=char_pt+1; 

					--put (char_current); put (" --"); new_line;
				end loop;

			R:=false;
			return R;
		end;


	function Get_Field_Count 
						(
						-- version 1.0 / MBL
						Line	: unbounded_string
						)
						return Natural is

		line_length	:	Natural;					-- length of given line
		char_pt		:	Natural := 1;				-- charcter pointer (points to character being processed inside the given line)
		IFS1		: 	constant Character := ' '; 				-- field separator space
		IFS2		: 	constant Character := Character'Val(9); -- field separator tabulator
		field_ct	:	Natural := 0;				-- field counter (the first field found gets number 1 assigned)
		field_pt	:	Natural := 1;				-- field pointer (points to the charcter being processed inside the current field)
		inside_field:	Boolean := true;			-- true if char_pt points inside a field
		char_current:	Character;					-- holds current character being processed
		char_last	:	Character := ' ';			-- holds character processed previous to char_current

		begin
			--put ("line  : "& Line); new_line;
			--put ("field : "); put (Field); new_line;
			--put ("value : "& Value); new_line;
			line_length:=(Length(Line));
			while char_pt <= line_length
				loop
					--put (char_pt);
					char_current:=(To_String(Line)(char_pt)); 
					if char_current = IFS1 or char_current = IFS2 then
						inside_field := false;
					else
						inside_field := true;
					end if;
	
					-- count fields if character other than IFS found
					if ((char_last = IFS1 or char_last = IFS2) and (char_current /= IFS1 and char_current /= IFS2)) then
						field_ct:=field_ct+1;
					end if;

					-- save last character
					char_last:=char_current;

					-- advance character pointer by one
					char_pt:=char_pt+1; 

					--put (char_current); put (" --"); new_line;
				end loop;
			
			return field_ct;
		end;
						


	function Get_Field	(
						-- version 1.0 / MBL
						Line	: unbounded_string;
						Field	: Natural
						)
						return string is

		Value		:	unbounded_string;			-- field content to return (NOTE: Value gets converted to string on return)
		line_length	:	Natural;					-- length of given line
		char_pt		:	Natural := 1;				-- charcter pointer (points to character being processed inside the given line)
		IFS1		: 	constant Character := ' '; 				-- field separator space
		IFS2		: 	constant Character := Character'Val(9); -- field separator tabulator
		field_ct	:	Natural := 0;				-- field counter (the first field found gets number 1 assigned)
		field_pt	:	Natural := 1;				-- field pointer (points to the charcter being processed inside the current field)
		inside_field:	Boolean := true;			-- true if char_pt points inside a field
		char_current:	Character;					-- holds current character being processed
		char_last	:	Character := ' ';			-- holds character processed previous to char_current

		begin
			--put ("line  : "& Line); new_line;
			--put ("field : "); put (Field); new_line;
			--put ("value : "& Value); new_line;
			line_length:=(Length(Line));
			while char_pt <= line_length
				loop
					--put (char_pt);
					char_current:=(To_String(Line)(char_pt)); 
					if char_current = IFS1 or char_current = IFS2 then
						inside_field := false;
					else
						inside_field := true;
					end if;
	
					-- count fields if character other than IFS found
					if ((char_last = IFS1 or char_last = IFS2) and (char_current /= IFS1 and char_current /= IFS2)) then
						field_ct:=field_ct+1;
					end if;

					if (Field = field_ct) then
						--put ("target field found"); new_line;
						if (inside_field = true) then -- if field entered
							--put ("target field entered"); 
							Value := Value & char_current;
							field_pt:=field_pt+1;
						end if;
					end if;

					if (field_ct > Field) then return to_string(Value); end if;

						
					-- save last character
					char_last:=char_current;

					-- advance character pointer by one
					char_pt:=char_pt+1; 

					--put (char_current); put (" --"); new_line;
				end loop;
			
			return to_string(Value);
		end;



	procedure remove_comments_from_file
						(
						-- version 1.0 / MBL
						input_file		:	in string;
						output_file		:	in string
						)
						is
		Previous_Output	: File_Type renames Current_Output;
		Previous_Input	: File_Type renames Current_Input;
		begin

			-- create output_file
			Create( OutputFile, Name => output_file );
			Set_Output(OutputFile);	-- all puts go there

			-- open input_file
			Open( 
				File => InputFile,
				Mode => In_File,
				Name => input_file
				);

			Set_Input(InputFile); -- all gets get sourced by data base

			while not End_Of_File 
				loop
					Line:=Get_Line;
					put (remove_comment_from_line(Line)); new_line;	
				end loop;
			Close(OutputFile); Close(InputFile); 
			Set_Output(Previous_Output); Set_Input(Previous_Input);
		end;


	procedure extract_netto_from_SubSection
						(
						-- version 1.0 / MBL
						input_file		:	in string; -- "tmp/chain.tmp"
						output_file		:	in string  -- "tmp/members.tmp"
						)
						is
		Previous_Output	: File_Type renames Current_Output;
		Previous_Input	: File_Type renames Current_Input;
		begin
			-- create output_file
			Create( OutputFile, Name => output_file );
			Set_Output(OutputFile);	-- set data sink

			-- open input_file
			Open( 
				File => InputFile,
				Mode => In_File,
				Name => input_file
				);

			Set_Input(InputFile); -- set data source

			while not End_Of_File 
				loop
					Line:=Get_Line;
					if Is_Field(Line,"SubSection",1) = false and Is_Field(Line,"EndSubSection",1) = false then 
						put(Line); new_line; 
					end if;
				end loop;
			Close(OutputFile); Close(InputFile); 
			Set_Output(Previous_Output); Set_Input(Previous_Input);
		end;
	

	procedure extract_section
						(
						-- version 1.0 / MBL
						input_file		:	in string; -- "tmp/udb_no_comments.tmp", 
						output_file		:	in string; -- "tmp/spc.tmp");
						section_begin_1	:	in string; -- "Section"
						section_end_1	:	in string; -- "EndSection", 
						section_begin_2	:	in string := ""; -- "scanpath_configuration"
						section_end_2 	:	in string := ""  -- optional
						)
						is

		section_entered	: boolean := false;
		section_left	: boolean := false;
		ExtractInputFile 	: Ada.Text_IO.File_Type;
		ExtractOutputFile 	: Ada.Text_IO.File_Type;
		Previous_Output	: File_Type renames Current_Output;
		Previous_Input	: File_Type renames Current_Input;
		begin
	
			-- create output_file
			Create( ExtractOutputFile, Name => output_file );
			Set_Output(ExtractOutputFile);	-- all puts go there

			-- open input_file
			Open( 
				File => ExtractInputFile,
				Mode => In_File,
				Name => input_file
				);
			Set_Input(ExtractInputFile); -- set data souce

			while not End_Of_File 
				loop
					Line:=Get_Line;
					-- on match of section_begin_1 and section_begin_2 set section_entered marker;
					if Is_Field(Line,section_begin_1,1) = true and Is_Field(Line,section_begin_2,2) = true then section_entered:=true; end if;
					if section_entered = true then put (Line); new_line; end if;

					-- search finished if section found and section_end_1 and section_end_2 found
					if section_entered = true and Is_Field(Line,section_end_1,1) = true then
						if Length(to_unbounded_string(section_end_2)) > 0 then -- check for section_end_2 if provided by mainline program only 
							if Is_Field(Line,section_end_2,2) = true then
								Close(ExtractInputFile); Close(ExtractOutputFile);
								Set_Output(Previous_Output); Set_Input(Previous_Input);
								return; -- exit to mainline program
							end if;
						else -- if no section_end_2 given
							Close(ExtractInputFile); Close(ExtractOutputFile);
							Set_Output(Previous_Output); Set_Input(Previous_Input);
							return; -- exit to mainline program
						end if;
					end if;
				end loop;
			Close(ExtractInputFile); Close(ExtractOutputFile);
			Set_Output(Previous_Output); Set_Input(Previous_Input);
			--exception 
			--	when others => 
			--		begin
			--			Set_Output(Standard_Output);		
			--			Put("--extract section debug--"); new_line;
						--put(Input_File); new_line;
						--put(Output_File); new_line;
			--		end;
		end;
	

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
			put (" created by interconnect test generator version "& version); new_line;
			put (" date       : " ); put (Image(clock)); new_line; 
			put (" UTC_Offset : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; 
			put (" database   : " & data_base); new_line;
			put (" algorithm  : true-complement"); new_line;
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



	procedure atg_mkintercon
				(
				-- version 1.0 / MBL
				count_members	: Natural;
				m				: members;
				vector_ct 		: Natural
				)
				is

			exponent		: Natural := 0;
			result 			: Natural := 0;
			dyn_ct			: Natural := 0;
			grp_ct			: Natural := 1;
			--x				: Natural := 0;
			grp_width		: Natural := 1;
			--z				: Boolean := true;
			step_ct			: natural;

			type interconnect_matrix is array (Natural range <>, Natural range <>) of String (1..1);

			Previous_Output	: File_Type renames Current_Output;
			Previous_Input	: File_Type renames Current_Input;
			InputFile 		: Ada.Text_IO.File_Type;
			OutputFile 		: Ada.Text_IO.File_Type;
			ct				: Natural := 0;
			Line			: unbounded_string;

		function build_interconnect_matrix	
									(
									-- version 1.0 / MBL
									dyn_ct	: Natural := 1;
									step_ct	: Natural := 1;
									mode	: Natural := 0		-- CS: use mode for further test algorithms
									)
									return interconnect_matrix is
									--is

			subtype interconnect_matrix_sized is interconnect_matrix (1..dyn_ct, 1..(step_ct*2));
			driver_matrix	: interconnect_matrix_sized;
			grp_ct			: Natural := 1;
			drv_high		: String (1..1) := "1";
			drv_low 		: String (1..1) := "0";
			scratch			: Natural := 1;
			drv_ptr			: Natural := 1;
			grp_ptr			: Natural := 0;
			step_ptr		: Natural := 0;

			begin
				--put ("dynamic net count rounded : "); put (dyn_ct); new_line;
				put (" -- steps required for true-complement test : "); put (step_ct*2,1); new_line; new_line;
				--put (" -- TRUE test"); new_line; new_line;

				grp_width := dyn_ct;
				while grp_width > 1
					loop
						step_ptr := step_ptr + 1;
						grp_width := grp_width / 2;
						grp_ct := grp_ct * 2;
						--put ("step number : "); put (step_ptr); new_line;
						--put ("group width : "); put (grp_width); new_line;
						--put ("group count : "); put (grp_ct); new_line; new_line;

						drv_ptr := 1;
						grp_ptr := 0;
						while grp_ptr < grp_ct
							loop
								grp_ptr := grp_ptr + 1;

								scratch := 1;
								while scratch <= grp_width
									loop
										--put (scratch); new_line;
										driver_matrix (drv_ptr,step_ptr) := drv_high;
										--put (driver_matrix(drv_ptr,step_ptr) & " ");
										scratch := scratch + 1;
										drv_ptr := drv_ptr + 1;
									end loop;

								grp_ptr := grp_ptr + 1;

								scratch := 1;
								while scratch <= grp_width
									loop
										--put (scratch); new_line;
										driver_matrix (drv_ptr,step_ptr) := drv_low;
										--put (driver_matrix(drv_ptr,step_ptr) & " ");
										scratch := scratch + 1;
										drv_ptr := drv_ptr + 1;
									end loop;
							end loop;
						--new_line;
					
					end loop;

				--put (" -- COMPLEMENT test"); new_line; new_line;
				grp_ct := 1;
				grp_width := dyn_ct;
				while grp_width > 1
					loop
						step_ptr := step_ptr + 1;
						grp_width := grp_width / 2;
						grp_ct := grp_ct * 2;
						--put ("step number : "); put (step_ptr); new_line;
						--put ("group width : "); put (grp_width); new_line;
						--put ("group count : "); put (grp_ct); new_line; new_line;

						drv_ptr := 1;
						grp_ptr := 0;
						while grp_ptr < grp_ct
							loop
								grp_ptr := grp_ptr + 1;

								scratch := 1;
								while scratch <= grp_width
									loop
										--put (scratch); new_line;
										driver_matrix (drv_ptr,step_ptr) := drv_low;
										--put (driver_matrix(drv_ptr,step_ptr) & " ");
										scratch := scratch + 1;
										drv_ptr := drv_ptr + 1;
									end loop;

								grp_ptr := grp_ptr + 1;

								scratch := 1;
								while scratch <= grp_width
									loop
										--put (scratch); new_line;
										driver_matrix (drv_ptr,step_ptr) := drv_high;
										--put (driver_matrix(drv_ptr,step_ptr) & " ");
										scratch := scratch + 1;
										drv_ptr := drv_ptr + 1;
									end loop;
							end loop;
						--new_line;
					
					end loop;

				return driver_matrix;
			end;


			function write_sxr_atg
							(
							-- version 1.0 / MBL
							vector_ct	: Natural;
							vector_type	: Natural
							)
							return Natural is

				Previous_Output	: File_Type renames Current_Output;
				scratch			: Natural;

				begin
					
				--	Open( 
				--		File => OutputFile,
				--		Mode => Append_File,
				--		Name => compose (to_string(test_name),to_string(test_name), "seq")
				--		);
				--	Set_Output(Outputfile); -- set data sink
					Set_Output(Standard_Output);
					put (".");
					Set_Output(Previous_Output);

					scratch := vector_ct;
					scratch := scratch + 1;
					if 		vector_type = 0 then put (" sdr id" & Integer'Image(scratch)); new_line;
					elsif 	vector_type = 1 then put (" sir id" & Integer'Image(scratch)); new_line;
					end if;

				--	Close(OutputFile);
				
					return scratch;
				end;


		procedure write_dynamic_drive_and_expect_values 
							( 
							count_members		: Natural;
							members_given		: members;
							matrix_current		: interconnect_matrix;
							vector_ct 			: Natural
							) is

			step_ptr	: Natural := 0;
			step_ct		: Natural := matrix_current'Last(2); -- get step count from matrix_current dimension
			dyn_ct		: Natural := matrix_current'Last(1); -- get dynamic net count from matrix_current dimension
			driver_id	: Natural := 0;
			device_ptr	: Natural := 0;
			device_ptr2	: Natural := 0;
			device_ptr3	: Natural := 0;
			atg_drive_list	: Ada.Text_IO.File_Type;
			atg_expect_list	: Ada.Text_IO.File_Type;
			--device_in_atg_drive_list : Boolean := false;
			m				: members := members_given;
			Line			: unbounded_string;
			Line2			: unbounded_string;
			vector_ct_atg	: Natural := vector_ct;

			begin
				put (" -- load dynamic drive and expect values"); new_line;

				extract_section("tmp/udb_no_comments.tmp","tmp/atg_drive.tmp","Section","EndSection","atg_drive");
				extract_section("tmp/udb_no_comments.tmp","tmp/atg_expect.tmp","Section","EndSection","atg_expect");

				-- open input_file
				Open( 
					File => atg_drive_list,
					Mode => In_File,
					Name => "tmp/atg_drive.tmp"
					);

				-- open input_file
				Open( 
					File => atg_expect_list,
					Mode => In_File,
					Name => "tmp/atg_expect.tmp"
					);


				--Set_Output(Standard_Output);

				-- eloaborate matrix_current dimensions
				--put (" -- step ct : "); put (step_ct); new_line;
				--put (" -- dyn  ct : "); put (dyn_ct); new_line;


				--search for at least one device entry in ATG expect list
				Set_Input(atg_expect_list);
				device_ptr := 0;
				while device_ptr < count_members
					loop
					-- loop here for each member
						device_ptr := device_ptr + 1; -- set device to be processed
						Reset(atg_expect_list);
						while not End_Of_File -- search in atg_expect_list
							loop
								Line:=Get_Line; -- from atg_expect_list
								if (Get_Field_Count(Line) > 0) and ( m(device_ptr).device = Get_Field(Line,6) ) then --if any device entry there
									m(device_ptr).bsr_expect := to_unbounded_string(" set " & to_string(m(device_ptr).device) & " exp boundary");
									m(device_ptr).bsr_expect_length := length(m(device_ptr).bsr_expect);
									--put ("seed : ");put (m(device_ptr).bsr_expect); new_line;
									exit; -- no more searching required if device found
								end if;
							end loop;

					end loop;


				while step_ptr < step_ct
					loop
						--loop here for each ATG step

						step_ptr := step_ptr + 1; put (" -- ATG step "); put (step_ptr,1); new_line;

						driver_id := 0;
						device_ptr := 0;
						while device_ptr < count_members
							loop
								-- loop here for each member
								device_ptr := device_ptr + 1; --put ("driver device " & m(device_ptr).device); new_line;

								--search for at least one device entry in ATG drive list
								Set_Input(atg_drive_list);
								Reset(atg_drive_list);
								while not End_Of_File
									loop
										Line:=Get_Line; -- from InputFile
										if (Get_Field_Count(Line) > 0) and ( m(device_ptr).device = Get_Field(Line,6) ) then --if any device entry there
											--device_in_atg_drive_list := true;
											m(device_ptr).bsr_drive := to_unbounded_string(" set " & to_string(m(device_ptr).device) & " drv boundary");
											exit; -- no more searching required if device found
										end if;
									end loop;

								--search for all device entries in ATG drive list
								Reset(atg_drive_list);
								while not End_Of_File
									loop
										Line:=Get_Line; -- from InputFile
										if (Get_Field_Count(Line) > 0) and ( m(device_ptr).device = Get_Field(Line,6) ) then --if device found

											driver_id := driver_id + 1; -- advance driver_id on each device match
											if Get_Field(Line,9) /= "control_cell" or Get_Field(Line,12) = "no" then
												-- append cell number and cell drive value to bsr_drive
												m(device_ptr).bsr_drive := m(device_ptr).bsr_drive & to_unbounded_string(" " & Get_Field(Line,10) &"="& matrix_current(driver_id,step_ptr));

											elsif Get_Field(Line,12) = "yes" then
												-- append cell number and inverted cell drive value to bsr_drive
												if matrix_current(driver_id,step_ptr) = "0" then
													m(device_ptr).bsr_drive := m(device_ptr).bsr_drive & to_unbounded_string(" " & Get_Field(Line,10) &"=1");
												else m(device_ptr).bsr_drive := m(device_ptr).bsr_drive & to_unbounded_string(" " & Get_Field(Line,10) &"=0");
												end if;
											end if;
										--	put ("--"); new_line;
											
										--end if;
											-- note: field 4 of current line holds primary net name

										

											-- now find input cells of other devices in current primary net in atg_expect_list

											Reset(atg_expect_list);
											Set_Input(atg_expect_list);

											device_ptr2 := 0;
											while device_ptr2 < count_members
												loop
													-- loop here for each member
													device_ptr2 := device_ptr2 + 1; --put ("receiver device " & m(device_ptr2).device); new_line;

													Reset(atg_expect_list);
													while not End_Of_File
														loop
															Line2:=Get_Line; -- from atg_expect_list
															-- if primary-net (field 3) and net-name match (field 4) and device match (field 6)
															if (Get_Field_Count(Line2) > 0) then
																if (Is_Field(Line2,"primary_net",3) = true) 
																	and (Get_Field(Line2,4) = Get_Field(Line,4)) 
																	and (Get_Field(Line2,6) = m(device_ptr2).device) then
																		m(device_ptr2).bsr_expect := m(device_ptr2).bsr_expect & to_unbounded_string(" " & Get_Field(Line2,10) &"="& matrix_current(driver_id,step_ptr)); 
																end if;
															end if;
														end loop;
													--put (m(device_ptr2).bsr_expect); new_line;
												end loop;

											
											--find input cells in secondary nets
											device_ptr2 := 0;
											while device_ptr2 < count_members
												loop
													-- loop here for each member
													device_ptr2 := device_ptr2 + 1; --set device to be processed for secondary net input search	
													--put ("-- sec dev ptr: "); put (device_ptr2); new_line;
													Reset(atg_expect_list);
													while not End_Of_File
														loop
															Line2:=Get_Line; -- from atg_expect_list
															if (Get_Field_Count(Line2) > 0) then
																if (Is_Field(Line2,"secondary_net",3) = true)	-- if secondary_net
																and Get_Field(Line2,12) = Get_Field(Line,4)  	-- if primary_net matches
																and Get_Field(Line2,6) = m(device_ptr2).device then -- if device matches
																	--put ("-- sec dev ptr: "); put (device_ptr2); new_line;
																	m(device_ptr2).bsr_expect := m(device_ptr2).bsr_expect & to_unbounded_string(" " & Get_Field(Line2,10) &"="& matrix_current(driver_id,step_ptr)); 
																end if;	
															end if;
														end loop;
												end loop;

										end if;
										Set_Input(atg_drive_list);

									end loop;
							
							end loop;
			
						-- step processing done

						-- write drive values
						device_ptr3 := 0;
						while device_ptr3 < count_members
							loop
								device_ptr3 := device_ptr3 + 1;
								put (m(device_ptr3).bsr_drive); new_line;
							end loop;

						vector_ct_atg := write_sxr_atg(vector_ct_atg,0); -- 0 -> sdr , 1 -> sir

						-- write expect values
						device_ptr3 := 0;
						while device_ptr3 < count_members
							loop
								device_ptr3 := device_ptr3 + 1;
								if Length(m(device_ptr3).bsr_expect) > m(device_ptr3).bsr_expect_length then 
									put (m(device_ptr3).bsr_expect); new_line;
									m(device_ptr3).bsr_expect := to_unbounded_string(" set " & to_string(m(device_ptr3).device) & " exp boundary");
								end if;
							end loop;
						new_line;

						

					end loop;
				
				close(atg_drive_list);
				close(atg_expect_list);

				vector_ct_atg := write_sxr_atg(vector_ct_atg,0); -- 0 -> sdr , 1 -> sir
				new_line;
				put (" trst  -- comment out this line if necessary "); new_line; new_line;
				put ("EndSection"); new_line;
			end write_dynamic_drive_and_expect_values;





		begin
			extract_section("tmp/udb_no_comments.tmp","tmp/statistics.tmp","Section","EndSection","statistics");

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
				Name => "tmp/statistics.tmp"
				);
			Set_Input(InputFile); -- set data source

			while not End_Of_File
				loop
					Line:=Get_Line; -- from InputFile
					if (Get_Field_Count(Line) > 0) and ( Is_Field(Line,"dynamic",2) = true) then 
						dyn_ct := Natural'Value( Get_Field(Line,4) );
						new_line;
						put (" -- generating test pattern for " & Get_Field(Line,4) & " dynamic nets ..."); new_line;
					end if;
				end loop;
					
			-- round up dynamic net count to next member in sequence 1,2,4,18,16,32,64, ...
			while result < dyn_ct
				loop
				exponent := exponent + 1;
				result := 2 ** exponent;
				end loop;
			dyn_ct := result;
			step_ct:=Natural(Float'Ceiling( log (base => 2.0, X => float(dyn_ct) ) ) );

			--build_interconnect_matrix (dyn_ct,step_ct,0);
			write_dynamic_drive_and_expect_values ( count_members, m , build_interconnect_matrix (dyn_ct,step_ct,0) , vector_ct);



			Close(InputFile); Close(OutputFile);
			Set_Output(Previous_Output); Set_Input(Previous_Input);
		end atg_mkintercon;


		function umask( mask : integer ) return integer;
		pragma import( c, umask );


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin

	put("interconnect test generator version "& Version); new_line;

	data_base:=to_unbounded_string(Argument(1));
	put ("data base      : ");	put(data_base); new_line;

	test_name:=to_unbounded_string(Argument(2));
	put ("test name      : ");	put(test_name); new_line;

	-- CS: algorithm:=to_unbounded_string(Argument(2));
	put ("algorithm      : true-complement"); new_line(2);

	dummy := umask ( 003 );
	
	-- removed begin in V3.3
	
	-- check if test exists and request user to confirm 
-- 	if exists (compose (to_string(test_name),to_string(test_name), "seq")) then
-- 		put ("WARNING ! Interconnect Test '"); put (test_name); put("' already exists. Overwrite ? (y/n) "); 
-- 		get (key); new_line;
-- 		if key = "n" then
-- 			prog_position := "OWR";
-- 			raise constraint_error;
-- 		else -- if answer is not "n" create test directory
-- 			Delete_Tree (to_string(test_name));
-- 		--	Create_Directory (to_string(test_name));
-- 		end if;
-- 	end if;

--	Delete_Tree (to_string(test_name)); -- ins V3.3 instead of user confirmation

	-- removed end in V3.3

	-- added begin in V3.4
	
	-- check if test exists and request user to confirm 
 	if exists (compose (to_string(test_name),to_string(test_name), "seq")) then
-- 		put ("WARNING ! Interconnect Test '"); put (test_name); put("' already exists. Overwrite ? (y/n) "); 
-- 		get (key); new_line;
-- 		if key = "n" then
-- 			prog_position := "OWR";
-- 			raise constraint_error;
-- 		else -- if answer is not "n" create test directory
 			Delete_Tree (to_string(test_name));
-- 		--	Create_Directory (to_string(test_name));
-- 		end if
 	end if;

	-- added end in V3.4
	




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

	-- ATG interconnect test
	atg_mkintercon(count_members, identify_chain_members(count_members),vector_ct);




--	vector_ct := write_sxr(vector_ct,0); -- 0 -> sdr , 1 -> sir

	exception
		when CONSTRAINT_ERROR => 
			if prog_position = "OWR" then
				--new_line;									
				--put ("ERROR : Test generator aborted !"); new_line;
				set_exit_status(1);
							
			end if;
			
			-- new_line;
			--	put ("PROGRAM ABORTED !"); new_line; new_line;

			
end mkintercon;
