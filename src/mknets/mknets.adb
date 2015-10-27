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

with m1; use m1;

procedure mknets is

	Version			: String (1..3) := "043";
	data_base  		: Unbounded_string;
	data_base_new	: Ada.Text_IO.File_Type;
	opt_file 		: Unbounded_string;
	device   		: Unbounded_string;
	InputFile 		: Ada.Text_IO.File_Type;
	OptFile 		: Ada.Text_IO.File_Type;
	Netlist 		: Ada.Text_IO.File_Type;
	Netlist_copy	: Ada.Text_IO.File_Type;
	warnings		: Ada.Text_IO.File_Type;
	udb_bak			: Ada.Text_IO.File_Type;
	member_list		: Ada.Text_IO.File_Type;
	netlist_plus_cells : Ada.Text_IO.File_Type;

	expect_input_cells		: Ada.Text_IO.File_Type;
	expect_atg_cells		: Ada.Text_IO.File_Type;
	input_unknown_cells		: Ada.Text_IO.File_Type;
	locked_dh_dl_nr_cells	: Ada.Text_IO.File_Type;
	locked_eh_el_unknown_cells 	: Ada.Text_IO.File_Type;
	locked_dh_dl_output_cells	: Ada.Text_IO.File_Type;
	drive_atg_cells				: Ada.Text_IO.File_Type;
	drive_atg_cells_old			: Ada.Text_IO.File_Type;
	locked_pu_pd_output_cells	: Ada.Text_IO.File_Type;
	locked_pu_pd_cells			: Ada.Text_IO.File_Type;
	new_udb						: Ada.Text_IO.File_Type;
	skeleton					: Ada.Text_IO.File_Type;


	net_ct_na		: Natural:=0;
	net_ct_nr		: Natural:=0;
	net_ct_el		: Natural:=0;
	net_ct_eh		: Natural:=0;
	net_ct_dh		: Natural:=0;
	net_ct_dl		: Natural:=0;
	net_ct_pu		: Natural:=0;
	net_ct_pd		: Natural:=0;
	next_net_is_a_primary_net	: Boolean:=true;

	--line_pt				: Positive_Count; --Natural:=0;
	--Line_pt_primary_net : Positive_Count;
	--Line_pt_secondary_nets : Positive_Count;

	Previous_Output	: File_Type renames Current_Output;
	Processed_Nets_File	: Ada.Text_IO.File_Type;
	OutputFile 		: Ada.Text_IO.File_Type;

	secondary_net_found		: Boolean := false;
	net_already_processed 	: Boolean := false;
	net_section_entered		: Boolean :=false;
	sec_bs_net_has_inputs	: Boolean :=false;
	net_name_primary		: Unbounded_String;
	--net_class_primary		: String (1..2);
	--input_cell_number		: Natural;
	last_field				: Natural := 24; -- defines maxcount of fields in a line of udb

	key				: String (1..1) := "n";
	scratch			: Unbounded_string;
	Line			: Unbounded_string;
	Line_member		: Unbounded_string;
	Line_opt		: Unbounded_string;
	Line_netlist	: Unbounded_string;
	Line_skeleton	: Unbounded_string;
	Line_secondary_net	: Unbounded_String;
	count_members	: Natural := 0; -- holds number of chain members
	dummy			: Integer;

	prog_position	: String (1..4) := "----"; -- ins v043


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
			prog_position := "ICM1"; --ins v043

			-- open input_file
			Open( 
				File => IdentInputFile,
				Mode => In_File,
				Name => "tmp/members.tmp"
				);
			Set_Input(IdentInputFile); -- set data source
			Set_Output(Standard_Output);

			-- identify chain members
			prog_position := "ICM2"; --ins v043
			while not End_Of_File
				loop
					prog_position := "ICM4"; --ins v043
					Line:=Get_Line; --(IdentInputFile);
					if Get_Field_Count(Line) > 0 then 
						prog_position := "ICM5"; --ins v043
						ct := ct+1;
						--put (ct);
						m(ct).device	:= to_unbounded_string ( Get_Field(Line,1)); -- IC301

						prog_position := "ICM6"; --ins v043
						m(ct).value			:= to_unbounded_string ( query_member_register (Get_Field(Line,1),"value") ); -- XC9536 := (IC301,value)
						prog_position := "ICM7"; --ins v043
						m(ct).ir_length		:= Natural'Value ( query_member_register (Get_Field(Line,1),"instruction_register_length") );
						prog_position := "ICM8"; --ins v043
						m(ct).bsr_length	:= Natural'Value ( query_member_register (Get_Field(Line,1),"boundary_register_length") );
						prog_position := "ICM9"; --ins v043
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
			prog_position := "ICM3"; --ins v043
			Close(IdentInputFile);
			Set_Input(Previous_Input);
			return m;
		end;











	procedure process_skeleton -- NOTE: skeleton must be set as input file, netlist_plus_cells as output file
		(
		-- version 1.0 / MBL
		count_members	: Natural;
		m				: members
		) is

		subtype array_device_map_seized is array_device_map(1..count_members);
		device_pin_cell_map : array_device_map_seized;

		--Previous_Output	: File_Type renames Current_Output;
		--Previous_Input	: File_Type renames Current_Input;
		Line_skeleton		: unbounded_string;
		Line_port_pin_map	: unbounded_string;
		dev_pos				: Natural := 1;


		Line_port_pin_map_extended 	: port_pin_extended;
		Line_port_io_map_extended 	: port_io_extended;
		Line_cells_extended			: cells_extended;

		bsr_file	: unbounded_string; --Ada.Text_IO.File_Type;

		net_name 	: unbounded_string; -- ins V042
		device_ct	: natural := 0; -- ins V042

		procedure Get_port_pin_line
			(
			-- version 1.0 / MBL
			--device_pin_cell_map	: array_device_map;
			dev_pos		: Natural;
			pin			: string
			) is --return port_pin_extended is

			scratch						: Natural := 0;
			Line_port_pin_map			: unbounded_string;
			--Line_port_pin_map_extended 	: port_pin_extended;
			pin_found					: Boolean := false;
			pin_position				: Natural := 0;



			procedure find_cells
				(
				-- version 1.0 / MBL
				--cell_map	: array_device_map_seized;
				dev_pos	: Natural;
				port	: string
				) is -- return cells_extended is

				Line_cells_extended	: unbounded_string;
				Line_cells 			: unbounded_string;
				Line_cc 			: unbounded_string;
				line_last			: Natural := 0;
				port_found			: Boolean := false;

				begin
					Set_Input(device_pin_cell_map(dev_pos).boundary_register); -- set input file: boundary_register of chain member
					Reset(device_pin_cell_map(dev_pos).boundary_register);

					while not End_Of_File -- read from boundary_register
						loop
							Line_cells := Get_Line; line_last := line_last + 1; -- count lines of boundary_register
								if Is_Field(Line_cells,"SubSection",1) = false and Is_Field(Line_cells,"EndSubSection",1) = false then -- if it is a valid boundary_register line
									if Get_Field(Line_cells,3) = port then -- if port found
										port_found := true;
										--exit;
										--Line_cells_extended.match := true;
										Line_cells_extended := Line_cells_extended & " | " -- append separator
											& Get_Field(Line_cells,1) & " " & Get_Field(Line_cells,2) & " " -- append cell number and cell type
											& Get_Field(Line_cells,4) & " " & Get_Field(Line_cells,5); -- append direction and safe value
			
										if Get_Field_Count(Line_cells) = 8 then -- if disable spec given
											Line_cells_extended := Line_cells_extended & " " -- append space
											& Get_Field(Line_cells,6) & " " & Get_Field(Line_cells,7) & " " -- append cc cell number and disable value
											& Get_Field(Line_cells,8); -- append disable result

											-- check for non-merged control cell
											if Get_Field(Line_cells,6) /= Get_Field(Line_cells,1) then --if cc number differs from actual cell number
												-- the control cell associated is to be found
												-- re-search device_pin_cell_map(scratch).boundary_register : 
												Reset(device_pin_cell_map(dev_pos).boundary_register); -- reset line pointer
												while not End_Of_File
													loop
														Line_cc := Get_Line;
														if Is_Field(Line_cc,"SubSection",1) = false and Is_Field(Line_cc,"EndSubSection",1) = false then -- if it is a valid boundary_register line
															if Get_Field(Line_cc,1) = Get_Field(Line_cells,6) and Is_Field(Line_cc,"-",3) then -- if current cell number matchs cc number, and if port is "-"
																Line_cells_extended := Line_cells_extended & " | " -- append separator
																& Get_Field(Line_cc,1) & " " & Get_Field(Line_cc,2) & " " -- append cell number and cell type
																& Get_Field(Line_cc,4) & " " & Get_Field(Line_cc,5); -- append direction and safe value
																exit; -- no search for further control cells required ; CS: there shouldn't be more !
															end if;
														end if;
													end loop;
												Reset(device_pin_cell_map(dev_pos).boundary_register); -- reset line pointer
												Set_Line(device_pin_cell_map(dev_pos).boundary_register,positive_count(line_last+1)); -- restore line pointer
											end if; -- check for non-merged control cell

										end if; -- if disable spec given
										
									end if; -- if port found
								end if;  -- if it is a valid boundary_register line
						end loop;

						if port_found then
							put (Line_cells_extended);
						else
							Set_Output(Standard_Output);
							--put_line ("WARNING : Device " & m(dev_pos).device & " port '" & port & "' not found in boundary register !"); -- changed in V042
							put_line (warnings,"-- WARNING : Device " & m(dev_pos).device & " port '" & port & "' not found in boundary register !"); -- changed in V042
							--put ("          Check selected package or BSDL file of " & m(dev_pos).device & " !"); new_line;
							--Abort_Task (Current_Task);
							Set_Output(netlist_plus_cells);
						end if; -- if port found

				end find_cells;




			procedure Get_port_io_line
				(
				-- version 1.0 / MBL
				dev_pos		: Natural;
				pin_pos		: Natural;
				port		: string
				) is --return port_io_extended is

				scratch							: Natural := 0;
				Line_port_io_map				: unbounded_string;
				bs_pin_found					: Boolean := false;
				pin_vector						: unbounded_string;
				port_list						: unbounded_string;
				port_index						: unbounded_string;
				first_port						: Natural := 0;
				port_found						: Boolean := false;
				pin_found						: Boolean := false;
				--last_port						: Natural := 0;

				-- find port in port_io_map
				begin
					Set_Input(device_pin_cell_map(dev_pos).port_io_map); -- set input file: port_io_map of chain member
					Reset(device_pin_cell_map(dev_pos).port_io_map);

					--Line_port_io_map_extended.match := false;
					--Line_port_io_map_extended.bs_port := false;
					read_port_io_map:
					while not End_Of_File -- read from port_io_map
						loop
							Line_port_io_map:=Get_Line;
							if Is_Field(Line_port_io_map,"SubSection",1) = false 
								and Is_Field(Line_port_io_map,"EndSubSection",1) = false then -- if it is a valid port_pin line

									-- find port in header of Line_port_io_map
									port_list := split_line(Line_port_io_map,true); -- separate ports (in header) from line
									for scratch in 1..Get_Field_Count(port_list) -- search port in port_list
										loop
											if Is_Field(port_list,port,scratch) then -- if port found
												port_found := true;
 
												-- check if first field of trailer is "out", "in", "inout" or "buffer"
												if Is_Field(split_line(Line_port_io_map,false),"out",1) or
													Is_Field(split_line(Line_port_io_map,false),"in",1) or
													Is_Field(split_line(Line_port_io_map,false),"inout",1) or
													Is_Field(split_line(Line_port_io_map,false),"buffer",1) then
													bs_pin_found := true;  -- CS: tck, tms, tdo, tdi should be excluded (rarely equipped with bs cells)
													
													-- check if port is vectored
													if Get_Field_Count(split_line(Line_port_io_map,false)) = 4 then
														first_port := Natural'Value(Get_Field(split_line(Line_port_io_map,false),2));
														-- CS: check last port ?

														if Is_Field(split_line(Line_port_io_map,false),"to",3) then -- to-vector found
															port_index := to_unbounded_string ("(" & trim(Natural'Image(first_port + pin_pos -1), Ada.Strings.Left) & ")");
															put (port_index); --append port index to netlist_plus_cells
															find_cells(dev_pos,port & to_string(port_index)); -- pass dev_pos, port and port_index to find_cells
															exit read_port_io_map;
														 -- to-vector found

														 -- downto-vector found
														elsif Is_Field(split_line(Line_port_io_map,false),"downto",3) then 
															port_index := to_unbounded_string ("(" & trim(Natural'Image(first_port - pin_pos +1), Ada.Strings.Left) & ")");
															put (port_index); --append port index to netlist_plus_cells
															find_cells(dev_pos,port & to_string(port_index)); -- pass dev_pos, port and port_index to find_cells
															exit read_port_io_map;
														 -- downto-vector found
															
														else -- port type unknown
															Set_Output(Standard_Output);
															put ("ERROR : Device " & m(dev_pos).device & " port '" & port & "' syntax error in port_io_map !"); new_line;
															put ("        Check selected package or BSDL file of " & m(dev_pos).device & " !"); new_line;
															Abort_Task (Current_Task);
														end if;

													-- if non-vectored port
													elsif Get_Field_Count(split_line(Line_port_io_map,false)) = 1 then
														find_cells(dev_pos,port); -- pass dev_pos and port to find_cells
														exit read_port_io_map;
													end if; -- check if port is vectored

												end if; -- check if first field of trailer is "out", "in", "inout" or "buffer"
												
											end if; -- if port found
										end loop; -- search port in port_list
							end if;
						end loop read_port_io_map;

						if port_found = false then
							Set_Output(Standard_Output);
							put ("ERROR : Device " & m(dev_pos).device & " port '" & port & "' not found in port_io_map !"); new_line;
							put ("        Check selected package or BSDL file of " & m(dev_pos).device & " !"); new_line;
							Abort_Task (Current_Task);
						end if;

					--return Line_port_io_map_extended; -- if port not found, return with Line_port_io_map_extended.match := false;
				end Get_port_io_line;





			-- find port belonging to pin in port_pin_map
			begin
				Set_Input(device_pin_cell_map(dev_pos).port_pin_map); -- set input file: port_pin_map of chain member
				Reset(device_pin_cell_map(dev_pos).port_pin_map);
				--put (" dev_pos :" & Natural'Image(dev_pos));


				read_port_pin_map:
				while not End_Of_File -- read from port_pin_map
					loop
						Line_port_pin_map:=Get_Line;
						--put ("--") ; put (Line_port_pin_map); new_line; -- copy line as it is to netlist_plus_cells
						if Is_Field(Line_port_pin_map,"SubSection",1) = false 
							and Is_Field(Line_port_pin_map,"EndSubSection",1) = false then -- if it is a valid port_pin line
								--Line_port_pin_map_extended.field_ct := Get_Field_Count(Line_port_pin_map); -- calculate field count of current line
								if Get_Field_Count(Line_port_pin_map) = 2 then -- port is non-vectored

									if Is_Field(Line_port_pin_map,pin,2) then -- on pin match
										pin_found := true;
										pin_position := 1; -- not really nessecary 
										exit;  -- no further pin search required, cancel here
									end if;
								
								end if; -- port is non-vectored

								if Get_Field_Count(Line_port_pin_map) > 2 then -- port is vectored
									for scratch in 2..Get_Field_Count(Line_port_pin_map) -- search pin in vector
										loop
											if Is_Field(Line_port_pin_map,pin,scratch) then -- on vectored pin match
												pin_found := true;
												pin_position := scratch - 1;
												exit read_port_pin_map; -- no further pin search required, cancel here
											end if; -- on vectored pin match
										end loop; -- search pin in vector
								end if; -- port is vectored
						end if; -- if it is a valid port_pin line
					end loop read_port_pin_map;
				
				if pin_found then
					put (" " & Get_Field(Line_port_pin_map,1)); -- append port name to netlist_plus_cells --CS: append " " first ?
					Get_port_io_line (dev_pos,pin_position,Get_Field(Line_port_pin_map,1)); -- pass dev_pos, pin_position, port name
				else
					--Set_Output(Standard_Output); -- rm V041
					--put ("ERROR : Device " & m(dev_pos).device & " pin '" & pin & "' not found in port_pin_map !"); new_line; -- rm V041
					--put_line("WARNING : Device " & m(dev_pos).device & " pin '" & pin & "' not found in port_pin_map !" &
					--						 " Check selected package or BSDL file of " & m(dev_pos).device & " !"); -- changed in V042
					put_line(warnings,"-- WARNING : Device " & m(dev_pos).device & " pin '" & pin & "' not found in port_pin_map !" &
											 " Check selected package or BSDL file of " & m(dev_pos).device & " !"); -- changed in V042
					put(" unknown"); -- ins V041
					--Abort_Task (Current_Task); -- rm V041
				end if;


			end Get_port_pin_line;







		begin
			prog_position:="SK00"; -- ins v043

			-- open port_pin_map of all members
			for scratch in 1..count_members
				loop
					Open( 
						File => device_pin_cell_map(scratch).port_pin_map,
						Mode => In_File,
						Name => Compose("tmp",to_string(m(scratch).device) & "_port_pin_map.tmp")
						);
				end loop;

			-- open port_io_map of all members
			for scratch in 1..count_members
				loop
					Open( 
						File => device_pin_cell_map(scratch).port_io_map,
						Mode => In_File,
						Name => Compose("tmp",to_string(m(scratch).device) & "_port_io_map.tmp")
						);
				end loop;

			-- open boundary_register of all members
			for scratch in 1..count_members
				loop
					Open( 
						File => device_pin_cell_map(scratch).boundary_register,
						Mode => In_File,
						Name => Compose("tmp",to_string(m(scratch).device) & "_boundary_register.tmp")
						);
				end loop;

			Set_Output(netlist_plus_cells);

			while not End_Of_File -- read from skeleton
				loop
					Line_skeleton:=Get_Line;
					put (Line_skeleton); -- copy line as it is to netlist_plus_cells

					-- in V042 begin
					-- "one pin nets" must be identified and output as warning
					if get_field(line_skeleton,1) = "SubSection" then -- net section entered
						net_name := to_unbounded_string(get_field(line_skeleton,2)); -- save net name
						device_ct := 0; -- reset device counter
					end if; 
					-- ins V042 end

					if Get_Field_Count(Line_skeleton) = 5 then -- if it is a device line
						device_ct := device_ct + 1; -- count pins of net. ins in V042
						for dev_pos in 1..count_members  -- search matching chain member
							loop 
								if Get_Field(Line_skeleton,1) = m(dev_pos).device then  -- chain member found
									
									-- pass pin to Get_port_pin_line
									Get_port_pin_line ( dev_pos, to_lower(Get_Field(Line_skeleton,5)) ) ; -- changed in V041
								end if; -- chain member found
							end loop;
					end if;  -- if it is a device line
					
					-- ins V042 begin
					if get_field(line_skeleton,1) = "EndSubSection" then -- end of net found
						if device_ct < 2 then -- this will also detect a net with zero pins (if possible at all)
							--put_line(standard_output,"WARNING : Net " & net_name & " has only one pin !");
							put_line(warnings,"-- WARNING : Net " & net_name & " has only one pin !");
						end if;
					end if;
					-- ins V042 end

					new_line;
					Set_Input(skeleton);
				end loop;




			-- close port_pin_map of all members
			for scratch in 1..count_members
				loop
					Close(device_pin_cell_map(scratch).port_pin_map);
				end loop;

			-- close port_io_map of all members
			for scratch in 1..count_members
				loop
					Close(device_pin_cell_map(scratch).port_io_map);
				end loop;

			-- close boundary_register of all members
			for scratch in 1..count_members
				loop
					Close(device_pin_cell_map(scratch).boundary_register);
				end loop;



			return;
		end process_skeleton;



	function umask( mask : integer ) return integer;
		pragma import( c, umask );


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin


	new_line;
	put("net maker version "& Version); new_line;

	data_base:=to_unbounded_string(Argument(1));
	put ("data base           : ");	put(data_base); new_line;

	prog_position := "INI0"; --ins v043

	dummy := umask ( 003 );
	prog_position := "INI1"; --ins v043
	--raise constraint_error;


	--#make backup of given udb
	--Copy_File(to_string(data_base),compose("bak", to_string(data_base & "_nets")));
	
	-- recreate an empty tmp directory
	if exists ("tmp") then 
		Delete_Tree("tmp");
		Create_Directory("tmp");
	else Create_Directory("tmp");
	end if;
	prog_position := "INI2"; --ins v043

	-- ins V042 begin
	-- all warnings should go there
	Create( OutputFile, Name => "tmp/warnings.tmp"); Close(OutputFile);
	Open( 
		File => warnings,
		Mode => out_file,
		Name => "tmp/warnings.tmp"
		);
	new_line(warnings);
	prog_position := "WRN1"; --ins v043
	-- ins V042 end

	-- append scanpath_configuration and registers to backup udb
	prog_position := "APS0"; --ins v043
	extract_section( (to_string(data_base)) ,"tmp/spc.tmp","Section","EndSection","scanpath_configuration");
	extract_section( (to_string(data_base)) ,"tmp/registers.tmp","Section","EndSection","registers");

	prog_position := "BAK0"; --ins v043
	Create( OutputFile, Name => Compose("bak",to_string(data_base) & "_registers")); Close(OutputFile);
	Open( 
		File => udb_bak,
		Mode => Append_File,
		Name => Compose("bak",to_string(data_base) & "_registers")
		);
	Set_Output(udb_bak);

	prog_position := "APS1"; --ins v043
	append_file_open("tmp/spc.tmp"); new_line;
	append_file_open("tmp/registers.tmp"); new_line;
	Close(udb_bak);

	prog_position := "APS2"; --ins v043
	Set_Output(Standard_Output);
	remove_comments_from_file (Compose("bak",to_string(data_base) & "_registers"),"tmp/udb_no_comments.tmp");

	-- read spc section (former tmp/spc.tmp will be overwritten)
	prog_position := "APS3"; --ins v043
	extract_section("tmp/udb_no_comments.tmp","tmp/spc.tmp","Section","EndSection","scanpath_configuration");
	extract_section("tmp/spc.tmp","tmp/chain.tmp","SubSection","EndSubSection","chain");
	extract_netto_from_SubSection("tmp/chain.tmp" , "tmp/members.tmp");

	-- count chain members
	prog_position := "CCM1"; --ins v043
	count_members := (count_chain_members("tmp/members.tmp"));

	Open( 
		File => member_list,
		Mode => In_File,
		Name => "tmp/members.tmp"
		);
	Set_Input(member_list);

	prog_position := "CCM2"; --ins v043
	while not End_Of_File -- read from member_list
		loop
			Line_member:=Get_Line;
			if Get_Field_Count(Line_member) > 0 then 
				device := to_unbounded_string(Get_Field(Line_member,1)); 
				--put (to_string(device)); new_line;
				--Set_Input(udb);
				--Reset(udb);

				-- get general information of device being examined
				extract_section("tmp/udb_no_comments.tmp",Compose("tmp",to_string(device) & "_all.tmp"),"SubSection","EndSubSection",to_string(device),to_string(device));

				--  get port-i/o map of device being examined
				extract_section(Compose("tmp",to_string(device) & "_all.tmp"),Compose("tmp",to_string(device) & "_port_io_map.tmp"),"SubSection","EndSubSection","port_io_map");

				--  get boundary register of device being examined
				extract_section(Compose("tmp",to_string(device) & "_all.tmp"),Compose("tmp",to_string(device) & "_boundary_register.tmp"),"SubSection","EndSubSection","boundary_register");

				--  get port-pin-map of device being examined
				extract_section(Compose("tmp",to_string(device) & "_all.tmp"),Compose("tmp",to_string(device) & "_port_pin_map.tmp"),"SubSection","EndSubSection","port_pin_map");


			end if;
		end loop; -- read from member_list

	put ("chain members total : " & Natural'Image(count_members)); new_line;


	-- read netlist from skeleton
	prog_position := "NSK0"; --ins v043
	extract_section("skeleton.txt","tmp/netlist_skeleton.tmp","Section","EndSection","netlist_skeleton");

	Open( 
		File => skeleton,
		Mode => In_File,
		Name => "tmp/netlist_skeleton.tmp"
		);
	Set_Input(skeleton);
	Close(member_list);

	prog_position := "NSK1"; --ins v043
	Create( OutputFile, Name => "tmp/netlist_plus_cells.tmp"); Close(OutputFile);
	Open( 
		File => netlist_plus_cells,
		Mode => Out_File,
		Name => "tmp/netlist_plus_cells.tmp"
		);
	Set_Output(netlist_plus_cells);

	-- NOTE: skeleton must be set as input file, netlist_plus_cells as output file
	prog_position := "NSK2"; --ins v043
	process_skeleton(count_members,identify_chain_members(count_members)); 
	new_line(warnings); -- ins V042
	close(warnings); -- ins V042

-------

	-- overwrite current udb with bak/${udb}_registers to remove old netlist section from current udb
	prog_position := "NSK3"; --ins v043
	Copy_File( Compose("bak",to_string(data_base) & "_registers"), to_string(data_base));

	-- append formated tmp/netlist_plus_cells.tmp to udb
	Open( 
		File => data_base_new,
		Mode => Append_File,
		Name => to_string(data_base)
		);
	Set_Output(data_base_new);
	Close(netlist_plus_cells);
	--append_file_open("tmp/netlist_plus_cells.tmp");

	new_line;

	put ("Section netlist"); new_line;
	put ("--------------------------------------------"); new_line;
	put ("-- created by netmaker version " & version); new_line;
	put ("-- date       : " ); put (Image(clock)); new_line; 
	put ("-- UTC_Offset : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; new_line;

	append_file_open("tmp/warnings.tmp"); -- ins V042

	Open( 
		File => netlist_plus_cells,
		Mode => In_File,
		Name => "tmp/netlist_plus_cells.tmp"
		);
	Set_Input(netlist_plus_cells);

	while not End_Of_File
		loop

			Line_netlist := Get_Line;
				if Is_Field(Line_netlist,"SubSection",1) or Is_Field(Line_netlist,"EndSubSection",1) then 
				--		[ "${line[0]}" = "SubSection" ] && echo ' '${line[*]} >> $udb
				--		[ "${line[0]}" = "EndSubSection" ] && echo ' '${line[*]} >> $udb
					put (Line_netlist); new_line; 

				elsif Is_Field(Line_netlist,"EndSection",1) then 
				--		[ "${line[0]}" = "EndSection" ] && echo ${line[*]} >> $udb
					put (Line_netlist); new_line; 

				elsif Get_Field(Line_netlist,1) /= "Section" then 
				--		[ "${line[0]}" != "Section" ] && [ "${line[0]}" != "EndSection" ] && [ "${line[0]}" != "SubSection" ] && [ "${line[0]}" != "EndSubSection" ] && echo '  '${line[*]} >> $udb
					put (Line_netlist); new_line; 
				end if;

		end loop;

	Set_Input(Standard_Input);
	Set_Output(Standard_Output);
	close(netlist_plus_cells);
	close(data_base_new);

	new_line(standard_output);
	put_line(standard_output,"CAUTION : READ WARNINGS ISSUED IN DATA BASE FILE: " & data_base & " section netlist or in tmp/warnings.tmp");
	--Abort_Task (Current_Task);

	-- ins v043 begin
	exception
		when CONSTRAINT_ERROR =>
			put_line(standard_output,"prog position : " & prog_position);
			set_exit_status(1);
	-- ins v043 end
	
end mknets;
