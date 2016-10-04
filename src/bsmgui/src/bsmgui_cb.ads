------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE BSMGUI_CB                           --
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
with m1_internal; 				use m1_internal;

package bsmgui_cb is

	gui_refresh_rate			: duration := 0.1;
	time_to_free_the_interface	: duration := 2.0;

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

	procedure terminate_main (self : access gtk_widget_record'class);
	procedure set_project (self : access gtk_file_chooser_button_record'class);
	procedure set_script (self : access gtk_file_chooser_button_record'class);
	procedure set_test (self : access gtk_file_chooser_button_record'class);
	procedure start_stop_test (self : access gtk_button_record'class);
	procedure start_stop_script (self : access gtk_button_record'class);
	procedure abort_shutdown (self : access gtk_button_record'class);

	function system( cmd : string ) return integer;
	pragma import( c, system );

	type type_status_script is (stopped, finished, running);
	status_script : type_status_script := stopped;

	type type_status_test is (stopped, finished, running);
	status_test : type_status_test := stopped;

end bsmgui_cb;
