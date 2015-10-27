with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with ada.directories; use ada.directories;
with gtk.main;
with gtk.box, gtk.window, gtk.button; -- use gtk.box, 
--use gtk.window, 
-- use gtk.button;
with gtk.label;
with gtk.Text_View;
with gtk.text_buffer;
with Gtk.Scrolled_Window; --use Gtk.Scrolled_Window;
with gtk.image;

with ada.text_io; use ada.text_io;
with gdk.event; -- use gdk.event;
with gtk.handlers; --use gtk.handlers;
with gtk.widget; -- use gtk.widget;
with Gtk.File_Selection;
--with gtk.file_chooser;
--with Gtk.File_Chooser_Button;

with gtk.message_dialog;

with GNAT.OS_Lib;   	use GNAT.OS_Lib;

--with gdk.font;
--with gtk.text_tag;
--with Glib.Properties;

procedure gm1 is

	Version			: String (1..3) := "014";
	--src_dir		: string := "/opt/m-1/src/ada/"; -- rm v014
	img_dir		: string := "/home/luno/cad/projects/m-1/bin/img/"; -- ins v014
	--img_dir		: string := "img/"; -- ins v014
	--bin_dir		: string := "/home/luno/cad/projects/m-1/bin/";
	bin_dir		: string := "/home/luno/cad/projects/m-1/bin/";
	window		: gtk.window.gtk_window;
	selection_sequence	: Gtk.File_Selection.Gtk_File_Selection;
	selection_load		: Gtk.File_Selection.Gtk_File_Selection;
--	selection_sequence2	: Gtk.File_Chooser_Button.Gtk_File_Chooser_Button;
	button_select_sequence	: gtk.button.gtk_button;
	button_load				: gtk.button.gtk_button;
	button_start_stop		: gtk.button.gtk_button;
	button_report			: gtk.button.gtk_button;
	label_uut_name			: gtk.label.gtk_label;
	label_uut_mark			: gtk.label.gtk_label;
	label_sequence_mark		: gtk.label.gtk_label;

	label_sequence_name	: gtk.label.gtk_label;

	box_back		: gtk.box.gtk_box;
	box_uut			: gtk.box.gtk_box;
	box_sequence	: gtk.box.gtk_box;
	box_head		: gtk.box.gtk_box;
	box_selection	: gtk.box.gtk_box;
	label_version		: gtk.label.gtk_label;

	img_status		: gtk.image.gtk_image;
--	Scrolled 	: Gtk.Scrolled_Window.Gtk_Scrolled_Window;
--	textbox		: gtk.text_view.gtk_text_view;
--	textbuf		: gtk.text_buffer.gtk_text_buffer;
	--font		: gdk.gdk_font;
--	dialog_wrong_file	: gtk.message_dialog.gtk_message_dialog;
	Result    	: Integer;
--	success		: boolean;
--	dummy		: Integer;

	--tag1 		: gtk.text_tag.gtk_text_tag;
	--fp : constant gtk.text_tag.Font_Property := "Sans Italic 12";

	sequence_name		: unbounded_string := to_unbounded_string("");
	load_name			: unbounded_string := to_unbounded_string("");
	uut_name			: unbounded_string := to_unbounded_string("");
	uut_name_previous	: unbounded_string := to_unbounded_string("");

	result_file 		: Ada.Text_IO.File_Type;
	result_file_name	: string := "last_run.txt";

