`timescale 1ns / 1ps

// V0.1 :
//			- hstrst on test fail
//			- hstrst extended to 6 tck cycles

// V0.2	:
//			- sxr_type is checked for sxr_default or sxr_on_fail_pwr_off

// V0.3	:
//			- exec_state disabled not used any more

// V0.4	:
//			- Bugfix:  on fail, sxr is to be finished, then abort
//			- Bugfix: pos_fail_bit_1 is loaded with first fail bit position only once

// V0.5	:
//			- output pos_current_or_fail_bit_1 added
//			- if exec_state is test_fail pos_current_or_fail_bit_1 outputs fail bit position, otherwise current bit position

// V0.6	:
//			- sxr_retry supported

// V0.7	:
//			- scanpath commands under construction


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
		llct, //low level command type
		llcc, //low level command itself
		//on_fail_action,
		//tck_frequency,
		//pwr_off_on_bit_fail,
		//pwr_off_on_vector_fail,
		//low_level_cmd,
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
		fail_x,
		
		retry_req, // ins V0.6
		
		// DEBUG
		chain_1_state,
		chain_2_state,
		//bits_processed_chain_1,  // removed V0.5
		bits_processed_chain_2,
		vec_state_1,
		vec_state_2,
		
		//pos_fail_bit_1  // removed V0.5
		pos_current_or_fail_bit_1  // new V0.5
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
	input [7:0] llct;	//CS: applies for all chains
	input [7:0] llcc;	//CS: applies for all chains
	//input [7:0] on_fail_action;
	//input [7:0] tck_frequency;
	//input [7:0] pwr_off_on_bit_fail;
	//input [7:0] pwr_off_on_vector_fail;
	//input [7:0] low_level_cmd;
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
	output tap_ready;
	output reg tck_1;
	output reg tck_2;
	output reg tms_1;
	output reg tms_2;
	output tdo_1;
	output tdo_2;
	output reg trst_1;
	output reg trst_2;
	output reg fail_1;
	output reg fail_2;
	output mask_1;
	output mask_2;
	output exp_1;
	output exp_2;	
	output fail_x;
	//DEBUG
	output reg [3:0] chain_1_state;
	output reg [3:0] chain_2_state;	

	`include "parameters.v"
	

	//output reg [31:0] bits_processed_chain_1; // rm V0.5
	reg [31:0] bits_processed_chain_1; // new V0.5
	
	output reg [31:0] bits_processed_chain_2;
	
	//output reg [31:0] pos_fail_bit_1; // V0.4 // rm V0.5
	reg [31:0] pos_fail_bit_1; // V0.4 // ins V0.5 

	output [31:0] pos_current_or_fail_bit_1; // ins V0.5
	
	output [7:0] vec_state_2;		// CS: remove when 2 chains supported
	assign vec_state_2[7:0] = 8'h00;
	
//// EXECUTOR STATE EVAL ////////////////////////////////////////

	reg init;  // active L on test start
	always @(negedge clk)
		begin
//			if (exec_state == disabled | exec_state == idle | exec_state == test_start | exec_state == test_fetch_low_level_cmd | exec_state == test_fail) init <= 0; // rm V0.3
//			if (exec_state == idle | exec_state == test_start | exec_state == test_fetch_low_level_cmd | exec_state == test_fail) init <= 0; // ins V0.3 // rm V0.6
			case (exec_state)
				idle,
				test_start,
				//test_fetch_step,		// ins V0.6 to reset fail_x, for sxr_retry relevant only
				test_fetch_low_level_cmd,
				test_fail			: init <= 0;
				default				: init <= 1;
			endcase
		end


	reg ex_llc;
	always @(negedge clk)
		begin		// start low level cmd execution if cmd fetched completely and if type is tap_operation only
			//if ((exec_state == test_fetch_low_level_cmd_done) & (llct == tap_operation)) ex_llc <= 0; # rm V0.1
			if (((exec_state == test_fetch_low_level_cmd_done) | (exec_state == test_fail_hstrst_ready)) & (llct == tap_operation)) ex_llc <= 0; // ins V0.1
				else ex_llc <= 1;
		end

	// shrink ex_llc signal to one clk cycle	
	pulse_maker pm_go_llc(
		.clk(clk),
		.reset(reset),
		.in(ex_llc), // L active
		.out(go_llc) // L active , updated on negedge of clk  //triggers low level command execution
		);	
		
	// build start signal for tap controller
	reg ex_sxr;
	always @(negedge clk)
		begin
			if (exec_state == test_vector_segments_ready) ex_sxr <= 0; //exec 67
				else ex_sxr <= 1;
		end

