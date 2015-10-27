`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:28:16 07/05/2011 
// Design Name: 
// Module Name:    command_decoder 
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
module command_decoder(
    data_in,
    cmd_out
    );

	input [7:0] data_in;
	output [15:0] cmd_out;
	reg [15:0] cmd_out;

	always @*
		begin
			case (data_in)
				8'h01 : cmd_out <= 16'h0001;
				8'h02 : cmd_out <= 16'h0002;
				8'h03 : cmd_out <= 16'h0004;
				8'h04 : cmd_out <= 16'h0008;				
				8'h05 : cmd_out <= 16'h0010;
				8'h06 : cmd_out <= 16'h0020;				
				8'h07 : cmd_out <= 16'h0040;				
				8'h08 : cmd_out <= 16'h0080;				
				8'h09 : cmd_out <= 16'h0100;				
				8'h0A : cmd_out <= 16'h0200;				
				8'h0B : cmd_out <= 16'h0400;								
				8'h0C : cmd_out <= 16'h0800;												
				8'h0D : cmd_out <= 16'h1000;								
				8'h0E : cmd_out <= 16'h2000;								
				8'h0F : cmd_out <= 16'h4000;								
				8'h10 : cmd_out <= 16'h8000;												

				default : cmd_out <= 16'h0000;
			endcase
		end
	
endmodule
