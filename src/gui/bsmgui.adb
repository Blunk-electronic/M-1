------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE BSMGUI                              --
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
--   todo: 

with ada.text_io;				use ada.text_io;
with ada.characters.handling; 	use ada.characters.handling;
with ada.strings; 				use ada.strings;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.unbounded.text_io; use ada.strings.unbounded.text_io;
with ada.exceptions; 			use ada.exceptions;

 
with gnat.os_lib;   			use gnat.os_lib;
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;
with ada.environment_variables;

with m1_internal; 				use m1_internal;
with m1_numbers;				use m1_numbers;
with m1_files_and_directories; 	use m1_files_and_directories;
with m1_firmware;				use m1_firmware;


-- with gtk.main;
-- with gtk.box, gtk.window, gtk.button; -- use gtk.box, 
-- --use gtk.window, 
-- -- use gtk.button;
-- with gtk.label;
-- with gtk.text_view;
-- with gtk.text_buffer;
-- with gtk.scrolled_window; --use gtk.scrolled_window;
-- with gtk.image;
-- 
-- with ada.text_io; use ada.text_io;
-- with gdk.event; -- use gdk.event;
-- with gtk.handlers; --use gtk.handlers;
-- with gtk.widget; -- use gtk.widget;
-- --with gtk.file_selection; -- rm v014
-- with gtk.file_chooser; -- ins v014
-- with gtk.file_chooser_button; -- ins v014
-- 
-- with gtk.message_dialog;
-- 
-- with gnat.os_lib;   	use gnat.os_lib;
-- 
-- --with gdk.font;
-- --with gtk.text_tag;
-- --with Glib.Properties;
-- with my_handlers;

procedure bsmgui is

	version		: string (1..3) := "014";





begin

	null;

end bsmgui;