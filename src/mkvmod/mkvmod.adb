with Ada.Text_IO;			use Ada.Text_IO;
with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
with Ada.Float_Text_IO;		use Ada.Float_Text_IO;
with Ada.Sequential_IO;		--use Ada.Sequential_IO;
with Ada.Characters; 		use Ada.Characters;
with Ada.Characters.Handling; 		use Ada.Characters.Handling;
with ada.characters.conversions;	use ada.characters.conversions;

with m1; use m1;

--with System.OS_Lib;   use System.OS_Lib;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.maps;	 	use Ada.Strings.maps;
with Ada.Strings.Fixed; 	use Ada.Strings.Fixed;
with Ada.Strings;		 	use Ada.Strings;
with interfaces;			use interfaces;
--with Ada.Numerics;			use Ada.Numerics;
--with Ada.Numerics.Elementary_Functions;	use Ada.Numerics.Elementary_Functions;

with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
--with Ada.Task_Identification;  use Ada.Task_Identification;
with Ada.Exceptions; use Ada.Exceptions;
 
--with GNAT.OS_Lib;   	use GNAT.OS_Lib;
with Ada.Command_Line;	use Ada.Command_Line;
with Ada.Directories;	use Ada.Directories;
 
with Ada.Calendar;				use Ada.Calendar;
with Ada.Calendar.Formatting;	use Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;	use Ada.Calendar.Time_Zones;