--	proc_id			: process_id;
	test_running	: boolean := false;

	function system( cmd : string ) return integer;
	pragma Import( C, system );

	function read_result_file
		return string is

		result_string	: unbounded_string;

		begin

			-- open input_file
			Open( 
				File => result_file,
				Mode => In_File,
				Name => result_file_name
				);
			Set_Input(result_file); -- set data souce

			while not End_Of_File 
				loop
					--line:=Get_Line;
					result_string := result_string & get_line & Character'Val(10);
				end loop;

			set_input(standard_input);
			close(result_file);

			return to_string(result_string);
		end read_result_file;

	package return_handlers is new gtk.handlers.return_callback
		(
		widget_type	=> gtk.widget.gtk_widget_record,
		return_type	=> boolean
		);

	-- 1.1b, this function gets called by the action caused at 1.1b
	function delete_event
		(
		widget	: access gtk.widget.gtk_widget_record'class;
		event	: gdk.event.gdk_event
		) 
		return boolean 
		is
			pragma unreferenced (event);
			pragma unreferenced (widget);
		begin
			gtk.main.main_quit;
			return false;
		end delete_event;


	function delete_load_dialog
		(
		widget	: access gtk.widget.gtk_widget_record'class;
		event	: gdk.event.gdk_event
		) 
		return boolean 
		is
			pragma unreferenced (event);
			pragma unreferenced (widget);
		begin
			--gtk.main.main_quit;
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), true);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), true);

			return false;
		end delete_load_dialog;


	function delete_sequence_dialog
		(
		widget	: access gtk.widget.gtk_widget_record'class;
		event	: gdk.event.gdk_event
		) 
		return boolean 
		is
			pragma unreferenced (event);
			pragma unreferenced (widget);
		begin
			--gtk.main.main_quit;
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), true);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), true);

			return false;
		end delete_sequence_dialog;



  	package Files_Cb is new gtk.handlers.Callback 
  		(
  		widget_type => Gtk.File_Selection.Gtk_File_Selection_Record
  		);

	-- this is a callback !
	procedure sequence_select_ok 
		(
		Files : access Gtk.File_Selection.Gtk_File_Selection_Record'Class
		) 
		is
		dead 		: boolean;
		file_valid : boolean := true;
        begin
			--Put_line ("Selected Batch " & Gtk.File_Selection.Get_Filename (Files));
			--put (current_directory); new_line;

			sequence_name := to_unbounded_string(Gtk.File_Selection.Get_Filename (Files)); --rm v014
			gtk.file_selection.destroy (selection_sequence);

			-- check file extension
			if extension (simple_name(to_string(sequence_name))) /= "test" then 
				--gtk.image.set (img_status, src_dir & "gui/img/wrong_test_file.png"); -- rm v014
				gtk.image.set (img_status, img_dir & "wrong_test_file.png"); -- ins v014
				file_valid := false;
				while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;
			end if;

			if file_valid then

				-- set label to display sequence_name
				gtk.label.set_text (label_sequence_name, simple_name(to_string(sequence_name)));

				-- set status image
				--gtk.image.set (img_status, src_dir & "gui/img/ready.png"); -- rm v014
				gtk.image.set (img_status, img_dir & "ready.png"); -- ins v014

				uut_name := to_unbounded_string(containing_directory(to_string(sequence_name)));
				set_directory(to_string(uut_name));
				--put_line (to_string(uut_name_previous) & ".");
				--put_line (to_string(uut_name) & ".");

				if uut_name /= uut_name_previous then

					-- launch external command
					Spawn 
						(  
						Program_Name           => bin_dir & "bsmcl",
						--program_name			=> to_string(sequence_name),
						Args                   => 	(
													1=> new String'("clear")
													),
						--Output_File			   => result_file_name,
						Output_File_Descriptor => Standout,
						--Success				   => success,
						Return_Code            => Result
						);

					--if result = 0 then gtk.image.set (img_status, src_dir & "gui/img/upload_request.png"); -- rm v014
					if result = 0 then gtk.image.set (img_status, img_dir & "upload_request.png"); -- ins v014
						--else gtk.image.set (img_status, src_dir & "gui/img/init_fail.png"); -- rm v014
						else gtk.image.set (img_status, img_dir & "init_fail.png"); -- ins v014
					end if;

					--put_line("WARNING ! You have changed the project ! ");
					--put_line("project        : " & uut_name)); new_line;

					--put_line (to_string(uut_name));
					set_directory (to_string(uut_name));
					uut_name_previous := uut_name;
				end if;

				gtk.label.set_text (label_uut_name, to_string(uut_name));
				gtk.button.set_label (button_start_stop, "START");

				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), true);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), true);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), true);

				test_running := false;
			end if;

        end sequence_select_ok;
       


	procedure sequence_select_cancel
		(
		Files : access Gtk.File_Selection.Gtk_File_Selection_Record'Class
		) 
		is
        begin
			--Put_line ("Selected Batch " & Gtk.File_Selection.Get_Filename (Files));
			--put (current_directory); new_line;

			--sequence_name := to_unbounded_string(Gtk.File_Selection.Get_Filename (Files));
			--gtk.file_selection.destroy (selection_sequence); -- rm 014
			--gtk.file_selection.destroy (selection_sequence); -- rm 014 -- no replacement found in Gtk.File_Chooser_Button
			gtk.label.set_text (label_sequence_name,  " ------------ ");
			--gtk.image.set (img_status, src_dir & "gui/img/idle.png"); -- rm v014
			gtk.image.set (img_status, img_dir & "idle.png"); -- ins v014

			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), true);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), true);

        end sequence_select_cancel;


	-- this is a callback !
	procedure sequence_load_ok 
		(
		Files : access Gtk.File_Selection.Gtk_File_Selection_Record'Class
		) 
		is

		--pragma unreferenced (widget);
		dead 		: boolean;
		file_valid	: boolean := true;
		init_successful : boolean := true;
		result_file	: Ada.Text_IO.File_Type;
		line		: unbounded_string;

        begin
			--Put_line ("Selected Batch " & Gtk.File_Selection.Get_Filename (Files));
			--put (current_directory); new_line;

			load_name := to_unbounded_string(Gtk.File_Selection.Get_Filename (Files));
			gtk.file_selection.destroy (selection_load);

			--put_line("hallo");
			--put_line(integer'image(length(load_name)));
			--put_line(to_string(load_name));
			-- check if load_name has been selected yet
-- 			if length(load_name) = 0 then
-- 				gtk.image.set (img_status, src_dir & "gui/img/no_load_file_yet.png");
-- 				file_valid := false;
-- 				while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;

			-- check file extension
			if extension (simple_name(to_string(load_name))) /= "load" then 
				--gtk.image.set (img_status, src_dir & "gui/img/wrong_load_file.png"); -- rm v014
				gtk.image.set (img_status, img_dir & "wrong_load_file.png"); -- ins v014
				file_valid := false;
				while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;
			end if;


			-- set label to display sequence_name
			--gtk.label.set_text (label_sequence_name, simple_name(to_string(sequence_name)));

			if file_valid then
				-- set status image
				--gtk.image.set (img_status, src_dir & "gui/img/upload.png"); -- rm v014
				gtk.image.set (img_status, img_dir & "upload.png"); -- ins v014
				while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;

				uut_name := to_unbounded_string(containing_directory(to_string(load_name)));
				set_directory(to_string(uut_name));
				--put_line (to_string(uut_name_previous) & ".");
				--put_line (to_string(uut_name) & ".");

				if uut_name /= uut_name_previous then

					-- launch external command
					Spawn 
						(  
						Program_Name           => bin_dir & "bsmcl",
						--program_name			=> to_string(sequence_name),
						Args                   => 	(
													1=> new String'("clear")
													),
						--Output_File			   => result_file_name,
						Output_File_Descriptor => Standout,
						--Success				   => success,
						Return_Code            => Result
						);

					if result = 0 then null;
						else
							init_successful := false;
							--gtk.image.set (img_status, src_dir & "gui/img/init_fail.png"); -- rm v014
							gtk.image.set (img_status, img_dir & "init_fail.png"); -- ins v014
							while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;
					end if;


					--put_line("WARNING ! You have changed the project ! ");
					--put_line("project        : " & uut_name)); new_line;

					--put_line (to_string(uut_name));
					set_directory (to_string(uut_name));
					uut_name_previous := uut_name;
				end if;

				if init_successful then

					gtk.label.set_text (label_uut_name, to_string(uut_name));

					--gtk.image.set (img_status, src_dir & "gui/img/run.png");
					--while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;

					Result := system( "xterm -geometry 100x15-0-0 -e run_and_log_sequence " & to_string(load_name) & ASCII.NUL );

					-- open result file
					Open( 
						File => Result_File,
						Mode => In_File,
						Name => "tmp/batch_exit_code.tmp"
						);
					Set_Input(Result_File); -- set data source

					-- read result file
					while not End_Of_File
						loop
							Line:=to_unbounded_string(Get_Line);
							--Put_Line("-" & to_string(Line) & "-");
						end loop;
					Close(Result_File);
					Set_Input(Standard_Input);

					if to_string(line) = "0" then 
						--gtk.image.set (img_status, src_dir & "gui/img/test_sequence_request.png"); -- rm v014
						gtk.image.set (img_status, img_dir & "test_sequence_request.png"); -- ins v014

						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), true);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), true);

						while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;
					else
						put_line("ERROR : Malfunction while uploading test sequence !"); 
						--gtk.image.set (img_status, src_dir & "gui/img/upload_fail.png"); -- rm v014
						gtk.image.set (img_status, img_dir & "gui/img/upload_fail.png"); -- ins v014

						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), true);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), true);

						while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;
					end if;

				end if;

			end if;

        end sequence_load_ok;


	procedure sequence_load_cancel
		(
		Files : access Gtk.File_Selection.Gtk_File_Selection_Record'Class
		) 
		is
        begin
			--Put_line ("Selected Batch " & Gtk.File_Selection.Get_Filename (Files));
			--put (current_directory); new_line;

			--sequence_name := to_unbounded_string(Gtk.File_Selection.Get_Filename (Files));
			--gtk.file_selection.destroy (selection_load); -- rmv 014 -- no replacement found in gtk.file_chooser_button
			--gtk.label.set_text (label_sequence_name,  " ------------ ");
			--gtk.image.set (img_status, src_dir & "gui/img/idle.png"); -- rm v014
			gtk.image.set (img_status, img_dir & "idle.png"); -- ins v014

			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), true);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
			gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), true);

        end sequence_load_cancel;



	type string_access is access all string;

	package handlers is new gtk.handlers.user_callback
		(
		widget_type	=> gtk.widget.gtk_widget_record,
		user_type	=> string_access
		);

	-- 2.1b, this procedure gets called by the action caused at 2.1a
	procedure button_callback

		(
		widget	: access gtk.widget.gtk_widget_record'class;
		data	: string_access
		)
		is
			pragma unreferenced (widget);
			dead 	: boolean;
			a		: integer := 0;

		begin
			if data.all = "START" then 
				if test_running = false then

					-- check if sequence has been selected yet
					if length(sequence_name) = 0 then
						--gtk.image.set (img_status, src_dir & "gui/img/no_file_yet.png"); -- rm v014
						gtk.image.set (img_status, img_dir & "no_file_yet.png"); -- ins v014
						while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;

					-- check file extension (*.sh)
					--elsif extension (simple_name(to_string(sequence_name))) /= "test" then 
					--	gtk.image.set (img_status, src_dir & "gui/img/wrong_test_file.png");
					--	while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;
					else
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), false);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), true);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), false);


						--gtk.image.set (img_status, src_dir & "gui/img/run.png"); -- rm v014
						gtk.image.set (img_status, img_dir & "run.png"); -- ins v014
						while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;					

						Result := system( "xterm -fn 10x20 -geometry 100x15-0-0 -e run_and_log_sequence " & to_string(sequence_name) & " &" & ASCII.NUL );

						gtk.button.set_label (button_start_stop, "STOP");
						test_running := true;

						result := 0;
						while result = 0
							loop
								result := system( "sleep 0.5; ps -A | grep xterm" & ASCII.NUL );
								while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;
							end loop;

						spawn
