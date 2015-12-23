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
with m1_internal; --use m1_internal;

procedure mkmemcon is

	version			: String (1..3) := "032";
	prog_position	: String (1..5) := "-----";

--	bic : m1_internal.bscan_ic_ptr;
	--bic_boundary_register	: m1_internal.type_bic_boundary_register_array;
	--m : m1_internal.bscan_ic_ptr;
	--n : m1_internal.net_ptr;
	--subtype parts_of_net_local is m1_internal.type_parts_of_net (1..2);
	--p : parts_of_net_local;
--	n := new
	--type hexnumber is array(1..4) of m1_internal.type_bit_character_class_1;
	--five : array (1..2) of m1_internal.type_bit_character_class_1 := "01";

	--package char_io is new Ada.Text_IO.Enumeration_IO(Character);

	procedure write_info_section is
	begin
		put_line("Section info");
		put_line(" created by memory connections test generator version "& version);
		put_line(" date          : " & m1.date_now);
		put_line(" database      : " & m1_internal.universal_string_type.to_string(m1_internal.data_base));
		put_line(" algorithm     : standard");
		put_line(" target_device : " & m1_internal.universal_string_type.to_string(m1_internal.target_device));
		put_line(" model_file    : " & m1_internal.universal_string_type.to_string(m1_internal.model_file));
		put_line(" device_package: " & m1_internal.universal_string_type.to_string(m1_internal.device_package));
		put_line("EndSection"); 
		new_line;
	end write_info_section;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	prog_position := "IN000";
	put_line("memory interconnect test generator version "& Version);

 	m1_internal.data_base:= m1_internal.universal_string_type.to_bounded_string(Argument(1));
 	put_line ("data base      : " & m1_internal.universal_string_type.to_string(m1_internal.data_base));
 
 	m1_internal.test_name:= m1_internal.universal_string_type.to_bounded_string(Argument(2));
 	put_line ("test name      : " & m1_internal.universal_string_type.to_string(m1_internal.test_name));
 
 	m1_internal.target_device := m1_internal.universal_string_type.to_bounded_string(Argument(3));
 	put_line ("target device  : " & m1_internal.universal_string_type.to_string(m1_internal.target_device));
 
 	m1_internal.model_file := m1_internal.universal_string_type.to_bounded_string(Argument(4));
 	put_line ("model file     : " & m1_internal.universal_string_type.to_string(m1_internal.model_file));
 
 	m1_internal.device_package := m1_internal.universal_string_type.to_bounded_string(Argument(5));
 	put_line ("device package : " & m1_internal.universal_string_type.to_string(m1_internal.device_package));
 
	m1_internal.debug_level := natural'value(argument(6));

	-- recreate an empty tmp directory
 	prog_position := "TMP01";
 	m1.clean_up_tmp_dir;

	-- create test directory
	prog_position := "DIR01";
 	m1_internal.create_test_directory(m1_internal.universal_string_type.to_string(m1_internal.test_name));
 
 	prog_position := "OSE01";
 	create(m1_internal.seq_file, 
		name => compose(m1_internal.universal_string_type.to_string(m1_internal.test_name),m1_internal.universal_string_type.to_string(m1_internal.test_name),"seq"));
	close(m1_internal.seq_file);
	prog_position := "OSE02";
	open(file => m1_internal.seq_file, mode => out_file,
		name => compose(m1_internal.universal_string_type.to_string(m1_internal.test_name),m1_internal.universal_string_type.to_string(m1_internal.test_name),"seq"));
 	prog_position := "OSE03";
 	set_output(m1_internal.seq_file);
 	prog_position := "OSE04";
 	write_info_section;

 	set_output(standard_output);

	if m1_internal.read_uut_data_base(
			name_of_data_base_file => m1_internal.universal_string_type.to_string(m1_internal.data_base),
			debug_level => m1_internal.debug_level
			) then 
				null; 
		--put_line(m1_internal.universal_string_type(m1_internal.bic.name));
-- 		put_line("--");
-- 		put_line(natural'image(m1_internal.bic.position));
-- 		m1_internal.bic := m1_internal.bic.next;
-- 		put_line(natural'image(m1_internal.bic.position));
-- 		m1_internal.bic := m1_internal.bic.next;
-- 		put_line(natural'image(m1_internal.bic.position));


	end if;
		m1_internal.print_bic_info;

-- 		put_line("ir  length:" & natural'image(m1_internal.bic.len_ir));
-- 		put_line("bsr length:" & natural'image(m1_internal.bic.len_bsr));
--  		m1_internal.bic := m1_internal.bic.next;
-- 		put_line("ir  length:" & natural'image(m1_internal.bic.len_ir));
-- 		put_line("bsr length:" & natural'image(m1_internal.bic.len_bsr));

-- 		put_line("ir length:" & natural'image(m1_internal.bic.len_ir));
-- 		put_line("net  " & m1_internal.universal_string_type.to_string(m1_internal.n.name));
-- 		put_line("part " & m1_internal.universal_string_type.to_string(m1_internal.n.parts(2)));
--	end if;

	--put_line("capture ir :" & m1_internal.type_string_of_characters_class_1'image(m.capture_ir));
	--put_line("ir length:" & natural'image(m(1,1).len_ir));
	
	--put("capt_ir  :" & m(1,1).capture_ir'first);
--	put_line( five(1..2) );
	--put(m1_internal.type_string_of_characters_class_1'image(m1_internal.type_string_of_characters_class_1'val(1))); new_line;

	close(m1_internal.seq_file);
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
			put_line("program error at position " & prog_position);
			--clean_up;
			--raise;

end mkmemcon;
