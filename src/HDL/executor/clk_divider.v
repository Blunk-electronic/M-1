`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:04:47 05/12/2010 
// Design Name: 
// Module Name:    clk_divider 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision: 4.1
// Additional Comments: 


//////////////////////////////////////////////////////////////////////////////////
module clk_divider(scale,clk_in,clk_out1,clk_out2,reset
    );

//	input [7:0] tck_step_ctrl;
	input clk_in;
	input	reset;
	input [7:0] scale; //applies for clk_out1 only !
	output reg clk_out1;  // 12,5 Mhz at scale=FFh -> 4,17 Mhz TCK
	output reg clk_out2;  // 10 hz

   reg [8:0] ct;	
	always @(posedge clk_in) // BS: or negedge reset)
		begin
			if (!reset) ct[8:0] <= 9'h0;
			else
				if (ct[8]) 
					begin
						ct[7:0] <= scale;
						//ct[10:0] <= 11'h0;
						ct[8] <= 1'b0;
						
					end
				else ct <= ct + 1;
		end
	
	always @(posedge ct[8])  // no good solution
		begin
			clk_out1 = ~clk_out1;
		end





	reg [23:0] ct2;
	always @(posedge clk_in)
		begin
			if (ct2 <= 24'd2500000) ct2 <= ct2 + 1;  // CS: or ct2 < 24'd2500000 ?
				else 
					begin
						ct2 <= 0;
						clk_out2 <= ~clk_out2;  // 10hz
					end
		end


		
endmodule