-- 						proc_id := non_blocking_spawn
							(
							program_name	=> bin_dir & "bsmcl", 
							Args            => 	(
												1=> new String'("status")
												),
							Output_File_Descriptor => Standout,
							--Success				   => success,
							Return_Code            => Result
							);


						--Result := system( "bsmcl status" & ASCII.NUL );
						--put (integer'image(result)); new_line;
						case result is
							-- rm v014 begin
							--when 11 => gtk.image.set (img_status, src_dir & "gui/img/pass.png");
							--when 14 => gtk.image.set (img_status, src_dir & "gui/img/ready.png");
							--when others => gtk.image.set (img_status, src_dir & "gui/img/fail.png");
							-- rm v014 end

							-- ins v014 begin
							when 11 => gtk.image.set (img_status, img_dir & "pass.png");
							when 14 => gtk.image.set (img_status, img_dir & "ready.png");
							when others => gtk.image.set (img_status, img_dir & "fail.png");
							-- ins v014 end
						end case;
 						--if result = 1 then 

						gtk.button.set_label (button_start_stop, "START");
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), true);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), true);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), true);
						gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), true);

						while Gtk.Main.Events_Pending loop Dead := Gtk.Main.Main_Iteration; end loop;
 						--	else gtk.image.set (img_status, src_dir & "gui/img/fail.png");
 						--end if;
						test_running := false;
					end if;

				else


					Result := system( "p=$(pidof xterm); kill $p; sleep 1" & ASCII.NUL );

					if result /= 0 then put_line("ERROR : xterm could not be killed !");
					end if;

					--Result := system( "bsmcl off" & ASCII.NUL );

					spawn
						(
						program_name	=> bin_dir & "bsmcl", 
						Args            => 	(
											1=> new String'("off")
											),
						Output_File_Descriptor => Standout,
						Return_Code            => Result
						);


 					--if result = 0 then gtk.image.set (img_status, src_dir & "gui/img/fail.png"); -- rm v014
					if result = 0 then gtk.image.set (img_status, img_dir & "fail.png"); -- ins v014
