------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKMEMCON                            --
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


with Ada.Text_IO;				use Ada.Text_IO;
with Ada.Integer_Text_IO;		use Ada.Integer_Text_IO;
with Ada.Characters.Handling; 	use Ada.Characters.Handling;

with Ada.Strings.Bounded; 		use Ada.Strings.Bounded;
with Ada.Exceptions; 			use Ada.Exceptions;
 
with Ada.Command_Line;			use Ada.Command_Line;
with Ada.Directories;			use Ada.Directories;

with m1;
with m1_internal; use m1_internal;



procedure mkmemcon is

	version			: String (1..3) := "032";
	prog_position	: natural := 0;
	type type_algorithm is ( standard );
	algorithm 		: type_algorithm;
	line_counter 	: natural := 0; -- counts lines in model file

	type type_info_item is
		record
			value			: string (1..5)  := "value";
			compatibles		: string (1..11) := "compatibles";
			date			: string (1..4)  := "date";
			version			: string (1..7)  := "version";
			status			: string (1..6)  := "status";
			author			: string (1..6)  := "author";
			manufacturer	: string (1..12) := "manufacturer";
			class			: string (1..5)  := "class";
			write_protect	: string (1..13) := "write_protect";
			protocol		: string (1..8)  := "protocol";
			ram_type		: string (1..8)  := "ram_type";
			rom_type		: string (1..8)  := "rom_type";
		end record;
	info_item : type_info_item;

	type type_model_status is ( experimental, verified );
	type type_target_class is ( UNKNOWN, ROM, RAM, CLUSTER );
	type type_type_ram is ( UNKNOWN, SRAM, SDRAM, DRAM, DDR, DDR2 );
	type type_type_rom is ( UNKNOWN, MAP, OTP, FLASH );
	type type_protocol is ( UNKNOWN, PARALLEL, I2C, SPI );
	type type_write_protect	is new boolean;

	--type type_target (class : type_target_class := ram) is
	type type_target;
	type type_ptr_target is access all type_target;
	type type_target (class : type_target_class := ram) is
		record
			date			: universal_string_type.bounded_string;
			author			: universal_string_type.bounded_string;
			status			: type_model_status;
			version			: universal_string_type.bounded_string;
			case class is
				when RAM | ROM =>
					value			: universal_string_type.bounded_string;
					compatibles		: universal_string_type.bounded_string;
					manufacturer	: universal_string_type.bounded_string;
					protocol 		: type_protocol;
					write_protect	: type_write_protect;
					case class is
						when RAM => 
							ram_type		: type_type_ram;
						when ROM =>
							rom_type		: type_type_rom;
						when others => null;
					end case;
				when CLUSTER =>
					null;
				when others =>
					null;
			end case;
		end record;
	ptr_target : type_ptr_target;

	-- type definition of a single pin
	-- The object of type type_pin will be added to a list later
	-- and accessed by pointer ptr_pin.
	type type_pin;
	type type_ptr_pin is access all type_pin;
	type type_pin_class is ( data, address, control);
	type type_direction is ( input, output, inout, bidir);
	type type_pin (class : type_pin_class) is
		record
			next			: type_ptr_pin;
			name_pin		: universal_string_type.bounded_string; -- like pin 75, 34, 4
			name_port		: universal_string_type.bounded_string; -- like port A13, SDA, D15
			direction		: type_direction;
			-- indexing is required for address or data ports only
			case class is
				when data | address =>
					index		: natural; -- like address 0, data 7
				when others => -- like CE, WE
					null;
			end case;
		end record;

	-- vector inout D[7:0] 19 18 17 16 15 13 12 11
	-- vector input A[14:0] 1 26 2 23 21 24 25 3 4 5 6 7 8 9 10
