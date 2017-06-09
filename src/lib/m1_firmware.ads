-- ------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 FIRMWARE DECLARATIONS                      --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               S p e c                                    --
--                                                                          --
--         Copyright (C) 2017 Mario Blunk, Blunk electronic                 --
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
--   info@blunk-electronic.de
--   or visit <http://www.blunk-electronic.de> for more contact data
--
--   history of changes:
--

with interfaces;					use interfaces;
with m1_numbers; 					use m1_numbers;
with gnat.serial_communications;	use gnat.serial_communications;

package m1_firmware is
	-- When bsmcl reads the system configuration, the firmware is verified against this constant.
	-- If an older version is found, the flag scan_master_present is set false. 
	-- This disables all actions that require a BSC !!!
	bsc_firmware_executor_min			: constant unsigned_16 := 16#0013#;
	
	type type_tck_frequency is new float range 0.0000001..12.0; -- unit is MHz
	tck_frequency_default : constant type_tck_frequency := 0.05;

	type type_voltage is delta 0.1 digits 2;
	type type_voltage_out is new type_voltage range 1.8 .. 3.3;
	type type_threshold_tdi is new type_voltage range 0.1 .. 3.3;
	threshold_tdi_default : constant type_threshold_tdi := 0.8;
	type type_driver_characteristic is (push_pull , weak0, weak1, tie_high, tie_low, highz);

	-- The scanport output voltage can assume discrete values 1.8V, 2.5V or 3.3V. Other values are not accepted.
	type type_voltage_out_discrete is ( V1_8 , V2_5 , V3_3);
	function is_voltage_out_discrete (voltage : type_voltage_out) return boolean;
	-- Returns true if given voltage is member of type_voltage_out_discrete.

	executor_master_clock	: constant positive := 50; -- MHz

	scanport_count_max 		: constant positive := 2; -- CS: currently max 2 ports supported

	mem_size				: constant positive := integer'value("16#07FFFF#"); -- BSC RAM size -- CS: rework
	subtype type_mem_address_byte is natural range 0..mem_size;
	subtype type_mem_address_page is natural range 0..mem_size/256;
	page_address_width_bits		: constant positive := 16; 
	page_address_width_bytes	: constant positive := 4;

	mem_address			: type_mem_address_byte;
	mem_address_page 	: type_mem_address_page;

	id_configuration		: unsigned_16	:= 16#0000#;
	mark_end_of_test		: unsigned_8	:= 16#77#;

	drive_characteristic_tck_push_pull	: unsigned_8	:= 16#06#;
	drive_characteristic_tck_weak1		: unsigned_8	:= 16#01#;
	drive_characteristic_tck_weak0		: unsigned_8	:= 16#02#;
	drive_characteristic_tck_tie_low	: unsigned_8	:= 16#04#;
	drive_characteristic_tck_tie_high	: unsigned_8	:= 16#05#;
	drive_characteristic_tck_highz		: unsigned_8	:= 16#03#;

	drive_characteristic_tms_push_pull	: unsigned_8	:= 16#30#;
	drive_characteristic_tms_weak1		: unsigned_8	:= 16#08#;
	drive_characteristic_tms_weak0		: unsigned_8	:= 16#10#;
	drive_characteristic_tms_tie_low	: unsigned_8	:= 16#20#;
	drive_characteristic_tms_tie_high	: unsigned_8	:= 16#28#;
	drive_characteristic_tms_highz		: unsigned_8	:= 16#18#;

	-- indicates a basic i2c operation
