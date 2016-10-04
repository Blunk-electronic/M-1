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
