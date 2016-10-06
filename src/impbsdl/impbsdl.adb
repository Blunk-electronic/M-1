------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE IMPBSDL                             --
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
with Ada.IO_Exceptions; use Ada.IO_Exceptions;
 
with GNAT.OS_Lib;   	use GNAT.OS_Lib;
with Ada.Command_Line;	use Ada.Command_Line;
with Ada.Directories;	use Ada.Directories;
 
with Ada.Calendar;				use Ada.Calendar;
with Ada.Calendar.Formatting;	use Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;	use Ada.Calendar.Time_Zones;

with m1; use m1;

procedure impbsdl is

	Version			: String (1..3) := "034";
	data_base  		: Unbounded_string;

	udb_work		: Ada.Text_IO.File_Type;
	InputFile 		: Ada.Text_IO.File_Type;

	OutputFile 		: Ada.Text_IO.File_Type;
	scratch			: Natural := 0;

	Line			: Unbounded_string;
	count_members	: Natural := 0; -- holds number of chain members


	type single_member is
		record				
			device		: Unbounded_String;
			packge		: Unbounded_String;
			model 		: Unbounded_String;
			options		: Boolean := false;
			--chain		: Natural := 0;
			position	: Natural := 0;
		end record;

	type members is array (Natural range <>) of single_member; --unbounded_string;


	type device_map is 
		record 
			port_pin_map 		: Ada.Text_IO.File_Type;
			port_io_map 		: Ada.Text_IO.File_Type;
			boundary_register	: Ada.Text_IO.File_Type;
		end record;
	type array_device_map is array (Natural range <>) of device_map;


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



	vector_ct		: Natural := 0;



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



	function count_chain_members_a
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
					end if;
				end loop;
			Close(CountInputFile);
			Set_Input(Previous_Input);
			return count_members;
		end;




	procedure examine_chain_members
					(
					-- version 1.0 / MBL
					input_file : string;
					count_members : Natural
					)
					is

		CountInputFile 	: Ada.Text_IO.File_Type;
		options        	: Ada.Text_IO.File_Type;
		Previous_Input	: File_Type renames Current_Input;
		Previous_Output	: File_Type renames Current_Output;
		scratch			: Natural := 0;

		subtype members_sized is members(1..count_members);
		m	: members_sized;



		procedure extract_port_pin_map
							(
							-- version 1.0 / MBL
							input_file	:	in string; -- "tmp/udb_no_comments.tmp", 
							output_file	:	in string; -- "tmp/spc.tmp");
							packge	 	:	in string;  -- package name
							device		:	in string -- device name
							)
							is

			section_entered	: boolean := false;
			vector_entered	: boolean := false;
			ExtractInputFile 	: Ada.Text_IO.File_Type;
			ExtractOutputFile 	: Ada.Text_IO.File_Type;
			OptionsFile 	: Ada.Text_IO.File_Type;
			Previous_Output	: File_Type renames Current_Output;
			Previous_Input	: File_Type renames Current_Input;
			scratch				: unbounded_string;
			line   				: unbounded_string;
			remove_pin_prefix 	: unbounded_string;
			remove_pin_prefix_length	: Natural := 0; -- when zero, do not apply option !
			line_length		:	Natural;					-- length of given line
			char_pt			:	Natural := 0;				-- charcter pointer (points to character being processed inside the given line)
			char_current	:	Character;					-- holds current character being processed
			char_last		:	Character := ' ';			-- holds character processed previous to char_current
			pin_name_entered	: Boolean := false;
			ct					: Natural := 0;

			begin
				-- check if there is an options file
				Set_Output(Standard_Output);
				if exists("tmp/options_" & device & ".tmp") then
					Open( 
						File => OptionsFile,
						Mode => In_File,
						Name => "tmp/options_" & device & ".tmp"
						);
					Set_Input(OptionsFile); -- set data souce
	
					while not End_Of_File
						loop
							line:=Get_Line;
							if Get_Field_Count(Line) > 0 then
								if is_Field(Line,"option",1) then
									put ("   -- applying option ");
									if is_Field(Line,"remove_pin_prefix",2) then
										remove_pin_prefix:= to_unbounded_string(Get_Field(Line,3));
										remove_pin_prefix_length := Length(to_unbounded_string(Get_Field(Line,3)));
										put ("'remove_pin_prefix " & Get_Field(Line,3) & "' ..."); new_line;
									end if;
								end if;
							end if;
						end loop;
					Close(OptionsFile);
				end if;

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

				put_line("  SubSection port_pin_map -- for package " & packge);
				put_line("  -- port pin(s)");
				put("     ");

				-- convert port_pin_map to a single long line
				search_package_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- on match of package set section_entered marker;
						if Is_Field(Line,"constant",1) and (Is_Field(Line,packge,2) or Is_Field(Line,packge & ":",2)) then
							section_entered:=true; 
							--put_line("  -- for package " & packge);
						end if;

						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));

							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));

									if is_control(char_current) = false then -- skip all control charcters 
										case char_current is
											when ';' => exit search_package_section; -- end of section found
											when ' ' => null; -- skip space 
											when '"' => null; -- skip hyphen
											when '&' => null; -- skip apersand
											when others => scratch := scratch & char_current; -- append other characters to scratch
										end case;
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_package_section; -- search_package_section
				
				-- delete header of port_pin_map line
				scratch := split_line(scratch,false,'=');

				-- put(scratch); new_line; -- debug

				-- write section port_pin_map
				line_length := Length(scratch);
				char_pt := 0;
				while char_pt <= (line_length - 1 )
					loop
						-- advance character pointer
						char_pt:=char_pt+1; 
						char_current:=(To_String(scratch)(char_pt));

						case char_current is
