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

module prescaler (clk,qa,qb,qc,qd,qe,qf,qg,qh);

output qd;
output qc;
output qb;
output qa;
output qe;
output qf;
output qg;
output reg qh;
input  clk;

reg [20:0] ct;
assign qg = ct[20]; // slow flashing leds
assign qf = ct[17]; // for debouncers and fast flashing leds
assign qe = ct[10];
assign qd = ct[6];
assign qc = ct[5];
assign qb = ct[1];
assign qa = ct[0]; 


always @(posedge clk)
	begin
			ct <= ct + 1;
	end
	
	
	
// ins V0.1 begin
	
	reg [3:0] ct2 = 0;
	always @(posedge qf) ct2 <= ct2 + 1;
		
	always @(ct2)
		begin
			if (ct2 == 0) qh <= 1; 
			 else qh <= 0;
		end
		
endmodule 
