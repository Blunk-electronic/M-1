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

module debouncer (clk,in,out);

output out; // updated on negedge of clk
input  in;  
input  clk;

reg [2:0] count;

//always @(posedge clk)
always @(negedge clk)
	begin
		if (!in)  // in L-active
			begin
				if (count < 4) 
					count <= count + 1;
				else
					count <= count;
			end
		else
			count <= 0;	
	end

//assign out = count[0] & count[1] & count[2];
// out L-active
assign out = !count[2];
	
endmodule 
