------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE CHKPSN                              --
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

--with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
--with Ada.Task_Identification;  use Ada.Task_Identification;
with Ada.Exceptions; use Ada.Exceptions;
 
with GNAT.OS_Lib;   	use GNAT.OS_Lib;
with Ada.Command_Line;	use Ada.Command_Line;
with Ada.Directories;	use Ada.Directories;
 
with Ada.Calendar;				use Ada.Calendar;
with Ada.Calendar.Formatting;	use Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;	use Ada.Calendar.Time_Zones;

with m1;
with m1_internal; use m1_internal;

procedure chkpsn is

-- 					if query_render_net_class (
-- 						primary_net_name => to_string(n.name), -- pass name of primary net
-- 						primary_net_class => n.class, -- pass class of primary net (seondary nets inherit class of primary net)
-- 						list_of_secondary_net_names	=> n.list_of_secondary_net_names, -- pass array of seondary net names
-- 						secondary_net_count	=> n.secondary_net_ct -- pass number of secondary nets
-- 						) then 
-- 							null;
-- 					end if;


	version			: String (1..3) := "043";
	prog_position	: string (1..6) := "------";
	line_of_file	: extended_string.bounded_string;
	line_counter	: natural := 0;
	debug_level		: natural := 0;
	summary			: type_udb_summary;
--	Previous_Output	: File_Type renames Current_Output;

	name_of_current_primary_net			: extended_string.bounded_string;
	class_of_current_primary_net		: type_net_class := NA;
	primary_net_section_entered			: boolean := false;
	secondary_net_section_entered 		: boolean := false;	

	procedure read_data_base is
	begin
		summary := read_uut_data_base(
			name_of_data_base_file => universal_string_type.to_string(data_base),
			debug_level => 0
			); --.net_count_statistics.total > 0 then null; 
	end read_data_base;



-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin


	new_line;
	put("primary/secondary/class builder "& version); new_line;

	data_base := universal_string_type.to_bounded_string(Argument(1));
	put_line ("data base      : " & universal_string_type.to_string(data_base));

	options_file := universal_string_type.to_bounded_string(Argument(2));
	put_line ("options file   : " & universal_string_type.to_string(options_file));

	if argument_count = 3 then
		debug_level := natural'value(argument(3));
		put_line ("debug level    :" & natural'image(debug_level));
	end if;

	-- make backup of given udb
	
	-- recreate an empty tmp directory
	m1.clean_up_tmp_dir;

	read_data_base;
	


	-- open input_file
	Open( 
		File => opt_file,
		Mode => in_file,
		Name => universal_string_type.to_string(options_file)
		);


-- Section /OSC_HALT class PU   -- single bs-net
--    --   IC103 ? 74LS00 DIL14 2 
--    --   IC301 ? XC9536 PLCC-S44 26  pb01_15 | 8 bc_1 input x | 7 bc_1 output3 x 6 0 z
--    --   JP403 ? MON2 2X20 16 
--    --   RN300 ? 8x1k8 SIL9 6 
-- EndSection


-- Section LED0 class NR
--    --   D401 ? none LED5MM K 
--    --   IC303 ? SN74BCT8240ADWR SOIC24 10  y2(4) | 0 bc_1 output3 x 16 1 z
--    --   JP402 ? MON1 2X20 24 
--    --   RN302 ? 2k7 SIL8 1 
--  SubSection secondary_nets
--   Net LED0_R
--    --   IC301 ? XC9536 PLCC-S44 2  pb00_00 | 107 bc_1 input x | 106 bc_1 output3 x 105 0 z
--    --   JP402 ? MON1 2X20 26 
--    --   RN302 ? 2k7 SIL8 2 
--  EndSubSection
-- EndSection


	-- find primary net in options file	
	Set_Input(opt_file); -- set data source
	while not end_of_file
		loop
			prog_position := "RD0000";
			line_counter := line_counter + 1;
			line_of_file := extended_string.to_bounded_string(get_line);
			line_of_file := remove_comment_from_line(line_of_file);

			if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything
				if debug_level >= 10 then
--					put_line("line read : ->" & to_string(line_of_file) & "<-");
					put_line(extended_string.to_string(line_of_file));
				end if;

				if primary_net_section_entered then

					-- clear primary net section entered flag on passing "EndSection"
					if to_upper(get_field_from_line(line_of_file,1)) = type_end_of_section_mark'image(EndSection) then
						primary_net_section_entered := false;
					end if;

					--if not secondary_net_section_entered
					-- inside a primary net section, wait for "SubSection secondary_nets"
					-- if "SubSection secondary_nets" found, set secondary_net_section_entered flag
					if to_upper(get_field_from_line(line_of_file,1)) = type_start_of_subsection_mark'image(SubSection) then
						if to_upper(get_field_from_line(line_of_file,2)) = type_secondary_net_identifier'image(secondary_nets) then
							secondary_net_section_entered := true;
						--secondary_net_count := secondary_net_count + 1;
						end if;
					end if;


				-- if primary net section not entered, wait for primary net header, then set primary net section entered flag
				elsif to_upper(get_field_from_line(line_of_file,1)) = type_start_of_section_mark'image(Section) then
					name_of_current_primary_net := extended_string.to_bounded_string(get_field_from_line(line_of_file,2));
					if to_upper(get_field_from_line(line_of_file,3)) = type_options_file_class_identifier'image(class) then
						null; -- fine
					else
						put_line("ERROR: Identifier '" & type_options_file_class_identifier'image(class) & "' expected after primary net name !");
						raise constraint_error;
					end if;
					class_of_current_primary_net := type_net_class'value(get_field_from_line(line_of_file,4));
					primary_net_section_entered := true;
				end if;

			end if;

			
		end loop;

	set_input(standard_input);
	close(opt_file);

	exception
		when others =>
--			put_line("ERROR in data base in line :" & natural'image(line_counter));
--			put_line("affected line reads        : " & trim(to_string(line_of_file),both));
			put_line("ERROR at program position  : " & prog_position);

end chkpsn;
