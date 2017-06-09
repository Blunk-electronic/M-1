------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 BASE COMPONENTS                            --
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


package body m1_base is

	procedure dummy is begin null; end dummy;

	function request_user_confirmation
		-- question_form given as natural determines kind of question addressed to the operator, default is 0
		-- show_confirmation_dialog given as boolean determines if operater request shall be done or not. default is true
		-- 
		-- returns true if user typed y, otherwise false
		( question_form : natural := 0;
		  show_confirmation_dialog : boolean := true)
		return boolean is
		type key_type is (y,n);
		key : key_type;
		c : string (1..1) := "n";
		Previous_Output	: File_Type renames Current_Output; -- ins v002
		Previous_Input	: File_Type renames Current_Input; -- ins v002
		--prog_position : string (1..5) := "RQ001";
		begin
			if show_confirmation_dialog = false then  -- exit with true if dialog is disabled
				set_output(previous_output); -- ins v002
				set_input(previous_input);  -- ins v002
				return true; 
			end if;

			set_output(standard_output);
			set_input(standard_input);
			new_line;
			case question_form is
				when 0 => put("ARE YOU SURE ? (y/n) :");
				when 1 => put("PROCEED ? (y/n) :");
				when 2 => put("EXECUTE ? (y/n) :");
				when 3 => put("OVERWRITE ? (y/n) :");
				when others => put("DO YOU REALLY MIND IT ? (y/n) :");
			end case;
			get(c);
			new_line;

			set_output(previous_output); -- ins v002
			set_input(previous_input);  -- ins v002

			key := key_type'value(c); -- do a type check (y/n)
			if key = y then return true; end if;
			return false;
		end request_user_confirmation;

	
end m1_base;

