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

with m1;
with m1_internal;

procedure mkmemcon is

	version			: String (1..3) := "032";
	prog_position	: String (1..5) := "-----";
	now				: time := clock;
	date_now		: string (1..19) := image(now, time_zone => UTC_Time_Offset(now));

	universal_string_length	: natural := 100;
	package universal_string_type is new generic_bounded_length(universal_string_length); use universal_string_type;
	test_name  		: universal_string_type.bounded_string;
	data_base  		: universal_string_type.bounded_string;
	target_device	: universal_string_type.bounded_string;
	model_file		: universal_string_type.bounded_string;
	device_package	: universal_string_type.bounded_string;

	seq_file		: ada.text_io.file_type;

	procedure write_info_section is
	begin
		put_line("Section info");
		put_line(" created by memory connections test generator version "& version);
		put_line(" date          : " & date_now);
		put_line(" database      : " & to_string(data_base));
		put_line(" algorithm     : standard");
		put_line(" target_device : " & to_string(target_device));
		put_line(" model_file    : " & to_string(model_file));
		put_line(" device_package: " & to_string(device_package));
		put_line("EndSection"); 
		new_line;
	end write_info_section;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	prog_position := "IN000";
	put("memory interconnect test generator version "& Version); new_line;

	data_base:= to_bounded_string(Argument(1));
	put_line ("data base      : " & to_string(data_base));

	test_name:= to_bounded_string(Argument(2));
	put_line ("test name      : " & to_string(test_name));

	target_device := to_bounded_string(Argument(3));
	put_line ("target device  : " & to_string(target_device));

	model_file := to_bounded_string(Argument(4));
	put_line ("model file     : " & to_string(model_file));

	device_package := to_bounded_string(Argument(5));
	put_line ("device package : " & to_string(device_package));

	-- recreate an empty tmp directory
	prog_position := "TMP01";
	m1.clean_up_tmp_dir;
	
	prog_position := "DIR01";
	m1_internal.create_test_directory(to_string(test_name));

	prog_position := "OSE01";
	create(seq_file, name => compose(to_string(test_name),to_string(test_name),"seq") );
	--prog_position := "OSE02";
	--open(file => seq_file, mode => out_file, name => compose(to_string(test_name),to_string(test_name),"seq") );
	prog_position := "OSE03";
	set_output(seq_file);
	prog_position := "OSE04";
	write_info_section;



	close(seq_file);
-- 
-- 	fraction_data_base;
-- 
-- 	write_options_section; --  appends options to testname/testname.seq
-- 
-- 
-- 	append_file ("setup/test_init_custom.txt", (compose (to_string(test_name),to_string(test_name), "seq")));
-- 
-- 
-- 	-- count and identify chain members
-- 	count_members := (count_chain_members("tmp/members.tmp"));
-- 
-- 	--put (count_members); new_line;
-- 
-- 	-- preset vector counter
-- 	vector_ct := 0;
-- 
-- 	-- safebit preloading
-- 	
-- 	-- write instructions in seq. file
-- 	
-- 	write_safebits_preload ( count_members, identify_chain_members(count_members) ); -- sets all members to sample/preload/extest
-- 	write_capture_ir_values ( count_members, identify_chain_members(count_members) );
-- 	vector_ct := write_sxr(vector_ct,1); -- 0 -> sdr , 1 -> s1r
-- 
-- 	write_safebits_data ( count_members, identify_chain_members(count_members) ); -- loads safebits in bsr of all members
-- 	vector_ct := write_sxr(vector_ct,0); -- 0 -> sdr , 1 -> s1r
-- 
-- 	write_all_extest ( count_members, identify_chain_members(count_members) ); -- sets all members to extest
-- 	vector_ct := write_sxr(vector_ct,1); -- 0 -> sdr , 1 -> s1r
-- 
-- 	write_static_drive_values ( count_members, identify_chain_members(count_members) );
-- 	vector_ct := write_sxr(vector_ct,0); -- 0 -> sdr , 1 -> sir
-- 
-- 	write_static_expect_values ( count_members, identify_chain_members(count_members) );
-- 	vector_ct := write_sxr(vector_ct,0); -- 0 -> sdr , 1 -> sir
-- 
-- 	-- ATG interconnect test
-- 	atg_mkintercon(count_members, identify_chain_members(count_members),vector_ct);




--	vector_ct := write_sxr(vector_ct,0); -- 0 -> sdr , 1 -> sir

	exception
		when constraint_error => 
			put_line(prog_position);
			if prog_position = "-----" then
				--new_line;									
				--put ("ERROR : Test generator aborted !"); new_line;
				set_exit_status(1);
			end if;
		when others =>
			put_line("program error at position " & prog_position);
end mkmemcon;