-- 							when '(' => vector_entered := true; 
-- 							when ')' => vector_entered := false;
-- 							when ',' => if vector_entered then put(' ');
-- 										else new_line; put("     "); end if;
-- 							when ':' => put(' ');
-- 							when others => put(char_current);

							when '(' => vector_entered := true;
										
							when ')' => vector_entered := false; pin_name_entered := false;
							when ',' => pin_name_entered := false;
										if vector_entered then put(' ');
										else new_line; put("     "); end if;
							when ':' => put(' ');

							when others => 
								if char_pt > 2 then -- if a single pin entered, set pin_name_entered flag
									if To_String(scratch)(char_pt-1) = ':' then pin_name_entered := true; end if;
								end if;
								if char_pt > 3 then -- if a pin vector entered, set pin_name_entered flag
									if To_String(scratch)(char_pt-2) = ':' and To_String(scratch)(char_pt-1) = '(' then pin_name_entered := true; end if;
								end if;

								if vector_entered then --if inside a vector and comma found, set pin_name_entered flag
									if To_String(scratch)(char_pt-1) = ',' then pin_name_entered := true; end if;
								end if;

								-- do the prefix check if prefix defined at all (prefix lenght greater than 0)
								if remove_pin_prefix_length = 0 then put(char_current); -- if no prefix check, put current char immediately
								else -- do the prefix check if pin entered now: (port name is not affected)
									if pin_name_entered then
										for ct in 1..remove_pin_prefix_length  -- look ahead if prefix is part of pin name
											loop
												-- on mismatch at any position, cancel prefix check and put current character
												-- do nothing if prefix found (the prefix is skipped this way)
												if To_String(remove_pin_prefix)(ct) /= To_String(scratch)(char_pt+ct-1) then 
													put(char_current); 
													exit;
												end if;
											end loop;
									-- put all other characters (port names, pin names, pin numbers)
									else put(char_current); 
									end if;
								end if;
						end case;

					end loop;

				new_line;
				put("  EndSubSection"); new_line;

				Close(ExtractInputFile); Close(ExtractOutputFile);
				Set_Output(Previous_Output); Set_Input(Previous_Input);

			end extract_port_pin_map;
		

		procedure extract_opcodes
							(
							-- version 1.0 / MBL
							input_file	:	in string; 
							output_file	:	in string
							)
							is

			section_entered	: boolean := false;
			opcode_bin_entered	: Boolean := false;
			ExtractInputFile 	: Ada.Text_IO.File_Type;
			ExtractOutputFile 	: Ada.Text_IO.File_Type;
			Previous_Output	: File_Type renames Current_Output;
			Previous_Input	: File_Type renames Current_Input;
			scratch			: unbounded_string;
			line_length		:	Natural;					-- length of given line
			char_pt			:	Natural := 0;				-- charcter pointer (points to character being processed inside the given line)
			char_current	:	Character;					-- holds current character being processed
			char_last		:	Character := ' ';			-- holds character processed previous to char_current
			field			:	Natural := 1;
			opc_line		:	unbounded_string;

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

				put("  SubSection instruction_opcodes"); new_line;
				put("  -- instruction opcode [alternative opcode]"); new_line;
				put("     ");

				-- convert opcodes to a single long line
				search_opcodes_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if instruction opcodes section found
						if Is_Field(Line,"attribute",1) and Is_Field(Line,"instruction_opcode",2) then section_entered:=true; end if;

						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));

							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));

									if is_control(char_current) = false then -- skip all control charcters 
										case char_current is
											when ';' => exit search_opcodes_section; -- end of section found
											--when ' ' => null; -- skip space 
											--when '"' => null; -- skip hyphen
											when '"' => scratch := scratch & ' '; -- replace hyphen by space
											when '&' => null; -- skip apersand
											when others => scratch := scratch & char_current; -- append other characters to scratch
										end case;
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_opcodes_section; -- search_opcodes_section

				--Set_Output(Standard_Output);
				--put(scratch); new_line;


				-- delete header of opcodes line
				-- modification in version 34 begin
				if get_field(scratch,5) = ":" then	-- if name and following colon are separated by " " , i.e. "attribute instruction_opcode of stm32_ufga176 : entity is ..."
					for field in 8..Get_Field_Count(scratch)
						loop
							opc_line := opc_line & Get_Field(scratch,field);
						end loop;
				else -- if name and following colon are not separated, i.e. "attribute instruction_opcode of stm32_ufga176: entity is ..."
					for field in 7..Get_Field_Count(scratch)
						loop
							opc_line := opc_line & Get_Field(scratch,field);
						end loop;
				end if;
				-- modification in version 34 end

				--put (opc_line); new_line;

				-- write section instruction_opcodes
				line_length := Length(opc_line);
				char_pt := 0;
				while char_pt <= (line_length - 1 )
					loop
						-- advance character pointer
						char_pt:=char_pt+1; 
						char_current:=(To_String(opc_line)(char_pt));

						case char_current is
							when '(' => opcode_bin_entered := true; put(' '); 
							when ')' => opcode_bin_entered := false;
							when ',' => if opcode_bin_entered then put(' ');
										else new_line; put("     "); end if;
							when others => put(char_current);
						end case;

					end loop;

				new_line;
				put("  EndSubSection"); new_line;

				Close(ExtractInputFile); Close(ExtractOutputFile);
				Set_Output(Previous_Output); Set_Input(Previous_Input);

			end extract_opcodes;
		

		procedure extract_bsr
							(
							-- version 1.0 / MBL
							input_file	:	in string; 
							output_file	:	in string
							)
							is

			section_entered	: boolean := false;
			cell_list_entered	: boolean := false;
			bracket_ct		:	Natural := 0;
			ExtractInputFile 	: Ada.Text_IO.File_Type;
			ExtractOutputFile 	: Ada.Text_IO.File_Type;
			Previous_Output	: File_Type renames Current_Output;
			Previous_Input	: File_Type renames Current_Input;
			scratch			: unbounded_string;
			line_length		:	Natural;					-- length of given line
			char_pt			:	Natural := 0;				-- charcter pointer (points to character being processed inside the given line)
			char_current	:	Character;					-- holds current character being processed
			char_last		:	Character := ' ';			-- holds character processed previous to char_current
			field			:	Natural := 1;
			bsr_line		:	unbounded_string;

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

				put("  SubSection boundary_register"); new_line;
				put("  -- num cell port function safe [control_cell disable_value disable_result]"); new_line;
				put("     ");

				-- convert bsr to a single long line
				search_bsr_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if bsr section section found
						if Is_Field(Line,"attribute",1) and Is_Field(Line,"boundary_register",2) then section_entered:=true; end if;

						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));

							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));

									if is_control(char_current) = false then -- skip all control charcters 
										if char_current = '"' then cell_list_entered := true; end if;

										if cell_list_entered then
											case char_current is
												when ';' => exit search_bsr_section; -- end of section found
												--when ' ' => null; -- skip space 
												when '"' => scratch := scratch & ' '; -- replace hyphen by space
												when '&' => null; -- skip apersand
												when others => scratch := scratch & char_current; -- append other characters to scratch
											end case;

										end if;
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_bsr_section; -- search_bsr_section

				--Set_Output(Standard_Output); put(scratch); new_line; Set_Output(Previous_Output);

				-- delete header of bsr line
