------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE USB_TEST                            --
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


with ada.text_io;				use ada.text_io;
--with ada.text_io.Integer_IO;

with ada.direct_io;				
with ada.characters.handling; 	use ada.characters.handling;
with ada.strings; 				use ada.strings;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.unbounded.text_io; use ada.strings.unbounded.text_io;
with interfaces;				use interfaces;
with ada.exceptions; 			use ada.exceptions;

 
with gnat.os_lib;   			use gnat.os_lib;
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;
with ada.environment_variables;

--with m1_sercom; 				--use m1_sercom;
with gnat.serial_communications;

with m1_internal; 				use m1_internal;
with m1_numbers;				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;
with m1_firmware;				use m1_firmware;

procedure usb_test is
	version			: constant string (1..3) := "000";
--	result			: integer;


-- 	type test_record is
-- 		record
-- 			byte_test		: unsigned_8;
-- 		end record;
-- 	a : test_record;
-- 
-- 	package direct_io is new ada.direct_io(test_record);
-- 	file_test 		: direct_io.file_type;
	
	
--	file_test 		: seq_io_unsigned_byte.file_type;
	byte_test		: unsigned_8 := 16#C0#;
	--	byte_test		: integer := 1;	

	package Int_IO is new Ada.Text_IO.Integer_IO (Integer);
	
	p : gnat.serial_communications.serial_port;
	
	flow : gnat.serial_communications.flow_control := gnat.serial_communications.rts_cts;
--	buffer : ada.streams.stream_element_array(1..1);

	function String_To_Stream ( The_String : in String) return
		Ada.Streams.Stream_Element_Array is
		Return_Value : Ada.Streams.Stream_Element_Array(1..The_String'length);
	begin
--      Put (" Start of Data out  :- ");
		for count in 1..Ada.Streams.Stream_Element_Offset(The_String'Length) loop
			put_line(Ada.Streams.Stream_Element_Offset'image(count));
			Return_Value(count) := character'pos(The_String(Integer(count)));
			int_io.Put(Integer(Return_Value(count)));
		end loop;
--      Put (" End of Data out ");
--      Put_Line (The_String);
      Return Return_Value(1..The_String'Length);
   end String_To_Stream;
   
begin

	check_environment;

	put_line(universal_string_type.to_string(interface_to_bsc));

 	gnat.serial_communications.open(
 		port	=> p,
		name	=> "/dev/ttyUSB0" -- universal_string_type.to_string(interface_to_bsc)
		);

	flow := gnat.serial_communications.none;
--	flow := gnat.serial_communications.Xon_Xoff;
--	flow := gnat.serial_communications.RTS_CTS;	
	
	gnat.serial_communications.set(
--		rate	=> gnat.serial_communications.B9600,
		rate	=> gnat.serial_communications.B19200,
 		port	=> p,
		flow	=> flow
		);

	

--	character'write(buffer(1),'S');

	gnat.serial_communications.write(
 		port	=> p,
		buffer	=> String_To_Stream(" ")
		);


 	gnat.serial_communications.close(
 		port	=> p
		);

	
------------------------------
-- 	-- write
-- 	seq_io_unsigned_byte.open(
-- 		file	=> file_test, 
-- 		mode	=> seq_io_unsigned_byte.out_file, 
-- 		name 	=> universal_string_type.to_string(interface_to_bsc)
-- 		);
-- 
-- 	seq_io_unsigned_byte.write(file_test,byte_test);
-- 
-- 	byte_test := 16#A0#;
-- 	seq_io_unsigned_byte.write(file_test,byte_test);
-- 	seq_io_unsigned_byte.close(file_test);
-- 
-- 
-- 	-- read
-- 	seq_io_unsigned_byte.open(
-- 		file	=> file_test, 
-- 		mode	=> seq_io_unsigned_byte.in_file, 
-- 		name 	=> universal_string_type.to_string(interface_to_bsc)
-- 		);
-- 	put_line("open");
-- 	while not end_of_file loop
-- 		seq_io_unsigned_byte.read(file_test,byte_test);
-- 		put_line("read");
-- 	end loop;
-- 
-- 	put_line("read2");	
-- 	seq_io_unsigned_byte.close(file_test);
-- 	put_line("close");
------------------------------
-- 	a.byte_test := 16#C0#;
-- 	
-- 	direct_io.open(
-- 		file	=> file_test, 
-- 		mode	=> direct_io.inout_file, 
-- 		name 	=> universal_string_type.to_string(interface_to_bsc)
-- 		);
-- 	if direct_io.is_open(file_test) then
-- 		put_line("open");
-- 	else
-- 		put_line("not open");
-- 	end if;
-- 		
-- 	direct_io.set_index(file_test,1);
-- 	put_line("index set");	
-- 	
-- 	a.byte_test := 16#C0#;
--	direct_io.write(file_test,a);
--	put_line("1st byte set");		
	
--	a.byte_test := 16#A0#;
--	direct_io.write(file_test,a);


--  	direct_io.read(file_test,a);
-- 
-- 
-- 	direct_io.close(file_test);
	
-- 	spawn 
-- 		(  
-- 		program_name           => compose( universal_string_type.to_string(name_directory_bin), name_module_cad_importer_orcad),
-- 		args                   => 	(
-- 									1=> new string'(universal_string_type.to_string(name_file_cad_net_list))
-- 									),
-- 		output_file_descriptor => standout,
-- 		return_code            => result
-- 		);
-- 
-- 	if result = 0 then
-- 		null;
-- 	else
-- 		null;
-- 	end if;



-- 	exception
-- 		when event: 
-- 			others =>
-- 				set_exit_status(failure);
-- 				set_output(standard_output);

end usb_test;