-- 	llc_cmd_connect_port_1				: unsigned_8	:= 16#81#; -- tap 1 relays on #CS: dio, aio ?
-- 	llc_cmd_connect_port_2				: unsigned_8	:= 16#82#; -- tap 2 relays on #CS: dio, aio ?
-- 	llc_cmd_disconnect_port_1			: unsigned_8	:= 16#01#; -- tap 1 relays off #CS: dio, aio ?
-- 	llc_cmd_disconnect_port_2			: unsigned_8	:= 16#02#; -- tap 2 relays off #CS: dio, aio ?

	-- low level command header
	llc_head_freq_prsclr				: unsigned_8	:= 16#01#; -- CS: no seq command defined yet -- CS: rename to llc_head_freq_tck
	llc_head_sp_thrshld_tdi				: unsigned_8	:= 16#02#; -- CS: no seq command defined yet
	llc_head_sp_vltg_out				: unsigned_8	:= 16#03#; -- CS: no seq command defined yet
	llc_head_drv_chr_tms_tck			: unsigned_8	:= 16#04#; -- CS: no seq command defined yet
	llc_head_drv_chr_trst_tdo			: unsigned_8	:= 16#05#; -- CS: no seq command defined yet
	llc_head_delay						: unsigned_8	:= 16#06#; 
	llc_head_power_on_off				: unsigned_8	:= 16#07#;
	llc_head_imax						: unsigned_8	:= 16#08#;
	llc_head_timeout					: unsigned_8	:= 16#09#;
	llc_head_connect_disconnect			: unsigned_8	:= 16#0A#;
	llc_head_tap						: unsigned_8	:= 16#0B#; -- indicates a tap_state operation -- CS: rename to llc_head_tap_state
	llc_head_tap_pulse_tck				: unsigned_8	:= 16#0C#; -- indicates a number of tck pulses, arg1 -> number, arg2 -> multiplier 10^arg2 -- CS: implement in comseq

	-- tap_state operation low level command argument 1 (applies for all scanports !)
	llc_cmd_tap_trst					: unsigned_8	:= 16#00#;
	llc_cmd_tap_strst					: unsigned_8	:= 16#01#; -- test-logic-reset
	llc_cmd_tap_htrst					: unsigned_8	:= 16#02#;
-- 	llc_cmd_tap_state_tlr				: unsigned_8	:= 16#03#; 
	llc_cmd_tap_state_rti				: unsigned_8	:= 16#03#; -- run-test/idle
	llc_cmd_tap_state_pdr				: unsigned_8	:= 16#04#; -- pause-dr
	llc_cmd_tap_state_pir				: unsigned_8	:= 16#05#; -- pause-ir    

-- EXECUTOR COMMANDS
    cmd_null            				: constant string (1..2) := "FF";
    cmd_clear_ram       				: constant string (1..2) := "20";
    cmd_step_test       				: constant string (1..2) := "10";
    cmd_step_tck        				: constant string (1..2) := "11";
	cmd_step_sxr        				: constant string (1..2) := "12";

-- EXECUTOR STATES
	ex_state_idle						: constant unsigned_8 := 16#00#;
	ex_state_wait_step_sxr				: constant unsigned_8 := 16#5C#;
	ex_state_shift						: constant unsigned_8 := 16#5A#;
	ex_state_error_compiler				: constant unsigned_8 := 16#F1#;
	ex_state_error_frmt					: constant unsigned_8 := 16#F3#;
	ex_state_error_act_scnpth			: constant unsigned_8 := 16#08#;
	ex_state_error_sxr_type				: constant unsigned_8 := 16#42#;
	ex_state_error_rd_sxr_sp_id			: constant unsigned_8 := 16#5E#;
	ex_state_end_of_test				: constant unsigned_8 := 16#E0#;
	ex_state_test_fail                  : constant unsigned_8 := 16#E3#;
	ex_state_test_abort                 : constant unsigned_8 := 16#E7#;
	

-- MMU STATES -- actually 4 bit wide !
    mmu_state_idle              		: constant unsigned_8 := 16#00#;
    mmu_state_init1             		: constant unsigned_8 := 16#01#;
    mmu_state_init2             		: constant unsigned_8 := 16#02#;        
    mmu_state_init3             		: constant unsigned_8 := 16#03#;
    mmu_state_init4             		: constant unsigned_8 := 16#08#;
    mmu_state_rout1             		: constant unsigned_8 := 16#04#;
    mmu_state_rf_write_ram1     		: constant unsigned_8 := 16#05#;
    mmu_state_rf_write_ram2     		: constant unsigned_8 := 16#0a#;
    mmu_state_rf_write_ram_wait 		: constant unsigned_8 := 16#0d#;
    mmu_state_ex_read_ram_wait  		: constant unsigned_8 := 16#0e#;
    mmu_state_ex_read_ram1      		: constant unsigned_8 := 16#06#;        
    mmu_state_ex_read_ram2      		: constant unsigned_8 := 16#07#;
    mmu_state_rf_read_ram       		: constant unsigned_8 := 16#09#;
    mmu_state_wait1             		: constant unsigned_8 := 16#0b#;
    mmu_state_wait_cycle        		: constant unsigned_8 := 16#0c#;