-- 					--	else gtk.image.set (img_status, src_dir & "gui/img/fail.png");
 					end if;

					gtk.button.set_label (button_start_stop, "START");
					test_running := false;


				--gtk.text_buffer.set_text (textbuf, read_result_file);
				end if;


 			elsif data.all = "LOAD" then

				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), false);

				Gtk.File_Selection.gtk_new (selection_load, title => "Upload Test Sequence");
				gtk.file_selection.Hide_Fileop_Buttons (selection_load);
				gtk.file_selection.show (selection_load);
				gtk.file_selection.complete (selection_load, pattern => "*.load");

				return_handlers.connect
					(
					selection_load, "delete_event",
					-- 1.1a the target function is "delete_event" , see 1.1b
					return_handlers.to_marshaller (delete_load_dialog'access)
					);


				-- this is a handler !
				files_cb.object_connect
					(
					Gtk.File_Selection.Get_Ok_Button (selection_load),  --  The object to connect to the handler
					"clicked",               --  The name of the signal
					files_cb.To_Marshaller (sequence_load_ok'Access),  --  The signal handler
					Slot_Object => selection_load
					);

				-- this is a handler !
				files_cb.object_connect
					(
					Gtk.File_Selection.Get_Cancel_Button (selection_load),  --  The object to connect to the handler
					"clicked",               --  The name of the signal
					files_cb.To_Marshaller (sequence_load_cancel'Access),  --  The signal handler
					Slot_Object => selection_load
					);

				

			elsif data.all = "SELECT" then 
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), false);

				Gtk.File_Selection.gtk_new (selection_sequence, title => "Select Test Sequence");
				gtk.file_selection.Hide_Fileop_Buttons (selection_sequence);
				gtk.file_selection.show (selection_sequence);
				gtk.file_selection.complete (selection_sequence, pattern => "*.test");

				return_handlers.connect
					(
					selection_sequence, "delete_event",
					-- 1.1a the target function is "delete_event" , see 1.1b
					return_handlers.to_marshaller (delete_sequence_dialog'access) 
					);


				-- this is a handler !
				files_cb.object_connect
					(
					Gtk.File_Selection.Get_Ok_Button (selection_sequence),  --  The object to connect to the handler
					"clicked",               --  The name of the signal
					files_cb.To_Marshaller (sequence_select_ok'Access),  --  The signal handler
					Slot_Object => selection_sequence
					);

				-- this is a handler !
				files_cb.object_connect
					(
					Gtk.File_Selection.Get_Cancel_Button (selection_sequence),  --  The object to connect to the handler
					"clicked",               --  The name of the signal
					files_cb.To_Marshaller (sequence_select_cancel'Access),  --  The signal handler
					Slot_Object => selection_sequence
					);

			elsif data.all = "VIEW" then 
					--put_line ("view");

				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), false);

				-- launch external command
				Spawn 
					(  
					--Program_Name           => "/bin/ls",
					program_name			=> bin_dir & "bsmcl",
					Args                   => 	(
												1=> new String'("report")
												),
					--Output_File			   => result_file_name,
					Output_File_Descriptor => Standout,
					--Success				   => success,
					Return_Code            => Result
					);

				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), true);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_load), true);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), true);
				gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), true);


			end if;

		end button_callback;


