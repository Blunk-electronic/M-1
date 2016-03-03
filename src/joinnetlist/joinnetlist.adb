------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE JOINNETLIST                         --
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


with Ada.Text_IO;		use Ada.Text_IO;
with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
with Ada.Sequential_IO;
--with System.OS_Lib;   use System.OS_Lib;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
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
 
procedure joinnetlist is
	Version			: String (1..3) := "002";
	skeleton_sub 	: unbounded_string;
	prog_position	: String (1..3) := "---";
	OutputFile 		: Ada.Text_IO.File_Type;
	scratch			: Unbounded_string;
	Line			: Unbounded_string;
	dummy			: Integer;
	InputFile		: Ada.Text_IO.File_Type;
	

	function umask( mask : integer ) return integer;
		pragma import( c, umask );



begin

	new_line;
	put("Netlist Joiner version "& Version); new_line;

	skeleton_sub:=to_unbounded_string(Argument(1));
	put ("submodule      : ");	put(skeleton_sub); new_line;

	dummy := umask ( 003 );
	
	-- recreate an empty tmp directory
	if exists ("tmp") then 
		Delete_Tree("tmp");
		Create_Directory("tmp");
	else Create_Directory("tmp");
	end if;

	extract_section("skeleton.txt","tmp/skeleton_brutto.tmp","Section","EndSection","netlist_skeleton");
	extract_netto_from_Section("tmp/skeleton_brutto.tmp","tmp/skeleton_netto.tmp");
	
	extract_section(to_string(skeleton_sub),"tmp/skeleton_brutto_sub.tmp","Section","EndSection","netlist_skeleton");
	extract_netto_from_Section("tmp/skeleton_brutto_sub.tmp","tmp/skeleton_netto_sub.tmp");
	
	--scratch:= ( delete(skeleton_sub,1,9) );
	--put(scratch(scratch'first .. scratch'last-1));
	
	--put (to_string(scratch)(to_string(scratch)'first+9 .. to_string(scratch)'last-4));
	--append_sub_name(to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4));
	--(to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4));
	
	Create( OutputFile, Name => Compose("tmp","skeleton_netto_sub_ext.tmp")); Close(OutputFile);
	Open( 
		File => OutputFile,
		Mode => Append_File,
		Name => ("tmp/skeleton_netto_sub_ext.tmp")
		);
	Set_Output(OutputFile);
	
	Open( 
		File => InputFile,
		Mode => In_File,
		Name => ("tmp/skeleton_netto_sub.tmp")
		);
	Set_Input(InputFile);
	
	while not End_Of_File
		loop
			Line:=Get_Line;
			if Get_Field_Count(Line) = 0 then new_line;
			
			elsif Is_Field(Line,"SubSection",1) then
-- rm V002 begin			
-- 				put ( " SubSection " & Get_Field(Line,2) & "_" 
-- 				 & (to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4))
-- 				 & " " & Get_Field(Line,3) & " " & Get_Field(Line,4) ); new_line;
-- rm V002 end

-- ins V002 begin			-- put prefix first before net name
 				put ( " SubSection " & (to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4)) & "_" 
 				 & Get_Field(Line,2)
 				 & " " & Get_Field(Line,3) & " " & Get_Field(Line,4) ); new_line;
-- ins V002 end

			--end if;
			
			elsif Is_Field(Line,"EndSubSection",1) then put(" EndSubSection"); new_line; --end if;

-- rm V002 begin			
--			else put ("  " & Get_Field(Line,1) & "_" 
-- 				 & (to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4))
-- 				 & " " & Get_Field(Line,2) & " " & Get_Field(Line,3) & " " & Get_Field(Line,4) & " " & Get_Field(Line,5) ); new_line;
-- rm V002 end

-- ins V002 begin 	- put prefix first before part name
			else put ("  " & (to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4)) & "_" 
				 & Get_Field(Line,1)
				 & " " & Get_Field(Line,2) & " " & Get_Field(Line,3) & " " & Get_Field(Line,4) & " " & Get_Field(Line,5) ); new_line;
-- ins V002 end

			end if;
		end loop;
	Set_Output(Standard_Output);	
	Set_Input(Standard_Input);	
	Close(InputFile);
	Close(OutputFile);	
	
	-- backup existing main module
	--extract_section( (to_string(data_base)) ,"tmp/spc_seed.tmp","Section","EndSection","scanpath_configuration");
	Copy_File( "skeleton.txt", Compose("bak","skeleton.txt"));
	Create( OutputFile, Name => Compose("tmp","skeleton.tmp")); Close(OutputFile);
	put ("NOTE           : A backup of the mainmodule skeleton can be found in directory 'bak'."); new_line;

	Open( 
		File => OutputFile,
		Mode => Append_File,
		Name => Compose("tmp","skeleton.tmp")
		);
	Set_Output(OutputFile);

	put ("Section info"); new_line;
	put ("---------------------------------------------------------------"); new_line;
	put ("-- created by Netlist Joiner version " & version); new_line;
	put ("-- date           : " ); put (Image(clock)); new_line; 
	put ("-- UTC_Offset     : " ); Put (Integer(UTC_Time_Offset/60),1); put(" hours"); new_line; new_line;
	put ("-- joined netlist : " & skeleton_sub); new_line;
--	put ("-- suffix         : " & (to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4))); new_line; -- rm V002
	put ("-- prefix         : " & (to_string(skeleton_sub)(to_string(skeleton_sub)'first+9 .. to_string(skeleton_sub)'last-4))); new_line; -- ins V002
	put ("EndSection "); new_line; new_line;
	
	put ("Section netlist_skeleton"); new_line; new_line;
	put ("------MAINMODULE BEGIN-------------------------------------------"); new_line(2);	
	append_file_open("tmp/skeleton_netto.tmp");
	new_line(2);
	put ("------SUBMODULE BEGIN--------------------------------------------"); new_line;
	put ("-- origin         : " & skeleton_sub); new_line(2);
	append_file_open("tmp/skeleton_netto_sub_ext.tmp");
	put ("EndSection"); new_line; new_line;
			
	Close(OutputFile);
	Copy_File( "tmp/skeleton.tmp" , "skeleton.txt" );

end joinnetlist;
