`timescale 1ns / 1ps

//`define sim

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:29:33 09/22/2011 
// Design Name: 
// Module Name:    i2c_master 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// V0.1 	- global conf. support
// V0.2 	- llc "connect port 1/2"
//			- frm state idle renamed to im_idle 
//			- compiler directive "sim"
// V0.3	- power up/down llc
// V0.4	- signal start_by_pc is reset on sysreset
//			- init value of start_by_pc set to 1

// V0.5	- imax supported (extended i2c operation with destination dac imax channel x)
// V0.51 - executor state test_fail causes reg pwr_relays_data defaulting to all power relays off
//			  so that on next test start all relays are off

// V0.6	- imax timeout

// V0.7  - SCL clock scaled down by 200 to about 50 khz

//////////////////////////////////////////////////////////////////////////////////
module i2c_master(clk, data_tx_1_ext, data_tx_2_ext, data_ct_ext, addr_ext ,reset,ack_fail,im_ready,sda,scl,start,
						exec_state,llct,llcc);


	input [7:0] exec_state;
	input [7:0] llct;
	input [7:0] llcc;
	
	`include "parameters.v"	

   input clk;
   input [7:0] data_tx_1_ext;
	input [7:0] data_tx_2_ext;
	input data_ct_ext; // number of data bytes to tx , 0 for one byte to tx / 1 for two bytes to tx
   input [7:0] addr_ext;  //NOTE: LSB is r/w bit !
	input reset;
	input start;
   output reg ack_fail;
	output im_ready; 
	reg ready;
	inout sda;
	output scl; // about 65 khz at 12,5Mhz clk

	
	reg ex_llc;
	always @(negedge clk)
		begin		// start low level cmd execution if cmd fetched completely and if type is i2c_operation only
		//	if ((exec_state == test_fetch_low_level_cmd_done) & (llct == i2c_operation)) ex_llc <= 0; // rm V0.5
		//if ((exec_state == test_fetch_low_level_cmd_done) & (llct == i2c_operation | llct == xi2c_operation_imax_1 | llct == xi2c_operation_imax_2 | llct == xi2c_operation_imax_3)) ex_llc <= 0; // ins V0.5  //rm V0.6
		// ins V0.6 begin
			if (exec_state == test_fetch_low_level_cmd_done)
				begin
					case (llct)
						i2c_operation,
						xi2c_operation_imax_1,
						xi2c_operation_imax_2,
						xi2c_operation_imax_3,
						xi2c_operation_imax_timeout_1,
						xi2c_operation_imax_timeout_2,
						xi2c_operation_imax_timeout_3		:	ex_llc <= 0;
						default	: ex_llc <= 1;
					endcase
				end
		// ins V0.6 end
			else ex_llc <= 1;
		end
  
	// shrink ex_llc signal to one clk cycle	
	pulse_maker pm_ex_llc(
		.clk(clk),
		.reset(reset),
		.in(ex_llc), // L active // sampled on posedge of clk
		.out(pc_go) // L active , updated on negedge of clk  -> starts parameter collector state machine
		);  



	reg [7:0] data_tx_1;
	reg [7:0] data_tx_2;
	reg [7:0] addr;
	reg data_ct;
		
	reg [7:0] addr_pc;
	reg [7:0] data_tx_1_pc;
	reg [7:0] data_tx_2_pc;
	reg data_ct_pc;
	reg start_by_pc = 1;	
	
	always @*
		begin
			if (ex_llc) // no llc operation -> data and addr provided externally by executor
				begin
					data_tx_1 <= data_tx_1_ext;
					data_tx_2 <= data_tx_2_ext;
					addr <= addr_ext;
					data_ct <= data_ct_ext;
				end
			else  // if llc operation -> data and addr provided by parameter collector
				begin
					data_tx_1 <= data_tx_1_pc;
					data_tx_2 <= data_tx_2_pc;
					addr <= addr_pc;
					data_ct <= data_ct_pc;
				end
		end	
				

   // parameter collector begin
	parameter pc_idle		= 4'hF;
	parameter pc_run		= 4'h0;
	parameter pc_alu		= 4'h1;
	parameter pc_imax_1	= 4'h2;
	parameter pc_imax_2	= 4'h3;
	parameter pc_imax_3	= 4'h4;	
	parameter pc_imax_timeout_1	= 4'h5; // ins V0.6
	parameter pc_imax_timeout_2	= 4'h6; // ins V0.6
	parameter pc_imax_timeout_3	= 4'h7; // ins V0.6	
	parameter pc_done		= 4'hD;

	reg [3:0] pc;
	always @(posedge clk)
		begin
			if (!reset) pc <= pc_idle;
			else
				case (pc)
					pc_idle	:	begin
										if (!pc_go)
											begin
												case (llct)
													i2c_operation				:	pc <= pc_alu;
													xi2c_operation_imax_1	: 	pc <= pc_imax_1;
													xi2c_operation_imax_2	: 	pc <= pc_imax_2;
													xi2c_operation_imax_3	: 	pc <= pc_imax_3;
													xi2c_operation_imax_timeout_1	:	pc <= pc_imax_timeout_1; // ins V0.6
													xi2c_operation_imax_timeout_2	:	pc <= pc_imax_timeout_2; // ins V0.6
													xi2c_operation_imax_timeout_3	:	pc <= pc_imax_timeout_3; // ins V0.6													
													default						:	pc <= pc_idle;
												endcase
											end
									end
					pc_alu	:	pc <= pc_run;
					pc_run	:	pc <= pc_done;
					pc_done	:	pc <= pc_idle;
					
					//pc_imax_1, pc_imax_2, pc_imax_3 :	pc <= pc_done; // rm v0.6
					//ins V0.6 begin
					pc_imax_1,
					pc_imax_2,
					pc_imax_3,
					pc_imax_timeout_1,
					pc_imax_timeout_2,
					pc_imax_timeout_3		:	pc <= pc_done;
					//ins V0.6 end
				endcase
		end

	reg [7:0] pwr_relays_data;
	
	always @(negedge clk)
		begin
			//if (!reset) //rm V0.51
			if (!reset | exec_state == test_fail)  // ins V0.51
				begin
					pwr_relays_data <= pwr_relay_off_all_data;
					start_by_pc <= 1;  // ins V0.4
				end
			else
			case (pc)
				pc_alu	:	begin
									case (llcc)
										pwr_relay_on_1		:	pwr_relays_data <= pwr_relays_data & pwr_relay_on_1_data;
										pwr_relay_on_2		:	pwr_relays_data <= pwr_relays_data & pwr_relay_on_2_data;
										pwr_relay_on_3		:	pwr_relays_data <= pwr_relays_data & pwr_relay_on_3_data;
										pwr_relay_on_all	:	pwr_relays_data <= pwr_relays_data & pwr_relay_on_all_data;
										pwr_relay_on_gnd	:	pwr_relays_data <= pwr_relays_data & pwr_relay_on_gnd_data;	

										pwr_relay_off_1	:	pwr_relays_data <= pwr_relays_data | pwr_relay_off_1_data;
										pwr_relay_off_2	:	pwr_relays_data <= pwr_relays_data | pwr_relay_off_2_data;
										pwr_relay_off_3	:	pwr_relays_data <= pwr_relays_data | pwr_relay_off_3_data;
										pwr_relay_off_all	:	pwr_relays_data <= pwr_relays_data | pwr_relay_off_all_data;
										pwr_relay_off_gnd	:	pwr_relays_data <= pwr_relays_data | pwr_relay_off_gnd_data;	
										
									endcase				
								end
								
				pc_run	:	begin
									data_ct_pc <= 0; // prepare for one data byte to be transferred
									case (llcc)
										//connect_port_1,
										//disconnect_port_1	: 	addr_pc <= rel_tap_1_addr;
										
										connect_port_1		:	begin
																		addr_pc <= rel_tap_1_addr;
																		data_tx_1_pc <= 8'hFC;	// relay gnd, tap on // CS: dio, aio ?
																	end
																	
										disconnect_port_1	:	begin
																		addr_pc <= rel_tap_1_addr;
																		data_tx_1_pc <= 8'hFF;	// all relays off										
																	end	

										connect_port_2		:	begin
																		addr_pc <= rel_tap_2_addr;
																		data_tx_1_pc <= 8'hFC;	// relay gnd, tap on // CS: dio, aio ?
																	end
																	
										disconnect_port_2	:	begin
																		addr_pc <= rel_tap_2_addr;
																		data_tx_1_pc <= 8'hFF;	// all relays off										
																	end	

										set_muxer_sub_bus_1	:	begin
																			addr_pc <= muxer_addr;
																			data_tx_1_pc <= enable_bus_1_data;										
																		end	

										set_muxer_sub_bus_2	:	begin
																			addr_pc <= muxer_addr;
																			data_tx_1_pc <= enable_bus_2_data;										
																		end	

										set_muxer_sub_bus_3	:	begin
																			addr_pc <= muxer_addr;
																			data_tx_1_pc <= enable_bus_3_data;										
																		end

										set_muxer_sub_bus_4	:	begin
																			addr_pc <= muxer_addr;
																			data_tx_1_pc <= enable_bus_4_data;										
																		end

										pwr_relay_on_1,
										pwr_relay_on_2,
										pwr_relay_on_3,
										pwr_relay_on_gnd,								
										pwr_relay_on_all,

										pwr_relay_off_1,
										pwr_relay_off_2,
										pwr_relay_off_3,
										pwr_relay_off_gnd,								
										pwr_relay_off_all
																	:	begin
																			addr_pc <= pwr_relays_addr;
																			data_tx_1_pc <= pwr_relays_data;										
																		end

									endcase
								end
								
				pc_imax_1	:	begin
										addr_pc <= address_imax_dac_1;
										data_ct_pc <= 1; // prepare for two data bytes to be transferred
										data_tx_1_pc <= command_byte_imax_dac;
										data_tx_2_pc <= llcc;  // analog value to output by dac
									end
				pc_imax_2	:	begin
										addr_pc <= address_imax_dac_2;
										data_ct_pc <= 1; // prepare for two data bytes to be transferred
										data_tx_1_pc <= command_byte_imax_dac;
										data_tx_2_pc <= llcc;  // analog value to output by dac
									end
				pc_imax_3	:	begin
										addr_pc <= address_imax_dac_3;
										data_ct_pc <= 1; // prepare for two data bytes to be transferred
										data_tx_1_pc <= command_byte_imax_dac;
										data_tx_2_pc <= llcc;  // analog value to output by dac
									end
									
				// ins V0.6 begin
				pc_imax_timeout_1	:
									begin
										addr_pc <= imax_timeout_1_adr;
										data_ct_pc <= 0; // prepare for one data bytes to be transferred
										data_tx_1_pc <= llcc; // timeout value for imax 
									end
				pc_imax_timeout_2	:
									begin
										addr_pc <= imax_timeout_2_adr;
										data_ct_pc <= 0; // prepare for one data bytes to be transferred
										data_tx_1_pc <= llcc; // timeout value for imax 
									end
				pc_imax_timeout_3	:
									begin
										addr_pc <= imax_timeout_3_adr;
										data_ct_pc <= 0; // prepare for one data bytes to be transferred
										data_tx_1_pc <= llcc; // timeout value for imax 
									end									
				// ins V0.6 end

				pc_done		: 	start_by_pc <= 0;
				default		: 	begin
										start_by_pc <= 1;
									end
			endcase
		end
					
   // parameter collector end






					

	parameter ackn_error				= 7'h7E;			
	parameter im_idle					= 7'h7F;
	parameter tx_done					= 7'h7D;
	parameter start_a					= 7'h00;
	parameter start_b					= 7'h01;
	parameter stop_a					= 7'h02;
	parameter stop_b					= 7'h03;
	parameter stop_c					= 7'h04;	

	parameter tx_bit_6_addr_a		= 7'h05;
	parameter tx_bit_6_addr_b		= 7'h06;	
	parameter tx_bit_6_addr_c		= 7'h07;		
	parameter tx_bit_5_addr_a		= 7'h08;
	parameter tx_bit_5_addr_b		= 7'h09;	
	parameter tx_bit_5_addr_c		= 7'h0A;		
	parameter tx_bit_4_addr_a		= 7'h0B;
	parameter tx_bit_4_addr_b		= 7'h0C;
	parameter tx_bit_4_addr_c		= 7'h0D;	
	parameter tx_bit_3_addr_a		= 7'h0E;
	parameter tx_bit_3_addr_b		= 7'h0F;
	parameter tx_bit_3_addr_c		= 7'h10;	
	parameter tx_bit_2_addr_a		= 7'h11;
	parameter tx_bit_2_addr_b		= 7'h12;
	parameter tx_bit_2_addr_c		= 7'h13;	
	parameter tx_bit_1_addr_a		= 7'h14;
	parameter tx_bit_1_addr_b		= 7'h15;
	parameter tx_bit_1_addr_c		= 7'h16;	
	parameter tx_bit_0_addr_a		= 7'h17;
	parameter tx_bit_0_addr_b		= 7'h18;
	parameter tx_bit_0_addr_c		= 7'h19;	
	parameter tx_rw_bit_a			= 7'h1A;
	parameter tx_rw_bit_b			= 7'h1B;
	parameter tx_rw_bit_c			= 7'h1C;	
	parameter rx_addr_ack_bit_a	= 7'h1D;
	parameter rx_addr_ack_bit_b	= 7'h1E;
	parameter rx_addr_ack_bit_c	= 7'h1F;	

	parameter tx_bit_7_data_1_a		= 7'h20;
	parameter tx_bit_7_data_1_b		= 7'h21;
	parameter tx_bit_7_data_1_c		= 7'h22;	
	parameter tx_bit_6_data_1_a		= 7'h23;
	parameter tx_bit_6_data_1_b		= 7'h24;
	parameter tx_bit_6_data_1_c		= 7'h25;	
	parameter tx_bit_5_data_1_a		= 7'h26;
	parameter tx_bit_5_data_1_b		= 7'h27;
	parameter tx_bit_5_data_1_c		= 7'h28;	
	parameter tx_bit_4_data_1_a		= 7'h29;
	parameter tx_bit_4_data_1_b		= 7'h2A;
	parameter tx_bit_4_data_1_c		= 7'h2B;	
	parameter tx_bit_3_data_1_a		= 7'h2C;
	parameter tx_bit_3_data_1_b		= 7'h2D;
	parameter tx_bit_3_data_1_c		= 7'h2E;	
	parameter tx_bit_2_data_1_a		= 7'h2F;
	parameter tx_bit_2_data_1_b		= 7'h30;
	parameter tx_bit_2_data_1_c		= 7'h31;	
	parameter tx_bit_1_data_1_a		= 7'h32;
	parameter tx_bit_1_data_1_b		= 7'h33;
	parameter tx_bit_1_data_1_c		= 7'h34;	
	parameter tx_bit_0_data_1_a		= 7'h35;
	parameter tx_bit_0_data_1_b		= 7'h36;
	parameter tx_bit_0_data_1_c		= 7'h37;	
	parameter rx_data_1_ack_bit_a		= 7'h38;
	parameter rx_data_1_ack_bit_b		= 7'h39;
	parameter rx_data_1_ack_bit_c		= 7'h3A;	

	parameter tx_bit_7_data_2_a		= 7'h3B;
	parameter tx_bit_7_data_2_b		= 7'h3C;
	parameter tx_bit_7_data_2_c		= 7'h3E;	
	parameter tx_bit_6_data_2_a		= 7'h3F;
	parameter tx_bit_6_data_2_b		= 7'h40;
	parameter tx_bit_6_data_2_c		= 7'h41;	
	parameter tx_bit_5_data_2_a		= 7'h42;
	parameter tx_bit_5_data_2_b		= 7'h43;
	parameter tx_bit_5_data_2_c		= 7'h44;	
	parameter tx_bit_4_data_2_a		= 7'h45;
	parameter tx_bit_4_data_2_b		= 7'h46;
	parameter tx_bit_4_data_2_c		= 7'h47;	
	parameter tx_bit_3_data_2_a		= 7'h48;
	parameter tx_bit_3_data_2_b		= 7'h49;
	parameter tx_bit_3_data_2_c		= 7'h4A;	
	parameter tx_bit_2_data_2_a		= 7'h4B;
	parameter tx_bit_2_data_2_b		= 7'h4C;
	parameter tx_bit_2_data_2_c		= 7'h4D;	
	parameter tx_bit_1_data_2_a		= 7'h4E;
	parameter tx_bit_1_data_2_b		= 7'h4F;
	parameter tx_bit_1_data_2_c		= 7'h50;	
	parameter tx_bit_0_data_2_a		= 7'h51;
	parameter tx_bit_0_data_2_b		= 7'h52;
	parameter tx_bit_0_data_2_c		= 7'h53;	
	parameter rx_data_2_ack_bit_a		= 7'h54;
	parameter rx_data_2_ack_bit_b		= 7'h55;
	parameter rx_data_2_ack_bit_c		= 7'h56;	

	
	reg [6:0] state;
	//reg [4:0] timer; // scales clk down by 100 // rm V0.7
	reg [5:0] timer; // scales clk down by 200  // ins V0.7
	reg timeout;
	always @(timer)
		begin
			if (timer == 0) timeout <= 0;
				else timeout <= 1;
		end
		
		
	
	always @(posedge clk)
		begin
			if (!reset) state <= im_idle;
			else
				begin
					case (state)
						im_idle				: 	//state <= im_idle;
													begin
														if (!start | !start_by_pc) state <= start_a;
														//if (!start) state <= start_a;
														else state <= im_idle;
													end
						start_a 				: 	begin
														if (!timeout) state <= start_b;
															else state <= state;
													end
						
						// address transfer
						start_b				: if (!timeout) state <= tx_bit_6_addr_a; 
						
						tx_bit_6_addr_a	: if (!timeout) state <= tx_bit_6_addr_b;
						tx_bit_6_addr_b	: if (!timeout) state <= tx_bit_6_addr_c;
						tx_bit_6_addr_c	: if (!timeout) state <= tx_bit_5_addr_a;						
						
						tx_bit_5_addr_a	: if (!timeout) state <= tx_bit_5_addr_b;
						tx_bit_5_addr_b	: if (!timeout) state <= tx_bit_5_addr_c;
						tx_bit_5_addr_c	: if (!timeout) state <= tx_bit_4_addr_a;

						tx_bit_4_addr_a	: if (!timeout) state <= tx_bit_4_addr_b;
						tx_bit_4_addr_b	: if (!timeout) state <= tx_bit_4_addr_c;
						tx_bit_4_addr_c	: if (!timeout) state <= tx_bit_3_addr_a;						
						
						tx_bit_3_addr_a	: if (!timeout) state <= tx_bit_3_addr_b;
						tx_bit_3_addr_b	: if (!timeout) state <= tx_bit_3_addr_c;
						tx_bit_3_addr_c	: if (!timeout) state <= tx_bit_2_addr_a;

						tx_bit_2_addr_a	: if (!timeout) state <= tx_bit_2_addr_b;
						tx_bit_2_addr_b	: if (!timeout) state <= tx_bit_2_addr_c;
						tx_bit_2_addr_c	: if (!timeout) state <= tx_bit_1_addr_a;						

						tx_bit_1_addr_a	: if (!timeout) state <= tx_bit_1_addr_b;
						tx_bit_1_addr_b	: if (!timeout) state <= tx_bit_1_addr_c;
						tx_bit_1_addr_c	: if (!timeout) state <= tx_bit_0_addr_a;						

						tx_bit_0_addr_a	: if (!timeout) state <= tx_bit_0_addr_b;
						tx_bit_0_addr_b	: if (!timeout) state <= tx_bit_0_addr_c;						
						tx_bit_0_addr_c	: if (!timeout) state <= tx_rw_bit_a;

						tx_rw_bit_a			: if (!timeout) state <= tx_rw_bit_b;
						tx_rw_bit_b			: if (!timeout) state <= tx_rw_bit_c;						
						tx_rw_bit_c			: if (!timeout) state <= rx_addr_ack_bit_a; //release sda 1D
						
						rx_addr_ack_bit_a	:  if (!timeout) state <= rx_addr_ack_bit_b; //scl high
						rx_addr_ack_bit_b	:  //if (!timeout) state <= rx_addr_ack_bit_c;  //for sim only
													begin
														if (!timeout)
															begin
																`ifdef sim //no sda sampling
																	state <= rx_addr_ack_bit_c; //scl low
																`else
																	if (!sda) state <= rx_addr_ack_bit_c; //scl low
																	else state <= ackn_error;
																`endif
																
															end
													end
						

						// data transfer byte #1
						rx_addr_ack_bit_c	: if (!timeout) state <= tx_bit_7_data_1_a;
						tx_bit_7_data_1_a	: if (!timeout) state <= tx_bit_7_data_1_b;
						tx_bit_7_data_1_b	: if (!timeout) state <= tx_bit_7_data_1_c;						
						tx_bit_7_data_1_c	: if (!timeout) state <= tx_bit_6_data_1_a;						

						tx_bit_6_data_1_a	: if (!timeout) state <= tx_bit_6_data_1_b;
						tx_bit_6_data_1_b	: if (!timeout) state <= tx_bit_6_data_1_c;						
						tx_bit_6_data_1_c	: if (!timeout) state <= tx_bit_5_data_1_a;
						
						tx_bit_5_data_1_a	: if (!timeout) state <= tx_bit_5_data_1_b;
						tx_bit_5_data_1_b	: if (!timeout) state <= tx_bit_5_data_1_c;						
						tx_bit_5_data_1_c	: if (!timeout) state <= tx_bit_4_data_1_a;

						tx_bit_4_data_1_a	: if (!timeout) state <= tx_bit_4_data_1_b;
						tx_bit_4_data_1_b	: if (!timeout) state <= tx_bit_4_data_1_c;						
						tx_bit_4_data_1_c	: if (!timeout) state <= tx_bit_3_data_1_a;
						
						tx_bit_3_data_1_a	: if (!timeout) state <= tx_bit_3_data_1_b;
						tx_bit_3_data_1_b	: if (!timeout) state <= tx_bit_3_data_1_c;
						tx_bit_3_data_1_c	: if (!timeout) state <= tx_bit_2_data_1_a;

						tx_bit_2_data_1_a	: if (!timeout) state <= tx_bit_2_data_1_b;
						tx_bit_2_data_1_b	: if (!timeout) state <= tx_bit_2_data_1_c;
						tx_bit_2_data_1_c	: if (!timeout) state <= tx_bit_1_data_1_a;

						tx_bit_1_data_1_a	: if (!timeout) state <= tx_bit_1_data_1_b;
						tx_bit_1_data_1_b	: if (!timeout) state <= tx_bit_1_data_1_c;						
						tx_bit_1_data_1_c	: if (!timeout) state <= tx_bit_0_data_1_a;

						tx_bit_0_data_1_a	: if (!timeout) state <= tx_bit_0_data_1_b;
						tx_bit_0_data_1_b	: if (!timeout) state <= tx_bit_0_data_1_c;
						tx_bit_0_data_1_c	: if (!timeout) state <= rx_data_1_ack_bit_a;
						
						rx_data_1_ack_bit_a	: if (!timeout) state <= rx_data_1_ack_bit_b;  //38 / 39
						rx_data_1_ack_bit_b	: //if (!timeout) state <= rx_data_1_ack_bit_c; //for sim only  39/3A
														begin
															if (!timeout)
																begin
																	`ifdef sim //no sda sampling
																		state <= rx_data_1_ack_bit_c;
																	`else
																		if (!sda) state <= rx_data_1_ack_bit_c;
																			else state <= ackn_error;
																	`endif
																end
														end
						
						rx_data_1_ack_bit_c	: 	begin
															if (!timeout)
																begin
																	if (!data_ct) state <= stop_a; // if only one byte is to tx, stop bus.
																	else state <= tx_bit_7_data_2_a; //else go transferring data byte #2
																end
														end

						// data transfer byte #2
						tx_bit_7_data_2_a	:	if (!timeout) state <= tx_bit_7_data_2_b; //3B
						tx_bit_7_data_2_b	:  if (!timeout) state <= tx_bit_7_data_2_c;						
						tx_bit_7_data_2_c	: 	if (!timeout) state <= tx_bit_6_data_2_a;						

						tx_bit_6_data_2_a	: 	if (!timeout) state <= tx_bit_6_data_2_b;
						tx_bit_6_data_2_b	: 	if (!timeout) state <= tx_bit_6_data_2_c;						
						tx_bit_6_data_2_c	: 	if (!timeout) state <= tx_bit_5_data_2_a;
						
						tx_bit_5_data_2_a	: 	if (!timeout) state <= tx_bit_5_data_2_b;
						tx_bit_5_data_2_b	: 	if (!timeout) state <= tx_bit_5_data_2_c;						
						tx_bit_5_data_2_c	: 	if (!timeout) state <= tx_bit_4_data_2_a;

						tx_bit_4_data_2_a	: 	if (!timeout) state <= tx_bit_4_data_2_b;
						tx_bit_4_data_2_b	: 	if (!timeout) state <= tx_bit_4_data_2_c;						
						tx_bit_4_data_2_c	: 	if (!timeout) state <= tx_bit_3_data_2_a;
						
						tx_bit_3_data_2_a	: 	if (!timeout) state <= tx_bit_3_data_2_b;
						tx_bit_3_data_2_b	: 	if (!timeout) state <= tx_bit_3_data_2_c;
						tx_bit_3_data_2_c	: 	if (!timeout) state <= tx_bit_2_data_2_a;

						tx_bit_2_data_2_a	: 	if (!timeout) state <= tx_bit_2_data_2_b;
						tx_bit_2_data_2_b	: 	if (!timeout) state <= tx_bit_2_data_2_c;
						tx_bit_2_data_2_c	: 	if (!timeout) state <= tx_bit_1_data_2_a;

						tx_bit_1_data_2_a	: 	if (!timeout) state <= tx_bit_1_data_2_b;
						tx_bit_1_data_2_b	: 	if (!timeout) state <= tx_bit_1_data_2_c;						
						tx_bit_1_data_2_c	: 	if (!timeout) state <= tx_bit_0_data_2_a;

						tx_bit_0_data_2_a	: 	if (!timeout) state <= tx_bit_0_data_2_b;
						tx_bit_0_data_2_b	: 	if (!timeout) state <= tx_bit_0_data_2_c;
						tx_bit_0_data_2_c	: 	if (!timeout) state <= rx_data_2_ack_bit_a;
						
						rx_data_2_ack_bit_a	: if (!timeout) state <= rx_data_2_ack_bit_b;
						rx_data_2_ack_bit_b	: //if (!timeout) state <= rx_data_2_ack_bit_c; //for sim only
														begin
															if (!timeout)
																begin
																	`ifdef sim
																		state <= rx_data_2_ack_bit_c; //no sda sampling
																	`else
																		if (!sda) state <= rx_data_2_ack_bit_c;
																			else state <= ackn_error;
																	`endif
																end
														end

						rx_data_2_ack_bit_c	: if (!timeout) state <= stop_a;
						
													
						stop_a				: if (!timeout) state <= stop_b;
						//stop_b				: state <= im_idle;	// rm V0.1
						stop_b				: if (!timeout) state <= stop_c; // ins V0.1
						stop_c				: if (!timeout) state <= tx_done; // in V0.1
						tx_done				: state <= im_idle; // 7D / 7F
						ackn_error			: state <= ackn_error; //frm im_idle
						
						default				: state <= im_idle;
						
					endcase
				end
		end
				

				
	reg scl_latch;
	reg sda_latch;
	//reg [7:0] data_tx;

	always @(negedge clk)
		begin
			
			case (state)
				start_a	:	begin
									sda_latch <= 1'b0;
									ready <= 1'b0;
									timer <= timer - 1;
								end
				start_b	:	begin
									scl_latch <= 1'b0;
									timer <= timer - 1;
								end


				
				// address transfer
				tx_bit_6_addr_a	: 	begin
												sda_latch <= addr[7];
												timer <= timer - 1;
											end
				tx_bit_6_addr_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer - 1;
											end
				tx_bit_6_addr_c	: 	begin 
												scl_latch <=	1'b0;				
												timer <= timer - 1;
											end
				
				tx_bit_5_addr_a	: 	begin 
												sda_latch <= addr[6];
												timer <= timer - 1;
											end
				tx_bit_5_addr_b	: 	begin 
												scl_latch <=	1'b1;
												timer <= timer - 1;
											end
				tx_bit_5_addr_c	: 	begin 
												scl_latch <=	1'b0;				
												timer <= timer - 1;
											end

				tx_bit_4_addr_a	: 	begin 
												sda_latch <= addr[5];
												timer <= timer - 1;
											end
				tx_bit_4_addr_b	: 	begin 
												scl_latch <=	1'b1;
												timer <= timer - 1;
											end
				tx_bit_4_addr_c	: 	begin 
												scl_latch <=	1'b0;				
												timer <= timer - 1;
											end

				tx_bit_3_addr_a	: 	begin 
												sda_latch <= addr[4];
												timer <= timer - 1;
											end
				tx_bit_3_addr_b	: 	begin 
												scl_latch <=	1'b1;
												timer <= timer - 1;
											end
				tx_bit_3_addr_c	: 	begin 
												scl_latch <=	1'b0;				
												timer <= timer - 1;
											end

				tx_bit_2_addr_a	: 	begin 
												sda_latch <= addr[3];
												timer <= timer - 1;
											end
				tx_bit_2_addr_b	: 	begin 
												scl_latch <=	1'b1;
												timer <= timer - 1;
											end
				tx_bit_2_addr_c	: 	begin 
												scl_latch <=	1'b0;				
												timer <= timer - 1;
											end

				tx_bit_1_addr_a	: 	begin 
												sda_latch <= addr[2];
												timer <= timer - 1;
											end
				tx_bit_1_addr_b	: 	begin 
												scl_latch <=	1'b1;
												timer <= timer - 1;
											end
				tx_bit_1_addr_c	: 	begin 
												scl_latch <=	1'b0;				
												timer <= timer - 1;
											end

				tx_bit_0_addr_a	: 	begin 
												sda_latch <= addr[1];
												timer <= timer - 1;
											end
				tx_bit_0_addr_b	: 	begin 
												scl_latch <=	1'b1;
												timer <= timer - 1;
											end
				tx_bit_0_addr_c	: 	begin 
												scl_latch <=	1'b0;				
												timer <= timer - 1;
											end

				tx_rw_bit_a			: 	begin 
												sda_latch <= addr[0]; //fmr 1'b0; //change to 1 for read access
												timer <= timer - 1;
											end
				tx_rw_bit_b			: 	begin 
												scl_latch <=	1'b1;
												timer <= timer - 1;
											end
				tx_rw_bit_c			: 	begin 
												scl_latch <=	1'b0;				
												timer <= timer - 1;
											end
					
				rx_addr_ack_bit_a	: 	begin 
												sda_latch <= 1'b1; //release sda
												timer <= timer - 1;
											end
				rx_addr_ack_bit_b	: 	begin 
												scl_latch <=	1'b1;
												timer <= timer - 1;
											end
				rx_addr_ack_bit_c	: 	begin 
												scl_latch <=	1'b0;				
												timer <= timer - 1;
											end
				
		
				
				
				// data transfer byte #1
				tx_bit_7_data_1_a	: 	begin
												sda_latch <= data_tx_1[7];
												timer <= timer -1;
											end
				tx_bit_7_data_1_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_7_data_1_c	: 	begin
												scl_latch <=	1'b0;
												timer <= timer -1;
											end
				
				tx_bit_6_data_1_a	: 	begin
												sda_latch <= data_tx_1[6];
												timer <= timer -1;
											end
				tx_bit_6_data_1_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_6_data_1_c	: 	begin
												scl_latch <=	1'b0;
												timer <= timer -1;
											end
				
				tx_bit_5_data_1_a	: 	begin
												sda_latch <= data_tx_1[5];
												timer <= timer -1;
											end
				tx_bit_5_data_1_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_5_data_1_c	: 	begin
												scl_latch <=	1'b0;
												timer <= timer -1;
											end

				tx_bit_4_data_1_a	: 	begin
												sda_latch <= data_tx_1[4];
												timer <= timer -1;
											end
				tx_bit_4_data_1_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_4_data_1_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end
											
				tx_bit_3_data_1_a	: 	begin
												sda_latch <= data_tx_1[3];
												timer <= timer -1;
											end
				tx_bit_3_data_1_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_3_data_1_c	: 	begin
												scl_latch <=	1'b0;
												timer <= timer -1;
											end

				tx_bit_2_data_1_a	: 	begin
												sda_latch <= data_tx_1[2];
												timer <= timer -1;
											end
				tx_bit_2_data_1_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_2_data_1_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end

				tx_bit_1_data_1_a	: 	begin
												sda_latch <= data_tx_1[1];
												timer <= timer -1;
											end
				tx_bit_1_data_1_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_1_data_1_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end

				tx_bit_0_data_1_a	: 	begin
												sda_latch <= data_tx_1[0];
												timer <= timer -1;
											end
				tx_bit_0_data_1_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_0_data_1_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end
						
				rx_data_1_ack_bit_a	:	begin
													sda_latch <= 1'b1; //release sda
													timer <= timer -1;
												end
				rx_data_1_ack_bit_b	: 	begin
													scl_latch <=	1'b1;
													timer <= timer -1;
												end
				rx_data_1_ack_bit_c	: 	begin
													scl_latch <=	1'b0;				
													timer <= timer -1;
												end


				// data transfer byte #2
				tx_bit_7_data_2_a	: 	begin
												sda_latch <= data_tx_2[7];
												timer <= timer -1;
											end
				tx_bit_7_data_2_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_7_data_2_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end
			
				tx_bit_6_data_2_a	: 	begin
												sda_latch <= data_tx_2[6];
												timer <= timer -1;
											end
				tx_bit_6_data_2_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_6_data_2_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end
				
				tx_bit_5_data_2_a	: 	begin
												sda_latch <= data_tx_2[5];
												timer <= timer -1;
											end
				tx_bit_5_data_2_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_5_data_2_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end

				tx_bit_4_data_2_a	: 	begin
												sda_latch <= data_tx_2[4];
												timer <= timer -1;
											end
				tx_bit_4_data_2_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end	
				tx_bit_4_data_2_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end

				tx_bit_3_data_2_a	: 	begin
												sda_latch <= data_tx_2[3];
												timer <= timer -1;
											end
				tx_bit_3_data_2_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_3_data_2_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end

				tx_bit_2_data_2_a	: 	begin
												sda_latch <= data_tx_2[2];
												timer <= timer -1;
											end
				tx_bit_2_data_2_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_2_data_2_c	: 	begin
												scl_latch <=	1'b0;	
												timer <= timer -1;
											end

				tx_bit_1_data_2_a	: 	begin
												sda_latch <= data_tx_2[1];
												timer <= timer -1;
											end
				tx_bit_1_data_2_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_1_data_2_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end

				tx_bit_0_data_2_a	: 	begin
												sda_latch <= data_tx_2[0];
												timer <= timer -1;
											end
				tx_bit_0_data_2_b	: 	begin
												scl_latch <=	1'b1;
												timer <= timer -1;
											end
				tx_bit_0_data_2_c	: 	begin
												scl_latch <=	1'b0;				
												timer <= timer -1;
											end
						
				rx_data_2_ack_bit_a	: 	begin
													sda_latch <= 1'b1; //release sda
													timer <= timer -1;
												end
				rx_data_2_ack_bit_b	: 	begin
													scl_latch <=	1'b1;
													timer <= timer -1;
												end
				rx_data_2_ack_bit_c	: 	begin
													scl_latch <=	1'b0;				
													timer <= timer -1;
												end

				
				stop_a	: 	begin
									sda_latch <= 1'b0;
									timer <= timer -1;
								end
				stop_b	: 	begin
									scl_latch <= 1'b1;
									timer <= timer -1;
								end
				stop_c	: 	begin  // 04
									timer <= timer -1;
									//ready <= 1'b1;
									sda_latch <= 1'b1;
								end
				
				tx_done	:	ready <= 1'b1; //7D
				
				ackn_error	: ack_fail <= 1'b0;
				
				default	: 	begin
									ready <= 1'b1;
									ack_fail <= 1'b1;
									scl_latch <= 1'b1;
									sda_latch <= 1'b1;
									timer <= -1;
								end

			endcase
		end
		
		
		
	assign sda = sda_latch ? 1'bz : 1'b0;
	assign scl = scl_latch ? 1'bz : 1'b0;
	
//	assign sda = sda_latch;
//	assign scl = scl_latch;
		
	
	assign ready_raw = !ready; // changes on negedge clk
	
	// shrink ready_raw signal to one clk cycle	
	pulse_maker pm_im_ready(
		.clk(clk),
		.reset(reset),
		.in(ready_raw), // L active // sampled on posedge of clk
		.out(im_ready) // L active , updated on negedge of clk  -> notifies executor about successful i2c data transfer
		);

		
endmodule