--	function umask( mask : integer ) return integer;
--		pragma import( c, umask );




begin

--	dummy := umask ( 003 );

	gtk.main.init;

	-- create a new window
	gtk.window.gtk_new (window);

	-- set the window title
	gtk.window.set_title (window, "Boundary Scan Master M-1");

	-- 1. set handler for the DELETE event to immediately exit GTK
	return_handlers.connect
		(
		window, "delete_event",
		-- 1.1a the target function is "delete_event" , see 1.1b
		return_handlers.to_marshaller (delete_event'access) 
		);

	-- set border with of the main window
	gtk.window.set_border_width (window, 20);

	-- create and place background box
	gtk.box.gtk_new_vbox (box_back, false, 0);
	gtk.window.add (window, box_back);

	-- create and place box_uut in box_back
	--gtk.box.gtk_new_hbox (box_uut, false, 0);
	--gtk.box.pack_start (box_back, box_uut, true, true, 0);
	--gtk.box.set_spacing (box_uut, 20);


	-- create and place box_head in box_back
	gtk.box.gtk_new_hbox (box_head, false, 0);
	gtk.box.pack_start (box_back, box_head, true, true, 0);
	gtk.box.set_spacing (box_head, 20);

	-- create and place box_selection in box_head
	gtk.box.gtk_new_vbox (box_selection, false, 0);
	gtk.box.pack_start (box_head, box_selection, true, true, 0);


	-- create "load" button and pack it into box_selection
	gtk.button.gtk_new (button_load, "Upload Test Sequence");
	gtk.box.pack_start (box_selection, button_load, true, true, 5);
	gtk.button.show (button_load);

	-- set handler for "load" button
	handlers.connect
		(
		button_load, "clicked",
		-- 2.1a the target procedure is "button_callback", see 2.1b
		handlers.to_marshaller (button_callback'access),
		new string'("LOAD")
		);


	-- create "select" button and pack it into box_selection
	gtk.button.gtk_new (button_select_sequence, "Select Test Sequence");
	gtk.box.pack_start (box_selection, button_select_sequence, true, true, 5);
	gtk.button.show (button_select_sequence);
	gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_select_sequence), false);

