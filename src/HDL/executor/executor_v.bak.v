`timescale 1ns / 1ps

//
// V0.1 :
//			- hstrst on test fail

// V0.2 :
//			- i2c

// V0.3 : - llc (dis)connect gnd

// V0.4	: - on_fail action depends on sxr type
//////////////////////////////////////////////////////////////////////////////////
module executor(
		reset,
		start,	// L-active
		stop,		// L-active
		active,			//ouput; address controlled by executor ex // L active
		start_addr,	//driven by register file //83-81h
		ram_addr, 		//drives output RAM address (if executor control selected)
		ram_data,		//driven by output RAM
		//selected_bit,	//outputs address of selected bit of RAM data
		//bit_data,		// outputs selected bit data
		tdo_1,
		tdo_2,
		tdi_1,
		tdi_2,
		tms_1,
		tms_2,
		tck_1,
		tck_2,
		trst_1,
		trst_2,
		fail_1,
		fail_2,
		fail_any_chain,
		step_id,
		pass,
		mask_1,
		mask_2,
		exp_1,
		exp_2,			
		clk,
		clk_timer,
		mode,
		exec_state,		// state machine excecutor
		run,
		debug,
		bits_processed_chain_1,
		bits_processed_chain_2,
		sxr_length_chain_1,
		sxr_length_chain_2,
		tap_ready,
		vec_state_1,
		vec_state_2,
		tck_frequency,
		sda,
		scl,
		im_ack_fail,
		uut_pwr_on_1,
		uut_pwr_on_2
		
		
		//ex_halt
		//chain_1_base_addr,
		//chain_ct
    );

	output [7:0] exec_state;
	reg [7:0] exec_state;
	
	output active;
	input reset;
	input start; // L-active
	input stop; // L-active
	input [23:0] start_addr;
	output [23:0] ram_addr;
	input [7:0]	ram_data;
	//output [2:0] selected_bit;
	//output bit_data;
	output tdo_1;
	output tdo_2;
	input tdi_1;
	input tdi_2;
	output tms_1;
	output tms_2;
	output tck_1;
	output tck_2;
	output trst_1;
	output trst_2;
	output fail_1;
	output fail_2;
	output reg fail_any_chain;
	output reg pass;
	output mask_1;
	output mask_2;
	output exp_1;
	output exp_2;	
	input clk_timer;
	input clk;
	input [7:0] mode;
	output [7:0] debug;
	output [31:0] bits_processed_chain_1;
	output [31:0] bits_processed_chain_2;	
	output tap_ready;
	output [7:0] vec_state_1;
	output [7:0] vec_state_2;
	output [7:0] tck_frequency;
	inout sda;
	output scl;
	output im_ack_fail;
	output reg uut_pwr_on_1;
	output reg uut_pwr_on_2;


	//reg [7:0] debug;
	//assign active = 1'b1;
	//output [31:0] chain_1_base_addr;
	//output [7:0] chain_ct;
	
	//input ex_halt;

	//always @(posedge clk)
	//	begin
	//		if (mode == 8'hFF) active = 1'b1;	// executor inactive if mode = FFh (after reset)
	//		else active = 1'b0;					// executor active
	//	end
	output run;
	reg run;
	reg active;
	reg [7:0] chain_ct;
	reg [31:0] chain_1_base_addr;
	reg [31:0] chain_2_base_addr;
	
	
	reg [26:0] addr;
	output reg [15:0] step_id;
	reg [7:0] low_level_cmd_type;	//CS: applies for all chains
	reg [7:0] low_level_cmd_cmd;	//CS: applies for all chains
	
	reg [7:0] sxr_type;				//CS: applies for all chains (taken from chain 1, sxr_types of chain_2 ignored)
	output reg [31:0] sxr_length_chain_1;
	output reg [31:0] sxr_length_chain_2;
	reg [31:0] byte_ct_chain_1;
	reg [31:0] offset_chain_1;
	reg [2:0] remainder_chain_1;
	reg [31:0] byte_ct_chain_2;
	reg [31:0] offset_chain_2;
	reg [2:0] remainder_chain_2;
	reg [7:0] drv_chain_1;
	reg [7:0] mask_chain_1;
	reg [7:0] exp_chain_1;
	reg [7:0] drv_chain_2;
	reg [7:0] mask_chain_2;
	reg [7:0] exp_chain_2;





	//reg [15:0] glob_conf_id;		//CS: glob conf id ignored, because glob conf occurrs only once (so far)
	//reg [7:0] glob_conf_type;		//CS: glob conf type ignored so far
	//reg [3:0] end_of_sdr_state;
	//reg [3:0] end_of_sir_state;
	//reg [7:0] pwr_off_on_bit_fail;
	//reg [7:0] pwr_off_on_vector_fail;
	//reg [7:0] tck_frequency;	
	//reg [7:0] low_level_cmd;
	reg [7:0] glob_conf_0; // drives tck_frequeny scale to main
	reg [7:0] glob_conf_1;	
	reg [7:0] glob_conf_2;
	reg [7:0] glob_conf_3;
	reg [7:0] glob_conf_4;
	reg [7:0] glob_conf_5;
	reg [7:0] glob_conf_6;
	reg [7:0] glob_conf_7;

	


	assign tck_frequency = glob_conf_0;
	wire [7:0] on_fail_action;
	assign on_fail_action = glob_conf_7;


///I2C master ///////////////////////////////////////////////////
	reg [7:0] im_data_tx_1;
	reg [7:0] im_data_tx_2;	
	reg [7:0] im_addr;
	reg im_data_tx_ct;
	reg im_start;

	i2c_master im (
		.clk(clk),
		.data_ct_ext(im_data_tx_ct), // number of bytes to tx
		.data_tx_1_ext(im_data_tx_1),
		.data_tx_2_ext(im_data_tx_2),		
		.addr_ext(im_addr),
		.reset(reset),
		.ack_fail(im_ack_fail),
		.sda(sda),
		.scl(scl),
		.im_ready(im_ready),
		.start(im_start),  // sampled on posedge clk / L-active for one clk cycle
		
		.exec_state(exec_state),
		.llct(low_level_cmd_type),
		.llcc(low_level_cmd_cmd)

    );

///////////////////////////////////////////////////////////////////////////////////




	
	assign ram_addr[23:0] = addr[26:3];	// map address register to output RAM address
	
	// decode ram data to one bit output
	//mux8to1 mux(
	//	.sel(addr[2:0]),
	//	.in(ram_data),
	//	.out(bit_data)
	//);
	
	// shrink start signal to one clk_tap cycle	
	pulse_maker pm(
		.clk(clk),
		.reset(reset),
		.in(start), // L active
		.out(go_step) // L active , updated on negedge of clk_tap
		);	

	wire tap_ready;
	tap_controller tc(
		// inputs
		.reset(reset),
		.chain_ct(chain_ct),
		.exec_state(exec_state),
		.clk(clk),
		.sxr_type(sxr_type),
		.sxr_length_chain_1(sxr_length_chain_1),
		.sxr_length_chain_2(sxr_length_chain_2),
		.llct(low_level_cmd_type),	//CS: applies for all chains
		.llcc(low_level_cmd_cmd),	//CS: applies for all chains
		.on_fail_action(on_fail_action), // CS: not used yet
		//.tck_frequency(tck_frequency),
		//.pwr_off_on_bit_fail(pwr_off_on_bit_fail),
		//.pwr_off_on_vector_fail(pwr_off_on_vector_fail),
		//.low_level_cmd(low_level_cmd_cmd),
		.drv_chain_1(drv_chain_1),
		.drv_chain_2(drv_chain_2),
		.mask_chain_1(mask_chain_1),
		.mask_chain_2(mask_chain_2),
		.exp_chain_1(exp_chain_1),
		.exp_chain_2(exp_chain_2),
		.tdi_1(tdi_1),
		.tdi_2(tdi_2),
		.go_step(go_step),
		.start(start),
		.mode(mode[3:0]), //low nibble of mode determines step width
		
		//outputs
		.tap_ready(tap_ready),
		.tck_1(tck_1),
		.tck_2(tck_2),
		.tms_1(tms_1),
		.tms_2(tms_2),
		.tdo_1(tdo_1),
		.tdo_2(tdo_2),
		.trst_1(trst_1),
		.trst_2(trst_2),
		
		.fail_1(fail_1), // H - active
		.fail_2(fail_2),
		.mask_1(mask_1),
		.mask_2(mask_2),
		.exp_1(exp_1),
		.exp_2(exp_2),	
		
		.bits_processed_chain_1(bits_processed_chain_1),
		.bits_processed_chain_2(bits_processed_chain_2),		
		
		.fail_x(fail_x),
		
		//debug
		.chain_1_state(debug[3:0]),
		.chain_2_state(debug[7:4]),
		.vec_state_1(vec_state_1),
		.vec_state_2(vec_state_2)		
	);


	// fail collector
	//assign fail_x = 1; //(fail_1 | fail_2); // CS: add further fail_x here
	//assign fail_x = fail_1; // | fail_2); // CS: add further fail_x here
	
	//

	wire timeout;
	timer tm(
		// inputs
		.reset(reset),
		.exec_state(exec_state),
		.clk_timer(clk_timer), // 10hz
		.clk(clk),
		.llct(low_level_cmd_type),	//CS: applies for all chains
		.llcc(low_level_cmd_cmd),	//CS: applies for all chains
		
		//outputs
		.timeout(timeout)		
	);


	assign llc_done = (timeout & tap_ready & im_ready);
	
	// DEBUG //////////////////////////////////
	
	//assign debug[0] = tap_ready;
	//assign debug[7:1] = 7'h00;
	
	// DEBUG end //////////////////////////////////

	`include "parameters.v"





	always @(posedge clk)		
		begin
			if (!stop) exec_state <= test_fail;
			else
			//if (!start & (exec_state == test_fail | exec_state == disabled))
				begin
					casex (mode) //84h  //CS: mode is updated on posedge clk too -> critical ?

						8'b00000xxx	: exec_state <= debug1;	// cmds 0-7h

						8'h1x		: 
							begin
								case (exec_state)
									test_done, test_fail , disabled , idle	:	
														begin
															if (!go_step) exec_state <= test_start;
															else exec_state <= exec_state;
														end
														
														
									//disabled		:	begin
									//						if (!start) exec_state <= test_start;
									//						else exec_state <= exec_state; //test_start;
									//					end
									debug1   							: exec_state <= test_start;
									//idle     							: exec_state <= test_start;
									test_start							: exec_state <= test_fetch_chain_ct;

									test_fetch_chain_ct					: exec_state <= test_fetch_chain_ct_done;
									test_fetch_chain_ct_done			: exec_state <= test_fetch_chain_1_base_addr;

									test_fetch_chain_1_base_addr			: exec_state <= test_fetch_chain_1_base_addr_0;
									test_fetch_chain_1_base_addr_0		: exec_state <= test_fetch_chain_1_base_addr_0_done;
									test_fetch_chain_1_base_addr_0_done	: exec_state <= test_fetch_chain_1_base_addr_1;
									test_fetch_chain_1_base_addr_1		: exec_state <= test_fetch_chain_1_base_addr_1_done;
									test_fetch_chain_1_base_addr_1_done	: exec_state <= test_fetch_chain_1_base_addr_2;
									test_fetch_chain_1_base_addr_2		: exec_state <= test_fetch_chain_1_base_addr_2_done;
									test_fetch_chain_1_base_addr_2_done	: exec_state <= test_fetch_chain_1_base_addr_3;
									test_fetch_chain_1_base_addr_3		: exec_state <= test_fetch_chain_1_base_addr_3_done;
									test_fetch_chain_1_base_addr_3_done	: exec_state <= test_fetch_chain_1_base_addr_done;
									test_fetch_chain_1_base_addr_done	: 	
																		begin 		//0E
																			if (chain_ct > 8'h02) exec_state <= error;
																			else if (chain_ct == 8'h02) exec_state <= test_fetch_chain_2_base_addr;
																			else exec_state <= test_fetch_global_conf; //means only one chain used
																		end

									test_fetch_chain_2_base_addr		: exec_state <= test_fetch_chain_2_base_addr_0;
									test_fetch_chain_2_base_addr_0		: exec_state <= test_fetch_chain_2_base_addr_0_done;
									test_fetch_chain_2_base_addr_0_done	: exec_state <= test_fetch_chain_2_base_addr_1;
									test_fetch_chain_2_base_addr_1		: exec_state <= test_fetch_chain_2_base_addr_1_done;
									test_fetch_chain_2_base_addr_1_done	: exec_state <= test_fetch_chain_2_base_addr_2;
									test_fetch_chain_2_base_addr_2		: exec_state <= test_fetch_chain_2_base_addr_2_done;
									test_fetch_chain_2_base_addr_2_done	: exec_state <= test_fetch_chain_2_base_addr_3;
									test_fetch_chain_2_base_addr_3		: exec_state <= test_fetch_chain_2_base_addr_3_done;
									test_fetch_chain_2_base_addr_3_done	: exec_state <= test_fetch_chain_2_base_addr_done;
									test_fetch_chain_2_base_addr_done	: 	exec_state <= test_fetch_global_conf;  //CS: read base address of chain 3 here ...



									test_fetch_global_conf			:	exec_state <= test_fetch_global_conf_0;
									test_fetch_global_conf_0		:	exec_state <= test_fetch_global_conf_0_done;
									
									test_fetch_global_conf_0_done	:	exec_state <= test_set_i2c_muxer; //11 / A3
									test_set_i2c_muxer				:	exec_state <= test_set_i2c_muxer_done;	// A3 / A4
									test_set_i2c_muxer_done			:	
																				begin
																					if (!im_ready) exec_state <= test_fetch_global_conf_1; //12
																						else exec_state <= test_set_i2c_muxer_done; //A4
																				end
																				
									test_fetch_global_conf_1		:	exec_state <= test_fetch_global_conf_1_tx; // 12 / A1
									test_fetch_global_conf_1_tx	:	exec_state <= test_fetch_global_conf_1_done; // A1 / 13
									test_fetch_global_conf_1_done	:
																				begin // 13
																					if (!im_ready) exec_state <= test_fetch_global_conf_2; //14
																						else exec_state <= test_fetch_global_conf_1_done; //13
																				end
									
									test_fetch_global_conf_2		:	exec_state <= test_fetch_global_conf_2_tx;	// 14 / A2
									test_fetch_global_conf_2_tx	:	exec_state <= test_fetch_global_conf_2_done; // A2 / 15
									test_fetch_global_conf_2_done	:	begin // 15
																					if (!im_ready) exec_state <= test_fetch_global_conf_3; //16
																						else exec_state <= test_fetch_global_conf_2_done; //15
																				end
																				
									test_fetch_global_conf_3		:	exec_state <= test_fetch_global_conf_3_tx;	// 16 / A5
									test_fetch_global_conf_3_tx	:	exec_state <= test_fetch_global_conf_3_done; // A5 / 17
									test_fetch_global_conf_3_done	:	begin // 17
																					if (!im_ready) exec_state <= test_fetch_global_conf_4; //18
																						else exec_state <= test_fetch_global_conf_3_done; //17
																				end
																				
									test_fetch_global_conf_4		:	exec_state <= test_fetch_global_conf_4_tx;	// 18 / A6
									test_fetch_global_conf_4_tx	:	exec_state <= test_fetch_global_conf_4_done; // A6 / 19
									test_fetch_global_conf_4_done	:	begin // 19
																					if (!im_ready) exec_state <= test_fetch_global_conf_5; //1A
																						else exec_state <= test_fetch_global_conf_4_done; //19
																				end
																				
									test_fetch_global_conf_5		:	exec_state <= test_fetch_global_conf_5_tx;	// 1A / A7
									test_fetch_global_conf_5_tx	:	exec_state <= test_fetch_global_conf_5_done; // A7 / 1B
									test_fetch_global_conf_5_done	:	begin // 1B
																					if (!im_ready) exec_state <= test_fetch_global_conf_6; //1C
																						else exec_state <= test_fetch_global_conf_5_done; //1B
																				end

									test_fetch_global_conf_6		:	exec_state <= test_fetch_global_conf_6_tx;	// 1C / A8
									test_fetch_global_conf_6_tx	:	exec_state <= test_fetch_global_conf_6_done; // A8 / 1D
									test_fetch_global_conf_6_done	:	begin // 1D
																					if (!im_ready) exec_state <= test_fetch_global_conf_7; //1E
																						else exec_state <= test_fetch_global_conf_6_done; //1D
																				end

									test_fetch_global_conf_7		:	exec_state <= test_fetch_global_conf_7_tx;	// 1E / A9
									test_fetch_global_conf_7_tx	:	exec_state <= test_fetch_global_conf_7_done; // A9 / 1F
									test_fetch_global_conf_7_done	:	begin // 1F
																					if (!im_ready) exec_state <= test_fetch_global_conf_8; //AA
																						else exec_state <= test_fetch_global_conf_7_done; //1F
																				end

									test_fetch_global_conf_8		:	exec_state <= test_fetch_global_conf_8_tx;	// AA / AB
									test_fetch_global_conf_8_tx	:	exec_state <= test_fetch_global_conf_8_done; // AB / AC
									test_fetch_global_conf_8_done	:	begin // AC
																					if (!im_ready) exec_state <= test_fetch_global_conf_9; //AD
																						else exec_state <= test_fetch_global_conf_8_done; //AC
																				end

									test_fetch_global_conf_9		:	exec_state <= test_fetch_global_conf_9_tx;	// AD / AE
									test_fetch_global_conf_9_tx	:	exec_state <= test_fetch_global_conf_9_done; // AE / AF
									test_fetch_global_conf_9_done	:	begin // AF
																					if (!im_ready) exec_state <= test_fetch_global_conf_10; //B0
																						else exec_state <= test_fetch_global_conf_9_done; //AF
																				end

									test_fetch_global_conf_10			:	exec_state <= test_fetch_global_conf_10_tx;	// B0 / B1
									test_fetch_global_conf_10_tx		:	exec_state <= test_fetch_global_conf_10_done; // B1 / B2
									test_fetch_global_conf_10_done	:	begin // B2
																					if (!im_ready) exec_state <= test_fetch_global_conf_done; //20
																						else exec_state <= test_fetch_global_conf_10_done; //B2
																				end


									test_fetch_global_conf_done 		:	exec_state <= test_fetch_step; //20 / 2B

									// pause here if step width is sxr_step
									test_fetch_step					: 	if ((!go_step & mode[3:0] == sxr_step) | mode[3:0] != sxr_step) exec_state <= test_fetch_id;
																				else exec_state <= exec_state;

									test_fetch_id					: 	exec_state <= test_fetch_id_0; //2C
									test_fetch_id_0					: 	exec_state <= test_fetch_id_0_done; //2E
									test_fetch_id_0_done			: 	exec_state <= test_fetch_id_1;
									test_fetch_id_1					:	exec_state <= test_fetch_id_1_done;
									test_fetch_id_1_done			:	exec_state <= test_fetch_id_done;
									test_fetch_id_done				:	
																	begin  //31h
																		if (step_id == 16'h0000) exec_state <= test_fetch_low_level_cmd;
																		else exec_state <= test_fetch_sxr; //3A
																	end

									test_fetch_low_level_cmd					:	exec_state <= test_fetch_low_level_cmd_type;
									test_fetch_low_level_cmd_type				:	exec_state <= test_fetch_low_level_cmd_type_done;
									test_fetch_low_level_cmd_type_done			:	exec_state <= test_fetch_low_level_cmd_chain_number;
									test_fetch_low_level_cmd_chain_number		:	exec_state <= test_fetch_low_level_cmd_chain_number_done;
									test_fetch_low_level_cmd_chain_number_done	: 	begin //36
																						if (ram_data == 8'h01) exec_state <= test_fetch_low_level_cmd_cmd;
																						else exec_state <= test_done; //test done if chain id greater than 01 found
																					end
									test_fetch_low_level_cmd_cmd				: 	exec_state <= test_fetch_low_level_cmd_cmd_done; //38

		//////////
									test_fetch_low_level_cmd_cmd_done			: 	
																								exec_state <= test_fetch_low_level_cmd_done; //39
																								//else exec_state <= exec_state;
		////////																						
									test_fetch_low_level_cmd_done	: 	begin // loop here until low level command executed by: tap controller, timer or I2C-master
																					//	exec_state <= test_fetch_step; //2B
																					//if (tap_ready == 0) exec_state <= test_fetch_step; // run low level command here
																					if (llc_done == 0) exec_state <= test_fetch_step; // run low level command here
																						else exec_state <= test_fetch_low_level_cmd_done;
																				end

									test_fetch_sxr							:	exec_state <= test_fetch_sxr_type; //3B
									test_fetch_sxr_type						:	exec_state <= test_fetch_sxr_type_done;
									test_fetch_sxr_type_done				:	exec_state <= test_fetch_sxr_chain;
									test_fetch_sxr_chain					:	exec_state <= test_fetch_sxr_chain_done; //3E
									test_fetch_sxr_chain_done				:	begin
																					if (ram_data == 8'h01) exec_state <= test_fetch_sxr_chain_1_length_0;
																					else exec_state <= test_done;
																				end
									test_fetch_sxr_chain_1_length_0			:	exec_state <= test_fetch_sxr_chain_1_length_0_done;
									test_fetch_sxr_chain_1_length_0_done	:	exec_state <= test_fetch_sxr_chain_1_length_1;
									test_fetch_sxr_chain_1_length_1			:	exec_state <= test_fetch_sxr_chain_1_length_1_done;
									test_fetch_sxr_chain_1_length_1_done	:	exec_state <= test_fetch_sxr_chain_1_length_2;
									test_fetch_sxr_chain_1_length_2			:	exec_state <= test_fetch_sxr_chain_1_length_2_done;
									test_fetch_sxr_chain_1_length_2_done	:	exec_state <= test_fetch_sxr_chain_1_length_3;
									test_fetch_sxr_chain_1_length_3			:	exec_state <= test_fetch_sxr_chain_1_length_3_done;
									test_fetch_sxr_chain_1_length_3_done	:	begin	//46h
																					if (chain_ct == 8'h01) exec_state <= test_calc_byte_ct_chain_1;
																					else exec_state <= test_fetch_sxr_chain_2_length_0;
																				end

									test_fetch_sxr_chain_2_length_0			:	exec_state <= test_fetch_sxr_chain_2_length_0_done;
									test_fetch_sxr_chain_2_length_0_done	:	exec_state <= test_fetch_sxr_chain_2_length_1;
									test_fetch_sxr_chain_2_length_1			:	exec_state <= test_fetch_sxr_chain_2_length_1_done;
									test_fetch_sxr_chain_2_length_1_done	:	exec_state <= test_fetch_sxr_chain_2_length_2;
									test_fetch_sxr_chain_2_length_2			:	exec_state <= test_fetch_sxr_chain_2_length_2_done;
									test_fetch_sxr_chain_2_length_2_done	:	exec_state <= test_fetch_sxr_chain_2_length_3;
									test_fetch_sxr_chain_2_length_3			:	exec_state <= test_fetch_sxr_chain_2_length_3_done;
									test_fetch_sxr_chain_2_length_3_done	:	exec_state <= test_calc_byte_ct_chain_1;  //4E, 4F

									test_calc_byte_ct_chain_1				:	exec_state <= test_calc_byte_ct_chain_1_done;
									test_calc_byte_ct_chain_1_done			:	begin
																					if (remainder_chain_1 > 3'b000) exec_state <= test_inc_byte_ct_chain_1;
																					else exec_state <= test_calc_byte_ct_chain_2;
																				end
									test_inc_byte_ct_chain_1				:	exec_state <= test_inc_byte_ct_chain_1_done;
									test_inc_byte_ct_chain_1_done			:	begin
																				//	if (chain_ct == 8'h01) exec_state <= test_calc_offset_chain_1;
																					exec_state <= test_calc_byte_ct_chain_2;
																				end



									test_calc_byte_ct_chain_2				:	exec_state <= test_calc_byte_ct_chain_2_done;
									test_calc_byte_ct_chain_2_done			:	begin
																					if (remainder_chain_2 > 3'b000) exec_state <= test_inc_byte_ct_chain_2;
																					else exec_state <= test_calc_offset_chain_1;
																				end
									test_inc_byte_ct_chain_2				:	exec_state <= test_inc_byte_ct_chain_2_done; //57
									test_inc_byte_ct_chain_2_done			:	exec_state <= test_calc_offset_chain_1; //65

									test_calc_offset_chain_1				:	exec_state <= test_calc_offset_chain_2; //66
									test_calc_offset_chain_2				:	exec_state <= test_fetch_vector_chain_1; //53



									//fetch netto data: drive, mask, expect / bytewise
									test_fetch_vector_chain_1				:	begin
																					if (byte_ct_chain_1 == 32'h00000000) exec_state <= test_fetch_vector_chain_2;
																					else exec_state <= test_fetch_vector_chain_1_drv; //59
																				end
									test_fetch_vector_chain_1_drv			:	exec_state <= test_fetch_vector_chain_1_drv_done; //5A
									test_fetch_vector_chain_1_drv_done		:	exec_state <= test_fetch_vector_chain_1_mask;
									test_fetch_vector_chain_1_mask			:	exec_state <= test_fetch_vector_chain_1_mask_done;
									test_fetch_vector_chain_1_mask_done		:	exec_state <= test_fetch_vector_chain_1_exp;
									test_fetch_vector_chain_1_exp			:	exec_state <= test_fetch_vector_chain_1_exp_done; //byte_ct -1
									test_fetch_vector_chain_1_exp_done		:	exec_state <= test_fetch_vector_chain_2; //58



									test_fetch_vector_chain_2				:	begin //if no chain 2 data present, byte_ct_chain_2 = 0
																					if (byte_ct_chain_2 == 32'h00000000) exec_state <= test_vector_segments_ready;
																					else exec_state <= test_fetch_vector_chain_2_drv; //5F
																				end
									test_fetch_vector_chain_2_drv			:	exec_state <= test_fetch_vector_chain_2_drv_done;
									test_fetch_vector_chain_2_drv_done		:	exec_state <= test_fetch_vector_chain_2_mask;
									test_fetch_vector_chain_2_mask			:	exec_state <= test_fetch_vector_chain_2_mask_done;
									test_fetch_vector_chain_2_mask_done		:	exec_state <= test_fetch_vector_chain_2_exp;
									test_fetch_vector_chain_2_exp			:	exec_state <= test_fetch_vector_chain_2_exp_done; //byte_ct -1
									test_fetch_vector_chain_2_exp_done		:	exec_state <= test_vector_segments_ready; 


									test_vector_segments_ready				:	//exec_state <= test_vector_segments_ready; //67
																				begin // loop here until tap_controller has processed current vector segments
																				
																					if (!fail_x) 
																						begin
																							case (sxr_type)  // sxr type determines what to do on !fail_x 
																								sdr_default,
																								sir_default				:	exec_state <= test_fail_hstrst_init; // F8 , ins V0.4
																								sdr_on_fail_pwr_off,
																								sir_on_fail_pwr_off	:	exec_state <= test_fail_pwr_off; // F7
																								default					: 	exec_state <= test_fail_pwr_off; // F7 , ins V0.4
																							endcase
																						end
																					else
																						//if (tap_ready == 0) exec_state <= test_check_byte_counts;
																						if (llc_done == 0) exec_state <= test_check_byte_counts; //if tap ready llc_done goes L
																						else exec_state <= test_vector_segments_ready;
																				end
									test_check_byte_counts					:	//68
																				begin
																					// vector execution done if all chain byte counts are zero
																					if ((byte_ct_chain_1 == 0) & (byte_ct_chain_2 == 0)) exec_state <= test_fetch_sxr_done; //69
																					else exec_state <= test_fetch_vector_chain_1; // 53h // otherwise fetch next vector segments
																				end

									test_fetch_sxr_done						:	exec_state <= test_fetch_step; //2B  // fetch next test step

									error											: 	exec_state <= error;
									
									test_fail_hstrst_init					: 	exec_state <= test_fail_hstrst_ready;
									test_fail_hstrst_ready					:	begin // loop here until low level command hstrst executed by tap controller																				//	exec_state <= test_fetch_step; //2B
																								//if (tap_ready == 0) exec_state <= test_fetch_step; // run low level command here
																							if (llc_done == 0) exec_state <= test_fail; // run low level command here
																							else exec_state <= test_fail_hstrst_ready;
																						end
									
									
									test_fail_pwr_off							:	exec_state <= test_fail_set_muxer_pwr_off; // F7, F3
									test_fail_set_muxer_pwr_off			:	exec_state <= test_fail_set_muxer_pwr_off_done; // F3, F4
									test_fail_set_muxer_pwr_off_done		:	// F4
																						begin
																							if (!im_ready) exec_state <= test_fail_all_pwr_relays_off; //F5
																							else exec_state <= test_fail_set_muxer_pwr_off_done; //F4
																						end
									test_fail_all_pwr_relays_off			:	exec_state <= test_fail_all_pwr_relays_off_done; // F5, F6
									test_fail_all_pwr_relays_off_done	:
																						begin
																							if (!im_ready) exec_state <= test_fail_disconnect_port_1; // F0
																							else exec_state <= test_fail_all_pwr_relays_off_done; //F6
																						end

									test_fail_disconnect_port_1			:	exec_state <= test_fail_disconnect_port_1_done; // F0, F1
									test_fail_disconnect_port_1_done		: // F1
																						begin
																							if (!im_ready) exec_state <= test_fail_disconnect_port_2; // F2
																							else exec_state <= test_fail_disconnect_port_1_done; // F1
																						end
									test_fail_disconnect_port_2			:	exec_state <= test_fail_disconnect_port_2_done; // F2, F3
									test_fail_disconnect_port_2_done		:  // F3
																						begin
																							if (!im_ready) exec_state <= test_fail; // FA
																							else exec_state <= test_fail_disconnect_port_2_done; // F3
																						end
																						
																		
									
									default : exec_state <= idle;
								endcase
							end

						8'hFF		: exec_state <= disabled;
	
						default 	: exec_state <= idle;

					endcase
				end
		end



	always @(negedge clk)  //(exec_state)
		begin
			case (exec_state)

				debug1 :
					begin
						addr[26:3] <= start_addr[23:0];	// preload address register (from rf 83-81h)
						addr[2:0] <= mode[2:0];			// preload bit address (from 84h)
						active <= 1'b0;
						run <= 1'b1;
					end

				test_start :
					begin
						active <= 1'b0;
						run <= 1'b0;
						sxr_type <= 8'h0;
						sxr_length_chain_1 <= 32'h0;
						sxr_length_chain_2 <= 32'h0;
						fail_any_chain <= 1'b0;
						pass <= 0;
					end

				test_done :
					begin
						//active <= 1'b0;
						pass <= 1;
						run <= 1'b1;
					end

				test_fail_pwr_off:
					begin
						uut_pwr_on_1 <= 1; // L active !
						uut_pwr_on_2 <= 1; // L active !						
					end

				test_fail_hstrst_init :  // ins V0.1
					begin
						low_level_cmd_type <= tap_operation; //set llct 
						low_level_cmd_cmd <= hs_trst;			// set llcc hstrst	
					end

				test_fail_set_muxer_pwr_off	:  // F3
					begin
						im_data_tx_ct <= 0; // one data byte is to tx
						im_data_tx_1 <= enable_bus_2_data; 
						im_addr <= muxer_addr;
						im_start <= 0; // starts i2c master						
					end
				test_fail_set_muxer_pwr_off_done	: im_start <= 1; // reset i2c master start signal  //F4

				test_fail_all_pwr_relays_off	:  // F5
					begin
						im_data_tx_ct <= 0; // one data byte is to tx
						im_data_tx_1 <= pwr_relay_off_all_data; 
						im_addr <= pwr_relays_addr;
						im_start <= 0; // starts i2c master						
					end
				test_fail_all_pwr_relays_off_done	: im_start <= 1; // reset i2c master start signal  //F6


				test_fail_disconnect_port_1	:	//F0
					begin
						im_data_tx_ct <= 0; // one data byte is to tx
						im_data_tx_1 <= rel_tap_1_all_off_data; 
						im_addr <= rel_tap_1_addr;
						im_start <= 0; // starts i2c master						
					end
				test_fail_disconnect_port_1_done	:	im_start <= 1;	// F1

				test_fail_disconnect_port_2	:	//F2
					begin
						im_data_tx_ct <= 0; // one data byte is to tx
						im_data_tx_1 <= rel_tap_2_all_off_data; 
						im_addr <= rel_tap_2_addr;
						im_start <= 0; // starts i2c master						
					end
				test_fail_disconnect_port_2_done	:	im_start <= 1;	// F3


				test_fail :
					begin
						fail_any_chain <= 1'b1;
						pass <= 0;						
					end

				test_fetch_chain_ct :
					begin
						addr[26:3] <= start_addr[23:0];	// fetch start adddress from address register (from rf 83-81h)
						addr[2:0] <= 3'b000;			// set bit address to 000b
					end

				test_fetch_chain_ct_done 			: chain_ct <= ram_data;


				test_fetch_chain_1_base_addr_0 		: addr[26:3] <= addr[26:3] + 1;
				test_fetch_chain_1_base_addr_0_done : chain_1_base_addr[7:0] <= ram_data;

				test_fetch_chain_1_base_addr_1		: addr[26:3] <= addr[26:3] + 1;
				test_fetch_chain_1_base_addr_1_done	: chain_1_base_addr[15:8] <= ram_data;		

				test_fetch_chain_1_base_addr_2 		: addr[26:3] <= addr[26:3] + 1;
				test_fetch_chain_1_base_addr_2_done : chain_1_base_addr[23:16] <= ram_data;		

				test_fetch_chain_1_base_addr_3 		: addr[26:3] <= addr[26:3] + 1;
				test_fetch_chain_1_base_addr_3_done : chain_1_base_addr[31:24] <= ram_data;		


				test_fetch_chain_2_base_addr_0 		: addr[26:3] <= addr[26:3] + 1;
				test_fetch_chain_2_base_addr_0_done : chain_2_base_addr[7:0] <= ram_data;

				test_fetch_chain_2_base_addr_1		: addr[26:3] <= addr[26:3] + 1;
				test_fetch_chain_2_base_addr_1_done	: chain_2_base_addr[15:8] <= ram_data;		

				test_fetch_chain_2_base_addr_2 		: addr[26:3] <= addr[26:3] + 1;
				test_fetch_chain_2_base_addr_2_done : chain_2_base_addr[23:16] <= ram_data;		

				test_fetch_chain_2_base_addr_3 		: addr[26:3] <= addr[26:3] + 1;
				test_fetch_chain_2_base_addr_3_done : chain_2_base_addr[31:24] <= ram_data;		




				test_fetch_global_conf_0			: addr[26:3] <= addr[26:3] + 1;
				test_fetch_global_conf_0_done		: glob_conf_0 <= ram_data;

				test_set_i2c_muxer					:	// A3
					begin
						im_data_tx_ct <= 0; // one data byte is to tx
						im_data_tx_1 <= enable_bus_1_data; //fmr enable_bus_0_data , changed in V0.4
						im_addr <= muxer_addr;
						im_start <= 0; // starts i2c master						
					end
				test_set_i2c_muxer_done				: im_start <= 1; // reset i2c master start signal  //A4

				test_fetch_global_conf_1			: addr[26:3] <= addr[26:3] + 1; // 12
				test_fetch_global_conf_1_tx		: //A1
					begin
						im_addr <= cmp_tdi_1_addr;
						im_data_tx_ct <= 1; // transfer dac_cmd byte, then dac output value red from RAM	
						im_data_tx_1 <= dac_cmd;					
						im_data_tx_2 <= ram_data;
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_1_done		: im_start <= 1; // reset i2c master start signal  //13

				
				test_fetch_global_conf_2			: addr[26:3] <= addr[26:3] + 1; //14
				test_fetch_global_conf_2_tx		: //A2
					begin
						im_addr <= cmp_tdi_2_addr;
						im_data_tx_ct <= 1; // transfer dac_cmd byte, then dac output value red from RAM	
						im_data_tx_1 <= dac_cmd;					
						im_data_tx_2 <= ram_data;
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_2_done		: im_start <= 1; // reset i2c master start signal  //15


				test_fetch_global_conf_3			: addr[26:3] <= addr[26:3] + 1; // 16
				test_fetch_global_conf_3_tx		: //A5
					begin
						im_addr <= vcc_tap_1_addr;
						im_data_tx_ct <= 1; // transfer dac_cmd byte, then dac output value red from RAM	
						im_data_tx_1 <= dac_cmd;					
						im_data_tx_2 <= ram_data;
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_3_done		: im_start <= 1; // reset i2c master start signal  //17

				
				test_fetch_global_conf_4			: addr[26:3] <= addr[26:3] + 1; //18
				test_fetch_global_conf_4_tx		: //A6
					begin
						im_addr <= vcc_tap_2_addr;
						im_data_tx_ct <= 1; // transfer dac_cmd byte, then dac output value red from RAM	
						im_data_tx_1 <= dac_cmd;					
						im_data_tx_2 <= ram_data;
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_4_done		: im_start <= 1; // reset i2c master start signal  //19


				test_fetch_global_conf_5			: addr[26:3] <= addr[26:3] + 1; //1A
				test_fetch_global_conf_5_tx		: //A7
					begin
						im_addr <= drv_char_1_tck_tms_addr;
						im_data_tx_ct <= 0; // transfer only one byte (drive char. tck1, tms1)
						im_data_tx_1 <= ram_data;					
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_5_done		: im_start <= 1; // reset i2c master start signal  //1B


				test_fetch_global_conf_6			: addr[26:3] <= addr[26:3] + 1; //1C
				test_fetch_global_conf_6_tx		: //A8
					begin
						im_addr <= drv_char_1_tdo_trst_addr;
						im_data_tx_ct <= 0; // transfer only one byte (drive char. tdo1, trst1)	
						im_data_tx_1 <= ram_data;					
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_6_done		: im_start <= 1; // reset i2c master start signal  //1D


				test_fetch_global_conf_7			: addr[26:3] <= addr[26:3] + 1; //1E
				test_fetch_global_conf_7_tx		: //A9
					begin
						im_addr <= drv_char_2_tck_tms_addr;
						im_data_tx_ct <= 0; // transfer only one byte (drive char. tck2, tms2)	
						im_data_tx_1 <= ram_data;					
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_7_done		: im_start <= 1; // reset i2c master start signal  //1F

				test_fetch_global_conf_8			: addr[26:3] <= addr[26:3] + 1; //AA
				test_fetch_global_conf_8_tx		: //AB
					begin
						im_addr <= drv_char_2_tdo_trst_addr;
						im_data_tx_ct <= 0; // transfer only one byte (drive char. tdo2, trst2)	
						im_data_tx_1 <= ram_data;					
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_8_done		: im_start <= 1; // reset i2c master start signal  //AC


				test_fetch_global_conf_9			: addr[26:3] <= addr[26:3] + 1; //AD
				test_fetch_global_conf_9_tx		: //AE
					begin
						im_addr <= rel_tap_1_addr;
						im_data_tx_ct <= 0; // transfer only one byte (relay switching port1)
						im_data_tx_1 <= ram_data;					
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_9_done		: im_start <= 1; // reset i2c master start signal  //AF

				test_fetch_global_conf_10			: addr[26:3] <= addr[26:3] + 1; //B0
				test_fetch_global_conf_10_tx		: //B1
					begin
						im_addr <= rel_tap_2_addr;
						im_data_tx_ct <= 0; // transfer only one byte (relay switching port2)	
						im_data_tx_1 <= ram_data;					
						im_start <= 0; // starts i2c master
					end
				test_fetch_global_conf_10_done		: im_start <= 1; // reset i2c master start signal  //B2


				test_fetch_id_0						: 	begin
															addr[26:3] <= addr[26:3] + 1;
															chain_2_base_addr <= chain_2_base_addr + 1;
														end
				test_fetch_id_0_done				: step_id[7:0] <= ram_data;
				test_fetch_id_1						: 	begin
															addr[26:3] <= addr[26:3] + 1;
															chain_2_base_addr <= chain_2_base_addr + 1;
														end
				test_fetch_id_1_done				: step_id[15:8] <= ram_data;

				test_fetch_low_level_cmd_chain_number		: 	begin
																	addr[26:3] <= addr[26:3] + 1;
																	chain_2_base_addr <= chain_2_base_addr + 1;
																end

				test_fetch_low_level_cmd_type				:	begin
																	addr[26:3] <= addr[26:3] + 1;
																	chain_2_base_addr <= chain_2_base_addr + 1;
																end
				test_fetch_low_level_cmd_type_done			: low_level_cmd_type <= ram_data;
				test_fetch_low_level_cmd_cmd				: 	begin
																	addr[26:3] <= addr[26:3] + 1;
																	chain_2_base_addr <= chain_2_base_addr + 1;
																end
				test_fetch_low_level_cmd_cmd_done			: low_level_cmd_cmd <= ram_data; //38



				test_fetch_sxr_type							: 	begin
																	addr[26:3] <= addr[26:3] + 1;
																	chain_2_base_addr <= chain_2_base_addr + 1;
																end
				test_fetch_sxr_type_done					: sxr_type <= ram_data;	//3C
				test_fetch_sxr_chain						: 	begin //3D
																	addr[26:3] <= addr[26:3] + 1;
																	chain_2_base_addr <= chain_2_base_addr + 1;
																end
				//test_fetch_sxr_chain_done					: //CS: no need - skipped
				test_fetch_sxr_chain_1_length_0						: addr[26:3] <= addr[26:3] + 1;
				test_fetch_sxr_chain_1_length_0_done				: sxr_length_chain_1[7:0] <= ram_data;
				test_fetch_sxr_chain_1_length_1						: addr[26:3] <= addr[26:3] + 1;
				test_fetch_sxr_chain_1_length_1_done				: sxr_length_chain_1[15:8] <= ram_data;
				test_fetch_sxr_chain_1_length_2						: addr[26:3] <= addr[26:3] + 1;
				test_fetch_sxr_chain_1_length_2_done				: sxr_length_chain_1[23:16] <= ram_data;
				test_fetch_sxr_chain_1_length_3						: addr[26:3] <= addr[26:3] + 1;
				test_fetch_sxr_chain_1_length_3_done				: 	begin  //46
																			sxr_length_chain_1[31:24] <= ram_data;
																			chain_1_base_addr <= addr[26:3];
																		end

				test_fetch_sxr_chain_2_length_0						: addr[26:3] <= chain_2_base_addr[23:0]; //47
				test_fetch_sxr_chain_2_length_0_done				: sxr_length_chain_2[7:0] <= ram_data;
				test_fetch_sxr_chain_2_length_1						: addr[26:3] <= addr[26:3] + 1;
				test_fetch_sxr_chain_2_length_1_done				: sxr_length_chain_2[15:8] <= ram_data;
				test_fetch_sxr_chain_2_length_2						: addr[26:3] <= addr[26:3] + 1;
				test_fetch_sxr_chain_2_length_2_done				: sxr_length_chain_2[23:16] <= ram_data;
				test_fetch_sxr_chain_2_length_3						: addr[26:3] <= addr[26:3] + 1;
				test_fetch_sxr_chain_2_length_3_done				: 	begin  //4E
																			sxr_length_chain_2[31:24] <= ram_data;
																			chain_2_base_addr <= addr[26:3];
																		end
					
				test_calc_byte_ct_chain_1					:	begin
																	byte_ct_chain_1 <= sxr_length_chain_1[31:3];
																	remainder_chain_1 <= sxr_length_chain_1[2:0];
																end
				test_inc_byte_ct_chain_1					: 	byte_ct_chain_1 <= byte_ct_chain_1  + 1;

				test_calc_byte_ct_chain_2					:	begin
																	byte_ct_chain_2 <= sxr_length_chain_2[31:3];
																	remainder_chain_2 <= sxr_length_chain_2[2:0];
																end
				test_inc_byte_ct_chain_2					: 	byte_ct_chain_2 <= byte_ct_chain_2  + 1;


				test_calc_offset_chain_1					:	offset_chain_1 <= byte_ct_chain_1;
				test_fetch_vector_chain_1_drv				:	addr[26:3] <= chain_1_base_addr[23:0] + 1;
				test_fetch_vector_chain_1_drv_done			:	drv_chain_1 <= ram_data;
				test_fetch_vector_chain_1_mask				:	addr[26:3] <= addr[26:3] + offset_chain_1;
				test_fetch_vector_chain_1_mask_done			:	mask_chain_1 <= ram_data;
				test_fetch_vector_chain_1_exp				:	addr[26:3] <= addr[26:3] + offset_chain_1;
				test_fetch_vector_chain_1_exp_done			:	begin
																	exp_chain_1 <= ram_data;
																	chain_1_base_addr <= chain_1_base_addr + 1;
																	byte_ct_chain_1 <= byte_ct_chain_1 - 1;
																end


				test_calc_offset_chain_2					:	offset_chain_2 <= byte_ct_chain_2;
				test_fetch_vector_chain_2_drv				:	addr[26:3] <= chain_2_base_addr[23:0] + 1;
				test_fetch_vector_chain_2_drv_done			:	drv_chain_2 <= ram_data;
				test_fetch_vector_chain_2_mask				:	addr[26:3] <= addr[26:3] + offset_chain_2;
				test_fetch_vector_chain_2_mask_done			:	mask_chain_2 <= ram_data;
				test_fetch_vector_chain_2_exp				:	addr[26:3] <= addr[26:3] + offset_chain_2;
				test_fetch_vector_chain_2_exp_done			:	begin
																	exp_chain_2 <= ram_data;
																	chain_2_base_addr <= chain_2_base_addr + 1;
																	byte_ct_chain_2 <= byte_ct_chain_2  - 1;
																end

				test_fetch_sxr_done							:	begin
																	chain_2_base_addr <= chain_2_base_addr + {offset_chain_2[30:0],1'b1};
																	addr[26:3] <= chain_1_base_addr[23:0] + {offset_chain_1[30:0],1'b0};
																end

				disabled :
					begin
						addr[26:3] <= addr[26:3];
						addr[2:0] <= addr[2:0];
						low_level_cmd_cmd [7:0] <= 8'h00;
						active <= 1'b1;			// ouptut RAM address control by register file
						run <= 1'b1;
						pass <= 0;
						fail_any_chain <= 1'b0;
						im_start <= 1; // keeps i2c master on hold
						uut_pwr_on_1 <= 1; // L active !
						uut_pwr_on_2 <= 1; // L active !						
					end

				idle : 
					begin
						addr[26:3] <= addr[26:3];
						addr[2:0] <= addr[2:0];
						low_level_cmd_cmd [7:0] <= 8'h00;
						active <= 1'b0;
						run <= 1'b1;
						pass <= 0;
						fail_any_chain <= 1'b0;
						im_start <= 1; // keeps i2c master on hold						
						uut_pwr_on_1 <= 1; // L active !
						uut_pwr_on_2 <= 1; // L active !						
					end

				default :
					begin
						addr[26:3] <= addr[26:3];
						addr[2:0] <= addr[2:0];
						//low_level_cmd_cmd [7:0] <= 8'h00;
						active <= 1'b0;
						pass <= 0;						
						fail_any_chain <= 1'b0;						
						im_start <= 1; // keeps i2c master on hold
						uut_pwr_on_1 <= 1; // L active !
						uut_pwr_on_2 <= 1; // L active !						

						//run <= 1'b1;						
					end
			endcase
		end

//	assign debug = chain_1_base_addr[7:0];

endmodule
