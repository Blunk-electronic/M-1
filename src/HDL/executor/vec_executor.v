	reg [7:0] vec_state_1;
	//reg [7:0] vec_state_2;	
	always @(posedge clk) //update vec_state on posedge clk
		begin
			if (!init | !reset)
				begin
					vec_state_1 <= sxr_idle;
				end
			else 
			if (!go_sxr)
				begin
					case (sxr_type)
						sdr_default, sir_default	:	vec_state_1 <= chk_chain_state; 	// CCh  //add further sxr types to case
						//sir_default	:	vec_state <= sir_default_a; 		// 81h
						default		:	vec_state_1 <= sxr_unknown; 			// FEh
					endcase
				end
			else 
				begin
					case (vec_state_1)
						chk_chain_state	:	begin
														case (chain_1_state) // where we are ?
															test_logic_reset	:	vec_state_1 <= tms_down;	// D1h
															run_test_idle		:	vec_state_1 <= tms_up;		// D3h
															select_dr_scan		:	begin
																							if (sxr_type == sdr_default) vec_state_1 <= tms_down;
																							else vec_state_1 <= tms_up;
																						end
															select_ir_scan		:	begin
																							if (sxr_type == sir_default) vec_state_1 <= tms_down;
																							else vec_state_1 <= vec_error;
																						end
															capture_dr			:	begin
																							if (sxr_type == sdr_default) vec_state_1 <= tms_down;
																							else vec_state_1 <= vec_error;
																						end
															capture_ir			:	begin
																							if (sxr_type == sir_default) vec_state_1 <= tms_down;
																							else vec_state_1 <= vec_error;
																						end
															shift_ir				:	begin
																							vec_state_1 <= tms_down;
																						end
															default				:	vec_state_1 <= vec_error;	// E0h
														endcase
													end
														
						tms_down, tms_up		:	vec_state_1 <= tck_up;			   // C1h
						tck_up					:	vec_state_1 <= chk_chain_state;	// C0h
						
						//sdr_default_d	:	vec_state_1 <= sxr_segment_request_a; // C0h

						//sir_default_a	:	vec_state_1 <= sir_default_b;	// 82h
						//sir_default_b	:	vec_state_1 <= sir_default_c;	// 83h
						//sir_default_c	:	vec_state_1 <= sir_default_d;	// 84h
						//sir_default_d	:	vec_state_1 <= sxr_segment_request_a; // C0h
						
						sxr_segment_request_a	: 	vec_state_1 <= sxr_segment_request_b; // C1h
						sxr_segment_request_b	:	vec_state_1 <= sxr_idle; // 00h
					endcase
				end
		end

					