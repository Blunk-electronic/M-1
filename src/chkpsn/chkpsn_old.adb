-- V 4.1
-- in procedure check_class bugfix: - it is sufficient if PD/PD prim. nets have at least one bidir or output3 pin, 
--									- disable value and result are don't care
--									- no need to check bidir or output3 pin for non-self-controlling output cell

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

procedure chkpsn is

	Version			: String (1..3) := "042";
	prog_position	: string := "---";
	data_base  		: Unbounded_string;
	opt_file 		: Unbounded_string;
	InputFile 		: Ada.Text_IO.File_Type;
	OptFile 		: Ada.Text_IO.File_Type;
	Netlist 		: Ada.Text_IO.File_Type;
	Netlist_copy	: Ada.Text_IO.File_Type;

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

	warnings 		: Ada.Text_IO.File_Type;

	net_ct_na		: Natural:=0;
	net_ct_nr		: Natural:=0;
	net_ct_el		: Natural:=0;
	net_ct_eh		: Natural:=0;
	net_ct_dh		: Natural:=0;
	net_ct_dl		: Natural:=0;
	net_ct_pu		: Natural:=0;
	net_ct_pd		: Natural:=0;
	next_net_is_a_primary_net	: Boolean:=true;

	line_pt				: Positive_Count; --Natural:=0;
	Line_pt_primary_net : Positive_Count;
	Line_pt_secondary_nets : Positive_Count;

	Previous_Output	: File_Type renames Current_Output;
	Processed_Nets_File	: Ada.Text_IO.File_Type;
	OutputFile 		: Ada.Text_IO.File_Type;

	secondary_net_found		: Boolean := false;
	net_already_processed 	: Boolean := false;
	net_section_entered		: Boolean :=false;
	sec_bs_net_has_inputs	: Boolean :=false;
	net_name_primary		: Unbounded_String;
	net_class_primary		: String (1..2);
	input_cell_number		: Natural;
	last_field				: Natural := 24; -- defines maxcount of fields in a line of udb

	key				: String (1..1) := "n";
	scratch			: Unbounded_string;
	Line			: Unbounded_string;
	Line_opt		: Unbounded_string;
	Line_netlist	: Unbounded_string;
	Line_secondary_net	: Unbounded_String;
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





	procedure check_class 
		(
		net_name_primary	: String;
		net_class_primary	: String;
		Line_pt_primary_net	: Positive_Count;
		secondary_net_found	: Boolean;
		Line_pt_secondary_nets : Positive_Count
		) is

		Line_netlist				: unbounded_string;
		primary_net_has_inputs 		: Boolean := false;
		secondary_nets_have_inputs	: Boolean := false;
		primary_net_has_a_single_input 	: Boolean := false;
		primary_net_has_a_single_output	: Boolean := false;
		ct_bspins	: Natural := 0;

		--net_ct_nr 	: Natural := 0;	-- count NR nets
		--net_ct_dh 	: Natural := 0;	-- count DH nets
		--net_ct_dl 	: Natural := 0;	-- count DL nets
		--net_ct_pu 	: Natural := 0;	-- count PU nets
		--net_ct_pd 	: Natural := 0;	-- count PD nets
		--net_ct_na 	: Natural := 0;	-- count NA nets

		primary_net_has_output2 : Boolean := false;
		primary_net_has_output3	: Boolean := false;
		primary_net_output2_ct	: Natural := 0;
		primary_net_has_weak0  	: Boolean := false;
		primary_net_has_weak1  	: Boolean := false;


		begin
			--new_line; put ("primary net : "); put (net_name_primary); new_line;
			--put ("class       : "); put (net_class_primary); new_line;
			--put ("line        : "); put (Natural(Line_pt_primary_net-1)); new_line;
			--if secondary_net_found then 
			--	put ("secondary nets from line : "); put (Natural(Line_pt_secondary_nets-1)); new_line; 
			--end if;

			Set_Input(netlist_copy); -- set data source netlist_copy


			-- HARD RULE 1 : a class NA, EL, EH, PU or PD primary net must NOT have output2 pins without disable spec

			if net_class_primary = "NA" or net_class_primary = "EL" or  net_class_primary = "EH" or
				net_class_primary = "PU" or  net_class_primary = "PD" then

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);
				--end_of_primary_net := false;

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
							--put (Line_net); new_line;

							-- check if there is an output2 without disable specification
							for scratch in 6..last_field -- test fields with id greater 5
								loop
									if Is_Field(Line_netlist,"output2",scratch) then
										-- if no disanble spec given, two fields to the rigth a "|" or line end is expected
										if Is_Field(Line_netlist,"|",scratch + 2) or Get_Field_Count(Line_netlist) = scratch + 1 then
											new_line;
											put ("ERROR ! Net " & net_name_primary & " has an Output2 pin without disable specification."); new_line;
											put ("        Net " & net_name_primary & " may not become member of class " & net_class_primary); new_line;
											new_line;
											put ("Affected line" & Integer'Image(Natural(Line_pt_primary_net-1)) & " of data base '" & to_string(data_base) & "' reads: "); new_line; new_line;
											put (Line_netlist); new_line; new_line;
											put ("Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design !"); new_line;
											Abort_Task (Current_Task); -- CS: not safe
										end if;
									end if; -- if field is "output2"
								end loop; -- test fields with Id greater 5
						end if; -- reading valid line from netlist_copy

						--if Get_Field_Count(Line_netlist) = 1 then end_of_primary_net := true; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					end loop;
			end if; -- if class NA,EL,EH,PD or PD


			-- SOFT RULE 1 : a class NA primary net should have inputs (helpful for manually written seq files)
			if net_class_primary = "NA" then
				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);
				--primary_net_has_inputs := := false;

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
							-- check if there is an "input", "bidir", "clock", "observe_only" without disable specification
							for scratch in 6..last_field -- test fields with id greater 5
								loop
									if Is_Field(Line_netlist,"input",scratch) or Is_Field(Line_netlist,"bidir",scratch) or
										Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
																				
											Set_Output(input_unknown_cells); 
											put (" class " & net_class_primary & " primary_net " & net_name_primary &
															" device " & Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) &
															" input_cell " & Get_Field(Line_netlist,scratch-2)); new_line;
											Set_Output(Standard_Output);
										
											primary_net_has_inputs := true;
										end if; -- if field is "input", "bidir", "clock", "observe_only"
								end loop; -- test fields with Id greater 5
						end if; -- reading valid line from netlist_copy
					end loop; -- read primary net section
			end if; -- if class NA


			-- SOFT RULE 1.1: if a NA primary net does not have input pins, there should be secondary nets with input pins

		-- UNDER CONSTRUCTION ! IN SHELL SCRIPT A USELESS PART ?!
		--	Reset(netlist_copy); 
		--	Set_Line(netlist_copy,Line_pt_secondary_net);

		--	if net_class_primary = "NA" and primary_net_has_inputs = false and secondary_net_found then
		--		while not End_Of_File -- secondary net section ends with "EndSubSection secondary_nets_of /CPU_WR" -- CS: better check for "EndSubSection secondary_nets_of /CPU_WR" ?
		--			loop
		--				Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
		--				if Get_Field_Count(Line_netlist) = 3 then exit; end if; -- secondary net section ends with "EndSubSection secondary_nets_of /CPU_WR" -- CS: better check for "EndSubSection secondary_nets_of" ?
		--				if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
							-- check if there is an "input", "bidir", "clock", "observe_only" without disable specification
		--					for scratch in 6..last_field -- test fields with id greater 5
		--						loop
		--							if Is_Field(Line_netlist,"input",scratch) or Is_Field(Line_netlist,"bidir",scratch) or
		--								Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
																				
											
											--primary_net_has_inputs := true;
		--								end if; -- if field is "input", "bidir", "clock", "observe_only"
		--						end loop; -- test fields with Id greater 5
		--				end if; -- reading valid line from netlist_copy
		--			end loop; -- read primary net section
		--	end if; -- if class NA, no inputs found in prim net and secondary nets found

		
			-- SOFT RULE 2: a primary net in class other than "NA" should have at least one pin with cell type input,bidir,clock or observe_only
			if net_class_primary /= "NA" then

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);
				primary_net_has_inputs := false;

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
							-- check if there is an "input", "bidir", "clock", "observe_only" without disable specification
							for scratch in 6..last_field -- test fields with id greater 5
								loop
									if Is_Field(Line_netlist,"input",scratch) or Is_Field(Line_netlist,"bidir",scratch) or
										Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
											primary_net_has_inputs := true;

											if net_class_primary = "DH" or net_class_primary = "EH" then
												Set_Output(expect_input_cells);
												put (" class " & net_class_primary & " primary_net " & net_name_primary &
																" device " & Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) &
																" input_cell " & Get_Field(Line_netlist,scratch-2) &
																" expect_value 1"); new_line;
											end if;
											if net_class_primary = "DL" or net_class_primary = "EL" then
												Set_Output(expect_input_cells);
												put (" class " & net_class_primary & " primary_net " & net_name_primary &
																" device " & Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) &
																" input_cell " & Get_Field(Line_netlist,scratch-2) &
																" expect_value 0"); new_line;
											end if;
											if net_class_primary = "PU" or net_class_primary = "PD" or net_class_primary = "NR" then
												Set_Output(expect_atg_cells);
												put (" class " & net_class_primary & " primary_net " & net_name_primary &
																" device " & Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) &
																" input_cell " & Get_Field(Line_netlist,scratch-2)); new_line;
											end if;
										
										end if; -- if field is "input", "bidir", "clock", "observe_only"
								end loop; -- test fields with Id greater 5
						end if; -- reading valid line from netlist_copy
					end loop; -- read primary net section

				--Set_Output(Standard_Output); -- rm v042
				if primary_net_has_inputs = false and secondary_net_found = false then
					--put ("WARNING ! Primary net " & net_name_primary & " has no input pin to measure state !"); new_line; --rm v042
					put_line(warnings,"WARNING ! Primary net " & net_name_primary & " has no input pin to measure state !"); --ins v042

					-- HARD RULE 2.1: a single primary EL or EH net must have input pins 
					if net_class_primary = "EH" or net_class_primary = "EL" then 
						--put ("ERROR   ! Primary net " & net_name_primary & " may not become member of class " & net_class_primary); new_line; -- rm v042
						put_line(standard_output,"ERROR   ! Primary net " & net_name_primary & " may not become member of class " & net_class_primary); -- ins v042
						put_line(warnings,"ERROR   ! Primary net " & net_name_primary & " may not become member of class " & net_class_primary); -- ins v042
						Abort_Task (Current_Task); -- CS: not safe
					end if;
				end if; -- if no inputs found in primary net and no secondary nets found

				-- SOFT RULE 2.2: if primary net other than class NA does not have input pins, there should be secondary nets with input pins
				-- seach sec nets for inputs
				if primary_net_has_inputs = false and secondary_net_found = true then
					--Reset(netlist_copy); 
					Set_Line(netlist_copy,Line_pt_secondary_nets);

					while not End_Of_File -- secondary net section ends with "EndSubSection secondary_nets_of XYZ" -- CS: better check for "EndSubSection secondary_nets_of XYZ" ?
						loop
							Line_netlist:=Get_Line;
							--put (Line_netlist); new_line;
							if Get_Field_Count(Line_netlist) = 3 then exit; end if; -- secondary net section ends with "EndSubSection secondary_nets_of XYZ" -- CS: better check for "EndSubSection secondary_nets_of XYZ" ?
							if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
								-- check if there is an "input", "bidir", "clock", "observe_only" without disable specification
								for scratch in 6..last_field -- test fields with id greater 5
									loop
										if Is_Field(Line_netlist,"input",scratch) or Is_Field(Line_netlist,"bidir",scratch) or
											Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
												secondary_nets_have_inputs := true;
										end if;
									end loop; -- test fields with id greater 5
							end if;
						end loop; -- read secondary nets section

					if secondary_nets_have_inputs = false then
						--put ("WARNING ! Neither class " & net_class_primary & " primary net " & net_name_primary & " nor any of its secondary nets have input pins to measure state ! (SOFT RULE 2.2)"); new_line; -- rm v042
						put_line(warnings,"WARNING ! Neither class " & net_class_primary & " primary net " & net_name_primary & " nor any of its secondary nets have input pins to measure state ! (SOFT RULE 2.2)"); -- ins v042

						--HARD RULE 2.2.1 : secondary nets of class EL or EH must have input pins 
						if net_class_primary = "EH" or net_class_primary = "EL" then 
							--put ("ERROR !   Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " !"); new_line; -- rm v042
							put_line(standard_output,"ERROR !   Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " !"); -- ins v042
							put_line(warnings,"ERROR !   Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " !"); -- ins v042
							Abort_Task (Current_Task); -- CS: not safebits	
						end if;

					end if;

				end if; -- search sec nets for inputs

			end if; -- if class other than NA



			-- SOFT RULE 3: (lonely pin rule)
			-- if the primary net in class DH,DL,NR, having only one bs-pin with output and input cell combined
			-- AND if a secondary net does not have inputs
			-- THEN the (lonley) pin in the primary net can not be tested for opens

			if net_class_primary = "DH" or net_class_primary = "DL" or net_class_primary = "NR" then
				primary_net_has_a_single_input := false;
				primary_net_has_a_single_output := false;
				ct_bspins := 0;

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
							ct_bspins := ct_bspins + 1; -- count bs-pins
							
							for scratch in 6..last_field -- test fields with id greater 5
								loop

									-- check if there is an "input", "clock" or "observe_only"
									if Is_Field(Line_netlist,"input",scratch) or
										Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
											primary_net_has_a_single_input := true;
									end if; -- if field is "input", "clock", "observe_only"

									-- check if there is a "bidir", "output2" or "output3" -- #CS: do a more detailed check regarding class & disable specs
									if Is_Field(Line_netlist," bidir",scratch) or Is_Field(Line_netlist,"output2",scratch) or
										Is_Field(Line_netlist,"output3",scratch) then
											primary_net_has_a_single_output := true;
									end if; -- if field is "bidir", "output2" or "output3"

								end loop; -- test fields with Id greater 5
						end if; -- reading valid line from netlist_copy
					end loop; -- read primary net section

					-- check if primary net has only one output pin and if this is the only one bspin
					if primary_net_has_a_single_output and ct_bspins = 1 then
						-- check if primary net has no input pins
						-- SOFT RULE 3.1
						if primary_net_has_a_single_input = false and secondary_net_found = false then
							--put ("WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " can neither be tested for open nor shorts !"); new_line; -- rm v042
							--put ("          There is no input pin in this net. (SOFT RULE 3.2)"); new_line; -- rm v042
							put_line(warnings,"WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " can neither be tested for open nor shorts !"); -- ins v042
							put_line(warnings,"          There is no input pin in this net. (SOFT RULE 3.2)"); -- ins v042
						end if;
						-- check if primary net has only one input pin
						if primary_net_has_a_single_input = true and secondary_net_found = false then
							--put ("WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " can not be tested for open !"); new_line; -- rm v042
							--put ("          There is a single self monitoring driver pin in this net. (SOFT RULE 3.1)"); new_line; -- rm v042
							put_line(warnings,"WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " can not be tested for open !"); -- ins v042
							put_line(warnings,"          There is a single self monitoring driver pin in this net. (SOFT RULE 3.1)"); -- ins v042
						end if;

						-- in case primary net has no input, check if secondary nets have inputs
						if primary_net_has_a_single_input = false and secondary_net_found = true then
							secondary_nets_have_inputs := false;

							--Reset(netlist_copy); 
							Set_Line(netlist_copy,Line_pt_secondary_nets);
						search_secondary_nets_for_at_least_one_input:
							while not End_Of_File -- secondary net section ends with "EndSubSection secondary_nets_of XYZ" -- CS: better check for "EndSubSection secondary_nets_of XYZ" ?
								loop
									Line_netlist:=Get_Line;
									--put (Line_netlist); new_line;
									if Get_Field_Count(Line_netlist) = 3 then exit; end if; -- secondary net section ends with "EndSubSection secondary_nets_of XYZ" -- CS: better check for "EndSubSection secondary_nets_of XYZ" ?
									if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
										-- check if there is an "input", "bidir", "clock", "observe_only" without disable specification
										for scratch in 6..last_field -- test fields with id greater 5
											loop
												if Is_Field(Line_netlist,"input",scratch) or Is_Field(Line_netlist,"bidir",scratch) or
													Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
														secondary_nets_have_inputs := true;
														exit search_secondary_nets_for_at_least_one_input;
												end if;
											end loop; -- test fields with id greater 5
									end if;
								end loop search_secondary_nets_for_at_least_one_input; -- read secondary nets section

								if secondary_nets_have_inputs = false then
									--put ("WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " can not be tested for open !"); new_line; -- rm v042
									--put ("          There is no input pin in this primary net nor in any of its secondary nets. (SOFT RULE 3.3)"); new_line; -- rm v042
									put_line(warnings,"WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " can not be tested for open !"); -- ins v042
									put_line(warnings,"          There is no input pin in this primary net nor in any of its secondary nets. (SOFT RULE 3.3)"); -- ins v042
								end if;
								
						end if; -- in case primary net has no inputs, check if secondary nets have inputs
					end if;
			end if; -- if class DH, DL, or NR



			-- check specific primary net class

			if net_class_primary = "NR" then

				net_ct_nr := net_ct_nr + 1;	-- count NR nets
				primary_net_has_output2 := false;
				primary_net_has_output3	:= false;
				primary_net_output2_ct	:= 0;

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
							
							for scratch in 6..last_field -- test fields with id greater 5
								loop
									-- check if there is a "output2"
									if Is_Field(Line_netlist,"output2",scratch) then
										-- if no disanble spec given, two fields to the rigth a "|" or line end is expected
										if Is_Field(Line_netlist,"|",scratch + 2) or Get_Field_Count(Line_netlist) = scratch + 1 then
											primary_net_output2_ct := primary_net_output2_ct + 1;
											primary_net_has_output2 := true;
											-- SOFT RULE 4.1 : check for multiple output2 pins without disable spec
											if primary_net_output2_ct > 1 then
												--new_line; new_line;
												--put ("!!!!!!!!! POSSIBLE SERIOUS DESIGN ERROR DETECTED ????????"); new_line; new_line; -- rm v042
												--put ("WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " has multiple output2 pins without disable specification."); new_line; -- rm v042
												--put ("          Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design ! (SOFT RULE 4.1)"); new_line; -- rm v042
												--new_line; new_line; -- rm v042

												new_line(standard_output,2); -- ins v042
												put_line(standard_output,"!!!!!!!!! POSSIBLE SERIOUS DESIGN ERROR DETECTED ????????"); new_line(standard_output,2); -- ins v042
												put_line(standard_output,"WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " has multiple output2 pins without disable specification."); -- ins v042
												put_line(standard_output,"          Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design ! (SOFT RULE 4.1)"); -- ins v042
												new_line(standard_output,2); -- ins v042

												new_line(warnings,2); -- ins v042
												put_line(warnings,"!!!!!!!!! POSSIBLE SERIOUS DESIGN ERROR DETECTED ????????"); new_line(warnings,2); -- ins v042
												put_line(warnings,"WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " has multiple output2 pins without disable specification."); -- ins v042
												put_line(warnings,"          Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design ! (SOFT RULE 4.1)"); -- ins v042
												new_line(warnings,2); -- ins v042

											end if; -- if multiple output2 without disable spec
										end if; -- if no disable spec given
									end if; -- if field is "output2"

									-- check if there is a "output3" or "bidir"
									if Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
										-- test if cell is not self-controlling (output cell number differs from control cell number)
										if Get_Field(Line_netlist,scratch - 2) /= Get_Field(Line_netlist,scratch + 2) then
											primary_net_has_output3 := true;
										end if; -- if cell is self-controlling (output cell number differs from control cell number)
									end if; -- if field is "output3" or "bidir"

								end loop; -- test fields with Id greater 5
						end if; -- reading valid line from netlist_copy
					end loop; -- read primary net section

					if primary_net_has_output2 = false and primary_net_has_output3 = false then
						--put ("ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); new_line; -- rm v042
						--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 4.2)"); new_line; -- rm v042
						put_line(standard_output,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 4.2)"); -- ins v042

						put_line(warnings,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 4.2)"); -- ins v042

						Abort_Task (Current_Task); -- CS: not safe
					end if; -- if no sutiable output2 or output3 found

			end if; -- if class NR


			if net_class_primary = "DH" then

				net_ct_dh := net_ct_dh + 1;	-- count DH nets
				primary_net_has_output2 := false;
				primary_net_has_output3	:= false;
				--primary_net_has_weak0  	:= false; -- rm V4.1
				primary_net_output2_ct	:= 0;

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields

							for scratch in 6..last_field -- test fields with id greater 5
								loop
									-- check if there is a "output2" without disable spec
									if Is_Field(Line_netlist,"output2",scratch) then
										-- if no disanble spec given, two fields to the rigth a "|" or line end is expected
										if Is_Field(Line_netlist,"|",scratch + 2) or Get_Field_Count(Line_netlist) = scratch + 1 then
											primary_net_output2_ct := primary_net_output2_ct + 1;
											primary_net_has_output2 := true;
											-- SOFT RULE 5.1 : check for multiple output2 pins without disable spec
											if primary_net_output2_ct > 1 then

												--new_line; new_line; -- rm v042
												--put ("!!!!!!!!! POSSIBLE SERIOUS DESIGN ERROR DETECTED ????????"); new_line; new_line; -- rm v042
												--put ("WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " has multiple output2 pins without disable specification."); new_line; -- rm v042
												--put ("          Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design ! (SOFT RULE 5.1)"); new_line;  -- rm v042
												--new_line; new_line; -- rm v042

												new_line(standard_output,2); -- ins v042
												put_line(standard_output,"!!!!!!!!! POSSIBLE SERIOUS DESIGN ERROR DETECTED ????????"); new_line(standard_output,2); -- ins v042
												put_line(standard_output,"WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " has multiple output2 pins without disable specification."); -- ins v042
												put_line(standard_output,"          Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design ! (SOFT RULE 5.1)"); -- ins v042
												new_line(standard_output,2); -- ins v042

												new_line(warnings,2); -- ins v042
												put_line(warnings,"!!!!!!!!! POSSIBLE SERIOUS DESIGN ERROR DETECTED ????????"); new_line(warnings,2); -- ins v042
												put_line(warnings,"WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " has multiple output2 pins without disable specification."); -- ins v042
												put_line(warnings,"          Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design ! (SOFT RULE 5.1)"); -- ins v042
												new_line(warnings,2); -- ins v042

											end if; -- if multiple output2 without disable spec

										end if;
									end if; -- check if there is a "output2" without disable spec

									-- check if there is a "output3" or "bidir"
									if Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
										
										-- remove begin V4.1
										
--										-- test if cell is not self-controlling (output cell number differs from control cell number)										
-- 										-- and if disable result is z
-- 										if Get_Field(Line_netlist,scratch - 2) /= Get_Field(Line_netlist,scratch + 2) -- self control check
-- 											and Is_Field(Line_netlist,"z",scratch + 4) then	-- disable result check
-- 											primary_net_has_output3 := true;
-- 										end if; -- if cell is self-controlling and disable result is z

										-- remove end V4.1									
										
										-- ins begin V4.1
										primary_net_has_output3 := true;
										-- ins end V4.1									
									
									end if; -- if field is "output3" or "bidir"

									-- remove begin V4.1
									
									-- check if there is a "output2" or "output3" or "bidir"
-- 									if Is_Field(Line_netlist,"output2",scratch) or Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
-- 											-- check if disable value is 0 and disable result is weak0 or pull0 or z
-- 											if Is_Field(Line_netlist,"0",scratch + 3) and 
-- 												(
-- 												Is_Field(Line_netlist,"weak0",scratch + 4) or
-- 												Is_Field(Line_netlist,"pull0",scratch + 4) or
-- 												Is_Field(Line_netlist,"z",scratch + 4)
-- 												) then
-- 												primary_net_has_weak0 := true;
-- 											end if; -- check if disable value is 0 and disable result is weak0 or pull0 or z
-- 									end if; -- if field is "output2" or "output3" or "bidir"
									
									-- remove end V4.1
									
								end loop; -- test fields with Id greater 5

						end if; -- reading valid line from netlist_copy
					end loop; -- read primary net section

--					if primary_net_has_output2 = false and primary_net_has_output3 = false and primary_net_has_weak1 = false then -- rm V4.1
					if primary_net_has_output2 = false and primary_net_has_output3 = false then -- rm V4.1
						--put ("ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); new_line; -- rm v042
						--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 5.2)"); new_line; -- rm v042
						put_line(standard_output,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 5.2)"); -- ins v042
						put_line(warnings,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 5.2)"); -- ins v042

						Abort_Task (Current_Task); -- CS: not safe
					end if; -- if no sutiable output2 or output3 found


			end if; -- if class DH



			if net_class_primary = "DL" then

				net_ct_dl := net_ct_dl + 1;	-- count DL nets
				primary_net_has_output2 := false;
				primary_net_has_output3	:= false;
				--primary_net_has_weak1  	:= false; -- rm V4.1
				primary_net_output2_ct	:= 0;

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields

							for scratch in 6..last_field -- test fields with id greater 5
								loop
									-- check if there is a "output2" without disable spec
									if Is_Field(Line_netlist,"output2",scratch) then
										-- if no disanble spec given, two fields to the rigth a "|" or line end is expected
										if Is_Field(Line_netlist,"|",scratch + 2) or Get_Field_Count(Line_netlist) = scratch + 1 then
											primary_net_output2_ct := primary_net_output2_ct + 1;
											primary_net_has_output2 := true;
											-- SOFT RULE 6.1 : check for multiple output2 pins without disable spec
											if primary_net_output2_ct > 1 then
												--new_line; new_line; -- rm v042
												--put ("!!!!!!!!! POSSIBLE SERIOUS DESIGN ERROR DETECTED ????????"); new_line; new_line; -- rm v042
												--put ("WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " has multiple output2 pins without disable specification."); new_line; -- rm v042
												--put ("          Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design ! (SOFT RULE 6.1)"); new_line;  -- rm v042
												--new_line; new_line; -- rm v042

												new_line(standard_output,2); -- ins v042
												put_line(standard_output,"!!!!!!!!! POSSIBLE SERIOUS DESIGN ERROR DETECTED ????????"); new_line(standard_output,2); -- ins v042
												put_line(standard_output,"WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " has multiple output2 pins without disable specification."); -- ins v042
												put_line(standard_output,"          Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design ! (SOFT RULE 6.1)"); -- ins v042
												new_line(standard_output,2); -- ins v042

												new_line(warnings,2); -- ins v042
												put_line(warnings,"!!!!!!!!! POSSIBLE SERIOUS DESIGN ERROR DETECTED ????????"); new_line(warnings,2); -- ins v042
												put_line(warnings,"WARNING ! Class " & net_class_primary & " primary net " & net_name_primary & " has multiple output2 pins without disable specification."); -- ins v042
												put_line(warnings,"          Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design ! (SOFT RULE 6.1)"); -- ins v042
												new_line(warnings,2); -- ins v042

											end if; -- if multiple output2 without disable spec

										end if;
									end if; -- check if there is a "output2" without disable spec

									-- check if there is a "output3" or "bidir"
									if Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
									
										-- remove begin V4.1
										
										-- test if cell is not self-controlling (output cell number differs from control cell number)
										-- and if disable result is z
-- 										if Get_Field(Line_netlist,scratch - 2) /= Get_Field(Line_netlist,scratch + 2) -- self control check
-- 											and Is_Field(Line_netlist,"z",scratch + 4) then	-- disable result check
-- 											primary_net_has_output3 := true;
-- 										end if; -- if cell is self-controlling and disable result is z
										
										-- remove begin V4.1
										
										primary_net_has_output3 := true; -- ins V4.1
										
									end if; -- if field is "output3" or "bidir"

									-- remove V4.1 begin
									
-- 									-- check if there is a "output2" or "output3" or "bidir"
-- 									if Is_Field(Line_netlist,"output2",scratch) or Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
-- 											-- check if disable value is 1 and disable result is weak1 or pull1 or z
-- 											if Is_Field(Line_netlist,"1",scratch + 3) and 
-- 												(
-- 												Is_Field(Line_netlist,"weak1",scratch + 4) or
-- 												Is_Field(Line_netlist,"pull1",scratch + 4) or
-- 												Is_Field(Line_netlist,"z",scratch + 4)
-- 												) then
-- 												primary_net_has_weak1 := true;
-- 											end if; -- check if disable value is 1 and disable result is weak1 or pull1 or z
-- 									end if; -- if field is "output2" or "output3" or "bidir"

									-- remove V4.1 end
									
								end loop; -- test fields with Id greater 5

						end if; -- reading valid line from netlist_copy
					end loop; -- read primary net section

--					if primary_net_has_output2 = false and primary_net_has_output3 = false and primary_net_has_weak1 = false then -- rm V4.1
					if primary_net_has_output2 = false and primary_net_has_output3 = false then -- rm V4.1
						--put ("ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); new_line; -- rm v042
						--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 6.2)"); new_line; -- rm v042
						put_line(standard_output,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 6.2)"); -- ins v042
						put_line(warnings,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 6.2)"); -- ins v042

						Abort_Task (Current_Task); -- CS: not safe
					end if; -- if no sutiable output2 or output3 found

			end if; -- if class DL

	

			if net_class_primary = "PD" then

				net_ct_pd := net_ct_pd + 1;	-- count PD nets
				primary_net_has_output2 := false;
				primary_net_has_output3	:= false;
-- 				primary_net_has_weak1  	:= false;
--				primary_net_has_weak0  	:= false; -- rm V4.1
				primary_net_has_inputs	:= false;
				--secondary_net_found 	:
				--primary_net_output2_ct	:= 0;

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields

							for scratch in 6..last_field -- test fields with id greater 5
								loop

									-- check if there is a "output3" or "bidir"
									if Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
										
										-- remove V4.1 begin
																			
-- 										-- test if cell is not self-controlling (output cell number differs from control cell number)
-- 										-- and if disable result is z
-- 										if Get_Field(Line_netlist,scratch - 2) /= Get_Field(Line_netlist,scratch + 2) -- self control check
-- 											and Is_Field(Line_netlist,"z",scratch + 4) then	-- disable result check
-- 											primary_net_has_output3 := true;
-- 										end if; -- if cell is self-controlling and disable result is z
										
										-- remove V4.1 end
																			
										primary_net_has_output3 := true; -- ins V4.1
										
									end if; -- if field is "output3" or "bidir"

									-- remove V4.1 begin
									
-- 									-- check if there is a "output2" or "output3" or "bidir"
-- 									if Is_Field(Line_netlist,"output2",scratch) or Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
-- 											-- check if disable value is 1 and disable result is weak0 or pull0 or z
-- --											if Is_Field(Line_netlist,"1",scratch + 3) and 
-- 											if true and
-- 												(
-- -- 												Is_Field(Line_netlist,"weak1",scratch + 4) or
-- -- 												Is_Field(Line_netlist,"pull1",scratch + 4) or
--  												Is_Field(Line_netlist,"weak0",scratch + 4) or
--  												Is_Field(Line_netlist,"pull0",scratch + 4) or
-- 												Is_Field(Line_netlist,"z",scratch + 4)
-- 												) then
-- -- 												primary_net_has_weak1 := true;
--  												primary_net_has_weak0 := true;
-- 											end if; -- check if disable value is 1 and disable result is weak1 or pull1 or z
-- 									end if; -- if field is "output2" or "output3" or "bidir"

									-- remove V4.1 end
									
									--check if current cell is an input,bidir,clock or observe_only
									if Is_Field(Line_netlist,"input",scratch) or Is_Field(Line_netlist,"bidir",scratch) or Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
										primary_net_has_inputs := true;
									end if;

								end loop; -- test fields with Id greater 5

						end if; -- reading valid line from netlist_copy
					end loop; -- read primary net section

					-- HARD RULE 7.1 : if neither output3 nor output2 nor weak1/pull1 pins found in the primary net abort here
-- 					if primary_net_has_output3 = false and primary_net_has_weak1 = false then
-- 					if primary_net_has_output3 = false and primary_net_has_weak0 = false then -- rm V4.1
 					if primary_net_has_output3 = false then -- ins V4.1					
						--put ("ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); new_line; -- rm v042
						--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 7.1)"); new_line; -- rm v042
						put_line(standard_output,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 7.1)"); -- ins v042
						put_line(warnings,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 7.1)"); -- ins v042
						Abort_Task (Current_Task); -- CS: not safe
					end if; -- if no sutiable output2 or output3 found

					-- HARD RULe 7.2 : if primary net does not have inputs AND if there are no secondary nets abort here
					if primary_net_has_inputs = false and secondary_net_found = false then
						--put ("ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no input pins to measure state !"); new_line; -- rm v042
						--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 7.2)"); new_line; -- rm v042
						put_line(standard_output,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no input pins to measure state !"); -- ins v042
						put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 7.2)"); -- ins v042
						put_line(warnings,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no input pins to measure state !"); -- ins v042
						put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 7.2)"); -- ins v042
						Abort_Task (Current_Task); -- CS: not safe
					end if; -- if primary net does not have inputs AND if there are no secondary nets abort here

					-- if primary net does not have inputs AND if there are secondary nets THEN search in secondary nets for inputs
					if primary_net_has_inputs = false and secondary_net_found = true then
						secondary_nets_have_inputs := false;
						Set_Line(netlist_copy,Line_pt_secondary_nets);
						search_pd_secondary_nets_for_at_least_one_input:
							while not End_Of_File -- secondary net section ends with "EndSubSection secondary_nets_of XYZ" -- CS: better check for "EndSubSection secondary_nets_of XYZ" ?
								loop
									Line_netlist:=Get_Line;
									--put (Line_netlist); new_line;
									if Get_Field_Count(Line_netlist) = 3 then exit; end if; -- secondary net section ends with "EndSubSection secondary_nets_of XYZ" -- CS: better check for "EndSubSection secondary_nets_of XYZ" ?
									if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
										-- check if there is an "input", "bidir", "clock", "observe_only"
										for scratch in 6..last_field -- test fields with id greater 5
											loop
												if Is_Field(Line_netlist,"input",scratch) or Is_Field(Line_netlist,"bidir",scratch) or
													Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
														secondary_nets_have_inputs := true;
														exit search_pd_secondary_nets_for_at_least_one_input;
												end if;
											end loop; -- test fields with id greater 5
									end if;
								end loop search_pd_secondary_nets_for_at_least_one_input; -- read secondary nets section

						-- HARD RULE 7.3 : if secondary nets do not have inputs abort here
						if secondary_nets_have_inputs = false then
							--put ("ERROR !   Neither class " & net_class_primary & " primary net " & net_name_primary & " nor any of its secondary nets have input pins to measure state !"); new_line; -- rm v042
							--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 7.3)"); new_line; -- rm v042
							put_line(standard_output,"ERROR !   Neither class " & net_class_primary & " primary net " & net_name_primary & " nor any of its secondary nets have input pins to measure state !"); -- ins v042
							put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 7.3)"); -- ins v042
							put_line(warnings,"ERROR !   Neither class " & net_class_primary & " primary net " & net_name_primary & " nor any of its secondary nets have input pins to measure state !"); -- ins v042
							put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 7.3)"); -- ins v042
							Abort_Task (Current_Task); -- CS: not safe
						end if; -- if secondary nets do not have inputs
					end if; -- if primary net does not have inputs AND if there are secondary nets THEN search in secondary nets for inputs

			end if; -- if class PD





			if net_class_primary = "PU" then

				net_ct_pu := net_ct_pu + 1;	-- count PU nets
				primary_net_has_output2 := false;
				primary_net_has_output3	:= false;
-- 				primary_net_has_weak0  	:= false;
--				primary_net_has_weak1  	:= false; -- rm V4.1
				primary_net_has_inputs	:= false;
				--secondary_net_found 	:
				--primary_net_output2_ct	:= 0;

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields

							for scratch in 6..last_field -- test fields with id greater 5
								loop

									-- check if there is a "output3" or "bidir"
									if Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then

										-- remove V4.1 begin
										
-- 										-- test if cell is not self-controlling (output cell number differs from control cell number)
-- 										-- and if disable result is z
-- 										if Get_Field(Line_netlist,scratch - 2) /= Get_Field(Line_netlist,scratch + 2) -- self control check
-- 											and Is_Field(Line_netlist,"z",scratch + 4) then	-- disable result check
-- 											primary_net_has_output3 := true;
-- 										end if; -- if cell is self-controlling and disable result is z

										-- remove V4.1 end
										
										primary_net_has_output3 := true; -- ins V4.1
										
									end if; -- if field is "output3" or "bidir"

									-- remove V4.1 begin
									
									-- check if there is a "output2" or "output3" or "bidir"
-- 									if Is_Field(Line_netlist,"output2",scratch) or Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
-- 											-- check if disable value is 0 and disable result is weak0 or pull0 or z
-- -- 											if Is_Field(Line_netlist,"0",scratch + 3) and 
-- 											if true and
-- 												(
-- -- 												Is_Field(Line_netlist,"weak0",scratch + 4) or
-- -- 												Is_Field(Line_netlist,"pull0",scratch + 4) or
-- 												Is_Field(Line_netlist,"weak1",scratch + 4) or
-- 												Is_Field(Line_netlist,"pull1",scratch + 4) or
-- 												Is_Field(Line_netlist,"z",scratch + 4)
-- 												) then
-- -- 												primary_net_has_weak0 := true;
-- 												primary_net_has_weak1 := true;
-- 											end if; -- check if disable value is 0 and disable result is weak0 or pull0 or z
-- 									end if; -- if field is "output2" or "output3" or "bidir"

									-- remove V4.1 end

									--check if current cell is an input,bidir,clock or observe_only
									if Is_Field(Line_netlist,"input",scratch) or Is_Field(Line_netlist,"bidir",scratch) or Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
										primary_net_has_inputs := true;
									end if;

								end loop; -- test fields with Id greater 5

						end if; -- reading valid line from netlist_copy
					end loop; -- read primary net section

					-- HARD RULE 8.1 : if neither output3 nor output2 nor weak0/pull0 pins found in the primary net abort here
-- 					if primary_net_has_output3 = false and primary_net_has_weak0 = false then
-- 					if primary_net_has_output3 = false and primary_net_has_weak1 = false then -- rm V4.1
 					if primary_net_has_output3 = false then -- ins V4.1
						--put ("ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); new_line; -- rm v042
						--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 8.1)"); new_line; -- rm v042
						put_line(standard_output,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 8.1)"); -- ins v042
						put_line(warnings,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no suitable driver pin !"); -- ins v042
						put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 8.1)"); -- ins v042
						Abort_Task (Current_Task); -- CS: not safe
					end if; -- if no sutiable output2 or output3 found

					-- HARD RULe 8.2 : if primary net does not have inputs AND if there are no secondary nets abort here
					if primary_net_has_inputs = false and secondary_net_found = false then
						--put ("ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no input pins to measure state !"); new_line; -- rm v042
						--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 8.2)"); new_line; -- rm v042
						put_line(standard_output,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no input pins to measure state !"); -- ins v042
						put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 8.2)"); -- ins v042
						put_line(warnings,"ERROR !   Class " & net_class_primary & " primary net " & net_name_primary & " has no input pins to measure state !"); -- ins v042
						put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 8.2)"); -- ins v042

						Abort_Task (Current_Task); -- CS: not safe
					end if; -- if primary net does not have inputs AND if there are no secondary nets abort here

					-- if primary net does not have inputs AND if there are secondary nets THEN search in secondary nets for inputs
					if primary_net_has_inputs = false and secondary_net_found = true then
						secondary_nets_have_inputs := false;
						Set_Line(netlist_copy,Line_pt_secondary_nets);
						search_pu_secondary_nets_for_at_least_one_input:
							while not End_Of_File -- secondary net section ends with "EndSubSection secondary_nets_of XYZ" -- CS: better check for "EndSubSection secondary_nets_of XYZ" ?
								loop
									Line_netlist:=Get_Line;
									--put (Line_netlist); new_line;
									if Get_Field_Count(Line_netlist) = 3 then exit; end if; -- secondary net section ends with "EndSubSection secondary_nets_of XYZ" -- CS: better check for "EndSubSection secondary_nets_of XYZ" ?
									if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
										-- check if there is an "input", "bidir", "clock", "observe_only"
										for scratch in 6..last_field -- test fields with id greater 5
											loop
												if Is_Field(Line_netlist,"input",scratch) or Is_Field(Line_netlist,"bidir",scratch) or
													Is_Field(Line_netlist,"clock",scratch) or Is_Field(Line_netlist,"observe_only",scratch) then
														secondary_nets_have_inputs := true;
														exit search_pu_secondary_nets_for_at_least_one_input;
												end if;
											end loop; -- test fields with id greater 5
									end if;
								end loop search_pu_secondary_nets_for_at_least_one_input; -- read secondary nets section

						-- HARD RULE 8.3 : if secondary nets do not have inputs abort here
						if secondary_nets_have_inputs = false then
							--put ("ERROR !   Neither class " & net_class_primary & " primary net " & net_name_primary & " nor any of its secondary nets have input pins to measure state !"); new_line; -- rm v042
							--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 8.3)"); new_line; -- rm v042
							put_line(standard_output,"ERROR !   Neither class " & net_class_primary & " primary net " & net_name_primary & " nor any of its secondary nets have input pins to measure state !"); -- ins v042
							put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 8.3)"); -- ins v042
							put_line(warnings,"ERROR !   Neither class " & net_class_primary & " primary net " & net_name_primary & " nor any of its secondary nets have input pins to measure state !"); -- ins v042
							put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 8.3)"); -- ins v042
							Abort_Task (Current_Task); -- CS: not safe
						end if; -- if secondary nets do not have inputs
					end if; -- if primary net does not have inputs AND if there are secondary nets THEN search in secondary nets for inputs

			end if; -- if class PU

			-- HARD RULE 9.0 check if unsupported class found
			if net_class_primary /= "NA" and net_class_primary /= "NR" 
				and net_class_primary /= "PD" and net_class_primary /= "PU" 
				and net_class_primary /= "DH" and net_class_primary /= "DL" 
				and net_class_primary /= "EH" and net_class_primary /= "EL" then
				--put ("ERROR !   Net class " & net_class_primary & " not supported !"); new_line; -- rm v042
				--put ("          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 9.0)"); new_line; -- rm v042
				put_line(standard_output,"ERROR !   Net class " & net_class_primary & " not supported !"); -- ins v042
				put_line(standard_output,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 9.0)"); -- ins v042
				put_line(warnings,"ERROR !   Net class " & net_class_primary & " not supported !"); -- ins v042
				put_line(warnings,"          Primary net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 9.0)"); -- ins v042
				Abort_Task (Current_Task); -- CS: not safe
			end if; -- -- HARD RULE 9.0 check if unsupported class found




			-- identify primary net control cells if pin is output2, output3 or bidir and write to locked cell list of EH,EL and NA nets
			if net_class_primary = "EH" or net_class_primary = "EL" or net_class_primary = "NA" then  
				if net_class_primary = "EH" then net_ct_eh := net_ct_eh + 1; end if; -- count EH nets
				if net_class_primary = "EL" then net_ct_el := net_ct_el + 1; end if; -- count EL nets
				if net_class_primary = "NA" then net_ct_na := net_ct_na + 1; end if; -- count NA nets

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				Set_Output(locked_eh_el_unknown_cells);
				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						--put (Line_netlist); new_line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields

							for scratch in 6..last_field -- test fields with id greater 5
								loop

									-- check if there is a "output2" or "output3" or "bidir"
									if Is_Field(Line_netlist,"output2",scratch) or Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
										put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " & Get_Field(Line_netlist,1) &
										" pin " & Get_Field(Line_netlist,5) & " control_cell " & Get_Field(Line_netlist,scratch + 2) & " locked_to disable_value " &
										Get_Field(Line_netlist,scratch + 3)); new_line;
									end if;

								end loop; -- test fields with Id greater 5

						end if; -- reading valid line from netlist_copy
					end loop; -- read primary net section

				Set_Output(Standard_Output);	

			end if; -- identify control cell if pin is output2, output3 or bidir and write to locked cell list of EH,EL and NA nets



			Set_Input(netlist); -- switch back to data source netlist
		end check_class;



	procedure find_dh_dl_nr_driver
		(
		net_name_primary	: String;
		net_class_primary	: String;
		Line_pt_primary_net	: Positive_Count;
		secondary_net_found	: Boolean
		) is

		driver_found 		: Boolean := false;
		shared_cc_conflict	: Boolean := false;
		Line_cell_list		: unbounded_string;
		Line_netlist		: unbounded_string;
		ev					: String (1..1); -- enable value of control cell
		begin

			Set_Input(netlist_copy); -- set data source netlist_copy

			-- find drivers without disable spec in DH, DL, NR nets
			if net_class_primary = "DH" or net_class_primary = "DL" or  net_class_primary = "NR" then
				driver_found := false;

				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
							--put (Line_net); new_line;

							-- check if there is an output2 without disable specification
							for scratch in 6..last_field -- test fields with id greater 5
								loop
									if Is_Field(Line_netlist,"output2",scratch) then
										-- if no disanble spec given, two fields to the rigth a "|" or line end is expected
										if Is_Field(Line_netlist,"|",scratch + 2) or Get_Field_Count(Line_netlist) = scratch + 1 then
											driver_found := true;
											-- write drive value of output cell in locked output cell list
											-- IMPORTANT NOTE: ALL OUTPUT2 DRIVERS WITHOUT DISABLE SPEC WILL DRIVE THE SAME VALUE ONTO THE NET
											if net_class_primary = "DH" then
												Set_Output(locked_dh_dl_output_cells);
												put (" class " & net_class_primary & " primary net " & net_name_primary & " pin " & Get_Field(Line_netlist,5) & 
												" output_cell " & Get_Field(Line_netlist,scratch - 2) & " locked_to drive_value 1"); new_line;
											end if;
											if net_class_primary = "DL" then
												Set_Output(locked_dh_dl_output_cells);
												put (" class " & net_class_primary & " primary net " & net_name_primary & " pin " & Get_Field(Line_netlist,5) & 
												" output_cell " & Get_Field(Line_netlist,scratch - 2) & " locked_to drive_value 0"); new_line;
											end if;
											if net_class_primary = "NR" then
												Set_Output(drive_atg_cells);
												put (" class " & net_class_primary & " primary net " & net_name_primary & " pin " & Get_Field(Line_netlist,5) & 
												" output_cell " & Get_Field(Line_netlist,scratch - 2)); new_line;
											end if;	
										end if; -- if no disanble spec given
									end if; -- if field is "output2"
								end loop; -- test fields with Id greater 5
						end if; -- reading valid line from netlist_copy

					end loop;
			end if; -- if class DH, DL or NR


			-- if no driver found so far, find drivers with disable spec in DH,DL,NR nets
			if net_class_primary = "DH" or net_class_primary = "DL" or  net_class_primary = "NR" then
							
				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
							--put (Line_netlist); new_line;

							shared_cc_conflict := false;
							-- check if there is an output2, output2 or bidir with disable specification
							search_driver_with_disable_spec:
							for scratch in 6..last_field -- test fields with id greater 5
								loop
									-- identify control cell if pin is output2, output3 or bidir
									if Is_Field(Line_netlist,"output2",scratch) or Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
										-- if no output2 driver has been found (see above) and
										-- if disanble spec given (means two fields to the rigth there must not be a "|" and no end of line) -- (no disable spec -> no control cell)
										if driver_found = false and Is_Field(Line_netlist,"|",scratch + 2) = false and Get_Field_Count(Line_netlist) > scratch + 1 then -- disable spec found

											-- test for shared control cell conflict -- HARD RULE 10.0
											-- look up control cell in locked cell list of EH, EL or NA nets
											Set_Input(locked_eh_el_unknown_cells);
											Reset(locked_eh_el_unknown_cells);

											while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
												loop
													Line_cell_list:=Get_Line;
													if Get_Field_Count(Line_cell_list) > 2 then -- a valid line has more than 2 fields
														-- if already locked, means, if device of primary net = device of locked cell list AND
														-- if control cell number of pin = control cell number in locked cell list
														if Get_Field(Line_netlist,1) = Get_Field(Line_cell_list,6) and
															Get_Field(Line_netlist,scratch + 2) = Get_Field(Line_cell_list,10) then
																shared_cc_conflict := true;
																exit search_driver_with_disable_spec; -- don't search for more locked cells, read in next pin instead
														end if;
													end if; -- reading valid line from cell list
												end loop;

											Set_Input(netlist_copy);
										end if; -- if no output2 driver found and (output3 or bidir) with disanble spec found
				
										-- after searching locked cell list, and if no conflict found
										if driver_found = false then
											driver_found := true;
											-- negate disable value to obtain enable value ev of output cell
											if Is_Field(Line_netlist,"0",scratch + 3) then ev := "1"; end if;
											if Is_Field(Line_netlist,"1",scratch + 3) then ev := "0"; end if;
											Set_Output(locked_dh_dl_nr_cells);
											put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " & Get_Field(Line_netlist,1) &
												" pin " & Get_Field(Line_netlist,5) & " control_cell " & Get_Field(Line_netlist,scratch + 2) &
												" locked_to enable_value " & ev ); new_line;

											-- for class DH,DL nets applies:
											-- write drive value of output cell in locked output cell list
											if net_class_primary = "DH" then
												Set_Output(locked_dh_dl_output_cells);
												put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " & Get_Field(Line_netlist,1) &
												" pin " & Get_Field(Line_netlist,5) & " output_cell " & Get_Field(Line_netlist,scratch - 2) &
												" locked_to drive_value 1"); new_line;
											end if;
											if net_class_primary = "DL" then 
												Set_Output(locked_dh_dl_output_cells);
												put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " & Get_Field(Line_netlist,1) &
												" pin " & Get_Field(Line_netlist,5) & " output_cell " & Get_Field(Line_netlist,scratch - 2) &
												" locked_to drive_value 0"); new_line;
											end if;


											-- for class NR nets applies:
											-- write output cell in atg drive cell list
											if net_class_primary = "NR" then
												Set_Output(drive_atg_cells);
												put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " & Get_Field(Line_netlist,1) &
												" pin " & Get_Field(Line_netlist,5) & " output_cell " & Get_Field(Line_netlist,scratch - 2)); new_line;
											end if;

											exit; -- suitable driver found, no further driver search required

										end if; -- after searching locked cell list, and if no conflict found

										-- if suitable driver found then, write control cell of all remaining driver pins in locked cell list of DH,DL,? nets
										if driver_found and Is_Field(Line_netlist,"|",scratch + 2) = false and Get_Field_Count(Line_netlist) > scratch + 1 then
											Set_Output(locked_dh_dl_nr_cells);
											put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " & Get_Field(Line_netlist,1) &
												" pin " & Get_Field(Line_netlist,5) & " control_cell " & Get_Field(Line_netlist,scratch + 2) &
												" locked_to disable_value " & Get_Field(Line_netlist,scratch + 3)); new_line;	
										end if;

									end if; -- identify control cell if pin is output2, output3 or bidir
								end loop search_driver_with_disable_spec; -- test fields with Id greater 5
						end if; -- reading valid line from netlist_copy

					end loop;

				-- HARD RULE 10.0
				if shared_cc_conflict then
					Set_Output(Standard_Output);
					put ("ERROR !   Shared control cell conflict in class " & net_class_primary & " primary net " & net_name_primary & " device " &
						Get_Field(Line_cell_list,6) & " pin " & Get_Field(Line_netlist,5) & " !"); new_line;
					put ("          Control cell " & Get_Field(Line_cell_list,10) & " already locked by higher priority class " & Get_Field(Line_cell_list,2) &
						" net " & Get_Field(Line_cell_list,4) & " !"); new_line;
					put ("          No suitable driver pin in net " & net_name_primary & " found !"); new_line;
					put ("          Net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 10.0)"); new_line;

					-- ins v042 begin
					Set_Output(warnings);
					put ("ERROR !   Shared control cell conflict in class " & net_class_primary & " primary net " & net_name_primary & " device " &
						Get_Field(Line_cell_list,6) & " pin " & Get_Field(Line_netlist,5) & " !"); new_line;
					put ("          Control cell " & Get_Field(Line_cell_list,10) & " already locked by higher priority class " & Get_Field(Line_cell_list,2) &
						" net " & Get_Field(Line_cell_list,4) & " !"); new_line;
					put ("          No suitable driver pin in net " & net_name_primary & " found !"); new_line;
					put ("          Net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 10.0)"); new_line;
					-- ins v042 end

					Abort_Task (Current_Task); -- CS: not safe
				end if; -- shared_cc_conflict

			end if; -- if class DH, DL or NR


		end find_dh_dl_nr_driver;




	procedure find_pu_pd_driver
		(
		net_name_primary	: String;
		net_class_primary	: String;
		Line_pt_primary_net	: Positive_Count;
		secondary_net_found	: Boolean
		) is

		driver_found 		: Boolean := false;
		shared_cc_conflict	: Boolean := false;
		Line_cell_list		: unbounded_string;
		Line_netlist		: unbounded_string;
		--ev					: String (1..1); -- enable value of control cell
		begin

			Set_Input(netlist_copy); -- set data source netlist_copy

			-- find drivers without disable spec in PU or PD nets
			if net_class_primary = "PU" or net_class_primary = "PD" then
							
				Reset(netlist_copy); 
				Set_Line(netlist_copy,Line_pt_primary_net);

				while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
					loop
						Line_netlist:=Get_Line;
						if Get_Field_Count(Line_netlist) = 1 then exit; end if; -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
						if Get_Field_Count(Line_netlist) > 5 then -- a bs-pin has more than 5 fields
							--put (Line_netlist); new_line;

							shared_cc_conflict := false;
							-- check if there is an output2, output2 or bidir with disable specification
							search_pull_driver_with_disable_spec:
							for scratch in 6..last_field -- test fields with id greater 5
								loop
									-- identify control cell if pin is output2, output3 or bidir
									if Is_Field(Line_netlist,"output2",scratch) or Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
										-- if disanble spec given (means two fields to the rigth there must not be a "|" and no end of line) -- (no disable spec -> no control cell)
										if Is_Field(Line_netlist,"|",scratch + 2) = false and Get_Field_Count(Line_netlist) > scratch + 1 then -- disable spec found

											-- test for shared control cell conflict -- preparation for HARD RULE 10.1
											-- look up control cell in locked cell list of EH, EL or NA nets
											Set_Input(locked_eh_el_unknown_cells);
											Reset(locked_eh_el_unknown_cells);

											while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
												loop
													Line_cell_list:=Get_Line;
													if Get_Field_Count(Line_cell_list) > 2 then -- a valid line has more than 2 fields
														-- if already locked, means, if device of primary net = device of locked cell list AND
														-- if control cell number of pin = control cell number in locked cell list
														if Get_Field(Line_netlist,1) = Get_Field(Line_cell_list,6) and
															Get_Field(Line_netlist,scratch + 2) = Get_Field(Line_cell_list,10) then
																shared_cc_conflict := true;
																Set_Input(netlist_copy);
																exit search_pull_driver_with_disable_spec; -- don't search for more locked cells, read in next pin instead
														end if;
													end if; -- reading valid line from cell list
												end loop;

											-- no control cell conflict found so far

											-- look up control cell in locked cell list of DH, DL or NR nets
											Set_Input(locked_dh_dl_nr_cells);
											Reset(locked_dh_dl_nr_cells);

											while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
												loop
													Line_cell_list:=Get_Line;
													if Get_Field_Count(Line_cell_list) > 2 then -- a valid line has more than 2 fields
														-- if already locked, means, if device of primary net = device of locked cell list AND
														-- if control cell number of pin = control cell number in locked cell list
														if Get_Field(Line_netlist,1) = Get_Field(Line_cell_list,6) and
															Get_Field(Line_netlist,scratch + 2) = Get_Field(Line_cell_list,10) then
																shared_cc_conflict := true;

																-- if control cell already locked to enable value -- HARD RULE 10.2
																if Is_Field(Line_cell_list,"enable_value",12) then
																	Set_Output(Standard_Output);
																	put ("ERROR !   Shared control cell conflict in class " & net_class_primary & " primary net " & net_name_primary & " device " &
																		Get_Field(Line_cell_list,6) & " pin " & Get_Field(Line_netlist,5) & " !"); new_line;
																	put ("          Control cell " & Get_Field(Line_cell_list,10) & " already locked to enable value by higher priority class " & Get_Field(Line_cell_list,2) &
																		" net " & Get_Field(Line_cell_list,4) & " !"); new_line;
																	put ("          Net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 10.2)"); new_line;

																	-- ins v042 begin
																	Set_Output(warnings);
																	put ("ERROR !   Shared control cell conflict in class " & net_class_primary & " primary net " & net_name_primary & " device " &
																		Get_Field(Line_cell_list,6) & " pin " & Get_Field(Line_netlist,5) & " !"); new_line;
																	put ("          Control cell " & Get_Field(Line_cell_list,10) & " already locked to enable value by higher priority class " & Get_Field(Line_cell_list,2) &
																		" net " & Get_Field(Line_cell_list,4) & " !"); new_line;
																	put ("          Net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 10.2)"); new_line;
																	-- ins v042 end

																	Abort_Task (Current_Task); -- CS: not safe
																end if; -- if control cell already locked to enable value
																Set_Input(netlist_copy);
																exit search_pull_driver_with_disable_spec; -- don't search for more locked cells, read in next pin instead
														end if;
													end if; -- reading valid line from cell list
												end loop;

											-- no control cell conflict found so far

											-- look up control cell in cell list of ATG nets
											Set_Input(drive_atg_cells_old);
											Reset(drive_atg_cells_old);

											while not End_Of_File -- primary net section ends with "EndSubSection" -- CS: better check for "EndSubSection" ?
												loop
													Line_cell_list:=Get_Line;
													if Get_Field_Count(Line_cell_list) > 2 then -- a valid line has more than 2 fields
														-- if already locked, means, if device of primary net = device of locked cell list AND
														-- if control cell number of pin = control cell number in locked cell list
														if Get_Field(Line_netlist,1) = Get_Field(Line_cell_list,6) and
															Get_Field(Line_netlist,scratch + 2) = Get_Field(Line_cell_list,10) then
																shared_cc_conflict := true;
																Set_Output(Standard_Output);
																put ("ERROR !   Shared control cell conflict in class " & net_class_primary & " primary net " & net_name_primary & " device " &
																	Get_Field(Line_cell_list,6) & " pin " & Get_Field(Line_netlist,5) & " !"); new_line;
																put ("          Control cell " & Get_Field(Line_cell_list,10) & " already designated for ATG by higher priority class " & Get_Field(Line_cell_list,2) &
																	" net " & Get_Field(Line_cell_list,4) & " !"); new_line;
																put ("          Net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 10.3)"); new_line;

																-- ins v042 begin
																Set_Output(warnings);
																put ("ERROR !   Shared control cell conflict in class " & net_class_primary & " primary net " & net_name_primary & " device " &
																	Get_Field(Line_cell_list,6) & " pin " & Get_Field(Line_netlist,5) & " !"); new_line;
																put ("          Control cell " & Get_Field(Line_cell_list,10) & " already designated for ATG by higher priority class " & Get_Field(Line_cell_list,2) &
																	" net " & Get_Field(Line_cell_list,4) & " !"); new_line;
																put ("          Net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 10.3)"); new_line;
																-- ins v042 end

																Abort_Task (Current_Task); -- CS: not safe
														end if;
													end if; -- reading valid line from ATG cell list
												end loop;

											if driver_found = false then -- current driver qualifies as PD/PU driver
												driver_found := true;

												if net_class_primary = "PU" then -- write PU net driver

													-- when control cell no. != output cell no. , then output cell drive value of PU driver is static 0
													if Get_Field(Line_netlist,scratch + 2) /= Get_Field(Line_netlist,scratch - 2) then
														Set_Output(locked_pu_pd_output_cells);	
														put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " &
														Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) & " output_cell " &
														Get_Field(Line_netlist,scratch - 2) & " locked_to drive_value 0"); new_line;
													end if;

													-- depending on disable value the atg drive value of the control cell is to negate

													if Is_Field(Line_netlist,"0",scratch + 3) then
														Set_Output(drive_atg_cells);
														put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " &
														Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) & " control_cell " &
														Get_Field(Line_netlist,scratch + 2) & " inverted yes"); new_line;
													end if;

													if Is_Field(Line_netlist,"1",scratch + 3) then
														Set_Output(drive_atg_cells);
														put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " &
														Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) & " control_cell " &
														Get_Field(Line_netlist,scratch + 2) & " inverted no"); new_line;
													end if;

												end if; -- write PU net driver

												if net_class_primary = "PD" then -- write PD net driver

													-- when control cell no. != output cell no. , then output cell drive value of PU driver is static 1
													if Get_Field(Line_netlist,scratch + 2) /= Get_Field(Line_netlist,scratch - 2) then
														Set_Output(locked_pu_pd_output_cells);
														put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " &
														Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) & " output_cell " &
														Get_Field(Line_netlist,scratch - 2) & " locked_to drive_value 1"); new_line;
													end if;

													-- depending on disable value the atg drive value of the control cell is to negate

													if Is_Field(Line_netlist,"1",scratch + 3) then
														Set_Output(drive_atg_cells);
														put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " &
														Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) & " control_cell " &
														Get_Field(Line_netlist,scratch + 2) & " inverted yes"); new_line;
													end if;
													if Is_Field(Line_netlist,"0",scratch + 3) then
														Set_Output(drive_atg_cells);
														put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " &
														Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) & " control_cell " &
														Get_Field(Line_netlist,scratch + 2) & " inverted no"); new_line;
													end if;

												end if; -- write PD net driver
												Set_Input(netlist_copy);
												exit; --search_pull_driver_with_disable_spec; -- driver found and written in cell list

											end if; -- if no driver found

											if driver_found = true then
												--Set_Output(Standard_Output); put ("--"); new_line;
												-- write control cell of all remaining driver pins in locked cell list of PU and PD nets
												Set_Output(locked_pu_pd_cells);
												put (" class " & net_class_primary & " primary_net " & net_name_primary & " device " &
												Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) & " control_cell " &
												Get_Field(Line_netlist,scratch + 2) & " locked_to disable_value " & Get_Field(Line_netlist,scratch + 3)); new_line;
												Set_Input(netlist_copy);
												exit; 
											end if;

											Set_Input(netlist_copy);
										end if; -- if disable spec found
				

									end if; -- identify control cell if pin is output2, output3 or bidir
								end loop search_pull_driver_with_disable_spec; -- test fields with Id greater 5
						end if; -- reading valid line from netlist_copy

					end loop;

				-- HARD RULE 10.1
				if shared_cc_conflict and driver_found = false then -- if shared control cell conflict can not be resolved (means no suitable driver pin found)
					Set_Output(Standard_Output);
					put ("ERROR !   Shared control cell conflict in class " & net_class_primary & " primary net " & net_name_primary & " device " &
						Get_Field(Line_cell_list,6) & " pin " & Get_Field(Line_netlist,5) & " !"); new_line;
					put ("          Control cell " & Get_Field(Line_cell_list,10) & " already locked by higher priority class " & Get_Field(Line_cell_list,2) &
						" net " & Get_Field(Line_cell_list,4) & " !"); new_line;
					put ("          No suitable driver pin in net " & net_name_primary & " found !"); new_line;
					put ("          Net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 10.1)"); new_line;

					-- ins v042 begin
					Set_Output(warnings);
					put ("ERROR !   Shared control cell conflict in class " & net_class_primary & " primary net " & net_name_primary & " device " &
						Get_Field(Line_cell_list,6) & " pin " & Get_Field(Line_netlist,5) & " !"); new_line;
					put ("          Control cell " & Get_Field(Line_cell_list,10) & " already locked by higher priority class " & Get_Field(Line_cell_list,2) &
						" net " & Get_Field(Line_cell_list,4) & " !"); new_line;
					put ("          No suitable driver pin in net " & net_name_primary & " found !"); new_line;
					put ("          Net " & net_name_primary & " may not become member of class " & net_class_primary & " ! (HARD RULE 10.1)"); new_line;
					-- ins v042 end

					Abort_Task (Current_Task); -- CS: not safe
				end if; -- shared_cc_conflict

			end if; -- if class PU or PD


		end find_pu_pd_driver;


		function umask( mask : integer ) return integer;
		pragma import( c, umask );


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin


	new_line;
	put("primary/secondary/class builder "& Version); new_line;

	data_base:=to_unbounded_string(Argument(1));
	put ("data base      : ");	put(data_base); new_line;

	opt_file:=to_unbounded_string(Argument(2));
	put ("options file   : ");	put(opt_file); new_line;

	dummy := umask ( 003 );
	-- umask 003 ?

   --Spawn
   --(  Program_Name           => "/bin/ls",
   --   Args                   => Arguments,
   --   Output_File_Descriptor => Standout,
   --   Return_Code            => Result
   --);
   --for Index in Arguments'Range loop
   --   Free (Arguments (Index)); -- Free the argument list
   --end loop;

	--#make backup of given udb
	Copy_File(to_string(data_base),compose("bak", to_string(data_base & "_nets")));
	
	-- recreate an empty tmp directory
	clean_up_tmp_dir; -- ins V042

	--read netlist section from udb
	extract_section( (to_string(data_base)) ,"tmp/netlist.tmp","Section","EndSection","netlist");
	remove_comments_from_file ("tmp/netlist.tmp","tmp/netlist_no_comments.tmp");
	remove_comments_from_file ( (to_string(opt_file)),"tmp/opt.tmp");

	Create( OutputFile, Name => "tmp/netlist_psnc.tmp" );	
	Set_Output(Outputfile); -- set data sink
	put ("Section netlist"); new_line;
	put ("---------------------------------------------------------------"); new_line;
	put ("-- modified by primary/secondary/class builder version " & version); new_line;
	put ("-- date       : " ); put (Image(clock)); new_line; 
	put ("-- UTC_Offset : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; new_line;
	Close(OutputFile);

	--prepare cell lists
	Create( OutputFile, Name => "tmp/locked_eh_el_unknown_cells.tmp" );	Set_Output(Outputfile);
	put ("Section locked_control_cells_in_class_EH_EL_?_nets"); new_line; Close(OutputFile); -- CS change to "Section locked_control_cells_in_class_EH_EL_NA_nets"

	Create( OutputFile, Name => "tmp/locked_dh_dl_nr_cells.tmp" );	Set_Output(Outputfile);
	put ("Section locked_control_cells_in_class_DH_DL_NR_nets"); new_line; Close(OutputFile);

	Create( OutputFile, Name => "tmp/locked_pu_pd_cells.tmp" );	Set_Output(Outputfile);
	put ("Section locked_control_cells_in_class_PU_PD_nets"); new_line; Close(OutputFile);

	Create( OutputFile, Name => "tmp/locked_dh_dl_output_cells.tmp" );	Set_Output(Outputfile);
	put ("Section locked_output_cells_in_class_DH_DL_nets"); new_line; Close(OutputFile);

	Create( OutputFile, Name => "tmp/locked_pu_pd_output_cells.tmp" );	Set_Output(Outputfile);
	put ("Section locked_output_cells_in_class_PU_PD_nets"); new_line; Close(OutputFile);

	Create( OutputFile, Name => "tmp/expect_input_cells.tmp" );	Set_Output(Outputfile);
	put ("Section static_expect"); new_line; Close(OutputFile);

	Create( OutputFile, Name => "tmp/expect_atg_cells.tmp" );	Set_Output(Outputfile);
	put ("Section atg_expect"); new_line; Close(OutputFile);

	Create( OutputFile, Name => "tmp/drive_atg_cells.tmp" );	Set_Output(Outputfile);
	put ("Section atg_drive"); new_line; Close(OutputFile);

	Create( OutputFile, Name => "tmp/input_unknown_cells.tmp" );	Set_Output(Outputfile);
	put ("Section input_cells_in_class_?_nets"); new_line; Close(OutputFile);

	Set_Output(Standard_Output);
	put ("step 1: parsing primary and secondary nets seperately ..."); new_line; -- mod v042
	--examine options file
	--make sure secondary nets do not have output2 pins without disable specifications
	--warn user if secondary nets do not have input pins

	Create( OutputFile, Name => "msg/chkpsn.txt" );	Close(OutputFile); -- ins V042


	-- open input_file
	Open( 
		File => Netlist,
		Mode => In_File,
		Name => "tmp/netlist_no_comments.tmp"
		);

	-- open input_file
	Open( 
		File => OptFile,
		Mode => In_File,
		Name => "tmp/opt.tmp"
		);

	Create( Processed_Nets_File, Name => "tmp/opt_nets_processed.tmp" );	

	Open( 
		File => expect_input_cells,
		Mode => Append_File,
		Name => "tmp/expect_input_cells.tmp"
		);

	Open( 
		File => expect_atg_cells,
		Mode => Append_File,
		Name => "tmp/expect_atg_cells.tmp"
		);

	Open( 
		File => input_unknown_cells,
		Mode => Append_File,
		Name => "tmp/input_unknown_cells.tmp"
		);

	Open( 
		File => locked_dh_dl_nr_cells,
		Mode => Append_File,
		Name => "tmp/locked_dh_dl_nr_cells.tmp"
		);

	Open( 
		File => warnings,
		Mode => Append_File,
		Name => "msg/chkpsn.txt"
		);
	put_line(warnings,"WARNINGS ISSUED BY CHKPSN");
	put_line(warnings,"---------------------------------");  


	Open( 
		File => OutputFile,
		Mode => Append_File,
		Name => "tmp/netlist_psnc.tmp"
		);
	Set_Output(Outputfile); -- set data sink

	-- find primary net in options file	
	net_section_entered:=false;
	Set_Input(OptFile); -- set data source
	while not End_Of_File -- read from Optfile
		loop
			Line_opt:=Get_Line; -- read from Optfile
			if Get_Field_Count(Line_opt) > 0 then 

				--in the opt file: the second field in a line beginning with "Section" is a primary net name
				-- field 2 is primary net name, field 4 is primary net class
				if Is_Field(Line_opt,"Section",1) = true then 
					net_name_primary := to_unbounded_string(Get_Field(Line_opt,2));
					net_class_primary := Get_Field(Line_opt,4);
					new_line;

					-- now find this primary net also in netlist
					Set_Input(Netlist);
					Reset(Netlist);  -- reset Netlist for a (new) search
					while not End_Of_File
						loop
							Line_netlist:=Get_Line;
							if Get_Field_Count(Line_netlist) > 0 then 
								-- in the netlist: the second field in a line beginning with "SubSection" is a net name
								-- field 2 is primary net name
								if Is_Field(Line_netlist,"SubSection",1) then
									if Get_Field(Line_opt,2) = Get_Field(Line_netlist,2) then -- on optfile and nelist net name match
										--Set_Output(Standard_Output); put (Line_netlist); new_line; Set_Output(Outputfile);
										-- save processed net in opt_nets_processed.tmp (to be removed later from netlist)
										Set_Output(Processed_Nets_File); put(Get_Field(Line_netlist,2)); new_line; Set_Output(Outputfile);
										net_section_entered:=true;
									end if;
								end if;

								-- if section entered append primary net (incl. parts and pins) line by line to tmp/netlist_psnc.tmp
								if net_section_entered = true then
									if Is_Field(Line_netlist,"SubSection",1) then -- e.g.  SubSection LED2 class NR
										put(" " & Get_Field(Line_netlist,1));
										put(" " & Get_Field(Line_netlist,2));
										put(" " & Get_Field(Line_netlist,3));
										put(" " & Get_Field(Line_opt,4)); new_line; -- write new net class (from opt_file) instead of old netclass (from netlist)
									end if;

									if Is_Field(Line_netlist,"EndSubSection",1) then 
										put(Line_netlist); new_line;
									end if;

									if Is_Field(Line_netlist,"SubSection",1) = false and Is_Field(Line_netlist,"EndSubSection",1) = false then  
										put(Line_netlist); new_line;
									end if;

								end if;

								if Is_Field(Line_netlist,"EndSubSection",1) then net_section_entered:=false;
								end if;

							end if;
						end loop; -- netlist reading
					Set_Input(OptFile); -- set data source back to optfile

				end if;

				if Is_Field(Line_opt,"SubSection",1) then
					new_line; put (" SubSection secondary_nets_of "& net_name_primary); new_line;
				end if;


				-- process secondary nets
				
				-- in the opt file: a line beginning with "Net" is a secondary net
				if Is_Field(Line_opt,"Net",1) then
					-- CS: if field 2 contains "Option" copy inverted status (must be in field 3) in sec_inverted
					-- sec_inverted=''
					-- [ "${line_opt[2]}" = "inverted" ] && sec_inverted=${line_opt[2]} 

					-- now find this secondary net also in netlist
					Set_Input(Netlist); Reset(Netlist);
				secondary_net_search:
					while not End_Of_File
						loop
							Line_netlist:=Get_Line; -- read from netlist
								if Get_Field_Count(Line_netlist) > 0 then
									-- check if begin of secondary net found 
									if Is_Field(Line_netlist,"SubSection",1) then
										if Get_Field(Line_opt,2) = Get_Field(Line_netlist,2) then -- on optfile and nelist net name match
											net_section_entered:=true;
											sec_bs_net_has_inputs:=false; --so far no input cells have been found in this secondary net
											-- save processed net in opt_nets_processed.tmp (to be removed later from netlist)
											Set_Output(Processed_Nets_File); put(Get_Field(Line_netlist,2)); new_line; Set_Output(Outputfile);
											new_line;
										end if;
									end if;

									-- if secondary net section entered append secondary net (incl. parts and pins) line by line to tmp/netlist_psnc.tmp
									if net_section_entered = true then
										if Is_Field(Line_netlist,"SubSection",1) then -- e.g.  SubSection LED2 class NR
											put("   " & Get_Field(Line_netlist,1));
											put(" " & Get_Field(Line_netlist,2));
											put(" " & Get_Field(Line_netlist,3));
											put(" " & net_class_primary);
											-- CS: put $sec_inverted
											new_line; -- write inherited new net class of primary net (from opt_file) instead of old netclass (from netlist)
										end if;

										--if Is_Field(Line_netlist,"EndSubSection",1) then 
										--	if sec_bs_net_has_inputs = false then
										--		put ("     -- WARNING ! Secondary net " & Get_Field(Line_opt,2) & " has no input pin to measure state !"); new_line;
										--	end if;
										--	put("  " & Line_netlist); new_line;
										--	net_section_entered := false;
										--	--exit secondary_net_search; -- exit here, because secondary net found
										--end if;

										-- extract secondary net cells in cell lists
										if Is_Field(Line_netlist,"SubSection",1) = false and Is_Field(Line_netlist,"EndSubSection",1) = false then  
											-- if a pin entry has more than 5 fields, the secondary net is a bscan-net 
											-- and the pin needs more detailed investigation
											if Get_Field_Count(Line_netlist) > 5 then
												-- check if there is a cell with direction input, bidir, clock or observe_only
												for scratch in 6..last_field -- test fields with id greater 5
												loop
													if Is_Field(Line_netlist,"input",scratch) = true 
														or Is_Field(Line_netlist,"bidir",scratch) = true 
														or Is_Field(Line_netlist,"clock",scratch) = true
														or Is_Field(Line_netlist,"observe_only",scratch) = true
														then
															sec_bs_net_has_inputs := true;

															-- find input cell number
															input_cell_number:= Natural'Value(Get_Field(Line_netlist,scratch - 2));
															--put("    -- input cell found "); put (input_cell_number); new_line;
															
															-- elaborate primary net class to be inherited
															if net_class_primary = "DH" or net_class_primary = "EH" then 
																Set_Output(expect_input_cells); 
																put (" class " & net_class_primary & " secondary_net " & Get_Field(Line_opt,2) &
																	" device " & Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) &
																	" input_cell" & Integer'Image(input_cell_number));
																put (" expect_value 1 primary_net_is " & net_name_primary); new_line;
																Set_Output(Outputfile);
															end if;

															if net_class_primary = "DL" or net_class_primary = "EL" then
																Set_Output(expect_input_cells); 
																put (" class " & net_class_primary & " secondary_net " & Get_Field(Line_opt,2) &
																	" device " & Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) &
																	" input_cell" & Integer'Image(input_cell_number));
																put (" expect_value 0 primary_net_is " & net_name_primary); new_line;
																Set_Output(Outputfile);
															end if;

															if net_class_primary = "PU" or net_class_primary = "PD" or net_class_primary = "NR" then
																Set_Output(expect_atg_cells); 
																put (" class " & net_class_primary & " secondary_net " & Get_Field(Line_opt,2) &
																	" device " & Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) &
																	" input_cell" & Integer'Image(input_cell_number));
																put (" primary_net_is " & net_name_primary); new_line;
																Set_Output(Outputfile);
															end if;
															
															if net_class_primary = "NA" then
																Set_Output(input_unknown_cells); 
																put (" class " & net_class_primary & " secondary_net " & Get_Field(Line_opt,2) &
																	" device " & Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) &
																	" input_cell" & Integer'Image(input_cell_number));
																put (" primary_net_is " & net_name_primary); new_line;
																Set_Output(Outputfile);
															end if;

														--exit;
													end if;
	
												end loop;

												-- check if there is an output2 without disable specification
												for scratch in 6..last_field -- test fields with id greater 5
												loop
													if Is_Field(Line_netlist,"output2",scratch) then
														-- if no disanble spec given, two fields to the rigth a "|" or line end is expected
														if Is_Field(Line_netlist,"|",scratch + 2) or Get_Field_Count(Line_netlist) = scratch + 1 then
															--new_line;
															--put ("ERROR ! Net " & Get_Field(Line_opt,2) & " has Output2 pins without disable specification."); new_line;
															--put ("        Net " & Get_Field(Line_opt,2) & " may not become a secondary net !"); new_line;
															--new_line;
															--put ("Affected line of data base '" & to_string(data_base) & "' reads: "); new_line; new_line;
															--put (Line_netlist); new_line; new_line;
															--put ("Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design !"); new_line;
															Set_Output(Standard_Output);
															new_line;
															put ("ERROR ! Net " & Get_Field(Line_opt,2) & " has Output2 pins without disable specification."); new_line;
															put ("        Net " & Get_Field(Line_opt,2) & " may not become a secondary net ! (HARD RULE 0.1)"); new_line;
															new_line;
															put ("Affected line of data base '" & to_string(data_base) & "' reads: "); new_line; new_line;
															put (Line_netlist); new_line; new_line;
															put ("Check options file '" & to_string(opt_file) & "' , BSDL file or UUT design !"); new_line;
															Abort_Task (Current_Task); -- CS: not safe
														end if;
													end if;
												end loop;

												-- identify control cell if pin is output2 with disable spec, output3 or bidir
												for scratch in 6..last_field -- test fields with id greater 5
												loop
													if Is_Field(Line_netlist,"output2",scratch) or Is_Field(Line_netlist,"output3",scratch) or Is_Field(Line_netlist,"bidir",scratch) then
														Set_Output(locked_dh_dl_nr_cells); 
														put (" class " & net_class_primary & " secondary_net " & Get_Field(Line_opt,2) &
															" device " & Get_Field(Line_netlist,1) & " pin " & Get_Field(Line_netlist,5) &
															" control_cell " & Get_Field(Line_netlist,scratch+2));
														put (" locked_to disable_value " & Get_Field(Line_netlist,scratch+3)); new_line;
														Set_Output(Outputfile);
													end if;
												end loop;		

												--new_line;
											end if;
											put("   " & Line_netlist); new_line;

										end if;

										-- check if end of secondary net found
										if Is_Field(Line_netlist,"EndSubSection",1) then 
-- 											if sec_bs_net_has_inputs = false then -- rm V4.1
											-- output warning if no inputs found and if net is not in class NA
											if sec_bs_net_has_inputs = false and net_class_primary /= "NA" then -- ins V4.1
												--put ("     -- WARNING ! Secondary net " & Get_Field(Line_opt,2) & " has no input pin to measure state !"); new_line;
												--Set_Output(Standard_Output); -- rm v042
												--put ("WARNING ! Secondary net " & Get_Field(Line_opt,2) & " has no input pin to measure state !"); new_line; -- rm v042
												put_line(warnings,"WARNING ! Secondary net " & Get_Field(Line_opt,2) & " has no input pin to measure state !"); -- ins v042
												Set_Output(Outputfile);
											end if;
											put("  " & Line_netlist); new_line;
											net_section_entered := false;
										end if;

									end if;

								end if;

						end loop secondary_net_search; -- reading netlist
					Set_Input(OptFile); -- set data source back to optfile

				end if;
				
				if Is_Field(Line_opt,"EndSubSection",1) then
					new_line; put (" EndSubSection secondary_nets_of "& net_name_primary); new_line;
					put ("---------------------------------------------------------------------------------------------------------"); new_line; new_line;
				end if;
	
			end if; -- read non-empty line from Optfile
		end loop; -- optfile reading



	-- now append all remaining nets to netlist_psnc
	new_line; put(" -- non-optimized nets follow ..."); new_line;
	Reset(Processed_Nets_File, In_File); -- reset Processed_Nets_File as In_File
	Reset(netlist); -- reset netlist
	Set_Input(netlist);	-- set data source

	while not End_Of_File
		loop
			Line_netlist:=Get_Line; -- read from netlist
			if Get_Field_Count(Line_netlist) > 0 then
				-- field 2 is primary net name
				if Is_Field(Line_netlist,"SubSection",1) then -- start searching net in Processed_Nets_File
					Reset(Processed_Nets_File);
					Set_Input(Processed_Nets_File);	-- set data source
					net_already_processed := false;
					while not End_Of_File
						loop
							-- if netlist name matches Processed_Nets_File name -> net already processed -> cancel search
							if Get_Field(Get_Line,1) = Get_Field(Line_netlist,2) then net_already_processed := true; exit;
							--else Set_Output(Standard_Output); put (Line_netlist); new_line; Set_Output(Outputfile);
							end if;
						end loop;
					Set_Input(netlist);
				end if; -- reading headline of net in netlist
			end if; -- reading non-empty line from netlist

		-- append lines of netlist to netlist_psnc as long as net_already_processed is falsed (do not append line begining with "Section")
		if Is_Field(Line_netlist,"Section",1) = false and net_already_processed = false then put (Line_netlist); new_line; end if;
		end loop;


	Close(OutputFile);
	Close(Processed_Nets_File);
	Close(netlist);
	Close(Optfile);
	--Close(expect_input_cells);
	--Close(expect_atg_cells);
	--Close(input_unknown_cells);
	Close(locked_dh_dl_nr_cells);

	-- #### check primary+secondary nets as a whole ##########

	Set_Output(Standard_Output); put ("step 2: parsing compounds of primary and secondary nets ..."); new_line; -- mod v042
	--Set_Output(Outputfile);

	Open( 
		File => netlist,
		Mode => In_File,
		Name => "tmp/netlist_psnc.tmp"
		);
	Set_Input(netlist);
	Reset(netlist);

	
	Copy_File("tmp/netlist_psnc.tmp","tmp/netlist_psnc_copy.tmp");
	Open( 
		File => netlist_copy,
		Mode => In_File,
		Name => "tmp/netlist_psnc_copy.tmp"
		);

	Open( 
		File => locked_eh_el_unknown_cells,
		Mode => Append_File,
		Name => "tmp/locked_eh_el_unknown_cells.tmp"
		);


	while not End_Of_File
		loop
			Line_netlist:=Get_Line; -- read from netlist

			if Get_Field_Count(Line_netlist) > 0 then
				-- search for primary net
				if Is_Field(Line_netlist,"SubSection",1) then -- the first net in netlist is a primary net e.g. SubSection LED0 class NR
					Line_pt_primary_net := Ada.Text_IO.Line(netlist);	-- primary net found, save line number
					net_name_primary  := to_unbounded_string(Get_Field(Line_netlist,2));
					net_class_primary := Get_Field(Line_netlist,4);
					secondary_net_found := false;

					-- search for secondary nets of the current primary net
					Set_Input(netlist_copy); -- set input source to netlist_copy
					Reset(netlist_copy);
					Set_Line(netlist_copy,Line_pt_primary_net); -- set netlist_copy pointer to line below "SubSection LED0 class NR" 
					Line_pt := Line_pt_primary_net; -- backup netlist_copy pointer in case there are no secondary nets
					while not End_Of_File	
						loop
							Line_secondary_net:=Get_Line;
							if Get_Field_Count(Line_secondary_net) > 0 then
								
								if Is_Field(Line_secondary_net,"SubSection",1) and Is_Field(Line_secondary_net,"secondary_nets_of",2) 
									and Is_Field(Line_secondary_net,to_string(net_name_primary),3) then  -- on SubSection secondary_nets_of LED0 match
										Line_pt_secondary_nets := Ada.Text_IO.Line(netlist_copy);	-- secondary nets found, save line number
										secondary_net_found := true;
								end if;

								if Is_Field(Line_secondary_net,"EndSubSection",1) and Is_Field(Line_secondary_net,"secondary_nets_of",2) 
									and Is_Field(Line_secondary_net,to_string(net_name_primary),3) then  -- on EndSubSection secondary_nets_of LED0 match
										Line_pt := Ada.Text_IO.Line(netlist_copy);
										exit;
								end if;

							end if; -- reading non-empty line from netlist
						end loop;
					Set_Input(netlist); -- switch back to input source "netlist"
					Set_Line(netlist,Line_pt); -- set netlist line pointer to line below "EndSubSection secondary_nets_of LED0" or 
											   -- if not secondary nets found below "EndSubSection"

					-- check net class of primary and secondary nets
					check_class(to_string(net_name_primary),net_class_primary,Line_pt_primary_net,secondary_net_found,Line_pt_secondary_nets);

				end if;

			end if; -- reading non-empty line from netlist
		end loop;



	--finalize cell lists
	Set_Output(locked_eh_el_unknown_cells); put ("EndSection"); new_line; Close(locked_eh_el_unknown_cells);
	Copy_File("tmp/locked_eh_el_unknown_cells.tmp","tmp/locked_eh_el_unknown_cells_copy.tmp");
	Set_Output(expect_input_cells); put ("EndSection"); new_line;
	Set_Output(expect_atg_cells); put ("EndSection"); new_line;
	Set_Output(input_unknown_cells); put ("EndSection"); new_line;

	Set_Output(Standard_Output);
	put ("step 3: identifying DH,DL and NR drivers..."); new_line; -- mod v042


	Open( 
		File => locked_eh_el_unknown_cells,
		Mode => In_File,
		Name => "tmp/locked_eh_el_unknown_cells_copy.tmp"
		);

	Open( 
		File => locked_dh_dl_output_cells,
		Mode => Append_File,
		Name => "tmp/locked_dh_dl_output_cells.tmp"
		);

	Open( 
		File => locked_dh_dl_nr_cells,
		Mode => Append_File,
		Name => "tmp/locked_dh_dl_nr_cells.tmp"
		);

	Open( 
		File => drive_atg_cells,
		Mode => Append_File,
		Name => "tmp/drive_atg_cells.tmp"
		);


	Set_Input(netlist);
	Reset(netlist);
	while not End_Of_File
		loop
			Line_netlist:=Get_Line; -- read from netlist

			if Get_Field_Count(Line_netlist) > 0 then
				-- search for primary net
				if Is_Field(Line_netlist,"SubSection",1) then -- the first net in netlist is a primary net e.g. SubSection LED0 class NR
					Line_pt_primary_net := Ada.Text_IO.Line(netlist);	-- primary net found, save line number
					--put (Line_netlist); new_line;
					net_name_primary  := to_unbounded_string(Get_Field(Line_netlist,2));
					net_class_primary := Get_Field(Line_netlist,4);
					secondary_net_found := false;

					-- search for secondary nets of the current primary net
					Set_Input(netlist_copy); -- set input source to netlist_copy
					Reset(netlist_copy);
					Set_Line(netlist_copy,Line_pt_primary_net); -- set netlist_copy pointer to line below "SubSection LED0 class NR" 
					Line_pt := Line_pt_primary_net; -- backup netlist_copy pointer in case there are no secondary nets
					while not End_Of_File	
						loop
							Line_secondary_net:=Get_Line;
							if Get_Field_Count(Line_secondary_net) > 0 then
								
								if Is_Field(Line_secondary_net,"SubSection",1) and Is_Field(Line_secondary_net,"secondary_nets_of",2) 
									and Is_Field(Line_secondary_net,to_string(net_name_primary),3) then  -- on SubSection secondary_nets_of LED0 match
										Line_pt_secondary_nets := Ada.Text_IO.Line(netlist_copy);	-- secondary nets found, save line number
										secondary_net_found := true;
								end if;

								if Is_Field(Line_secondary_net,"EndSubSection",1) and Is_Field(Line_secondary_net,"secondary_nets_of",2) 
									and Is_Field(Line_secondary_net,to_string(net_name_primary),3) then  -- on EndSubSection secondary_nets_of LED0 match
										Line_pt := Ada.Text_IO.Line(netlist_copy);
										exit;
								end if;

							end if; -- reading non-empty line from netlist
						end loop;
					Set_Input(netlist); -- switch back to input source "netlist"					
					Set_Line(netlist,Line_pt); -- set netlist line pointer to line below "EndSubSection secondary_nets_of LED0" or 
											   -- if not secondary nets found below "EndSubSection"

					-- check net class of primary nets
					find_dh_dl_nr_driver(to_string(net_name_primary),net_class_primary,Line_pt_primary_net,secondary_net_found);
					Set_Input(netlist); -- switch back to input source "netlist"					

				end if;

			end if; -- reading non-empty line from netlist
		end loop;

	Set_Output(locked_dh_dl_nr_cells);
	put ("EndSection"); new_line; Close(locked_dh_dl_nr_cells);
	Copy_File("tmp/locked_dh_dl_nr_cells.tmp","tmp/locked_dh_dl_nr_cells_copy.tmp");

	Set_Output(locked_dh_dl_output_cells);
	put ("EndSection"); new_line; Close(locked_dh_dl_output_cells);

	Close(drive_atg_cells);
	Copy_File("tmp/drive_atg_cells.tmp","tmp/drive_atg_cells_old.tmp");

	Set_Output(Standard_Output);
	put ("step 4: identifying PU and PD drivers..."); new_line; -- mod v042

	
	Open( 
		File => locked_dh_dl_nr_cells,
		Mode => In_File,
		Name => "tmp/locked_dh_dl_nr_cells_copy.tmp"
		);

	Open( 
		File => drive_atg_cells_old,
		Mode => In_File,
		Name => "tmp/drive_atg_cells_old.tmp"
		);

	Open( 
		File => drive_atg_cells,
		Mode => Append_File,
		Name => "tmp/drive_atg_cells.tmp"
		);

	Open( 
		File => locked_pu_pd_output_cells,
		Mode => Append_File,
		Name => "tmp/locked_pu_pd_output_cells.tmp"
		);

	Open( 
		File => locked_pu_pd_cells,
		Mode => Append_File,
		Name => "tmp/locked_pu_pd_cells.tmp"
		);


	Set_Input(netlist);
	Reset(netlist);
	while not End_Of_File
		loop
			Line_netlist:=Get_Line; -- read from netlist

			if Get_Field_Count(Line_netlist) > 0 then
				-- search for primary net
				if Is_Field(Line_netlist,"SubSection",1) then -- the first net in netlist is a primary net e.g. SubSection LED0 class NR
					Line_pt_primary_net := Ada.Text_IO.Line(netlist);	-- primary net found, save line number
					--put (Line_netlist); new_line;
					net_name_primary  := to_unbounded_string(Get_Field(Line_netlist,2));
					net_class_primary := Get_Field(Line_netlist,4);
					secondary_net_found := false;

					-- search for secondary nets of the current primary net
					Set_Input(netlist_copy); -- set input source to netlist_copy
					Reset(netlist_copy);
					Set_Line(netlist_copy,Line_pt_primary_net); -- set netlist_copy pointer to line below "SubSection LED0 class NR" 
					Line_pt := Line_pt_primary_net; -- backup netlist_copy pointer in case there are no secondary nets
					while not End_Of_File	
						loop
							Line_secondary_net:=Get_Line;
							if Get_Field_Count(Line_secondary_net) > 0 then
								
								if Is_Field(Line_secondary_net,"SubSection",1) and Is_Field(Line_secondary_net,"secondary_nets_of",2) 
									and Is_Field(Line_secondary_net,to_string(net_name_primary),3) then  -- on SubSection secondary_nets_of LED0 match
										Line_pt_secondary_nets := Ada.Text_IO.Line(netlist_copy);	-- secondary nets found, save line number
										secondary_net_found := true;
								end if;

								if Is_Field(Line_secondary_net,"EndSubSection",1) and Is_Field(Line_secondary_net,"secondary_nets_of",2) 
									and Is_Field(Line_secondary_net,to_string(net_name_primary),3) then  -- on EndSubSection secondary_nets_of LED0 match
										Line_pt := Ada.Text_IO.Line(netlist_copy);
										exit;
								end if;

							end if; -- reading non-empty line from netlist
						end loop;
					Set_Input(netlist); -- switch back to input source "netlist"					
					Set_Line(netlist,Line_pt); -- set netlist line pointer to line below "EndSubSection secondary_nets_of LED0" or 
											   -- if not secondary nets found below "EndSubSection"

					-- check net class of primary nets
					find_pu_pd_driver(to_string(net_name_primary),net_class_primary,Line_pt_primary_net,secondary_net_found);
					Set_Input(netlist); -- switch back to input source "netlist"					

				end if;

			end if; -- reading non-empty line from netlist
		end loop;


	Close(locked_eh_el_unknown_cells);
	Close(locked_dh_dl_nr_cells);
	Close(drive_atg_cells_old);

	Set_Output(locked_pu_pd_cells); put ("EndSection"); new_line;
	Set_Output(locked_pu_pd_output_cells); put ("EndSection"); new_line;
	Set_Output(drive_atg_cells); put ("EndSection"); new_line;
	Close(locked_pu_pd_cells);
	Close(locked_pu_pd_output_cells);
	Close(drive_atg_cells);
	Close(expect_atg_cells);
	Close(input_unknown_cells);
	Close(expect_input_cells);

	Set_Input(Standard_Input);
	Close(netlist);

	--Close(netlist_copy);

	Set_Output(Standard_Output);
	put ("step 5: updating UUT database " & data_base & " ..."); new_line; -- mod v042

	-- assemble new udb
	extract_section(to_string(data_base),"tmp/new_udb.tmp","Section","EndSection","scanpath_configuration");

	--Abort_Task (Current_Task); -- CS: not safe
	
  	Open( 
  		File => new_udb,
  		Mode => Append_File,
  		Name => "tmp/new_udb.tmp"
  		);
  	Set_Output(new_udb); 

	-- read scanpath_configuration section from given udb and append to new udb
  	new_line; new_line;
	put ("---------- REGISTERS -----------------------------------------------------------------------------------------"); new_line; new_line;
	extract_section(to_string(data_base),"tmp/registers.tmp","Section","EndSection","registers");
	append_file_open("tmp/registers.tmp");

	-- append checked netlist to new udb
	new_line; new_line;
	put ("---------- NETLIST -------------------------------------------------------------------------------------------"); new_line; new_line;
	append_file_open("tmp/netlist_psnc.tmp");

	-- append lists of locked cells to new udb
	new_line; new_line;
	put ("---------- CELL LIST -----------------------------------------------------------------------------------------"); new_line; new_line;
  	append_file_open("tmp/locked_eh_el_unknown_cells.tmp");

 	new_line;
	append_file_open("tmp/locked_dh_dl_nr_cells.tmp");
 	new_line;
	append_file_open("tmp/locked_pu_pd_cells.tmp");
 	new_line;
	append_file_open("tmp/locked_pu_pd_output_cells.tmp");
 	new_line;
	append_file_open("tmp/locked_dh_dl_output_cells.tmp");
 	new_line;
	append_file_open("tmp/expect_input_cells.tmp");
 	new_line;
	append_file_open("tmp/expect_atg_cells.tmp");
 	new_line;
	append_file_open("tmp/drive_atg_cells.tmp");
 	new_line;
	append_file_open("tmp/input_unknown_cells.tmp");
 	new_line;


	-- write statistics to new_udb
	new_line;
	put ("---------- STATISTICS ----------------------------------------------------------------------------------------"); new_line; new_line;
	put ("Section statistics"); new_line;
	put ("---------------------------------------------------"); new_line;
	put (" Pull-Up nets        (PU): " & Natural'Image(net_ct_pu)); new_line;
	put (" Pull-Down nets      (PD): " & Natural'Image(net_ct_pd)); new_line;
	put (" Drive-High nets     (DH): " & Natural'Image(net_ct_dh)); new_line;
	put (" Drive-Low nets      (DL): " & Natural'Image(net_ct_dl)); new_line;
	put (" Expect-High nets    (EH): " & Natural'Image(net_ct_eh)); new_line;
	put (" Expect-Low nets     (EL): " & Natural'Image(net_ct_el)); new_line;
	put (" unrestricted nets   (NR): " & Natural'Image(net_ct_nr)); new_line;
	put (" not classified nets (NA): " & Natural'Image(net_ct_na)); new_line;
	put ("---------------------------------------------------"); new_line;
	put (" total                   : " & Natural'Image(net_ct_pu + net_ct_pd + net_ct_dh + net_ct_dl + net_ct_eh + net_ct_el + net_ct_nr + net_ct_na)); new_line;
	put ("---------------------------------------------------"); new_line;
	--put (" thereof :"); new_line;
	put (" bs-nets static          : " & Natural'Image(net_ct_dh + net_ct_dl + net_ct_eh + net_ct_el)); new_line;
	put (" thereof :"); new_line;
	put ("   bs-nets static L      : " & Natural'Image(net_ct_dl + net_ct_el)); new_line;
	put ("   bs-nets static H      : " & Natural'Image(net_ct_dh + net_ct_eh)); new_line;
	put (" bs-nets dynamic         : " & Natural'Image(net_ct_pu + net_ct_pd + net_ct_nr)); new_line;
	put (" bs-nets testable        : " & Natural'Image(net_ct_pu + net_ct_pd + net_ct_dh + net_ct_dl + net_ct_eh + net_ct_el + net_ct_nr)); new_line;
	put ("EndSection"); new_line;
	
	Close(new_udb);
	Copy_File("tmp/new_udb.tmp",to_string(data_base));

	Set_Output(Standard_Output);
	new_line;
	put ("CAUTION: READ WARNINGS ISSUED IN FILE msg/chkpsn.txt !!!"); new_line;

	exception
		when constraint_error =>
			put_line(prog_position);
		
end chkpsn;
