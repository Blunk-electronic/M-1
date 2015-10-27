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
module pulse_maker2(
    input clk,
    input reset,
    input in,
    output reg out  // outputs L on 2nd negedge after posedge of CLK
    );

	//reg out;
	reg latch;
	reg [2:0] ct;
	
	always @(posedge clk)
		begin
			if (!reset | in) latch <= 1;
			else if (!in) latch <= 0; 
		end

	always @(posedge clk)
		begin
			if (!reset | latch) ct <= 3'h5; 	// reload countdown
			else if (ct != 0) ct <= ct - 1;  // count down if low-input latched
		end

	always @(negedge clk)	//update out on falling edge of clk
		begin
			if ((ct < 5) & (ct > 1)) out <= 0;
			//if (ct == 1 | ct == 2) out <= 0;
				else out <= 1;
		end



endmodule