-- 	Gtk.File_Chooser_Button.gtk_new (selection_sequence2, title => "Select Sequence", action => gtk.file_chooser.Action_open);
-- 	gtk.box.pack_start (box_selection, selection_sequence2, true, true, 0);
-- 	gtk.file_chooser_button.show (selection_sequence2);

	-- set handler for "select sequence" button
	handlers.connect
		(
		button_select_sequence, "clicked",
		-- 2.1a the target procedure is "button_callback", see 2.1b
		handlers.to_marshaller (button_callback'access),
		new string'("SELECT")
		);

	-- create and place box_uut in box_selection
	gtk.box.gtk_new_hbox (box_uut, false, 0);
	gtk.box.pack_start (box_selection, box_uut, true, true, 10);
	gtk.box.show (box_uut);

	-- create uut marker label and place it into box_uut
	gtk.label.gtk_new (label_uut_mark, "UUT :");
	gtk.box.pack_start (box_uut, label_uut_mark, false, true, 10);
	gtk.label.show (label_uut_mark);

	-- create uut name label to show selected uut and place it into box_uut
	gtk.label.gtk_new (label_uut_name, " ------------ ");
	gtk.box.pack_start (box_uut, label_uut_name, false, true, 10);
	gtk.label.show (label_uut_name);


	-- create and place box_sequence in box_selection
	gtk.box.gtk_new_hbox (box_sequence, false, 0);
	gtk.box.pack_start (box_selection, box_sequence, true, true, 10);
	gtk.box.show (box_sequence);

	-- create sequence marker label and place it into box_sequence
	gtk.label.gtk_new (label_sequence_mark, "SEQ :");
	gtk.box.pack_start (box_sequence, label_sequence_mark, false, true, 10);
	gtk.label.show (label_sequence_mark);

	-- create label to show selected sequence and place it into box_selection
	gtk.label.gtk_new (label_sequence_name, " ------------ ");
	gtk.box.pack_start (box_sequence, label_sequence_name, false, true, 10);
	gtk.label.show (label_sequence_name);



	-- create another button
	gtk.button.gtk_new (button_start_stop, "START");

	-- 2. set handler for the event: "START" is clicked
	handlers.connect
		(
		button_start_stop, "clicked",
		-- 2.1a the target procedure is "button_callback", see 2.1b
		handlers.to_marshaller (button_callback'access),
		new string'("START")
		);

	-- pack the button "START" into box_head
	gtk.box.pack_start (box_head, button_start_stop, true, true, 0);
	
	-- display "button 2" and disable it
	gtk.button.show (button_start_stop);
	gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_start_stop), false);

	-- create status image box
	--gtk.image.gtk_new (img_status, src_dir & "gui/img/upload_request_startup.png"); -- rm v014
	gtk.image.gtk_new (img_status, img_dir & "upload_request_startup.png"); -- ins v014
	gtk.box.pack_start (box_back, img_status, true, true, 10);
	gtk.image.show (img_status);


	gtk.button.gtk_new (button_report, "View Test Report");
	handlers.connect
		(
		button_report, "clicked",
		handlers.to_marshaller (button_callback'access),
		new string'("VIEW")
		);

	gtk.box.pack_start (box_back, button_report, true, true, 10);
	gtk.button.show (button_report);
	gtk.widget.set_sensitive ( Gtk.Widget.Gtk_Widget (button_report), false);


	-- create label to show program version 
	gtk.label.gtk_new (label_version, "M-1 GUI V" & version & " / Blunk electronic / support : info@blunk-electronic.de");
	gtk.box.pack_start (box_back, label_version, true, true, 0);
	gtk.label.show (label_version);



	-- create scrolled window and pack it into box1
	--gtk.scrolled_window.Gtk_New (scrolled);
	--gtk.box.pack_start (box_back, scrolled);



	--if font = Gdk.Font.Null_Font then Ada.Text_IO.Put_Line ("Error: Could not open font"); end if;

	-- create a text buffer
	--gtk.text_buffer.gtk_new (textbuf);
	--tag1 := gtk.text_buffer.create_tag(textbuf,"testtag");
	--gtk.text_buffer.text_property("Utopia");

	-- create a textbox with the text buffer inside
	--gtk.text_view.gtk_new (textbox, textbuf);


	-- set size of textbox
	--gtk.text_view.set_usize (textbox, 400, 100);

	-- disable editing of the textbox
	--gtk.text_view.set_editable (textbox, false);

	-- pack textbox into scrolled window
	--gtk.scrolled_window.add (scrolled, textbox);

	-- set startup text 
	--gtk.text_buffer.set_text (textbuf, " IDLE ");

	-- show scrolled window
	--gtk.scrolled_window.set_placement (	scrolled, corner_top_left);
	--gtk.scrolled_window.show (scrolled);

	-- show textbox
	--gtk.text_view.show (textbox);

	-- gdk.font.load (font => font, font_name => "Utopia");

	-- display "box1"
	gtk.box.show (box_back);
	--gtk.box.show (box_uut);
	gtk.box.show (box_head);

	gtk.box.show (box_selection);

	gtk.window.show (window);
	gtk.main.main;


end gm1;