with Ada.Text_IO; use Ada.Text_IO;
with Gtk.Main;

package body hello_cb is
   -- If you return false in the "delete_event" signal handler,
   -- GTK will emit the "destroy" signal. Returning true means
   -- you don't want the window to be destroyed.
   --
   -- This is useful for popping up 'are you sure you want to quit?'
   -- type dialogs.
   function main_del
     (Self  : access Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event)
      return  Boolean
   is
   begin
      Put_Line ("Delete event encounter.");
      return True;
   end main_del;

   procedure main_quit (Self : access Gtk_Widget_Record'Class) is
   begin
      Gtk.Main.Main_Quit;
		put_line("quit");
   end main_quit;

   procedure button_clicked (Self : access Gtk_Button_Record'Class) is
   begin
      Put_Line ("Hello clicked");
   end button_clicked;

   procedure button_quit (Self : access Gtk_Widget_Record'Class) is
   begin
      Put_Line ("buttion_quit is called");
      Destroy (Self);
   end button_quit;




	procedure button_quit_clicked (self : access gtk_button_record'class) is
	begin
		put_line ("quit clicked");
	end button_quit_clicked;

	procedure terminate_main (self : access gtk_widget_record'class) is
	begin
		put_line ("terminated");
		--destroy (self);
		gtk.main.main_quit;
	end terminate_main;

	procedure set_uut (self : access gtk_button_record'class) is
	begin
		put_line("set uut");
		--return true;
	end set_uut;

end hello_cb;
