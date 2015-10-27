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

module prescaler (clk,qa,qb,qc,qd,qe,qf);

output qd;
output qc;
output qb;
output qa;
output qe;
output qf;
input  clk;

reg [13:0] ct;
assign qf = ct[13]; // very slow
assign qe = ct[9];	// slow
assign qd = ct[6];
assign qc = ct[5];
assign qb = ct[1];
assign qa = ct[0];  // fast


always @(posedge clk)
	begin
			ct <= ct + 1;
	end
	
endmodule 
