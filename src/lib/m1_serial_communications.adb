-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 SERIAL COMMUNICATIONS                      --
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

with m1_firmware;				use m1_firmware;
--with m1_sercom; 				--use m1_sercom;
with gnat.serial_communications;	use gnat.serial_communications;

package body m1_serial_communications is

	serial_if : aliased serial_port;
	
	procedure interface_init (
		interface_name : in string; 
		speed	: in data_rate := sercom_speed
		) is
		--flow_control 	: flow_control := rts_cts;
	begin
		open(
			port	=> serial_if,
			name	=> port_name(interface_name)
			);

		set(
		rate	=> speed,
 		port	=> serial_if,
		flow	=> rts_cts,
		timeout	=> 0.5
		);

	end interface_init;

	procedure interface_write (byte : in unsigned_8) is
		edc : unsigned_8 := 0;
	begin
		-- SEND DATA BYTE
		unsigned_8'write (serial_if'access, byte); -- comment for EDAC testing

		-- for EDAC testing use this lines 
		--unsigned_8'write (serial_if'access, byte and 16#FE#); -- bit 0 corrupted
		--unsigned_8'write (serial_if'access, byte and 16#7F#); -- bit 7 corrupted
		--unsigned_8'write (serial_if'access, byte and 16#3F#); -- bit 7 and 6 corrupted
		--unsigned_8'write (serial_if'access, byte and 16#FC#); -- bit 1 and 0 corrupted
		--unsigned_8'write (serial_if'access, byte and 16#F7#); -- bit 3 corrupted

		-- COMPUTE HAMMING CODE BITS EDC[3:0]
		-- edc[3]
