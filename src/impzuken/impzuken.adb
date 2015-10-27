with Ada.Text_IO;			use Ada.Text_IO;
with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
--with Ada.Float_Text_IO;		use Ada.Float_Text_IO;
with Ada.Characters; 		use Ada.Characters;
with Ada.Characters.Handling; 		use Ada.Characters.Handling;
with ada.characters.conversions;	use ada.characters.conversions;

with m1; use m1;

--with System.OS_Lib;   use System.OS_Lib;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
--with Ada.Strings.Bounded; 	use Ada.Strings.Bounded;
with Ada.Strings.Fixed; 	use Ada.Strings.Fixed;
with Ada.Strings;		 	use Ada.Strings;
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

procedure impzuken is

	Version			: String (1..3) := "1.0";
	device   		: Unbounded_string;
	netlist   		: Unbounded_string;
	submodule_name	: Unbounded_string;
	np		 		: Ada.Text_IO.File_Type;
	nets	 		: Ada.Text_IO.File_Type;
	netlist_file	: Ada.Text_IO.File_Type;
	overwrite_main_module	: boolean := false;
	overwrite_sub_module	: boolean := false;
	skeleton		: Ada.Text_IO.File_Type;

	line_ct		: Natural:=0;
	net_ct		: Natural:=0;
	part_ct		: Natural:=0;

	Previous_Output	: File_Type renames Current_Output;
	OutputFile 		: Ada.Text_IO.File_Type;
	prog_position 	: string := "---"; 

	key				: String (1..1) := "n";
	scratch			: Unbounded_string;
	Line			: Unbounded_string;
	dummy			: Integer;


	type netlist_line is
		record		
			net			: unbounded_string;
			device		: Unbounded_String;
			value		: Unbounded_String;
			packge 		: Unbounded_String;
			pin  		: Unbounded_String;
			--line_id		: Natural := 0;
			processed	: Boolean := false;
		end record;

	type netlist_array_type is array (Natural range <>) of netlist_line;





	function make_netlist_array
		(
		line_ct	: natural
		) return natural is
		
		char_current	: character := ' ';
		netlist_array	: netlist_array_type (Natural range 1..line_ct);
		end_marker		: constant character := ';';
		entries_counter : natural := 0;
		scratch			: unbounded_string;
		ct				: natural := 1;
		net_ct			: natural := 0;

		begin

			while not end_of_file
				loop
					get(char_current);
					case char_current is

						when end_marker => 
							entries_counter := entries_counter + 1;
							line := line & Character'Val(10);
							--put_line(line);

							netlist_array(entries_counter).net := to_unbounded_string(replace_char(trim(replace_char(get_field(line,1,':'),'"',' '), side => both),' ','_'));
							--put_line(netlist_array(entries_counter).net);

							-- extract package field, replace '"' by ' ', trim sides, replace ' ' by '_'
							netlist_array(entries_counter).packge := to_unbounded_string(replace_char(trim(replace_char(get_field(line,4,':'),'"',' '), side => both),' ','_'));
							if netlist_array(entries_counter).packge = to_unbounded_string("") then netlist_array(entries_counter).packge := to_unbounded_string("package_unknown"); end if; 
							--put_line(netlist_array(entries_counter).packge);

							-- extract value field, replace '"' by ' ', trim sides, replace ' ' by '_'
							netlist_array(entries_counter).value := to_unbounded_string(replace_char(trim(replace_char(get_field(line,3,':'),'"',' '), side => both),' ','_'));
							--put_line(netlist_array(entries_counter).value);

							-- extract device field, replace '"' by ' ', trim sides, replace ' ' by '_'
							netlist_array(entries_counter).device := to_unbounded_string(replace_char(trim(replace_char(get_field(line,5,':'),'"',' '), side => both),' ','_'));
							--put_line(netlist_array(entries_counter).device);

							-- extract pin field, replace '"' by ' ', trim sides, replace ' ' by '_'
							netlist_array(entries_counter).pin := to_unbounded_string(replace_char(trim(replace_char(get_field(line,6,':'),'"',' '), side => both),' ','_'));
							--put_line(netlist_array(entries_counter).pin);
 							
							--new_line;
							line := to_unbounded_string(""); -- clear line buffer
							--netlist_array(entries_counter).processed := true;

						when others => -- file line buffer char by char
							line := line & char_current;
					end case;


					--pointer:=pointer+1;
					--put_line(get_field(line,2,' '));
					
				end loop;
