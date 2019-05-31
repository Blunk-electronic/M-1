-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 SERIAL COMMUNICATIONS                      --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               S p e c                                    --
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

with interfaces;				use interfaces;
with m1_firmware;				use m1_firmware;
--with m1_sercom;
with gnat.serial_communications;	use gnat.serial_communications;

package m1_serial_communications is

	procedure interface_init (
		interface_name : in string; 
		speed	: in data_rate := sercom_speed
		);
	
	procedure interface_write (byte : in unsigned_8);

	interface_rx_error_count : natural := 0; -- increments when rx error occured
	function interface_read return unsigned_8;
	procedure interface_close;

end m1_serial_communications;