-- 		edc := edc + 8 * (
-- 				(byte and 16#80#) / 128 xor -- bit 7
-- 				(byte and 16#40#) /  64 xor -- bit 6
-- 				(byte and 16#10#) /  16 xor -- bit 4
-- 				(byte and 16#08#) /   8 xor -- bit 3
-- 				(byte and 16#02#) /   2);   -- bit 1
-- 
-- 		-- edc[2]
-- 		edc := edc + 4 * (
-- 				(byte and 16#80#) / 128 xor -- bit 7
-- 				(byte and 16#20#) /  32 xor -- bit 5
-- 				(byte and 16#10#) /  16 xor -- bit 4
-- 				(byte and 16#04#) /   4 xor -- bit 2
-- 				(byte and 16#02#) /   2);   -- bit 1
-- 
-- 		-- edc[1]
-- 		edc := edc + 2 * (
-- 				(byte and 16#40#) /  64 xor -- bit 6
-- 				(byte and 16#20#) /  32 xor -- bit 5
-- 				(byte and 16#10#) /  16 xor -- bit 4
-- 				(byte and 16#01#) /   1);   -- bit 0
-- 
-- 		-- edc[0]
-- 		edc := edc + 1 * (
-- 				(byte and 16#08#) /   8 xor -- bit 3
-- 				(byte and 16#04#) /   4 xor -- bit 2
-- 				(byte and 16#02#) /   2 xor -- bit 1
-- 				(byte and 16#01#) /   1);   -- bit 0
-- 		
-- 		unsigned_8'write (serial_if'access, edc); -- send hamming code
	end interface_write;

	
	function interface_read return unsigned_8 is
		byte 		: unsigned_8;
-- 		edc			: unsigned_8;
	
-- 		syndrome	: unsigned_8 := 0; -- low nibble used only
		rx_error 	: boolean := false; -- true when error detected
	begin
		-- RECEIVE DATA BYTE
		unsigned_8'read (serial_if'access, byte);

		-- RECEIVE EDC BYTE
-- 		unsigned_8'read (serial_if'access, edc);

		-- edac testing
--		byte := byte and 2#01111111#; -- simulate bit x stuck at zero
--		byte := byte or  2#00001000#; -- simulate bit x stuck at one
		
		-- DECODE EDC (HAMMING CODE)
		-- syndrome[0]
-- 		syndrome := syndrome + 1 * (
-- 					(edc 	and 16#08#) /   8 xor -- edc bit 3
-- 					(byte 	and 16#80#) / 128 xor -- data bit 7
-- 					(byte 	and 16#40#) /  64 xor -- data bit 6
-- 					(byte 	and 16#10#) /  16 xor -- data bit 4
-- 					(byte 	and 16#08#) /   8 xor -- data bit 3
-- 					(byte 	and 16#02#) /   2);   -- data bit 1
-- 
-- 		-- syndrome[1]
-- 		syndrome := syndrome + 2 * (
-- 					(edc 	and 16#04#) /   4 xor -- edc bit 2
-- 					(byte 	and 16#80#) / 128 xor -- data bit 7
-- 					(byte 	and 16#20#) /  32 xor -- data bit 5
-- 					(byte 	and 16#10#) /  16 xor -- data bit 4
-- 					(byte 	and 16#04#) /   4 xor -- data bit 2
-- 					(byte 	and 16#02#) /   2);   -- data bit 1
-- 
-- 		-- syndrome[2]
-- 		syndrome := syndrome + 4 * (
-- 					(edc 	and 16#02#) /   2 xor -- edc bit 1
-- 					(byte 	and 16#40#) /  64 xor -- data bit 6
-- 					(byte 	and 16#20#) /  32 xor -- data bit 5
-- 					(byte 	and 16#10#) /  16 xor -- data bit 4
-- 					(byte 	and 16#01#) /   1);   -- data bit 0
-- 
-- 		-- syndrome[3]
-- 		syndrome := syndrome + 8 * (
-- 					(edc 	and 16#01#) /   1 xor -- edc bit 0
-- 					(byte 	and 16#08#) /   8 xor -- data bit 3
-- 					(byte 	and 16#04#) /   4 xor -- data bit 2
-- 					(byte 	and 16#02#) /   2 xor -- data bit 1
-- 					(byte 	and 16#01#) /   1);   -- data bit 0
-- 
-- 		-- correct rx errors
-- 		case syndrome is
-- 			when 0 => 
-- 				null; -- everything fine
-- 				
-- 			when 1 | 2 | 4 | 8 => 
-- 				rx_error := true; -- syndrome error but no data correction required
-- 
-- 			when 3 => 
-- 				rx_error := true; -- data error, bit 7 corrupted -> must be inverted: 
-- 				if (byte and 2#10000000#) > 0 then -- if bit set
-- 					byte := byte and 2#01111111#; -- clear bit position
-- 				else
-- 					byte := byte or  2#10000000#; -- set bit position
-- 				end if;
-- 
-- 			when 5 => 
-- 				rx_error := true; -- data error, bit 6 corrupted -> must be inverted: 
-- 				if (byte and 2#01000000#) > 0 then -- if bit set
-- 					byte := byte and 2#10111111#; -- clear bit position
-- 				else
-- 					byte := byte or  2#01000000#; -- set bit position
-- 				end if;
-- 
-- 			when 6 => 
-- 				rx_error := true; -- data error, bit 5 corrupted -> must be inverted: 
-- 				if (byte and 2#00100000#) > 0 then -- if bit set
-- 					byte := byte and 2#11011111#; -- clear bit position
-- 				else
-- 					byte := byte or  2#00100000#; -- set bit position
-- 				end if;
-- 				
-- 			when 7 => 
-- 				rx_error := true; -- data error, bit 4 corrupted -> must be inverted: 
-- 				if (byte and 2#00010000#) > 0 then -- if bit set
-- 					byte := byte and 2#11101111#; -- clear bit position
-- 				else
-- 					byte := byte or  2#00010000#; -- set bit position
-- 				end if;
-- 
-- 			when 9 => 
-- 				rx_error := true; -- data error, bit 3 corrupted -> must be inverted: 
-- 				if (byte and 2#00001000#) > 0 then -- if bit set
-- 					byte := byte and 2#11110111#; -- clear bit position
-- 				else
-- 					byte := byte or  2#00001000#; -- set bit position
-- 				end if;
-- 
-- 			when 10 => 
-- 				rx_error := true; -- data error, bit 2 corrupted -> must be inverted: 
-- 				if (byte and 2#00000100#) > 0 then -- if bit set
-- 					byte := byte and 2#11111011#; -- clear bit position
-- 				else
-- 					byte := byte or  2#00000100#; -- set bit position
-- 				end if;
-- 
-- 			when 11 => 
-- 				rx_error := true; -- data error, bit 1 corrupted -> must be inverted: 
-- 				if (byte and 2#00000010#) > 0 then -- if bit set
-- 					byte := byte and 2#11111101#; -- clear bit position
-- 				else
-- 					byte := byte or  2#00000010#; -- set bit position
-- 				end if;
-- 				
-- 			when 12 => 
-- 				rx_error := true; -- data error, bit 0 corrupted -> must be inverted: 
-- 				if (byte and 2#00000001#) > 0 then -- if bit set
-- 					byte := byte and 2#11111110#; -- clear bit position
-- 				else
-- 					byte := byte or  2#00000001#; -- set bit position
-- 				end if;
-- 				
-- 			when others => null; -- CS: count errors ; rx_error := true;
-- 		end case;

		-- COUNT RX ERRORS
		if rx_error then
			interface_rx_error_count := interface_rx_error_count + 1;
		end if;
		
		return byte;
	end interface_read;

	procedure interface_close is
	begin
		close(
			port	=> serial_if
			);
	end interface_close;
	
end m1_serial_communications;
