`timescale 1ns / 1ps

module tap_controller(
		// inputs
		reset,
		start,
		chain_ct,
		exec_state,
		//clk_cpu,
		clk,
		sxr_type,
		sxr_length_chain_1,
		sxr_length_chain_2,
		//byte_ct_chain_1,
		//byte_ct_chain_2,		
		end_of_sir_state,
		end_of_sdr_state,
		tck_frequency,
		pwr_off_on_bit_fail,
		pwr_off_on_vector_fail,
		low_level_cmd,
		drv_chain_1,
		drv_chain_2,
		mask_chain_1,
		mask_chain_2,
		exp_chain_1,
		exp_chain_2,
		tdi_1,
		tdi_2,
		go_step,
		mode,

		//outputs
		tap_ready,
		tck_1,
		tck_2,
		tms_1,
		tms_2,
		tdo_1,
		tdo_2,
		trst_1,
		trst_2,
		mask_1,
		mask_2,
		exp_1,
		exp_2,		
		
		fail_1,
		fail_2,
		
		// DEBUG
		chain_1_state,
		chain_2_state,
		bits_processed_chain_1,
		bits_processed_chain_2
		
	);

	// inputs
	input reset;
	input start;
	input [7:0] chain_ct;
	input [7:0] exec_state;
	input clk;
	input [7:0] sxr_type;  //CS: applies for all chains (taken from chain 1, sxr_types of chain_2 ignored)
	input [31:0] sxr_length_chain_1;
	input [31:0] sxr_length_chain_2;
	input [7:0] end_of_sir_state;
	input [7:0] end_of_sdr_state;
	input [7:0] tck_frequency;
	input [7:0] pwr_off_on_bit_fail;
	input [7:0] pwr_off_on_vector_fail;
	input [7:0] low_level_cmd;
	input [7:0] drv_chain_1;
	input [7:0] drv_chain_2;
	input [7:0] mask_chain_1;
	input [7:0] mask_chain_2;
	input [7:0] exp_chain_1;
	input [7:0] exp_chain_2;
	input tdi_1;
	input tdi_2;
	input go_step;
	input [3:0] mode; //defines step width

	//outputs
	output reg tap_ready;
	output reg tck_1;
	output reg tck_2;
	output reg tms_1;
	output reg tms_2;
	output tdo_1;
	output tdo_2;
	output reg trst_1;
	output reg trst_2;
	output fail_1;
	output fail_2;
	output mask_1;
	output mask_2;
	output exp_1;
	output exp_2;	
	
	//DEBUG
	output reg [3:0] chain_1_state;
	output reg [3:0] chain_2_state;	

	`include "parameters.v"
	

	output reg [31:0] bits_processed_chain_1;
	output reg [31:0] bits_processed_chain_2;
	
//// EXECUTOR STATE EVAL ////////////////////////////////////////

	reg init;
	always @(negedge clk)
		begin
			if (exec_state == idle | exec_state == test_start) init <= 0;
				else init <= 1;
		end


	reg ex_llc;
	always @(negedge clk)
		begin
			if (exec_state == test_fetch_low_level_cmd_done) ex_llc <= 0;
				else ex_llc <= 1;
		end


	reg ex_sxr;
	always @(negedge clk)
		begin
			if (exec_state == test_vector_segments_ready) ex_sxr <= 0;
				else ex_sxr <= 1;
		end
	

// LOW LEVEL CMD EXECUTION ///////////////////////


	// shrink ex_llc signal to one clk cycle	
	pulse_maker pm_go_llc(
		.clk(clk),
		.reset(reset),
		.in(ex_llc), // L active
		.out(go_llc) // L active , updated on negedge of clk
		);	

	reg [7:0] llc_state;
	//reg llc_running;
	always @(posedge clk) //update llc_state on posedge clk
		begin
			if (!init | !reset)
				begin
					llc_state <= llc_idle;
				end
			else 
			if (!go_llc)
				begin
					case (low_level_cmd)
						hs_trst	:	llc_state <= hs_trst_a; 		//01h
						default	:	llc_state <= llc_unknown; 		//FEh
					endcase
				end
			else 
				begin
					case (llc_state)
						hs_trst_a			: 	llc_state <= hs_trst_b;
						hs_trst_b			:	llc_state <= hs_trst_c;
						hs_trst_c			:	llc_state <= hs_trst_d;
						hs_trst_d			:	llc_state <= hs_trst_e;
						hs_trst_e			:	llc_state <= hs_trst_f;
						hs_trst_f			:	llc_state <= hs_trst_g;
						hs_trst_g			:	llc_state <= hs_trst_h;
						hs_trst_h			:	llc_state <= hs_trst_i;
						hs_trst_i			:	llc_state <= hs_trst_j;
						hs_trst_j			:	llc_state <= hs_trst_k;		
						hs_trst_k			:	llc_state <= hs_trst_l;	
						hs_trst_l			:	llc_state <= hs_trst_m;
						hs_trst_m			:	llc_state <= hs_trst_n;	
						hs_trst_n			:	llc_state <= llc_idle;
					endcase
				end
		end