/*	
	// shrink ex_sxr signal to three clk cycles	
	pulse_maker2 pm_go_sxr(
		.clk(clk),
		.reset(reset),
		.in(ex_sxr), // L active
		.out(go_sxr) // L active , updated on negedge of clk
		);
*/

	// new experimental

	// shrink ex_sxr signal to one clk cycle	
	wire set_go_sxr;
	pulse_maker3 pm_go_sxr(
		.clk(clk),
		.reset(reset),
		.in(ex_sxr), // L active
		.out(set_go_sxr) // L active , updated on posedge of clk
		);

	output reg [7:0] vec_state_1;
	reg go_sxr;
	always @(negedge clk)
		begin
			if (!set_go_sxr) go_sxr <= 0;	//trigger vec_state machine
			
				// vec_state machine acknowledges reception of start signal 
				else if ((vec_state_1 == sxr_idle) | (vec_state_1 == tms_down_rti) | (vec_state_1 == tms_up) | (vec_state_1 == tms_down)) go_sxr <= 1;
					else go_sxr <= go_sxr;
		end

	// new end

// LOW LEVEL CMD EXECUTION ///////////////////////


	reg [7:0] llc_state; // CS: route this reg to rf for debugging
	//reg llc_running;
	always @(posedge clk) //update llc_state on posedge clk
		begin
			if (!init | !reset)
				begin
					llc_state <= llc_idle; // 00
				end
			else 
			if (!go_llc)
				begin
					case (llcc)  // low level command
						hs_trst	:	llc_state <= hs_trst_a; 		//01
						h_trst	:	llc_state <= h_trst_a;			//11 //no TCK or TMS changings
						s_trst	:	llc_state <= hs_trst_b;			//02 (skip hs_trst_a which pulls trst-pins low)
						
						// ins V0.7 begin
						scanpath_reset	:
										begin
											case (chain_1_state)
												test_logic_reset	: 	llc_state <= scanpath_go_from_tlr_to_tlr;	// 37 done
												run_test_idle		:	llc_state <= scanpath_go_from_rti_to_tlr; // 38 done
												pause_dr,
												pause_ir				:	llc_state <= scanpath_go_from_pause_to_tlr;  //39h done
											endcase										
										end
						
						scanpath_idle	:
										begin
											case (chain_1_state)
												test_logic_reset,
												run_test_idle		:	llc_state <= scanpath_go_from_tlr_or_rti_to_idle; // 30h / done verified
												pause_dr,
												pause_ir				:	llc_state <= scanpath_go_from_pause_to_idle;  //31h done
											endcase										
										end
										
						scanpath_drpause	:
										begin
											case (chain_1_state)
												test_logic_reset	:	llc_state <= scanpath_go_from_tlr_to_drpause; // 4Dh done
												run_test_idle		:	llc_state <= scp_5_c; // skip entry rti, then do as scanpath_go_from_tlr_to_drpause done
												pause_dr,			
												pause_ir				:	llc_state <= scanpath_go_from_drpause_to_drpause; // 58 done // NOTE: path from pause_ir is the same
											endcase										
										end
						
						scanpath_irpause	:
										begin
											case (chain_1_state)
												test_logic_reset	:	llc_state <= scanpath_go_from_tlr_to_irpause; // 5F done
												run_test_idle		:	llc_state <= scp_7_c; // skip entry rti, then do as scanpath_go_from_tlr_to_irpause done
												pause_dr,			
												pause_ir				:	llc_state <= scanpath_go_from_irpause_to_irpause; // 66 done // NOTE: path from pause_dr is the same
											endcase										
										end
						
						
						// ins V0.7 end
						
						default	:	llc_state <= llc_unknown; 		//FEh
					endcase
				end
			else 
				begin
					case (llc_state)
					
						// ins V0.7 begin
						scanpath_go_from_tlr_to_tlr			:	llc_state <= scp_0_a; //tms up / 35
						scp_0_a				:	llc_state <= scp_1_b;   // tck up

						scanpath_go_from_rti_to_tlr			:	llc_state <= scp_2_a; // tms up / 3A
						scp_2_a				:	llc_state <= scp_2_b;	// tck up  // 3B  (enter select-dr-scan)
						scp_2_b				:	llc_state <= scp_2_c;	// tck down // 3C
						scp_2_c				:	llc_state <= scp_2_d;	// tcp up  // 3D
						scp_2_d				:	llc_state <= scp_2_e;	// tck down // 3E
						scp_2_e				:	llc_state <= scp_2_f;	// tck up  // 3F
						scp_2_f				:	llc_state <= scp_2_g;	// tck down // 40
						scp_2_g				:	llc_state <= llc_ending_a;	// FC
						
						scanpath_go_from_pause_to_tlr			:	llc_state <= scp_3_a; // tms up 41
						scp_3_a				:	llc_state <= scp_3_b; // tck up 42 // (enter exit2-xr)
						scp_3_b				:	llc_state <= scp_3_c; // tck down 43
						scp_3_c				:	llc_state <= scp_3_d; // tck up 44 // (enter update-xr) 
						scp_3_d				:	llc_state <= scp_3_e; // tck down 45
						scp_3_e				:	llc_state <= scp_2_b; // tck up // 3B (enter select-dr-scan)
						
						scanpath_go_from_pause_to_idle		:	llc_state <= scp_4_a; // tms up 47
						scp_4_a				:	llc_state <= scp_4_b; // tck up 48 (enter exit2-xr)
						scp_4_b				:	llc_state <= scp_4_c; // tck down 49
						scp_4_c				:	llc_state <= scp_4_d; // tck up 4A (enter update-xr)
						scp_4_d				:	llc_state <= scp_4_e; // tck down, tms down // 4B
						scp_4_e				:	llc_state <= scp_2_f; // tck up 3F (enter rti)
						
						scanpath_go_from_tlr_or_rti_to_idle	:	llc_state <= scp_1_a; //tms down
						scp_1_a				:	llc_state <= scp_1_b;   // tck up
						scp_1_b				:	llc_state <= scp_1_c;	// tck down, tms up
						scp_1_c				:	llc_state <= llc_ending_a; // FC
						
						scanpath_go_from_tlr_to_drpause		:	llc_state <= scp_5_a; // tms down
						scp_5_a				:	llc_state <= scp_5_b; // tck up (enter rti)
						scp_5_b				:	llc_state <= scp_5_c; // tck down, tms up
						scp_5_c				:	llc_state <= scp_5_d; // tck up (enter select-dr)
						scp_5_d				:	llc_state <= scp_5_e; // tck down, tms down
						scp_5_e				:	llc_state <= scp_5_f; // tck up (enter capture-dr)
						scp_5_f				:	llc_state <= scp_5_g; // tck down, tms up
						scp_5_g				:	llc_state <= scp_5_h; // tck up (enter exit1-dr)
						scp_5_h				:	llc_state <= scp_5_i; // tck down, tms down
						scp_5_i				:	llc_state <= scp_2_f; // tck up (enter pause-dr)

						scanpath_go_from_drpause_to_drpause	:	llc_state <= scp_6_a; //tms up
						scp_6_a				:	llc_state <= scp_6_b; // tck up (enter exit2-dr)
						scp_6_b				:	llc_state <= scp_6_c; // tck down
						scp_6_c				:	llc_state <= scp_6_d; // tck up (enter update-dr)
						scp_6_d				:	llc_state <= scp_6_e; // tck down
						scp_6_e				:	llc_state <= scp_5_d; // tck up (enter select-dr)
						
						scanpath_go_from_tlr_to_irpause		:	llc_state <= scp_7_a; //tms down
						scp_7_a				:	llc_state <= scp_7_b; // tck up (enter rti)
						scp_7_b				:	llc_state <= scp_7_c; // tck down, tms up
						scp_7_c				:	llc_state <= scp_7_d; // tck up (enter select-dr)
						scp_7_d				:	llc_state <= scp_7_e; // tck down
						scp_7_e				:	llc_state <= scp_5_d; // tck up (enter select-ir)
						
						scanpath_go_from_irpause_to_irpause	:	llc_state <= scp_8_a; //tms up
						scp_8_a				:	llc_state <= scp_8_b; // tck up (enter exit2-ir)
						scp_8_b				:	llc_state <= scp_8_c; // tck down
						scp_8_c				:	llc_state <= scp_8_d; // tck up (enter update-ir)
						scp_8_d				:	llc_state <= scp_8_e; // tck down
						scp_8_e				:	llc_state <= scp_7_d; // tck up (enter select-dr)

						// ins V0.7 end
						
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
						hs_trst_k			:	llc_state <= hs_trst_j1;	

						hs_trst_j1			:	llc_state <= hs_trst_k1;	// sixth clock cycle inserted in V0.1
						hs_trst_k1			:	llc_state <= hs_trst_l;		// because of instable UUT soft trst # CS: why ? 

						hs_trst_l			:	llc_state <= llc_ending_a;
						
						h_trst_a			: 	llc_state <= h_trst_b;
						h_trst_b			:	llc_state <= h_trst_c;
						h_trst_c			:	llc_state <= h_trst_d;
						h_trst_d			:	llc_state <= h_trst_e;
						h_trst_e			:	llc_state <= h_trst_f;
						h_trst_f			:	llc_state <= h_trst_g;
						h_trst_g			:	llc_state <= h_trst_h;
						h_trst_h			:	llc_state <= h_trst_i;
						h_trst_i			:	llc_state <= h_trst_j;
						h_trst_j			:	llc_state <= h_trst_k;		
						h_trst_k			:	llc_state <= h_trst_l;	

						h_trst_l			:	llc_state <= llc_ending_a;

						llc_ending_a		:	llc_state <= llc_ending_b;	
						llc_ending_b		:	llc_state <= llc_idle;

					endcase
				end
		end


