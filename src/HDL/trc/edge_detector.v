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

module edge_detector (out,clk,in,edge_sel,ext_rst_en,reset);

output 	out;		// H-active
input  	in;
input		edge_sel;		// L -> negedge detect
								// H -> posedge detect
input 	ext_rst_en;	// H-active to enable external reset
input 	clk;		// 
input 	reset;	// L-active

// edge selector
assign in_mode = edge_sel ? in : !in;


reg [1:0] ct;
reg cat;

// timer ct counts up while cat=H
always @(posedge clk or negedge cat)
	begin
		if (cat == 0) ct <= 0;
		else ct <= ct + 1;
	end

// r formed by ct1=H or external low active reset depending on ext_rst_en
assign r = !ext_rst_en ? ct[1] : !reset; 

// asynchronous reset of ct when r goes high
// otherwise cat goes high on edge of input in
always @(posedge in_mode or posedge r)
	begin
		if (r) cat <= 0;
		else
		 cat <= 1;
	end
		


assign out = cat;

	
endmodule 
