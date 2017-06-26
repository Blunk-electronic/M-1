-- ---------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 STRING PROCESSING                          --
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


-- with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.directories;			use ada.directories;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;
with ada.text_io;				use ada.text_io;
-- with ada.float_text_io;			use ada.float_text_io;

with ada.containers;            use ada.containers;
--with ada.containers.vectors;
with ada.containers.indefinite_vectors;

-- with interfaces;				use interfaces;
-- with ada.exceptions;

with ada.calendar;				use ada.calendar;
with ada.calendar.formatting;	use ada.calendar.formatting;
with ada.calendar.time_zones;	use ada.calendar.time_zones;

--with ada.containers.ordered_sets;
-- with m1_database;				use m1_database;
with m1_firmware; 				use m1_firmware;
with m1_numbers; 				use m1_numbers;

package m1_string_processing is

	now				: time := clock;
	date_now		: string (1..19) := image(now, time_zone => utc_time_offset(now));

	-- CS: clean up
	quote_single		: constant string (1..1) := "'";
	dot					: constant string (1..1) := ".";
	exclamation			: constant string (1..1) := "!";
	done				: constant string (1..7) := "...done";
	aborting			: constant string (1..11) := "Aborting...";
	message_error		: constant string (1..7) := "ERROR: ";
	message_warning		: constant string (1..9) := "WARNING: ";
	message_note		: constant string (1..6) := "NOTE: ";
	message_example		: constant string (1..9) := "Example: ";
	passed				: constant string (1..6) := "PASSED";
	failed				: constant string (1..6) := "FAILED";
	successful			: constant string (1..10):= "successful";
	running				: constant string (1..7) := "RUNNING";
	aborted				: constant string (1..7) := "ABORTED";
	--quote_double		: constant string (1..1) := """;
	row_separator_0		: constant string (1..1) := " ";
	row_separator_1		: constant string (1..3) := " | ";
	row_separator_1a	: constant string (1..1) := "|";
	column_separator_0	: constant string (1..100) := (100 * "-");
	column_separator_1	: constant string (1..100) := ("--" & 98 * "=");
	column_separator_2	: constant string (1..100) := (100 * "=");

	type type_section_mark is
		record
			section			: string (1..7)  := "Section";
			endsection		: string (1..10) := "EndSection";
			subsection		: string (1..10) := "SubSection";
			endsubsection	: string (1..13) := "EndSubSection";
		end record;
	section_mark : type_section_mark;

	-- FREQUENTLY USED WORDS, PHRASES, ...
	bscan_standard_1				: constant string (1..10) := "IEEE1149.1";
	bscan_standard_4				: constant string (1..10) := "IEEE1149.4";
	bscan_standard_7				: constant string (1..10) := "IEEE1149.7";
	text_unknown					: constant string (1..7)  := "unknown";

	-- BSDL keywords -- NOTE: some of them also used as UDB keywords
	text_bsdl_entity				: constant string (1..6) := "entity";
	text_bsdl_attribute				: constant string (1..9) := "attribute";
	text_bsdl_instruction_length	: constant string (1..18) := "instruction_length";
	text_bsdl_instruction_capture	: constant string (1..19) := "instruction_capture";
	text_bsdl_idcode_register		: constant string (1..15) := "idcode_register";
	text_bsdl_usercode_register		: constant string (1..17) := "usercode_register";
	text_bsdl_boundary_length		: constant string (1..15) := "boundary_length";
	text_bsdl_boundary_register		: constant string (1..17) := "boundary_register";
	text_bsdl_instruction_opcode	: constant string (1..18) := "instruction_opcode";
	text_bsdl_tap_scan_reset		: constant string (1..14) := "tap_scan_reset";
	text_bsdl_of					: constant string (1..2)  := "of";
	text_bsdl_port_identifier		: constant string (1..4)  := "port";
	text_bsdl_bit_vector			: constant string (1..10) := "bit_vector";
	text_bsdl_to					: constant string (1..2)  := "to";
	text_bsdl_downto				: constant string (1..6)  := "downto";
	text_bsdl_bit					: constant string (1..3)  := "bit";
	text_bsdl_constant				: constant string (1..8)  := "constant";

	-- UDB keywords
	text_udb_class							: constant string (1..5) := "class";
	text_udb_option							: constant string (1..6) := "option";	
	text_udb_none							: constant string (1..4) := "none";
	text_udb_instruction_register_length 	: constant string (1..27) := "instruction_register_length";
	text_udb_boundary_register_length		: constant string (1..24) := "boundary_register_length";
	text_udb_trst_pin						: constant string (1..8) := "trst_pin";
	text_udb_available						: constant string (1..9) := "available";
	text_udb_safebits						: constant string (1..8) := "safebits";
	text_udb_opcodes						: constant string (1..19) := "instruction_opcodes";
	text_udb_port_io_map					: constant string (1..11) := "port_io_map";
	text_udb_port_pin_map					: constant string (1..12) := "port_pin_map";


	short_string_length_max : constant natural := 10;
 	package type_short_string is new generic_bounded_length(short_string_length_max);

	universal_string_length_max	: constant natural := 1000;
	package type_universal_string is new generic_bounded_length(universal_string_length_max);
	
	long_string_length_max	: constant natural := 10000;
	package type_long_string is new generic_bounded_length(long_string_length_max);
	
	extended_string_length_max	: constant natural := 100000;
	package type_extended_string is new generic_bounded_length(extended_string_length_max);

	function ht_to_space (c : in character) return character;
	
	function wildcard_match (text_with_wildcards : in string; text_exact : in string) return boolean;
	-- Returns true if text_with_wildcards matches text_exact.
	-- text_with_wildcards is something like R41* , text_exact is something like R415
	
	function remove_comment_from_line(text_in : string) return string;

	function get_field_count (text_in : string) return natural;

-- 	function get_field_from_line (
-- 		text_in 	: in string;
-- 		position 	: in positive;
-- 		ifs 		: in character := latin_1.space
-- 		) return string;

	function strip_quotes (text_in : in string) return string;
	-- removes heading and trailing quotation from given string

	function enclose_in_quotes (text_in : in string; quote : in character := latin_1.apostrophe) return string;
	-- Adds heading and trailing quotate to given string. NOTE: apostrophe is ', quotation is "

	function trim_space_in_string (text_in : in string) return string;
	-- shrinks successive space characters to a single one in given string
	
	function get_field_from_line(
	-- Extracts a field separated by ifs at position. If trailer is true, the trailing content untiil trailer_to is also returned.
		text_in 	: in string;
		position 	: in positive;
		ifs 		: in character := latin_1.space;
		trailer 	: in boolean := false;
		trailer_to 	: in character := latin_1.semicolon
		) return string;

	-- CS: comments
	package type_list_of_strings is new indefinite_vectors (index_type => positive, element_type => string);
	type type_fields_of_line is record -- CS: should be private
		fields		: type_list_of_strings.vector;
		field_count	: count_type; 
	end record;
	function read_line ( line : in string; ifs : in character := latin_1.space ) return type_fields_of_line;
	function append (left : in type_fields_of_line; right : in type_fields_of_line) return type_fields_of_line;
	
	function get_field_from_line (line : in type_fields_of_line; position : in positive) return string;

	function to_string ( line : in type_fields_of_line) return string;
	
-- MESSAGES	
	procedure direct_messages;
	-- Sets the output channel to logfile accroding to action.
	
	procedure write_log_header(module_version : in string);
	-- Creates logfile according to current action.
	-- Writes header information in logfile and leaves it open.

	procedure write_log_footer;
	-- Writes the footer in logfile according to current action.
	-- Writes footer information in logfile and closes it.
	
	procedure write_message (
		file_handle : in ada.text_io.file_type;
		identation : in natural := 0;
		text : in string; 
		lf   : in boolean := true;		
		file : in boolean := true;
		console : in boolean := false);
	
	
end m1_string_processing;

