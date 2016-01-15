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
 
--with Ada.Calendar;				use Ada.Calendar;
--with Ada.Calendar.Formatting;	use Ada.Calendar.Formatting;
--with Ada.Calendar.Time_Zones;	use Ada.Calendar.Time_Zones;

with m1;
with m1_internal; use m1_internal;

procedure udbinfo is

	version			: String (1..3) := "001";
	prog_position	: natural := 0;

	inquired_item	: type_item_udbinfo;
	inquired_target	: universal_string_type.bounded_string;

	debug_level 	: natural := 0;

	procedure read_data_base is
	begin
		if read_uut_data_base(
			name_of_data_base_file => universal_string_type.to_string(data_base),
			debug_level => debug_level 
			) then null; 
		end if;
	end read_data_base;


-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	new_line;
	put_line("UUT DATA BASE INFO version "& version);
	put_line("====================================");

 	data_base:= universal_string_type.to_bounded_string(Argument(1));
 	put_line("data base      : " & universal_string_type.to_string(data_base));
 
	action := type_action'value(argument(2));
	put_line("action         : " & type_action'image(action));

	if action = udbinfo then
		read_data_base;

		inquired_item := type_item_udbinfo'value(argument(3));
		put_line("item           : " & type_item_udbinfo'image(inquired_item));

		inquired_target := universal_string_type.to_bounded_string(argument(4));
		put_line("name           : " & universal_string_type.to_string(inquired_target));



		if inquired_item = net then
			print_net_info(universal_string_type.to_string(inquired_target));
		end if;
	end if;
	


		--m1_internal.print_bic_info;

	exception
-- 		when constraint_error => 
-- 			put_line(prog_position);
-- 			if prog_position = "-----" then
-- 				--new_line;									
-- 				--put ("ERROR : Test generator aborted !"); new_line;
-- 				set_exit_status(1);
-- 			end if;
-- 		when others =>
-- 			put_line("program error at position " & prog_position);

		when event: others =>
			put("unexpected exception: ");
			put_line(exception_name(event));
			put(exception_message(event)); new_line;
			put_line("program error at position " & natural'image(prog_position));
			--clean_up;
			--raise;

end udbinfo;