--				for field in 8..Get_Field_Count(scratch)
--					loop
--						bsr_line := bsr_line & Get_Field(scratch,field);
--					end loop;

				--Set_Output(Standard_Output); put (bsr_line); new_line; Set_Output(Previous_Output);
	
				bsr_line := scratch;			

				-- write section boundary_register
				line_length := Length(bsr_line);
				char_pt := 0;
				while char_pt <= (line_length - 1 )
					loop
						-- advance character pointer
						char_pt:=char_pt+1; 
						char_current:=(To_String(bsr_line)(char_pt));

						case char_current is
							when ' ' => null;
							when '(' => if bracket_ct = 0 then put (" "); end if;
										if bracket_ct = 1 then put (char_current); end if;	
										bracket_ct := bracket_ct + 1; 
							when ')' => if bracket_ct = 2 then put (char_current); end if;
										bracket_ct := bracket_ct - 1;
							when ',' => if bracket_ct = 0 then new_line; put("     "); -- put(' ');
										else put(" "); end if;
							-- CS: replace first * by - ?
							when others => put(char_current);
						end case;

					end loop;

				new_line;
				put("  EndSubSection"); new_line;

				Close(ExtractInputFile); Close(ExtractOutputFile);
				Set_Output(Previous_Output); Set_Input(Previous_Input);

			end extract_bsr;
		



		procedure extract_port_io_map
							(
							-- version 1.0 / MBL
							input_file	:	in string; 
							output_file	:	in string
							)
							is

			section_entered	: boolean := false;
			bracket_ct		:	Natural := 0;
			ExtractInputFile 	: Ada.Text_IO.File_Type;
			ExtractOutputFile 	: Ada.Text_IO.File_Type;
			Previous_Output	: File_Type renames Current_Output;
			Previous_Input	: File_Type renames Current_Input;
			scratch			: unbounded_string;
			line_length		:	Natural;					-- length of given line
			char_pt			:	Natural := 0;				-- charcter pointer (points to character being processed inside the given line)
			char_current	:	Character;					-- holds current character being processed
			char_last		:	Character := ' ';			-- holds character processed previous to char_current
			field			:	Natural := 1;
			port_line		:	unbounded_string;

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

				put("  SubSection port_io_map"); new_line;
				put("  -- port(s) : direction [up/down vector]"); new_line;
				put("    ");

				-- convert port_io_map to a single long line
				search_port_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if port section section found
						if Is_Field(Line,"port",1) then section_entered:=true; end if;

						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));

							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));

									if is_control(char_current) = false then -- skip all control charcters 
										case char_current is
											when '(' => bracket_ct := bracket_ct + 1; scratch := scratch & ' ';
											when ')' => bracket_ct := bracket_ct - 1; scratch := scratch & ' ';
											when ';' => scratch := scratch & ' ' & char_current & ' ' ; if bracket_ct = 0 then exit search_port_section; end if; -- end of section found
											when ':' => scratch := scratch & ' ';
											when others => scratch := scratch & char_current; -- append other characters to scratch
										end case;
									elsif char_current = ascii.ht then -- replace horizontal tabs by space
										scratch := scratch & ' ';
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_port_section; -- search_bsr_section

	--			Set_Output(Standard_Output);
	--			scratch := split_line(scratch,false,'=');

