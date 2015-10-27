`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:56:30 07/27/2010 
// Design Name: 
// Module Name:    sh_reg 
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

module needle_maker (in,needle,gate);

//	output out;
	output needle;
	input  in;
	input  gate;

	reg out;
//	wire s;
	
	always @(posedge in or negedge out)
		begin
			if (!out) out <= 1'b1;
			else if (out) out <= 1'b0;
		end	
	
//	always @(posedge in or posedge s)
//		begin
//			if (s) out <= 1'b1;
//			else out <= 1'b0;
//		end

//	assign s = !(out & gate);
	assign needle = gate ? out : 1'b1;
	
endmodule 
