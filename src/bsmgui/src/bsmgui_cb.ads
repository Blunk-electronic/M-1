with gtk.widget;  				use gtk.widget;
with gtk.button;  				use gtk.button;
with gtk.image;					use gtk.image;
with gtk.file_chooser_button;	use gtk.file_chooser_button;
with glib.object;
with gdk.event;

with gnat.os_lib;   			use gnat.os_lib;

package bsmgui_cb is

	gui_refresh_rate		: duration := 0.1;

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

	pid		: process_id := invalid_pid;
	type type_status_test is (stopped, finished, running);
	status_test : type_status_test := stopped;

end bsmgui_cb;