--				put (scratch); new_line(2);
	--			Abort_Task(Current_Task);

				-- delete header of port line,
				-- remove words "bit", "bit_vector"
				-- insert " : " after port name
				for field in 2..Get_Field_Count(scratch)
					loop
						if Is_Field(scratch,"bit",field) and Is_Field(scratch,";",field + 1) then null;
						elsif Is_Field(scratch,"bit_vector",field) and Is_Field(scratch,";",field + 4) then null;
						elsif Is_Field(scratch,"out",field) or Is_Field(scratch,"in",field) or Is_Field(scratch,"inout",field) or Is_Field(scratch,"linkage",field) then
							port_line := port_line & " : " & Get_Field(scratch,field);
						else port_line := port_line & ' ' & Get_Field(scratch,field);
						end if;
					end loop;

				--put (port_line); new_line;

				-- write section port_io_map
				line_length := Length(port_line);
				char_pt := 0;
				while char_pt <= (line_length - 1 )
					loop
						-- advance character pointer
						char_pt:=char_pt+1; 
						char_current:=(To_String(port_line)(char_pt));

						case char_current is
							when ';' => new_line; put("    "); -- use ; as end of line mark
							when ',' => null; -- skip commas
							-- CS: replace first * by - ?
							when others => put(char_current);
						end case;

					end loop;

				new_line;
				put("  EndSubSection"); new_line;

				Close(ExtractInputFile); Close(ExtractOutputFile);
				Set_Output(Previous_Output); Set_Input(Previous_Input);

			end extract_port_io_map;
		



		function extract_misc
							(
							-- version 1.0 / MBL
							input_file	:	in string;
							output_file	:	in string
							)
							return Natural is

			section_entered	: boolean := false;
			bracket_ct		:	Natural := 0;
			ExtractInputFile 	: Ada.Text_IO.File_Type;
			ExtractOutputFile 	: Ada.Text_IO.File_Type;
			Previous_Output	: File_Type renames Current_Output;
			Previous_Input	: File_Type renames Current_Input;
			scratch			: unbounded_string;
			line_length		:	Natural;					-- length of given line
			char_pt			:	Natural := 0;				-- charcter pointer (points to character being processed inside the given line)
			char_current	:	Character;					-- holds current character being processed
			char_last		:	Character := ' ';			-- holds character processed previous to char_current
			field			:	Natural := 1;
			port_line		:	unbounded_string;
			bsr_length		:	Natural := 0;

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

				-- EXTRACT VALUE
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if entity found
						if Is_Field(Line,"entity",1) then put("  value " & Get_Field(Line,2)); new_line; new_line; exit; end if;
					end loop;


				-- EXTRACT IR LENGTH
				Set_Output(Standard_Output); put ("   -- extracting instruction register length ..."); new_line; Set_Output(ExtractOutputFile);
				put("  instruction_register_length ");
				Reset(ExtractInputFile);

				-- convert ir_length entry to a single long line
				search_irl_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if attribute instruction_length found
						if Is_Field(Line,"attribute",1) and Is_Field(Line,"instruction_length",2) then section_entered:=true; end if;
						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));
							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));

									if is_control(char_current) = false then -- skip all control charcters 
										case char_current is
											when ';' => exit search_irl_section; -- end of section found
											when ':' => scratch := scratch & ' ';
											when others => scratch := scratch & char_current; -- append other characters to scratch
										end case;
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_irl_section; -- search_irl_section
				--Set_Output(Standard_Output);
				--put (scratch); new_line;
				--Abort_Task(Current_Task);

				-- delete header of irl line, just put ir length
				put (Get_Field(scratch,7)); new_line;
				section_entered := false;				-- clear section_entered flag
				scratch := to_unbounded_string("");		-- clear scratch


				-- EXTRACT IR CAPTURE
				Set_Output(Standard_Output); put ("   -- extracting instruction capture value ..."); new_line; Set_Output(ExtractOutputFile);
				put("  instruction_capture         ");
				Reset(ExtractInputFile);

				-- convert ir_capture entry to a single long line
				search_irc_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if attribute instruction_capture found
						if Is_Field(Line,"attribute",1) and Is_Field(Line,"instruction_capture",2) then section_entered:=true; end if;
						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));
							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));

									if is_control(char_current) = false then -- skip all control charcters 
										case char_current is
											when ';' => exit search_irc_section; -- end of section found
											when ':' => scratch := scratch & ' ';
											when '"' => scratch := scratch & ' ';
											when others => scratch := scratch & char_current; -- append other characters to scratch
										end case;
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_irc_section; -- search_irc_section

				--Set_Output(Standard_Output);
				--put (scratch); new_line;
				--Abort_Task(Current_Task);

				-- delete header of irc line, just put ir capture
				put (Get_Field(scratch,7)); new_line;
				section_entered := false;				-- clear section_entered flag
				scratch := to_unbounded_string("");		-- clear scratch


				-- EXTRACT ID CODE
				Set_Output(Standard_Output); put ("   -- extracting idcode ..."); new_line; Set_Output(ExtractOutputFile);
				put("  idcode_register             ");
				Reset(ExtractInputFile);

				-- convert id_code entry to a single long line
				search_idc_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if attribute idcode_register found
						if Is_Field(Line,"attribute",1) and Is_Field(Line,"idcode_register",2) then section_entered:=true; end if;
						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));
							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));
						
									if is_control(char_current) = false then -- skip all control charcters 
										case char_current is
											when ';' => exit search_idc_section; -- end of section found
											when '&' => null; --scratch := scratch & ' ';
											--when '"' => null; --scratch := scratch & ' ';
											when '"' => scratch := scratch & ' '; -- replace hyphen by space
											when ':' => scratch := scratch & ' ';
											when others => scratch := scratch & char_current; -- append other characters to scratch
										end case;
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_idc_section; -- search_idc_section

				--Set_Output(Standard_Output);
				--put (scratch); new_line;
				--Abort_Task(Current_Task);

				if section_entered then
					-- delete header of idcode line, just put idcode
					for field in 7..Get_Field_Count(scratch)
						loop
							put (Get_Field(scratch,field));
						end loop;
				else put ("none");
				end if;
				new_line;
				
				section_entered := false;				-- clear section_entered flag
				scratch := to_unbounded_string("");		-- clear scratch


				-- EXTRACT USR CODE
				Set_Output(Standard_Output); put ("   -- extracting usercode ..."); new_line; Set_Output(ExtractOutputFile);
				put("  usercode_register           ");
				Reset(ExtractInputFile);

				-- convert user_code entry to a single long line
				search_usr_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if attribute usercode_register found
						if Is_Field(Line,"attribute",1) and Is_Field(Line,"usercode_register",2) then section_entered:=true; end if;
						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));
							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));
						
									if is_control(char_current) = false then -- skip all control charcters 
										case char_current is
											when ';' => exit search_usr_section; -- end of section found
											when '&' => null; --scratch := scratch & ' ';
											--when '"' => null; --scratch := scratch & ' ';
											when '"' => scratch := scratch & ' '; -- replace hyphen by space
											when ':' => scratch := scratch & ' ';
											when others => scratch := scratch & char_current; -- append other characters to scratch
										end case;
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_usr_section; -- search_usr_section

				--Set_Output(Standard_Output);
				--put (scratch); new_line;
				--Abort_Task(Current_Task);

				if section_entered then
					-- delete header of usrcode line, just put usrcode
					for field in 7..Get_Field_Count(scratch)
						loop
							put (Get_Field(scratch,field));
						end loop;
				else put("none");
				end if;
				new_line;

				section_entered := false;				-- clear section_entered flag
				scratch := to_unbounded_string("");		-- clear scratch



				-- EXTRACT BSR LENGTH
				Set_Output(Standard_Output); put ("   -- extracting boundary register length ..."); new_line; Set_Output(ExtractOutputFile);
				put("  boundary_register_length    ");
				Reset(ExtractInputFile);

				-- convert boundary_length entry to a single long line
				search_bsrl_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if attribute boundary_length found
						if Is_Field(Line,"attribute",1) and Is_Field(Line,"boundary_length",2) then section_entered:=true; end if;
						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));
							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));

									if is_control(char_current) = false then -- skip all control charcters 
										case char_current is
											when ';' => exit search_bsrl_section; -- end of section found
											when ':' => scratch := scratch & ' ';
											--when '"' => scratch := scratch & ' ';
											when others => scratch := scratch & char_current; -- append other characters to scratch
										end case;
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_bsrl_section; -- search_bsrl_section

				--Set_Output(Standard_Output);
				--put (scratch); new_line;
				--Abort_Task(Current_Task);

				-- delete header of bsrl line, just put bsr length
				put (Get_Field(scratch,7)); new_line;
				bsr_length := Natural'Value(Get_Field(scratch,7)); -- required for safebits later
				section_entered := false;				-- clear section_entered flag
				scratch := to_unbounded_string("");		-- clear scratch


				-- EXTRACT TRST
				new_line;
				Set_Output(Standard_Output); put ("   -- checking for optional TRST pin ..."); new_line; Set_Output(ExtractOutputFile);
				put("  trst_pin ");
				Reset(ExtractInputFile);

				-- convert trst entry to a single long line
				search_trst_section:
				while not End_Of_File 
					loop
						Line:=Get_Line;
						-- if attribute tap_scan_reset found
						if Is_Field(Line,"attribute",1) and Is_Field(Line,"tap_scan_reset",2) then section_entered:=true; end if;
						if section_entered = true then 

							-- process line character by character
							line_length	:= (Length(Line));
							char_pt := 0;
							while char_pt <= (line_length - 1)
								loop
									-- advance character pointer
									char_pt:=char_pt+1; 
									char_current:=(To_String(Line)(char_pt));

									if is_control(char_current) = false then -- skip all control charcters 
										case char_current is
											when ';' => exit search_trst_section; -- end of section found
											when ':' => scratch := scratch & ' ';
											--when '"' => scratch := scratch & ' ';
											when others => scratch := scratch & char_current; -- append other characters to scratch
										end case;
	 								end if;

								end loop;
						end if; -- if section entered

					end loop search_trst_section; -- search_bsrl_section

				--Set_Output(Standard_Output);
				--put (scratch); new_line;
				--Abort_Task(Current_Task);

				-- check trst for true/flase
				if section_entered then
					if Is_Field(scratch,"true",7) then put("available");
					else put("none");
					end if;
				else put("none");
				end if;
				new_line;

				--section_entered := false;				-- clear section_entered flag
				--scratch := to_unbounded_string("");		-- clear scratch
			

				Close(ExtractInputFile); Close(ExtractOutputFile);
				Set_Output(Previous_Output); Set_Input(Previous_Input);

				return bsr_length;

			end extract_misc;






		procedure extract_safebits
					(
					bsr_length	: Natural;
					input_file	: String;
					output_file	: String;
					device		: String
					) is

			Previous_Input	: File_Type renames Current_Input;
			Previous_Output	: File_Type renames Current_Output;
			ExtractInputFile 	: Ada.Text_IO.File_Type;
			ExtractOutputFile 	: Ada.Text_IO.File_Type;
			cell_number			: Natural := 0;
			cell_line			: unbounded_string;
			line_ct				: Natural := 0;
		
			--type bin_number is array (0 .. bsr_length-1) of character;
			type character_extended is 
				record
					value		: character;
					processed	: Boolean := false;
				end record;

			type bin_number is array (0 .. bsr_length-1) of character_extended;
			safebits	:	bin_number;

			begin
				-- create output_file
				Create( ExtractOutputFile, Name => output_file );
				Set_Output(ExtractOutputFile);	-- all puts go there
				--Set_Output(Standard_Output);
				-- open input_file
				Open( 
					File => ExtractInputFile,
					Mode => In_File,
					Name => input_file
					);
				Set_Input(ExtractInputFile); -- set data souce

				-- EXTRACT SAFEBITS
				new_line;
				Set_Output(Standard_Output); put ("   -- extracting safebits ..."); new_line; Set_Output(ExtractOutputFile);
				put("  SubSection safebits"); new_line;
				put("          -- MSB...LSB"); new_line;
				put("    safebits ");

				--put(bsr_length); new_line;
				line_ct := 0;
				while not End_Of_File
					loop
						cell_line := Get_Line;
						if Is_Field(cell_line,"EndSubSection",1) then exit; end if; -- quit if end of BSR reached
						line_ct := line_ct + 1;

						if line_ct > 2 then  -- skip header of BSR cell list
							cell_number := Natural'Value(Get_Field(cell_line,1));

							-- check if cell id is outside bsr length
							if cell_number > bsr_length-1 then
								Set_Output(Standard_Output);
								put("ERROR   : Device '" & device & "' boundary register cell" & Natural'Image(cell_number) & 
									" is outside the specified register length of" & Natural'Image(bsr_length) & " !"); new_line;
								put("          Verify that BSDL model and path to model file are correct !"); new_line;
								Abort_Task(Current_Task);
							end if;

							-- mark cell as processed if not processed yet
							if safebits(cell_number).processed = false then
								safebits(cell_number).processed := true;
							else -- if already processed, check if safe values differ
								if safebits(cell_number).value /= Get_Field(cell_line,5)(1) then
									Set_Output(Standard_Output);
									put("WARNING : Safe value mismatch in device '" & device & "' !"); new_line;
									put("          Cell" & Natural'Image(cell_number) & " has different safe values defined in the BSDL model !"); new_line;
									put("          The last occurence of " & Get_Field(cell_line,5)(1) & " will overwrite ALL former entries to " & safebits(cell_number).value & " !"); new_line;
									Set_Output(ExtractOutputFile);
								end if;
							end if;

							-- update safebit array
							safebits(cell_number).value := Get_Field(cell_line,5)(1);

						end if;
					end loop;

				--Set_Output(Standard_Output); put ("   -- debug 2 ..."); new_line; Set_Output(ExtractOutputFile);

				-- write safebits in reverse in output file
				-- abort if unprocessed cell found
				for cell_number in reverse 0 .. (bsr_length -1)
					loop
						if safebits(cell_number).processed then put (safebits(cell_number).value);
						else 
							Set_Output(Standard_Output);
							put("ERROR   : Device '" & device & "' boundary register cell" & Natural'Image(cell_number) & " not found !"); new_line;
							put("          Verify that BSDL model and path to model file are correct !"); new_line;
							Abort_Task(Current_Task);
						end if;
					end loop;
				new_line;

				put("    total   " & Natural'Image(bsr_length)); new_line;				
				put("  EndSubSection"); new_line;

				Close(ExtractInputFile); Close(ExtractOutputFile);		
				Set_Output(Previous_Output); Set_Input(Previous_Input);

			end extract_safebits;






		procedure format_models
					(
					m 				: members_sized;
					count_members	: Natural
					) is
			
			scratch			: Natural := 0;
			bsdl_file      	: Ada.Text_IO.File_Type;
			Previous_Input	: File_Type renames Current_Input;
			Previous_Output	: File_Type renames Current_Output;

			begin

				while scratch < count_members
					loop
						scratch := scratch + 1;

						Set_Output(Standard_Output);
						new_line;
						put ("-- processing device '" & m(scratch).device & "' at position" & Natural'Image(scratch) & " ..."); new_line;
						Set_Output(Previous_Output);

						-- open bsdl file to test if it is there (exception otherwise, see below)
						Open( 
							File => bsdl_file,
							Mode => In_File,
							Name => to_string(m(scratch).model)
							);
						Close(bsdl_file); -- close bsdl file
						remove_comments_from_file(to_string(m(scratch).model), "tmp/bsdl_nc_" & to_string(m(scratch).device) & ".tmp");
						convert_file_to_lower_case("tmp/bsdl_nc_" & to_string(m(scratch).device) & ".tmp",
													"tmp/bsdl_lc_" & to_string(m(scratch).device) & ".tmp");

						Set_Output(Standard_Output); put ("   -- extracting port_pin map ..."); new_line; Set_Output(Previous_Output);
						extract_port_pin_map("tmp/bsdl_lc_" & to_string(m(scratch).device) & ".tmp",
										"tmp/pac_" & to_string(m(scratch).device) & ".tmp",
										to_string(m(scratch).packge),
										to_string(m(scratch).device));

						Set_Output(Standard_Output); put ("   -- extracting opcodes ..."); new_line; Set_Output(Previous_Output);
						extract_opcodes("tmp/bsdl_lc_" & to_string(m(scratch).device) & ".tmp",
										"tmp/opc_" & to_string(m(scratch).device) & ".tmp");

						Set_Output(Standard_Output); put ("   -- extracting boundary register cells ..."); new_line; Set_Output(Previous_Output);
						extract_bsr("tmp/bsdl_lc_" & to_string(m(scratch).device) & ".tmp",
										"tmp/cells_" & to_string(m(scratch).device) & ".tmp");

						Set_Output(Standard_Output); put ("   -- extracting port_io_map ..."); new_line; Set_Output(Previous_Output);
						extract_port_io_map("tmp/bsdl_lc_" & to_string(m(scratch).device) & ".tmp",
										"tmp/port_" & to_string(m(scratch).device) & ".tmp");


						-- extract value, ir_length, ir_capture, trst
						Set_Output(Standard_Output); put ("   -- extracting miscellaneous information ..."); new_line; Set_Output(Previous_Output);
						extract_safebits( extract_misc("tmp/bsdl_lc_" & to_string(m(scratch).device) & ".tmp", 
												"tmp/misc_" & to_string(m(scratch).device) & ".tmp"), -- pass bsr_length
												"tmp/cells_" & to_string(m(scratch).device) & ".tmp", -- pass name of bsr file
												"tmp/safe_" & to_string(m(scratch).device) & ".tmp", -- pass name of safebits file
												to_string(m(scratch).device)); -- pass device name

				Set_Output(Standard_Output); put ("   -- assembling register section ..."); new_line; Set_Output(Previous_Output);

						put (" SubSection " & to_string(m(scratch).device)); new_line;
						append_file_open("tmp/misc_" & to_string(m(scratch).device) & ".tmp");
						--new_line;
						append_file_open("tmp/safe_" & to_string(m(scratch).device) & ".tmp");
						new_line;
						append_file_open("tmp/opc_" & to_string(m(scratch).device) & ".tmp");
						new_line;
						append_file_open("tmp/cells_" & to_string(m(scratch).device) & ".tmp");
						new_line;
						append_file_open("tmp/port_" & to_string(m(scratch).device) & ".tmp");
						new_line;
						append_file_open("tmp/pac_" & to_string(m(scratch).device) & ".tmp");
						new_line;
						put (" EndSubSection " & to_string(m(scratch).device)); new_line; new_line;
						put (" --------------------------------------"); new_line; new_line;

					end loop;

				exception
					when ADA.IO_EXCEPTIONS.NAME_ERROR => 
						Set_Output(Standard_Output);
						put ("ERROR : Device '" & m(scratch).device & "' at position" & Natural'Image(scratch) & ": BSDL model file not found !"); new_line;
						put ("        Please verify that path and BSDL file name are correct."); new_line;
						Abort_Task(Current_Task);

			end format_models;






		begin  -- examine_chain_members

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
						scratch := scratch + 1;
						m(scratch).position := scratch;
						m(scratch).device := to_unbounded_string(Get_Field(Line,1));
						m(scratch).packge := to_unbounded_string(to_lower(Get_Field(Line,2))); -- to_lower added in v033
						m(scratch).model  := to_unbounded_string(Get_Field(Line,3));

						-- check parameter count  (e.g. in case of missing parameters)
						if Get_Field_Count(Line) < 3 then
							Set_Output(Standard_Output);
							put ("ERROR : Missing parameter for device " & m(scratch).device & " at position" & Natural'Image(scratch) & " !"); new_line;
							put ("        A scan chain device is specified for example like this:"); new_line;
							put ("        IC301 pc44_package /home/user/models/BSDL/xc9536_pc44.bsd (option ...)"); new_line;
							Abort_Task(Current_Task);
					
						
						-- check if any option is given in field 4 for current device
						elsif Get_Field_Count(Line) > 3 then

							-- check for keyword "option"
							if Is_Field(Line,"option",4) then

								m(scratch).options := true;

								-- if options given for current device, create opt file
								Create( options, Name => Compose("tmp","options_" & Get_Field(Line,1),"tmp")); Close(options);
								Open( 
									File => options,
									Mode => Append_File,
									Name => Compose("tmp","options_" & Get_Field(Line,1),"tmp")
									);
								Set_Output(options); -- direct puts to opt file

								-- CS: read further options one by one in options file
								if Is_Field(Line,"remove_pin_prefix",5) then
									put ("option " & Get_Field(Line,5) & " " & Get_Field(Line,6)); new_line;
									--Set_Output(Standard_Output);
									--put ("
								end if;

								Set_Output(Previous_Output); -- redirect puts
								Close(options);

							else
								Set_Output(Standard_Output);
								put ("ERROR : Missing keyword 'options' for device " & m(scratch).device & " at position" & Natural'Image(scratch) & " !"); new_line;
								put ("        Specify options example: 'option remove_pin_prefix pad_'"); new_line;
								Abort_Task(Current_Task);
			
							end if; -- check for keyword "option"
						
						end if; -- check if any option is given in field 4 for current device

					end if;
				end loop;
			Close(CountInputFile);
			Set_Input(Previous_Input);
			--return count_members;

			format_models(m,scratch);

		end examine_chain_members;





-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin


	new_line;
	put("BSDL importer version "& Version); new_line;

	data_base:=to_unbounded_string(Argument(1));
	put ("data base           : ");	put(data_base); new_line;




	--#make backup of given udb
	--Copy_File(to_string(data_base),compose("bak", to_string(data_base & "_nets")));
	
	-- recreate an empty tmp directory
	if exists ("tmp") then 
		Delete_Tree("tmp");
		Create_Directory("tmp");
	else Create_Directory("tmp");
	end if;

	-- backup scanpath_configuration as seed
	extract_section( (to_string(data_base)) ,"tmp/spc_seed.tmp","Section","EndSection","scanpath_configuration");
	Copy_File( "tmp/spc_seed.tmp", Compose("bak",to_string(data_base) & "_seed"));

	Create( OutputFile, Name => Compose("tmp",to_string(data_base) & "_work")); Close(OutputFile);

	Open( 
		File => udb_work,
		Mode => Append_File,
		Name => Compose("tmp",to_string(data_base) & "_work")
		);
	Set_Output(udb_work);


	-- append seed to udb_work
	append_file_open("tmp/spc_seed.tmp"); new_line; new_line;


	-- remove all comments from spc seed and write to tmp file
	remove_comments_from_file ("tmp/spc_seed.tmp","tmp/nc.tmp");


	-- read chain section
	--extract_section("tmp/nc.tmp","tmp/spc.tmp","Section","EndSection","scanpath_configuration");
	extract_section("tmp/nc.tmp","tmp/chain.tmp","SubSection","EndSubSection","chain");
	extract_netto_from_SubSection("tmp/chain.tmp" , "tmp/members.tmp");

	-- examine chain members 	#CS: How to handle multiple scan paths ?
	count_members := count_chain_members_a("tmp/members.tmp");

	Set_Output(Standard_Output);
	put ("chain members total :" & Natural'Image(count_members)); new_line;

	Set_Output(udb_work);
	put ("Section registers"); new_line;
	put ("---------------------------------------------------------------"); new_line;
	put ("-- created by BSDL importer version " & version); new_line;
	put ("-- date       : " ); put (Image(clock)); new_line; 
	put ("-- UTC_Offset : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; new_line;

	examine_chain_members("tmp/members.tmp",count_members);

	--new_line;
	put ("EndSection "); new_line; new_line;

	Close(udb_work);
	Copy_File( "tmp/" & to_string(data_base) & "_work" , to_string(data_base) );

	
end impbsdl;