// SXR EXECUTION /////////////////////////////////////////////////////////

	// shrink ex_llc signal to one clk cycle	
	pulse_maker pm_go_sxr(
		.clk(clk),
		.reset(reset),
		.in(ex_sxr), // L active
		.out(go_sxr) // L active , updated on negedge of clk
		);	
		
	//`include "vec_executor.v"
	
	reg [7:0] vec_state_1;
	//reg sxr_1_in_progress;
	//reg [7:0] vec_state_2;	
	always @(posedge clk) //update vec_state on posedge clk
		begin
			if (!init | !reset)
				begin
					vec_state_1 <= sxr_idle;
				end
			else 
		//	if (!go_sxr)
		//		begin
		//			case (sxr_type)
		//				sdr_default, sir_default	:	vec_state_1 <= chk_chain_state; 	// CCh  //add further sxr types to case
		//				//sir_default	:	vec_state <= sir_default_a; 		// 81h
		//				default		:	vec_state_1 <= sxr_unknown; 			// FEh
		//			endcase
		//		end
		//	else 
				begin
					case (vec_state_1)
						chk_chain_state	:	begin
														case (chain_1_state) // where are we ?
															test_logic_reset	:	begin
																							//sxr_1_in_progress <= 1;
																							if (!go_sxr) vec_state_1 <= tms_down;	// C3h
																							else vec_state_1 <= tms_up;
																						end
															run_test_idle		:	begin
																							//sxr_1_in_progress <= 1;
																							if (!go_sxr) vec_state_1 <= tms_up;		// C1h
																						end
															select_dr_scan		:	begin
																							//bits_processed_chain_1 <= -1;
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
															shift_ir,
															shift_dr				:	begin
																						//	bits_processed_chain_1 <= bits_processed_chain_1 + 1;
																							if ((bits_processed_chain_1[2:0] == 3'b111) & (!bits_processed_chain_1[31])) vec_state_1 <= tms_up;
																								else 
																									begin
																										vec_state_1 <= tms_down;
																									end
																						end 
															exit1_ir:				begin
																							if ((sxr_type == sir_default) & (bits_processed_chain_1 + 1 == sxr_length_chain_1)) vec_state_1 <= tms_up;
																								else vec_state_1 <= tms_down;
																						end
															pause_ir				:	vec_state_1 <= tms_up;
															exit2_ir				:	vec_state_1 <= tms_down;
															update_ir			:	begin
																							if (sxr_type == sir_default) vec_state_1 <= tms_down;
																								else vec_state_1 <= tms_up;
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

					
	
	
	
// TAP SIGNALS ////////////////////////////////////////////////////////////
	
	always @(negedge clk) //update tap signals on negedge clk
		begin
			if (vec_state_1 == sxr_idle) // eval llc_state only if no vector exection running !
				begin
					case (llc_state)
						llc_idle		:	begin
												tap_ready <= 1;
												trst_1 	<= 1;
												trst_2 	<= 1;
												tms_1		<= 1;
												tms_2		<= 1;
												tck_1		<= 0;
												tck_2		<= 0;
											end

						hs_trst_a	:	begin
												trst_1 <= 0;
												trst_2 <= 0;
											end
						hs_trst_b	:	begin
												tck_1 <= 1;
												tck_2 <= 1;	//1a
											end
						hs_trst_c	:	begin
												tck_1 <= 0;
												tck_2 <= 0;	//1b
											end
						hs_trst_d	:	begin
												tck_1 <= 1;
												tck_2 <= 1;	//2a
											end
						hs_trst_e	:	begin
												tck_1 <= 0;
												tck_2 <= 0;	//2b
											end
						hs_trst_f	:	begin
												tck_1 <= 1;
												tck_2 <= 1;	//3a
											end
						hs_trst_g	:	begin
												tck_1 <= 0;
												tck_2 <= 0;	//3b
											end
						hs_trst_h	:	begin
												tck_1 <= 1;
												tck_2 <= 1;	//4a
											end
						hs_trst_i	:	begin
												tck_1 <= 0;
												tck_2 <= 0;	//4b
											end
						hs_trst_j	:	begin
												tck_1 <= 1;	
												tck_2 <= 1;	//5a
											end
						hs_trst_k	:	begin
												tck_1 <= 0;
												tck_2 <= 0;	//5b
											end
						hs_trst_l	:	begin
												trst_1 <= 1;
												trst_2 <= 1;
											end
						hs_trst_m	:	tap_ready <= 0;
						hs_trst_n	:	tap_ready <= 1;
					endcase
				end	
				else
				begin
					case (vec_state_1)
						// CS: add state sxr_idle ?
						tck_up			:	begin		// D0
													tck_1 <= 1;
													//tck_2 <= 1;
												end
												
						tms_down			:	begin		// D1
													tck_1 <= 0;
													//tck_2 <= 0;
													tms_1 <= 0;
												end
						//tms_2_down		:	begin    // D2
						//							tck_1 <= 0;
													//tck_2 <= 0;
													//tms_2 <= 0;
						//						end		
						tms_up  			:	begin		// D3
													tck_1 <= 0;
								//					tck_2 <= 0;
													tms_1 <= 1;
												end
						chk_chain_state:	begin
													case (chain_1_state)
														shift_ir,
														shift_dr			:	bits_processed_chain_1 <= bits_processed_chain_1 + 1;
														select_dr_scan	:	bits_processed_chain_1 <= -1;
														//update_ir		:	tap_ready <= 0;
													endcase
												end		
						//tms_all_up  	:	begin    // D5
						//							tck_1 <= 0;
						//							tck_2 <= 0;
						//							tms_1 <= 1;
						//							tms_2 <= 1;
						//						end		
						//tms_all_down  	:	begin    // D6
						//							tck_1 <= 0;
						//							tck_2 <= 0;
						//							tms_1 <= 0;
						//							tms_2 <= 0;
						//						end		

												
						sxr_segment_request_a	:	tap_ready <= 0;
						sxr_segment_request_b	:	tap_ready <= 1;
					endcase
				end
		end
		
//// MUX //////////////////////////////////////////////////////////////

	mux8to1 mux_drv_chain_1(
		.sel(bits_processed_chain_1[2:0]),
		.in(drv_chain_1),
		.out(tdo_1)
	);

	mux8to1 mux_drv_chain_2(
		.sel(bits_processed_chain_2[2:0]),
		.in(drv_chain_2),
		.out(tdo_2)
	);

	mux8to1 mux_exp_chain_1(
		.sel(bits_processed_chain_1[2:0]),
		.in(exp_chain_1),
		.out(exp_1)
	);

	mux8to1 mux_exp_chain_2(
		.sel(bits_processed_chain_2[2:0]),
		.in(exp_chain_2),
		.out(exp_2)
	);

	mux8to1 mux_mask_chain_1(
		.sel(bits_processed_chain_1[2:0]),
		.in(mask_chain_1),
		.out(mask_1)
	);

	mux8to1 mux_mask_chain_2(
		.sel(bits_processed_chain_2[2:0]),
		.in(mask_chain_2),
		.out(mask_2)
	);




///////// monitoring chain 1 /////////////////////////////////////////////////////////

	always @(posedge tck_1)
		begin
			if (!reset | exec_state == idle) chain_1_state <= test_logic_reset;
			else
			case (chain_1_state)
				test_logic_reset	:	begin
												if (tms_1 == 0) chain_1_state <= run_test_idle;
													else chain_1_state <= test_logic_reset;
											end

				run_test_idle		:	begin
												if (tms_1 == 1) chain_1_state <= select_dr_scan;
													else chain_1_state <= run_test_idle;
											end

				select_dr_scan		:	begin
												if (tms_1 == 1) chain_1_state <= select_ir_scan;
													else chain_1_state <= capture_dr;
											end
											
				select_ir_scan		:	begin	//3
												if (tms_1 == 1) chain_1_state <= test_logic_reset;
													else chain_1_state <= capture_ir;
											end
				//DR path
				capture_dr			:	begin
												if (tms_1 == 1) chain_1_state <= exit1_dr;
													else chain_1_state <= shift_dr;
											end

				shift_dr				:	begin
												if (tms_1 == 1) chain_1_state <= exit1_dr;
													else chain_1_state <= shift_dr;
											end
											
				exit1_dr				:	begin
												if (tms_1 == 1) chain_1_state <= update_dr;
													else chain_1_state <= pause_dr;
											end

				pause_dr				:	begin
												if (tms_1 == 1) chain_1_state <= exit2_dr;
													else chain_1_state <= pause_dr;
											end

				exit2_dr				:	begin
												if (tms_1 == 1) chain_1_state <= update_dr;
													else chain_1_state <= shift_dr;
											end

				update_dr			:	begin
												if (tms_1 == 1) chain_1_state <= select_dr_scan;
													else chain_1_state <= run_test_idle;
											end

				// IR path
				capture_ir			:	begin
												if (tms_1 == 1) chain_1_state <= exit1_ir;
													else chain_1_state <= shift_ir;
											end

				shift_ir				:	begin
												if (tms_1 == 1) chain_1_state <= exit1_ir;
													else chain_1_state <= shift_ir;
											end
											
				exit1_ir				:	begin
												if (tms_1 == 1) chain_1_state <= update_ir;
													else chain_1_state <= pause_ir;
											end

				pause_ir				:	begin
												if (tms_1 == 1) chain_1_state <= exit2_ir;
													else chain_1_state <= pause_ir;
											end

				exit2_ir				:	begin
												if (tms_1 == 1) chain_1_state <= update_ir;
													else chain_1_state <= shift_ir;
											end

				update_ir			:	begin
												if (tms_1 == 1) chain_1_state <= select_dr_scan;
													else chain_1_state <= run_test_idle;
											end

				default				:	chain_1_state <= test_logic_reset;
			endcase
		end
		
///////// monitoring chain 2 //////////////////////////////////////////////////////////

	always @(posedge tck_2)
		begin
			if (!reset) chain_2_state <= test_logic_reset;
			else
			case (chain_2_state)
				test_logic_reset	:	begin
												if (tms_2 == 0) chain_2_state <= run_test_idle;
													else chain_2_state <= test_logic_reset;
											end

				run_test_idle		:	begin
												if (tms_2 == 1) chain_2_state <= select_dr_scan;
													else chain_2_state <= run_test_idle;
											end

				select_dr_scan		:	begin
												if (tms_2 == 1) chain_2_state <= select_ir_scan;
													else chain_2_state <= capture_dr;
											end
											
				select_ir_scan		:	begin	//3
												if (tms_2 == 1) chain_2_state <= test_logic_reset;
													else chain_2_state <= capture_ir;
											end
				//DR path
				capture_dr			:	begin
												if (tms_2 == 1) chain_2_state <= exit1_dr;
													else chain_2_state <= shift_dr;
											end

				shift_dr				:	begin
												if (tms_2 == 1) chain_2_state <= exit1_dr;
													else chain_2_state <= shift_dr;
											end
											
				exit1_dr				:	begin
												if (tms_2 == 1) chain_2_state <= update_dr;
													else chain_2_state <= pause_dr;
											end

				pause_dr				:	begin
												if (tms_2 == 1) chain_2_state <= exit2_dr;
													else chain_2_state <= pause_dr;
											end

				exit2_dr				:	begin
												if (tms_2 == 1) chain_2_state <= update_dr;
													else chain_2_state <= shift_dr;
											end

				update_dr			:	begin
												if (tms_2 == 1) chain_2_state <= select_dr_scan;
													else chain_2_state <= run_test_idle;
											end

				// IR path
				capture_ir			:	begin
												if (tms_2 == 1) chain_2_state <= exit1_ir;
													else chain_2_state <= shift_ir;
											end

				shift_ir				:	begin
												if (tms_2 == 1) chain_2_state <= exit1_ir;
													else chain_2_state <= shift_ir;
											end
											
				exit1_ir				:	begin
												if (tms_2 == 1) chain_2_state <= update_ir;
													else chain_2_state <= pause_ir;
											end

				pause_ir				:	begin
												if (tms_2 == 1) chain_2_state <= exit2_ir;
													else chain_2_state <= pause_ir;
											end

				exit2_ir				:	begin
												if (tms_2 == 1) chain_2_state <= update_ir;
													else chain_2_state <= shift_ir;
											end

				update_ir			:	begin
												if (tms_2 == 1) chain_2_state <= select_dr_scan;
													else chain_2_state <= run_test_idle;
											end

				default				:	chain_2_state <= test_logic_reset;
			endcase
		end



endmodule