-- 	type type_bus (width : positive) is
-- 		record
-- 			name				: universal_string_type.bounded_string;
-- 			ptr_pin_list		: type_ptr_pin;
-- 		end record;

	procedure add_to_pin_list(
		list				: in out type_ptr_pin;
		class_given			: in type_pin_class;
		name_pin_given		: in universal_string_type.bounded_string;
		name_port_given		: in universal_string_type.bounded_string;
		direction_given		: in type_direction;
		index_given			: in natural := 0 -- default in case it is don't care
		) is
	begin
		-- CS: check if pin already in list
		case class_given is
			when data =>
				list := new type_pin'(
					next		=> list,
					class		=> data,
					name_pin	=> name_pin_given,
					name_port	=> name_port_given,
					direction	=> direction_given,
					index		=> index_given
					);
			when address =>
				list := new type_pin'(
					next		=> list,
					class		=> address,
					name_pin	=> name_pin_given,
					name_port	=> name_port_given,
					direction	=> direction_given,
					index		=> index_given
					);
			when others =>
				list := new type_pin'(
					next		=> list,
					class		=> control,
					name_pin	=> name_pin_given,
					name_port	=> name_port_given,
					direction	=> direction_given
					);
		end case;
	end add_to_pin_list;


	procedure print_info is
	begin
		put_line("target properties:");
		put_line("class         : " & type_target_class'image(ptr_target.class));
		case ptr_target.class is 
			when RAM => put_line("ram_type      : " & type_type_ram'image(ptr_target.ram_type));
			when ROM => put_line("rom_type      : " & type_type_rom'image(ptr_target.rom_type));
			when others => null;
		end case;
		case ptr_target.class is 
			when RAM | ROM =>
				put_line("value         : " & universal_string_type.to_string(ptr_target.value));
				put_line("compatibles   : " & universal_string_type.to_string(ptr_target.compatibles));
				put_line("manufacturer  : " & universal_string_type.to_string(ptr_target.manufacturer));
				put_line("protocol      : " & type_protocol'image(ptr_target.protocol));
				put_line("write_protect : " & type_write_protect'image(ptr_target.write_protect));
			when others => null;
		end case;
		put_line("date          : " & universal_string_type.to_string(ptr_target.date));
		put_line("author        : " & universal_string_type.to_string(ptr_target.author));
		put_line("status        : " & type_model_status'image(ptr_target.status));
		put_line("version       : " & universal_string_type.to_string(ptr_target.version));
	end print_info;


	procedure read_memory_model is
		line_of_file	: extended_string.bounded_string;
		ptr_pin			: type_ptr_pin;

		section_info_entered	:	boolean := false;

		scratch_value			: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_compatibles		: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_manufacturer	: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_date			: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_version			: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_status			: type_model_status := experimental;
		scratch_author			: universal_string_type.bounded_string := universal_string_type.to_bounded_string("unknown");
		scratch_protocol 		: type_protocol := unknown;
		scratch_write_protect	: type_write_protect := true; -- safety measure
		scratch_class			: type_target_class := unknown;
		scratch_ram_type		: type_type_ram := unknown;
		scratch_rom_type		: type_type_rom := unknown;

	begin
		put_line("reading memory model file ...");
		open(
			file => model, 
			name => universal_string_type.to_string(model_file),
			mode => in_file
			);
		set_input(model);
		while not end_of_file loop
			line_counter := line_counter + 1;
			line_of_file := extended_string.to_bounded_string(get_line);
			line_of_file := remove_comment_from_line(line_of_file);

			if get_field_count(extended_string.to_string(line_of_file)) > 0 then -- if line contains anything
				if debug_level >= 110 then
					put_line("line read : ->" & extended_string.to_string(line_of_file) & "<-");
				end if;

				if section_info_entered then
					if get_field_from_line(line_of_file,1) = section_mark.endsection then
						section_info_entered := false;

						-- section info reading done. now check for missing parameters in that section
						-- then create object "target"
						if scratch_protocol = unknown then
							put_line("ERROR: Protocol not specified in section info !");
							raise constraint_error;
						end if;

						prog_position := 1000;
						case scratch_class is
							when ROM =>
								if scratch_write_protect = false then -- by default this options is enabled (true)
									prog_position := 1010; -- otherwise warn operator
									put_line("WARNING: WRITE PROTECTION DISABLED !");
								end if;
								if scratch_rom_type = unknown then
									prog_position := 1020;
									put_line("ERROR: ROM type not specified in section info !");
									raise constraint_error;
								end if;
							when RAM =>
								if scratch_ram_type = unknown then
									prog_position := 1030;
									put_line("ERROR: RAM type not specified in section info !");
									raise constraint_error;
								end if;
							when CLUSTER => null;
							when UNKNOWN =>
								prog_position := 1040;
								put_line("ERROR: Target class not specified in section info !");
						end case;

						-- create target object pointed to by ptr_target
						-- the object subtype depends on discriminant "class"
						prog_position := 1200;
						case scratch_class is
							when RAM =>
								prog_position := 1210;
								ptr_target := new type_target'(
									class			=> RAM,
									value			=> scratch_value,
									compatibles		=> scratch_compatibles,
									manufacturer	=> scratch_manufacturer,
									date			=> scratch_date,
									version			=> scratch_version,
									status			=> scratch_status,
									author			=> scratch_author,
									protocol		=> scratch_protocol,
									write_protect	=> scratch_write_protect,
									ram_type		=> scratch_ram_type
									);
							when ROM =>
								prog_position := 1220;
								ptr_target := new type_target'(
									class			=> ROM,
									value			=> scratch_value,
									compatibles		=> scratch_compatibles,
									manufacturer	=> scratch_manufacturer,
									date			=> scratch_date,
									version			=> scratch_version,
									status			=> scratch_status,
									author			=> scratch_author,
									protocol		=> scratch_protocol,
									write_protect	=> scratch_write_protect,
									rom_type		=> scratch_rom_type
									);
							when CLUSTER =>
								prog_position := 1230;
								ptr_target := new type_target'(
									class			=> CLUSTER,
									date			=> scratch_date,
									version			=> scratch_version,
									status			=> scratch_status,
									author			=> scratch_author
									);
							when others =>
								prog_position := 1240;
								put_line("ERROR: Target class not specified in section info !");
								raise constraint_error;
						end case;

						print_info;

					else
						-- process info section:
						-- collect all info items in scratch variables
						-- scratch variables will be used to create an object of type type_targt pointed to by ptr_target
						if debug_level >= 100 then
							put_line("info : ->" & extended_string.to_string(line_of_file) & "<-");
						end if;

						prog_position := 1310;
						if get_field_from_line(line_of_file,1) = info_item.value then
							scratch_value := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1320;
						if get_field_from_line(line_of_file,1) = info_item.compatibles then
							scratch_compatibles := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1330;
						if get_field_from_line(line_of_file,1) = info_item.date then
							scratch_date := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1340;
						if get_field_from_line(line_of_file,1) = info_item.version then
							scratch_version := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1350;
						if get_field_from_line(line_of_file,1) = info_item.status then
							scratch_status := type_model_status'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1360;
						if get_field_from_line(line_of_file,1) = info_item.author then
							scratch_author := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1370;
						if get_field_from_line(line_of_file,1) = info_item.class then
							scratch_class := type_target_class'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1380;
						if get_field_from_line(line_of_file,1) = info_item.manufacturer then
							scratch_manufacturer := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1390;
						if get_field_from_line(line_of_file,1) = info_item.write_protect then
							scratch_write_protect := type_write_protect'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1400;
						if get_field_from_line(line_of_file,1) = info_item.protocol then
							scratch_protocol :=type_protocol'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1410;
						if get_field_from_line(line_of_file,1) = info_item.ram_type then
							scratch_ram_type := type_type_ram'value(get_field_from_line(line_of_file,2));
						end if;

						prog_position := 1420;
						if get_field_from_line(line_of_file,1) = info_item.rom_type then
							scratch_rom_type := type_type_rom'value(get_field_from_line(line_of_file,2));
						end if;

					end if;

				else
					if get_field_from_line(line_of_file,1) = section_mark.section then
						if get_field_from_line(line_of_file,2) = "info" then
							section_info_entered := true;
						end if;
					end if;
				end if;

			end if; -- if line contains anything


-- add_to_pin_list(
-- 		list				=> ptr_pin,
-- 		class_given			=> data,
-- 		name_pin_given		=> universal_string_type.to_bounded_string("x"),
-- 		name_port_given		=> universal_string_type.to_bounded_string("x"),
-- 		direction_given		=> bidir,
-- 		index_given			=> 0
-- 		);


		end loop;
	end read_memory_model;



	procedure write_info_section is
	begin
		-- create sequence file
		create( sequence_file, 
			name => (compose (universal_string_type.to_string(test_name), universal_string_type.to_string(test_name), "seq")));
		set_output(sequence_file); -- set data sink

		put_line("Section info");
		put_line(" created by memory connections test generator version "& version);
		put_line(" date          : " & m1.date_now);
		put_line(" database      : " & m1_internal.universal_string_type.to_string(m1_internal.data_base));
		put_line(" algorithm     : " & type_algorithm'image(standard));
		put_line(" target_device : " & m1_internal.universal_string_type.to_string(m1_internal.target_device));
		put_line(" model_file    : " & universal_string_type.to_string(model_file));
		put_line(" device_package: " & m1_internal.universal_string_type.to_string(m1_internal.device_package));
		put_line("EndSection"); 
		new_line;
	end write_info_section;



-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	put_line("memory interconnect test generator version "& Version);
	put_line("==============================================");

	prog_position	:= 10;
 	m1_internal.data_base:= m1_internal.universal_string_type.to_bounded_string(Argument(1));
 	put_line ("data base      : " & m1_internal.universal_string_type.to_string(m1_internal.data_base));
 
	prog_position	:= 20;
 	m1_internal.test_name:= m1_internal.universal_string_type.to_bounded_string(Argument(2));
 	put_line ("test name      : " & m1_internal.universal_string_type.to_string(m1_internal.test_name));
 
	prog_position	:= 30;
 	m1_internal.target_device := m1_internal.universal_string_type.to_bounded_string(Argument(3));
 	put_line ("target device  : " & m1_internal.universal_string_type.to_string(m1_internal.target_device));
 
	prog_position	:= 40;
 	m1_internal.model_file := m1_internal.universal_string_type.to_bounded_string(Argument(4));
 	put_line ("model file     : " & m1_internal.universal_string_type.to_string(m1_internal.model_file));
 
	prog_position	:= 50;
 	m1_internal.device_package := m1_internal.universal_string_type.to_bounded_string(Argument(5));
 	put_line ("device package : " & m1_internal.universal_string_type.to_string(m1_internal.device_package));
 
	prog_position	:= 55;
	if argument_count = 6 then
		m1_internal.debug_level := natural'value(argument(6));
		put_line("debug level    :" & natural'image(debug_level));
	end if;

	-- CS: get algorithm as argument
	-- for the time being it is fixed
	algorithm := standard;

	prog_position	:= 60;
	read_data_base;
	prog_position	:= 65;
	read_memory_model;

	prog_position	:= 70;
 	create_temp_directory;

	-- create test directory
	prog_position	:= 80;
	create_test_directory(
		test_name 			=> universal_string_type.to_string(test_name),
		warnings_enabled 	=> false
		);

	prog_position	:= 90; 
	write_info_section;
	prog_position	:= 100;
	write_test_section_options;

	prog_position	:= 110;
	write_test_init;

	prog_position	:= 120;
	
	--write_sequences;

	prog_position	:= 130;
	set_output(standard_output);

	prog_position	:= 140;
	close(sequence_file);


	exception
		when event: others =>
			case prog_position is
				when 10 =>
					put_line("ERROR: Data base file missing or insufficient access rights !");
					put_line("       Provide data base name as argument. Example: mkmemcon my_uut.udb");
				when 20 =>
					put_line("ERROR: Test name missing !");
					put_line("       Provide test name as argument ! Example: mkmemcon my_uut.udb my_memory_test");
				when 30 =>
					put_line("ERROR: Target device missing !");
					put_line("       Provide target device as argument ! Example: mkmemcon my_uut.udb my_memory_test IC22");
				when 40 =>
					put_line("ERROR: Device model missing !");
					put_line("       Provide device model as argument ! Example: mkmemcon my_uut.udb my_memory_test IC22 models/sdram.txt");
				when 50 =>
					put_line("ERROR: Device package missing !");
					put_line("       Provide device package as argument ! Example: mkmemcon my_uut.udb my_memory_test IC22 models/sdram.txt SOP24");
				when 55 =>
					put_line("ERROR: Invalid argument for debug level. Debug level must be provided as natural number !");


				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & natural'image(prog_position));
			end case;

end mkmemcon;
