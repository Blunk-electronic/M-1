------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 DATABASE COMPONENTS                        --
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
--   todo:


with ada.text_io;					use ada.text_io;
-- with ada.strings.unbounded; 		use ada.strings.unbounded;
--with ada.strings.bounded; 			use ada.strings.bounded;
-- with ada.strings.unbounded.text_io; use ada.strings.unbounded.text_io;

with ada.strings; 					use ada.strings;
-- with ada.strings.fixed;				use ada.strings.fixed;
with ada.characters;				use ada.characters;
with ada.characters.handling;		use ada.characters.handling;
-- with ada.characters.latin_1;		use ada.characters.latin_1;

-- with ada.containers;                use ada.containers;
-- with ada.containers.vectors;

-- with gnat.os_lib;   				use gnat.os_lib;
with ada.directories;				use ada.directories;
with ada.exceptions;

with m1_base;						use m1_base;
with m1_string_processing;			use m1_string_processing;
with m1_files_and_directories; 		use m1_files_and_directories;
with m1_test_gen_and_exec;			use m1_test_gen_and_exec;

package body m1_database is

	function get_secondary_nets (name_net : in type_net_name.bounded_string) return type_list_of_secondary_net_names.vector is
	-- Returns a list of secondary nets connected to the given primary net.
	-- If there are no secondary nets, an empty list is returned.
		l	: type_list_of_secondary_net_names.vector;
		net	: type_net;
		net_cursor : type_list_of_nets.cursor := first(list_of_nets);
	begin
		--for n in 1..type_list_of_nets.length(list_of_nets) loop
		while net_cursor /= type_list_of_nets.no_element loop
			--net := type_list_of_nets.element(list_of_nets,positive(n));
			net := element(net_cursor);
			--if net.name = name_net then
			if key(net_cursor) = name_net then
				if net.level = primary then
					return net.secondary_net_names;
				end if;
			end if;
		end loop;

		-- if loop finished, net has not been found in database or is not a primary net
		write_message (
			file_handle => current_output,
			text => message_error & "Primary net " & type_net_name.to_string(name_net) 
				& " not found in " & text_identifier_database & " !",
			console => true);
		raise constraint_error;

		return l; -- this code should be never reached, but is required for compiliation
	end get_secondary_nets;

	function query_render_net_class (
	-- Returns true if class rendering is allowed for net primary_net_name.
	-- Messages are directed in logfile according to action.
		--primary_net_name 					: in type_net_name.bounded_string; -- the net it is about
		primary_net_cursor 					: in type_list_of_nets.cursor; -- the net it is about
		primary_net_class					: in type_net_class; -- requested net class
		list_of_secondary_net_names			: in type_list_of_secondary_net_names.vector -- the secondary nets of the primary net in question -- CS: should be a map
		) return boolean is	
		net 								: type_net;
-- 		net_found							: boolean := false;
		pin_found							: boolean := false;
		output2_pin_without_disable_spec_ct	: natural := 0;
		secondary_with_inputs				: boolean := false;

		secondary_net_count : natural := natural(length(list_of_secondary_net_names));

		procedure put_error_on_invalid_class( net_name : in type_net_name.bounded_string; class : in type_net_class) is
		begin
			write_message (
				file_handle => current_output,
				text => "Class " & type_net_class'image(class) & " not allowed for net " &
					to_string(net_name) & " !",
				console => true);
			raise constraint_error;
		end put_error_on_invalid_class;

		procedure put_warning_on_missing_input_pin( net_name : in type_net_name.bounded_string; class : in type_net_class) is
		begin
			put_line(message_warning & "Class " & type_net_class'image(class) & " net " 
				& to_string(net_name) & " has no input pins to measure state ! (SR2)");
		end put_warning_on_missing_input_pin;

		function secondary_net_has_input_pin ( net_name : in type_net_name.bounded_string) return boolean is
-- 			net_found		: boolean := false;
			input_found		: boolean := false;
			net				: type_net;
		begin
-- 			for n in 1..type_list_of_nets.length(list_of_nets) loop
-- 				net := type_list_of_nets.element(list_of_nets,positive(n));
-- 				if to_string(net.name) = net_name then
-- 					net_found := true;
				net := element(list_of_nets, net_name);
					if net.bs_capable then
						-- HR10 : secondary nets must not have output pins without disable specification 
						if (net.bs_bidir_pin_count > 0 or net.bs_output_pin_count > 0) then
							for p in 1..type_list_of_pins.length(net.pins) loop
								--pin := type_list_of_pins.element(net.pins,positive(p));
								-- NOTE: type_list_of_pins.element(net.pins,positive(p)) equals the particular pin
								if type_list_of_pins.element(net.pins,positive(p)).is_bscan_capable then
									if type_list_of_pins.element(net.pins,positive(p)).cell_info.control_cell_id = -1 then
										write_message (
											file_handle => current_output,
											text => message_error & "Net " & to_string(net_name) 
												& " has a pin without disable specification. It can not become a secondary net ! (HR10)",
											console => true);
										--put_error_on_invalid_class(primary_net_name,primary_net_class);
										put_error_on_invalid_class(key(primary_net_cursor),primary_net_class);
									end if;
								end if;
							end loop;
						end if;

						-- SR7: secondary nets should have input pins
						if (net.bs_bidir_pin_count > 0 or net.bs_input_pin_count > 0) then
							input_found := true;
						end if;
					else
						-- net is not scan capable, hence no bs-inputs present
						--put_warning_on_missing_input_pin(net_name, primary_net_class); -- CS: warning really required ?
						input_found := false;
					end if;
-- 					exit;
-- 				end if;
-- 			end loop;

-- 			if not net_found then
-- 				write_message (
-- 					file_handle => current_output,
-- 					text => message_error & "Secondary net " & to_string(net_name)
-- 						& " not found in " & text_identifier_database & " !",
-- 					console => true);
-- 				raise constraint_error;
-- 			end if;

			return input_found;
		end secondary_net_has_input_pin;
	
		function secondary_nets_exist return boolean is
		-- Reads list of secondary nets one by one, and checks if this net does appear in database.
			net			: type_net;
			net_found	: boolean := false;
		begin
			for s in 1..secondary_net_count loop -- loop as many times as there are secondary nets
				net_found := false; -- reset "net found flag"
				-- loop though net list until begin of list reached
-- 				for n in 1..type_list_of_nets.length(list_of_nets) loop
-- 					net := type_list_of_nets.element(list_of_nets,positive(n));
-- 					if net.name = element(list_of_secondary_net_names, s) then -- on match of net name
-- 						net_found := true; -- set "net found flag"
-- 						exit; -- no more seaching required
-- 					end if;
-- 				end loop;
				if contains(list_of_nets, element(list_of_secondary_net_names, s)) then
					net_found := true;
				end if;

				-- evaluate "net found flag"
				if net_found then
					null; -- fine
				else
					put_line(message_error & "Net " & 
						to_string(element(list_of_secondary_net_names, s) &
						" not found in " & text_identifier_database & " !"));
					raise constraint_error;
				end if;

			end loop;
			return true;
		end secondary_nets_exist;
		
	begin -- query_render_net_class
-- 		for n in 1..length(list_of_nets) loop
-- 			net := element(list_of_nets,positive(n));
-- 		
-- 			if to_string(net.name) = primary_net_name then
-- 				net_found := true;
		net := element(primary_net_cursor);
				-- if secondary nets attached, make sure they exist
				if secondary_net_count /= 0 then
					if secondary_nets_exist then
						null;
					end if;
				end if;

				if net.bs_capable then

					case primary_net_class is
						when NA => null; -- all nets can be changed to class NA
						when others =>

							-- SR2: primary nets of this class should have input pins
							if net.bs_input_pin_count > 0 or net.bs_bidir_pin_count > 0 then
								null; -- fine
							else
								if secondary_net_count = 0 then -- if there are no secondary nets:
									-- put_warning_on_missing_input_pin(primary_net_name, primary_net_class);
									put_warning_on_missing_input_pin(key(primary_net_cursor), primary_net_class);
								else
								-- SR2.2: if there are secondary nets, at least one of them should have an input pin
									secondary_with_inputs := false;
									for s in 1..secondary_net_count loop
										if secondary_net_has_input_pin( element(list_of_secondary_net_names, s)) then
											secondary_with_inputs := true;
											exit; -- no more input pin search in remaining secondary nets required
										end if;
									end loop;
									if not secondary_with_inputs then