-- DATA PATH -- actually 4 bit wide !
    path_rf_writes_ram  				: constant unsigned_8 := 16#00#;
    path_rf_reads_ram   				: constant unsigned_8 := 16#01#;    
    path_ex_reads_ram   				: constant unsigned_8 := 16#05#;
    path_null           				: constant unsigned_8 := 16#0F#;

-- BSC STATUS
	bsc_text_state_mmu					: constant string (1..22) := "state mmu [path:state]";
	bsc_text_cmd						: constant string (1..7)  := "command";	
	bsc_text_state_executor				: constant string (1..14) := "state executor";
	bsc_text_state_llc_processor		: constant string (1..10) := "state llcp";
	bsc_text_state_shifter_1			: constant string (1..15) := "state shifter 1";	
	bsc_text_state_shifter_2			: constant string (1..15) := "state shifter 2";
	bsc_text_failed_scanpath			: constant string (1..15) := "failed scanport";
	bsc_text_processed_step_id			: constant string (1..17) := "step id processed";
	bsc_text_chain_length_total			: constant string (1..18) := "chain length total";
	bsc_text_bits_processed				: constant string (1..14) := "bits processed";
	bsc_text_breakpoint_step_id			: constant string (1..18) := "breakpoint step id";
	bsc_text_breakpoint_bit_position	: constant string (1..23) := "breakpoint bit position";
	bsc_text_state_tap					: constant string (1..9)  := "tap [2:1]";
	bsc_text_scanport_bits				: constant string (1..19) := "scanport bits [2:1]";
	bsc_text_state_i2c_master			: constant string (1..16) := "state i2c master";
	bsc_text_ram_address_ex_out			: constant string (1..20) := "RAM address exec out";
	--bsc_text_ram_address_ex_in			: constant string (1..20) := "RAM address exec in ";
	bsc_text_output_ram_data			: constant string (1..15) := "output RAM data";	
	--bsc_text_ram_data_in				: constant string (1..15) := "input  RAM data";		
	bsc_text_firmware_executor			: constant string (1..17) := "firmware executor";	
	bsc_text_rx_errors					: constant string (1..9)  := "rx errors";
	
	bsc_text_tx_errors					: constant string (1..9)  := "tx errors"; 
	-- NOTE: There is no correspoinding BSC register for tx errors. Tx errors are counted at the
	--       host machine (see m1_serial_communications.ads) in variable interface_rx_error_count.
	--       Seen from the host machine, these are rx errors. When displaying the BSC status, they 
	--       are threated as tx errors.

	bsc_register_state_mmu				: unsigned_8;
	bsc_register_cmd_readback			: unsigned_8;
	bsc_register_state_executor			: unsigned_8;
	bsc_register_state_llc_processor	: unsigned_8;	
	bsc_register_state_shifter_1		: unsigned_8;
	bsc_register_state_shifter_2		: unsigned_8;
	bsc_register_step_id				: unsigned_16; -- assumes zero on test start and test end
	bsc_register_failed_scanpath		: unsigned_8; -- bit set for every failed scanpath
	bsc_register_length_sxr_1			: unsigned_32;
	bsc_register_length_sxr_2			: unsigned_32;	
	bsc_register_processed_bits_1		: unsigned_32; -- assumes zero on test start
	bsc_register_processed_bits_2		: unsigned_32;	
	bsc_register_breakpoint_sxr_id		: unsigned_16;
	bsc_register_breakpoint_bit_pos		: unsigned_32;	
	bsc_register_state_tap_1_2			: unsigned_8; -- port 1 low nibble, port 2 high nibble
	bsc_register_scanport_bits_1_2		: unsigned_16; -- port 1 lowbyte. TDI,EXP,MASK,FAIL,TRST,TDO,TMS,TCK
	bsc_register_state_i2c_master		: unsigned_8;
	bsc_register_ram_address_ex_out		: unsigned_32; -- actually 24 bit wide
	--	bsc_register_ram_address_ex_in		: unsigned_32; -- actually 24 bit wide	
	bsc_register_output_ram_data		: unsigned_8;
	-- bsc_register_input_ram_data			: unsigned_8;
	bsc_register_firmware_executor		: unsigned_16;
	bsc_register_rx_error_counter		: unsigned_16; -- holds number of rx errors recorded by uart
	
