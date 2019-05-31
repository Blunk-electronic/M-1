------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 FIRMWARE DECLARATIONS                      --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               B o d y                                    --
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
with ada.text_io;				use ada.text_io;
with ada.strings;		 		use ada.strings;
with ada.strings.fixed; 		use ada.strings.fixed;
with m1_string_processing;		use m1_string_processing;

package body m1_firmware is

	function is_voltage_out_discrete (voltage : type_voltage_out) return boolean is
	-- Returns true if given voltage is member of type_voltage_out_discrete.
		voltage_scratch : string (1..3);
	begin

		-- Search in type_voltage_out_discrete for given voltage.
		-- Elements of type_voltage_out_discrete are converted to a string and compared with
		-- the image of given voltage.
		-- On match return true. If no matching element found, output error message.
		for v in 0..type_voltage_out_discrete'pos(type_voltage_out_discrete'last) loop
			voltage_scratch := type_voltage_out_discrete'image( type_voltage_out_discrete'val(v))(2..4); -- removes heading letter "V"
			voltage_scratch(2) := '.'; -- replaces "_" by "."
			if trim(type_voltage_out'image(voltage),left) = voltage_scratch then -- compared
				--put_line(standard_output,voltage_scratch);
				return true;
			end if;
		end loop;

		-- No matching element found. Output error message and display available scanport voltages.
		put_line(standard_output,message_error & "Scanport output voltage" & type_voltage_out'image(voltage) & "V not supported !");
		put(standard_output,message_error'last * row_separator_0 & "Available values are: ");
		for v in 0..type_voltage_out_discrete'pos(type_voltage_out_discrete'last) loop
			voltage_scratch := type_voltage_out_discrete'image( type_voltage_out_discrete'val(v))(2..4);
			voltage_scratch(2) := '.';
			put(standard_output,voltage_scratch & "V ");
		end loop;
		new_line(standard_output);

		return false;
	end is_voltage_out_discrete;


end m1_firmware;