--		put_line(natural'image(entries_counter));

		new_line;
		put_line("Section netlist_skeleton");

		-- make skeleton netlist from netlist_array
		entries_counter := 1;
		while entries_counter <= line_ct 
			loop
				if netlist_array(entries_counter).processed = false then -- care for unprocessed entries only
					net_ct := net_ct + 1;
					new_line;
					put_line(" SubSection " & netlist_array(entries_counter).net & " class NA"); -- write net section header
					put_line("  " & netlist_array(entries_counter).device & " ? " & netlist_array(entries_counter).value & " " & netlist_array(entries_counter).packge & " " & netlist_array(entries_counter).pin);
					netlist_array(entries_counter).processed := true; -- mark entry as processed

					-- search for entries having the same net name
					ct := 1;
					while ct <= line_ct  
						loop
							if netlist_array(ct).processed = false then -- care for unprocessed entries only
								if netlist_array(ct).net = netlist_array(entries_counter).net then -- on net name match write dev, val, pack, pin in tmp/nets.tmp
									put_line("  " & netlist_array(ct).device & " ? " & netlist_array(ct).value & " " & netlist_array(ct).packge & " " & netlist_array(ct).pin);
									netlist_array(ct).processed := true; -- mark entry as processed
								end if;
							end if;
							ct := ct + 1; -- advance entry pointer
						end loop;
					put_line(" EndSubSection"); -- close net section
				end if;
			
				entries_counter := entries_counter + 1;	-- advance entry pointer
			
			end loop;
		put_line("EndSection"); -- close netlist skeleton

		return net_ct;
	end make_netlist_array;



	function umask( mask : integer ) return integer;
		pragma import( c, umask );


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin

	if exists ("skeleton.txt") then 
		put_line("WARNING ! CAD data for main module already exists.");
		put("          Overwrite existing data set ? (y/n/c) "); get(key); --put_line(key);

		if key /= "y" and key /= "n" then 
			put_line("CAD data import cancelled");
			prog_position := "CAN"; 
			raise Constraint_Error;
		elsif key = "y" then
			overwrite_main_module := true;
		elsif key = "n" then
			overwrite_sub_module := true;
			put_line("Importing CAD data as UUT submodule.");
			put ("Enter submodule name : "); 
			--flush;
			submodule_name := (get_line);
			submodule_name := (get_line);  
			--put_line("submodule :" & submodule_name);

			if exists ("skeleton_" & to_string(submodule_name) & ".txt" ) then
				put_line("WARNING ! CAD data for submodule '" & submodule_name & "' already exists.");
				put("          Overwrite existing data set ? (y/n/c) "); get(key);
				if key /= "y" then 
					prog_position := "CAN"; 
					raise Constraint_Error;
				end if;
			end if;

		end if;
	end if;


	dummy := umask ( 003 );

	-- recreate an empty tmp directory
	if exists ("tmp") then 
		Delete_Tree("tmp");
		Create_Directory("tmp");
	else Create_Directory("tmp");
	end if;

	new_line;
	put_line("importing ZUKEN CR5000 CAD-Data with importer version " & version);
	prog_position := "NLT";
	netlist:=to_unbounded_string(Argument(1));
	put_line ("netlist           : " & netlist);


 	Create( OutputFile, Name => "tmp/np.tmp"); Close(OutputFile);
 	Open( 
 		File => np,
 		Mode => Append_File,
 		Name => "tmp/np.tmp"
 		);
 	Set_Output(np);

	put_line("Section info");
	if overwrite_sub_module then put_line(" -- netlist skeleton submodule");
	else put_line(" -- netlist skeleton");
	end if;

	put_line(" -- created by impzuken version " & version );
	put (" -- date       : " ); put (Image(clock)); new_line; 
	put (" -- UTC_Offset : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; new_line;
	put_line("-----------------------------------------------------------------------------------");

 	Create( OutputFile, Name => "tmp/nets.tmp"); Close(OutputFile);
 	Open( 
 		File => nets,
 		Mode => Out_File,
 		Name => "tmp/nets.tmp"
 		);
 
 
 	Set_Output(Standard_Output);
 
 	Open( 
 		File => netlist_file,
 		Mode => In_File,
 		Name => to_string(netlist)
 		);
 	Set_Input(netlist_file);

	-- count entries in netlist ending with ';'
	line_ct:=count_entries(';');

	put_line("processing" & natural'image(line_ct) & " pins ..."); --new_line;
 	Set_Output(nets);
	reset(netlist_file);
	net_ct:=make_netlist_array(line_ct);

 	Set_Output(np);
	put_line(" --" & natural'image(net_ct) & " nets imported");
	put_line("EndSection"); new_line;
	close(nets);

	append_file_open("tmp/nets.tmp");
	close(np);

 	Set_Output(Standard_Output);
	if overwrite_main_module = false and overwrite_sub_module = false then 
		copy_file("tmp/np.tmp","skeleton.txt"); 
		put_line("NOTE: Please read 'skeleton.txt' for warnings !");	
	end if;

	if overwrite_main_module then 
		copy_file("tmp/np.tmp","skeleton.txt"); 
		put_line("NOTE: Please read 'skeleton.txt' for warnings !");	
	end if;

	if overwrite_sub_module then 
		copy_file("tmp/np.tmp","skeleton_" & to_string(submodule_name) & ".txt"); 
		put_line("NOTE: Please read 'skeleton_" & submodule_name & ".txt' for warnings !");	
	end if;


end impzuken;
