`timescale 1ns / 1ps

module tap_controller(
		// inputs
		reset,
		start,
		chain_ct,
		exec_state,
		//clk_cpu,
		clk_tap,
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
		chain_1,
		chain_2,
		led,
		bits_processed_chain_1,
		bits_processed_chain_2,
		
		bit_no_1,
		bit_no_2
	);

	// inputs
	input reset;
	input start;
	input [7:0] chain_ct;
	input [7:0] exec_state;
	//input clk_cpu;
	input clk_tap;
	input [7:0] sxr_type;
	input [31:0] sxr_length_chain_1;
	input [31:0] sxr_length_chain_2;
//	input [31:0] byte_ct_chain_1;
//	input [31:0] byte_ct_chain_2;
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
	output tap_ready;
	output tck_1;
	output tck_2;
	output tms_1;
	output tms_2;
	output tdo_1;
	output tdo_2;
	output trst_1;
	output trst_2;
	output fail_1;
	output fail_2;
	output mask_1;
	output mask_2;
	output exp_1;
	output exp_2;	
	
	//DEBUG
	output [3:0] chain_1;
	output [3:0] chain_2;	
	output led;

	`include "parameters.v"
	

	output reg [31:0] bits_processed_chain_1;
	output reg [31:0] bits_processed_chain_2;
