`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:47:04 12/15/2011 
// Design Name: 
// Module Name:    pulse_maker 
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
module pulse_maker3(
    input clk,
    input reset,
    input in,
    output reg out  // outputs L on 2nd negedge after posedge of CLK
    );

	//reg out;
	reg latch;
	reg [1:0] ct;
	
	always @(posedge clk)
		begin
			if (!reset | in) latch <= 1;
			else if (!in) latch <= 0; 
		end

	always @(posedge clk)
		begin
			if (!reset | latch) ct <= 2'h3; 	// reload countdown
			else if (ct != 0) ct <= ct - 1;  // count down if low-input latched
		end

	always @(posedge clk)	//update out on posedge of clk
		begin
			if (ct == 2) out <= 0;
			//if (ct == 1 | ct == 2) out <= 0;
				else out <= 1;
		end



endmodule
