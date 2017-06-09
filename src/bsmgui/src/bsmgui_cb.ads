------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE BSMGUI_CB                           --
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
--   todo: 


with ada.text_io; 				use ada.text_io;
with gtk.widget;  				use gtk.widget;
with gtk.button;  				use gtk.button;
with gtk.image;					use gtk.image;
with gtk.file_chooser_button;	use gtk.file_chooser_button;
with glib.object;
with gdk.event;

with gnat.os_lib;   			use gnat.os_lib;


package bsmgui_cb is

	procedure write_log_header (version : in string);
	procedure write_log_footer;
	
	gui_refresh_rate			: duration := 0.1;

	-- After killing processes, it takes this time for the interface to become free
	-- for other commands.
	time_for_interface_to_become_free : duration := 1.0; 


	button_start_stop_test		: gtk_button;
	button_start_stop_script	: gtk_button;
	button_abort_shutdown		: gtk_button;

	text_label_button_test_start	: constant string (1..10) := "START TEST";
	text_label_button_test_stop		: constant string (1..9)  := "STOP TEST";
	text_label_button_script_start	: constant string (1..12) := "START SCRIPT";
	text_label_button_script_stop	: constant string (1..11) := "STOP SCRIPT";

	chooser_set_uut		: gtk_file_chooser_button;
	chooser_set_script	: gtk_file_chooser_button;
	chooser_set_test	: gtk_file_chooser_button;

	img_status			: gtk.image.gtk_image;

	-- The image that displays in bright red, green, yellow the result of an action.
	type type_status_image is (fail, pass, ready, running, aborted, abort_fail);
	procedure set_status_image(status : in type_status_image);

	procedure terminate_main (self : access gtk_widget_record'class);
	procedure set_project (self : access gtk_file_chooser_button_record'class);
	procedure set_script (self : access gtk_file_chooser_button_record'class);
	procedure set_test (self : access gtk_file_chooser_button_record'class);
	procedure start_stop_test (self : access gtk_button_record'class);
	procedure start_stop_script (self : access gtk_button_record'class);
	procedure abort_shutdown (self : access gtk_button_record'class);

	file_session	: ada.text_io.file_type;
	procedure write_session_file_headline;

	function system( cmd : string ) return integer;
	pragma import( c, system );

	type type_status_script is (stopped, finished, running);
	status_script : type_status_script := stopped;
	--script_valid : boolean := false; -- true once a valid script has been set by the operator

	type type_status_test is (stopped, finished, running);
	status_test : type_status_test := stopped;
	--test_valid : boolean := false; -- true once a valid test has been set by the operator

	-- here useless stuff goes (when external program "pidof" is running)
	trash_bin_text : file_descriptor := open_read_write (name => "/dev/null", fmode => text);

	abort_pending : boolean := false;

end bsmgui_cb;