//	reg [31:0] bytes_ct_chain_1;
//	reg [31:0] bytes_ct_chain_2;
	output reg [4:0] bit_no_1;
	output reg [4:0] bit_no_2;
	reg [3:0] chain_1;
	reg [3:0] chain_2;

	//reg [3:0] bit_no;
	//reg tdo_1;
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


	////////////// fail filter ///////////////////////////////////////////
	assign fail_1_pre = (exp_1 ^ tdi_1) & mask_1; // (exp XOR tdi) & mask
	assign fail_2_pre = (exp_2 ^ tdi_2) & mask_2;	

	reg fail_1;
	always @(posedge tck_1)
		begin
			if ((exec_state == test_vector_segments_ready) & (bits_processed_chain_1 != 32'hFFFFFFFF)) // do not compute fail if bits_processed_1 is FFFFFFFFh (init state)
				begin
					case (chain_1)
						shift_dr , shift_ir	:	fail_1 <= fail_1_pre; //if (fail_1_pre) fail_1 <= 1;
						default					:	fail_1 <= 0;
					endcase
				end
			else fail_1 <= 0;
		end



	reg fail_2;
	always @(posedge tck_2)
		begin
			if ((exec_state == test_vector_segments_ready) & (bits_processed_chain_2 != 32'hFFFFFFFF)) // do not compute fail if bits_processed_2 is FFFFFFFFh (init state)
				begin
					case (chain_2)
						shift_dr , shift_ir	:	fail_2 <= fail_2_pre;
						default					:	fail_2 <= 0;
					endcase
				end
			else fail_2 <= 0;
		end

	assign led = !fail_1;
	////////////////////////////////////////////////////////////////////////////

	reg [3:0] tck_ct;
	reg tck_1;
	reg tck_2;
	//reg tms_1;
	reg tms_1_pre;	
	reg tms_2_pre;	
	//reg tms_2;
//	reg tms_1_state;
//	reg tms_2_state;
	reg trst_1;
	reg trst_2;

	reg tap_ready;
	reg tap_ready_1;
	reg tap_ready_2;
	reg tap_1_segment_request_only;
	reg tap_2_segment_request_only;	
	reg tap_fault;

//	reg chain_1_pause;
//	reg chain_2_pause;

	// workaround for adder and subtractors begin
	wire [31:0] bits_processed_chain_1_inc;
	assign bits_processed_chain_1_inc = bits_processed_chain_1 +1;
	wire [31:0] sxr_length_chain_1_dec;
	assign sxr_length_chain_1_dec = sxr_length_chain_1 -1;
	
	wire [31:0] bits_processed_chain_2_inc;
	assign bits_processed_chain_2_inc = bits_processed_chain_2 +1;
	wire [31:0] sxr_length_chain_2_dec;
	assign sxr_length_chain_2_dec = sxr_length_chain_2 -1;
	// workaround for adder and subtractors end	
	
	reg all_chains_done;
	
	always @(posedge clk_tap)
		begin
/*			if (!reset) 						begin
														tap_ready_1 <= 0;
														tap_ready_2 <= 0;
														tck_ct <= 0;
														tck_1 <= 0; // CS: toggle tck here ?
														tck_2 <= 0; // CS: toggle tck here ?
														tms_1_pre <= 1; 
														tms_2_pre <= 1;
														tap_fault <= 0;
														chain_1_pause <= 0;
														chain_2_pause <= 0;
													end
			else
*/								
			case (exec_state)
				disabled						:	begin
												//		bits_processed_chain_1 <= 32'hFFFFFFFF;
														tap_ready_1 <= 0;
														tap_ready_2 <= 0;
														tck_ct <= 0;
														tck_1 <= 0; // CS: toggle tck here ?
														tck_2 <= 0; // CS: toggle tck here ?
														tms_1_pre <= 1; 
														tms_2_pre <= 1;
														tap_fault <= 0;
													end
													
				test_start					:	begin
														tap_ready_1 <= 0;
														tap_ready_2 <= 0;
														tck_1 <= 0;
														tck_2 <= 0;
														tck_ct <= 0;
														tms_1_pre <= 1;
														tms_2_pre <= 1;
													end

				test_fetch_low_level_cmd_done		: 	begin  //39
																	case (low_level_cmd)
																		8'h00	:	begin		// hard + soft test bus reset
																						if (tck_ct < 4'hF)
																							begin
																								tap_ready_1 <= 0;	// reset tap_ready to indicate low level cmd in progress
																								tap_ready_2 <= 0;	// reset tap_ready to indicate low level cmd in progress
																								tms_1_pre <= 1;
																								tms_2_pre <= 1;
																								tck_ct <= tck_ct + 1;
																								tck_1 <= tck_ct[0];
																								tck_2 <= tck_ct[0];
																							end
																						else 
																							begin
																								tck_1 <= 0;
																								tck_2 <= 0;
																								tap_ready_1 <= 1; //indicate low level cmd done
																								tap_ready_2 <= 1; //indicate low level cmd done
																							end
																					end
																		default	:	tap_fault <= 1;
																	endcase
																end

				test_fetch_step			:	begin  //2B
														tap_ready_1 <= 0;	// aknowledge and reset tap_ready
														tap_ready_2 <= 0;	// aknowledge and reset tap_ready
														tck_ct <= 0;
													end
						
				//test_fetch_low_level_cmd,
				//test_fetch_low_level_cmd_type,
				//test_fetch_low_level_cmd_type_done,
				//test_fetch_low_level_cmd_chain_number,
				//test_fetch_low_level_cmd_chain_number_done,
				//test_fetch_low_level_cmd_cmd,
				test_fetch_low_level_cmd_cmd_done,
				test_fetch_low_level_cmd_done,
	
				test_vector_segments_ready	,  //67 
				//test_check_byte_counts, // 68 	
				test_fetch_sxr_chain_1_length_0 , test_fetch_sxr_chain_1_length_0_done ,
				test_fetch_sxr_chain_1_length_1 , test_fetch_sxr_chain_1_length_1_done , 
				test_fetch_sxr_chain_1_length_2 , test_fetch_sxr_chain_1_length_2_done , 
				test_fetch_sxr_chain_1_length_3 , test_fetch_sxr_chain_1_length_3_done :
				// 3F - 46
												begin
													if ((!go_step & mode == tck_step) | mode != tck_step)
														begin
															// chain 1 control
															case (chain_1)
																test_logic_reset	:	begin
																								//tck_1 <= 0;
																								tms_1_pre <= 0;
																								//chain_1_pause <= 0;
																								if (tms_1_pre == 0) tck_1 <= 1;
																									else tck_1 <= 0; //n
																									
																							end
																run_test_idle		:	begin
																								//tck_1 <= 0;
																								tms_1_pre <= 1;
																								if (tms_1_pre == 1) tck_1 <= 1;
																									else tck_1 <= 0; //n
																							end
																select_dr_scan		:	begin
																								//tck_1 <= 0;
																								bits_processed_chain_1 <= 32'hFFFFFFFF; //independed of sir or sdr
																								case (sxr_type)
																									8'h01 : 	begin
																													tms_1_pre <= 0;
																													if (tms_1_pre == 0) tck_1 <= 1;
																														else tck_1 <= 0; //n
																													// entry capture_dr follows
																												end
																									default : 
																												begin
																													//tms_1 <= 1; //already 1 from previous state
																													if (tck_1 == 0) tck_1 <= 1;
																														else tck_1 <= 0; //n
																													// entry select_ir follows
																												end
																									endcase
																							end
																select_ir_scan		:	begin
																								//tck_1 <= 0;
																								case (sxr_type)
																									8'h02 : 	begin
																													tms_1_pre <= 0;
																													if (tms_1_pre == 0) tck_1 <= 1;
																														else tck_1 <= 0; //n
																													// entry capture_ir follows
																												end
																									default : 
																												begin
																													//tms_1 <= 1; // already 1 from previous state
																													if (tck_1 == 0) tck_1 <= 1;
																														else tck_1 <= 0; //n
																													// entry run_test_idle follows
																												end
																									endcase
																							end
																capture_ir , capture_dr	:	
																							begin
																								//tck_1 <= 0;
																								bit_no_1 <= 5'h1F;
																								//tms_1 <= 0; // already 1 from previous state select_ir_scan
																								if (tck_1 == 0) tck_1 <= 1; //move to shift_ir
																									else tck_1 <= 0; //n
																							end
																shift_ir , shift_dr	:	
																							begin
																								//tck_1 <= 0;
																								///////////////////////////////////////////////////////
																								case (chain_ct)
																									8'h01	:	begin	//bit_no_1 == 5'h0E | bits_processed_chain_1 == sxr_length_chain_1 -1) 	
																													if (bit_no_1 == 5'h0E | bits_processed_chain_1 == sxr_length_chain_1_dec) //sxr_length_chain_1 -1) 
																														begin
																															tap_ready_1 <= 1;
																															bit_no_1 <= 5'h1F;
																														end
																														else bit_no_1 <= bit_no_1 + 1;
																												end
																								
																									8'h02	:	begin	//bit_no_1 == 5'h0E | bits_processed_chain_1 == sxr_length_chain_1 -1) 	
																													if (bit_no_1 == 5'h0E) 
																														begin
																															tap_ready_1 <= 1;
																															bit_no_1 <= 5'h1F;
																														end
																														else bit_no_1 <= bit_no_1 + 1;
																												end
																								endcase
																																																		
																								////////////////////////////////////////////////////////									
																								//case (exec_state)
																								//	test_vector_segments_ready : begin
																																				if (bits_processed_chain_1_inc < sxr_length_chain_1) //bits_processed_chain_1 preloaded with -1 earlier
																																				begin
																																					if (tck_1 == 0) tck_1 <= 1;
																																						else 
																																							begin
																																								bits_processed_chain_1 <= bits_processed_chain_1 + 1;
																																								tck_1 <= 0; //n
																																							end
																																				end
																																				else 
																																				begin
																																					if (tck_1 == 0) tck_1 <= 1;
																																					else tck_1 <= 0; //n
																																				end
																																			//end
																																			
																								//	test_check_byte_counts	:	 begin
																								//												tck_1 <= 0; //n
																								//												if (bits_processed_chain_1_inc < sxr_length_chain_1) //bits_processed_chain_1 preloaded with -1 earlier
																								//												begin
																																					//if (tck_1 == 0) tck_1 <= 1;
																																					//	else 
																																					//		begin
																								//																bits_processed_chain_1 <= bits_processed_chain_1 + 1;
																																								
																																					//		end
																								//												end
																																				//else 
																																				//begin
																																				//	if (tck_1 == 0) tck_1 <= 1;
																																				//	else tck_1 <= 0; //n
																																				//end
																								//											end
																								//endcase
																							end
																									
																									
																exit1_ir	, exit1_dr	:	
																							begin
																								//tck_1 <= 0;
																								//if (end_of_sir_state == 8'h0B) tms_1_pre <= 0;
																								//if (chain_1_pause) tms_1_pre <= 0;
																								if (chain_ct > 8'h01) tms_1_pre <= 0; //if more than one chain needed go to pause_xr
																									else tms_1_pre <= 1; // else goto update_xr
																								
																								if (tck_1 == 0) tck_1 <= 1; //move to update_ir or pause_ir
																									else 
																										begin
																											bits_processed_chain_1 <= 0; // 
																											tck_1 <= 0; //n
																										end
																							end
																pause_ir	, pause_dr	:	
																							begin
																								//tck_1 <= 0;
																								if (all_chains_done) tms_1_pre <= 1;
																									else tms_1_pre <= 0;
																								
																								if (tck_1 == 0) tck_1 <= 1;
																									else tck_1 <= 0; //n
																							end
																							
																exit2_ir , exit2_dr	:
																							begin
																								//tck_1 <= 0;
																								if (tck_1 == 0) tck_1 <= 1;
																									else tck_1 <= 0; //n
																							end
																							
																update_ir			:	begin
																								//tck_1 <= 0;
																								if (end_of_sir_state == 8'h02) tms_1_pre <= 1; //move to select_dr_scan
																									else tms_1_pre <= 0;
																									
																								if (tck_1 == 0) tck_1 <= 1; //move to run_test_idle
																									else tck_1 <= 0; //n
																							end
																							
																update_dr			:	begin
																								//tck_1 <= 0;
																								if (end_of_sdr_state == 8'h02) tms_1_pre <= 1; //move to select_dr_scan
																									else tms_1_pre <= 0;
																									
																								if (tck_1 == 0) tck_1 <= 1; //move to run_test_idle
																									else tck_1 <= 0; //n
																							end																							
															endcase //case chain_1


															// chain 2 control
															if (chain_ct > 8'h01) 
															begin
															case (chain_2)
																test_logic_reset	:	begin
																								tck_2 <= 0;
																								tms_2_pre <= 0;
																								//chain_2_pause <= 0;
																								if (tms_2_pre == 0) tck_2 <= 1;
																									//else tck_1 <= 0;
																									
																							end
																run_test_idle		:	begin
																								tck_2 <= 0;
																								tms_2_pre <= 1;
																								if (tms_2_pre == 1) tck_2 <= 1;
																							end
																select_dr_scan		:	begin
																								tck_2 <= 0;
																								bits_processed_chain_2 <= -1; //independed of sir or sdr
																								case (sxr_type)
																									8'h01 : 	begin
																													tms_2_pre <= 0;
																													if (tms_2_pre == 0) tck_2 <= 1;
																													// entry capture_dr follows
																												end
																									default : 
																												begin
																													//tms_1 <= 1; //already 1 from previous state
																													if (tck_2 == 0) tck_2 <= 1;
																													// entry select_ir follows
																												end
																									endcase
																							end
																select_ir_scan		:	begin
																								tck_2 <= 0;
																								case (sxr_type)
																									8'h02 : 	begin
																													tms_2_pre <= 0;
																													if (tms_2_pre == 0) tck_2 <= 1;
																													// entry capture_ir follows
																												end
																									default : 
																												begin
																													//tms_1 <= 1; // already 1 from previous state
																													if (tck_2 == 0) tck_2 <= 1;
																													// entry run_test_idle follows
																												end
																									endcase
																							end
																capture_ir , capture_dr	:	
																							begin
																								tck_2 <= 0;
																								bit_no_2 <= 5'h1F;
																								//tms_1 <= 0; // already 1 from previous state select_ir_scan
																								if (tck_2 == 0) tck_2 <= 1; //move to shift_ir
																							end
																shift_ir , shift_dr	:	
																							begin
																								tck_2 <= 0;
																								///////////////////////////////////////////////////////
																								case (chain_ct)
																									8'h01	:	begin	//bit_no_1 == 5'h0E | bits_processed_chain_1 == sxr_length_chain_1 -1) 	
																													if (bit_no_2 == 5'h0E | bits_processed_chain_2 == sxr_length_chain_2_dec) 
																														begin
																															tap_ready_2 <= 1;
																															bit_no_2 <= 5'h1F;
																														end
																														else bit_no_2 <= bit_no_2 + 1;
																												end
																								
																									8'h02	:	begin	//bit_no_1 == 5'h0E | bits_processed_chain_1 == sxr_length_chain_1 -1) 	
																													if (bit_no_2 == 5'h0E) 
																														begin
																															tap_ready_2 <= 1;
																															bit_no_2 <= 5'h1F;
																														end
																														else bit_no_2 <= bit_no_2 + 1;
																												end
																								endcase
																								////////////////////////////////////////////////////////									
																								if (bits_processed_chain_2_inc < sxr_length_chain_2) //bits_processed_chain_1 preloaded with -1 earlier
																									begin
																										if (tck_2 == 0) tck_2 <= 1;
																										else bits_processed_chain_2 <= bits_processed_chain_2 + 1;
																									end
																								else 
																									begin
																										//bits_processed_chain_1 <= 0;
																										if (tck_2 == 0) tck_2 <= 1;
																									end
																							end
																exit1_ir	, exit1_dr	:	
																							begin
																								tck_2 <= 0;
																								//if (end_of_sir_state == 8'h0B) tms_1_pre <= 0;
																								//if (chain_2_pause) tms_2_pre <= 0;
																								if (chain_ct > 8'h01) tms_2_pre <= 0; //if more than one chain selected goto pause_xr
																									else tms_2_pre <= 1; //else goto update_xr
																								
																								if (tck_2 == 0) tck_2 <= 1; //move to update_ir or pause_ir
																									else bits_processed_chain_2 <= 0; // 
																							end
																pause_ir	, pause_dr	:	
																							begin
																								tck_2 <= 0;
																								if (all_chains_done) tms_2_pre <= 1;
																									else tms_2_pre <= 0;
																								
																								if (tck_2 == 0) tck_2 <= 1; //move to update_ir or pause_ir
																							end

																exit2_ir , exit2_dr	:
																							begin
																								tck_2 <= 0;
																								if (tck_2 == 0) tck_2 <= 1;
																							end

																update_ir			:	begin
																								tck_2 <= 0;
																								if (end_of_sir_state == 8'h02) tms_2_pre <= 1; //move to select_dr_scan
																									else tms_2_pre <= 0;
																									
																								if (tck_2 == 0) tck_2 <= 1; //move to run_test_idle
																							end
																							
																update_dr			:	begin
																								tck_2 <= 0;
																								if (end_of_sdr_state == 8'h02) tms_2_pre <= 1; //move to select_dr_scan
																									else tms_2_pre <= 0;
																									
																								if (tck_2 == 0) tck_2 <= 1; //move to run_test_idle
																							end																							
															endcase //case chain_2
															end //if chain_ct > 2
														end //if begin

												end // top
															
						
				default						:	begin
														tck_ct <= 0;
														tck_1 <= tck_1;
														tms_1_pre <= tms_1_pre; //tms_1_state <= tms_1_state;
														tap_ready_1 <= 0;
														tap_ready_2 <= 0;
														tap_1_segment_request_only <= 0;
														tap_2_segment_request_only <= 0;
													end

			endcase
		end


	// tap_ready forming
	always @*
		begin
			if (chain_ct > 8'b01) 
				begin
					if (all_chains_done | tap_ready_1 | tap_ready_2 ) tap_ready <= 1;
						else tap_ready <= 0;
					end
			else tap_ready <= tap_ready_1;
		end

	// all_chains_done forming from pause_xr
	always @*
		begin
			if ((chain_1 == pause_ir & chain_2 == pause_ir) | (chain_1 == pause_dr & chain_2 == pause_dr)) all_chains_done <= 1;
				else all_chains_done <= 0;
			//if (chain_1 == pause_dr & chain_2 == pause_dr) all_chains_done <= 1;
			//	else all_chains_done <= 0;
		end
		

	// tms forming out of last_bit_chain or tms_pre
	assign sxr_length_chain_1_dec = sxr_length_chain_1 -1;
	reg last_bit_chain_1;
	always @*
		begin
			case (bits_processed_chain_1) //changes on posedge of clk
				sxr_length_chain_1_dec	:	begin
														if (exec_state == test_vector_segments_ready) last_bit_chain_1 <= 1;
													end
				default						:	last_bit_chain_1 <= 0;
			endcase
		end

	assign tms_1 = (tms_1_pre | last_bit_chain_1);


	assign sxr_length_chain_2_dec = sxr_length_chain_2 -1;
	reg last_bit_chain_2;
	always @*
		begin
			case (bits_processed_chain_2) //changes on posedge of clk
				sxr_length_chain_2_dec	:	
													begin
														if (chain_ct > 8'h01 & exec_state == test_vector_segments_ready) last_bit_chain_2 <= 1;
													end
				default						:	last_bit_chain_2 <= 0;
			endcase
		end

	assign tms_2 = (tms_2_pre | last_bit_chain_2);





	// trst forming

	always @*
		begin
			if (tck_ct > 0) 	
				begin
					trst_1 <= 0;
					trst_2 <= 0;									
				end
			else 
				begin
					trst_1 <= 1;
					trst_2 <= 1;
				end
		end


///////// monitoring chain 1 //////////////////////////////////////////////////////////

	always @(posedge tck_1)
		begin
			if (!reset) chain_1 <= test_logic_reset;
			else
			case (chain_1)
				test_logic_reset	:	begin
												if (tms_1 == 0) chain_1 <= run_test_idle;
													else chain_1 <= test_logic_reset;
											end

				run_test_idle		:	begin
												if (tms_1 == 1) chain_1 <= select_dr_scan;
													else chain_1 <= run_test_idle;
											end

				select_dr_scan		:	begin
												if (tms_1 == 1) chain_1 <= select_ir_scan;
													else chain_1 <= capture_dr;
											end
											
				select_ir_scan		:	begin	//3
												if (tms_1 == 1) chain_1 <= test_logic_reset;
													else chain_1 <= capture_ir;
											end
				//DR path
				capture_dr			:	begin
												if (tms_1 == 1) chain_1 <= exit1_dr;
													else chain_1 <= shift_dr;
											end

				shift_dr				:	begin
												if (tms_1 == 1) chain_1 <= exit1_dr;
													else chain_1 <= shift_dr;
											end
											
				exit1_dr				:	begin
												if (tms_1 == 1) chain_1 <= update_dr;
													else chain_1 <= pause_dr;
											end

				pause_dr				:	begin
												if (tms_1 == 1) chain_1 <= exit2_dr;
													else chain_1 <= pause_dr;
											end

				exit2_dr				:	begin
												if (tms_1 == 1) chain_1 <= update_dr;
													else chain_1 <= shift_dr;
											end

				update_dr			:	begin
												if (tms_1 == 1) chain_1 <= select_dr_scan;
													else chain_1 <= run_test_idle;
											end

				// IR path
				capture_ir			:	begin
												if (tms_1 == 1) chain_1 <= exit1_ir;
													else chain_1 <= shift_ir;
											end

				shift_ir				:	begin
												if (tms_1 == 1) chain_1 <= exit1_ir;
													else chain_1 <= shift_ir;
											end
											
				exit1_ir				:	begin
												if (tms_1 == 1) chain_1 <= update_ir;
													else chain_1 <= pause_ir;
											end

				pause_ir				:	begin
												if (tms_1 == 1) chain_1 <= exit2_ir;
													else chain_1 <= pause_ir;
											end

				exit2_ir				:	begin
												if (tms_1 == 1) chain_1 <= update_ir;
													else chain_1 <= shift_ir;
											end

				update_ir			:	begin
												if (tms_1 == 1) chain_1 <= select_dr_scan;
													else chain_1 <= run_test_idle;
											end

				default				:	chain_1 <= test_logic_reset;
			endcase
		end
		
///////// monitoring chain 2 //////////////////////////////////////////////////////////

	always @(posedge tck_2)
		begin
			if (!reset) chain_2 <= test_logic_reset;
			else
			case (chain_2)
				test_logic_reset	:	begin
												if (tms_2 == 0) chain_2 <= run_test_idle;
													else chain_2 <= test_logic_reset;
											end

				run_test_idle		:	begin
												if (tms_2 == 1) chain_2 <= select_dr_scan;
													else chain_2 <= run_test_idle;
											end

				select_dr_scan		:	begin
												if (tms_2 == 1) chain_2 <= select_ir_scan;
													else chain_2 <= capture_dr;
											end
											
				select_ir_scan		:	begin	//3
												if (tms_2 == 1) chain_2 <= test_logic_reset;
													else chain_2 <= capture_ir;
											end
				//DR path
				capture_dr			:	begin
												if (tms_2 == 1) chain_2 <= exit1_dr;
													else chain_2 <= shift_dr;
											end

				shift_dr				:	begin
												if (tms_2 == 1) chain_2 <= exit1_dr;
													else chain_2 <= shift_dr;
											end
											
				exit1_dr				:	begin
												if (tms_2 == 1) chain_2 <= update_dr;
													else chain_2 <= pause_dr;
											end

				pause_dr				:	begin
												if (tms_2 == 1) chain_2 <= exit2_dr;
													else chain_2 <= pause_dr;
											end

				exit2_dr				:	begin
												if (tms_2 == 1) chain_2 <= update_dr;
													else chain_2 <= shift_dr;
											end

				update_dr			:	begin
												if (tms_2 == 1) chain_2 <= select_dr_scan;
													else chain_2 <= run_test_idle;
											end

				// IR path
				capture_ir			:	begin
												if (tms_2 == 1) chain_2 <= exit1_ir;
													else chain_2 <= shift_ir;
											end

				shift_ir				:	begin
												if (tms_2 == 1) chain_2 <= exit1_ir;
													else chain_2 <= shift_ir;
											end
											
				exit1_ir				:	begin
												if (tms_2 == 1) chain_2 <= update_ir;
													else chain_2 <= pause_ir;
											end

				pause_ir				:	begin
												if (tms_2 == 1) chain_2 <= exit2_ir;
													else chain_2 <= pause_ir;
											end

				exit2_ir				:	begin
												if (tms_2 == 1) chain_2 <= update_ir;
													else chain_2 <= shift_ir;
											end

				update_ir			:	begin
												if (tms_2 == 1) chain_2 <= select_dr_scan;
													else chain_2 <= run_test_idle;
											end

				default				:	chain_2 <= test_logic_reset;
			endcase
		end



endmodule