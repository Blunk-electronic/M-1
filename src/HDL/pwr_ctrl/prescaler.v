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

module prescaler (clk,qa,qb,qc,qd,qe,qf,q1);

output qd;
output qc;
output qb;
output qa;
output qe;
output qf;
output q1;
input  clk;

reg [13:0] ct;
reg [7:0] ct2;

assign qf = ct[13]; // very slow
assign qe = ct[10];	// slow
assign qd = ct[8];
assign qc = ct[5];
assign qb = ct[1];
assign qa = ct[0];  // fast


always @(posedge clk)
	begin
		ct <= ct + 1;
	end
	
// divide osc clock by 250 to output 50 Hz at q1
always @(posedge clk)
	begin
		if (ct2 < 250) ct2 <= ct2 + 1;
		else ct2 <= 0;
	end
	
assign q1 = ct2[7];
	
endmodule 
