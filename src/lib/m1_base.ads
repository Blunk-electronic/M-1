-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 BASE COMPONENTS                            --
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

-- with ada.strings.unbounded; 	use ada.strings.unbounded;
-- with ada.strings.bounded; 		use ada.strings.bounded;
-- with ada.strings.fixed; 		use ada.strings.fixed;
-- with ada.characters;			use ada.characters;
-- with ada.characters.latin_1;	use ada.characters.latin_1;
-- with ada.characters.handling;	use ada.characters.handling;
with ada.text_io;				use ada.text_io;
-- with ada.float_text_io;			use ada.float_text_io;
-- 
-- with ada.containers;            use ada.containers;
-- with ada.containers.indefinite_vectors;

-- with interfaces;				use interfaces;
-- with ada.exceptions;

-- with ada.calendar;				use ada.calendar;
-- with ada.calendar.formatting;	use ada.calendar.formatting;
-- with ada.calendar.time_zones;	use ada.calendar.time_zones;
-- 
-- with ada.containers.ordered_sets;
-- with m1_firmware; 				use m1_firmware;
-- with m1_numbers; 				use m1_numbers;

package m1_base is

	procedure dummy;
	
	name_system		: constant string (1..29) := "BOUNDARY SCAN TEST SYSTEM M-1";
	name_bsc		: constant string (1..24) := "Boundary Scan Controller";

	type type_language is (german, english);
	language 	: type_language := english;

	-- OPERATOR ACTIONS
	type type_action is ( 
		--HELP,
		CONFIGURATION,
		CREATE,
		IMPORT_CAD, -- CS: update manual
		MKVMOD, -- CS: update manual
		IMPORT_BSDL, -- CS: update manual
		JOIN_NETLIST,
		MKNETS,
		CHKPSN,
		MKOPTIONS,
		GENERATE,
		COMPILE,
		LOAD,
		DUMP,
		OFF,
		CLEAR,
		RUN,
		BREAK,
		--REPORT, CS
		UDBINFO,
		STATUS,
		FIRMWARE
		);
	action	: type_action;
	

	-- CS: obsolete ?
-- 	name_script		: universal_string_type.bounded_string;
-- 	name_test		: universal_string_type.bounded_string;
-- 	target_device	: universal_string_type.bounded_string;
-- 	target_pin		: universal_string_type.bounded_string;
-- 	target_net		: universal_string_type.bounded_string;
--     device_package	: universal_string_type.bounded_string;

	function request_user_confirmation -- CS: move it to m1_dialogue
		-- version 001
		-- question_form given as natural determines kind of question addressed to the operator, default is 0
		-- show_confirmation_dialog given as boolean determines if operater request shall be done or not. default is true
		-- 
		-- returns true if user typed y, otherwise false
		( question_form : natural := 0;
		  show_confirmation_dialog : boolean := true)
		return boolean;

	comment_mark : constant string (1..3) := "-- ";
end m1_base;