// SXR EXECUTION /////////////////////////////////////////////////////////

		
	// build last_bit for shift_xr and exit1_xr only
	reg last_bit_1; //updated on falling edge of clk  (chain_1_state changes on negedge of clk)
	always @*
		begin
			case (chain_1_state)
				shift_ir,
				shift_dr,
				exit1_ir,
				exit1_dr		:	begin
										if (bits_processed_chain_1 + 1 == sxr_length_chain_1) last_bit_1 <= 1;
											else last_bit_1 <= 0;
									end
				default		:	last_bit_1 <= 0;
			endcase
		end
		
	// build fail_1 for shift_xr and exit_xr only //updated on negedge of clk
	always @(negedge clk)
		begin
			if (!init | !reset)
				begin
					fail_1 <= 1;
					//pos_fail_bit_1 <= -1;
				end
			else	
			if (vec_state_1 == tck_up) // C1
				begin
					case (chain_1_state)
						capture_dr,
						capture_ir	:	fail_1 <= 1;	// V0.6
						shift_ir,
						shift_dr		:	begin
											//	if ((exp_1 ^ tdi_1) & mask_1) fail_1 <= 1; // (exp XOR tdi) & mask
												if ((exp_1 ^ tdi_1) & mask_1 & fail_1) // V0.4 - load pos_fail_bit_1 only on first fail - no later updating !
													begin
														fail_1 <= 0; // (exp XOR tdi) & mask
														pos_fail_bit_1 <= bits_processed_chain_1; // V0.4
													end
													else fail_1 <= fail_1;
											end
						default		:	fail_1 <= fail_1;
					endcase
				end
			else fail_1 <= fail_1;
		end
	
	assign pos_current_or_fail_bit_1 = (exec_state == test_fail) ? pos_fail_bit_1 : bits_processed_chain_1;  // ins V0.5
	
	output reg retry_req;
	
	always @(posedge clk) //update vec_state on posedge clk
		begin
			if (!init | !reset)
				begin
					vec_state_1 <= sxr_idle; // 00h
					retry_req <= 1; // ins V0.6
				end
			else 
				begin
					case (vec_state_1)
					
						// on !go_sxr go to select-dr-scan directly, then go to chk_chain_state
						sxr_idle				:	begin
														if (!go_sxr) vec_state_1 <= tms_down_rti;
															else vec_state_1 <= vec_state_1;
													end
						tms_down_rti		:	vec_state_1 <= tck_up_rti;
						tck_up_rti   		:	vec_state_1 <= tms_up_sel_dr;
						tms_up_sel_dr		:	vec_state_1 <= tck_up_sel_dr;  // select-dr-scan reached
						tck_up_sel_dr		:	vec_state_1 <= chk_chain_state;
						
						// check TAP state
						chk_chain_state	:	begin
														case (chain_1_state) // where are we ?
															test_logic_reset	:	vec_state_1 <= tms_down;
															run_test_idle		:	begin  // wait for !go_sxr
																							if (!go_sxr) vec_state_1 <= tms_up;
																								else vec_state_1 <= tms_down;
																						end
															select_dr_scan		:	begin
																							//if (sxr_type == sdr_default | sxr_type == sdr_on_fail_pwr_off | sxr_type == sdr_retry_default) vec_state_1 <= tms_down;
																							//else vec_state_1 <= tms_up;
																							case (sxr_type)
																								sdr_default,
																								sdr_on_fail_pwr_off,
																								sdr_retry_default,
																								sdr_retry_pwr_off		:	vec_state_1 <= tms_down;
																								default					:	vec_state_1 <= tms_up;
																							endcase
																						end
															select_ir_scan		:	begin
																							//if (sxr_type == sir_default | sxr_type == sir_on_fail_pwr_off | sxr_type == sir_retry_default) vec_state_1 <= tms_down;
																							//else vec_state_1 <= vec_error;
																							case (sxr_type)
																								sir_default,
																								sir_on_fail_pwr_off,
																								sir_retry_default,
																								sir_retry_pwr_off		:	vec_state_1 <= tms_down;
																								default					:	vec_state_1 <= vec_error;
																							endcase
																						end
															capture_dr			:	begin
																							retry_req <= 1;	// reset retry-request // ins V0.6
																							//if (sxr_type == sdr_default | sxr_type == sdr_on_fail_pwr_off | sxr_type == sdr_retry_default) vec_state_1 <= tms_down;
																							//else vec_state_1 <= vec_error;
																							case (sxr_type)
																								sdr_default,
																								sdr_on_fail_pwr_off,
																								sdr_retry_default,
																								sdr_retry_pwr_off		:	vec_state_1 <= tms_down;
																								default					:	vec_state_1 <= vec_error;
																							endcase
																						end
															capture_ir			:	begin
																							retry_req <= 1;	// reset retry-request //ins V0.6
																							//if (sxr_type == sir_default | sxr_type == sir_on_fail_pwr_off | sxr_type == sir_retry_default) vec_state_1 <= tms_down;
																							//else vec_state_1 <= vec_error;
																							case (sxr_type)
																								sir_default,
																								sir_on_fail_pwr_off,
																								sir_retry_default,
																								sir_retry_pwr_off		:	vec_state_1 <= tms_down;
																								default					:	vec_state_1 <= vec_error;
																							endcase
																						end
															shift_ir,
															shift_dr				:	begin // start with bit no 0, on 7th bit or last_bit_1, go to exit1-xr
																								// bit 31 of bits_processed must have been cleared.
																								// bits_processed gets incremented on negedge of clk here (see below)
																							if (((bits_processed_chain_1[2:0] == 3'b111) & (!bits_processed_chain_1[31])) | last_bit_1) vec_state_1 <= tms_up;
																								else 
																									begin // else keep cycling in shift-xr
																										vec_state_1 <= tms_down;
																									end
																						end 
															exit1_ir:				begin // if last bit has been processed and if sxr_default, go to update-xr
																							//if ((sxr_type == sir_default | sxr_type == sir_on_fail_pwr_off | sxr_type == sir_retry_default) & last_bit_1) vec_state_1 <= tms_up;
																							//	else vec_state_1 <= tms_down; // else go to pause-xr
																							if (last_bit_1)
																								begin
																									case (sxr_type)
																										sir_default,
																										sir_on_fail_pwr_off,
																										sir_retry_default,
																										sir_retry_pwr_off		:	vec_state_1 <= tms_up;
																										default					:	vec_state_1 <= tms_down;
																									endcase
																								end
																							else vec_state_1 <= tms_down;
																						end
															exit1_dr:				begin // if last bit has been processed and if sxr_default, go to update-xr
																							//if ((sxr_type == sdr_default | sxr_type == sdr_on_fail_pwr_off | sxr_type == sdr_retry_default) & last_bit_1) vec_state_1 <= tms_up;
																							//	else vec_state_1 <= tms_down; // else go to pause-xr
																							if (last_bit_1)
																								begin
																									case (sxr_type)
																										sdr_default,
																										sdr_on_fail_pwr_off,
																										sdr_retry_default,
																										sdr_retry_pwr_off		:	vec_state_1 <= tms_up;
																										default					:	vec_state_1 <= tms_down;
																									endcase
																								end
																							else vec_state_1 <= tms_down;
																						end

															pause_ir				:	begin																								
																							case (sxr_type)
																								sir_default,
																								sir_on_fail_pwr_off,
																								sir_retry_default,
																								sir_retry_pwr_off
																												:	begin
																														if (!go_sxr) vec_state_1 <= tms_up; // wait for !go_sxr, then go to exit2-ir
																															else vec_state_1 <= tms_down;	// else keep cycling in pause_ir
																													end
																								default		:	vec_state_1 <= vec_error;
																							endcase
																						end
															pause_dr				:	begin																								
																							case (sxr_type)
																								sdr_default,
																								sdr_on_fail_pwr_off,
																								sdr_retry_default,
																								sdr_retry_pwr_off
																												:	
																													begin
																														if (!go_sxr) vec_state_1 <= tms_up; // wait for !go_sxr, then go to exit2-dr
																															else vec_state_1 <= tms_down;	// else keep cycling in pause_dr
																													end
																								default		:	vec_state_1 <= vec_error;
																							endcase
																						end

															exit2_ir				:	begin
																							case (sxr_type)
																								sir_default,
																								sir_on_fail_pwr_off,
																								sir_retry_default,
																								sir_retry_pwr_off
																												:	vec_state_1 <= tms_down; // go back to shift-xr
																								default		:	vec_state_1 <= vec_error;
																							endcase
																						end
																						
															exit2_dr				:	begin
																							case (sxr_type)
																								sdr_default,
																								sdr_on_fail_pwr_off,
																								sdr_retry_default,
																								sdr_retry_pwr_off
																												:	vec_state_1 <= tms_down; // go back to shift-xr
																								default		:	vec_state_1 <= vec_error;
																							endcase
																						end

															update_ir			:	begin
																							case (sxr_type)
																								sir_default,
																								sir_on_fail_pwr_off,
																								sir_retry_default,
																								sir_retry_pwr_off
																												: 	vec_state_1 <= tms_down;	// go to rti
																								default		:	vec_state_1 <= vec_error;
																							endcase
															  							end
															update_dr			:	begin
																							case (sxr_type)
																								sdr_default,
																								sdr_on_fail_pwr_off,
																								sdr_retry_default,
																								sdr_retry_pwr_off
																												: 	vec_state_1 <= tms_down;	// go to rti
																								default		:	vec_state_1 <= vec_error;
																							endcase
															  							end

															default				:	vec_state_1 <= vec_error;	// E0h
														endcase
													end
				/*										
						tms_down, 			// C3
						tms_up					:	vec_state_1 <= tck_up; //C2 , C1
				*/
				// experimental begin
						tms_down, 			// C3
						tms_up,					//:	vec_state_1 <= tck_up; //C2 , C1
						vec_pause				:	begin
															//vec_state_1 <= tck_up;
															if ((mode == tck_step & !go_step) | (mode != tck_step)) vec_state_1 <= tck_up;
																else if (mode == tck_step) vec_state_1 <= vec_pause;
																		else vec_state_1 <= vec_error;
														end

				
						tck_up					:	begin			//C1
															if (!fail_1 & ((chain_1_state == update_ir) | (chain_1_state == update_dr))) 
																begin
																/*	if (sxr_type != sir_retry_default & sxr_type != sdr_retry_default) vec_state_1 <= vec_fail;  // fail_1 updated on negedge clk
																		else 
																			begin
																				vec_state_1 <= chk_chain_state; //do not care about fail_x // ins V0.6
																				retry_req <= 0;	// request a retry // ins V0.6
																			end */
																			
																	case (sxr_type)
																		sir_default,
																		sdr_default,
																		sir_on_fail_pwr_off,
																		sdr_on_fail_pwr_off	:	vec_state_1 <= vec_fail;
																		default					:	begin
																											vec_state_1 <= chk_chain_state; //do not care about fail_x // ins V0.6
																											retry_req <= 0;	// request a retry // ins V0.6
																										end
																	endcase		
																	
																end
															else vec_state_1 <= chk_chain_state;	
														end
														
						vec_fail					:	vec_state_1 <= vec_state_1;
					endcase
				end
		end

				
	reg fail_x;
//	always @*  // rm V0.6
	always @(negedge clk) // ins V0.6
		begin
			if (vec_state_1 == vec_fail) fail_x <= 0; //CS: add vec_state_2,3,4, ... of other chains here
				else fail_x <= 1;
		end
	
	
// TAP SIGNALS ////////////////////////////////////////////////////////////

	reg tap_ready_raw;
	
	always @(negedge clk) //update tap signals on negedge clk
		begin
			//if (vec_state_1 == sxr_idle) // evaluate llc_state only if no vector exection is running ! // rm v0.1
			if ((vec_state_1 == sxr_idle) | (vec_state_1 == vec_fail)) // evaluate llc_state only if no vector exection is running or on vector fail! // ins v0.1
				begin
					case (llc_state)
						llc_idle		:	begin
												tap_ready_raw <= 1;
												trst_1 	<= 1;
												trst_2 	<= 1;
												tms_1		<= 1;
												tms_2		<= 1;
												tck_1		<= 0;
												tck_2		<= 0;
											end

						hs_trst_a,
						h_trst_a		:	begin
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
						hs_trst_j1	:	begin					// sixth clock cycle inserted in V0.1
												tck_1 <= 1;	
												tck_2 <= 1;	//6a
											end
						hs_trst_k1	:	begin
												tck_1 <= 0;
												tck_2 <= 0;	//6b
											end
						hs_trst_l,
						h_trst_l		:	begin
												trst_1 <= 1;
												trst_2 <= 1;
											end
											
						// ins V0.7 begin
						
						//scanpath_go_from_tlr_to_tlr
						scp_0_a		:	begin
												tms_1 <= 1; //tms up / 35
											end
											
						// scanpath_go_from_tlr_or_rti_to_idle
						scp_1_a		:	begin		// 32h
												tms_1 <= 0;
											end
						scp_1_b		:	begin    // 33h
												tck_1 <= 1;
											end
						scp_1_c		:	begin    // 34h
												tck_1 <= 0;
												tms_1 <= 1;
											end
											
						//scanpath_go_from_rti_to_tlr
						scp_2_a		:	begin // 3A
												tms_1 <= 1;
											end   
						scp_2_b		:	begin // 3B
												tck_1 <= 1;
											end
						scp_2_c		:	begin  // 3C
												tck_1 <= 0;
											end   
						scp_2_d		:	begin  // 3D
												tck_1 <= 1;
											end
						scp_2_e		:	begin  // 3E
												tck_1 <= 0;
											end
						scp_2_f		:	begin  // 3F
												tck_1 <= 1;
											end
						scp_2_g		:	begin	// 40
												tck_1 <= 0;
											end
											
						//scanpath_go_from_pause_to_tlr
						scp_3_a		:	begin // 41
												tms_1 <= 1;
											end
						scp_3_b		:	begin // 42
												tck_1 <= 1;
											end
						scp_3_c		:	begin  // 43
												tck_1 <= 0;
											end
						scp_3_d		:	begin  // 44
												tck_1 <= 1;
											end
						scp_3_e		:	begin  // 45
												tck_1 <= 0;
											end
											
						//scanpath_go_from_pause_to_idle
						scp_4_a		:	begin // 47
												tms_1 <= 1;
											end
						scp_4_b		:	begin // 48
												tck_1 <= 1;
											end
						scp_4_c		:	begin // 49
												tck_1 <= 0;
											end
						scp_4_d		:	begin // 4A
												tck_1 <= 1;
											end
						scp_4_e		:	begin // 4B
												tck_1 <= 0;
												tms_1 <= 0;
											end
											
						//scanpath_go_from_tlr_to_drpause
						scp_5_a		:	begin
												tms_1 <= 0;
											end
						scp_5_b		:	begin
												tck_1 <= 1;
											end
						scp_5_c		:	begin
												tck_1 <= 0;
												tms_1 <= 1;												
											end
						scp_5_d		:	begin
												tck_1 <= 1;
											end
						scp_5_e		:	begin
												tck_1 <= 0;
												tms_1 <= 0;												
											end
						scp_5_f		:	begin
												tck_1 <= 1;
											end
						scp_5_g		:	begin
												tck_1 <= 0;
												tms_1 <= 1;												
											end
						scp_5_h		:	begin
												tck_1 <= 1;
											end
						scp_5_i		:	begin
												tck_1 <= 0;
												tms_1 <= 0;
											end
						
						//scanpath_go_from_drpause_to_drpause
						scp_6_a		:	begin
												tms_1 <= 1;
											end
						scp_6_b		:	begin
												tck_1 <= 1;
											end
						scp_6_c		:	begin
												tck_1 <= 0;
											end
						scp_6_d		:	begin
												tck_1 <= 1;
											end
						scp_6_e		:	begin
												tck_1 <= 0;
											end
											
						//scanpath_go_from_tlr_to_irpause
						scp_7_a		:	begin
												tms_1 <= 0;
											end
						scp_7_b		:	begin
												tck_1 <= 1;
											end
						scp_7_c		:	begin
												tck_1 <= 0;
												tms_1 <= 1;
											end
						scp_7_d		:	begin
												tck_1 <= 1;
											end
						scp_7_e		:	begin
												tck_1 <= 0;
											end
											
						//scanpath_go_from_irpause_to_irpause
						scp_8_a		:	begin
												tms_1 <= 1;
											end
						scp_8_b		:	begin
												tck_1 <= 1;
											end
						scp_8_c		:	begin
												tck_1 <= 0;
											end
						scp_8_d		:	begin
												tck_1 <= 1;
											end
						scp_8_e		:	begin
												tck_1 <= 0;
											end
											
						// ins V0.7 end
						
						llc_ending_a	:	tap_ready_raw <= 0;
						llc_ending_b	:	tap_ready_raw <= 1;
						// CS: default : ???
					endcase
				end	
				else
				begin
					case (vec_state_1)
						tck_up			:	begin		// C1
													tck_1 <= 1;
												end
												
						tms_down			:	begin		// C3
													tck_1 <= 0;
													tms_1 <= 0;
												end
						tms_down_rti	:	begin    // C4
													tck_1 <= 0;
													tms_1 <= 0;
												end		
						tck_up_rti		:	tck_1 <= 1; // C5
						tms_up_sel_dr	:	begin    // C6
													tck_1 <= 0;
													tms_1 <= 1;
												end		
						tck_up_sel_dr	:	tck_1 <= 1; // C7
						tms_up  			:	begin
													tck_1 <= 0;
													tms_1 <= 1;
												end
						chk_chain_state:	begin
													case (chain_1_state)
														select_dr_scan	:	bits_processed_chain_1 <= -1;
														shift_ir,
														shift_dr			:	bits_processed_chain_1 <= bits_processed_chain_1 + 1;
														
														pause_ir,
														update_ir,
														pause_dr,
														update_dr		:	tap_ready_raw <= 0;
														
														exit2_ir,
														exit2_dr,
														run_test_idle	:	tap_ready_raw <= 1;
													endcase
												end	
					//	vec_fail			:	tap_ready_raw <= 0; // ins V0.6
						default 			:	begin
													tck_1 <= tck_1;
													tms_1 <= tms_1;
												end

					endcase
				end
		end
		
	
	// shrink tap_ready_raw signal to one clk cycle	
	pulse_maker pm_tap_ready(
		.clk(clk),
		.reset(reset),
		.in(tap_ready_raw), // L active // sampled on posedge of clk
		.out(tap_ready) // L active , updated on negedge of clk
		);	
		
//// MUX //////////////////////////////////////////////////////////////

	mux8to1 mux_drv_chain_1(
		.sel(bits_processed_chain_1[2:0]),
		.in(drv_chain_1),
		.out(tdo_1)	// updated on negedge of clk
	);

	mux8to1 mux_drv_chain_2(
		.sel(bits_processed_chain_2[2:0]),
		.in(drv_chain_2),
		.out(tdo_2) // updated on negedge of clk
	);

	mux8to1 mux_exp_chain_1(
		.sel(bits_processed_chain_1[2:0]),
		.in(exp_chain_1),
		.out(exp_1) // updated on negedge of clk
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

	assign trst_1_and_reset = (trst_1 & reset);  // for asychronous reset of chain

	always @(posedge tck_1) // or negedge trst_1_and_reset)
		begin
			//if (!reset | exec_state == idle) chain_1_state <= test_logic_reset;
			if (!trst_1_and_reset) chain_1_state <= test_logic_reset;
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

	assign trst_2_and_reset = (trst_2 & reset);  // for asychronous reset of chain
	
	always @(posedge tck_2 or negedge trst_2_and_reset)
		begin
			//if (!reset) chain_2_state <= test_logic_reset;
			if (!trst_2_and_reset) chain_2_state <= test_logic_reset;
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