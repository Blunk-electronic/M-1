`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:26:25 09/29/2011 
// Design Name: 
// Module Name:    i2c_controller 
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
module i2c_controller(
    input clk,
    input [7:0] data_tx1,
    input [7:0] data_tx2,
    input [7:0] data_tx3,
    input [7:0] data_tx4,	 
    input [6:0] addr_slave1,
    input [6:0] addr_slave2,
    input [6:0] addr_slave3,
    input [6:0] addr_slave4,	 
    input reset,
    output ack_fail,
	 inout sda,
	 output scl
    );

	parameter idle = 4'hF;
	parameter set_parm_1 = 4'h0;
	parameter tx_parm_1a	= 4'h1;
	parameter tx_parm_1b	= 4'h2; 
	parameter set_parm_2 = 4'h3;
	parameter tx_parm_2a	= 4'h4;
	parameter tx_parm_2b	= 4'h5; 
	parameter set_parm_3 = 4'h6;
	parameter tx_parm_3a	= 4'h7;
	parameter tx_parm_3b	= 4'h8; 
	parameter set_parm_4 = 4'h9;
	parameter tx_parm_4a	= 4'hA;
	parameter tx_parm_4b	= 4'hB; 
	
		
	
	
	wire ready;

	reg [3:0] ic_state;

	always @(posedge clk)
		begin
			if (!reset) ic_state <= idle;
			else
				begin
					case (ic_state)
						idle				:	begin
													if (ready) ic_state <= set_parm_1;
													else ic_state <= idle;
												end
						set_parm_1		:	ic_state <= tx_parm_1a;
						tx_parm_1a		:	ic_state <= tx_parm_1b;
						tx_parm_1b		:	begin						
													if (ready) ic_state <= set_parm_2;
													else ic_state <= tx_parm_1b;
												end

						set_parm_2		:	ic_state <= tx_parm_2a;
						tx_parm_2a		:	ic_state <= tx_parm_2b;
						tx_parm_2b		:	begin						
													if (ready) ic_state <= set_parm_3;
													else ic_state <= tx_parm_2b;
												end

						set_parm_3		:	ic_state <= tx_parm_3a;
						tx_parm_3a		:	ic_state <= tx_parm_3b;
						tx_parm_3b		:	begin						
													if (ready) ic_state <= set_parm_4;
													else ic_state <= tx_parm_3b;
												end

						set_parm_4		:	ic_state <= tx_parm_4a;
						tx_parm_4a		:	ic_state <= tx_parm_4b;
						tx_parm_4b		:	begin						
													if (ready) ic_state <= set_parm_1;
													else ic_state <= tx_parm_4b;
												end

			
						default			:	ic_state <= idle;
						
					endcase
				end
		end
		
	reg start;
	reg [6:0] im_addr;
	reg [7:0] im_data_tx;
	always @(negedge clk)
		begin
			case (ic_state)
				idle				:	start <= 1'b1;
				set_parm_1		:	begin
											im_addr <= addr_slave1;
											im_data_tx <= data_tx1;
										end
				tx_parm_1a		:	start <= 1'b0;
				tx_parm_1b		:	start <= 1'b1;				

				set_parm_2		:	begin
											im_addr <= addr_slave2;
											im_data_tx <= data_tx2;
										end
				tx_parm_2a		:	start <= 1'b0;
				tx_parm_2b		:	start <= 1'b1;				

				set_parm_3		:	begin
											im_addr <= addr_slave3;
											im_data_tx <= data_tx3;
										end
				tx_parm_3a		:	start <= 1'b0;
				tx_parm_3b		:	start <= 1'b1;			

				set_parm_4		:	begin
											im_addr <= addr_slave4;
											im_data_tx <= data_tx4;
										end
				tx_parm_4a		:	start <= 1'b0;
				tx_parm_4b		:	start <= 1'b1;			


				//default			:	start <= 1'b1;			
			endcase
		end
		
		
	i2c_master im (
		.clk(clk),
		.data_tx(im_data_tx),
		.addr(im_addr),
		.reset(reset),
		.ack_fail(ack_fail),
		.sda(sda),
		.scl(scl),
		.ready(ready),
		.start(start)
    );

endmodule