procedure mkvmod is

	Version			: String (1..3) := "004";
	prog_position	: String (1..3) := "---";
	module_name		: unbounded_string;
	skeleton_name	: unbounded_string;
	vfile      		: Ada.Text_IO.File_Type;
	scratch			: Unbounded_string;
	Line			: Unbounded_string;
	dummy			: Integer;
	skeleton 		: Ada.Text_IO.File_Type;
	net_ct			: natural;
	connector_prefix	: character := 'X';
	key				: String (1..1) := "n";

	function umask( mask : integer ) return integer;
		pragma import( c, umask );



	procedure process_netlist
		(
		net_ct : in natural
		)
		is

		line		: unbounded_string;
		net_entered	: Boolean := false;
		ct			: Natural := 0;
		ct2			: Natural := 0;
		type single_net is
			record
				id				: Natural := 0; -- indexing starts with 1, zero means: net not processed yet
				name			: unbounded_string;
				device_ct		: Natural := 0;
				content			: unbounded_string;
				processed		: Boolean := false;
				connector_net	: Boolean := false;	-- if net contains a connector -> true
				connector_list	: unbounded_string; -- list of connectors found in this net
				connector_count : Natural := 0;
			end record;
		type netlist_array_type is array (Natural range <>) of single_net;	
		subtype netlist_array_sized is netlist_array_type(1..net_ct);
		netlist_array	: netlist_array_sized;
		connector_list	: unbounded_string;	-- global connector list
		connector_count	: natural := 0;	-- global connector count
		connector_pointer : natural;


		procedure add_to_connector_list	-- on every occurence of a connector
		(
		connector_name : in string
		)
		is
		ct : Natural := 1;
		connnector_already_listed : boolean := false;
		begin
			-- update global connector count
			connector_count	:= get_field_count(connector_list);
			while ct <= connector_count
			loop  -- search global connector list for this connector
				if get_field(connector_list,ct) = connector_name then
					connnector_already_listed := true;  -- if found, mark connector as "already listed"
					exit; -- and stop seaching
				end if;
				ct := ct + 1;
			end loop;
			if not connnector_already_listed then -- if connector not listed, add to global connector list
				connector_list := connector_list & " " & connector_name;
				-- update global connector count
				connector_count	:= get_field_count(connector_list);
			end if;
		end add_to_connector_list;
		

		begin
			while not End_Of_File -- read from netlist in array
			loop
				Line:=Get_Line;
					--put(Line); new_line;
					if Get_Field_Count(Line) > 0 then 
								
						-- if net section begin found
						if get_field(Line,1) = "SubSection" then
 							ct := ct + 1;
 							netlist_array(ct).id	:= ct;
 							netlist_array(ct).name	:= to_unbounded_string(Get_Field(Line,2));
							net_entered := true;

						-- if net section end found
						elsif get_field(Line,1) = "EndSubSection" then
								--netlist_array(ct).processed	:= true;
							net_entered := false;
								
							-- debug
							--put(netlist_array(ct).id); new_line;
							--put(netlist_array(ct).name); new_line;
							--put(netlist_array(ct).content); new_line (2);
							
						elsif net_entered then
 							-- net section entered 
	

							-- update device counter of this net (used to detect one pin nets or so called dead ends)
							netlist_array(ct).device_ct := netlist_array(ct).device_ct + 1;

							-- test if device is a connector
							if get_field(line,1)(1) = connector_prefix then
								netlist_array(ct).connector_net := true;

								-- update global connector list
								add_to_connector_list(get_field(line,1)); 

								-- update connector/pin list of this net
								netlist_array(ct).connector_list := netlist_array(ct).connector_list & to_unbounded_string(" " & get_field(line,1) & " " & get_field(line,5));

								-- update connector count of this net
								netlist_array(ct).connector_count := netlist_array(ct).connector_count + 1;
							end if;

						end if;
							
					end if;		
			end loop;

			-- do a cross check of net count proviede (net_ct) and nets counted here (ct)
			if net_ct = ct then null; 
			else
				Set_Output(standard_output);
				put_line("ERROR: Net count mismatch !");
				raise constraint_error;
				--CS: put more details here
			end if;
			-- netlist array ready

		-- port list writing begin

			-- debug
			--put(connector_list);
			put_line("    // connector count total :" & Natural'Image(connector_count)); new_line;
			ct := 1; -- preset global connector pointer
			while ct <= connector_count
			loop
				-- write connector name as comment in vfile
				new_line;
				put_line("    // connector " & get_field(connector_list,ct));
				put_line("    // inout " & get_field(connector_list,ct) & ","); -- ins V004
				ct2 := 1; -- preset net pointer
				-- find nets connected to the current connector

				while ct2 <= net_ct
				loop

					-- search in connector nets only and skip dead ends (one pin nets), skip GND nets
					if netlist_array(ct2).connector_net and netlist_array(ct2).device_ct > 1 and netlist_array(ct2).name /= "GND" then
						connector_pointer := 1; -- preset local connector pointer

						-- search connector list of this net (connector list contains twice as many fields as connectors in this net
						-- name, pin i.e. X1 4 X65 2 ...)
						while connector_pointer <= (netlist_array(ct2).connector_count * 2)
						loop
							-- if connector name in net = current connector -> match
							if get_field(netlist_array(ct2).connector_list,connector_pointer) = get_field(connector_list,ct) then
							-- write in vfile:
							put_line("    //");
							put_line(
									"    // INFO: pin " & -- as comment: former pin
									get_field(netlist_array(ct2).connector_list,connector_pointer+1) & -- pin itself
									" / former net name: " & netlist_array(ct2).name  -- former net name
									);
							put_line(
									"    //output " & -- direction
									get_field(connector_list,ct) & "_" & -- port name part 1 (connector name)
									"pin_" & get_field(netlist_array(ct2).connector_list,connector_pointer+1) & "_" & -- port name part 2 (pin name)
									"net_" &convert_special_char_to_underscore(to_string(netlist_array(ct2).name)) & -- port name part 3 (converted net name)
									","  -- final comma
									);
							put_line(
									"    //input  " & -- direction
									get_field(connector_list,ct) & "_" & -- port name part 1 (connector name)
									"pin_" & get_field(netlist_array(ct2).connector_list,connector_pointer+1) & "_" & -- port name part 2 (pin name)
									"net_" &convert_special_char_to_underscore(to_string(netlist_array(ct2).name)) & -- port name part 3 (converted net name)
									","  -- final comma
									);
							put_line(
									"    //inout  " & -- direction
									get_field(connector_list,ct) & "_" & -- port name part 1 (connector name)
									"pin_" & get_field(netlist_array(ct2).connector_list,connector_pointer+1) & "_" & -- port name part 2 (pin name)
									"net_" &convert_special_char_to_underscore(to_string(netlist_array(ct2).name)) & -- port name part 3 (converted net name)
									","  -- final comma
									);

							end if;
							connector_pointer := connector_pointer + 2;
						end loop;

					end if;
					ct2 := ct2 + 1;	-- prepare for next net
				end loop;
				ct := ct + 1; -- prepare for next connector
			end loop;

		put_line ("    // NOTE: Remove trailing comma from last line !");
		put_line ("    );"); 
		put_line ("    // port list end"); new_line;
		-- port list writing end

		-- assignment writing begin
		put_line ("    // assignment list begin");
		put_line ("    // NOTE: - Ports which can be assigned to each other are listed only.");
		put_line ("    //       - The actual data direction is to be taken from the schematic.");
		put_line ("    //       - Example: assign a = b; means: b drives a.");
		put_line ("    //       - data sink left, data source right");
		put_line ("    //       - GND nets are omitted. Power supply nets may be left commented."); new_line;
		ct2 := 1; -- preset net pointer
		-- find connector nets with at least 2 connector pins

		while ct2 <= net_ct
			loop
				-- search in connector nets with at least 2 connectors only (skip GND nets)
				if netlist_array(ct2).connector_net and netlist_array(ct2).connector_count >= 2 and netlist_array(ct2).name /= "GND" then
					connector_pointer := 1; -- preset connector pointer of this net
					-- search connector list of this net (connector list contains twice as many fields as connectors in this net
					-- name, pin i.e. X1 4 X65 2 ...)
					while connector_pointer <= (netlist_array(ct2).connector_count * 2)
					loop
						put(
							"    //assign " & 
							get_field(netlist_array(ct2).connector_list,connector_pointer) & "_" & -- port name part 1 (connector name)
							"pin_" & get_field(netlist_array(ct2).connector_list,connector_pointer+1) & "_" & -- port name part 2 (pin name)
							"net_" & convert_special_char_to_underscore(to_string(netlist_array(ct2).name)) & -- port name part 3 (converted net name)
							" = yxz ;"
							--get_field(netlist_array(ct2).connector_list,3) & "_" & -- port name part 1 (connector name)
							--"pin_" & get_field(netlist_array(ct2).connector_list,4) & "_" & -- pin name
							--"net_" & convert_special_char_to_underscore(to_string(netlist_array(ct2).name)) & -- port name part 2 (converted net name)
							--" ;"
							);
						new_line;
						connector_pointer := connector_pointer + 2;
					end loop;
				new_line;
				end if;
				ct2 := ct2 + 1;	-- prepare for next net
			end loop;
		--put_line ("    assign OSC_OUT = !OSC_RC;");
		new_line;
		put_line ("    // assignment list end");
		-- assignment writing end
	
		end;


begin
	dummy := umask ( 003 );
	clean_up_tmp_dir;

	new_line;
	put_line("Verilog Model Maker Version "& Version); new_line;

	prog_position := "ARC";
	if argument_count /= 2 then
		raise Constraint_Error;
	end if;

	prog_position := "SKE";
	skeleton_name:=(to_unbounded_string(Argument(1))); -- raises exception if skeleton file not given
	if exists(to_string(skeleton_name)) then null; -- raises exception if skeleton does not exist
		else 
			prog_position := "NSK";	
			raise Constraint_Error;
	end if;

	prog_position := "MOD";
	module_name:=(to_unbounded_string(Argument(2))); -- raises exception if module name not given

	if exists (to_string(module_name) & ".v") then 
		put_line("WARNING ! Target Verilog module already exists.");
		put("          Overwrite existing module ? (y/n/c) "); get(key); --put_line(key);
		if key /= "y" then 
			put_line("Writing Verilog module cancelled !");
			prog_position := "CAN"; 
			raise Constraint_Error;
		end if;
	end if;


	-- read info from skeleton
	extract_section(to_string(skeleton_name),"tmp/info_skeleton.tmp","Section","EndSection","info");


	-- read netlist from skeleton
	extract_section(to_string(skeleton_name),"tmp/netlist_skeleton.tmp","Section","EndSection","netlist_skeleton");
	-- CS: remove comments from netlist section ?
	Open( 
		File => skeleton,
		Mode => In_File,
		Name => "tmp/netlist_skeleton.tmp"
		);
	Set_Input(skeleton);
	net_ct := count_nets;
	reset(skeleton);

	-- debug
	--put ("- net count total :" & Natural'Image(net_ct)); new_line;

	Create( vfile, Name => to_string(module_name & ".v")); Close(vfile);
	Open( 
		File => vfile,
		Mode => out_file,
		Name => to_string(module_name & ".v")
		);
	Set_Output(vfile);
	
	new_line;

	put_line ("/* Verilog Model"); new_line;
	put ("--------------------------------------------"); new_line;
	put ("created by mkvmod version " & version); new_line;
	put ("contact: Blunk electronic at www.train-z.de"); new_line;
	put ("date       : " ); put (Image(clock)); new_line; 
	put ("UTC_Offset : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; new_line;
	
	put_line ("ORIGIN:"); new_line;
	append_file_open("tmp/info_skeleton.tmp");
	new_line;
	put_line ("ORIGIN END"); new_line;

	put_line ("NOTE: - Port directions are commented, uncomment according to your needs !");
	put_line ("      - One-Pin nets are omitted here as hey are dead ends in the schematic.");
	put_line ("      - Verilog is case insensitive and accepts letters, numbers and underscore only."); new_line;
	put_line ("Leave your comments here: ");
	new_line; new_line;	new_line; new_line;
	put_line ("*/"); new_line;

	put_line ("`timescale 1ns / 1ps // required for simulation"); new_line;
	-- convert_special_char_to_underscore required for module name
	put_line ("module " & convert_special_char_to_underscore(to_string(module_name)));
	put_line ("    (");

	process_netlist(net_ct);

	put_line ("endmodule");
	close(vfile);
	close(skeleton);

	exception
		when Constraint_Error => 
			if prog_position = "ARC" then
				put ("ERROR ! Too little arguments specified !"); new_line;
				put ("        Example: mkvmod skeleton.txt your_verilog_module (without .v extension)"); new_line;  
			elsif prog_position = "SKE" then
				put ("ERROR ! No input skeleton file specified !"); new_line; 
			elsif prog_position = "NSK" then
				put ("ERROR ! The given input skeleton file does not exist !"); new_line; 
			elsif prog_position = "MOD" then
				put ("ERROR : No output module name specified !"); new_line;
			else null;
			end if;
			Set_Exit_Status(Failure);		
end mkvmod;