-- TAP STATES -- CS: adopt proposed values from IEEE1149.1
--     tap_test_logic_reset            	: constant type_hexadecimal_character := '0';
--     tap_run_test_idle               	: constant type_hexadecimal_character := '1';
--     tap_select_dr_scan              	: constant type_hexadecimal_character := '2';
--     tap_capture_dr          	        : constant type_hexadecimal_character := '3';           
--     tap_shift_dr                    	: constant type_hexadecimal_character := '4';
-- 	tap_exit1_dr 	                   	: constant type_hexadecimal_character := '5';
--     tap_pause_dr                    	: constant type_hexadecimal_character := '6';
--     tap_exit2_dr                    	: constant type_hexadecimal_character := '7';
--     tap_update_dr                   	: constant type_hexadecimal_character := '8';   
--     tap_select_ir_scan              	: constant type_hexadecimal_character := '9';
--     tap_capture_ir                  	: constant type_hexadecimal_character := 'A';           
--     tap_shift_ir                    	: constant type_hexadecimal_character := 'B';
--     tap_exit1_ir                    	: constant type_hexadecimal_character := 'C';
--     tap_pause_ir                    	: constant type_hexadecimal_character := 'D';
--     tap_exit2_ir                    	: constant type_hexadecimal_character := 'E';
--     tap_update_ir                   	: constant type_hexadecimal_character := 'F';   

    tap_test_logic_reset            	: constant unsigned_8 := 16#00#;
    tap_run_test_idle               	: constant unsigned_8 := 16#01#;
    tap_select_dr_scan              	: constant unsigned_8 := 16#02#;
    tap_capture_dr          	        : constant unsigned_8 := 16#03#;           
    tap_shift_dr                    	: constant unsigned_8 := 16#04#;
	tap_exit1_dr 	                   	: constant unsigned_8 := 16#05#;
    tap_pause_dr                    	: constant unsigned_8 := 16#06#;
    tap_exit2_dr                    	: constant unsigned_8 := 16#07#;
    tap_update_dr                   	: constant unsigned_8 := 16#08#;   
    tap_select_ir_scan              	: constant unsigned_8 := 16#09#;
    tap_capture_ir                  	: constant unsigned_8 := 16#0A#;           
    tap_shift_ir                    	: constant unsigned_8 := 16#0B#;
    tap_exit1_ir                    	: constant unsigned_8 := 16#0C#;
    tap_pause_ir                    	: constant unsigned_8 := 16#0D#;
    tap_exit2_ir                    	: constant unsigned_8 := 16#0E#;
    tap_update_ir                   	: constant unsigned_8 := 16#0F#;   