-- 										put_line(message_warning & "Neither primary net " & to_string(primary_net_name) 
-- 											& " nor any of its secondary nets "
-- 											& "has input pins to measure state ! (SR2.2)");
-- 										put_line("Net " & to_string(primary_net_name) & " can neither be tested for "
-- 											& type_fault'image(open) & " nor for " & type_fault'image(short) & " !");
										put_line(message_warning & "Neither primary net " & to_string(key(primary_net_cursor)) 
											& " nor any of its secondary nets "
											& "has input pins to measure state ! (SR2.2)");
										put_line("Net " & to_string(key(primary_net_cursor)) & " can neither be tested for "
											& type_fault'image(open) & " nor for " & type_fault'image(short) & " !");
												 
									end if;
								end if;
							end if;
					end case;

					case primary_net_class is
						when EL | EH => 
							-- HR2.1: primary nets of this class having no secondary nets must have input or bidir pins 
							if net.bs_input_pin_count > 0 or net.bs_bidir_pin_count > 0 then
								null; -- fine
							else
								if secondary_net_count = 0 then -- if there are no secondary nets:
									write_message (
										file_handle => current_output,
										--text => message_error & "Net " & to_string(primary_net_name) & " has no input pins to measure state ! (HR2.1)",
										text => message_error & "Net " & to_string(key(primary_net_cursor)) 
											& " has no input pins to measure state ! (HR2.1)",
										console => true);
									--put_error_on_invalid_class(primary_net_name,primary_net_class);
									put_error_on_invalid_class(key(primary_net_cursor),primary_net_class);
								else
								-- HR2.2.1: if there are secondary nets, at least one of them must have an input pin
									secondary_with_inputs := false;
									for s in 1..secondary_net_count loop
										if secondary_net_has_input_pin( element(list_of_secondary_net_names,s)) then
											secondary_with_inputs := true;
											exit; -- no more input pin search in remaining secondary nets required
										end if;
									end loop;
									if not secondary_with_inputs then
										write_message (
											file_handle => current_output,
											--text => message_error & "Neither primary net " & to_string(primary_net_name)
											text => message_error & "Neither primary net " & to_string(key(primary_net_cursor)) 
												& " nor any of its secondary nets "
												& "has input pins to measure state ! (HR2.2.1)",
											console => true);
										raise constraint_error;
									end if;
								end if;
							end if;
						when others => null;
					end case;

					case primary_net_class is
						when EL | EH | PU | PD | NA =>
							-- HR1: primary nets of this class must not have any output2 pins without disable specification
							for p in 1..length(net.pins) loop
								--pin := element(net.pins, positive(p));
								-- NOTE: element(net.pins, positive(p)) equals the particular pin
								if element(net.pins, positive(p)).is_bscan_capable then
									if element(net.pins, positive(p)).cell_info.output_cell_function = output2 then
										if element(net.pins, positive(p)).cell_info.control_cell_id = -1 then -- means, there is no control cell
											write_message (
												file_handle => current_output,
												--text => message_error & "Net '" & to_string(primary_net_name)
												text => message_error & "Net '" & to_string(key(primary_net_cursor)) 
													 & "' has output pins that can not be disabled ! (HR1)",
												console => true);
											--put_error_on_invalid_class(primary_net_name,primary_net_class);
											put_error_on_invalid_class(key(primary_net_cursor),primary_net_class);
										end if;
									end if;
								end if;
							end loop;
						when others => null;
					end case;

					case primary_net_class is
						when DH | DL | NR =>
							-- SR3.x : lonely pin rules checks:

							-- if there is only one bidir pin
							if (net.bs_bidir_pin_count = 1 and net.bs_input_pin_count = 0 and net.bs_output_pin_count = 0) then
								if secondary_net_count = 0 then -- if there are no secondary nets:

									--put_line(message_warning & "Net " & to_string(primary_net_name)
									put_line(message_warning & "Net " & to_string(key(primary_net_cursor)) 
										& " can not be tested for " & type_fault'image(open) & " ! (SR3.1)");
								else
									secondary_with_inputs := false;
									for s in 1..secondary_net_count loop
										if secondary_net_has_input_pin( element(list_of_secondary_net_names,s)) then
											secondary_with_inputs := true;
											exit; -- no more input pin search in remaining secondary nets required
										end if;
									end loop;
									if not secondary_with_inputs then
										--put_line("WARNING: Neither primary net '" & primary_net_name & "' nor any of its secondary nets "
										--	& "has input pins to measure state. They can not be tested for '" & type_fault'image(open) & "' ! (SR3.1)");
-- 										put_line("WARNING: Neither primary net '" & to_string(primary_net_name) 
-- 											& "' nor any of its secondary nets "
-- 											& "can be tested for '" & type_fault'image(open) & "' ! (SR3.1)");

										--put_line(message_warning & "neither primary net " & to_string(primary_net_name)
										put_line(message_warning & "neither primary net " & to_string(key(primary_net_cursor)) 
											& " nor any of its secondary nets can be tested for " 
											& type_fault'image(open) & " ! (SR3.1)");
									end if;
								end if;

							-- if there is only one output pin
							elsif (net.bs_bidir_pin_count = 0 and net.bs_input_pin_count = 0 and net.bs_output_pin_count = 1) then
								if secondary_net_count = 0 then -- if there are no secondary nets:
-- 									put_line(message_warning & "Net '" & to_string(primary_net_name) & "' can neither be tested for '" 
-- 											 & type_fault'image(open) & "' nor for '" & type_fault'image(short) & "' ! (SR3.2)");

									--put_line(message_warning & "Net " & to_string(primary_net_name) & " can neither be tested for "
									put_line(message_warning & "Net " & to_string(key(primary_net_cursor)) & " can neither be tested for " 
										& type_fault'image(open) & " nor for " & type_fault'image(short) & " ! (SR3.2)");

								else
									secondary_with_inputs := false;
									for s in 1..secondary_net_count loop
										if secondary_net_has_input_pin( element(list_of_secondary_net_names,s)) then
											secondary_with_inputs := true;
											exit; -- no more input pin search in remaining secondary nets required
										end if;
									end loop;
									if not secondary_with_inputs then
-- 										put_line("WARNING: Neither primary net '" & primary_net_name & "' nor any of its secondary nets "
-- 											& "has input pins to measure state. They can neither be tested for '" 
-- 											& type_fault'image(open) & "' nor for '" & type_fault'image(short) & "' ! (SR3.2)");
--										put_line(message_warning & "Neither primary net " & to_string(primary_net_name) & " nor any of its secondary nets "
										put_line(message_warning & "Neither primary net " & to_string(key(primary_net_cursor)) & " nor any of its secondary nets "												 
											& "can be tested for " 
											& type_fault'image(open) & " or for " & type_fault'image(short) & " ! (SR3.2)");
									end if;
								end if;
							end if;

						when others => null;
					end case;

					case primary_net_class is
						when NR | DH | DL =>
							-- HR4.2A: nets of this class must have at least one output pin -- CS: not tested yet
							if (net.bs_bidir_pin_count > 0 or net.bs_output_pin_count > 0) then

								-- SR4.1, 5.1, 6.1 : primary nets of this class must not have more than one output2 pin without disable specification
								-- otherwise a design warning is to output
								if (net.bs_bidir_pin_count > 1 or net.bs_output_pin_count > 1) then
									output2_pin_without_disable_spec_ct	:= 0;
									for p in 1..length(net.pins) loop
										--pin := element(net.pins, positive(p));
										-- NOTE: element(net.pins, positive(p)) equals the particular pin
										if element(net.pins, positive(p)).is_bscan_capable then
											if element(net.pins, positive(p)).cell_info.output_cell_function = output2 then
												if element(net.pins, positive(p)).cell_info.control_cell_id = -1 then -- means, there is no control cell for that pin
													output2_pin_without_disable_spec_ct := output2_pin_without_disable_spec_ct + 1;
													if output2_pin_without_disable_spec_ct > 1 then
													-- put_line(message_warning & "Net " & to_string(primary_net_name)
														put_line(message_warning & "Net " & to_string(key(primary_net_cursor)) 
															& " has more than one output2 pin that can not be disabled ! (SR4.1)");
														exit;
													end if;
												end if;
											end if;
										end if;
									end loop;
								end if;

							else
								write_message (
									file_handle => current_output,
									--text => message_error & "Net " & to_string(primary_net_name) & " has no output pins ! (HR4.2A)",
									text => message_error & "Net " & to_string(key(primary_net_cursor)) & " has no output pins ! (HR4.2A)",
									console => true);
								--put_error_on_invalid_class(primary_net_name,primary_net_class);
								put_error_on_invalid_class(key(primary_net_cursor),primary_net_class);
							end if;

						when others => null;
					end case;

					case primary_net_class is
						when NR =>
							-- HR4.2 : if there is only one driver pin, primary nets of this class must not have self controlled output cell 
							if (net.bs_bidir_pin_count = 1 or net.bs_output_pin_count = 1) then
								for p in 1..length(net.pins) loop
									--pin := element(net.pins, positive(p));
									-- NOTE: element(net.pins, positive(p)) equals the particular pin
									if element(net.pins, positive(p)).is_bscan_capable then

										-- if there is a control and an output cell, and if they have the same id, it is a self controlled output cell
										-- pins having no control and no output cell must be excluded from this check
										if element(net.pins, positive(p)).cell_info.output_cell_id /= -1 then -- if there is an output cell
											if element(net.pins, positive(p)).cell_info.control_cell_id = element(net.pins, positive(p)).cell_info.output_cell_id then
												write_message (
													file_handle => current_output,
													-- text => message_error & "Net " & to_string(primary_net_name)
													text => message_error & "Net " & to_string(key(primary_net_cursor)) 
														 & " has a pin with a self controlled output cell ! (HR4.2)",
													console => true);
												--put_error_on_invalid_class(primary_net_name,primary_net_class);
												put_error_on_invalid_class(key(primary_net_cursor),primary_net_class);
											end if;
										end if;

									end if;
								end loop;
							end if;
						when others => null;
					end case;

					case primary_net_class is
						when PU | PD =>
							-- HR7.1, HR8.1 : there must be at least one bidir or output pin with disable specification
							-- NOTE: HR1 has been checked above, so the outputs in the net have disable specs.
							pin_found := false; -- reset this flag from previous checks
							if (net.bs_bidir_pin_count > 0 or net.bs_output_pin_count > 0) then
								for p in 1..length(net.pins) loop
									--pin := element(net.pins, positive(p));
									-- NOTE: element(net.pins, positive(p)) equals the particular pin
									if element(net.pins, positive(p)).is_bscan_capable then -- check scan capable pins only
										
										if element(net.pins, positive(p)).cell_info.output_cell_id /= -1 then -- if there is an output cell
											if element(net.pins, positive(p)).cell_info.control_cell_id /= -1 then -- if there is a control cell (already ensured by HR1)

												-- if self controlled output cell, check disable result
												-- if control and output cell have the same id, it is a self controlled output cell
												if element(net.pins, positive(p)).cell_info.control_cell_id = element(net.pins, positive(p)).cell_info.output_cell_id then

													case primary_net_class is
														when PU =>
															if element(net.pins, positive(p)).cell_info.disable_result = weak1 
															or element(net.pins, positive(p)).cell_info.disable_result = pull1
															or element(net.pins, positive(p)).cell_info.disable_result = z
															then 
																pin_found := true; -- fine
															end if;
														when PD =>
															if element(net.pins, positive(p)).cell_info.disable_result = weak0 
															or element(net.pins, positive(p)).cell_info.disable_result = pull0
															or element(net.pins, positive(p)).cell_info.disable_result = z
															then 
																pin_found := true; -- fine
															end if;
														when others => null;
													end case;

												else -- it is a non-self controlling output cell
													pin_found := true; -- fine

													-- check for disable results according to net class PD/PU
													case primary_net_class is
														when PD => -- in PD nets there should not be any pull-up resistance
															if element(net.pins, positive(p)).cell_info.disable_result = weak1 
															or element(net.pins, positive(p)).cell_info.disable_result = pull1
															then 
																--put_line(message_warning & "Net " & to_string(primary_net_name) 
																put_line(message_warning & "Net " & to_string(key(primary_net_cursor)) 
																& " has a driver pin with disable result that contradicts net class !");
															end if;
														when PU => -- in PU nets there should not be any pull-down resistance
															if element(net.pins, positive(p)).cell_info.disable_result = weak0 
															or element(net.pins, positive(p)).cell_info.disable_result = pull0
															then 
															--put_line(message_warning & "Net " & to_string(primary_net_name) 
																put_line(message_warning & "Net " & to_string(key(primary_net_cursor)) 
																& " has a driver pin with disable result that contradicts net class !");
															end if;
														when others => null;
													end case;

												end if;

											else  -- this code should never be reached at all !
												write_message (
													file_handle => current_output,
													text => message_error & "No control cell found ! (HR1)",
													console => true);
												--put_error_on_invalid_class(primary_net_name,primary_net_class);
												put_error_on_invalid_class(key(primary_net_cursor),primary_net_class);
											end if;
										end if;
									end if;
								end loop;
								if not pin_found then
									write_message (
										file_handle => current_output,
										--text => message_error & "Net " & to_string(primary_net_name)
										text => message_error & "Net " & to_string(key(primary_net_cursor)) 
											 & " has no driver pins with suitable disable results ! (HR7.1, HR 8.1)",
										console => true);									
									-- put_error_on_invalid_class(primary_net_name,primary_net_class);
									put_error_on_invalid_class(key(primary_net_cursor),primary_net_class);
								end if;
							else
								write_message (
									file_handle => current_output,
									--text => message_error & "Net " & to_string(primary_net_name) & " has no output pins ! (HR7.1, HR 8.1)",
									text => message_error & "Net " & to_string(key(primary_net_cursor)) 
										& " has no output pins ! (HR7.1, HR 8.1)",
									console => true);									
								--put_error_on_invalid_class(primary_net_name,primary_net_class);
								put_error_on_invalid_class(key(primary_net_cursor),primary_net_class);
							end if;
						when others => null;
					end case;

				else
					-- non-bscan nets must be in class NA. Other class requests result in an error:
					if primary_net_class /= NA then
						write_message (
							file_handle => current_output,
							--text => message_error & "Net " & to_string(primary_net_name) & " has no bscan capable pins !",
							text => message_error & "Net " & to_string(key(primary_net_cursor)) & " has no bscan capable pins !",
							console => true);
						--put_error_on_invalid_class(primary_net_name,primary_net_class);
						put_error_on_invalid_class(key(primary_net_cursor),primary_net_class);
					end if;
				end if;
-- 				exit;
-- 			end if;
-- 		end loop;
-- 
-- 		if net_found then
-- 			null; -- fine
-- 		else
-- 			write_message (
-- 				file_handle => current_output,
-- 				text => message_error & "Primary net " & to_string(primary_net_name) 
-- 					& " not found in " & text_identifier_database & " !",
-- 				console => true);
-- 			raise constraint_error;
-- 		end if;

		return true;
	end query_render_net_class;

	procedure verify_net_classes is
	-- Locates primary nets in net list and passes them to query_render_net_class.
	-- NOTE: this procedure is local. no specification
		net : type_net;
		net_cursor : type_list_of_nets.cursor := first(list_of_nets);
	begin
		put_line(" verifying net classes ...");
		--for n in 1..length(list_of_nets) loop
		while net_cursor /= type_list_of_nets.no_element loop
			--net := element(list_of_nets, positive(n));
			net := element(net_cursor);
			
			if net.level = primary then
				if net.bs_capable then
					-- check if class requirement of the primary net and its secondary nets can be fulfilled
					-- NOTE: This is a compound of primary and secondary nets !
					if query_render_net_class (
						--primary_net_name => net.name, -- pass name of primary net
						primary_net_cursor => net_cursor, -- pass name of primary net
						primary_net_class => net.class, -- pass class of primary net (seondary nets inherit class of primary net)
						list_of_secondary_net_names	=> net.secondary_net_names -- pass list of seondary net names
						--secondary_net_count	=> net.secondary_net_ct -- pass number of secondary nets
						) then 
							null;
					end if;
				end if;
			end if;
			
			next(net_cursor);
		end loop;
	end verify_net_classes;

	function instruction_present(instruction_in : type_string_of_bit_characters_class_1) return boolean is
	-- returns false if given instruction opcode contains no 1 and no 0
	begin
		for c in 1..instruction_in'last loop
			case instruction_in(c) is
				when '0' => return true;
				when '1' => return true;
				when others => null;
			end case;
		end loop;
		return false;
	end instruction_present;

	function drive_value_derived_from_class (class_given : type_net_class) return type_bit_char_class_0 is
	begin
		case class_given is
			when DL | PU => return '0';
			when DH | PD => return '1';
			when others =>
				write_message (
					file_handle => current_output,
					text => message_error & "A drive value can only be derived from classes DL, DH, PD or PU !",
					console => true);
				raise constraint_error;
		end case;
	end drive_value_derived_from_class;

	function expect_value_derived_from_class (class_given : type_net_class) return type_bit_char_class_0 is
	begin
		case class_given is
			when EL | DL => return '0';
			when EH | DH => return '1';
			when others =>
				write_message (
					file_handle => current_output,
					text => message_error & "An expect value can only be derived from classes DL, DH, EL or EH !",
					console => true);
				raise constraint_error;
		end case;
	end expect_value_derived_from_class;
	
	function inverted_status_derived_from_class_and_disable_value (
		class 			: in type_net_class;
		disable_value	: in type_bit_char_class_0) return boolean is
	begin
		case class is
			when PD =>
				if disable_value = '0' then 
					-- a disable value of 0, causes the pin to go L
					return false; --> no inversion required
				else
					-- a disable value of 1, causes the pin to go L
					return true; -- inversion is required
				end if;

			when PU =>
				if disable_value = '0' then 
					-- a disable value of 0, causes the pin to go H
					return true; -- inversion is required
				else
					-- a disable value of 1, causes the pin to go H
					return false; --> no inversion required
				end if;

			when others =>
				write_message (
					file_handle => current_output,
					text => message_error & "An inverted status can only be derived from class PD or PU !",
					console => true);
				raise constraint_error;
		end case;
	end inverted_status_derived_from_class_and_disable_value;

	function disable_value_derived_from_class_and_inverted_status(
		class_given : type_net_class;
		inverted_given : boolean) return type_bit_char_class_0 is
	begin
		case class_given is
			when PU =>
				if inverted_given then
					return '0';
				else 
					return '1';
				end if;
			when PD =>
				if inverted_given then
					return '1';
				else 
					return '0';
				end if;
			when others =>
				write_message (
					file_handle => current_output,
					text => message_error & "A disable value can only be derived from class PD or PU !",
					console => true);
				raise constraint_error;
		end case;
	end disable_value_derived_from_class_and_inverted_status;


	procedure print_bic_info (bic_name : in type_device_name.bounded_string) is
		bic			: type_bscan_ic;
		bsr_bit		: type_bit_of_boundary_register;
		io			: type_port;
		pp			: type_port_pin;
	begin
		new_line;
		put_line("BIC (BSCAN-IC) INFO");
		put_line("---------------------------------");

		if contains(list_of_bics, bic_name) then
			bic := element(list_of_bics, bic_name);

-- 			put_line("  id          :" & positive'image(positive(b)));
			put_line("  name        : " & to_string(bic_name));
			put_line("  package     : " & to_string(bic.housing));
			put_line("  model file  : " & to_string(bic.model_file));
			put_line("  options     : " & to_string(bic.options));
			put_line("  value       : " & to_string(bic.value));
			put_line("  chain       :" & positive'image(bic.chain));
			put_line("  position    :" & positive'image(bic.position));
			put_line("  length ir   :" & positive'image(bic.len_ir));
			put     ("  capture ir  : "); put_binary_class_1(bic.capture_ir,current_output); new_line;
			put     ("  op bypass   : "); put_binary_class_1(bic.opc_bypass,current_output); new_line;
			put     ("  op extest   : "); put_binary_class_1(bic.opc_extest,current_output); new_line;
			if instruction_present(bic.opc_sample) then 
				put ("  op sample   : "); put_binary_class_1(bic.opc_sample,current_output); new_line;
			end if;
			if instruction_present(bic.opc_idcode) then 
				put ("  op idcode   : "); put_binary_class_1(bic.opc_idcode,current_output); new_line;
			end if;
			if instruction_present(bic.opc_usercode) then 
				put ("  op usercode : "); put_binary_class_1(bic.opc_usercode,current_output); new_line;
			end if;
			if instruction_present(bic.opc_highz) then 
				put ("  op highz    : "); put_binary_class_1(bic.opc_highz,current_output); new_line;
			end if;
			if instruction_present(bic.opc_clamp) then 
				put ("  op clamp    : "); put_binary_class_1(bic.opc_clamp,current_output); new_line;
			end if;
			if instruction_present(bic.opc_intest) then 
				put ("  op intest   : "); put_binary_class_1(bic.opc_intest,current_output); new_line;
			end if;
			put_line("  length bsr  :" & positive'image(bic.len_bsr));
				
			put_line ("  boundary register description :");
			for i in 1..length(bic.boundary_register) loop
				bsr_bit := element(bic.boundary_register, positive(i));
				put("   cell id" & type_cell_id'image(bsr_bit.id) & row_separator_0 &
					"type " & type_boundary_register_cell'image(bsr_bit.cell_type) & row_separator_0 &
					"port " & to_string(bsr_bit.port) & row_separator_0 &
					"function " & type_cell_function'image(bsr_bit.cell_function) & row_separator_0 &
					"safe val " & strip_quotes(type_bit_char_class_1'image(bsr_bit.cell_safe_value)));
				if bsr_bit.control_cell_id /= -1 then
					put_line(row_separator_0 &
					"ctrl cell" & type_cell_id'image(bsr_bit.control_cell_id) & row_separator_0 &
					"dis val " & strip_quotes(type_bit_char_class_0'image(bsr_bit.disable_value)) & row_separator_0 &
					"dis rslt " & type_disable_result'image(bsr_bit.disable_result) 
					);
				else
					new_line;
				end if;
			end loop;

			put_line ("  port io map :");
			for i in 1..length(bic.port_io_map) loop
				io := element(bic.port_io_map, positive(i));
				put("   name " & to_string(io.name) & row_separator_0 &
					"direction " & type_port_direction'image(io.direction) & row_separator_0 &
					"vectored " & boolean'image(io.is_vector));
				if io.is_vector then
					put_line(row_separator_0 & 
					"start" & positive'image(io.index_start) & row_separator_0 & 
					"orientation " & type_vector_orientation'image(io.vector_orientation) & row_separator_0 & 
					"end" & positive'image(io.index_end) & row_separator_0 &
					"lenght" & positive'image(io.vector_length) & row_separator_0
					);
				else
					new_line;
				end if;
			end loop;

			put_line ("  port pin map :");
			for i in 1..length(bic.port_pin_map) loop
				pp := element(bic.port_pin_map, positive(i));
				put("   name " & to_string(pp.port_name) & row_separator_0 &
					"pin count" & positive'image(positive(length(pp.pin_names))) & row_separator_0 & "pin name(s) " );
				for p in 1..length(pp.pin_names) loop
					put(to_string( element(pp.pin_names,positive(p)) ) & row_separator_0);
				end loop;
				new_line;
			end loop;

			new_line;

		else
			put_line(message_error & "specified device either does not support boundary scan or is not in " & text_identifier_database & " !");
		end if;
	end print_bic_info;

	procedure print_scc_info (bic_name : in type_device_name.bounded_string ; control_cell_id : in type_cell_id) is
		use type_list_of_shared_control_cells;
		use type_list_of_nets_with_shared_control_cell;
		
		net_with_shared_control_cell	: type_net_with_shared_control_cell;
		shared_control_cell_with_nets	: type_shared_control_cell_with_nets;
		bic_with_shared_control_cell	: type_bic_with_shared_control_cell;
		bic 							: type_bscan_ic;
-- 		bic_found						: boolean := false;		
	begin
		new_line;
		put_line("SHARED CONTROL CELL (SCC) INFO");
		put_line(column_separator_0);

		if contains(list_of_bics, bic_name) then
			bic := element(list_of_bics, bic_name);

-- 		loop_through_bic_list:
-- 
--         for b in 1..length(list_of_bics) loop
-- 			bic := element(list_of_bics, positive(b));
--             if to_string(bic.name) = bic_name then
		
-- 			bic_found := true;
			if control_cell_id < bic.len_bsr then

				loop_cc_journal:
				for j in 1..length(shared_control_cell_journal) loop
					bic_with_shared_control_cell := element(shared_control_cell_journal, positive(j));
					if bic_with_shared_control_cell.name = bic_name then
						put_line("BIC name       : " & to_string(bic_name));
						for c in 1..length(bic_with_shared_control_cell.cells) loop
							shared_control_cell_with_nets := element(bic_with_shared_control_cell.cells, positive(c));
							if shared_control_cell_with_nets.cell_id = control_cell_id then
								put_line("control cell   :" & type_cell_id'image(control_cell_id));
								put     ("shared by nets : ");

								for n in 1..length(shared_control_cell_with_nets.nets) loop
									net_with_shared_control_cell := element(shared_control_cell_with_nets.nets, positive(n));
									put(to_string(net_with_shared_control_cell.name) & row_separator_0);
								end loop;
								new_line;
								exit loop_cc_journal;
							end if;
						end loop;
						put_line("Specified cell" & type_cell_id'image(control_cell_id) & " is not shared by any net.");
						exit loop_cc_journal;
					end if;
				end loop loop_cc_journal;
				new_line;
				put_line("Specified device does not have any shared control cells.");
-- 				exit loop_through_bic_list;
			else
				put_line(message_error & "Specified cell" & type_cell_id'image(control_cell_id) & " not found in boundary register !");
			end if;

-- 		end loop loop_through_bic_list;
-- 		if not bic_found then
-- 			put_line(message_error & "specified device either does not support boundary scan or is not in " & text_identifier_database & " !");
		else
-- 			null;
			put_line(message_error & "specified device either does not support boundary scan or is not in " & text_identifier_database & " !");
		end if;
	end print_scc_info;

	function is_scanport_active (id : type_scanport_id) return boolean is
	-- returns true if scanport with given id is maked active
	begin
		if type_list_of_scanports.element(list_of_scanports, id).active then
			return true;
		end if;
		return false;
	end is_scanport_active;

	function number_of_active_scanports return natural is
	-- returns the number of active scanpaths
		n : natural := 0;
	begin
		if length(list_of_scanports) > 0 then -- if there are scanports at all
		for i in 1..length(list_of_scanports) loop
				-- count those with the active flag set
				if element(list_of_scanports, positive(i)).active then 
					n := n + 1;
				end if;
			end loop;
		end if;
		return n;
	end number_of_active_scanports;
		
	function is_shared (bic_name : in type_device_name.bounded_string; control_cell_id : in type_cell_id) return boolean is
	-- returns true if given bic exists and control cell is shared
		use type_list_of_shared_control_cells;

		shared_control_cell_with_nets	: type_shared_control_cell_with_nets;
		bic_with_shared_control_cell	: type_bic_with_shared_control_cell;
		bic								: type_bscan_ic;
	begin -- is_shared
--         -- loop through bic list
--         for b in 1..length(list_of_bics) loop    
-- 			--if b.name = bic_name then -- given ic is a bic
-- 			bic := element(list_of_bics, positive(b));
--             if to_string(bic.name) = bic_name then
		if contains(list_of_bics, bic_name) then
			bic := element(list_of_bics, bic_name);

			-- loop through shared control cell journal pointed to by j
			for j in 1..length(shared_control_cell_journal) loop
				bic_with_shared_control_cell := element(shared_control_cell_journal, positive(j));
				if bic_with_shared_control_cell.name = bic_name then -- given bic has shared control cells
					for c in 1..length(bic_with_shared_control_cell.cells) loop
						shared_control_cell_with_nets := element(bic_with_shared_control_cell.cells, positive(c));
						if shared_control_cell_with_nets.cell_id = control_cell_id then -- given cell is shared
							return true; -- so quit searching and return to calling program
						end if;
					end loop;
				end if; -- given bic has shared control cells
			end loop;
			
			return false;
		else
			return false;
		end if;
	end is_shared;

	function get_safe_value_of_cell (
		device 	: in type_device_name.bounded_string;
		id 		: in type_cell_id
		) return type_bit_char_class_1 is
	-- this function looks up the safebits string specified in section registers.
	-- NOTE: The only reliable source of safe values for cells is to be found in section registers.safebits !
	-- NOTE: this function is local. no specification
		cell_found	: boolean := false;
		safe_value	: type_bit_char_class_1; -- x,X,0,1
		bic			: type_bscan_ic;
	begin
--         for b in 1..length(list_of_bics) loop    
-- 			bic := element(list_of_bics, positive(b));
-- 			if bic.name = device then

-- 		if contains(list_of_bics, bic_name) then
		bic := element(list_of_bics, device);
				
				for i in 1..bic.len_bsr loop -- loop as long as how many cells are in boundary register
											-- start with safe bit pos 1 -> this is cell MSB
											-- end with safe bit pos last -> this is cell LSB
											-- safebits x1xxxxxxxxxxxxxxxx (MSB left, LSB right !)
					if i = bic.len_bsr - id then -- if i matches given id 
						cell_found := true;
						case bic.safebits(i) is
							when 'x' | 'X' => safe_value := 'X'; -- translate x or X to X
							when others => safe_value := bic.safebits(i); -- all other values (0,1) can be taken as they are
						end case;
						exit; -- cell found, cancel search here
					end if;
				end loop;
-- 				exit; -- exit here (searching other bics makes no sense)
-- 			end if;
-- 		end loop;

		if not cell_found then
			write_message (
				file_handle => current_output,
				text => message_error & "The given cell with ID" & type_cell_id'image(id) 
					& " does not exist in device '" & to_string(device) & "' !",
				console => true);
			raise constraint_error;
		end if;
		return safe_value;
	end get_safe_value_of_cell;


	procedure print_net_info (net_name : in type_net_name.bounded_string) is
		net					: type_net;
-- 		net_found			: boolean := false;
		secondary_net_count : natural := natural(length(net.secondary_net_names));
	begin
		new_line;
		put_line("NET INFO: " & to_string(net_name));
		put_line("------------------------------------------------------------------------------");
		-- 		for n in 1..length(list_of_nets) loop
		if contains(list_of_nets, net_name) then
			--net := element(list_of_nets, positive(n));
			net := element(list_of_nets, net_name);
-- 			if net.name = net_name then
-- 				net_found := true;
				put_line("level               : " & type_net_level'image(net.level));
				if net.level = secondary then
					put_line("primary net         : " & to_string(net.name_of_primary_net));
				end if;
				put_line("class               : " & type_net_class'image(net.class));
				put_line("bs capable          : " & boolean'image(net.bs_capable));
				put_line("pin count total     : " & trim(natural'image(natural(length(net.pins))),left));
				put_line("bs bidir pin count  : " & trim(natural'image(net.bs_bidir_pin_count),left));
				put_line("bs input pin count  : " & trim(natural'image(net.bs_input_pin_count),left));
				put_line("bs output pin count : " & trim(natural'image(net.bs_output_pin_count),left));
				put_line("pin list begin :");
				for p in 1..length(net.pins) loop
					--pin := element(net.pins, positive(p)); -- load a pin from the pinlist of the net
					-- NOTE: element(net.pins, positive(p)) equals the particular pin
					-- write general properties of the pin
					put(row_separator_0 & to_string(element(net.pins, positive(p)).device_name) & row_separator_0
						& strip_quotes(type_device_class'image(element(net.pins, positive(p)).device_class)) & row_separator_0
						& to_string(element(net.pins, positive(p)).device_value) & row_separator_0
						& to_string(element(net.pins, positive(p)).device_package) & row_separator_0
						& to_string(element(net.pins, positive(p)).device_pin_name) & row_separator_0
					   );

					-- CS: write port ?

					-- if pin is scan capable, write cell info
					if element(net.pins, positive(p)).is_bscan_capable then
						--put("cells: ");
						if element(net.pins, positive(p)).cell_info.input_cell_id /= -1 then
							put(row_separator_1 & "in" & type_cell_id'image(element(net.pins, positive(p)).cell_info.input_cell_id)
								& row_separator_0 & type_boundary_register_cell'image(element(net.pins, positive(p)).cell_info.input_cell_type)
								& row_separator_0 & "sv " 
								& strip_quotes(type_bit_char_class_1'image(element(net.pins, positive(p)).cell_info.input_cell_safe_value))
								);
						end if;
						
						if element(net.pins, positive(p)).cell_info.output_cell_id /= -1 then
							put(row_separator_1 & "out" & type_cell_id'image(element(net.pins, positive(p)).cell_info.output_cell_id)
								& row_separator_0 & type_boundary_register_cell'image(element(net.pins, positive(p)).cell_info.output_cell_type)
								& row_separator_0 & type_cell_function'image(element(net.pins, positive(p)).cell_info.output_cell_function)
								& row_separator_0 & "sv " 
								& strip_quotes(type_bit_char_class_1'image(element(net.pins, positive(p)).cell_info.output_cell_safe_value))
								);
						end if;
						
						if element(net.pins, positive(p)).cell_info.control_cell_id /= -1 then
							put(row_separator_1 & "ctrl" & type_cell_id'image(element(net.pins, positive(p)).cell_info.control_cell_id)
								& row_separator_0 & "shared " & boolean'image(element(net.pins, positive(p)).cell_info.control_cell_shared)
								& row_separator_0 & "safe " 
								& strip_quotes(type_bit_char_class_1'image(
									get_safe_value_of_cell (
										element(net.pins, positive(p)).device_name, 
										element(net.pins, positive(p)).cell_info.control_cell_id)))
								& row_separator_0 & "dv "
								& strip_quotes(type_bit_char_class_0'image (element(net.pins, positive(p)).cell_info.disable_value))
								& row_separator_0 & "dr " 
								& type_disable_result'image(element(net.pins, positive(p)).cell_info.disable_result)
								);
						end if;

					end if; -- if pin is scan capable
					new_line;
				end loop;
				put_line("pin list end");
				if net.level = primary then
					if secondary_net_count > 0 then
						put_line("secondary net count : " & trim(natural'image(secondary_net_count),left));
						put("secondary nets      : ");
						for s in 1..secondary_net_count loop
							put(to_string(element(net.secondary_net_names, positive(s))) & row_separator_0);
						end loop;
						new_line;
					end if;
				end if;
-- 				exit;
-- 			end if;
-- 		end loop;
-- 		if not net_found then
		else
			put_line(message_error & "Net not found !");
-- 		else
-- 			null;
		end if;
	end print_net_info;

	function is_primary (name_net : in type_net_name.bounded_string) return boolean is
	-- returns true if given net is a primary net
		net : type_net;
	begin
		direct_messages;
		
-- 		for n in 1..length(list_of_nets) loop
-- 			net := element(list_of_nets, positive(n));
-- 			if net.name = name_net then
		net := element(list_of_nets, name_net);
				if net.level = primary then
					return true;
-- 				else
-- 					return false;
				end if;
-- 			end if;
-- 		end loop;

-- 		-- if loop finished, net has not been found in database
-- 		write_message (
-- 			file_handle => current_output,
-- 			text => message_error & "Net " & to_string(name_net) & " not found in " & text_identifier_database & " !",
-- 			console => true);
-- 		raise constraint_error;
		
		return false; 
	end is_primary;
	
	function get_primary_net (name_net : in type_net_name.bounded_string) return type_net_name.bounded_string is
	-- returns the name of the superordinated primary net.
	-- if given net is a primary net, the same name will be returned
		net	: type_net;
	begin
-- 		for n in 1..length(list_of_nets) loop
-- 			net := element(list_of_nets, positive(n));
-- 			if net.name = name_net then
-- 				if net.level = primary then
-- 					return net.name;
-- 				else
-- 					return net.name_of_primary_net;
-- 				end if;
-- 			end if;
-- 		end loop;

		net := element(list_of_nets, name_net);
		if net.level = secondary then
			return net.name_of_primary_net;
		end if;

-- 		-- if loop finished, net has not been found in data base
-- 		write_message (
-- 			file_handle => current_output,
-- 			text => message_error & "Net " & to_string(name_net) & " not found in " & text_identifier_database & " !",
-- 			console => true);
-- 		raise constraint_error;
		
--		return type_net_name.to_bounded_string(""); -- this code should be never reached, but is required for compiliation
		return name_net;
	end get_primary_net;

	function get_number_of_secondary_nets (name_net : in type_net_name.bounded_string) return natural is
	-- Returns the number of secondary nets connected to the given primary net.
	-- If given net is secondary, zero will be returned.
		net : type_net;
	begin
-- 		for n in 1..length(list_of_nets) loop
-- 			net := element(list_of_nets, positive(n));
-- 			if net.name = name_net then
		net := element(list_of_nets, name_net);
				if net.level = primary then
					return natural(length(net.secondary_net_names));
				end if;
-- 			end if;
-- 		end loop;

-- 		-- if loop finished, net has not been found in data base or is not a primary net
-- 		write_message (
-- 			file_handle => current_output,
-- 			text => message_error & "Net " & to_string(name_net) & " not found in " & text_identifier_database & " !",
-- 			console => true);
-- 		raise constraint_error;
		
		return 0;
	end get_number_of_secondary_nets;

	procedure verify_net_appears_only_once_in_net_list (name : in type_net_name.bounded_string) is -- CS: probably not required any more since nets are stored in a map
	-- NOTE: this procedure is local, no specification
		net		: type_net;
		net_cursor : type_list_of_nets.cursor := first(list_of_nets);
	begin
--		for n in 1..length(list_of_nets) loop
		while net_cursor /= type_list_of_nets.no_element loop
			--net := element(list_of_nets, positive(n));
			net := element(net_cursor);
		
			--if net.name = name then
			if key(net_cursor) = name then

				write_message (
					file_handle => current_output,
					text => message_error & "Net '" & to_string(name) & "' already exists in netlist !",
					console => true);
				raise constraint_error;
				
			end if;

			next(net_cursor);
		end loop;
	end verify_net_appears_only_once_in_net_list;

	procedure add_to_net_list(
	-- NOTE: this procedure is local, no specification
		name_given					: in type_net_name.bounded_string;
		class_given					: in type_net_class;
		bs_bidir_pin_count_given	: in natural;
		bs_input_pin_count_given	: in natural;
		bs_output_pin_count_given	: in natural;
		bs_capable_given			: in boolean;
		net_level_given				: in type_net_level;
		name_of_primary_net_given	: in type_net_name.bounded_string; -- don't care if level of targeted net is primary already
		pins_given		 			: in type_list_of_pins.vector;
		secondary_net_names			: in type_list_of_secondary_net_names.vector
		) is

		lp : natural := natural(length(pins_given));
		
		procedure add_primary_net is
			net	: type_net := (
				level 					=> primary,
-- 				name					=> name_given,
				class					=> class_given,
				bs_bidir_pin_count		=> bs_bidir_pin_count_given,
				bs_input_pin_count		=> bs_input_pin_count_given,
				bs_output_pin_count		=> bs_output_pin_count_given,
				bs_capable				=> bs_capable_given,
				optimized				=> false, -- this is just a default, it will be set by chkpsn
				cluster					=> false, -- this is just a default, it will be set by mkoptions
				cluster_id				=> 0, -- this is just a default, it will be set by mkoptions
				secondary_net_names		=> secondary_net_names,
				pins					=> pins_given);
		begin			
			--append(list_of_nets,net);
			insert(container => list_of_nets, key => name_given, new_item => net);
		end add_primary_net;

		procedure add_secondary_net is
			net : type_net := (
				level  					=> secondary,
-- 				name					=> name_given,
				class					=> class_given,
 				bs_bidir_pin_count		=> bs_bidir_pin_count_given,
				bs_input_pin_count		=> bs_input_pin_count_given,
 				bs_output_pin_count		=> bs_output_pin_count_given,
				bs_capable				=> bs_capable_given,
				optimized				=> false, -- this is just a default, it will be set by chkpsn
				cluster					=> false, -- this is just a default, it will be set by mkoptions
				cluster_id				=> 0, -- this is just a default, it will be set by mkoptions				
 				name_of_primary_net		=> name_of_primary_net_given,
				pins					=> pins_given);
		begin
			--append(list_of_nets,net);
			insert(container => list_of_nets, key => name_given, new_item => net);
		end add_secondary_net;

		
		procedure verify_pin_appears_only_once_in_net_list is
			net				: type_net;
			pin_a , pin_b	: type_pin_base;
			net_cursor		: type_list_of_nets.cursor;
		begin
			-- check if every pin appears only once in the given list of pins
			for pa in 1..lp loop -- pa points to the pin of interest
				if pa > lp then -- check for further occurences makes sense as long as the bottom of the list
								-- has not been reached.
					pin_a := type_pin_base(element(pins_given, positive(pa))); -- load pin of interest

					-- search further down the list for the same device and pin
					for pb in pa+1..lp loop 
						pin_b := type_pin_base(element(pins_given, positive(pb))); -- load pin
						if pin_b.device_name = pin_a.device_name then -- on device match
							if pin_b.device_pin_name = pin_a.device_pin_name then -- on pin match
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(pin_a.device_name) & " pin " 
										 & to_string(pin_a.device_pin_name) & " must appear only once in this net !",
									console => true);
								raise constraint_error;
							end if;
						end if;
					end loop;
				end if;
			end loop;

			-- loop in net list and check if any pin of array pin_given appears in other nets
			for pa in 1..lp loop -- loop though pin_given
				pin_a := type_pin_base(element(pins_given, positive(pa))); -- load pin of interest

				--for n in 1..length(list_of_nets) loop -- loop in netlist
				net_cursor := first(list_of_nets);
				while net_cursor /= type_list_of_nets.no_element loop
					--net := element(list_of_nets, positive (n)); -- load a net
					net := element(net_cursor); -- load a net
					for p in 1..length(net.pins) loop -- loop in pinlist of that net
						pin_b := type_pin_base(element(net.pins, positive(p))); -- load pin
						if pin_b.device_name = pin_a.device_name then -- on device name match
							if pin_b.device_pin_name = pin_a.device_pin_name then -- on pin match
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(pin_a.device_name) & " pin " 
										& to_string(pin_a.device_pin_name)
-- 										& " already used in net " & to_string(net.name) & " !",
										& " already used in net " & to_string(key(net_cursor)) & " !",
									console => true);
								
								raise constraint_error;
							end if;
						end if;
					end loop;
					next(net_cursor);
				end loop;
			end loop;
		end verify_pin_appears_only_once_in_net_list;


	begin -- add_to_net_list
		if degree_of_database_integrity_check >= medium then
			verify_pin_appears_only_once_in_net_list;
		end if;
		
		case net_level_given is
			when primary 	=> add_primary_net;
			when secondary 	=> add_secondary_net;
		end case;
	end add_to_net_list;

	
	function is_register_present (text_in : in string)
		return boolean is
	begin
		-- check whether text_in is type_bic_optional_register_present. return false is yes
		case type_bic_optional_register_present'value(to_upper(text_in)) is
			when others => null;
		end case;
		return false;
		
		exception -- means, text_in was something other than type_bic_optional_register_present
			when constraint_error => return true;
	end is_register_present;
	


	procedure complete_bic_data (
	-- NOTE: local, no specification
			name				: in type_device_name.bounded_string;
			value				: in type_device_value.bounded_string;
			len_ir 				: in type_register_length; -- => bic_instruction_register_length,
			len_bsr				: in type_register_length; --=> bic_boundary_register_length,
-- 			len_bsr_description : in positive; --=> bic_boundary_register_description_length,
-- 			len_port_io_map 	: in positive; --=> bic_port_io_map_length,
-- 			len_port_pin_map	: in positive;  -- => bic_port_pin_map_length);
			preliminary_opcodes : in type_preliminary_opcodes_by_standard; -- array of bounded strings
			ir_capture			: in type_preliminary_ir_capture.bounded_string;
			safebits			: in type_preliminary_safebits.bounded_string;
			bsr_description		: in type_list_of_bsr_bits.vector; -- CS: type_bsr_description.vector
			port_io_map			: in type_port_io_map.vector;
			port_pin_map		: in type_port_pin_map.vector;
			idcode_pre			: in type_preliminary_idcode.bounded_string;
			usercode_pre		: in type_preliminary_usercode.bounded_string;
			trst_pin			: in type_trst_availability
		) is

		bic_pre 	: type_bscan_ic_pre;
		bic_scratch : type_bscan_ic (
						len_ir => len_ir, -- bic_instruction_register_length,
						len_bsr => len_bsr); -- bic_boundary_register_length,
-- 						len_bsr_description => len_bsr_description, -- bic_boundary_register_description_length,
-- 						len_port_io_map => len_port_io_map, -- bic_port_io_map_length,
-- 						len_port_pin_map => len_port_io_map); -- bic_port_pin_map_length);

	begin -- complete_bic_data
		-- get bic_pre from list_of_bics_pre (created while reading scanpath configuration)
		bic_pre := element(list_of_bics_pre, name);

		write_message (
			--file_handle => file_database_messages,
			file_handle => current_output,
			identation => 2,
			text => "completing BIC " & to_string(name) & " scanpath" & positive'image(bic_pre.chain) &
				" position" & positive'image(bic_pre.position) & " length of bsr" & positive'image(len_bsr) &
				" len of ir" & positive'image(len_ir),
			console => false);
		
-- 		bic_scratch.name 		:= name;
		bic_scratch.value 		:= value;
		bic_scratch.chain		:= bic_pre.chain; -- get scanpath id
		bic_scratch.position 	:= bic_pre.position; -- get position
		bic_scratch.housing 	:= bic_pre.housing; -- get housing (or package name)
		bic_scratch.model_file 	:= bic_pre.model_file; -- get model file
		bic_scratch.options 	:= bic_pre.options; -- get options

		bic_scratch.capture_ir 	:= to_binary_class_1(to_binary(to_string(ir_capture),len_ir,class_1));
		bic_scratch.safebits 	:= to_binary_class_1(to_binary(to_string(safebits),len_bsr,class_1));

		if length(idcode_pre) /= 0 then
			bic_scratch.idcode	:= to_binary_class_1(to_binary(to_string(idcode_pre),bic_idcode_register_length,class_1));
		end if;

		if length(usercode_pre) /= 0 then
			bic_scratch.usercode := to_binary_class_1(to_binary(to_string(usercode_pre),bic_usercode_register_length,class_1));
		end if;

		bic_scratch.trst_pin	:= trst_pin;
		
		bic_scratch.boundary_register 	:= bsr_description;
		bic_scratch.port_io_map 		:= port_io_map;
		bic_scratch.port_pin_map 		:= port_pin_map;

		-- If mandatory opcodes are missing they are replaced by defaults.
		-- If optional opcodes are missing all their bit positions are set to X.
		if length(preliminary_opcodes.bypass) = 0 then
			--bic_opc_bypass := bic_instruction_register_length * '1';
			bic_scratch.opc_bypass := to_binary_class_1(to_binary(len_ir * '1',len_ir,class_1)); -- all bits 1
			put_line(message_warning & "Instruction " & type_bic_instruction'image(BYPASS) & " not found ! Assume default !");
		else
			bic_scratch.opc_bypass := to_binary_class_1(to_binary(to_string(preliminary_opcodes.bypass),len_ir,class_1));
		end if;
		
		if length(preliminary_opcodes.extest) = 0 then
			--bic_opc_extest := bic_instruction_register_length * '0';
			bic_scratch.opc_extest := to_binary_class_1(to_binary(len_ir * '0',len_ir,class_1)); -- all bits 0
			put_line(message_warning & "Instruction " & type_bic_instruction'image(EXTEST) & " not found ! Assume default !");
		else
			bic_scratch.opc_extest := to_binary_class_1(to_binary(to_string(preliminary_opcodes.extest),len_ir,class_1));
		end if;
		
		if length(preliminary_opcodes.intest) = 0 then
			--bic_opc_intest := bic_instruction_register_length * 'X';
			bic_scratch.opc_intest := to_binary_class_1(to_binary(len_ir * 'X',len_ir,class_1)); -- all bits X
		else
			bic_scratch.opc_intest := to_binary_class_1(to_binary(to_string(preliminary_opcodes.intest),len_ir,class_1));
		end if;
		
		if length(preliminary_opcodes.sample) = 0 then
			--bic_opc_sample := bic_instruction_register_length * 'X';
			bic_scratch.opc_sample := to_binary_class_1(to_binary(len_ir * 'X',len_ir,class_1)); -- all bits X
			put_line(message_warning & "Instruction " & type_bic_instruction'image(SAMPLE) & " not found !");
		else
			bic_scratch.opc_sample := to_binary_class_1(to_binary(to_string(preliminary_opcodes.sample),len_ir,class_1));
		end if;
		
		if length(preliminary_opcodes.preload) = 0 then
			--bic_opc_preload := bic_instruction_register_length * 'X';
			bic_scratch.opc_preload := to_binary_class_1(to_binary(len_ir * 'X',len_ir,class_1)); -- all bits X
		else
			bic_scratch.opc_preload := to_binary_class_1(to_binary(to_string(preliminary_opcodes.preload),len_ir,class_1));
		end if;
		
		if length(preliminary_opcodes.idcode) = 0 then
			--bic_opc_idcode := bic_instruction_register_length * 'X';					
			bic_scratch.opc_idcode := to_binary_class_1(to_binary(len_ir * 'X',len_ir,class_1)); -- all bits X
			put_line(message_warning & "Instruction " & type_bic_instruction'image(IDCODE) & " not found !");
		else
			bic_scratch.opc_idcode := to_binary_class_1(to_binary(to_string(preliminary_opcodes.idcode),len_ir,class_1));
		end if;
		
		if length(preliminary_opcodes.usercode) = 0 then
			bic_scratch.opc_usercode := to_binary_class_1(to_binary(len_ir * 'X',len_ir,class_1)); -- all bits X
			put_line(message_warning & "Instruction " & type_bic_instruction'image(USERCODE) & " not found !");
		else
			bic_scratch.opc_usercode := to_binary_class_1(to_binary(to_string(preliminary_opcodes.usercode),len_ir,class_1));
		end if;
		
		if length(preliminary_opcodes.clamp) = 0 then
			--bic_opc_clamp := bic_instruction_register_length * 'X';
			bic_scratch.opc_clamp := to_binary_class_1(to_binary(len_ir * 'X',len_ir,class_1)); -- all bits X
		else
			bic_scratch.opc_clamp := to_binary_class_1(to_binary(to_string(preliminary_opcodes.clamp),len_ir,class_1));					
		end if;
		
		if length(preliminary_opcodes.highz) = 0 then
			bic_scratch.opc_highz := to_binary_class_1(to_binary(len_ir * 'X',len_ir,class_1)); -- all bits X
		else
			bic_scratch.opc_highz := to_binary_class_1(to_binary(to_string(preliminary_opcodes.highz),len_ir,class_1));					
		end if;
		
		-- CS:
		-- perform in depth check of safebits, port io maps, port_pin maps cross dependencies

		--append(list_of_bics, bic_scratch);
		insert(container => list_of_bics, key => name, new_item => bic_scratch);
				

		-- clear temporarily used opcodes for next bic
		bic_opcodes_preliminary := bic_opcodes_init;

	end complete_bic_data;
	

    function is_bic (name_of_ic_given: in type_device_name.bounded_string) return boolean is
    -- Returns true if given device is a bic (as listed in section scanpath configuration)
	begin
-- 		for b in 1..length(list_of_bics_pre) loop
-- 			if element(list_of_bics_pre,positive(b)).name = name_of_ic_given then
-- 				--put_line(to_string(b.name));
-- 				return true;
-- 			end if;
-- 		end loop;
-- 		return false;
		return contains(list_of_bics_pre, name_of_ic_given);
	end is_bic;


 	procedure read_opcode (line : in type_fields_of_line; len_ir : in type_register_length) is
	-- Reads the opcode from a line like "IDCODE 11100000 11100010" and updates preliminary_opcodes.
		i	: type_bic_instruction;
		oc	: type_preliminary_opcode.bounded_string;
		pos : natural := 0;
	begin
		i := type_bic_instruction'value(get_field_from_line(line,1)); -- this is an indirect test of supported instruction acc. to ieee1149.1
		-- 		if get_field_count(line) > 1 then -- if at least one opcode follows a supported instruction
		if line.field_count > 1 then -- if at least one opcode follows a supported instruction
			-- CS: only the first opcode after instruction name will be read. all others ignored !
			pos := 1;
			oc := to_bounded_string(get_field_from_line(line,2)); -- "11100000"

			-- check for valid opcode
			pos := 5;				
			if to_binary_class_1(to_binary(to_string(oc),len_ir,class_1)) not in type_string_of_bit_characters_class_1 then 
				raise constraint_error; 
			end if;

			pos := 10;				
			case i is
				when BYPASS		=> bic_opcodes_preliminary.bypass	:= oc;
				when EXTEST 	=> bic_opcodes_preliminary.extest 	:= oc;
				when INTEST 	=> bic_opcodes_preliminary.intest 	:= oc;
				when SAMPLE		=> bic_opcodes_preliminary.sample 	:= oc;
				when PRELOAD	=> bic_opcodes_preliminary.preload	:= oc;
				when IDCODE 	=> bic_opcodes_preliminary.idcode 	:= oc;
				when USERCODE	=> bic_opcodes_preliminary.usercode := oc;
				when HIGHZ 		=> bic_opcodes_preliminary.highz	:= oc;
				when CLAMP	 	=> bic_opcodes_preliminary.clamp 	:= oc;
				when others => null; -- CS: manufacturer specific opcodes ?
			end case;

		else -- if opcode missing
			pos := 15;
			write_message (
				file_handle => current_output,
				text => message_error & "Instruction opcode expected after instruction name !",
				console => true);
			raise constraint_error;
		end if;

		exception
			when constraint_error => 
				--put_line(natural'image(pos));
				case pos is 
					when 0 => 
-- 						put_line(message_warning & "Instruction '" & get_field_from_line(line,1) &
-- 								 "' is not supported by standard " & bscan_standard_1 & " !");
						write_message (
							file_handle => current_output,
							text => message_warning & "Instruction " & get_field_from_line(line,1) &
								 " is not supported by standard " & bscan_standard_1 & " !", 
							console => false);

					when 5 => 
						write_message (
							file_handle => current_output,
							text => message_error & "Invalid character in opcode of instruction " &
								 get_field_from_line(line,1) & " !", 
							console => true);
						raise constraint_error;
						
					when others => raise;
				end case;
	end read_opcode;


	procedure read_boundary_register (line : in type_fields_of_line) is

		procedure add_basic_bsr_bit is
			bsr_bit : type_bit_of_boundary_register := (
				id				=> type_cell_id'value(get_field_from_line(line,1)),
				cell_type		=> type_boundary_register_cell'value(to_upper(get_field_from_line(line,2))),
				port			=> type_port_name.to_bounded_string(get_field_from_line(line,3)),
				cell_function	=> type_cell_function'value(to_upper(get_field_from_line(line,4))),
				cell_safe_value	=> to_binary(text_in => get_field_from_line(line,5), length => 1, class => class_1)(1),

				-- defaults
				appears_in_net_list	=> false,
				control_cell_id		=> -1,
				disable_value		=> '1',
				disable_result		=> Z
				);
		begin
			append(bic_bsr_description_preliminary,bsr_bit);
		end add_basic_bsr_bit;

		procedure add_extended_bsr_bit is
			bsr_bit : type_bit_of_boundary_register := (
				id				=> type_cell_id'value(get_field_from_line(line,1)),
				cell_type		=> type_boundary_register_cell'value(get_field_from_line(line,2)),
				port			=> type_port_name.to_bounded_string(get_field_from_line(line,3)),
				cell_function	=> type_cell_function'value(get_field_from_line(line,4)),
				cell_safe_value	=> to_binary(text_in => get_field_from_line(line,5), length => 1, class => class_1)(1),
				control_cell_id	=> type_control_cell_id'value(get_field_from_line(line,6)),
				disable_value	=> to_binary(text_in => get_field_from_line(line,7), length => 1, class => class_0)(1),
				disable_result	=> type_disable_result'value(get_field_from_line(line,8)),
				appears_in_net_list	=> false				
				);
		begin
			append(bic_bsr_description_preliminary,bsr_bit);
		end add_extended_bsr_bit;
		
	begin -- read_boundary_register
		-- 		case get_field_count(line) is
		case line.field_count is
			-- if optional [control_cell disable_value disable_result] are NOT provided:
			when 5 => 
				add_basic_bsr_bit;
			-- if optional [control_cell disable_value disable_result] ARE provided:
			when 8 =>
				add_extended_bsr_bit;
			when others =>
				write_message (
					file_handle => current_output,
					text => message_error & "Invalid field count !",
					console => true);
				raise constraint_error;
		end case;
	end read_boundary_register;
	

	procedure read_port_io_map (line : in type_fields_of_line) is
	-- reads a line like "IO_V10 : inout"
		use type_short_string;
		
-- 		field_count		: positive;
		name			: type_port_name.bounded_string;
		scratch			: type_short_string.bounded_string;
	-- 		ifs_position	: positive;
		ifs_position	: natural := 0;
		port_direction	: type_port_direction;
		idx_start		: natural;
		idx_end			: natural;
		vector_length	: positive;
		vector_orientation	: type_vector_orientation;
		is_vector			: boolean := false;
		port				: type_port;
	begin
		-- find position of ifs
		-- make sure there is an ifs, if not abort
-- 		if index(line,port_ifs) = 0 then 
-- 			write_message (
-- 				file_handle => current_output,
-- 				text => message_error & "Field separator '" & port_ifs & "' not found !",
-- 				console => true);
-- 			raise constraint_error;
-- 		end if;
		
-- 		field_count := get_field_count(line);
-- 		for f in 1..field_count loop
		for f in 1..positive(line.field_count) loop
			if get_field_from_line(line,f) = port_ifs then
				ifs_position := f;
			end if;
		end loop;

		if ifs_position = 0 then
			write_message (
				file_handle => current_output,
				text => message_error & "Field separator '" & port_ifs & "' not found !",
				console => true);
			raise constraint_error;
		end if;

		-- read port name from field 1
		name := to_bounded_string(get_field_from_line(line,1));

		-- check for keyword right of ifs "IO_V10 : inout" 
		scratch := to_bounded_string(get_field_from_line(line,ifs_position+1));
		
		if to_string(scratch) = port_direction_in then 
			port_direction := input;
		elsif to_string(scratch) = port_direction_out then
			port_direction := output;
		elsif to_string(scratch) = port_direction_inout then
			port_direction := inout;
		elsif to_string(scratch) = port_direction_linkage then
			port_direction := linkage;
		else
			write_message (
				file_handle => current_output,
				text => message_error & "Port direction invalid !",
				console => true);
			raise constraint_error;
		end if;

		-- check if it is a vector
-- 		for f in (ifs_position+1)..field_count loop
		for f in (ifs_position+1)..positive(line.field_count) loop
			if 		to_upper(get_field_from_line(line,f)) = type_vector_orientation'image(to) then
						vector_orientation := to;
						is_vector	:= true; -- set is_vector flag
			elsif 	to_upper(get_field_from_line(line,f)) = type_vector_orientation'image(downto) then 
						vector_orientation := downto;
						is_vector := true; -- set is_vector flag
-- 					else
-- 						put_line("ERROR: Expected identifier '" & type_vector_orientation'image(downto) 
-- 								& "' or '" & type_vector_orientation'image(to) & "' after start index !");
-- 						raise constraint_error;
			-- CS: do something when identifier to/downto has typing error like "dowto". currently this leads to a incorrect error message
			end if;
			
			if is_vector then
				-- make sure there is only one field before ifs (means ifs =2)
				if ifs_position /= 2 then
					write_message (
						file_handle => current_output,
						text => message_error & "Vectored port permits only one name field before '" & port_ifs & "' !",
						console => true);
					raise constraint_error;
				end if;

				-- assign start and end point of port vector. 
				idx_start	:= natural'value(get_field_from_line(line,f-1)); -- start is always the number found before (do/downto) !
				idx_end		:= natural'value(get_field_from_line(line,f+1)); -- end   is always the number found after  (do/downto) !

				case vector_orientation is
					when to 	=> vector_length := 1 + idx_end - idx_start;
					when downto	=> vector_length := 1 + idx_start - idx_end;
				end case;
				exit;
			end if;
		end loop;

		-- build port and add port to list
		port.name				:= name;
		port.direction			:= port_direction;
		port.index_start		:= idx_start;
		port.index_end			:= idx_end;
		port.vector_length		:= vector_length;
		port.is_vector			:= is_vector;
		port.vector_orientation	:= vector_orientation;

		append(bic_port_io_map_preliminary,port);
			
	end read_port_io_map;


	procedure read_port_pin_map (line : in type_fields_of_line) is
		-- extracts from a line like "a1 23 22 21 20" the port name and pins
-- 		line : extended_string.bounded_string := line_in;
-- 		use extended_string;
			
-- 		field_count		: positive;
		name			: type_port_name.bounded_string;
		pin_names		: type_list_of_pin_names.vector;
		
		port_pin		: type_port_pin;
	begin
-- 		field_count := get_field_count(line);
		name		:= to_bounded_string(get_field_from_line(line,1)); -- the first field always contains the port name

		-- collect all pin names
-- 		for f in 2..field_count loop
		for f in 2..positive(line.field_count) loop -- indirect check if only one field provided
			append(pin_names,to_bounded_string(get_field_from_line(line,f)));
		end loop;

		port_pin.port_name := name;
		port_pin.pin_names := pin_names;

		append(bic_port_pin_map_preliminary,port_pin);

	end read_port_pin_map;


	function build_cell_info(
	-- builds from a line like "IC301 NA XC9536 PLCC-S44 43  pb01_03 | 44 bc_1 input x | 43 bc_1 output3 x 42 0 z"
	-- the object cell_info. cell_info is part of type type_pin
	-- 		line		: in string;
		line		: in type_fields_of_line;	
		line_counter: in natural)
-- 		device		: in type_device_name.bounded_string;
-- 		port		: in type_port_name.bounded_string;
-- 		pin			: in type_pin_name.bounded_string)
		return type_pin_cell_info is

		device		: type_device_name.bounded_string	:= to_bounded_string(get_field_from_line(line,1));
		pin			: type_pin_name.bounded_string		:= to_bounded_string(get_field_from_line(line,5));
		port		: type_port_name.bounded_string		:= to_bounded_string(get_field_from_line(line,6));
		
		cell_info						: type_pin_cell_info;
		cell_id, cell_control_cell_id	: type_cell_id; -- boundary register cell id 0,2,4,5, ...
		cell_type						: type_boundary_register_cell; -- bc_1, bc_2, ...
		cell_function					: type_cell_function; -- input , output2, output3, bidir, clock, ...
		cell_safe_value					: type_bit_char_class_1; -- x,X,0,1
		cell_disable_value				: type_bit_char_class_0; -- 0,1
		cell_disable_result				: type_disable_result; -- weakx, pullx or z
		prog_position					: natural := 0;
		
		field_count_min					: constant positive := 2; -- there must be at least one cell entry after the default fields "name class value package pin port"
		field_count_max					: constant positive := 3; -- maximim number of cell entries is 2 (separated by "|")
		subtype type_field_count is positive range field_count_min..field_count_max;
		-- example for 2 entries  : "IC303 NA SN74BCT8240ADWR SOIC24 10 y2(4) | 0 bc_1 output3 X 16 1 z "
		-- example for 3 entries  : "IC301 NA XC9536 PLCC-S44 2  pb00_00 | 107 bc_1 input x | 106 bc_1 output3 x 105 0 z"

		use type_universal_string;

		cell_entry_list : type_fields_of_line;
		cell_entry2		: type_fields_of_line;

		cell_entry_field_count_min	: positive := 4; -- there must be at least 4 fields within an entry like "107 bc_1 input x"
		cell_entry_field_count_max	: positive := 7; -- there must be no more than 7 fields within an entry like "106 bc_1 output3 x 105 0 z"
		subtype type_cell_entry_field_count is positive range cell_entry_field_count_min..cell_entry_field_count_max;

		procedure verify_cell(
		-- verifies the connection of device, port, port index, control cell, save value, disable value, disable result, ... against
		-- the specifications derived from the bsdl-model (section registers)
		-- example line from net list:  IC301 NA XC9536 PLCC-S44 43  pb01_03 | 44 bc_1 input x | 43 bc_1 output3 x 42 0 z
			id			: type_cell_id; -- 44,43,42
			ctype		: type_boundary_register_cell; -- bc_1
			func		: type_cell_function; -- input, output3, ...
			safe		: type_bit_char_class_1; -- x,1,0
			cc			: type_control_cell_id := -1; -- control cell id -- default -1 if no cc given
			dv			: type_bit_char_class_0 := '0'; -- 0,1 -- default if no dv given
			dr			: type_disable_result := Z; -- z, weak0, ... -- default if no dr given
			pin			: type_pin_name.bounded_string; -- 43
			port		: type_port_name.bounded_string; -- pb01_03
			device		: type_device_name.bounded_string) -- IC301 
			is
			cell_id_valid		: boolean := false;
			cc_id_valid			: boolean := false;
			cell_type_valid		: boolean := false;
			port_valid			: boolean := false;
-- 			device_valid 		: boolean := false;
			port_name_valid		: boolean := false;
			port_index_valid 	: boolean := false;
			pin_valid 			: boolean := false;
			function_valid		: boolean := false;
			cc_function_valid	: boolean := false;
			safe_value_valid	: boolean := false;
			dv_valid 			: boolean := false;
			dr_valid 			: boolean := false;
			port_scratch		: type_port_name.bounded_string := port;
			port_opening_bracket_count 	: natural;
			port_closing_bracket_count 	: natural;
			port_is_vectored			: boolean; -- set if portname and port index found by port given in net list
													-- if a port like y2(4) found, for example
			opening_bracket_position	: positive;
			closing_bracket_position	: positive;
			port_index					: natural;
			port_name					: type_port_name.bounded_string;
			prog_position				: natural := 0;

			port_io_temp				: type_port;
			port_pin_temp 				: type_port_pin;
			bsr_bit_temp				: type_bit_of_boundary_register;
			bic_temp					: type_bscan_ic;
			
			procedure put_error_on_syntax_error_in_port is
			begin
				write_message (
					file_handle => current_output,
					text => message_error & "Syntax error in port '" & to_string(port) & "' !",
					console => true);
				raise constraint_error;
			end put_error_on_syntax_error_in_port;

			procedure check_safe_value_of_control_cell is
			-- this procedure looks up the safebits string specified in section registers.
			-- it puts a warning if the safe bit of the control cell being processed (cc) is undefined
			-- or if the safe value (for this control cell) -given in safebits- results in an enabled output pin
			-- NOTE: The only reliable source of safe values for control cells is to be found in section registers.safebits !
				bic : type_bscan_ic;
			begin
-- 				for b in 1..length(list_of_bics) loop    
-- 					--if b.name = device then -- find bic name
-- 					if element(list_of_bics,positive(b)).name = device then
					bic := element(list_of_bics, device);

						for i in 1..bic.len_bsr loop -- loop as long as how many cells are in boundary register
													-- start with safe bit pos 1 -> this is cell MSB
													-- end with safe bit pos last -> this is cell LSB
													-- safebits x1xxxxxxxxxxxxxxxx (MSB left, LSB right !)
							if i = bic.len_bsr - cc then -- if i matches given cc id 
								-- check if safe value results in an enabled output (which is quite dangerous)
								case bic.safebits(i) is
									when 'x' | 'X' => 
										put_line(message_warning & "Line" & natural'image(line_counter) & ": Control cell with undefined safe value found !");
										put_line("affected line : " & to_string(line)); 
									when '0' => -- if safe bit value is 0, the disable value should be the same
										case dv is
											when '0' => null; -- fine
											when '1' => -- this is in contradiction with the safe bit value
												put_line(message_warning & "Line" & natural'image(line_counter) & ": Control cell with dangerous safe value found !");
												put_line("affected line : " & to_string(line)); 
										end case;
									when '1' => -- if safe bit value is 1, the disable value should be the same
										case dv is
											when '1' => null; -- fine
											when '0' => -- this is in contradiction with the safe bit value
												put_line(message_warning & "Line" & natural'image(line_counter) & ": Control cell with dangerous safe value found !");
												put_line("affected line : " & to_string(line)); 
										end case;
								end case;
								exit; -- no more bit search required
							end if;
						end loop;
-- 						exit; -- no more bic search required
-- 					end if;
-- 				end loop;
			end check_safe_value_of_control_cell;
			
-- 			procedure mark_cell_as_used (bic_id : in positive; cell_id : in positive) is
-- 				procedure set_appears_in_cell_list (bic : in out type_bscan_ic) is
-- 				begin
-- 					bic.boundary_register(cell_id).appears_in_net_list := true;
-- 				end set_appears_in_cell_list;
-- 			begin
-- 				update_element(list_of_bics,positive(bic_id),
-- 					set_appears_in_cell_list'access);                        
-- 			end mark_cell_as_used;

			procedure mark_cell_as_used (cell_id : in positive) is
				
				procedure set_appears_in_cell_list (key : in type_device_name.bounded_string; bic : in out type_bscan_ic) is
				begin
					bic.boundary_register(cell_id).appears_in_net_list := true;
				end set_appears_in_cell_list;
				
			begin
				type_list_of_bics.update_element(container => list_of_bics, position => find(list_of_bics, device),
					process => set_appears_in_cell_list'access);                        
			end mark_cell_as_used;


		begin -- verify_cell
			write_message (
				file_handle => current_output,
				identation => 2,
				text => "verifying cell " & type_cell_id'image(id), -- CS: put other properties
				console => false);
			
-- 			for b in 1..length(list_of_bics) loop    
-- 				if element(list_of_bics,positive(b)).name = device then -- if device found
-- 					bic_temp := element(list_of_bics,positive(b));
-- 			if contains(list_of_bics, device) then
					bic_temp := element(list_of_bics, device);
-- 					device_valid := true;

					-- check syntax of port name: number and position of opening and closing brackets
					prog_position := 10;
					port_opening_bracket_count := type_port_name.count(port_scratch,"(");
					port_closing_bracket_count := type_port_name.count(port_scratch,")");
					prog_position := 20;
					case port_opening_bracket_count is
						when 0 => 
							prog_position := 30;
							if port_closing_bracket_count = 0 then -- if no brackets found, it is a non-vectored port
								port_is_vectored 	:= false;
								port_name			:= port_scratch; -- save port name as it is in port_name
							else
								put_error_on_syntax_error_in_port;
							end if;
						when 1 =>
							prog_position := 50;
							if port_closing_bracket_count = 1 then -- if one opening and one closing bracket found
	
								-- the first bracket must be on postion 2 or greater
								if type_port_name.index(port_scratch,"(") > 1 then 
									prog_position := 60;

									-- the last bracket must be on last position
									if type_port_name.index(port_scratch,")") = length(port_scratch) then
										prog_position := 70;

										-- slice the number enclosed in brackets and save it as port_index
										-- slice the part before '(' and save it as port_name
										opening_bracket_position := type_port_name.index(port_scratch,"(");
										closing_bracket_position := type_port_name.index(port_scratch,")");
										prog_position := 75;
										port_index 	:= natural'value( slice(port_scratch,opening_bracket_position+1, closing_bracket_position-1) );
										port_name	:= to_bounded_string(slice(port_scratch,1,opening_bracket_position-1));
										port_is_vectored := true; -- this is to be verified against the actual port name given by bsdl-model
																-- see below
										-- port extraction done
									else
										put_error_on_syntax_error_in_port;
									end if;
								else
									prog_position := 80;
									put_error_on_syntax_error_in_port;
								end if;
							else
								prog_position := 90;
								put_error_on_syntax_error_in_port;
							end if;
						when others =>
							prog_position := 100;
							put_error_on_syntax_error_in_port;
					end case;
					-- port extraction done: port_name and port_index hold result

					-- search port_name in port_io_map (defined by bsdl-model). if port is vectored then verify index
					prog_position := 500;
-- 					for p in 1..element(list_of_bics,positive(b)).len_port_io_map loop 
					for p in 1..length(bic_temp.port_io_map) loop  -- length of port_io_map					
						port_io_temp := element( bic_temp.port_io_map, positive(p) );
-- 							--put_line(" --- " & to_string(b.port_io_map(p).name));
-- 						if element(list_of_bics,positive(b)).port_io_map(p).name = port_name then -- if port found as defined by bsdl-model (section registers)
						if port_io_temp.name = port_name then -- if port found as defined by bsdl-model (section registers)
							port_name_valid := true; -- the port name (like "y2") found in net list is regarded as valid

							-- verify port_index
							prog_position := 510;
							if port_is_vectored then -- verify if port is vectored according to index extraction above
								--if element(list_of_bics,positive(b)).port_io_map(p).is_vector then -- if vector port according to port_io_map (derived from bsdl-model)
								if port_io_temp.is_vector then -- if vector port according to port_io_map (derived from bsdl-model)

									case port_io_temp.vector_orientation is
										when to =>
											-- verify port index of a rising vector
											prog_position := 520;
											-- if the index (like the 8 in "y2(8)") is in range between index_start and index_end
											for i in port_io_temp.index_start .. port_io_temp.index_end loop
												if i = port_index then
													port_index_valid := true; -- the index is to be regarded as valid
													-- CS: verify the port has not been used yet in the net list

													-- verify pin of RISING VECTORED port
													prog_position := 530;
													for pp in 1..length(bic_temp.port_pin_map) loop -- search port_name in port_pin_map
														port_pin_temp := element(bic_temp.port_pin_map, positive(pp));
														--put_line("-- port: " & to_string(b.port_pin_map(pp).port_name));
														-- NOTE: the port name is the primary key between port_io_map and port_pin_map !
														--if element(list_of_bics,positive(b)).port_pin_map(pp).port_name = port_name then -- if port found
														if port_pin_temp.port_name = port_name then -- if port found
															--put_line("-- port found in port_pin_map");

															-- verify position of pin name in accordance to port_index and vector orientation
															-- in a rising vector, the given pin must appear at postion port_index in the port_pin_map
															prog_position := 540;
															--	if b.port_pin_map(pp).pin_names(a) = to_bounded_string(pin) then
															--if element(list_of_bics,positive(b)).port_pin_map(pp).pin_names(port_index) = to_bounded_string(pin) then
															if element(port_pin_temp.pin_names, positive(port_index)) = pin then
																pin_valid := true;
																exit; -- no more pin searching required
															end if;
														end if;
													end loop;
												end if; -- if port found
											end loop;

										when downto =>
											-- verify port index of a falling vector
											prog_position := 620;
											-- if the index (like the 8 in "y2(8)") is in range between index_end and index_start
											for i in port_io_temp.index_end..port_io_temp.index_start loop
												if i = port_index then
													port_index_valid := true; -- regard the index as valid
													-- CS: verify the port has not been used yet in the net list

													-- verify pin of FALLING VECTORED port
													prog_position := 630;
													for pp in 1..length(bic_temp.port_pin_map) loop -- search port_name in port_pin_map
														port_pin_temp := element(bic_temp.port_pin_map, positive(pp));
														--put_line("-- port: " & to_string(b.port_pin_map(pp).port_name));
														-- NOTE: the port name is the primary key between port_io_map and port_pin_map !
														if port_pin_temp.port_name = port_name then -- if port found
															--put_line("-- port found in port_pin_map");

															-- verify position of pin name in accordance to port_index and vector orientation
															-- in a falling vector, the given pin must appear at postion port_index in the port_pin_map
															prog_position := 640;

															--if element(list_of_bics,positive(b)).port_pin_map(pp).pin_names(element(list_of_bics,positive(b)).port_io_map(p).index_start - port_index + 1) = to_bounded_string(pin) then
															if element(port_pin_temp.pin_names, positive(port_io_temp.index_start - port_index + 1)) = pin then
																pin_valid := true;
																exit; -- no more pin searching required
															end if;
														end if;
													end loop;
												end if; -- if port found
											end loop;
									end case;

								else -- contradiction: port index extraction yielded port index, but non-vectored port according to port_io_map
									prog_position := 650;
									write_message (
										file_handle => current_output,
										text => message_error & "Invalid port found ! Index for port '" & to_string(port_name) & "' not allowed !",
										console => true);
									raise constraint_error;
								end if;

							else -- if port is non-vectored according to port index extraction above

								--if not element(list_of_bics,positive(b)).port_io_map(p).is_vector then -- if non-vector port according to port_io_map
								if not port_io_temp.is_vector then -- if non-vector port according to port_io_map
									-- verify pin of NON-VECTOR port
									prog_position := 700;
										--for pp in 1..element(list_of_bics,positive(b)).len_port_pin_map loop -- search port_name in port_pin_map
										for pp in 1..length(bic_temp.port_pin_map) loop -- search port_name in port_pin_map
											port_pin_temp := element(bic_temp.port_pin_map, positive(pp));

											-- NOTE: the port name is the primary key between port_io_map and port_pin_map !
											--if element(list_of_bics,positive(b)).port_pin_map(pp).port_name = port_name then -- if port found
											if port_pin_temp.port_name = port_name then -- if port found
												-- in a non-vector port, the selector 'pin_names' contains the only pin name of the port
												--if element(list_of_bics,positive(b)).port_pin_map(pp).pin_names(1) = to_bounded_string(pin) then
												if element(port_pin_temp.pin_names, 1) = pin then
													pin_valid := true;
													exit; -- no more pin searching required
												end if;
											end if;
										end loop;

								else -- contradiction: port index extraction yielded no, but vectored port according to port_io_map
									prog_position := 710;
									write_message (
										file_handle => current_output,
										text => message_error & "Invalid port found ! Index expected for port '" & to_string(port_name) & "' !",
										console => true);
									raise constraint_error;
								end if;
							end if; -- if port_is_vectored

							exit; -- no more port searching required
						end if;
					end loop;

					-- search for given cell id in boundary register
					prog_position := 400;
					for c in 1..length(bic_temp.boundary_register) loop
						prog_position := 401;
						bsr_bit_temp := element(bic_temp.boundary_register, positive(c));
						--if element(list_of_bics,positive(b)).boundary_register(c).id = id then
						if bsr_bit_temp.id = id then
							cell_id_valid := true;

							-- check if cell has already found in net list and abort if cell already in use
							--if element(list_of_bics,positive(b)).boundary_register(c).appears_in_net_list then
							prog_position := 420;
							if bsr_bit_temp.appears_in_net_list then
								write_message (
									file_handle => current_output,
									text => message_error & "Cell with ID" & type_cell_id'image(id) & " of this device is already in use !",
									console => true);
								raise constraint_error;
							else
								-- if not used yet, mark cell as used now
								--mark_cell_as_used(bic_id => positive(b), cell_id => positive(c));
								mark_cell_as_used(cell_id => positive(c));
							end if;

							prog_position := 430;
							--if element(list_of_bics,positive(b)).boundary_register(c).cell_type = ctype then
							if bsr_bit_temp.cell_type = ctype then
								cell_type_valid := true;
								if bsr_bit_temp.port = port_scratch then
									port_valid := true;
									if bsr_bit_temp.cell_function = func then
										function_valid := true;
										prog_position := 440;
										if bsr_bit_temp.cell_safe_value = safe then -- this is about the safe value of the output cell !
											safe_value_valid := true;
											prog_position := 443;
											if cc /= -1 then -- if a control cell was given
												-- if control cell defined in model matches given control cell
												prog_position := 445;
												if bsr_bit_temp.control_cell_id = cc then
													cc_id_valid := true;

													-- if disable value defined in model matches given disable value
													prog_position := 450;
													if bsr_bit_temp.disable_value = dv then
														dv_valid := true;
														-- if disable result definded in model matches given disable result
														prog_position := 455;
														if bsr_bit_temp.disable_result = dr then
															dr_valid := true;
															check_safe_value_of_control_cell;
															exit;
														end if;
													end if;
												end if;
											end if;
										end if;
									end if;
								end if;
							end if;
						end if;
					end loop;

-- 					exit; -- no more device searching required
-- 				end if;
-- 			end loop;

			-- if device not found after searching bic list
-- 			prog_position := 200;
-- 			if not device_valid then
-- 			else
-- 				write_message (
-- 					file_handle => current_output,
-- 					text => message_error & "Invalid device found ! " & to_string(device) & " is not part of any scanpath !",
-- 					console => true);
-- 
-- 				--put_line("        Check scan path configuration !");
-- 				raise constraint_error;
-- 			end if;

			-- if port_name not found after searching port_io_map
			prog_position := 210;
			if not port_name_valid then
				write_message (
					file_handle => current_output,
					text => message_error & "Invalid port found. Device " & to_string(device) 
						& " does not have a port '" & to_string(port_name) & "' !",
					console => true);
				raise constraint_error;
			end if;

			-- if port_index invalid after searching port (which is a type_port in array type_port_io_map)
			prog_position := 220;
			if port_is_vectored then
				if not port_index_valid then
					write_message (
						file_handle => current_output,
						text => message_error & "Invalid index found. Port '" & to_string(port_name) 
							& "' does not have an index" & natural'image(port_index) & " !",
						console => true);
					raise constraint_error;
				end if;
			end if;

			-- if pin invalid after searching in port_pin_map
			prog_position := 230;
			if not pin_valid then
				if port_is_vectored then
					write_message (
						file_handle => current_output,
						text => message_error & "Invalid pin found. Vector port '" 
							& to_string(port_name) & "(" & trim(natural'image(port_index),left) 
							& ")' is not mapped to pin '" & to_string(pin) & "' !",
						console => true);
					raise constraint_error;
				else
					prog_position := 235;
					write_message (
						file_handle => current_output,
						text => message_error & "Invalid pin found. Port '" & to_string(port_name) &
							 "' is not mapped to pin '" & to_string(pin) & "' !",
						console => true);
					raise constraint_error;
				end if;
			end if;

			-- if input/output cell id invalid after searching in boundary register
			prog_position := 240;
			if not cell_id_valid then
				write_message (
					file_handle => current_output,
					text => message_error & "Invalid cell found ! Cell ID" & type_cell_id'image(id) & " invalid for given device !",
					console => true);
				raise constraint_error;
			end if;

			-- if cell type invalid
			prog_position := 245;
			if not cell_type_valid then
				write_message (
					file_handle => current_output,
					text => message_error & "Invalid cell found ! Cell type '" 
						& type_boundary_register_cell'image(ctype) & "' invalid for given port !",
					console => true);
				raise constraint_error;
			end if;

			-- if port invalid
			prog_position := 250;
			if not port_valid then
				write_message (
					file_handle => current_output,
					text => message_error & "Invalid port found ! Port '" 
						& to_string(port_scratch) & "' is not connected to given cell !",
					console => true);
				raise constraint_error;
			end if;

			-- if function invalid
			prog_position := 260;
			if not function_valid then
				write_message (
					file_handle => current_output,
					text => message_error & "Invalid cell function '" 
						& type_cell_function'image(func) & "' found !",
					console => true);
				raise constraint_error;
			end if;

			-- if safe value invalid
			prog_position := 270;
			if not safe_value_valid then
				case func is
					when input =>
						write_message (
							file_handle => current_output,
							text => message_error & "Line" & natural'image(line_counter) 
								& ": Invalid safe value " & type_bit_char_class_1'image(safe) 
								& " for cell" & type_cell_id'image(id) & " found !",
							console => true);
						raise constraint_error;

					when others =>
						write_message ( -- CS: same as above. reduce to one action
							file_handle => current_output,
							text => message_error & "Line" & natural'image(line_counter) 
								& "Invalid safe value " & type_bit_char_class_1'image(safe) 
								& " for cell" & type_cell_id'image(id) & " found !",
							console => true);
						raise constraint_error;
				end case;
			end if;

			-- if control cell given, if id invalid after searching in boundary register
			prog_position := 280;
			if cc /= -1 then -- means, if there was a control cell given
				if not cc_id_valid then
					write_message (
						file_handle => current_output,
						text => message_error & "Invalid control cell found ! Cell ID" & type_cell_id'image(cc) & " invalid for this port !",
						console => true);
					raise constraint_error;
				end if;
				if not dv_valid then
					write_message (
						file_handle => current_output,
						text => message_error & "Invalid disable value " & type_bit_char_class_0'image(dv) 
							& " for control cell with ID" & type_cell_id'image(cc) & " found !",
						console => true);
					raise constraint_error;
				end if;
				if not dr_valid then
					write_message (
						file_handle => current_output,
						text => message_error & "Invalid disable result '" & type_disable_result'image(dr) 
							& "' for output cell with ID" & type_cell_id'image(id) & " found !",
						console => true);
					raise constraint_error;
				end if;
			end if;

			exception
				when constraint_error => 
					case prog_position is 
						when 75 => 
							write_message (
								file_handle => current_output,
								text => message_error & "Invalid index found in port '" 
									& to_string(port) & "'! Index must be a positive number !",
								console => true);
						when others => null;
					end case;
					put_line("prog position: verify_pin: " & natural'image(prog_position));
					raise;
		end verify_cell;

	begin -- build_cell_info
		put_line("  building cell info for device " & to_string(device) & " pin " & to_string(pin));
		
		cell_entry_list := read_line(to_string(line), row_separator_1a(1));
		-- CS: do something less time consuming than to_string(line) here

		-- Load cell entries (like "104 bc_1 input x") one by one into cell_entry2 for further processing.
		prog_position := 20;
		-- CS: if cell_entry_list.field_count is in type_field_count
		for e in field_count_min..positive(cell_entry_list.field_count) loop -- we always start with field 2
			-- example: if line is "IC301 NA XC9536 PLCC-S44 3  pb00_01 | 104 bc_1 input x | 103 bc_1 output3 x 102 0 z" then the first field
			-- to read is "104 bc_1 input x" (field 2)
			-- field 3 would be "103 bc_1 output3 x 102 0 z"

			cell_entry2 := read_line(get_field_from_line(cell_entry_list,e));

			-- Read and check fields of cell_entry2 (separated by space):
			for c in 1..positive(cell_entry2.field_count) loop
				case c is
					when 1 => 
						prog_position := 100; 
						cell_id := type_cell_id'value(get_field_from_line(cell_entry2, c));
						-- exception handler will do the rest on error
					when 2 => 
						prog_position := 110;
						cell_type := type_boundary_register_cell'value(get_field_from_line(cell_entry2, c));
						-- exception handler will do the rest on error
					when 3 => 
						prog_position := 120;
						cell_function := type_cell_function'value(get_field_from_line(cell_entry2, c));
						-- exception handler will do the rest on error

						case cell_function is
							-- if it is an input cell, make sure there are no control cell parameters
							when input | clock | observe_only => -- CS: testing required for clock and observe_only, std conformity ?
								case cell_entry2.field_count is
									when 4 => -- an input cell entry has 4 fields
										--put_line(trim(to_string(line),both)); 
										-- look ahead and fetch safe value from field 4
										prog_position := 2000;
										--cell_safe_value := type_bit_char_class_1'value("'" & to_upper(get_field_from_line(to_string(scratch),c + 1)) & "'");
										cell_safe_value := type_bit_char_class_1'value(
																enclose_in_quotes(to_upper(get_field_from_line(cell_entry2,c + 1))));

										-- place the collected input cell info in cell_info
										-- example "104 bc_1 input x"
										-- example "104 bc_1 clock x"
										-- example "104 bc_1 observe_only x"

										-- make sure this is the first and only input cell of this pin
										if cell_info.input_cell_id = -1 then -- if no input cell registered yet (indicated by -1)
											--put_line("input cell ID registered : " & natural'image(cell_info.id_input_cell));
											cell_info.input_cell_id := cell_id; -- register this input cell 
										else -- otherwise an input cell has already been found
											prog_position := 2010;
											write_message (
												file_handle => current_output,
												text => message_error & "Only one input cell allowed !",
												console => true);
											--put_line("input cell ID already registered :" & natural'image(cell_info.id_input_cell));
											raise constraint_error;
										end if;

										cell_info.input_cell_type := cell_type; -- bc_1
										cell_info.input_cell_function := cell_function; -- input
										cell_info.input_cell_safe_value := cell_safe_value;

										prog_position := 2020;
										if degree_of_database_integrity_check >= medium then
											verify_cell(
												id => cell_id, ctype => cell_type, 
												func => cell_function, safe => cell_safe_value,
												pin => pin, port => port, device => device);
										end if;
										
									when others =>
										prog_position := 2100;
										raise constraint_error;
								end case;

							-- (c holds 3) if it is an output2 cell:
							when output2 =>
								case cell_entry2.field_count is
									when 4 =>
										-- look ahead and fetch safe value from field 4
										prog_position := 1100;
										--cell_safe_value := type_bit_char_class_1'value("'" & to_upper(get_field_from_line(to_string(scratch),c + 1)) & "'");
										cell_safe_value := type_bit_char_class_1'value(
															enclose_in_quotes(to_upper(get_field_from_line(cell_entry2,c + 1))));
										if cell_safe_value = 'X' then -- CS: needs testing !
											put_line(message_warning & "Line" & natural'image(line_counter) & ": Output2 cell with undefined safe value found !");
											put_line("affected line : " & to_string(line)); 
										end if;

										-- place the collected output2 cell info in cell_info
										-- example "104 bc_1 output2 1"

										-- make sure this is the first and only output cell of this pin
										if cell_info.output_cell_id = -1 then -- if no output cell registered yet (indicated by default -1)
											cell_info.output_cell_id := cell_id; -- register this output cell 
										else -- otherwise a output cell has already been found
											prog_position := 1110;
											write_message (
												file_handle => current_output,
												text => message_error & "Only one output cell allowed !",
												console => true);
											raise constraint_error;
										end if;

										prog_position := 1120;
										cell_info.output_cell_type := cell_type; -- bc_1
										cell_info.output_cell_function := cell_function; -- output2
										cell_info.output_cell_safe_value := cell_safe_value;

										prog_position := 1130;
										if degree_of_database_integrity_check >= medium then
											verify_cell(
												id => cell_id, ctype => cell_type, 
												func => cell_function, safe => cell_safe_value,
												pin => pin, port => port, device => device);
										end if;

									when 7 => 
										-- A control cell is associated: (103 bc_1 output2 x 103 0 weak0)
										-- In this case it is a "self controlling" output2 cell.

										-- look ahead and fetch safe value from field 4
										prog_position := 1200;
										--cell_safe_value := type_bit_char_class_1'value("'" & to_upper(get_field_from_line(to_string(scratch),c + 1)) & "'");
										cell_safe_value := type_bit_char_class_1'value(
															enclose_in_quotes(to_upper(get_field_from_line(cell_entry2,c + 1))));

										-- make sure the control cell ID (field 5) matches the output cell ID
										-- fetch control cell ID from field 5
										-- raise error on mismatch of output2 cell ID and control cell ID
										prog_position := 1210;
										--cell_control_cell_id := type_cell_id'value(get_field_from_line(to_string(scratch),c + 2));
										cell_control_cell_id := type_cell_id'value(get_field_from_line(cell_entry2,c + 2));
										if cell_id = cell_control_cell_id then 
											null;
										else
											prog_position := 1220;
											raise constraint_error;
										end if;

										-- fetch disable value from field 6
										prog_position := 1230;
										--cell_disable_value := type_bit_char_class_0'value("'" & get_field_from_line(to_string(scratch),c + 3) & "'");
										cell_disable_value := type_bit_char_class_0'value(
																enclose_in_quotes(get_field_from_line(cell_entry2,c + 3))); 

										-- fetch disable result from field 7
										prog_position := 1240;
										--cell_disable_result := type_disable_result'value(get_field_from_line(to_string(scratch),c + 4));
										cell_disable_result := type_disable_result'value(get_field_from_line(cell_entry2,c + 4));

										-- disable result against disable value and put warning if nessecariy
										case cell_disable_result is
											when Z => null;
											when weak0 | pull0 => 
												case cell_disable_value is
													when '0' => null; -- fine
													when '1' =>
														put_line(message_warning & "Line" & natural'image(line_counter) 
															& ": Disable value of self controlled output cell contradicts with disable result !");
														put_line("affected line : " & to_string(line)); 
												end case;
											when weak1 | pull1 =>
												case cell_disable_value is
													when '1' => null; -- fine
													when '0' =>
														put_line(message_warning & "Line" & natural'image(line_counter) 
															& ": Disable value of self controlled output cell contradicts with disable result !");
														put_line("affected line : " & to_string(line)); 
												end case;
											when others => 
												prog_position := 1250;
												raise constraint_error;
										end case;

										-- place the collected output2 cell info in cell_info
										-- example "104 bc_1 output2 x 104 weak0"

										-- make sure this is the first and only output cell of this pin
										if cell_info.output_cell_id = -1 then -- if no output cell registered yet (indicated by default -1)
											cell_info.output_cell_id := cell_id; -- register this output cell 
										else -- otherwise a output cell has already been found
											prog_position := 1260;
											write_message (
												file_handle => current_output,
												text => message_error & "Only one output cell allowed !",
												console => true);
											raise constraint_error;
										end if;

										prog_position := 1270;
										cell_info.output_cell_type := cell_type; -- bc_1
										cell_info.output_cell_function := cell_function; -- output2
										cell_info.output_cell_safe_value := cell_safe_value;
										cell_info.control_cell_id := cell_control_cell_id;
										cell_info.disable_value := cell_disable_value;
										cell_info.disable_result := cell_disable_result;

										prog_position := 1280;
										if degree_of_database_integrity_check >= medium then
											verify_cell(
												id => cell_id, ctype => cell_type, func => cell_function, 
												safe => cell_safe_value, 
												cc => cell_control_cell_id,
												dv => cell_disable_value, dr => cell_disable_result, 
												pin => pin, port => port, device => device);
										end if;

										-- CS: check if control cell is used already and set "shared" flag if nessecary
										--cell_info.control_cell_shared := shared_control_cell(cell_control_cell_id);
									when others => 
										prog_position := 1300;
										raise constraint_error;

								end case;

							-- (c holds 3) if it is an output3 or bidir cell, 
							-- make sure there is a disable specification
							when output3 | bidir =>
								case cell_entry2.field_count is
									when 7 => -- an output3 or bidir cell entry has 7 fields

										-- look ahead and fetch safe value from field 4
										prog_position := 3000;
										--cell_safe_value := type_bit_char_class_1'value("'" & to_upper(get_field_from_line(to_string(scratch),c + 1)) & "'");
										cell_safe_value := type_bit_char_class_1'value(
															enclose_in_quotes(to_upper(get_field_from_line(cell_entry2,c + 1))));

										-- there must be a control cell associated
										-- fetch control cell ID from field 5
										prog_position := 3010;
										--cell_control_cell_id := type_cell_id'value(get_field_from_line(to_string(scratch),c + 2));
										cell_control_cell_id := type_cell_id'value(get_field_from_line(cell_entry2,c + 2));

										-- Put warning if control cell ID (field 5) matches the output cell ID (should be quite unusual)
										-- In this case it is a "self controlling" output3 or bidir cell (should be quite unusual).
										if cell_id = cell_control_cell_id then 
											prog_position := 3020;
											put_line(message_warning & "Self controlling " & type_cell_function'image(output3) & " cell found.");
											put_line("line   : " & to_string(line)); 
											--put_line("cell   : " & to_string(cell_entry(e)));

											-- CS: check std conformity !
											--raise constraint_error;
										end if;

										-- fetch disable value from field 6
										prog_position := 3030;
										--cell_disable_value := type_bit_char_class_0'value("'" & get_field_from_line(to_string(scratch),c + 3) & "'");
										cell_disable_value := type_bit_char_class_0'value(
																enclose_in_quotes(get_field_from_line(cell_entry2,c + 3))); 

										-- fetch disable result from field 7
										prog_position := 3040;
										--cell_disable_result := type_disable_result'value(get_field_from_line(to_string(scratch),c + 4));
										cell_disable_result := type_disable_result'value(get_field_from_line(cell_entry2,c + 4)); 


										-- place the collected output3 or bidir cell info in cell_info
										-- example "104 bc_1 output3 x 17 weak0"
										-- or "15 BC_7 BIDIR X 14 1 Z"

										-- make sure this is the first and only output cell of this pin
										if cell_info.output_cell_id = -1 then -- if no output cell registered yet (indicated by default -1)
											cell_info.output_cell_id := cell_id; -- register this output cell 

											-- in case of a bidir cell, the input and output cell id are the same:
											if cell_function = bidir then
												-- Make sure there has no input cell been found yet.
												-- Assign the input cell the same id, type, function and safe value as the output cell,
												-- because output and input cell are the same.
												if cell_info.input_cell_id = -1 then
													cell_info.input_cell_id := cell_id; 
													cell_info.input_cell_type := cell_type;
													cell_info.input_cell_function := cell_function;
													cell_info.input_cell_safe_value := cell_safe_value;
												else
													write_message (
														file_handle => current_output,
														text => message_error & "Only one input cell allowed !",
														console => true);
												end if;
											end if;
											
										else -- otherwise an output cell has already been found
											prog_position := 3050;
											write_message (
												file_handle => current_output,
												text => message_error & "Only one output cell allowed !",
												console => true);
											raise constraint_error;
										end if;

										prog_position := 3060;
										cell_info.output_cell_type := cell_type; -- bc_1
										cell_info.output_cell_function := cell_function; -- output3 or bidir
										cell_info.output_cell_safe_value := cell_safe_value;
										cell_info.control_cell_id := cell_control_cell_id;
										cell_info.disable_value := cell_disable_value;
										cell_info.disable_result := cell_disable_result;

										prog_position := 3070;
										if degree_of_database_integrity_check >= medium then
											verify_cell(
												id => cell_id, ctype => cell_type, func => cell_function,
												safe => cell_safe_value,
												cc => cell_control_cell_id,
												dv => cell_disable_value, dr => cell_disable_result, 
												pin => pin, port => port, device => device);
										end if;
										
										-- CS: check if control cell is used already and set "shared" flag if nessecary
										--cell_info.control_cell_shared := shared_control_cell(cell_control_cell_id);

									when others =>
										prog_position := 3100;
										raise constraint_error;
								end case;

							when others => -- CS: other cell functions should not appear here
								prog_position := 3200;
								raise constraint_error;
						end case;
						
					when others => 
						-- No further accessing of fields within cell entry required, because in previous cases fields 4..7 have been
						-- looked for and checked ahead.
						exit;
				end case;
			end loop;

		end loop;

		-- now all data for cell_info has been collected
		
		-- if there is an input cell, do some cross checking
		if cell_info.input_cell_id /= -1 then
			
			-- If non-bidir cell, make sure input and output cell IDs are not the same and put a warning if nessecariy
			if cell_info.output_cell_function /= bidir then
				if cell_info.input_cell_id = cell_info.output_cell_id then
					put_line(message_warning & "ID of input and output cell are the same !");
					put_line("line : " & to_string(line)); 
					prog_position := 4000;
				end if;
			end if;
			
			-- make sure input and control cell IDs are not the same and put a warning if nessecariy
			if cell_info.input_cell_id = cell_info.control_cell_id then
				put_line(message_warning & "ID of input and control cell are the same !");
				put_line("line : " & to_string(line)); 
				prog_position := 4010;
			end if;
		end if;

		return cell_info;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => 
						write_message (
							file_handle => current_output,
							text => message_error & "At least one and maximal two cell entries separated by '" 
								& row_separator_1a & "' allowed ! Found :" 
								& natural'image(ada.strings.fixed.count(to_string(line),row_separator_1a)),
							console => true);
					when 100 => 
						write_message (
							file_handle => current_output,
							text => message_error & "Boundary register cell ID as natural number expected after '" 
								& row_separator_1a & "' !",
							console => true);
					when 110 => 
						write_message (
							file_handle => current_output,
							text => message_error & "Invalid cell type found after cell ID !",
							console => true);
						-- CS: put allowed cell types using enumeration_io
					when 120 => 
						write_message (
							file_handle => current_output,
							text => message_error & "Invalid cell function found after cell type !",
							console => true);
						-- CS: put allowed cell functions using enumeration_io
					when 2000 | 1100 | 1200 | 3000 => 
						write_message (
							file_handle => current_output,
							text => message_error & "Invalid safe value found after cell function !",
							console => true);
					when 2100 => 
						write_message (
							file_handle => current_output,
							text => message_error & "Too many parameters for this kind of cell !",
							console => true);
					when 1210 => 
						write_message (
							file_handle => current_output,
							text => message_error & "Control cell ID as natural number expected after safe value !",
							console => true);
					when 1220 => 
						write_message (
							file_handle => current_output,
							text => message_error & "ID of output cell and associated control cell must match !",
							console => true);
					when 1230 | 3030 =>
						write_message (
							file_handle => current_output,
							text => message_error & "Invalid disable value found after control cell !",
							console => true);
						-- CS: put allowed cell functions using enumeration_io
					when 1240 | 3040 =>
						write_message (
							file_handle => current_output,
							text => message_error & "Invalid disable result found after disable value !",
							console => true);
						-- CS: put allowed cell functions using enumeration_io
					when 30 | 1300 | 3100 => 
						write_message (
							file_handle => current_output,
							text => message_error & "Invalid field count within cell entry ! " 
								& "Valid number of fields are:" 
								& positive'image(cell_entry_field_count_min) & " and " 
								& trim(positive'image(cell_entry_field_count_max),left) & ".",
							console => true);
					when others => null;
				end case;

				put_line("line : " & to_string(line)); 
-- 				put_line("cell : " & to_string(cell_entry(e_bak)));
				put_line("prog position:" & natural'image(prog_position));
				raise;
	end build_cell_info;


	procedure complete_net_data (
	-- Builds a complete dataset for a net (from the given arguments) and appends the net to the database netlist.
	-- Updates the net statistics in summary.
		name 				: in type_net_name.bounded_string;
		name_of_primary_net	: in type_net_name.bounded_string := to_bounded_string("");
		class				: in type_net_class;
		pinlist 			: in type_list_of_pins.vector;
		level 				: in type_net_level;
		secondary_net_names	: in type_list_of_secondary_net_names.vector := empty_list_of_secondary_net_names;
		net_counter			: in out natural
		) is
		
		prog_position	: natural := 0;
		bs_input_count	: natural := 0;
		bs_output_count	: natural := 0;
		bs_bidir_count	: natural := 0;
		bs_capable		: boolean := false; -- true if net has scan capable pins
	begin
		put_line("  completing net with pins :");
		
		if degree_of_database_integrity_check >= medium then
			verify_net_appears_only_once_in_net_list(name);
		end if;

		net_counter := net_counter + 1; -- inout variable !
		
		-- CS: progress bar
		if (net_counter rem 100) = 0 then -- put a dot every 100 nets
			put(standard_output,'.');
		end if;
		
-- 		if (net_counter rem 10) = 0 then -- put a dot every 10 nets
-- 			put(standard_output,'-' & latin_1.cr);
-- 		end if;
-- 		if (net_counter rem 20) = 0 then -- put a dot every 10 nets
-- 			put(standard_output,'/' & latin_1.cr);
-- 		end if;
-- 		if (net_counter rem 30) = 0 then -- put a dot every 10 nets
-- 			put(standard_output,'|' & latin_1.cr);
-- 		end if;
-- 		if (net_counter rem 40) = 0 then -- put a dot every 10 nets
-- 			put(standard_output,'\' & latin_1.cr);
-- 		end if;

-- 		case (net_counter rem 20) is
-- 			when 0 => put(standard_output,'-' & latin_1.cr);
-- 			when 2 => put(standard_output,'/' & latin_1.cr);
-- 			when 4 => put(standard_output,'|' & latin_1.cr);
-- 			when 6 => put(standard_output,'\' & latin_1.cr);
-- 			when others => null;
-- 		end case;
		
		-- Evaluate scan capabilites of net.
		-- loop in given pinlist
		for p in 1..length(pinlist) loop 
			--pin := element(pinlist, positive(p));
			-- NOTE: element(pinlist, positive(p)) equals the particular pin
			
			put_line ("   device " & to_string(element(pinlist, positive(p)).device_name) &
				" pin "  & to_string(element(pinlist, positive(p)).device_pin_name));

			-- look at scan capable pins only
			if element(pinlist, positive(p)).is_bscan_capable then
			
				-- count bidir pins (both input and output cell provided)
				if element(pinlist, positive(p)).cell_info.input_cell_id /= -1 
					and element(pinlist, positive(p)).cell_info.output_cell_id /= -1 then
						bs_bidir_count := bs_bidir_count + 1; 
						bs_capable := true; -- set bs_capable flag
				end if;

				-- count input pins (only input cell provided)
				if element(pinlist, positive(p)).cell_info.input_cell_id /= -1 
					and element(pinlist, positive(p)).cell_info.output_cell_id = -1 then
						bs_input_count := bs_input_count + 1;
						bs_capable := true; -- set bs_capable flag
				end if;

				-- count output pins (only output cell provided)
				if element(pinlist, positive(p)).cell_info.output_cell_id /= -1 
					and element(pinlist, positive(p)).cell_info.input_cell_id = -1 then
						bs_output_count := bs_output_count + 1;
						bs_capable := true; -- set bs_capable flag
				end if;

			end if;
		end loop;
		
		-- if net is scan capable, report pin count of bidir, output and input
		if bs_capable then
			write_message (
				file_handle => current_output,
				identation => 3,
				text => "bs pin count: bidir" & natural'image(bs_bidir_count) &
						" input"  & natural'image(bs_input_count) &
						" output" & natural'image(bs_output_count));
		end if;

		-- CS: check level and class against bs_pin counts !
		case level is
			when primary =>
				case class is
					when NR | DL | DH | PU | PD | EH | EL =>
						if not bs_capable then
							write_message (
								file_handle => current_output,
								text => message_error & "Net " & to_string(name) 
									& " has no scan capable pins. It can not become a primary net of class " 
									& type_net_class'image(class) & " !",
								console => true);
							raise constraint_error;
						end if;
					when others => null;
				end case;

			when secondary =>
				case class is
					when NR | DL | DH | PU | PD | EH | EL =>
						if not bs_capable then
							write_message (
								file_handle => current_output,
								text => message_warning & "Net " & to_string(name) 
									& " has no scan capable pins. It can not be tested fully !",
								console => false);
						end if;
					when others => null;
				end case;
		end case;

		-- CS: check net class against bs_pin directions (in, out, disable results)

		prog_position := 300;

		add_to_net_list(
			name_given					=> name,
			class_given					=> class,
			bs_bidir_pin_count_given	=> bs_bidir_count,
			bs_input_pin_count_given	=> bs_input_count,
			bs_output_pin_count_given	=> bs_output_count,
			bs_capable_given			=> bs_capable,
			net_level_given				=> level, 
			name_of_primary_net_given	=> name_of_primary_net, -- don't care if level of targeted net is primary already
			pins_given		 			=> pinlist,
			secondary_net_names			=> secondary_net_names -- don't care if level of targeted net is secondary already
			);

-- 		-- update net statistics. NOTE: number of atg_drivers and atg_receivers is calculated by chkpsn (when writing statistics).
-- 		summary.net_count_statistics.total := summary.net_count_statistics.total + 1;
-- 		case class is
-- 			when PU => 
-- 				summary.net_count_statistics.pu 			:= summary.net_count_statistics.pu + 1;
-- 				summary.net_count_statistics.bs_dynamic		:= summary.net_count_statistics.bs_dynamic + 1;
-- 				summary.net_count_statistics.bs_testable	:= summary.net_count_statistics.bs_testable + 1;
-- 			when PD => 
-- 				summary.net_count_statistics.pd 			:= summary.net_count_statistics.pd + 1; 
-- 				summary.net_count_statistics.bs_dynamic 	:= summary.net_count_statistics.bs_dynamic + 1;
-- 				summary.net_count_statistics.bs_testable 	:= summary.net_count_statistics.bs_testable + 1;
-- 			when DH => 
-- 				summary.net_count_statistics.dh 			:= summary.net_count_statistics.dh + 1;
-- 				summary.net_count_statistics.bs_static 		:= summary.net_count_statistics.bs_static + 1;
-- 				summary.net_count_statistics.bs_static_h 	:= summary.net_count_statistics.bs_static_h + 1;
-- 				summary.net_count_statistics.bs_testable 	:= summary.net_count_statistics.bs_testable + 1;
-- 			when DL => 
-- 				summary.net_count_statistics.dl 			:= summary.net_count_statistics.dl + 1;
-- 				summary.net_count_statistics.bs_static 		:= summary.net_count_statistics.bs_static + 1;
-- 				summary.net_count_statistics.bs_static_l 	:= summary.net_count_statistics.bs_static_l + 1;
-- 				summary.net_count_statistics.bs_testable 	:= summary.net_count_statistics.bs_testable + 1;
-- 			when EH => 
-- 				summary.net_count_statistics.eh 			:= summary.net_count_statistics.eh + 1;
-- 				summary.net_count_statistics.bs_static 		:= summary.net_count_statistics.bs_static + 1;
-- 				summary.net_count_statistics.bs_static_h 	:= summary.net_count_statistics.bs_static_h + 1;
-- 				summary.net_count_statistics.bs_testable 	:= summary.net_count_statistics.bs_testable + 1;
-- 			when EL => 
-- 				summary.net_count_statistics.el 			:= summary.net_count_statistics.el + 1;
-- 				summary.net_count_statistics.bs_static 		:= summary.net_count_statistics.bs_static + 1;
-- 				summary.net_count_statistics.bs_static_l 	:= summary.net_count_statistics.bs_static_l + 1;
-- 				summary.net_count_statistics.bs_testable 	:= summary.net_count_statistics.bs_testable + 1;
-- 			when NR => 
-- 				summary.net_count_statistics.nr 			:= summary.net_count_statistics.nr + 1;
-- 				summary.net_count_statistics.bs_dynamic 	:= summary.net_count_statistics.bs_dynamic + 1;
-- 				summary.net_count_statistics.bs_testable 	:= summary.net_count_statistics.bs_testable + 1;
-- 			when NA => 
-- 				summary.net_count_statistics.na 			:= summary.net_count_statistics.na + 1;
-- 		end case;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;

				put_line("prog position: Complete net data CN" & trim(natural'image(prog_position),left));
				raise;

	end complete_net_data;


	procedure put_error_on_endsection_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & section_mark.endsection & " expected !",
			console => true);
		raise constraint_error;
	end put_error_on_endsection_expected;

	procedure cell_list_put_error_on_class_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_class & "' at begin of line !",
			console => true);
		raise constraint_error;
	end cell_list_put_error_on_class_keyword_expected;

	procedure cell_list_put_error_on_invalid_class is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Invalid net class found in this section !",
			console => true);
		raise constraint_error;		
	end cell_list_put_error_on_invalid_class;

-- 	procedure cell_list_put_error_on_invalid_net_level is
-- 	begin
-- 		put_line("ERROR: Expected net level keyword '" & type_cell_list_net_level'image(primary_net) & "' or '" &
-- 			type_cell_list_net_level'image(secondary_net) & "' after net class !");
-- 	end cell_list_put_error_on_invalid_net_level;

	procedure cell_list_put_error_on_device_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_device & "' after net name !",
			console => true);
		raise constraint_error;
	end cell_list_put_error_on_device_keyword_expected;

	procedure cell_list_put_error_on_pin_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_pin & "' after device name !",
			console => true);
		raise constraint_error;		
	end cell_list_put_error_on_pin_keyword_expected;

	procedure cell_list_put_error_on_control_cell_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_control_cell & "' after pin name !",
			console => true);

		write_message (
			file_handle => current_output,
			text => "This section addresses control cells exclusively !",
			console => true);

		raise constraint_error;
	end cell_list_put_error_on_control_cell_keyword_expected;

	procedure cell_list_put_error_on_output_cell_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_output_cell & "' after pin name !",
			console => true);

		write_message (
			file_handle => current_output,
			text => "This section addresses output cells exclusively !",
			console => true);

		raise constraint_error;		
	end cell_list_put_error_on_output_cell_keyword_expected;

	procedure cell_list_put_error_on_output_or_control_cell_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_output_cell & "' or '" & 
				cell_list_keyword_control_cell & "' after pin name !",
			console => true);

		write_message (
			file_handle => current_output,
			text => "This section addresses output or control cells exclusively !",
			console => true);

		raise constraint_error;
	end cell_list_put_error_on_output_or_control_cell_keyword_expected;

	procedure cell_list_put_error_on_input_cell_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_input_cell & "' after pin name !",
			console => true);

		write_message (
			file_handle => current_output,
			text => "This section addresses input cells exclusively !",
			console => true);

		raise constraint_error;		
	end cell_list_put_error_on_input_cell_keyword_expected;

	procedure cell_list_put_error_on_expect_value_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_expect_value & "' after cell id !",
			console => true);
		raise constraint_error;		
	end cell_list_put_error_on_expect_value_keyword_expected;

	procedure cell_list_put_error_on_cell_locked_to_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_locked_to & "' after cell id !",
			console => true);
		raise constraint_error;
	end cell_list_put_error_on_cell_locked_to_keyword_expected;

	procedure cell_list_put_error_on_drive_value_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_drive_value & "' after 'locked_to' !",
			console => true);
		raise constraint_error;		
	end cell_list_put_error_on_drive_value_keyword_expected;

	procedure cell_list_put_error_on_cell_disable_value_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_disable_value 
				& "' after '" & cell_list_keyword_locked_to & "' !",
			console => true);
		raise constraint_error;
	end cell_list_put_error_on_cell_disable_value_keyword_expected;

	procedure cell_list_put_error_on_enable_disable_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected keyword '" & cell_list_keyword_disable_value & "' or '"
				 & cell_list_keyword_enable_value & "' after 'locked_to' !",
			console => true);
		raise constraint_error;				
	end cell_list_put_error_on_enable_disable_keyword_expected; 

	procedure cell_list_put_error_on_invalid_static_expect_value is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Invalid expect value for input cell in this net class !",
			console => true);
		raise constraint_error;				
	end cell_list_put_error_on_invalid_static_expect_value;

	procedure cell_list_put_error_on_primary_net_is_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "After '" & cell_list_keyword_expect_value 
				& "' expected keyword '" 
				& cell_list_keyword_primary_net_is & "' followed by name of primary net !",
			console => true);

		write_message (
			file_handle => current_output,
			text => "Secondary nets require specification of superordinated primary net !",
			console => true);

		write_message (
			file_handle => current_output,
			text => "Example: 'class DL secondary_net A3R device IC1 pin 2 input_cell 7 expect_value 0 primary_net_is A3' ",
			console => true);

		-- CS: use predefined keywords for cell list here.
		raise constraint_error;				
	end cell_list_put_error_on_primary_net_is_keyword_expected;

	procedure cell_list_put_error_on_primary_net_name_mismatch is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Invalid primary net name found after '" & cell_list_keyword_primary_net_is & "' !",
			console => true);

		write_message (
			file_handle => current_output,
			text => "The primary net name differs from the one specified in netlist !",
			console => true);

		raise constraint_error;				
	end cell_list_put_error_on_primary_net_name_mismatch;

	procedure cell_list_put_error_on_control_cell_inverted_keyword_expected is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Expected '" 
				& cell_list_keyword_control_cell_inverted & row_separator_0 & cell_list_keyword_yes & "' or '" 
				& cell_list_keyword_control_cell_inverted & row_separator_0 & cell_list_keyword_no & "' !",
			console => true);
		raise constraint_error;		
	end cell_list_put_error_on_control_cell_inverted_keyword_expected;

	procedure cell_list_put_error_on_contradicting_net_level (
		net		: type_net_name.bounded_string;
		level	: type_net_level )
		is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Level of net " & to_string(net) 
				& " should be type " & type_net_level'image(level) & " !",
			console => true);

		write_message (
			file_handle => current_output,
			text => "The level found contradicts with those specified in section 'netlist' !", -- CS: use constant
			console => true);

		raise constraint_error;				
	end cell_list_put_error_on_contradicting_net_level;

	procedure cell_list_put_error_on_contradicting_net_class (
		net		: type_net_name.bounded_string;
		class	: type_net_class )
		is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Class of net " & to_string(net) & " should be " & type_net_class'image(class) & " !",
			console => true);

		write_message (
			file_handle => current_output,
			text => "The class found contradicts with the one specified in section 'netlist' !",
			console => true);

		raise constraint_error;				
	end cell_list_put_error_on_contradicting_net_class;

	procedure cell_list_put_error_on_non_scan_net (
		net : type_net_name.bounded_string) is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Net " & to_string(net) & " is not scan capable and must not appear here !",
			console => true);
		raise constraint_error;				
	end cell_list_put_error_on_non_scan_net;

	procedure cell_list_put_error_on_invalid_control_cell is
	begin 
		write_message (
			file_handle => current_output,
			text => message_error & "Control cell ID invalid ! Contradiction with those specified in section 'netlist' !",
			console => true);
		raise constraint_error;				
	end cell_list_put_error_on_invalid_control_cell;

	procedure cell_list_put_error_on_invalid_output_cell is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Output cell ID invalid ! Contradiction with those specified in section 'netlist' !",
			console => true);
		raise constraint_error;		
	end cell_list_put_error_on_invalid_output_cell;

	procedure cell_list_put_error_on_invalid_input_cell is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Input cell ID invalid ! Contradiction with those specified in section 'netlist' !",
			console => true);
		raise constraint_error;				
	end cell_list_put_error_on_invalid_input_cell;

	procedure cell_list_put_error_on_invalid_disable_value is
	begin 
		write_message (
			file_handle => current_output,
			text => message_error & "Control cell disable value invalid ! Contradiction with those specified in section 'netlist' !",
			console => true);
		raise constraint_error;				
	end cell_list_put_error_on_invalid_disable_value;

	procedure cell_list_put_error_on_invalid_enable_value is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Control cell enable value invalid ! Contradiction with disable value specified in section 'netlist' !",
			console => true);
		raise constraint_error;				
	end cell_list_put_error_on_invalid_enable_value;

	procedure cell_list_put_error_on_pin_not_found(
		device		: type_device_name.bounded_string;
		pin			: type_pin_name.bounded_string;
		net			: type_net_name.bounded_string
		) is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Device '" & to_string(device) & "' pin '" & to_string(pin) 
				& "' is not connected to net '" & to_string(net) & "' !",
			console => true);
		raise constraint_error;				
	end cell_list_put_error_on_pin_not_found;

	procedure cell_list_put_error_on_net_not_found(
		net 		: type_net_name.bounded_string
		) is
	begin
		write_message (
			file_handle => current_output,
			text => message_error & "Net '" & to_string(net) & "' does not appear in netlist and is considered as invalid !",
			console => true);
		raise constraint_error;				
	end cell_list_put_error_on_net_not_found;


	procedure mark_bic_as_having_static_drive_cell (device : in type_device_name.bounded_string) is
-- 		bic_found : boolean := false;

-- 		procedure set_has_static_drive_cell ( bic : in out type_bscan_ic) is
-- 		begin
-- 			bic.has_static_drive_cell := true;
-- 		end set_has_static_drive_cell;

		procedure set_has_static_drive_cell ( key : in type_device_name.bounded_string; bic : in out type_bscan_ic) is
		begin
			bic.has_static_drive_cell := true;
		end set_has_static_drive_cell;

	begin
-- 		for b in 1..length(list_of_bics) loop    
-- 			if element(list_of_bics,positive(b)).name = device then
-- 				bic_found := true;
-- 				update_element(list_of_bics,positive(b),set_has_static_drive_cell'access);
-- 				exit;
-- 			end if;
-- 		end loop;

		update_element(
			container => list_of_bics,
			position => find(list_of_bics, device),
			process => set_has_static_drive_cell'access
			);
						

-- 		if not bic_found then
-- 			write_message (
-- 				file_handle => current_output,
-- 				text => message_error & "Device '" & to_string(device) & "' is not part of any scanpath !",
-- 				console => true);
-- 			raise constraint_error;
-- 		end if;
	end mark_bic_as_having_static_drive_cell;

	procedure mark_bic_as_having_static_expect_cell(device : type_device_name.bounded_string) is
-- 		bic_found : boolean := false;
-- 		procedure set_has_static_expect_cell ( bic : in out type_bscan_ic) is
-- 		begin
-- 			bic.has_static_expect_cell := true;
-- 		end set_has_static_expect_cell;

		procedure set_has_static_expect_cell ( key : in type_device_name.bounded_string; bic : in out type_bscan_ic) is
		begin
			bic.has_static_expect_cell := true;
		end set_has_static_expect_cell;

	begin
-- 		for b in 1..length(list_of_bics) loop    
-- 			if element(list_of_bics,positive(b)).name = device then            
-- 				bic_found := true;
-- 				update_element(list_of_bics,positive(b),set_has_static_expect_cell'access);
-- 				exit;
-- 			end if;
-- 		end loop;

		update_element(
			container => list_of_bics,
			position => find(list_of_bics, device),
			process => set_has_static_expect_cell'access
			);

-- 		if not bic_found then
-- 			write_message (
-- 				file_handle => current_output,
-- 				text => message_error & "Device '" & to_string(device) & "' is not part of any scanpath !",
-- 				console => true);
-- 			raise constraint_error;
-- 		end if;
	end mark_bic_as_having_static_expect_cell;

	procedure mark_bic_as_having_dynamic_drive_cell(device : type_device_name.bounded_string) is
-- 		bic_found : boolean := false;
-- 		procedure set_has_dynamic_drive_cell ( bic : in out type_bscan_ic) is
-- 		begin
-- 			bic.has_dynamic_drive_cell := true;
-- 		end set_has_dynamic_drive_cell;

		procedure set_has_dynamic_drive_cell ( key : in type_device_name.bounded_string; bic : in out type_bscan_ic) is
		begin
			bic.has_dynamic_drive_cell := true;
		end set_has_dynamic_drive_cell;

	begin
-- 		for b in 1..length(list_of_bics) loop            
-- 			if element(list_of_bics,positive(b)).name = device then                        
-- 				bic_found := true;
-- 				update_element(list_of_bics,positive(b),set_has_dynamic_drive_cell'access);
-- 				exit;
-- 			end if;
-- 		end loop;

		update_element(
			container => list_of_bics,
			position => find(list_of_bics, device),
			process => set_has_dynamic_drive_cell'access
			);


-- 		if not bic_found then
-- 			write_message (
-- 				file_handle => current_output,
-- 				text => message_error & "Device '" & to_string(device) & "' is not part of any scanpath !",
-- 				console => true);
-- 			raise constraint_error;
-- 		end if;
	end mark_bic_as_having_dynamic_drive_cell;

	procedure mark_bic_as_having_dynamic_expect_cell(device : type_device_name.bounded_string) is
-- 		bic_found : boolean := false;
-- 		procedure set_has_dynamic_expect_cell ( bic : in out type_bscan_ic) is
-- 		begin
-- 			bic.has_dynamic_expect_cell := true;
-- 		end set_has_dynamic_expect_cell;

		procedure set_has_dynamic_expect_cell ( key : in type_device_name.bounded_string; bic : in out type_bscan_ic) is
		begin
			bic.has_dynamic_expect_cell := true;
		end set_has_dynamic_expect_cell;

	begin
-- 		for b in 1..length(list_of_bics) loop                    
-- 			if element(list_of_bics,positive(b)).name = device then                                    
-- 				bic_found := true;
-- 				update_element(list_of_bics,positive(b),set_has_dynamic_expect_cell'access);
-- 				exit;
-- 			end if;
-- 		end loop;

		update_element(
			container => list_of_bics,
			position => find(list_of_bics, device),
			process => set_has_dynamic_expect_cell'access
			);

-- 		if not bic_found then
-- 			write_message (
-- 				file_handle => current_output,
-- 				text => message_error & "Device '" & to_string(device) & "' is not part of any scanpath !",
-- 				console => true);
-- 			raise constraint_error;
-- 		end if;
	end mark_bic_as_having_dynamic_expect_cell;

	-- PROCESSING CELL LISTS BEGIN

	procedure mark_control_cell_as_appears_in_cell_list (pin : in out type_pin) is
	begin
		pin.cell_info.control_cell_appears_in_cell_list := true;
	end mark_control_cell_as_appears_in_cell_list;

	procedure mark_output_cell_as_appears_in_cell_list (pin : in out type_pin) is
	begin
		pin.cell_info.output_cell_appears_in_cell_list := true;
	end mark_output_cell_as_appears_in_cell_list;

	procedure mark_input_cell_as_appears_in_cell_list (pin : in out type_pin) is
	begin
		pin.cell_info.input_cell_appears_in_cell_list := true;
	end mark_input_cell_as_appears_in_cell_list;
	
	procedure lock_control_cell_in_class_EH_EL_NA_net(
		-- The pin and cell data extracted from the cell list is verified against the netlist.
		-- If valid, the cell info will be filled with those values.
		class 			: type_net_class;
		level 			: type_net_level;
		net				: type_net_name.bounded_string;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		control_cell_id					: type_cell_id;
		control_cell_in_enable_state	: boolean; -- not enumerated here because the control cell value is taken as disable value anyway
		control_cell_value				: type_bit_char_class_0
		) is
		net_scratch		: type_net;
		prog_position	: natural := 0;
		pin_found		: boolean := false;
-- 		net_found		: boolean := false;

		procedure set_control_cell_value (pin : in out type_pin) is
		begin
			pin.cell_info.control_cell_drive_static := control_cell_value;
		end set_control_cell_value;

-- 		net_cursor : type_list_of_nets.cursor := first(list_of_nets);
	begin
		put_line ( "  class " & type_net_class'image(class) & " level " & type_net_level'image(level) & " net " 
			& to_string(net) & " device " & to_string(device) & " pin " & to_string(pin) & " ctrl cell " 
			& type_cell_id'image(control_cell_id) 
			& " disable value " & type_bit_char_class_0'image(control_cell_value));

		prog_position := 10;
		--for n in 1..length(list_of_nets) loop
-- 		while net_cursor /= type_list_of_nets.no_element loop
			--net_scratch := element(list_of_nets, positive(n));
			net_scratch := element(list_of_nets,net);
-- 			next(net_cursor);
			
			--if net_scratch.name = net then
-- 			if key(net_cursor) = net then
-- 				net_found := true;

				--put_line("found net in list");
				prog_position := 100;
				if not net_scratch.bs_capable then
					cell_list_put_error_on_non_scan_net (net => net);
					raise constraint_error;
				end if;

				prog_position := 200;
				if net_scratch.class /= class then
					cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
					raise constraint_error;
				end if;

				prog_position := 300;
				if net_scratch.level /= level then
					cell_list_put_error_on_contradicting_net_level(net => net, level => net_scratch.level);
					raise constraint_error;
				end if;

				prog_position := 400;
				for p in 1..length(net_scratch.pins) loop
					--pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).device_name = device and element(net_scratch.pins, positive(p)).device_pin_name = pin then
						pin_found := true;
						mark_bic_as_having_static_drive_cell(device);
						prog_position := 410;
						
						if element(net_scratch.pins, positive(p)).cell_info.control_cell_id /= control_cell_id then
							cell_list_put_error_on_invalid_control_cell;
							raise constraint_error;
						else
							-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
							if element(net_scratch.pins, positive(p)).cell_info.control_cell_appears_in_cell_list then
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(device) & " pin " 
										& to_string(pin) & " control cell" 
										& type_cell_id'image(control_cell_id) & " already in cell list !",
									console => true);
								raise constraint_error;
							else
								-- mark this cell as "appeares in cell list"
-- 								pin_scratch.cell_info.control_cell_appears_in_cell_list := true;
								
								update_element(
									container => net_scratch.pins, 
									index => positive(p),
									process => mark_control_cell_as_appears_in_cell_list'access);
							end if;
						end if;
						
						-- if control cell value in cell list differs from disable value in netlist, abort.
						-- otherwise control_cell_drive_static is set according to given control cell value
						if element(net_scratch.pins, positive(p)).cell_info.disable_value /= control_cell_value then
							cell_list_put_error_on_invalid_disable_value;
							raise constraint_error;
						else
							--element(net_scratch.pins, positive(p)).cell_info.control_cell_drive_static := control_cell_value;
							update_element(
								container => net_scratch.pins,
								index => positive(p),
								process => set_control_cell_value'access);
						end if;

						--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);
						exit; -- no more searching required
					end if;
				end loop;
				
				prog_position := 420;
				if not pin_found then
					cell_list_put_error_on_pin_not_found(device => device, pin => pin, net => net);
					raise constraint_error;
				end if;

				--replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace(container => list_of_nets, key => net, new_item => net_scratch);
-- 				exit;
-- 			end if;
-- 		end loop;
		
		-- if net not found in net list
-- 		if not net_found then 
-- 			cell_list_put_error_on_net_not_found(net => net);
-- 			raise constraint_error;
-- 		end if;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Lock control cell in class EH EL NA net : " & trim(natural'image(prog_position),left));
				raise;
	end lock_control_cell_in_class_EH_EL_NA_net;
	
	procedure lock_control_cell_in_class_DX_NR(
		-- The pin and cell data extracted from the cell list is verified against the net list.
		-- If valid, the cell info will be filled with those values.
		class 			: type_net_class;
		level 			: type_net_level;
		net				: type_net_name.bounded_string;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		control_cell_id					: type_cell_id;
		control_cell_in_enable_state	: boolean;
		control_cell_value				: type_bit_char_class_0
		) is
		net_scratch		: type_net;
		prog_position	: natural := 0;
		pin_found		: boolean := false;
-- 		net_found		: boolean := false;

		procedure set_control_cell_value (pin : in out type_pin) is
		begin
			pin.cell_info.control_cell_drive_static := control_cell_value;
		end set_control_cell_value;

	begin
		put_line("  class " & type_net_class'image(class) & " level " & type_net_level'image(level) & " net " 
			& to_string(net) & " device " & to_string(device) & " pin " & to_string(pin) & " ctrl cell" 
			& type_cell_id'image(control_cell_id) & " value " & type_bit_char_class_0'image(control_cell_value) 
			& " enable state " & boolean'image(control_cell_in_enable_state));

		prog_position := 10;
		--for n in 1..length(list_of_nets) loop
-- 		while net_cursor /= type_list_of_nets.no_element loop
-- 			--net_scratch := element(list_of_nets, positive(n));
-- 			net_scratch := element(net_cursor);
-- 			next(net_cursor);
			
			-- 			if net_scratch.name = net then
			net_scratch := element(list_of_nets,net);
-- 				net_found := true;

				prog_position := 100;
				if not net_scratch.bs_capable then
					cell_list_put_error_on_non_scan_net (net => net);
					raise constraint_error;
				end if;

				prog_position := 200;
				if net_scratch.class /= class then
					cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
					raise constraint_error;
				end if;

				prog_position := 300;
				if net_scratch.level /= level then
					cell_list_put_error_on_contradicting_net_level(net => net, level => net_scratch.level);
					raise constraint_error;
				end if;

				prog_position := 400;
				for p in 1..length(net_scratch.pins) loop
					--pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).device_name = device and element(net_scratch.pins, positive(p)).device_pin_name = pin then
						pin_found := true;
						mark_bic_as_having_static_drive_cell(device);
						prog_position := 410;

						-- the pin found in the net list must have the current control cell associated
						if element(net_scratch.pins, positive(p)).cell_info.control_cell_id /= control_cell_id then
							cell_list_put_error_on_invalid_control_cell;
							raise constraint_error;
						else
							-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
							if element(net_scratch.pins, positive(p)).cell_info.control_cell_appears_in_cell_list then
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(device) & " pin " 
										& to_string(pin) & " control cell" 
										& type_cell_id'image(control_cell_id) & " already in cell list !",
									console => true);
								raise constraint_error;
							else
								-- mark this cell as "appears in cell list"
								--pin_scratch.cell_info.control_cell_appears_in_cell_list := true;
								update_element(
									container => net_scratch.pins,
									index => positive(p),
									process => mark_control_cell_as_appears_in_cell_list'access);
							end if;
						end if;
						
						-- if control cell disable/enable value in cell list differs from disable value in netlist, abort.
						case control_cell_in_enable_state is
							when false => -- means the control cell is locked to disable value
								-- so the disable value given in net list must match the given control cell value 
								if element(net_scratch.pins, positive(p)).cell_info.disable_value = control_cell_value then
									null; -- fine
								else
									cell_list_put_error_on_invalid_disable_value;
									raise constraint_error;
								end if;
							when true => -- means the control cell is locked to enable value
								-- so the disable value given in net list must match the given control cell value INVERTED
								-- since this data type is type_bit_char_class_0 (either 0 or 1), checking the inverted value is easy:
								if element(net_scratch.pins, positive(p)).cell_info.disable_value /= control_cell_value then
									null; -- fine
								else
									cell_list_put_error_on_invalid_enable_value;
									raise constraint_error;
								end if;
						end case;
						
						-- control_cell_drive_static is to be set according to given control cell value
						--pin_scratch.cell_info.control_cell_drive_static := control_cell_value;

						update_element(
							container => net_scratch.pins,
							index => positive(p),
							process => set_control_cell_value'access);
						
						--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);
						exit; -- no more searching required
					end if;
				end loop;
				prog_position := 420;
				if not pin_found then
					cell_list_put_error_on_pin_not_found(device => device, pin => pin, net => net);
					raise constraint_error;
				end if;

				-- 				replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace(container => list_of_nets, key => net, new_item => net_scratch);
-- 				exit;
-- 			end if;
-- 		end loop;
-- 
-- 		-- if net not found in net list
-- 		if not net_found then 
-- 			cell_list_put_error_on_net_not_found(net => net);
-- 			raise constraint_error;
-- 		end if;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Lock control cell in class DH DL NR net : " & trim(natural'image(prog_position),left));
				raise;
	end lock_control_cell_in_class_DX_NR;
	
	procedure lock_control_cell_in_class_PU_PD_net(
		-- The pin and cell data extracted from the cell list is verified against the net list.
		-- If valid, the cell info will be filled with those values.
		class 			: type_net_class;
		level 			: type_net_level;
		net				: type_net_name.bounded_string;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		control_cell_id					: type_cell_id;
		control_cell_value				: type_bit_char_class_0
		) is
		net_scratch		: type_net;
-- 		pin_scratch		: type_pin;
		prog_position	: natural := 0;
		pin_found		: boolean := false;
-- 		net_found		: boolean := false;

		procedure set_control_cell_value (pin : in out type_pin) is
		begin
			pin.cell_info.control_cell_drive_static := control_cell_value;
		end set_control_cell_value;

	begin
		put_line("  class " & type_net_class'image(class) & " level " & type_net_level'image(level) & " net " 
			& to_string(net) & " dev " & to_string(device) & " pin " & to_string(pin) & " ctrl cell" 
			& type_cell_id'image(control_cell_id) 
			& " value " & type_bit_char_class_0'image(control_cell_value) & " disable state");

		prog_position := 10;
-- 		for n in 1..length(list_of_nets) loop
-- 			net_scratch := element(list_of_nets, positive(n));
-- 			if net_scratch.name = net then
-- 				net_found := true;
			net_scratch := element(list_of_nets, net);

				prog_position := 100;
				if not net_scratch.bs_capable then
					cell_list_put_error_on_non_scan_net (net => net);
					raise constraint_error;
				end if;

				prog_position := 200;
				if net_scratch.class /= class then
					cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
					raise constraint_error;
				end if;

				prog_position := 300;
				if net_scratch.level /= level then
					cell_list_put_error_on_contradicting_net_level(net => net, level => net_scratch.level);
					raise constraint_error;
				end if;

				prog_position := 400;
				for p in 1..length(net_scratch.pins) loop
					--pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).device_name = device and element(net_scratch.pins, positive(p)).device_pin_name = pin then
						pin_found := true;
						mark_bic_as_having_static_drive_cell(device);
						
						prog_position := 410;
						if element(net_scratch.pins, positive(p)).cell_info.control_cell_id /= control_cell_id then
							cell_list_put_error_on_invalid_control_cell;
							raise constraint_error;
						else
							-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
							if element(net_scratch.pins, positive(p)).cell_info.control_cell_appears_in_cell_list then
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(device) & " pin " 
										& to_string(pin) & " control cell" 
										& type_cell_id'image(control_cell_id) & " already in cell list !",
									console => true);
								raise constraint_error;
							else
								-- mark this cell as "appears in cell list"
								--pin_scratch.cell_info.control_cell_appears_in_cell_list := true;

								update_element(
									container => net_scratch.pins,
									index => positive(p),
									process => mark_control_cell_as_appears_in_cell_list'access);
							end if;
						end if;
						
-- 							-- if control cell disable/enable value in cell list differs from disable value in netlist, abort.
-- 							case control_cell_in_enable_state is
-- 								when false => -- means the control cell is locked to disable value
-- 									-- so the disable value given in net list must match the given control cell value 
-- 									if n.pin(p).cell_info.disable_value = control_cell_value then
-- 										null; -- fine
-- 									else
-- 										cell_list_put_error_on_invalid_disable_value;
-- 										raise constraint_error;
-- 									end if;
-- 								when true => -- means the control cell is locked to enable value
-- 									-- so the disable value given in net list must match the given control cell value INVERTED
-- 									-- since this data type is type_bit_char_class_0 (either 0 or 1), checking the inverted value is easy:
-- 									if n.pin(p).cell_info.disable_value /= control_cell_value then
-- 										null; -- fine
-- 									else
-- 										cell_list_put_error_on_invalid_enable_value;
-- 										raise constraint_error;
-- 									end if;
-- 							end case;

						-- if control cell disable value in cell list differs from disable value in netlist, abort.
						-- the control cell is locked to disable value
						-- so the disable value given in net list must match the given control cell value 
						if element(net_scratch.pins, positive(p)).cell_info.disable_value = control_cell_value then
							null; -- fine
						else
							cell_list_put_error_on_invalid_disable_value;
							raise constraint_error;
						end if;

						-- control_cell_drive_static is to be set according to given control cell value
						--pin_scratch.cell_info.control_cell_drive_static := control_cell_value;
						update_element(
							container => net_scratch.pins,
							index => positive(p),
							process => set_control_cell_value'access);

						--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);
						exit; -- no more searching required
					end if;
				end loop;
				prog_position := 420;
				if not pin_found then
					cell_list_put_error_on_pin_not_found(device => device, pin => pin, net => net);
					raise constraint_error;
				end if;

				--replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace(container => list_of_nets, key => net, new_item => net_scratch);
-- 				exit;
-- 			end if;
-- 		end loop;
-- 
-- 		-- if net not found in net list
-- 		if not net_found then 
-- 			cell_list_put_error_on_net_not_found(net => net);
-- 			raise constraint_error;
-- 		end if;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Lock control cell in class PU PD net : " & trim(natural'image(prog_position),left));
				raise;
	end lock_control_cell_in_class_PU_PD_net;

	procedure lock_output_cell_in_class_PU_PD_net(
		-- The pin and cell data extracted from the cell list is verified against the net list.
		-- If valid, the cell info will be filled with those values.
		class 			: type_net_class;
		level 			: type_net_level;
		net				: type_net_name.bounded_string;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		output_cell_id	: type_cell_id;
		output_cell_drive_value	: type_bit_char_class_0
		) is
		net_scratch		: type_net;
-- 		pin_scratch		: type_pin;
		prog_position	: natural := 0;
		pin_found		: boolean := false;
-- 		net_found		: boolean := false;

		procedure set_output_cell_value (pin : in out type_pin) is
		begin
			pin.cell_info.output_cell_drive_static := output_cell_drive_value;
		end set_output_cell_value;
		
	begin
		put_line("  class " & type_net_class'image(class) & " level " & type_net_level'image(level) & " net " 
			& to_string(net) & " device " & to_string(device) & " pin " & to_string(pin) & " output cell" 
			& type_cell_id'image(output_cell_id) 
			& " drive value " & type_bit_char_class_0'image(output_cell_drive_value));

		prog_position := 10;
-- 		for n in 1..length(list_of_nets) loop
-- 			net_scratch := element(list_of_nets, positive(n));
-- 			if net_scratch.name = net then
-- 				net_found := true;
		net_scratch := element(list_of_nets, net);

				prog_position := 100;
				if not net_scratch.bs_capable then
					cell_list_put_error_on_non_scan_net (net => net);
					raise constraint_error;
				end if;

				prog_position := 200;
				if net_scratch.class /= class then
					cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
					raise constraint_error;
				end if;

				prog_position := 300;
				if net_scratch.level /= level then
					cell_list_put_error_on_contradicting_net_level(net => net, level => net_scratch.level);
					raise constraint_error;
				end if;

				prog_position := 400;
				for p in 1..length(net_scratch.pins) loop
					-- pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).device_name = device and element(net_scratch.pins, positive(p)).device_pin_name = pin then
						pin_found := true;
						mark_bic_as_having_static_drive_cell(device);
						
						prog_position := 410;
						if element(net_scratch.pins, positive(p)).cell_info.output_cell_id /= output_cell_id then
							cell_list_put_error_on_invalid_output_cell;
							raise constraint_error;
						else
							-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
							if element(net_scratch.pins, positive(p)).cell_info.output_cell_appears_in_cell_list then
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(device) & " pin " 
										& to_string(pin) & " output cell" 
										& type_cell_id'image(output_cell_id) & " already in cell list !",
									console => true);
								raise constraint_error;
							else
								-- mark this cell as "appears in cell list"
								--pin_scratch.cell_info.output_cell_appears_in_cell_list := true;

								update_element(
									container => net_scratch.pins,
									index => positive(p),
									process => mark_output_cell_as_appears_in_cell_list'access);
							end if;
						end if;
						
						-- output_cell_drive_static is to be set according to given output cell value
						--pin_scratch.cell_info.output_cell_drive_static := output_cell_drive_value;

						update_element(
							container => net_scratch.pins,
							index => positive(p),
							process => set_output_cell_value'access);
						
						--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);
						exit; -- no more searching required
					end if;
				end loop;
				prog_position := 420;
				if not pin_found then
					cell_list_put_error_on_pin_not_found(device => device, pin => pin, net => net);
					raise constraint_error;
				end if;

				--replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace(container => list_of_nets, key => net, new_item => net_scratch);
-- 				exit;
-- 			end if;
-- 		end loop;

-- 		-- if net not found in net list
-- 		if not net_found then 
-- 			cell_list_put_error_on_net_not_found(net => net);
-- 			raise constraint_error;
-- 		end if;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Lock output cell in class PU PD net : " & trim(natural'image(prog_position),left));
				raise;
	end lock_output_cell_in_class_PU_PD_net;

	procedure lock_output_cell_in_class_DX(
		-- The pin and cell data extracted from the cell list is verified against the net list.
		-- If valid, the cell info will be filled with those values.
		class 			: type_net_class;
		level 			: type_net_level;
		net				: type_net_name.bounded_string;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		output_cell_id	: type_cell_id;
		output_cell_drive_value	: type_bit_char_class_0
		) is
		net_scratch		: type_net;
		prog_position	: natural := 0;
		pin_found		: boolean := false;
-- 		net_found		: boolean := false;

		procedure set_output_cell_value (pin : in out type_pin) is
		begin
			pin.cell_info.output_cell_drive_static := output_cell_drive_value;
		end set_output_cell_value;
		
	begin
		put_line("  class " & type_net_class'image(class) & " level " & type_net_level'image(level) & " net "
			& to_string(net) & " device " & to_string(device) & " pin " & to_string(pin) & " output cell"
			& type_cell_id'image(output_cell_id) 
			& " drive value " & type_bit_char_class_0'image(output_cell_drive_value));

		prog_position := 10;
-- 		for n in 1..length(list_of_nets) loop
-- 			net_scratch := element(list_of_nets, positive(n));
-- 			if net_scratch.name = net then
-- 				net_found := true;
		net_scratch := element(list_of_nets, net);

				prog_position := 100;
				if not net_scratch.bs_capable then
					cell_list_put_error_on_non_scan_net (net => net);
					raise constraint_error;
				end if;

				prog_position := 200;
				if net_scratch.class /= class then
					cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
					raise constraint_error;
				end if;

				prog_position := 300;
				if net_scratch.level /= level then
					cell_list_put_error_on_contradicting_net_level(net => net, level => net_scratch.level);
					raise constraint_error;
				end if;

				prog_position := 400;
				for p in 1..length(net_scratch.pins) loop
					-- pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).device_name = device and element(net_scratch.pins, positive(p)).device_pin_name = pin then
						pin_found := true;
						mark_bic_as_having_static_drive_cell(device);
						
						prog_position := 410;
						if element(net_scratch.pins, positive(p)).cell_info.output_cell_id /= output_cell_id then
							cell_list_put_error_on_invalid_output_cell;
							raise constraint_error;
						else
							-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
							if element(net_scratch.pins, positive(p)).cell_info.output_cell_appears_in_cell_list then
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(device) & " pin " 
										& to_string(pin) & " output cell" 
										& type_cell_id'image(output_cell_id) & " already in cell list !",
									console => true);
								raise constraint_error;
							else
								-- mark this cell as "appears in cell list"
								--pin_scratch.cell_info.output_cell_appears_in_cell_list := true;

								update_element(
									container => net_scratch.pins,
									index => positive(p),
									process => mark_output_cell_as_appears_in_cell_list'access);
							end if;
						end if;
						
						-- output_cell_drive_static is to be set according to given output cell value
						--pin_scratch.cell_info.output_cell_drive_static := output_cell_drive_value;

						update_element(
							container => net_scratch.pins,
							index => positive(p),
							process => set_output_cell_value'access);
						
						--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);						
						exit; -- no more searching required
					end if;
				end loop;
				prog_position := 420;
				if not pin_found then
					cell_list_put_error_on_pin_not_found(device => device, pin => pin, net => net);
					raise constraint_error;
				end if;

				--replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace(container => list_of_nets, key => net, new_item => net_scratch);
-- 				exit;
-- 			end if;
-- 		end loop;
-- 
-- 		-- if net not found in net list
-- 		if not net_found then 
-- 			cell_list_put_error_on_net_not_found(net => net);
-- 			raise constraint_error;
-- 		end if;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Lock output cell in class DH DL net : " & trim(natural'image(prog_position),left));
				raise;
	end lock_output_cell_in_class_DX;

	procedure lock_input_cell_static_expect(
		-- The pin and cell data extracted from the cell list is verified against the net list.
		-- If valid, the cell info will be filled with those values.
		class 			: type_net_class;
		level 			: type_net_level;
		net				: type_net_name.bounded_string;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		input_cell_id			: type_cell_id;
		input_cell_expect_value	: type_bit_char_class_0;
		primary_net_is			: type_net_name.bounded_string
		) is
		net_scratch		: type_net;
		prog_position	: natural := 0;
		pin_found		: boolean := false;
-- 		net_found		: boolean := false;

		procedure set_input_cell_value (pin : in out type_pin) is
		begin
			pin.cell_info.input_cell_expect_static := input_cell_expect_value;
		end set_input_cell_value;
		
	begin
		put("  class " & type_net_class'image(class) & " level " & type_net_level'image(level) & " net " 
			& to_string(net) & " device " & to_string(device) & " pin " & to_string(pin) & " input cell" 
			& type_cell_id'image(input_cell_id) 
			& " expect value " & type_bit_char_class_0'image(input_cell_expect_value));
			if level = secondary then
				put_line(" primary_net_is " & to_string(primary_net_is));
			else
				new_line;
			end if;

		prog_position := 10;
-- 		for n in 1..length(list_of_nets) loop
-- 			net_scratch := element(list_of_nets, positive(n));
-- 		
-- 			if net_scratch.name = net then
-- 				net_found := true;
		net_scratch := element(list_of_nets, net);

				prog_position := 100;
				if not net_scratch.bs_capable then
					cell_list_put_error_on_non_scan_net (net => net);
					raise constraint_error;
				end if;

				prog_position := 200;
				if net_scratch.class /= class then
					cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
					raise constraint_error;
				end if;

				prog_position := 300;
				if net_scratch.level /= level then
					cell_list_put_error_on_contradicting_net_level(net => net, level => net_scratch.level);
					raise constraint_error;
				end if;

				prog_position := 400;
				for p in 1..length(net_scratch.pins) loop
					--pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).device_name = device and element(net_scratch.pins, positive(p)).device_pin_name = pin then
						pin_found := true;
						mark_bic_as_having_static_expect_cell(device);
						
						prog_position := 410;
						if element(net_scratch.pins, positive(p)).cell_info.input_cell_id /= input_cell_id then
							cell_list_put_error_on_invalid_input_cell;
							raise constraint_error;
						else
							-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
							if element(net_scratch.pins, positive(p)).cell_info.input_cell_appears_in_cell_list then
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(device) & " pin " 
										& to_string(pin) & " input cell" 
										& type_cell_id'image(input_cell_id) & " already in cell list !",
									console => true);
								raise constraint_error;
							else
								-- mark this cell as "appears in cell list"
								-- pin_scratch.cell_info.input_cell_appears_in_cell_list := true;
								update_element(
									container => net_scratch.pins,
									index => positive(p),
									process => mark_input_cell_as_appears_in_cell_list'access);
							end if;
						end if;
						
						-- input_cell_expect_static is to be set according to given input cell value
						--pin_scratch.cell_info.input_cell_expect_static := input_cell_expect_value;

						update_element(
							container => net_scratch.pins,
							index => positive(p),
							process => set_input_cell_value'access);
						
						--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);						
						exit; -- no more pin searching required
					end if;
				end loop;
				prog_position := 420;
				if not pin_found then
					cell_list_put_error_on_pin_not_found(device => device, pin => pin, net => net);
					raise constraint_error;
				end if;

				-- check name of given primary net
				if net_scratch.level = secondary then
					if net_scratch.name_of_primary_net = primary_net_is then
						null; -- primary net name given in cell list matches primary net name defined in netlist
					else
						cell_list_put_error_on_primary_net_name_mismatch;
						raise constraint_error;
					end if;
				end if;

				--replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace(container => list_of_nets, key => net, new_item => net_scratch);
-- 				exit; -- no more net searching required
-- 			end if;
-- 		end loop;
-- 
-- 		-- if net not found in net list
-- 		if not net_found then 
-- 			cell_list_put_error_on_net_not_found(net => net);
-- 			raise constraint_error;
-- 		end if;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Lock input cell in static net : " & trim(natural'image(prog_position),left));
				raise;
	end lock_input_cell_static_expect;


	procedure assign_input_cell_atg_expect(
		-- The pin and cell data extracted from the cell list is verified against the net list.
		-- If valid, the cell info will be filled with those values.
		class 			: type_net_class;
		level 			: type_net_level;
		net				: type_net_name.bounded_string;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		input_cell_id	: type_cell_id;
		primary_net_is	: type_net_name.bounded_string
		) is
		net_scratch		: type_net;
		prog_position	: natural := 0;
		pin_found		: boolean := false;
-- 		net_found		: boolean := false;

		procedure set_input_cell_atg (pin : in out type_pin) is
		begin
			pin.cell_info.input_cell_expect_atg := true;
		end set_input_cell_atg;
		
	begin
		put("  class " & type_net_class'image(class) & " level " & type_net_level'image(level) & " net " 
			& to_string(net) & " device " & to_string(device) & " pin " & to_string(pin) & " input cell" 
			& type_cell_id'image(input_cell_id));
			if level = secondary then
				put_line(" primary_net_is " & to_string(primary_net_is));
			else
				new_line;
			end if;

		prog_position := 10;
-- 		for n in 1..length(list_of_nets) loop
-- 			net_scratch := element(list_of_nets, positive(n));
-- 			if net_scratch.name = net then
-- 				net_found := true;
		net_scratch := element(list_of_nets, net);

				prog_position := 100;
				if not net_scratch.bs_capable then
					cell_list_put_error_on_non_scan_net (net => net);
					raise constraint_error;
				end if;

				prog_position := 200;
				if net_scratch.class /= class then
					cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
					raise constraint_error;
				end if;

				prog_position := 300;
				if net_scratch.level /= level then
					cell_list_put_error_on_contradicting_net_level(net => net, level => net_scratch.level);
					raise constraint_error;
				end if;

				prog_position := 400;
				for p in 1..length(net_scratch.pins) loop
					--pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).device_name = device and element(net_scratch.pins, positive(p)).device_pin_name = pin then
						pin_found := true;
						mark_bic_as_having_dynamic_expect_cell(device);
						
						prog_position := 410;
						if element(net_scratch.pins, positive(p)).cell_info.input_cell_id /= input_cell_id then
							cell_list_put_error_on_invalid_input_cell;
							raise constraint_error;
						else
							-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
							if element(net_scratch.pins, positive(p)).cell_info.input_cell_appears_in_cell_list then
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(device) & " pin " 
										& to_string(pin) & " input cell" 
										& type_cell_id'image(input_cell_id) & " already in cell list !",
									console => true);
								raise constraint_error;
							else
								-- mark this cell as "appears in cell list"
								-- pin_scratch.cell_info.input_cell_appears_in_cell_list := true;

								update_element(
									container => net_scratch.pins,
									index => positive(p),
									process => mark_input_cell_as_appears_in_cell_list'access);
							end if;
						end if;
						
						-- mark input cell as target for atg
						-- pin_scratch.cell_info.input_cell_expect_atg := true;
						update_element(
							container => net_scratch.pins,
							index => positive(p),
							process => set_input_cell_atg'access);
						
						--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);
						exit; -- no more pin searching required
					end if;
				end loop;
				prog_position := 420;
				if not pin_found then
					cell_list_put_error_on_pin_not_found(device => device, pin => pin, net => net);
					raise constraint_error;
				end if;

				-- check name of given primary net
				if net_scratch.level = secondary then
					if net_scratch.name_of_primary_net = primary_net_is then
						null; -- primary net name given in cell list matches primary net name defined in netlist
					else
						cell_list_put_error_on_primary_net_name_mismatch;
						raise constraint_error;
					end if;
				end if;

				--replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace(container => list_of_nets, key => net, new_item => net_scratch);
-- 				exit; -- no more net searching required
-- 			end if;
-- 		end loop;
-- 
-- 		-- if net not found in net list
-- 		if not net_found then 
-- 			cell_list_put_error_on_net_not_found(net => net);
-- 			raise constraint_error;
-- 		end if;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Assign input cell in atg net : " & trim(natural'image(prog_position),left));
				raise;
	end assign_input_cell_atg_expect;

	procedure assign_output_control_cell_atg_drive(
		-- The pin and cell data extracted from the cell list is verified against the net list.
		-- If valid, the cell info will be filled with those values.
		class 						: type_net_class;
		level 						: type_net_level;
		net							: type_net_name.bounded_string;
		device						: type_device_name.bounded_string;
		pin							: type_pin_name.bounded_string;
		controlled_by_control_cell	: boolean;
		output_cell_id				: type_cell_id;
		control_cell_id				: type_cell_id;
		control_cell_inverted		: boolean
		) is
		net_scratch		: type_net;
		prog_position	: natural := 0;
		pin_found		: boolean := false;
-- 		net_found		: boolean := false;

		procedure set_control_cell_atg (pin : in out type_pin) is
		begin
			pin.cell_info.control_cell_drive_atg := true;
		end set_control_cell_atg;

		procedure set_control_cell_inverted (pin : in out type_pin) is
		begin
			pin.cell_info.control_cell_inverted := true;
		end set_control_cell_inverted;

		procedure set_control_cell_not_inverted (pin : in out type_pin) is
		begin
			pin.cell_info.control_cell_inverted := false;
		end set_control_cell_not_inverted;

		procedure set_output_cell_atg (pin : in out type_pin) is
		begin
			pin.cell_info.output_cell_drive_atg := true;
		end set_output_cell_atg;
		
	begin
		put("  class " & type_net_class'image(class) & " level " & type_net_level'image(level) & " net " 
			& to_string(net) & " device " & to_string(device) & " pin " & to_string(pin));
			if controlled_by_control_cell then
				put_line(" control cell" & type_cell_id'image(control_cell_id) & " inverted " & boolean'image(control_cell_inverted));
			else
				put_line(" output cell" & type_cell_id'image(control_cell_id));
			end if;

		prog_position := 10;
-- 		for n in 1..length(list_of_nets) loop
-- 			net_scratch := element(list_of_nets, positive(n));
-- 			if net_scratch.name = net then
-- 				net_found := true;
		net_scratch := element(list_of_nets, net);

				prog_position := 100;
				if not net_scratch.bs_capable then
					cell_list_put_error_on_non_scan_net (net => net);
					raise constraint_error;
				end if;

				prog_position := 200;
				if net_scratch.class /= class then
					cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
					raise constraint_error;
				end if;

				prog_position := 300;
				if net_scratch.level /= level then
					cell_list_put_error_on_contradicting_net_level(net => net, level => net_scratch.level);
					raise constraint_error;
				end if;

				prog_position := 400;
				for p in 1..length(net_scratch.pins) loop
					-- pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).device_name = device and element(net_scratch.pins, positive(p)).device_pin_name = pin then -- on device and pin match
						pin_found := true;
						mark_bic_as_having_dynamic_drive_cell(device);
						
						prog_position := 410;
						-- depending on the way the pin is controlled (either by output cell directly or indirectly by control cell):
						if controlled_by_control_cell then -- controlled by control cell:

							-- verify given control cell against specification in net list
							if element(net_scratch.pins, positive(p)).cell_info.control_cell_id /= control_cell_id then
								prog_position := 420;
								cell_list_put_error_on_invalid_control_cell;
								raise constraint_error;
							else
								-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
								if element(net_scratch.pins, positive(p)).cell_info.control_cell_appears_in_cell_list then
									write_message (
										file_handle => current_output,
										text => message_error & "Device " & to_string(device) & " pin " 
											& to_string(pin) & " control cell" 
											& type_cell_id'image(control_cell_id) & " already in cell list !",
										console => true);
									raise constraint_error;
								else
									-- mark this cell as "appears in cell list"
									-- pin_scratch.cell_info.control_cell_appears_in_cell_list := true;
									update_element(
										container => net_scratch.pins,
										index => positive(p),
										process => mark_control_cell_as_appears_in_cell_list'access);
								end if;
							end if;
							-- mark control cell as target for atg
							-- pin_scratch.cell_info.control_cell_drive_atg := true;
							update_element(
								container => net_scratch.pins,
								index => positive(p),
								process => set_control_cell_atg'access);

							-- verify "inverted yes/no" flag against net class and disable value
							case net_scratch.class is
								when PD => -- when pull down net class
									prog_position := 430;
									case element(net_scratch.pins, positive(p)).cell_info.disable_value is
										when '0' => -- a disable value of 0, causes the pin to go L
											prog_position := 440;
											if control_cell_inverted = false then -- so in the cell list we expect a "inverted no" entry
												--pin_scratch.cell_info.control_cell_inverted := false; 
												-- fine, inversion NOT required
												update_element(
													container => net_scratch.pins,
													index => positive(p),
													process => set_control_cell_not_inverted'access);
											else
												write_message (
													file_handle => current_output,
													text => message_error & "Expected '" & cell_list_keyword_control_cell_inverted & " '" 
														 & cell_list_keyword_no & "' for the control cell of this pin !",
													console => true);

												--put_line("        In the net list, a disable result of '" 
												--	& type_disable_result'image(n.pin(p).cell_info.disable_result) & "' was specified
												raise constraint_error;
											end if;
										when '1' => -- a disable value of 1, causes the pin to go L
											prog_position := 450;
											if control_cell_inverted = true then -- so in the cell list we expect a "inverted yes" entry
												--pin_scratch.cell_info.control_cell_inverted := true;
												-- fine, inversion IS required
												update_element(
													container => net_scratch.pins,
													index => positive(p),
													process => set_control_cell_inverted'access);
											else
												write_message (
													file_handle => current_output,
													text => message_error & "Expected '" & cell_list_keyword_control_cell_inverted & " '" 
														 & cell_list_keyword_yes & "' for the control cell of this pin !",
													console => true);
												
												--put_line("        In the net list, a disable result of '" 
												--	& type_disable_result'image(n.pin(p).cell_info.disable_result) & "' was specified
												raise constraint_error;
											end if;
									end case;
								when PU => -- when pull up net class
									prog_position := 460;
									case element(net_scratch.pins, positive(p)).cell_info.disable_value is
										when '0' => -- a disable value of 0, causes the pin to go H
											prog_position := 470;
											if control_cell_inverted = true then -- so in the cell list we expect a "inverted yes" entry
												--pin_scratch.cell_info.control_cell_inverted := true;
												-- fine, inversion IS required
												update_element(
													container => net_scratch.pins,
													index => positive(p),
													process => set_control_cell_inverted'access);
											else
												write_message (
													file_handle => current_output,
													text => message_error & "Expected '" & cell_list_keyword_control_cell_inverted & " '" 
														 & cell_list_keyword_yes & "' for the control cell of this pin !",
													console => true);

												--put_line("        In the net list, a disable result of '" 
												--	& type_disable_result'image(n.pin(p).cell_info.disable_result) & "' was specified
												raise constraint_error;
											end if;
										when '1' => -- a disable value of 1, causes the pin to go H
											prog_position := 480;
											if control_cell_inverted = false then -- so in the cell list we expect a "inverted no" entry
												--pin_scratch.cell_info.control_cell_inverted := false; 
												-- fine, inversion NOT required
												update_element(
													container => net_scratch.pins,
													index => positive(p),
													process => set_control_cell_not_inverted'access);
											else
												write_message (
													file_handle => current_output,
													text => message_error & "Expected '" & cell_list_keyword_control_cell_inverted & " '" 
														 & cell_list_keyword_no & "' for the control cell of this pin !",
													console => true);
												
												--put_line("        In the net list, a disable result of '" 
												--	& type_disable_result'image(n.pin(p).cell_info.disable_result) & "' was specified
												raise constraint_error;
											end if;
									end case;
								when others => -- this should never happen, as the net class check has been done earlier
									prog_position := 490;
									cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
									raise constraint_error;
							end case;


						else -- controlled by output cell:
							-- verify given output cell against specification in net list
							if element(net_scratch.pins, positive(p)).cell_info.output_cell_id /= output_cell_id then
								prog_position := 417;
								cell_list_put_error_on_invalid_output_cell;
								raise constraint_error;
							else
								-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
								if element(net_scratch.pins, positive(p)).cell_info.output_cell_appears_in_cell_list then
									write_message (
										file_handle => current_output,
										text => message_error & "Device " & to_string(device) & " pin " 
											& to_string(pin) & " output cell" 
											& type_cell_id'image(output_cell_id) & " already in cell list !",
										console => true);
									raise constraint_error;
								else
									-- mark this cell as "appears in cell list"
									--pin_scratch.cell_info.output_cell_appears_in_cell_list := true;
									update_element(
										container => net_scratch.pins,
										index => positive(p),
										process => mark_output_cell_as_appears_in_cell_list'access);
								end if;
							end if;
							-- mark output cell as target for atg
							--pin_scratch.cell_info.output_cell_drive_atg := true;
							update_element(
								container => net_scratch.pins,
								index => positive(p),
								process => set_output_cell_atg'access);
						end if;
						
						--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);
						exit; -- no more pin searching required
					end if;
				end loop;

				prog_position := 420;
				if not pin_found then
					cell_list_put_error_on_pin_not_found(device => device, pin => pin, net => net);
					raise constraint_error;
				end if;

-- 				replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace(container => list_of_nets, key => net, new_item => net_scratch);				
-- 				exit; -- no more net searching required
-- 			end if;
-- 		end loop;
-- 
-- 		-- if net not found in net list
-- 		if not net_found then 
-- 			cell_list_put_error_on_net_not_found(net => net);
-- 			raise constraint_error;
-- 		end if;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Assign output/control cell in atg net : " & trim(natural'image(prog_position),left));
				raise;
	end assign_output_control_cell_atg_drive;

	procedure assign_input_cell_unclassified_net(
		-- The pin and cell data extracted from the cell list is verified against the net list.
		-- If valid, the cell info will be filled with those values.
		class 			: type_net_class;
		level 			: type_net_level;
		net				: type_net_name.bounded_string;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		input_cell_id	: type_cell_id;
		primary_net_is	: type_net_name.bounded_string
		) is
		net_scratch		: type_net;
		prog_position	: natural := 0;
		pin_found		: boolean := false;
-- 		net_found		: boolean := false;
	begin
		put("  class " & type_net_class'image(class) & " level " & type_net_level'image(level) & " net " 
			& to_string(net) & " device " & to_string(device) & " pin " & to_string(pin) & " input cell"
			& type_cell_id'image(input_cell_id));
			if level = secondary then
				put_line(" primary_net_is " & to_string(primary_net_is));
			else
				new_line;
			end if;

		prog_position := 10;
-- 		for n in 1..length(list_of_nets) loop
-- 			net_scratch := element(list_of_nets, positive(n));
-- 			if net_scratch.name = net then
-- 				net_found := true;
		net_scratch := element(list_of_nets, net);

				prog_position := 100;
				if not net_scratch.bs_capable then
					cell_list_put_error_on_non_scan_net (net => net);
					raise constraint_error;
				end if;

				prog_position := 200;
				if net_scratch.class /= class then
					cell_list_put_error_on_contradicting_net_class(net => net, class => net_scratch.class);
					raise constraint_error;
				end if;

				prog_position := 300;
				if net_scratch.level /= level then
					cell_list_put_error_on_contradicting_net_level(net => net, level => net_scratch.level);
					raise constraint_error;
				end if;

				prog_position := 400;
				for p in 1..length(net_scratch.pins) loop
					--pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).device_name = device and element(net_scratch.pins, positive(p)).device_pin_name = pin then
						pin_found := true;
						
						prog_position := 410;
						if element(net_scratch.pins, positive(p)).cell_info.input_cell_id /= input_cell_id then
							cell_list_put_error_on_invalid_input_cell;
							raise constraint_error;
						else
							-- if cell already in any cell list, print error, otherwise mark cell as "appears in cell list"
							if element(net_scratch.pins, positive(p)).cell_info.input_cell_appears_in_cell_list then
								write_message (
									file_handle => current_output,
									text => message_error & "Device " & to_string(device) & " pin " 
										& to_string(pin) & " input cell" 
										& type_cell_id'image(input_cell_id) & " already in cell list !",
									console => true);
								raise constraint_error;
							else
								-- mark this cell as "appears in cell list"
								--pin_scratch.cell_info.input_cell_appears_in_cell_list := true;
								update_element(
									container => net_scratch.pins,
									index => positive(p),
									process => mark_input_cell_as_appears_in_cell_list'access);
							end if;
						end if;
						
						--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);
						exit; -- no more pin searching required
					end if;
				end loop;
				prog_position := 420;
				if not pin_found then
					cell_list_put_error_on_pin_not_found(device => device, pin => pin, net => net);
					raise constraint_error;
				end if;

				-- check name of given primary net
				if net_scratch.level = secondary then
					if net_scratch.name_of_primary_net = primary_net_is then
						null; -- primary net name given in cell list matches primary net name defined in netlist
					else
						cell_list_put_error_on_primary_net_name_mismatch;
						raise constraint_error;
					end if;
				end if;
				
				--replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace(container => list_of_nets, key => net, new_item => net_scratch);
-- 				exit; -- no more net searching required
-- 			end if;
-- 		end loop;
-- 
-- 		-- if net not found in net list
-- 		if not net_found then 
-- 			cell_list_put_error_on_net_not_found(net => net);
-- 			raise constraint_error;
-- 		end if;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Assign input cell in unclassified net : " & trim(natural'image(prog_position),left));
				raise;
	end assign_input_cell_unclassified_net;

	-- PROCESSING CELL LISTS END


	procedure check_cells_are_in_cell_list is
		net				: type_net;
		prog_position	: natural := 0;
		net_cursor : type_list_of_nets.cursor := first(list_of_nets);
	begin
		prog_position := 10;
-- 		for n in 1..length(list_of_nets) loop
		while net_cursor /= type_list_of_nets.no_element loop
			-- net := element(list_of_nets, positive(n));
			net := element(net_cursor);
			
			-- check bs_capable nets only
			if net.bs_capable then

				prog_position := 400;

				-- check bs_capable pins of this net only
				for p in 1..length(net.pins) loop
					--pin := element(net.pins, positive(p));
					-- NOTE: element(net.pins, positive(p)) equals the particular pin
					if element(net.pins, positive(p)).is_bscan_capable then
						prog_position := 410;

						-- if there is an input cell, its ID is greater -1
						if element(net.pins, positive(p)).cell_info.input_cell_id /= -1 then
							if element(net.pins, positive(p)).cell_info.input_cell_appears_in_cell_list then
								null; -- fine, cell is in cell list
							else -- input cell is not in cell list
								prog_position := 420;
								write_message (
									file_handle => current_output,
									text => message_error & "Input cell with ID" 
										& type_cell_id'image(element(net.pins, positive(p)).cell_info.input_cell_id) 
										& " of device " & to_string(element(net.pins, positive(p)).device_name) 
										& " does not appear in any cell list !",
									console => true);
								
								write_message (
									file_handle => current_output,
									text => "Cell is specified in class " 
										& type_net_class'image(net.class) & " net " 
										--& to_string(net.name) & " device "
										& to_string(key(net_cursor)) & " device "
										& to_string(element(net.pins, positive(p)).device_name) 
										& " pin " & to_string(element(net.pins, positive(p)).device_pin_name),
									console => true);

								raise constraint_error;
							end if;
						end if;

						-- if there is a control cell, its ID is greater -1
						if element(net.pins, positive(p)).cell_info.control_cell_id /= -1 then
							if element(net.pins, positive(p)).cell_info.control_cell_appears_in_cell_list then
								null; -- fine, cell is in cell list
							else -- control cell is not in cell list
								prog_position := 430;
								write_message (
									file_handle => current_output,
									text => message_error & "Control cell with ID" 
										& type_cell_id'image(element(net.pins, positive(p)).cell_info.control_cell_id) 
										& " of device " & to_string(element(net.pins, positive(p)).device_name) 
										& " does not appear in any cell list !",
									console => true);
								
								write_message (
									file_handle => current_output,
									text => "Cell is specified in class " & type_net_class'image(net.class) & " net " 
									--& to_string(net.name) & " device "
										& to_string(key(net_cursor)) & " device "
										& to_string(element(net.pins, positive(p)).device_name) 
										& " pin " & to_string(element(net.pins, positive(p)).device_pin_name),
									console => true);

								raise constraint_error;
							end if;
						end if;

						-- if there is an output cell, its ID is greater -1
						if element(net.pins, positive(p)).cell_info.output_cell_id /= -1 then
							if element(net.pins, positive(p)).cell_info.output_cell_appears_in_cell_list then
								null; -- fine, cell is in cell list
							else -- output cell is not in cell list

								-- check output cells of primary nets exclusively (in secondary nets, output cells do not matter)
								if net.level = primary then
									prog_position := 440;
									case net.class is
										when PU | PD => -- in such nets, if the control cell is not target of atg -> it is static,
														-- if cell is static -> it is in disable state -> output cell does not matter
											if not element(net.pins, positive(p)).cell_info.control_cell_drive_atg then
												prog_position := 450;
											end if;
										when EL | EH | NA => -- in such nets, the driver pin is in highz, so the output cell does not matter
												prog_position := 460;
										when others => 	-- NR, DL, DH nets
											prog_position := 470;
											write_message (
												file_handle => current_output,
												text => message_error & "Output cell with ID" 
													& type_cell_id'image(element(net.pins, positive(p)).cell_info.output_cell_id) 
													& " of device " & to_string(element(net.pins, positive(p)).device_name) 
													& " does not appear in any cell list !",
												console => true);
											
											write_message (
												file_handle => current_output,
												text => "Cell is specified in class " & type_net_class'image(net.class) 
												--& " net " & to_string(net.name) & " device "
													& " net " & to_string(key(net_cursor)) & " device "
													& to_string(element(net.pins, positive(p)).device_name) 
													& " pin " & to_string(element(net.pins, positive(p)).device_pin_name),
												console => true);

											raise constraint_error;
									end case;
								end if;
							end if;
						end if;

					end if;
				end loop;

			end if;
				
			next(net_cursor);
		end loop;

		exception
			when constraint_error => 
				case prog_position is 
					when 0 => null;
					when others => null;
				end case;
				put_line("prog position: Check cells in cell list : " & trim(natural'image(prog_position),left));
				raise;

	end check_cells_are_in_cell_list;
	

	procedure verify_shared_control_cells is
		-- this procedure searches for multiple occurences of control cells in net list.
		-- if a control cell is used by two different pins of the same device (bic), the "control_cell_shared" flag
		-- is set in the cell_info of both pins
		net_scratch		: type_net;
		control_cell_id	: type_cell_info_cell_id;
		device			: type_device_name.bounded_string;
		pin				: type_pin_name.bounded_string;
		type type_shared_control_cell_status is 
			record
				net				: type_net_name.bounded_string;
				pin				: type_pin_name.bounded_string;
				drive_static	: type_bit_char_class_0;
				drive_atg		: boolean := false; -- true if atg drives something here
			end record;
		control_cell_b_status : type_shared_control_cell_status;

		procedure set_control_cell_shared (pin : in out type_pin) is
		begin
			pin.cell_info.control_cell_shared := true;
		end set_control_cell_shared;
		
		function find_shared_control_cell_b return boolean is
		-- this function searches the net list for the given control cell of the current device
		-- if the control cell appears with a pin different from the given pin, the cell is marked as "shared"
			net_scratch	: type_net;
			--pin_scratch	: type_pin;
			net_cursor : type_list_of_nets.cursor := first(list_of_nets);
		begin
			-- loop in netlist
			--for n in 1..length(list_of_nets) loop
			while net_cursor /= type_list_of_nets.no_element loop
				--net_scratch := element(list_of_nets, positive(n));
				net_scratch := element(net_cursor);
				if net_scratch.bs_capable then -- if net is bs capable
					--put_line("    in net " & to_string(net_scratch.name) );
					put_line("    in net " & to_string(key(net_cursor)));
					for p in 1..length(net_scratch.pins) loop -- loop though pin list of this net
						--pin_scratch := element(net_scratch.pins, positive(p));
						-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin						
						if element(net_scratch.pins, positive(p)).is_bscan_capable then -- if pin is bs capable
							-- CS: look in boundary register description of bics for shared control cells,
							-- this could speed up the check.
							if element(net_scratch.pins, positive(p)).device_name = device then -- on device name match
								if element(net_scratch.pins, positive(p)).device_pin_name /= pin then -- the pin name must be different,
								-- because the same pin must not be checked against itself
									if element(net_scratch.pins, positive(p)).cell_info.control_cell_id = control_cell_id then -- on match of control cell id

										put_line("     shared with pin " & to_string(element(net_scratch.pins, positive(p)).device_pin_name));

										--pin_scratch.cell_info.control_cell_shared := true; -- mark the control cell of the other pin as shared too
										update_element(
											container => net_scratch.pins,
											index => positive(p),
											process => set_control_cell_shared'access);
										
										--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);

										-- collect some information about the affected cell
										--control_cell_b_status.net			:= net_scratch.name; -- get net name
										control_cell_b_status.net			:= key(net_cursor); -- get net name
										control_cell_b_status.pin			:= element(net_scratch.pins, positive(p)).device_pin_name;
										control_cell_b_status.drive_static	:= element(net_scratch.pins, positive(p)).cell_info.control_cell_drive_static;
										control_cell_b_status.drive_atg 	:= element(net_scratch.pins, positive(p)).cell_info.control_cell_drive_atg;
										return true;
									end if;
								end if;
							end if;
						end if;
					end loop;
					--replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
					replace_element(container => list_of_nets, position => net_cursor, new_item => net_scratch);
				end if;
				next(net_cursor);	
			end loop;
			return false; -- if given cc_id does not appear in net list, it is not shared by any pin yet
		end find_shared_control_cell_b;

		net_cursor : type_list_of_nets.cursor := first(list_of_nets);
	begin -- verify_shared_control_cells
		put_line(" verifying shared control cells ...");

		--for n in 1..length(list_of_nets) loop
		while net_cursor /= type_list_of_nets.no_element loop		
			--net_scratch := element(list_of_nets, positive(n));
			net_scratch := element(net_cursor);
			if net_scratch.bs_capable then -- if net is bs capable
				for p in 1..length(net_scratch.pins) loop -- loop though pin list of this net
					--pin_scratch := element(net_scratch.pins, positive(p));
					-- NOTE: element(net_scratch.pins, positive(p)) equals the particular pin
					if element(net_scratch.pins, positive(p)).is_bscan_capable then -- if pin is bs capable
						-- CS: look in boundary register description of bics for shared control cells,
						-- this could speed up the check.
						device 	:= element(net_scratch.pins, positive(p)).device_name; -- get device name
						pin 	:= element(net_scratch.pins, positive(p)).device_pin_name; -- get pin name
						control_cell_id := element(net_scratch.pins, positive(p)).cell_info.control_cell_id; -- get control cell id
						if control_cell_id /= -1 then
							put_line("   device " & to_string(device) & " pin " & to_string(pin) & " cell" & type_cell_id'image(control_cell_id));

							-- if control cell b is shared with the current control cell, mark the current control cell as "shared" too
							if find_shared_control_cell_b then
								--pin_scratch.cell_info.control_cell_shared := true;
								update_element(
									container => net_scratch.pins,
									index => positive(p),
									process => set_control_cell_shared'access);
								--replace_element(container => net_scratch.pins, index => positive(p), new_item => pin_scratch);
								
								put_line("     cell is shared");

								-- verify control cell statuses against each other. on mismatch abort

								if element(net_scratch.pins, positive(p)).cell_info.control_cell_drive_static /= control_cell_b_status.drive_static then
									write_message (
										file_handle => current_output,
										text => message_error & "Shared control cell conflict with device " 
											& to_string(device) 
											& " cell" & type_cell_id'image(control_cell_id) & " !",
										console => true);

									write_message (
										file_handle => current_output,
										--text => "  Net " & to_string(net_scratch.name) & " pin " & to_string(pin)
										text => "  Net " & to_string(key(net_cursor)) & " pin " & to_string(pin) 
											& " drive_static " 
											& type_bit_char_class_0'image(element(net_scratch.pins, positive(p)).cell_info.control_cell_drive_static),
										console => true);

									write_message (
										file_handle => current_output,
										text => "Net " & to_string(control_cell_b_status.net) & " pin " 
											& to_string(control_cell_b_status.pin)
											& " drive_static " & type_bit_char_class_0'image(control_cell_b_status.drive_static),
										console => true);
									
									raise constraint_error;
								end if;

								if element(net_scratch.pins, positive(p)).cell_info.control_cell_drive_atg /= control_cell_b_status.drive_atg then
									write_message (
										file_handle => current_output,
										text => message_error & "Shared control cell conflict with device " 
											& to_string(device) 
											& " cell" & type_cell_id'image(control_cell_id) & " !",
										console => true);

									write_message (
										file_handle => current_output,
										--text => "  Net " & to_string(net_scratch.name) & " pin "
										text => "  Net " & to_string(key(net_cursor)) & " pin " 
											& to_string(pin) 
											& " drive_atg " 
											& boolean'image(element(net_scratch.pins, positive(p)).cell_info.control_cell_drive_atg),
										console => true);

									write_message (
										file_handle => current_output,
										text => "  Net " & to_string(control_cell_b_status.net) & " pin " 
											& to_string(control_cell_b_status.pin)
											& " drive_atg " & boolean'image(control_cell_b_status.drive_atg),
										console => true);

									raise constraint_error;
								end if;
							end if;

						end if;
					end if;
				end loop;
				--replace_element(container => list_of_nets, index => positive(n), new_item => net_scratch);
				replace_element(container => list_of_nets, position => net_cursor, new_item => net_scratch);
			end if;
			next(net_cursor);
		end loop;
	end verify_shared_control_cells;

	procedure make_shared_control_cell_journal is 
		-- creates a journal of bics, control_cells and affected nets from the uut database netlist
		net			: type_net;
		bic_name	: type_device_name.bounded_string;
		shared_control_cell_found	: boolean := false;

		use type_list_of_nets_with_shared_control_cell;
		list_of_nets_with_shared_control_cell : type_list_of_nets_with_shared_control_cell.vector;
		
		use type_list_of_shared_control_cells;
		list_of_shared_control_cells : type_list_of_shared_control_cells.vector;

		-- scratch variables
		net_with_shared_control_cell 	: type_net_with_shared_control_cell;		
		shared_control_cell_with_nets	: type_shared_control_cell_with_nets;
		bic_with_shared_control_cell	: type_bic_with_shared_control_cell;
		
		--procedure find_other_nets_with_this_control_cell (origin : type_net_name.bounded_string; cc_id : type_cell_id) is
		procedure find_other_nets_with_this_control_cell (origin : in type_list_of_nets.cursor; cc_id : in type_cell_id) is
			net	: type_net;
			net_with_shared_control_cell : type_net_with_shared_control_cell;
			cell_found : boolean := false;

			procedure mark_control_cell_as_processed (pin : in out type_pin) is
				begin
					pin.cell_info.control_cell_in_journal := true;
				end mark_control_cell_as_processed;

			net_cursor : type_list_of_nets.cursor := first(list_of_nets);
		begin
			--for n in 1..length(list_of_nets) loop
			while net_cursor /= type_list_of_nets.no_element loop
				--net := element(list_of_nets, positive(n));
				net := element(net_cursor);
				cell_found := false;
				if net.bs_capable then
					--if net.name /= origin then -- do not search in the net you came from
					if net_cursor /= origin then -- we do not search in the net we came from
						for p in 1..length(net.pins) loop
							--pin := element(net.pins, positive(p));
							-- NOTE: element(net.pins, positive(p)) equals the particular pin
							if element(net.pins, positive(p)).is_bscan_capable then
								if element(net.pins, positive(p)).device_name = bic_name then -- on match of bic name
									if element(net.pins, positive(p)).cell_info.control_cell_id = cc_id then -- on match of control cell id
-- 										add_to_nets_with_shared_control_cell(
-- 											list 				=> ptr_list_of_nets_with_shared_control_cell,
-- 											net_name_given 		=> n.name,
-- 											net_level_given 	=> n.level,
-- 											net_class_given		=> n.class
-- 											);

										--net_with_shared_control_cell.name := net.name;
										net_with_shared_control_cell.name := key(net_cursor);
										net_with_shared_control_cell.level := net.level;
										net_with_shared_control_cell.class := net.class;
										append(list_of_nets_with_shared_control_cell, net_with_shared_control_cell);

										-- mark this control cell as processed
										--pin.cell_info.control_cell_in_journal := true; 
										update_element(
											container => net.pins,
											index => positive(p),
											process => mark_control_cell_as_processed'access);
										
										--replace_element(net.pins, positive(p), pin);
										cell_found := true;
									end if;
								end if;
							end if;
						end loop;
					end if; -- do not search in the net you came from
				end if; -- if bs_capable
				
				if cell_found then
					--replace_element(list_of_nets, positive(n), net);
					replace_element(list_of_nets, net_cursor, net);
				end if;
					
				next(net_cursor);	
			end loop;
		end find_other_nets_with_this_control_cell;

		bic_cursor : type_list_of_bics.cursor := first(list_of_bics);
		net_cursor : type_list_of_nets.cursor;
		
	begin -- make_shared_control_cell_journal
		put_line(" creating shared control cell journal ...");	
-- 		for b in 1..length(list_of_bics) loop    
-- 			bic_name := element(list_of_bics,positive(b)).name; -- get bic name

		while bic_cursor /= type_list_of_bics.no_element loop
			bic_name := key(bic_cursor);
			next(bic_cursor);

			--put_line("bic : " & universal_string_type.to_string(b.name));
			shared_control_cell_found := false; -- initially, assume there is no shared control cell in this this bic

			-- purge list_of_shared_control_cells
			delete(container => list_of_shared_control_cells, index => 1, count => length(list_of_shared_control_cells)); -- CS: use clear

			--put_line("bic 1: " & universal_string_type.to_string(b.name));
			--for n in 1..length(list_of_nets) loop -- loop though netlist
			net_cursor := first(list_of_nets);
			while net_cursor /= type_list_of_nets.no_element loop
				--net := element(list_of_nets, positive(n));
				net := element(net_cursor);
				--put_line("bic 2: " & universal_string_type.to_string(b.name));

				if net.bs_capable then -- investigate scan capable nets only
					for p in 1..length(net.pins) loop -- loop through part list of that net
						--pin := element(net.pins, positive(p));
						-- NOTE: element(net.pins, positive(p)) equals the particular pin
						if element(net.pins, positive(p)).is_bscan_capable then -- investigate scan capable pins only
							if element(net.pins, positive(p)).device_name = bic_name then -- on match of bic name
								if element(net.pins, positive(p)).cell_info.control_cell_shared then -- check control cells only
									-- NOTE: this flag may have been set by procedure verify_shared_control_cells earlier
									-- put_line("bic : " & to_string(b.name));

									-- if this control cell is not in the journal yet:
									if not element(net.pins, positive(p)).cell_info.control_cell_in_journal then 
									-- NOTE: the flag cell_info.control_cell_in_journal may have been set by 
									-- procedure find_other_nets_with_this_control_cell in order to prevent
									-- multiple searching for nets connected to that control cell
										--put_line("bic : " & to_string(b.name));
										shared_control_cell_found := true;

										-- assume this control cell as "master cell". later procedure find_other_nets_with_this_control_cell
										-- will search for other nets connected to this control cell
										shared_control_cell_with_nets.cell_id := element(net.pins, positive(p)).cell_info.control_cell_id;

										-- purge temporarily list_of_nets_with_shared_control_cell
										delete(list_of_nets_with_shared_control_cell,1,length(list_of_nets_with_shared_control_cell));
										
										--net_with_shared_control_cell.name := net.name;
										net_with_shared_control_cell.name := key(net_cursor);
										net_with_shared_control_cell.level := net.level;
										net_with_shared_control_cell.class := net.class;
										append(list_of_nets_with_shared_control_cell, net_with_shared_control_cell);

										find_other_nets_with_this_control_cell(
											--origin => net.name,
											origin => net_cursor,
											cc_id => element(net.pins, positive(p)).cell_info.control_cell_id);

										shared_control_cell_with_nets.nets := list_of_nets_with_shared_control_cell;
										append(list_of_shared_control_cells, shared_control_cell_with_nets);
									end if;
								end if;
							end if;
						end if;
					end loop;
				end if;

				next(net_cursor);
			end loop;

			-- add to bic the shared control cell (if there is any shared control cell)
			-- if no shared control cell of this bic found, nothing is to be added to journal
			if shared_control_cell_found then
				bic_with_shared_control_cell.name := bic_name;
				bic_with_shared_control_cell.cells := list_of_shared_control_cells;
				--put_line("bic: " & to_string(bic_name));
				append(shared_control_cell_journal, bic_with_shared_control_cell);
			end if;
		end loop;
	end make_shared_control_cell_journal;

	procedure mark_active_scanport is
	-- searches bics in scanport list and sets flag "active" if particular scanport is used by any bic
		sp : type_scanport;
		bic_cursor : type_list_of_bics.cursor;
	begin
		put_line(" marking active scanports ...");
		for s in 1..length(list_of_scanports) loop
			sp := element(list_of_scanports, positive(s));

-- 			for b in 1..length(list_of_bics) loop    
-- 				if element(list_of_bics,positive(b)).chain = type_scanport_id(s) then -- bic is in scanport
-- 					sp.active := true; -- mark port as active 
-- 					exit; -- no further search required
-- 				end if;
-- 			end loop;

			bic_cursor := first(list_of_bics);
			while bic_cursor /= type_list_of_bics.no_element loop
				if element(bic_cursor).chain = type_scanport_id(s) then -- bic is in scanport
					sp.active := true; -- mark port as active 
					exit; -- no further search required
				end if;
				next(bic_cursor);
			end loop;

			replace_element(list_of_scanports, positive(s), sp);

		end loop;
	end mark_active_scanport;
	

	procedure process_static_control_cell_class_EX_NA (line : in type_fields_of_line) is
		cell : type_static_control_cell_class_EX_NA;				
	begin
		-- check class keyword
		if get_field_from_line(line,1) /= cell_list_keyword_class then
			cell_list_put_error_on_class_keyword_expected;
		end if;

		-- get net class
		case type_net_class'value(get_field_from_line(line,2)) is
			when EH => cell.class := EH;
			when EL => cell.class := EL;
			when NA => cell.class := NA;
			when others =>
				cell_list_put_error_on_invalid_class;
		end case;

		-- get net level
		case type_cell_list_net_level'value(get_field_from_line(line,3)) is
			when primary_net => 	cell.level := primary;
			when secondary_net => 	cell.level := secondary;
		end case;

		-- get net name
		cell.net := to_bounded_string(get_field_from_line(line,4));

		-- check device keyword
		if get_field_from_line(line,5) /= cell_list_keyword_device then
			cell_list_put_error_on_device_keyword_expected;
		end if;
		
		-- get device name
		cell.device := to_bounded_string(get_field_from_line(line,6));

		-- check pin keyword
		if get_field_from_line(line,7) /= cell_list_keyword_pin then
			cell_list_put_error_on_pin_keyword_expected;
		end if;

		-- get pin name
		cell.pin := to_bounded_string(get_field_from_line(line,8));

		-- check control cell keyword
		if get_field_from_line(line,9) /= cell_list_keyword_control_cell then
			cell_list_put_error_on_control_cell_keyword_expected;
		end if;						

		-- get control cell id
		cell.id := type_cell_id'value(get_field_from_line(line,10)); 
		
		-- check locked_to keyword
		if get_field_from_line(line,11) /= cell_list_keyword_locked_to then
			cell_list_put_error_on_cell_locked_to_keyword_expected;
		end if;						

		-- check disable_value keyword
		if get_field_from_line(line,12) = cell_list_keyword_disable_value then
			null; --cell_list_control_cell_in_enable_state := false;
		else
			cell_list_put_error_on_cell_disable_value_keyword_expected;
			write_message (
				file_handle => current_output,
				text => "In a net of class EH, EL or NA, control cells must be locked in disable state !",
				console => true);
			raise constraint_error;
		end if;						

		-- get control cell disable value
		cell.disable_value := type_bit_char_class_0'value(enclose_in_quotes(get_field_from_line(line,13)));

		-- write cell status in cell info of that pin
		lock_control_cell_in_class_EH_EL_NA_net(
			class							=> cell.class,
			level							=> cell.level,
			net								=> cell.net,
			device							=> cell.device,
			pin								=> cell.pin,
			control_cell_id					=> cell.id,
			control_cell_in_enable_state	=> false,
			control_cell_value				=> cell.disable_value
			);
		
		type_list_of_static_control_cells_class_EX_NA.append(list_of_static_control_cells_class_EX_NA, cell);
	end process_static_control_cell_class_EX_NA;


	procedure process_static_control_cell_class_DX_NR (line : in type_fields_of_line) is
		cell 	: type_cell_of_cell_list;
		level 	: type_net_level;
		control_cell_in_enable_state : boolean;
	begin
		-- check class keyword
		if get_field_from_line(line,1) /= cell_list_keyword_class then
			cell_list_put_error_on_class_keyword_expected;
		end if;

		-- get net class
		case type_net_class'value(get_field_from_line(line,2)) is
			when DH => cell.class := DH;
			when DL => cell.class := DL;
			when NR => cell.class := NR;
			when others =>
				cell_list_put_error_on_invalid_class;
		end case;

		-- get net level
		case type_cell_list_net_level'value(get_field_from_line(line,3)) is
			when primary_net => 	level := primary;
			when secondary_net => 	level := secondary;
		end case;

		-- get net name
		cell.net := to_bounded_string(get_field_from_line(line,4));

		-- check device keyword
		if get_field_from_line(line,5) /= cell_list_keyword_device then
			cell_list_put_error_on_device_keyword_expected;
		end if;
		
		-- get device name
		cell.device := to_bounded_string(get_field_from_line(line,6));

		-- check pin keyword
		if get_field_from_line(line,7) /= cell_list_keyword_pin then
			cell_list_put_error_on_pin_keyword_expected;
		end if;

		-- get pin name
		cell.pin := to_bounded_string(get_field_from_line(line,8));

		-- check control cell keyword
		if get_field_from_line(line,9) /= cell_list_keyword_control_cell then
			cell_list_put_error_on_control_cell_keyword_expected;
		end if;						

		-- get control cell id
		cell.id := type_cell_id'value(get_field_from_line(line,10)); 
		
		-- check locked_to keyword
		if get_field_from_line(line,11) /= cell_list_keyword_locked_to then
			cell_list_put_error_on_cell_locked_to_keyword_expected;
		end if;						

		-- check enable/disable_value keyword in dependence of net level
		case level is
			when secondary => -- if secondary net, control cell must be disabled for this pin
				if get_field_from_line(line,12) = cell_list_keyword_disable_value then
					control_cell_in_enable_state := false;
				else
					cell_list_put_error_on_cell_disable_value_keyword_expected;
					write_message (
						file_handle => current_output,
						text => "In secondary nets of class DH, DL or NR, the control cell of a pin must be locked in disable state !",
						console => true);
					raise constraint_error;
				end if;
			when primary => -- in a primary net, control cells may be in enable or disable state
				if get_field_from_line(line,12) = cell_list_keyword_disable_value then
					control_cell_in_enable_state := false;
				elsif get_field_from_line(line,12) = cell_list_keyword_enable_value then
					control_cell_in_enable_state := true;
				else
					cell_list_put_error_on_enable_disable_keyword_expected;
				end if;
		end case;


		-- write cell status in cell info of that pin
		lock_control_cell_in_class_DX_NR(
			class							=> cell.class,
			level							=> level,
			net								=> cell.net,
			device							=> cell.device,
			pin								=> cell.pin,
			control_cell_id					=> cell.id,
			control_cell_in_enable_state	=> control_cell_in_enable_state,
			control_cell_value				=> type_bit_char_class_0'value(
												enclose_in_quotes(get_field_from_line(line,13)))
			);		
		
		-- build cell and append to cell list
		if control_cell_in_enable_state then
			type_list_of_static_control_cells_class_DX_NR.append(list_of_static_control_cells_class_DX_NR, 
				( cell with 
					locked_to_enable_state => true,
					level => level,
					-- get control cell value
					enable_value => type_bit_char_class_0'value(enclose_in_quotes(get_field_from_line(line,13)))
				));
		else
			type_list_of_static_control_cells_class_DX_NR.append(list_of_static_control_cells_class_DX_NR, 
				( cell with 
					locked_to_enable_state => false,
					level => level,
					-- get control cell value
					disable_value => type_bit_char_class_0'value(enclose_in_quotes(get_field_from_line(line,13)))
				));
		end if;

	end process_static_control_cell_class_DX_NR;


	procedure process_static_control_cell_class_PX (line : in type_fields_of_line) is
		cell 	: type_static_control_cell_class_PX;
		level 	: type_net_level;
	begin
		-- check class keyword
		if get_field_from_line(line,1) /= cell_list_keyword_class then
			cell_list_put_error_on_class_keyword_expected;
		end if;

		-- get net class
		case type_net_class'value(get_field_from_line(line,2)) is
			when PU => cell.class := PU;
			when PD => cell.class := PD;
			when others =>
				cell_list_put_error_on_invalid_class;
		end case;

		-- get net level
		case type_cell_list_net_level'value(get_field_from_line(line,3)) is
			when primary_net => 	level := primary;
			when secondary_net => 	level := secondary;
		end case;

		-- get net name
		cell.net := to_bounded_string(get_field_from_line(line,4));

		-- check device keyword
		if get_field_from_line(line,5) /= cell_list_keyword_device then
			cell_list_put_error_on_device_keyword_expected;
		end if;
		
		-- get device name
		cell.device := to_bounded_string(get_field_from_line(line,6));

		-- check pin keyword
		if get_field_from_line(line,7) /= cell_list_keyword_pin then
			cell_list_put_error_on_pin_keyword_expected;
		end if;

		-- get pin name
		cell.pin := to_bounded_string(get_field_from_line(line,8));

		-- check control cell keyword
		if get_field_from_line(line,9) /= cell_list_keyword_control_cell then
			cell_list_put_error_on_control_cell_keyword_expected;
		end if;						

		-- get control cell id
		cell.id := type_cell_id'value(get_field_from_line(line,10)); 
		
		-- check locked_to keyword
		if get_field_from_line(line,11) /= cell_list_keyword_locked_to then
			cell_list_put_error_on_cell_locked_to_keyword_expected;
		end if;						

		-- check disable_value keyword
		if get_field_from_line(line,12) = cell_list_keyword_disable_value then
			null;
		else
			cell_list_put_error_on_cell_disable_value_keyword_expected;
			write_message (
				file_handle => current_output,
				text => "In nets of class PU or PD, the control cell of a unused pin must be locked in disable state !",
				console => true);
			raise constraint_error;
		end if;

		-- get control cell value
		cell.disable_value := type_bit_char_class_0'value(enclose_in_quotes(get_field_from_line(line,13)));
		
		-- write cell status in cell info of that pin
		lock_control_cell_in_class_PU_PD_net(
			class				=> cell.class,
			level				=> level,
			net					=> cell.net,
			device				=> cell.device,
			pin					=> cell.pin,
			control_cell_id		=> cell.id,
			control_cell_value	=> cell.disable_value
			);
		
		-- append to cell list
		type_list_of_static_control_cells_class_PX.append(list_of_static_control_cells_class_PX, cell);

	end process_static_control_cell_class_PX;


	procedure process_static_output_cell_class_PX (line : in type_fields_of_line) is	
		cell 	: type_static_output_cell_class_PX;
		level 	: type_net_level;
	begin
		-- check class keyword
		if get_field_from_line(line,1) /= cell_list_keyword_class then
			cell_list_put_error_on_class_keyword_expected;
		end if;

		-- get net class
		case type_net_class'value(get_field_from_line(line,2)) is
			when PU => cell.class := PU;
			when PD => cell.class := PD;
			when others =>
				cell_list_put_error_on_invalid_class;
		end case;

		-- get net level
		case type_cell_list_net_level'value(get_field_from_line(line,3)) is
			when primary_net =>
				level := primary;
			when secondary_net =>
				write_message (
					file_handle => current_output,
					text => message_error & "This section adresses primary nets exclusively !",
					console => true);
				raise constraint_error;
		end case;

		-- get net name
		cell.net := to_bounded_string(get_field_from_line(line,4));

		-- check device keyword
		if get_field_from_line(line,5) /= cell_list_keyword_device then
			cell_list_put_error_on_device_keyword_expected;
		end if;
		
		-- get device name
		cell.device := to_bounded_string(get_field_from_line(line,6));

		-- check pin keyword
		if get_field_from_line(line,7) /= cell_list_keyword_pin then
			cell_list_put_error_on_pin_keyword_expected;
		end if;

		-- get pin name
		cell.pin := to_bounded_string(get_field_from_line(line,8));

		-- check output cell keyword
		if get_field_from_line(line,9) /= cell_list_keyword_output_cell then
			cell_list_put_error_on_output_cell_keyword_expected;
		end if;						

		-- get output cell id
		cell.id := type_cell_id'value(get_field_from_line(line,10)); 
		
		-- check locked_to keyword
		if get_field_from_line(line,11) /= cell_list_keyword_locked_to then
			cell_list_put_error_on_cell_locked_to_keyword_expected;
		end if;						

		-- check drive_value keyword
		if get_field_from_line(line,12) = cell_list_keyword_drive_value then
			null;
		else
			cell_list_put_error_on_drive_value_keyword_expected;
			write_message (
				file_handle => current_output,
				text => "In nets of class PU or PD, the control cell of an unused pin must be locked to disable state !",
				console => true);
			raise constraint_error;
		end if;

		-- get drive value
		cell.drive_value := type_bit_char_class_0'value(enclose_in_quotes(get_field_from_line(line,13)));
		
		-- write cell status in cell info of that pin
		lock_output_cell_in_class_PU_PD_net(
			class					=> cell.class,
			level					=> level,
			net						=> cell.net,
			device					=> cell.device,
			pin						=> cell.pin,
			output_cell_id			=> cell.id,
			output_cell_drive_value	=> cell.drive_value
			);
		
		-- append to cell list
		type_list_of_static_output_cells_class_PX.append(list_of_static_output_cells_class_PX, cell);

	end process_static_output_cell_class_PX;
	

	procedure process_static_output_cell_class_DX_NR (line : in type_fields_of_line) is	
		cell 	: type_static_output_cell_class_DX_NR;
		level 	: type_net_level;
	begin
		-- check class keyword
		if get_field_from_line(line,1) /= cell_list_keyword_class then
			cell_list_put_error_on_class_keyword_expected;
		end if;

		-- get net class
		case type_net_class'value(get_field_from_line(line,2)) is
			when DH => cell.class := DH;
			when DL => cell.class := DL;
			when NR => cell.class := NR;
			when others =>
				cell_list_put_error_on_invalid_class;
		end case;

		-- get net level
		case type_cell_list_net_level'value(get_field_from_line(line,3)) is
			when primary_net =>
				level := primary;
			when secondary_net =>
				write_message (
					file_handle => current_output,
					text => message_error & "This section adresses primary nets exclusively !",
					console => true);
				raise constraint_error;
		end case;

		-- get net name
		cell.net := to_bounded_string(get_field_from_line(line,4));

		-- check device keyword
		if get_field_from_line(line,5) /= cell_list_keyword_device then
			cell_list_put_error_on_device_keyword_expected;
		end if;
		
		-- get device name
		cell.device := to_bounded_string(get_field_from_line(line,6));

		-- check pin keyword
		if get_field_from_line(line,7) /= cell_list_keyword_pin then
			cell_list_put_error_on_pin_keyword_expected;
		end if;

		-- get pin name
		cell.pin := to_bounded_string(get_field_from_line(line,8));

		-- check output cell keyword
		if get_field_from_line(line,9) /= cell_list_keyword_output_cell then
			cell_list_put_error_on_output_cell_keyword_expected;
		end if;						

		-- get output cell id
		cell.id := type_cell_id'value(get_field_from_line(line,10)); 
		
		-- check locked_to keyword
		if get_field_from_line(line,11) /= cell_list_keyword_locked_to then
			cell_list_put_error_on_cell_locked_to_keyword_expected;
		end if;						

		-- check drive_value keyword
		if get_field_from_line(line,12) = cell_list_keyword_drive_value then
			null;
		else
			cell_list_put_error_on_drive_value_keyword_expected;
			raise constraint_error;
		end if;

		-- get drive value
		cell.drive_value := type_bit_char_class_0'value(enclose_in_quotes(get_field_from_line(line,13)));
		
		-- write cell status in cell info of that pin
		lock_output_cell_in_class_DX(
			class					=> cell.class,
			level					=> level,
			net						=> cell.net,
			device					=> cell.device,
			pin						=> cell.pin,
			output_cell_id			=> cell.id,
			output_cell_drive_value	=> cell.drive_value
			);
		
		-- append to cell list
		type_list_of_static_output_cells_class_DX_NR.append(list_of_static_output_cells_class_DX_NR, cell);

	end process_static_output_cell_class_DX_NR;


	procedure process_static_expect_cell (line : in type_fields_of_line) is
		cell 			: type_cell_of_cell_list;
		level 			: type_net_level;
		expect_value	: type_bit_char_class_0;
		primary_net_is	: type_net_name.bounded_string;
	begin
		-- check class keyword
		if get_field_from_line(line,1) /= cell_list_keyword_class then
			cell_list_put_error_on_class_keyword_expected;
		end if;

		-- get net class
		case type_net_class'value(get_field_from_line(line,2)) is
			when DH => cell.class := DH;
			when DL => cell.class := DL;
			when EH => cell.class := EH;
			when EL => cell.class := EL;
			when others =>
				cell_list_put_error_on_invalid_class;
		end case;

		-- get net level
		case type_cell_list_net_level'value(get_field_from_line(line,3)) is
			when primary_net => 	level := primary;
			when secondary_net =>	level := secondary;
		end case;

		-- get net name
		cell.net := to_bounded_string(get_field_from_line(line,4));

		-- check device keyword
		if get_field_from_line(line,5) /= cell_list_keyword_device then
			cell_list_put_error_on_device_keyword_expected;
		end if;
		
		-- get device name
		cell.device := to_bounded_string(get_field_from_line(line,6));

		-- check pin keyword
		if get_field_from_line(line,7) /= cell_list_keyword_pin then
			cell_list_put_error_on_pin_keyword_expected;
		end if;

		-- get pin name
		cell.pin := to_bounded_string(get_field_from_line(line,8));

		-- check input cell keyword
		if get_field_from_line(line,9) /= cell_list_keyword_input_cell then
			cell_list_put_error_on_input_cell_keyword_expected;
		end if;						

		-- get input cell id
		cell.id := type_cell_id'value(get_field_from_line(line,10)); 
		
		-- check expect_value keyword
		if get_field_from_line(line,11) /= cell_list_keyword_expect_value then
			cell_list_put_error_on_expect_value_keyword_expected;
		end if;						

		-- get expect value of input cell depending on net class
		expect_value := type_bit_char_class_0'value(enclose_in_quotes(get_field_from_line(line,12)));
		case cell.class is
			when EH | DH => -- an input cell should read a 1 here 
				if expect_value = '1' then 
					null;
				else
					cell_list_put_error_on_invalid_static_expect_value;
				end if;
			when EL | DL => -- in input cell should read a 0 here
				if expect_value = '0' then 
					null;
				else
					cell_list_put_error_on_invalid_static_expect_value;
				end if;
			when others => -- his should never happen, as the net class check has been conducted earlier
				cell_list_put_error_on_invalid_class;
		end case;

		-- if secondary net, get primary_net_is identifier and name from fields 13 and 14
		if level = secondary then
		-- 			if get_field_count(line) = 14 then -- due to trailing fields "primary_net_is net_abc"
			if line.field_count = 14 then -- due to trailing fields "primary_net_is net_abc"
				if get_field_from_line(line,13) /= cell_list_keyword_primary_net_is then
					cell_list_put_error_on_primary_net_is_keyword_expected;
				end if;
				primary_net_is := to_bounded_string(get_field_from_line(line,14));
			else -- if there are not 14 fields
				cell_list_put_error_on_primary_net_is_keyword_expected;
			end if;
		end if;

		lock_input_cell_static_expect(
			class					=> cell.class,
			level					=> level,
			net						=> cell.net,
			device					=> cell.device,
			pin						=> cell.pin,
			input_cell_id			=> cell.id,
			input_cell_expect_value	=> expect_value,
			primary_net_is			=> primary_net_is
			);

		-- build cell and add cell to cell list
		case level is
			when primary =>
				type_list_of_static_expect_cells.append(list_of_static_expect_cells,
					( cell with 
						level => primary,
						expect_value => expect_value)
					);
			when secondary =>
				type_list_of_static_expect_cells.append(list_of_static_expect_cells,
					( cell with 
						level => secondary,
						primary_net_is => primary_net_is,
						expect_value => expect_value)
					);
		end case;
	end process_static_expect_cell;


	procedure process_atg_expect_cell (line : in type_fields_of_line) is
		cell 			: type_cell_of_cell_list;
		level 			: type_net_level;
		primary_net_is	: type_net_name.bounded_string;
	begin
		-- check class keyword
		if get_field_from_line(line,1) /= cell_list_keyword_class then
			cell_list_put_error_on_class_keyword_expected;
		end if;

		-- get net class
		case type_net_class'value(get_field_from_line(line,2)) is
			when NR => cell.class := NR;
			when PU => cell.class := PU;
			when PD => cell.class := PD;
			when others =>
				cell_list_put_error_on_invalid_class;
		end case;

		-- get net level
		case type_cell_list_net_level'value(get_field_from_line(line,3)) is
			when primary_net => 	level := primary;
			when secondary_net =>	level := secondary;
		end case;

		-- get net name
		cell.net := to_bounded_string(get_field_from_line(line,4));

		-- check device keyword
		if get_field_from_line(line,5) /= cell_list_keyword_device then
			cell_list_put_error_on_device_keyword_expected;
		end if;
		
		-- get device name
		cell.device := to_bounded_string(get_field_from_line(line,6));

		-- check pin keyword
		if get_field_from_line(line,7) /= cell_list_keyword_pin then
			cell_list_put_error_on_pin_keyword_expected;
		end if;

		-- get pin name
		cell.pin := to_bounded_string(get_field_from_line(line,8));

		-- check input cell keyword
		if get_field_from_line(line,9) /= cell_list_keyword_input_cell then
			cell_list_put_error_on_input_cell_keyword_expected;
		end if;						

		-- get input cell id
		cell.id := type_cell_id'value(get_field_from_line(line,10)); 
		
		-- if secondary net, get primary_net_is keyword and name from fields 11 and 12
		if level = secondary then
		-- 			if get_field_count(line) = 12 then -- due to trailing fields "primary_net_is net_abc"
			if line.field_count = 12 then -- due to trailing fields "primary_net_is net_abc"
				if get_field_from_line(line,11) /= cell_list_keyword_primary_net_is then
					cell_list_put_error_on_primary_net_is_keyword_expected;
				end if;
				primary_net_is := to_bounded_string(get_field_from_line(line,12));
			else -- if there are not 12 fields
				cell_list_put_error_on_primary_net_is_keyword_expected;
			end if;
		end if;

		assign_input_cell_atg_expect(
			class					=> cell.class,
			level					=> level,
			net						=> cell.net,
			device					=> cell.device,
			pin						=> cell.pin,
			input_cell_id			=> cell.id,
			primary_net_is			=> primary_net_is
			);

		-- build cell and add cell to cell list
		case level is
			when primary =>
				type_list_of_atg_expect_cells.append(list_of_atg_expect_cells,
					( cell with 
						level => primary)
					);
			when secondary =>
				type_list_of_atg_expect_cells.append(list_of_atg_expect_cells,
					( cell with 
						level => secondary,
						primary_net_is => primary_net_is)
					);
		end case;
	end process_atg_expect_cell;


	procedure process_atg_drive_cell (line : in type_fields_of_line) is	
		cell 						: type_cell_of_cell_list;
		controlled_by_control_cell	: boolean := false;
		control_cell_inverted		: boolean := false;		
	begin
		-- check class keyword
		if get_field_from_line(line,1) /= cell_list_keyword_class then
			cell_list_put_error_on_class_keyword_expected;
		end if;

		-- get net class
		case type_net_class'value(get_field_from_line(line,2)) is
			when NR => cell.class := NR;
			when PU => cell.class := PU;
			when PD => cell.class := PD;
			when others =>
				cell_list_put_error_on_invalid_class;
		end case;

		-- get net level
		case type_cell_list_net_level'value(get_field_from_line(line,3)) is
			when primary_net => null;
			when secondary_net =>
				write_message (
					file_handle => current_output,
					text => message_error & "This section adresses primary nets exclusively !",
					console => true);
				raise constraint_error;
		end case;

		-- get net name
		cell.net := to_bounded_string(get_field_from_line(line,4));

		-- check device keyword
		if get_field_from_line(line,5) /= cell_list_keyword_device then
			cell_list_put_error_on_device_keyword_expected;
		end if;
		
		-- get device name
		cell.device := to_bounded_string(get_field_from_line(line,6));

		-- check pin keyword
		if get_field_from_line(line,7) /= cell_list_keyword_pin then
			cell_list_put_error_on_pin_keyword_expected;
		end if;

		-- get pin name
		cell.pin := to_bounded_string(get_field_from_line(line,8));

		-- example 1 : class NR primary_net LED7 device IC303 pin 2 output_cell 7
		-- example 2 : class PU primary_net /CPU_WR device IC300 pin 26 control_cell 6 inverted yes
		-- example 3 : class PD primary_net /DRV_EN device IC301 pin 27 control_cell 9 inverted no
		
		-- check output/control cell keyword
		if get_field_from_line(line,9) = cell_list_keyword_output_cell then
			controlled_by_control_cell	:= false;
			-- cell id in field 10 is read later
			
		elsif get_field_from_line(line,9) = cell_list_keyword_control_cell then
			controlled_by_control_cell	:= true;
			-- cell id in field 10 is read later
			
			-- if a control cell is specified here, two extra fields are expected and to evaluate
			-- 			if get_field_count(line) = 12 then -- due to trailing fields "inverted yes/no"
			if line.field_count = 12 then -- due to trailing fields "inverted yes/no"

				-- get inverted identifier
				if get_field_from_line(line,11) /= cell_list_keyword_control_cell_inverted then
					cell_list_put_error_on_control_cell_inverted_keyword_expected;
				end if;
				
				-- get inverted yes/no status
				if get_field_from_line(line,12) = cell_list_keyword_yes then
					control_cell_inverted := true;
				elsif get_field_from_line(line,12) = cell_list_keyword_no then
					control_cell_inverted := false;
				else
					cell_list_put_error_on_control_cell_inverted_keyword_expected;
				end if;
				
			else -- if there are not 12 fields
				cell_list_put_error_on_control_cell_inverted_keyword_expected;
				raise constraint_error;
			end if;
		else
			cell_list_put_error_on_output_or_control_cell_keyword_expected;
		end if;						

		-- get output or control cell id
		cell.id := type_cell_id'value(get_field_from_line(line,10)); 
		

		assign_output_control_cell_atg_drive(
			class						=> cell.class,
			level						=> primary, -- CS: always primary
			net							=> cell.net,
			device						=> cell.device,
			pin							=> cell.pin,
			controlled_by_control_cell	=> controlled_by_control_cell,
			output_cell_id				=> cell.id,
			control_cell_id				=> cell.id,
			control_cell_inverted		=> control_cell_inverted
			);

		
		-- build cell and add cell to cell list
		case controlled_by_control_cell is
			when true =>
				type_list_of_atg_drive_cells.append(list_of_atg_drive_cells,
					( cell with 
						controlled_by_control_cell => true,
						inverted => control_cell_inverted)
					);
			when false =>
				type_list_of_atg_drive_cells.append(list_of_atg_drive_cells,
					( cell with 
						controlled_by_control_cell => false)
					);
		end case;
	end process_atg_drive_cell;


	procedure process_input_cell_class_NA (line : in type_fields_of_line) is	
		cell 			: type_cell_of_cell_list;
		level 			: type_net_level;
		primary_net_is	: type_net_name.bounded_string;
	begin
		-- check class keyword
		if get_field_from_line(line,1) /= cell_list_keyword_class then
			cell_list_put_error_on_class_keyword_expected;
		end if;

		-- get net class
		case type_net_class'value(get_field_from_line(line,2)) is
			when NA => cell.class := NA;
			when others =>
				cell_list_put_error_on_invalid_class;
		end case;

		-- get net level
		case type_cell_list_net_level'value(get_field_from_line(line,3)) is
			when primary_net => 	level := primary;
			when secondary_net =>	level := secondary;
		end case;

		-- get net name
		cell.net := to_bounded_string(get_field_from_line(line,4));

		-- check device keyword
		if get_field_from_line(line,5) /= cell_list_keyword_device then
			cell_list_put_error_on_device_keyword_expected;
		end if;
		
		-- get device name
		cell.device := to_bounded_string(get_field_from_line(line,6));

		-- check pin keyword
		if get_field_from_line(line,7) /= cell_list_keyword_pin then
			cell_list_put_error_on_pin_keyword_expected;
		end if;

		-- get pin name
		cell.pin := to_bounded_string(get_field_from_line(line,8));

		-- check input cell keyword
		if get_field_from_line(line,9) /= cell_list_keyword_input_cell then
			cell_list_put_error_on_input_cell_keyword_expected;
		end if;						

		-- get input cell id
		cell.id := type_cell_id'value(get_field_from_line(line,10)); 

		-- if secondary net, get primary_net_is identifier and name from fields 13 and 14
		if level = secondary then
		-- 			if get_field_count(line) = 12 then -- due to trailing fields "primary_net_is net_abc"
			if line.field_count = 12 then -- due to trailing fields "primary_net_is net_abc"		
				if get_field_from_line(line,11) /= cell_list_keyword_primary_net_is then
					cell_list_put_error_on_primary_net_is_keyword_expected;
				end if;
				primary_net_is := to_bounded_string(get_field_from_line(line,12));
			else -- if there are not 12 fields
				cell_list_put_error_on_primary_net_is_keyword_expected;
			end if;
		end if;

		assign_input_cell_unclassified_net(
			class				=> cell.class,
			level				=> level,
			net					=> cell.net,
			device				=> cell.device,
			pin					=> cell.pin,
			input_cell_id		=> cell.id,
			primary_net_is		=> primary_net_is
			);

		-- build cell and add cell to cell list
		case level is
			when primary =>
				type_list_of_input_cells_class_NA.append(list_of_input_cells_class_NA,
					( cell with 
						level => primary)
					);
			when secondary =>
				type_list_of_input_cells_class_NA.append(list_of_input_cells_class_NA,
					( cell with 
						level => secondary,
						primary_net_is => primary_net_is)
					);
		end case;
	end process_input_cell_class_NA;

	
	procedure clear_summary is
		summary_default : type_udb_summary;
	begin
		summary := summary_default;
	end clear_summary;

	procedure clear_lists is
		use type_list_of_scanports;
 		use type_list_of_bics_pre;
		use type_list_of_bics;
		use type_list_of_nets;
		
		use type_list_of_static_control_cells_class_EX_NA;
		use type_list_of_static_control_cells_class_DX_NR;
		use type_list_of_static_control_cells_class_PX;
		use type_list_of_static_output_cells_class_PX;
		use type_list_of_static_output_cells_class_DX_NR;
		use type_list_of_static_expect_cells;

		use type_list_of_atg_expect_cells;
		use type_list_of_atg_drive_cells;		

		use type_list_of_input_cells_class_NA;
	begin
		delete(list_of_scanports,1,length(list_of_scanports)); -- CS: use "clear" for all vectors
-- 		delete(list_of_bics_pre,1,length(list_of_bics_pre));
		clear(list_of_bics_pre);
		-- 		delete(list_of_bics,1,length(list_of_bics));
		clear(list_of_bics);
		-- 		delete(list_of_nets,1,length(list_of_nets));
		clear(list_of_nets);

		delete(list_of_static_control_cells_class_EX_NA,1,length(list_of_static_control_cells_class_EX_NA));
		delete(list_of_static_control_cells_class_DX_NR,1,length(list_of_static_control_cells_class_DX_NR));
		delete(list_of_static_control_cells_class_PX,1,length(list_of_static_control_cells_class_PX));
		delete(list_of_static_output_cells_class_PX,1,length(list_of_static_output_cells_class_PX));
		delete(list_of_static_output_cells_class_DX_NR,1,length(list_of_static_output_cells_class_DX_NR));
		delete(list_of_static_expect_cells,1,length(list_of_static_expect_cells));
		
		delete(list_of_atg_expect_cells,1,length(list_of_atg_expect_cells));
		delete(list_of_atg_drive_cells,1,length(list_of_atg_drive_cells));
		
		delete(list_of_input_cells_class_NA,1,length(list_of_input_cells_class_NA));
	end clear_lists;

   	procedure read_uut_database is
		-- to do: 
		--	check multiple occurences of bic in section registers
		--	save line numbers of objects in order to make debugging easier
		--  in highest degree_of_database_integrity_check -> error if a pin occurs more than once (function occurences_of_pin)
		use ada.exceptions;
			
		prog_position 			: natural := 0;
		line_list				: type_fields_of_line;
		line_counter			: natural := 0;
		net_counter				: natural := 0; -- general net counter. increments once a net has been added to list_of_nets
		
		section_scanpath_configuration_entered					: boolean := false;
		subsection_scanpath_configuration_options_entered 		: boolean := false;
		subsection_scanpath_configuration_scanpath_1_entered	: boolean := false;
		subsection_scanpath_configuration_scanpath_2_entered	: boolean := false;
		
		section_registers_entered				: boolean := false;
		subsection_bic_entered					: boolean := false;
		subsection_safebits_entered				: boolean := false;
		subsection_opcodes_entered				: boolean := false;		
		subsection_boundary_register_entered	: boolean := false;
		subsection_port_io_map_entered			: boolean := false;
		subsection_port_pin_map_entered			: boolean := false;		

		section_netlist_entered					: boolean := false;
		subsection_net_entered					: boolean := false;
		net_level_entered						: type_net_level := primary;

		section_static_control_cells_class_EX_NA_entered	: boolean := false;
		section_static_control_cells_class_DX_NR_entered	: boolean := false;
		section_static_control_cells_class_PX_entered		: boolean := false;
		section_static_output_cells_class_PX_entered		: boolean := false;
		section_static_output_cells_class_DX_NR_entered		: boolean := false;
		section_static_expect_entered						: boolean := false;
		section_atg_expect_entered							: boolean := false;
		section_atg_drive_entered							: boolean := false;
		section_input_cells_in_class_NA_nets_entered		: boolean := false;
		
		section_statistics_entered							: boolean := false;

		empty_pin_list : type_list_of_pins.vector; -- used for clearing pin_list_preliminary. do not append anything here !
	begin -- read read_uut_database

		-- clean up summary and main lists from previous spins
		clear_summary;
		clear_lists;

		-- To improve performance several lists should get a reserved capacity:
		reserve_capacity(empty_list_of_secondary_net_names,0);
		-- CS: add more lists

		put_line("degree of database integrity check " 
			& type_degree_of_database_integrity_check'image(degree_of_database_integrity_check));
		put_line(column_separator_0);
		put_line("reading database ...");

		-- open database
		if not exists(type_name_database.to_string(name_file_database)) then
			write_message (
				file_handle => current_output,
				text => message_error & text_identifier_database 
					& type_name_database.to_string(name_file_database) & " does not exist !",
				console => true);
			raise constraint_error;
		end if;
		
		open(file => file_database, name => type_name_database.to_string(name_file_database), mode => in_file);
		set_input(file_database);

		-- The main loop that reads the database line per line is cancelled depending on
		-- the action:
		
		loop_read_database:
		while not end_of_file loop
			line_counter := line_counter + 1;
			line_list := read_line(get_line);
			if line_list.field_count > 0 then -- if line contains anything

						-- read scanpath configuration begin
						if not section_scanpath_configuration_entered then
							-- wait for section scanpath_configuration header
							if get_field_from_line(line_list,1) = section_mark.section and
							get_field_from_line(line_list,2) = section_scanpath_configuration then
								section_scanpath_configuration_entered := true;
								write_message (
									file_handle => current_output,
									text => "reading scanpath configuration ...", 
									console => true);
							end if;
						else
							if get_field_from_line(line_list,1) = section_mark.endsection then 
							-- we are leaving the section scanpath_configuration
								section_scanpath_configuration_entered := false;
								summary.sections_processed.section_scanpath_configuration := true; -- mark section as processed
								summary.line_number_end_of_section_scanpath_configuration := line_counter; -- save line number in summary

								-- We finish here if we are importing bsdl models
								if action = import_bsdl then
									exit loop_read_database;
								end if;
							else -- we are inside the section scanpath_configuration
		-- 						write_message (
		-- 							file_handle => current_output,
		-- 							identation => 1,
		-- 							text => to_string(line));
								
								-- read scanpath options begin
								if not subsection_scanpath_configuration_options_entered then
									
									-- wait for subsection scanpath options header
									if get_field_from_line(line_list,1) = section_mark.subsection and 
									get_field_from_line(line_list,2) = subsection_scanpath_configuration_options then
										subsection_scanpath_configuration_options_entered := true;
										write_message (
											file_handle => current_output,
											identation => 1,
											text => "reading scanpath options ...", 
											console => true);
									end if;
								else
									if get_field_from_line(line_list,1) = section_mark.endsubsection then 
									-- we are leaving the subsection "options"
										subsection_scanpath_configuration_options_entered := false;

										-- Append preliminary scanport regardless if something is connected to it or not.
										append(list_of_scanports,scanport_1_preliminary);
										append(list_of_scanports,scanport_2_preliminary);								
										
									else -- we are inside the subsection
		-- 							   	write_message (
		-- 									file_handle => file_database_messages,
		-- 									identation => 2,
		-- 									text => to_string(line), 
		-- 									--lf   : in boolean := true;		
		-- 									--file : in boolean := true;
		-- 									console => false);

										-- process line
										case type_scanpath_option'value(get_field_from_line(line_list,1)) is
											when on_fail =>
												prog_position := 20200;
												case type_on_fail_action'value(get_field_from_line(line_list,2)) is
													when hstrst => scanport_options_global.on_fail_action := hstrst;
													when power_down => scanport_options_global.on_fail_action := power_down;
													when others => scanport_options_global.on_fail_action := power_down;
												end case;

											when frequency =>
												scanport_options_global.tck_frequency := type_tck_frequency'value(get_field_from_line(line_list,2));
											when trailer_ir =>
												scanport_options_global.trailer_sir := to_binary_class_0 (to_binary (
													get_field_from_line(line_list,2),
													get_field_from_line(line_list,2)'length,
													class_0));
											when trailer_dr =>
												scanport_options_global.trailer_sdr := to_binary_class_0 (to_binary (
													get_field_from_line(line_list,2),
													get_field_from_line(line_list,2)'length,
													class_0));
												
											when voltage_out_port_1 =>
												scanport_1_preliminary.voltage_out := type_voltage_out'value(get_field_from_line(line_list,2));
											when threshold_tdi_port_1 =>
												scanport_1_preliminary.voltage_threshold_tdi := type_threshold_tdi'value(get_field_from_line(line_list,2));
											when tck_driver_port_1 =>
												scanport_1_preliminary.characteristic_tck_driver := type_driver_characteristic'value(get_field_from_line(line_list,2));
											when tms_driver_port_1 =>
												scanport_1_preliminary.characteristic_tms_driver := type_driver_characteristic'value(get_field_from_line(line_list,2));
											when tdo_driver_port_1 =>
												scanport_1_preliminary.characteristic_tdo_driver := type_driver_characteristic'value(get_field_from_line(line_list,2));
											when trst_driver_port_1 =>
												scanport_1_preliminary.characteristic_trst_driver := type_driver_characteristic'value(get_field_from_line(line_list,2));

											when voltage_out_port_2 =>
												scanport_2_preliminary.voltage_out := type_voltage_out'value(get_field_from_line(line_list,2));
											when threshold_tdi_port_2 =>
												scanport_2_preliminary.voltage_threshold_tdi := type_threshold_tdi'value(get_field_from_line(line_list,2));
											when tck_driver_port_2 =>
												scanport_2_preliminary.characteristic_tck_driver := type_driver_characteristic'value(get_field_from_line(line_list,2));
											when tms_driver_port_2 =>
												scanport_2_preliminary.characteristic_tms_driver := type_driver_characteristic'value(get_field_from_line(line_list,2));
											when tdo_driver_port_2 =>
												scanport_2_preliminary.characteristic_tdo_driver := type_driver_characteristic'value(get_field_from_line(line_list,2));
											when trst_driver_port_2 =>
												scanport_2_preliminary.characteristic_trst_driver := type_driver_characteristic'value(get_field_from_line(line_list,2));

										end case;
									end if;
								end if;
								-- read scanpath options end

								-- read scanpaths begin
								if not subsection_scanpath_configuration_scanpath_1_entered then

									-- wait for subsection scanpath 1 header
									if get_field_from_line(line_list,1) = section_mark.subsection and 
										get_field_from_line(line_list,2) = subsection_scanpath_configuration_scanpath and
										get_field_from_line(line_list,3) = trim(type_scanport_id'image(1),left) then
										subsection_scanpath_configuration_scanpath_1_entered := true;

										write_message (
											file_handle => current_output,
											identation => 1,
											text => "scanpath 1 ...", 
											console => true);

										bic_pre_preliminary.position := 1; -- reset bic position counter
									end if;
								else
									if get_field_from_line(line_list,1) = section_mark.endsubsection then 
									-- we are leaving the subsection 
										subsection_scanpath_configuration_scanpath_1_entered := false;
									else -- we are inside the subsection
										-- process line
										put_line("  " & get_field_from_line(line_list,1));
										
										--bic_pre_preliminary.name 		:= to_bounded_string(get_field_from_line(line_list,1));--CS: check if name syntax ok, check if name is used only once
										bic_pre_preliminary.housing		:= to_bounded_string(get_field_from_line(line_list,2));--CS: check if housing exists
										bic_pre_preliminary.model_file	:= to_bounded_string(get_field_from_line(line_list,3));--CS: check if file exists
										bic_pre_preliminary.chain       := 1;
										
										-- collect options in a single string (if there are any)
										if line_list.field_count > 3 then
											for f in 4..positive(line_list.field_count) loop
												bic_pre_preliminary.options := trim(
													bic_pre_preliminary.options & " " &
													to_bounded_string(get_field_from_line(line_list,f)),both);
												--CS: do a detailed options check here !
											end loop;
										end if;

										--append(list_of_bics_pre,bic_pre_preliminary);
										insert(container => list_of_bics_pre, 
											   key => to_bounded_string(get_field_from_line(line_list,1)), -- bic name like "IC303"
											   new_item => bic_pre_preliminary);

										-- purge options for next spin
										bic_pre_preliminary.options		:= to_bounded_string("");

										-- advance bic position counter for next bic
										bic_pre_preliminary.position 	:= bic_pre_preliminary.position + 1; 
									end if;
								end if;

								if not subsection_scanpath_configuration_scanpath_2_entered then
									-- wait for subsection scanpath 1 header
									if get_field_from_line(line_list,1) = section_mark.subsection and 
										get_field_from_line(line_list,2) = subsection_scanpath_configuration_scanpath and
										get_field_from_line(line_list,3) = trim(type_scanport_id'image(2),left) then
										subsection_scanpath_configuration_scanpath_2_entered := true;

										write_message (
											file_handle => current_output,
											identation => 1,
											text => "scanpath 2 ...", 
											console => true);

										bic_pre_preliminary.position := 1; -- reset bic position counter
									end if;
								else
									if get_field_from_line(line_list,1) = section_mark.endsubsection then -- we are leaving the subsection
										subsection_scanpath_configuration_scanpath_2_entered := false;
									else -- we are inside the subsection
										-- process line
										put_line("  " & get_field_from_line(line_list,1));
										
										--bic_pre_preliminary.name 		:= to_bounded_string(get_field_from_line(line_list,1));--CS: check if name syntax ok, check if name is used only once
										bic_pre_preliminary.housing		:= to_bounded_string(get_field_from_line(line_list,2));--CS: check if housing exists
										bic_pre_preliminary.model_file	:= to_bounded_string(get_field_from_line(line_list,3));--CS: check if file exists
										bic_pre_preliminary.chain       := 2;

										-- collect options if there are any
										if line_list.field_count > 3 then
											for f in 4..positive(line_list.field_count) loop
												bic_pre_preliminary.options := bic_pre_preliminary.options & " " &
													to_bounded_string(get_field_from_line(line_list,f));
												--CS: do a detailed options check here !
											end loop;
										end if;

										--append(list_of_bics_pre,bic_pre_preliminary);
										insert(container => list_of_bics_pre, 
											   key => to_bounded_string(get_field_from_line(line_list,1)), -- bic name like "IC303"
											   new_item => bic_pre_preliminary);


										-- purge options for next spin
										bic_pre_preliminary.options		:= to_bounded_string("");

										-- advance bic position counter for next bic
										bic_pre_preliminary.position 	:= bic_pre_preliminary.position + 1;
									end if;
								end if;
								-- read scanpaths end
							end if;
						end if;
						-- read scanpath configuration end

						-- read registers begin
						if not section_registers_entered then
							-- wait for section registers header
							if get_field_from_line(line_list,1) = section_mark.section and get_field_from_line(line_list,2) = section_registers then
								section_registers_entered := true;
								write_message (
									file_handle => current_output,
									text => "reading registers, ports and pins ...", 
									console => true);
							end if;
						else
							if get_field_from_line(line_list,1) = section_mark.endsection then 
							-- we are leaving the section registers
								section_registers_entered := false;
								summary.sections_processed.section_registers := true; -- mark section as processed
								summary.line_number_end_of_section_registers := line_counter; -- save line number in summary

								-- We finish here if we are making nets
								if action = mknets then
									exit loop_read_database;
								end if;

								-- We finish here if we are generating an infrastructure test.
								if action = generate and test_profile = infrastructure then
									exit loop_read_database;
								end if;

								-- We finish here if we are compiling
								if action = compile then
									exit loop_read_database;
								end if;

								
							else -- we are inside the section registers

								-- read bic registers begin
								if not subsection_bic_entered then
									-- wait for subsection bic_name
									if get_field_from_line(line_list,1) = section_mark.subsection then
										-- read bic name and check if it is valid
										bic_name_preliminary := to_bounded_string(get_field_from_line(line_list,2)); 
										if is_bic(bic_name_preliminary) then
											subsection_bic_entered := true;
											write_message (
												file_handle => current_output,
												identation => 1,
												text => to_string(bic_name_preliminary) & " ...", 
												console => true);
										else
											write_message (
												file_handle => current_output,
												text => message_error & to_string(bic_name_preliminary) & " is not part of any scanpath !", 
												console => true);
											raise constraint_error;
										end if;
									end if;
								else -- on leaving this section, we complete the bic data
									if 	get_field_from_line(line_list,1) = section_mark.endsubsection and -- "EndSubSection IC303"
										get_field_from_line(line_list,2) = to_string(bic_name_preliminary) then -- we are leaving the subsection
										subsection_bic_entered := false;
										complete_bic_data (
											name => 			    		bic_name_preliminary,
											value =>                        bic_value_preliminary,
											len_ir =>                       bic_len_ir_preliminary,
											len_bsr =>                      bic_len_bsr_preliminary,
											preliminary_opcodes =>          bic_opcodes_preliminary,				
											ir_capture =>                   bic_capture_ir_preliminary,			
											safebits =>                     bic_safebits_preliminary,			
											bsr_description =>              bic_bsr_description_preliminary,		
											port_io_map =>                  bic_port_io_map_preliminary,			
											port_pin_map =>                 bic_port_pin_map_preliminary,
											idcode_pre =>					bic_idcode_preliminary,
											usercode_pre =>					bic_usercode_preliminary,
											trst_pin =>						bic_trst_pin_preliminary
											);

										-- purge temporarily used lists
										delete(bic_bsr_description_preliminary,1,length(bic_bsr_description_preliminary));
										delete(bic_port_pin_map_preliminary,1,length(bic_port_pin_map_preliminary));
										delete(bic_port_io_map_preliminary,1,length(bic_port_io_map_preliminary));

									else -- we are inside the subsection bic_name -- subsection IC300

										-- As long as no further subsection has been entered, we read things like:
										
		-- 								value sn74bct8240a
		-- 								instruction_register_length 8
		-- 								instruction_capture 10000001
		-- 								idcode_register none
		-- 								usercode_register none
		-- 								boundary_register_length 18

										if not (subsection_safebits_entered or
												subsection_opcodes_entered or
												subsection_boundary_register_entered or
												subsection_port_io_map_entered or
												subsection_port_pin_map_entered) then -- no further subsection entered yet

											-- wait for keywords
											-- A special keyword is "subsection" which indicates a subsection like "safebits, opcodes, .."
											case type_register_keywords'value(get_field_from_line(line_list,1)) is
												when value => 
													bic_value_preliminary := to_bounded_string(get_field_from_line(line_list,2));
												when instruction_register_length =>
													bic_len_ir_preliminary := type_register_length'value(get_field_from_line(line_list,2));
												when instruction_capture =>
													bic_capture_ir_preliminary := to_bounded_string(get_field_from_line(line_list,2));
												when boundary_register_length =>
													bic_len_bsr_preliminary := type_register_length'value(get_field_from_line(line_list,2));
												when idcode_register =>
													if get_field_from_line(line_list,2) = register_not_available then
														bic_idcode_preliminary := to_bounded_string("");
													else
														bic_idcode_preliminary := to_bounded_string(get_field_from_line(line_list,2));
													end if;
												when usercode_register =>
													if get_field_from_line(line_list,2) = register_not_available then
														bic_usercode_preliminary := to_bounded_string("");
													else
														bic_usercode_preliminary := to_bounded_string(get_field_from_line(line_list,2));
													end if;
												when trst_pin =>
													bic_trst_pin_preliminary := type_trst_availability'value(get_field_from_line(line_list,2));
													
												when subsection => -- the keyword in field 2 tells us which subsection is up next
													-- The correspondig flag like "subsection_safebits_entered" or "subsection_opcodes_entered"
													-- is set accordingly.
													case type_register_subsection'value(get_field_from_line(line_list,2)) is
														when safebits => 
															subsection_safebits_entered := true;
																write_message (
																	file_handle => current_output,
																	identation => 2,
																	text => "safebits ...", 
																	console => false);

														when instruction_opcodes =>
															subsection_opcodes_entered := true;
																write_message (
																	file_handle => current_output,
																	identation => 2,
																	text => "opcodes ...", 
																	console => false);
															
														when boundary_register =>
															subsection_boundary_register_entered := true;
																write_message (
																	file_handle => current_output,
																	identation => 2,
																	text => "boundary register ...", 
																	console => false);

														when port_io_map =>
															subsection_port_io_map_entered := true;
																write_message (
																	file_handle => current_output,
																	identation => 2,
																	text => "port io map ...", 
																	console => false);

														when port_pin_map =>
															subsection_port_pin_map_entered := true;
																write_message (
																	file_handle => current_output,
																	identation => 2,
																	text => "port pin map ...", 
																	console => false);
													end case;
											end case;
										else -- we are inside a subsection like "safebits, opcodes, boundary register, ..."
											
											-- When passing the footer of a subsection clear all subsection-entered flags,
											-- otherwise process line of subsection.
											if get_field_from_line(line_list,1) = section_mark.endsubsection then
												subsection_safebits_entered 			:= false; -- we are leaving a subsection
												subsection_opcodes_entered				:= false;		
												subsection_boundary_register_entered	:= false;
												subsection_port_io_map_entered			:= false;
												subsection_port_pin_map_entered			:= false;
											else
		-- 										put_line(to_string(line));
												
												if subsection_safebits_entered then
													case type_safebits_keywords'value(get_field_from_line(line_list,1)) is
														when safebits =>
															bic_safebits_preliminary := to_bounded_string(get_field_from_line(line_list,2));
														when total =>
															-- CS: this check assumes bic_len_bsr_preliminary has been read earlier
															if type_register_length'value(get_field_from_line(line_list,2)) /= bic_len_bsr_preliminary then
																write_message (
																	file_handle => current_output,
																	identation => 2,
																	text => message_error & "Value of 'safebits total' differs from boundary register length !", 
																	console => false);
																raise constraint_error;
															end if;
													end case;
												end if;

												if subsection_opcodes_entered then
												-- 											read_opcode(to_string(line),bic_len_ir_preliminary);
													read_opcode(line_list,bic_len_ir_preliminary);
												end if;

												if subsection_boundary_register_entered then
													--read_boundary_register(to_string(line));
													read_boundary_register(line_list);
												end if;

												if subsection_port_io_map_entered then
													--read_port_io_map(to_string(line));
													read_port_io_map(line_list);
												end if;

												if subsection_port_pin_map_entered then
												-- read_port_pin_map(to_string(line));
													read_port_pin_map(line_list);
												end if;
											end if;
											
										end if;
										-- read safebits end
									end if;
								end if;
								-- read bic registers end
								
							end if;
						end if;
						-- read registers end

				case action is
					when mkoptions | chkpsn | generate | udbinfo =>
						-- read netlist begin
						if not section_netlist_entered then
							if get_field_from_line(line_list,1) = section_mark.section and
							get_field_from_line(line_list,2) = section_netlist then
								section_netlist_entered := true;
								write_message (
									file_handle => current_output,
									text => "reading netlist ...", 
									console => true);
							end if;
						else
							if get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section netlist
								section_netlist_entered := false; 
								summary.sections_processed.section_netlist := true; -- mark this section as processed
								summary.line_number_end_of_section_netlist := line_counter; -- save line number in summary

								new_line(standard_output); -- finishes progress bar/display
								
								-- if we are doing chkpsn or mkoptions we can sefely exit here.
								if action = chkpsn or action = mkoptions then
									exit loop_read_database;
								end if;
								
							else -- we are inside section netlist
								
								-- read net begin
								if not subsection_net_entered then
									-- wait for header of a net. example: "SubSection LED0 class NA"
									if get_field_from_line(line_list,1) = section_mark.subsection and -- SubSection D2 class NA
									get_field_from_line(line_list,2) /= netlist_keyword_header_secondary_nets and
									get_field_from_line(line_list,3) = netlist_keyword_header_class then

										net_name_preliminary := to_bounded_string(get_field_from_line(line_list,2));
										net_class_preliminary := type_net_class'value(get_field_from_line(line_list,4));

										write_message (
											file_handle => current_output,
											identation => 1,
											text => "net " & to_string(net_name_preliminary) &
												" class " & type_net_class'image(net_class_preliminary),
											console => false);
									
									-- If this is a secondary net, make sure it is in same class as its parent net.
									-- Then add name to list of secondary nets.
										if net_level_entered = secondary then
											if current_primary_net_class = net_class_preliminary then
												append(list_of_secondary_net_names_preliminary,net_name_preliminary);
											else
												write_message (
													file_handle => current_output,
													text => message_error & "Class of secondary net does not match class of superordinated primary net !",
													console => false);
													
												write_message (
													file_handle => current_output,
													text => "Secondary nets inherit the class of their parent nets.",
													console => false);

												raise constraint_error;
											end if;
										end if;
									
										subsection_net_entered := true;
									end if;
									
								else -- we are inside a net
									if get_field_from_line(line_list,1) = section_mark.endsubsection then
										subsection_net_entered := false; -- we are leaving a net

										-- check number of pins found in net
										case length(pin_list_preliminary) is
											when 0 =>
												write_message (
													file_handle => current_output,
													text => message_error & "No pins found in net '" & to_string(net_name_preliminary) & "' !",
													console => true);
												raise constraint_error;
											when 1 =>
												write_message (
													file_handle => current_output,
													text => message_warning & "Only one pin in net '" & to_string(net_name_preliminary) & "' !",
													console => false);
											when others =>
												null;
										end case;

										-- complete net
										case net_level_entered is
											when primary =>
												complete_net_data ( 
													name => net_name_preliminary,
													class => net_class_preliminary,
													pinlist => pin_list_preliminary,
													level => net_level_entered,
													secondary_net_names => list_of_secondary_net_names_preliminary,
													net_counter => net_counter
													);
												
											when secondary =>
												complete_net_data ( 
													name => net_name_preliminary,
													name_of_primary_net => current_primary_net_name,
													class => net_class_preliminary,
													pinlist => pin_list_preliminary,
													level => net_level_entered,
													net_counter => net_counter
													);
										end case;

										-- purge pinlist for next net
										--delete(pin_list_preliminary,1,length(pin_list_preliminary));
										pin_list_preliminary := empty_pin_list;
									else
		-- 								-- read line like "RN401 NA 8x10k SIL9 4"

										case line_list.field_count is
											when 5 => -- is is a non-bscan pin. example "RN401 NA 8x10k SIL9 4"
												append(pin_list_preliminary, ( 
													is_bscan_capable 	=> false,
													device_name 		=> to_bounded_string(get_field_from_line(line_list,1)),
													device_class 		=> type_device_class'value(get_field_from_line(line_list,2)),
													device_value		=> to_bounded_string(get_field_from_line(line_list,3)),
													device_package 		=> to_bounded_string(get_field_from_line(line_list,4)),
													device_pin_name 	=> to_bounded_string(get_field_from_line(line_list,5)),
													device_port_name	=> to_bounded_string("") -- no port name provided
													));
													
											when 6 => -- it is a linkage pin of a bic. example: "IC301 NA XC9536 PLCC-S44 2 tms"
												append(pin_list_preliminary, (
													is_bscan_capable 	=> false,
													device_name 		=> to_bounded_string(get_field_from_line(line_list,1)),
													device_class 		=> type_device_class'value(get_field_from_line(line_list,2)),
													device_value		=> to_bounded_string(get_field_from_line(line_list,3)),
													device_package 		=> to_bounded_string(get_field_from_line(line_list,4)),
													device_pin_name 	=> to_bounded_string(get_field_from_line(line_list,5)),
													device_port_name	=> to_bounded_string(get_field_from_line(line_list,6))
													));

											when 7..19 => -- bscan pin. example: "IC301 NA XC9536 PLCC-S44 2  pb00_00 | 107 bc_1 input x | 106 bc_1 output3 x 105 0 z" )
												append(pin_list_preliminary, (	
													is_bscan_capable 	=> true,
													device_name 		=> to_bounded_string(get_field_from_line(line_list,1)),
													device_class 		=> type_device_class'value(get_field_from_line(line_list,2)),
													device_value		=> to_bounded_string(get_field_from_line(line_list,3)),
													device_package 		=> to_bounded_string(get_field_from_line(line_list,4)),
													device_pin_name 	=> to_bounded_string(get_field_from_line(line_list,5)),
													device_port_name	=> to_bounded_string(get_field_from_line(line_list,6)),
													cell_info 			=> build_cell_info(
																			line 			=> line_list, 
																			line_counter	=> line_counter)
													));

											when others => 
												write_message (
													file_handle => current_output,
													text => message_error & "Too many fields found in line !",
													console => false);
												raise constraint_error;
										end case;
										
									end if;
										
								end if;
								-- read net end

								-- Set flag net_level_entered.
								-- CS: We assume a primary net has been processed before.
								case net_level_entered is
									when primary =>
										-- wait for header of subsection secondary nets. example: "SubSection secondary_nets_of LED0"
										if 	get_field_from_line(line_list,1) = section_mark.subsection and
											get_field_from_line(line_list,2) = netlist_keyword_header_secondary_nets then

											if get_field_from_line(line_list,3) = to_string(net_name_preliminary) then
												-- Save name of primary net. Required later when adding secondary nets to the netlist.
												current_primary_net_name := net_name_preliminary; 
												current_primary_net_class := net_class_preliminary;
												net_level_entered := secondary;
											else
												write_message (
													file_handle => current_output,
													text => message_error & "Expected name of superordinated primary net " 
														& to_string(net_name_preliminary) & " !",
													console => false);
												raise constraint_error;
											end if;

											-- CS: check field count (should be 3)
										end if;

									when secondary =>
										-- Wait for footer of subsection secondary nets. example: "EndSubSection secondary_nets_of LED0".
										-- This takes us back to the primary net level.
										-- Purge list_of_secondary_net_names_preliminary for next spin.
										if 	get_field_from_line(line_list,1) = section_mark.endsubsection and
											get_field_from_line(line_list,2) = netlist_keyword_header_secondary_nets then

											if get_field_from_line(line_list,3) = to_string(current_primary_net_name) then
												net_level_entered := primary;
												delete(list_of_secondary_net_names_preliminary,1, length(list_of_secondary_net_names_preliminary));
											else
												write_message (
													file_handle => current_output,
													text => message_error & "Expected name of superordinated primary net " 
														& to_string(current_primary_net_name) & " !",
													console => false);
												raise constraint_error;
											end if;

											-- CS: check field count (should be 3)
										end if;
								end case;
							end if;
						end if;
						-- read netlist end

						-- read statistics begin
						if not section_statistics_entered then
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_statistics then
								section_statistics_entered := true;
								put_line(" reading " & section_statistics & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_statistics_entered := false;
								summary.sections_processed.section_statistics := true; -- mark this section as processed
							else
								-- process line
								--process_line_of_statistic(line_list);
								null;
							end if;
						end if;
						-- read statistics end

						-- read cell lists begin
						-- the cell lists are parsed separately for class, level, net name, device, pin, input/output/control cell status
						-- the cell status locked after-wards in the cell info of the individual pin

						if not section_static_control_cells_class_EX_NA_entered then
						-- this section addresses primary and secondary nets
						-- example: "class NA secondary_net LED0_R device IC301 pin 2 control_cell 105 locked_to disable_value 0"
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_static_control_cells_class_EX_NA then
								section_static_control_cells_class_EX_NA_entered := true;
								put_line(" reading " & section_static_control_cells_class_EX_NA & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_static_control_cells_class_EX_NA_entered := false;
								summary.sections_processed.section_static_control_cells_class_EX_NA := true; -- mark this section as processed
							else
								-- process line
								-- 						process_static_control_cell_class_EX_NA(to_string(line));
								process_static_control_cell_class_EX_NA(line_list);
							end if;
						end if;

						if not section_static_control_cells_class_DX_NR_entered then
						-- this section addresses primary and secondary nets
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_static_control_cells_class_DX_NR then
								section_static_control_cells_class_DX_NR_entered := true;
								put_line(" reading " & section_static_control_cells_class_DX_NR & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_static_control_cells_class_DX_NR_entered := false;
								summary.sections_processed.section_static_control_cells_class_DX_NR := true; -- mark this section as processed
							else
								-- process line
								-- 						process_static_control_cell_class_DX_NR(to_string(line));
								process_static_control_cell_class_DX_NR(line_list);
							end if;
						end if;

						if not section_static_control_cells_class_PX_entered then
						-- this section addresses primary and secondary nets
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_static_control_cells_class_PX then
								section_static_control_cells_class_PX_entered := true;
								put_line(" reading " & section_static_control_cells_class_PX & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_static_control_cells_class_PX_entered := false;
								summary.sections_processed.section_static_control_cells_class_PX := true; -- mark this section as processed
							else
								-- process line
		-- 						process_static_control_cell_class_PX(to_string(line));
								process_static_control_cell_class_PX(line_list);
							end if;
						end if;

						if not section_static_output_cells_class_PX_entered then
						-- this section addresses primary nets only
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_static_output_cells_class_PX then
								section_static_output_cells_class_PX_entered := true;
								put_line(" reading " & section_static_output_cells_class_PX & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_static_output_cells_class_PX_entered := false;
								summary.sections_processed.section_static_output_cells_class_PX := true; -- mark this section as processed
							else
								-- process line
		-- 						process_static_output_cell_class_PX(to_string(line));
								process_static_output_cell_class_PX(line_list);
							end if;
						end if;

						if not section_static_output_cells_class_DX_NR_entered then
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_static_output_cells_class_DX_NR then
								section_static_output_cells_class_DX_NR_entered := true;
								put_line(" reading " & section_static_control_cells_class_DX_NR & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_static_output_cells_class_DX_NR_entered := false;
								summary.sections_processed.section_static_output_cells_class_PX := true; -- mark this section as processed
							else
								-- process line
								-- 						process_static_output_cell_class_DX_NR(to_string(line));
								process_static_output_cell_class_DX_NR(line_list);	
							end if;
						end if;

						if not section_static_expect_entered then
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_static_expect then
								section_static_expect_entered := true;
								put_line(" reading " & section_static_expect & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_static_expect_entered := false;
								summary.sections_processed.section_static_expect := true; -- mark this section as processed
							else
								-- process line
		-- 						process_static_expect_cell(to_string(line));
								process_static_expect_cell(line_list);
							end if;
						end if;

						if not section_atg_expect_entered then
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_atg_expect then
								section_atg_expect_entered := true;
								put_line(" reading " & section_atg_expect & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_atg_expect_entered := false;
								summary.sections_processed.section_atg_expect := true; -- mark this section as processed
							else
								-- process line
								-- 						process_atg_expect_cell(to_string(line));
								process_atg_expect_cell(line_list);
							end if;
						end if;

						if not section_atg_drive_entered then
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_atg_drive then
								section_atg_drive_entered := true;
								put_line(" reading " & section_atg_drive & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_atg_drive_entered := false;
								summary.sections_processed.section_atg_drive := true; -- mark this section as processed
							else
								-- process line
		-- 						process_atg_drive_cell(to_string(line));
								process_atg_drive_cell(line_list);
							end if;
						end if;

						if not section_input_cells_in_class_NA_nets_entered then
							-- wait for section header
							if 	get_field_from_line(line_list,1) = section_mark.section and 
								get_field_from_line(line_list,2) = section_input_cells_class_NA then
								section_input_cells_in_class_NA_nets_entered := true;
								put_line(" reading " & section_input_cells_class_NA & " ...");
							end if;
						else
							if 	get_field_from_line(line_list,1) = section_mark.endsection then -- we are leaving the section
								section_input_cells_in_class_NA_nets_entered := false;
								summary.sections_processed.section_input_cells_class_NA := true; -- mark this section as processed
							else
								-- process line
								-- 						process_input_cell_class_NA(to_string(line));
								process_input_cell_class_NA(line_list);
							end if;
						end if;
						-- read cell lists end

					when others => null;
				end case;	
					
			end if; -- if line contains anything
		end loop loop_read_database; -- end_of_file
		close(file_database);

		case action is
			when mkoptions | chkpsn =>
				verify_net_classes;

				-- If the database is complete, check if there are cells that do not appear in cell lists.
				--  1. After chkpsn, this check is performed on the preliminary database.
				--  2. For other units that read the database, this is just a formal matter. 
				--     In case someone messed around in the database the check is useful.
				if summary.sections_processed.section_registers
					and summary.sections_processed.section_netlist
					and summary.sections_processed.section_static_control_cells_class_EX_NA 
					and summary.sections_processed.section_static_control_cells_class_DX_NR
					and summary.sections_processed.section_static_control_cells_class_PX
					and summary.sections_processed.section_static_output_cells_class_PX
					and summary.sections_processed.section_static_output_cells_class_DX_NR
					and summary.sections_processed.section_static_expect
					and summary.sections_processed.section_atg_expect
					and summary.sections_processed.section_atg_drive
					and summary.sections_processed.section_input_cells_class_NA then
						check_cells_are_in_cell_list; -- works only if cell lists are there
						--verify_shared_control_cells; -- find and check shared control cells
				end if;

				verify_shared_control_cells; -- find and check shared control cells
				make_shared_control_cell_journal;

				-- complete summary begin
		-- 		summary.scanport_ct := type_scanport_id(length(list_of_scanports));
				
-- 				if length(list_of_bics) > 0 then
-- 					summary.bic_ct := positive(length(list_of_bics));
-- 				end if;
				-- complete summary end

			when compile =>
				mark_active_scanport;
			
			when others => null;
		end case;
			

		exception when event: others =>
			if is_open(file_database) then
				close(file_database);
			end if;
				
			write_message (
				file_handle => current_output,
				text => message_error & "in " & text_identifier_database & " line" & natural'image(line_counter),
				console => false);

			raise;
	end read_uut_database;

    function get_bic (bic_name : in type_device_name.bounded_string) return type_bscan_ic is
    -- returns a full bic as type_bscan_ic
    begin
-- 		for b in 1..length(list_of_bics) loop    
-- 			if element(list_of_bics,positive(b)).name = bic_name then
-- 				return element(list_of_bics,positive(b));
-- 			end if;
-- 		end loop;
-- 
-- 		write_message (
-- 			file_handle => current_output,
-- 			text => message_error & "device " & to_string(bic_name) & " is not part of any scanpath !",
-- 			console => false);
-- 		raise constraint_error;

		return element(list_of_bics, bic_name);
    end get_bic;
    
	function occurences_of_pin (
	-- Returns the number of occurences of a device pin in the database netlist.
		device_name				: in type_device_name.bounded_string; 	-- the device name
		pin_name				: in type_pin_name.bounded_string;		-- the pin name
		quit_on_first_occurence	: in boolean := true					-- return after first occurence
		) return natural is

		net			: type_net;
		pin			: type_pin_base;
		occurences	: natural := 0;

		net_cursor : type_list_of_nets.cursor := first(list_of_nets);
	begin
		loop_netlist:
		--for i in 1..length(list_of_nets) loop
		while net_cursor /= type_list_of_nets.no_element loop
			--net := element(list_of_nets, positive(i)); -- load a net
			net := element(net_cursor); -- load a net
			for i in 1..length(net.pins) loop
				pin := type_pin_base(element(net.pins, positive(i))); -- load a pin

				-- test if device name and pin name match
				if pin.device_name = device_name and pin.device_pin_name = pin_name then
					occurences := occurences + 1;

					-- exit on first occurence if required
					if quit_on_first_occurence then
						exit loop_netlist;
					end if;
					
				end if;
			end loop;
			next(net_cursor);	
		end loop loop_netlist;

		return occurences;
	end occurences_of_pin;
	
	
end m1_database;

