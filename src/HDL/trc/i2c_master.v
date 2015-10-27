`timescale 1ns / 1ps
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
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module i2c_master(clk,data_tx,addr,reset,ack_fail,ready,sda,scl,start);

   input clk;
   input [7:0] data_tx;
   input [6:0] addr;
	input reset;
	input start;
   output reg ack_fail;
	output reg ready;
	inout sda;
	output scl;
  

	parameter ackn_error				= 7'h7E;			
	parameter idle						= 7'h7F;
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

	parameter tx_bit_7_data_a		= 7'h20;
	parameter tx_bit_7_data_b		= 7'h21;
	parameter tx_bit_7_data_c		= 7'h22;	
	parameter tx_bit_6_data_a		= 7'h23;
	parameter tx_bit_6_data_b		= 7'h24;
	parameter tx_bit_6_data_c		= 7'h25;	
	parameter tx_bit_5_data_a		= 7'h26;
	parameter tx_bit_5_data_b		= 7'h27;
	parameter tx_bit_5_data_c		= 7'h28;	
	parameter tx_bit_4_data_a		= 7'h29;
	parameter tx_bit_4_data_b		= 7'h2A;
	parameter tx_bit_4_data_c		= 7'h2B;	
	parameter tx_bit_3_data_a		= 7'h2C;
	parameter tx_bit_3_data_b		= 7'h2D;
	parameter tx_bit_3_data_c		= 7'h2E;	
	parameter tx_bit_2_data_a		= 7'h2F;
	parameter tx_bit_2_data_b		= 7'h30;
	parameter tx_bit_2_data_c		= 7'h31;	
	parameter tx_bit_1_data_a		= 7'h32;
	parameter tx_bit_1_data_b		= 7'h33;
	parameter tx_bit_1_data_c		= 7'h34;	
	parameter tx_bit_0_data_a		= 7'h35;
	parameter tx_bit_0_data_b		= 7'h36;
	parameter tx_bit_0_data_c		= 7'h37;	
	parameter rx_data_ack_bit_a	= 7'h38;
	parameter rx_data_ack_bit_b	= 7'h39;
	parameter rx_data_ack_bit_c	= 7'h40;	

	
	reg [6:0] state;
	
	
	always @(posedge clk)
		begin
			if (!reset) state <= idle;
			else
				begin
					case (state)
						idle					: 	begin
														if (!start) state <= start_a;
														else state <= idle;
													end
						start_a 				: state <= start_b;
						
						// address transfer
						start_b				: state <= tx_bit_6_addr_a; 
						
						tx_bit_6_addr_a	: state <= tx_bit_6_addr_b;
						tx_bit_6_addr_b	: state <= tx_bit_6_addr_c;
						tx_bit_6_addr_c	: state <= tx_bit_5_addr_a;						
						
						tx_bit_5_addr_a	: state <= tx_bit_5_addr_b;
						tx_bit_5_addr_b	: state <= tx_bit_5_addr_c;
						tx_bit_5_addr_c	: state <= tx_bit_4_addr_a;

						tx_bit_4_addr_a	: state <= tx_bit_4_addr_b;
						tx_bit_4_addr_b	: state <= tx_bit_4_addr_c;
						tx_bit_4_addr_c	: state <= tx_bit_3_addr_a;						
						
						tx_bit_3_addr_a	: state <= tx_bit_3_addr_b;
						tx_bit_3_addr_b	: state <= tx_bit_3_addr_c;
						tx_bit_3_addr_c	: state <= tx_bit_2_addr_a;

						tx_bit_2_addr_a	: state <= tx_bit_2_addr_b;
						tx_bit_2_addr_b	: state <= tx_bit_2_addr_c;
						tx_bit_2_addr_c	: state <= tx_bit_1_addr_a;						

						tx_bit_1_addr_a	: state <= tx_bit_1_addr_b;
						tx_bit_1_addr_b	: state <= tx_bit_1_addr_c;
						tx_bit_1_addr_c	: state <= tx_bit_0_addr_a;						

						tx_bit_0_addr_a	: state <= tx_bit_0_addr_b;
						tx_bit_0_addr_b	: state <= tx_bit_0_addr_c;						
						tx_bit_0_addr_c	: state <= tx_rw_bit_a;

						tx_rw_bit_a			: state <= tx_rw_bit_b;
						tx_rw_bit_b			: state <= tx_rw_bit_c;						
						tx_rw_bit_c			: state <= rx_addr_ack_bit_a; //release sda
						
						rx_addr_ack_bit_a	: state <= rx_addr_ack_bit_b;
						rx_addr_ack_bit_b	: //state <= rx_addr_ack_bit_c;  //for sim only
													begin
														if (!sda) state <= rx_addr_ack_bit_c;
														else state <= ackn_error;
													end
						

						// data transfer
						rx_addr_ack_bit_c	: state <= tx_bit_7_data_a;
						tx_bit_7_data_a	: state <= tx_bit_7_data_b;
						tx_bit_7_data_b	: state <= tx_bit_7_data_c;						
						tx_bit_7_data_c	: state <= tx_bit_6_data_a;						

						tx_bit_6_data_a	: state <= tx_bit_6_data_b;
						tx_bit_6_data_b	: state <= tx_bit_6_data_c;						
						tx_bit_6_data_c	: state <= tx_bit_5_data_a;
						
						tx_bit_5_data_a	: state <= tx_bit_5_data_b;
						tx_bit_5_data_b	: state <= tx_bit_5_data_c;						
						tx_bit_5_data_c	: state <= tx_bit_4_data_a;

						tx_bit_4_data_a	: state <= tx_bit_4_data_b;
						tx_bit_4_data_b	: state <= tx_bit_4_data_c;						
						tx_bit_4_data_c	: state <= tx_bit_3_data_a;
						
						tx_bit_3_data_a	: state <= tx_bit_3_data_b;
						tx_bit_3_data_b	: state <= tx_bit_3_data_c;
						tx_bit_3_data_c	: state <= tx_bit_2_data_a;

						tx_bit_2_data_a	: state <= tx_bit_2_data_b;
						tx_bit_2_data_b	: state <= tx_bit_2_data_c;
						tx_bit_2_data_c	: state <= tx_bit_1_data_a;

						tx_bit_1_data_a	: state <= tx_bit_1_data_b;
						tx_bit_1_data_b	: state <= tx_bit_1_data_c;						
						tx_bit_1_data_c	: state <= tx_bit_0_data_a;

						tx_bit_0_data_a	: state <= tx_bit_0_data_b;
						tx_bit_0_data_b	: state <= tx_bit_0_data_c;
						tx_bit_0_data_c	: state <= rx_data_ack_bit_a;
						
						rx_data_ack_bit_a	: state <= rx_data_ack_bit_b;
						rx_data_ack_bit_b	: // state <= rx_data_ack_bit_c; //for sim only
													begin
														if (!sda) state <= rx_data_ack_bit_c;
														else state <= ackn_error;
													end
						
						rx_data_ack_bit_c	: state <= stop_a;
						stop_a				: state <= stop_b;
						stop_b				: state <= idle;
						ackn_error			: state <= idle; //ackn_error;
						
						default				: state <= idle;
						
					endcase
				end
		end
				

				
	reg scl_latch;
	reg sda_latch;
	

	always @(negedge clk)
		begin
			case (state)
				start_a	:	begin
									sda_latch <= 1'b0;
									ready <= 1'b0;
								end
				start_b	:	begin
									scl_latch <= 1'b0;
								end
						
				// address transfer
				tx_bit_6_addr_a	: sda_latch <= addr[6];
				tx_bit_6_addr_b	: scl_latch <=	1'b1;
				tx_bit_6_addr_c	: scl_latch <=	1'b0;				
				
				tx_bit_5_addr_a	: sda_latch <= addr[5];
				tx_bit_5_addr_b	: scl_latch <=	1'b1;
				tx_bit_5_addr_c	: scl_latch <=	1'b0;				

				tx_bit_4_addr_a	: sda_latch <= addr[4];
				tx_bit_4_addr_b	: scl_latch <=	1'b1;
				tx_bit_4_addr_c	: scl_latch <=	1'b0;				

				tx_bit_3_addr_a	: sda_latch <= addr[3];
				tx_bit_3_addr_b	: scl_latch <=	1'b1;
				tx_bit_3_addr_c	: scl_latch <=	1'b0;				

				tx_bit_2_addr_a	: sda_latch <= addr[2];
				tx_bit_2_addr_b	: scl_latch <=	1'b1;
				tx_bit_2_addr_c	: scl_latch <=	1'b0;				

				tx_bit_1_addr_a	: sda_latch <= addr[1];
				tx_bit_1_addr_b	: scl_latch <=	1'b1;
				tx_bit_1_addr_c	: scl_latch <=	1'b0;				

				tx_bit_0_addr_a	: sda_latch <= addr[0];
				tx_bit_0_addr_b	: scl_latch <=	1'b1;
				tx_bit_0_addr_c	: scl_latch <=	1'b0;				

				tx_rw_bit_a			: sda_latch <= 1'b0; //change to 1 for read access
				tx_rw_bit_b			: scl_latch <=	1'b1;
				tx_rw_bit_c			: scl_latch <=	1'b0;				
					
				rx_addr_ack_bit_a	: sda_latch <= 1'b1; //release sda
				rx_addr_ack_bit_b	: scl_latch <=	1'b1;
				rx_addr_ack_bit_c	: scl_latch <=	1'b0;				
				
		
				
				
				// data transfer
				tx_bit_7_data_a	: sda_latch <= data_tx[7];
				tx_bit_7_data_b	: scl_latch <=	1'b1;
				tx_bit_7_data_c	: scl_latch <=	1'b0;				
				
				tx_bit_6_data_a	: sda_latch <= data_tx[6];
				tx_bit_6_data_b	: scl_latch <=	1'b1;
				tx_bit_6_data_c	: scl_latch <=	1'b0;				
				
				tx_bit_5_data_a	: sda_latch <= data_tx[5];
				tx_bit_5_data_b	: scl_latch <=	1'b1;
				tx_bit_5_data_c	: scl_latch <=	1'b0;				

				tx_bit_4_data_a	: sda_latch <= data_tx[4];
				tx_bit_4_data_b	: scl_latch <=	1'b1;
				tx_bit_4_data_c	: scl_latch <=	1'b0;				

				tx_bit_3_data_a	: sda_latch <= data_tx[3];
				tx_bit_3_data_b	: scl_latch <=	1'b1;
				tx_bit_3_data_c	: scl_latch <=	1'b0;				

				tx_bit_2_data_a	: sda_latch <= data_tx[2];
				tx_bit_2_data_b	: scl_latch <=	1'b1;
				tx_bit_2_data_c	: scl_latch <=	1'b0;				

				tx_bit_1_data_a	: sda_latch <= data_tx[1];
				tx_bit_1_data_b	: scl_latch <=	1'b1;
				tx_bit_1_data_c	: scl_latch <=	1'b0;				

				tx_bit_0_data_a	: sda_latch <= data_tx[0];
				tx_bit_0_data_b	: scl_latch <=	1'b1;
				tx_bit_0_data_c	: scl_latch <=	1'b0;				
						
				rx_data_ack_bit_a	: sda_latch <= 1'b1; //release sda
				rx_data_ack_bit_b	: scl_latch <=	1'b1;
				rx_data_ack_bit_c	: scl_latch <=	1'b0;				
				
				stop_a	: sda_latch <= 1'b0;
				stop_b	: scl_latch <= 1'b1;
				stop_c	: 	begin
									ready <= 1'b1;
									sda_latch <= 1'b1;
								end
				
				ackn_error	: ack_fail <= 1'b0;
				
				default	: 	begin
									ready <= 1'b1;
									ack_fail <= 1'b1;
									scl_latch <= 1'b1;
									sda_latch <= 1'b1;
								end

			endcase
		end
		
		
	assign sda = sda_latch ? 1'bz : 1'b0;
	assign scl = scl_latch ? 1'bz : 1'b0;
		
endmodule