-- SERIAL COMMUNICATION
	--	sercom_speed						: constant m1_sercom.data_rate := m1_sercom.B9600;
	sercom_speed							: constant data_rate := B115200;
	-- header
	sercom_head_write						: constant unsigned_8 := 16#00#;
	sercom_head_read						: constant unsigned_8 := 16#01#;
	sercom_head_page						: constant unsigned_8 := 16#02#; -- must be added to sercom_head_write/read
	sercom_page_size						: constant positive := 256;
	sercom_page_fill_byte					: constant unsigned_8 := 16#FF#;
	
	-- commands
	sercom_cmd_null							: constant unsigned_8 := 16#FF#;	
	sercom_cmd_clear_ram					: constant unsigned_8 := 16#20#;
	sercom_cmd_step_test					: constant unsigned_8 := 16#10#;
	sercom_cmd_step_tck						: constant unsigned_8 := 16#11#;
	sercom_cmd_step_sxr						: constant unsigned_8 := 16#12#;
	sercom_cmd_test_halt					: constant unsigned_8 := 16#02#;
	sercom_cmd_test_abort					: constant unsigned_8 := 16#03#;
		
	-- data path
	sercom_path_null						: constant unsigned_8 := 16#0F#;
	sercom_path_rf_writes_ram				: constant unsigned_8 := 16#00#;
	sercom_path_rf_reads_ram				: constant unsigned_8 := 16#01#;
	sercom_path_ex_reads_ram				: constant unsigned_8 := 16#05#;

	-- address
	sercom_addr_data						: constant unsigned_8 := 16#80#;	

	-- address output by uart
	sercom_addr_addr_start_a				: constant unsigned_8 := 16#81#; -- lowbyte
	sercom_addr_addr_start_b				: constant unsigned_8 := 16#82#;
	sercom_addr_addr_start_c				: constant unsigned_8 := 16#83#; -- highbyte
	
	sercom_addr_cmd							: constant unsigned_8 := 16#84#;

	-- RAM address generated by executor
	sercom_addr_addr_ram_a					: constant unsigned_8 := 16#85#; -- lowbyte
	sercom_addr_addr_ram_b					: constant unsigned_8 := 16#86#; 
	sercom_addr_addr_ram_c					: constant unsigned_8 := 16#87#; -- highbyte
	
	sercom_addr_failed_scanpath				: constant unsigned_8 := 16#88#;
	sercom_addr_state_executor				: constant unsigned_8 := 16#89#;
	sercom_addr_state_tap_1_2				: constant unsigned_8 := 16#8A#;
	sercom_addr_path						: constant unsigned_8 := 16#8B#;
	
	sercom_addr_processed_bits_1_a			: constant unsigned_8 := 16#8C#; -- lowbyte
	sercom_addr_processed_bits_1_b			: constant unsigned_8 := 16#8D#; 
	sercom_addr_processed_bits_1_c			: constant unsigned_8 := 16#8E#;  
	sercom_addr_processed_bits_1_d			: constant unsigned_8 := 16#8F#; -- highbyte

	sercom_addr_length_sxr_1_a				: constant unsigned_8 := 16#90#; -- lowbyte
	sercom_addr_length_sxr_1_b				: constant unsigned_8 := 16#91#;
	sercom_addr_length_sxr_1_c				: constant unsigned_8 := 16#92#;	
	sercom_addr_length_sxr_1_d				: constant unsigned_8 := 16#93#; -- highbyte

	sercom_addr_sxr_id_a					: constant unsigned_8 := 16#94#; -- lowbyte
	sercom_addr_sxr_id_b					: constant unsigned_8 := 16#95#; -- highbyte	
	sercom_add_state_shifter_1				: constant unsigned_8 := 16#96#; 

	sercom_addr_processed_bits_2_a			: constant unsigned_8 := 16#97#; -- lowbyte
	sercom_addr_processed_bits_2_b			: constant unsigned_8 := 16#98#; 
	sercom_addr_processed_bits_2_c			: constant unsigned_8 := 16#99#;  
	sercom_addr_processed_bits_2_d			: constant unsigned_8 := 16#9A#; -- highbyte

	sercom_addr_length_sxr_2_a				: constant unsigned_8 := 16#9B#; -- lowbyte
	sercom_addr_length_sxr_2_b				: constant unsigned_8 := 16#9C#;
	sercom_addr_length_sxr_2_c				: constant unsigned_8 := 16#9D#;	
	sercom_addr_length_sxr_2_d				: constant unsigned_8 := 16#9E#; -- highbyte
	sercom_add_state_shifter_2				: constant unsigned_8 := 16#9F#;

	sercom_addr_firmware_executor_a			: constant unsigned_8 := 16#A0#; -- lowbyte
	sercom_addr_firmware_executor_b			: constant unsigned_8 := 16#A1#; -- highbyte

	sercom_addr_path_state_mmu_readback		: constant unsigned_8 := 16#A2#;
	
	sercom_addr_cmd_readback				: constant unsigned_8 := 16#A4#;
	sercom_addr_state_llc					: constant unsigned_8 := 16#A5#;
	sercom_addr_state_i2c					: constant unsigned_8 := 16#A6#;
	sercom_addr_breakpoint_sxr_a			: constant unsigned_8 := 16#A7#; -- breakpoint sxr id lowbyte
	sercom_addr_breakpoint_sxr_b			: constant unsigned_8 := 16#A8#; -- breakpoint sxr id highbyte
	
	sercom_addr_breakpoint_bit_pos_a		: constant unsigned_8 := 16#A9#; -- breakpoint bit position lowbyte
	sercom_addr_breakpoint_bit_pos_b		: constant unsigned_8 := 16#AA#;	
	sercom_addr_breakpoint_bit_pos_c		: constant unsigned_8 := 16#AB#;	
	sercom_addr_breakpoint_bit_pos_d		: constant unsigned_8 := 16#AC#; -- breakpoint bit position highbyte

	sercom_addr_scanport_bits_1				: constant unsigned_8 := 16#AD#; 
	sercom_addr_scanport_bits_2				: constant unsigned_8 := 16#AE#;

	sercom_addr_rx_error_counter_a			: constant unsigned_8 := 16#B0#; -- lowbyte
	sercom_addr_rx_error_counter_b			: constant unsigned_8 := 16#B1#; -- highbyte
	
	
end m1_firmware;

