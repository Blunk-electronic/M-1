`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// fail_dmany: 
// Engineer: 
// 
// Create Date:    04:12:11 11/09/2009 
// Design Name: 
// Module Name:    dmux 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 6.0
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module tdi_dmux(adr,tdi,meas,mask,exp,fail,clk,fail_flag,reset,tdo_en,tck);

 input [2:0] adr;
 input [7:0] exp;
 input [7:0] mask; 
 input tdi;
 input clk;
 input reset;
 input tdo_en;
 input tck;
 
 output [7:0] fail; 
 output fail_flag;
 output [7:0] meas;  
 
 reg [7:0] fail;
 reg [7:0] meas; 

 reg exp_dm;
 reg mask_dm;
	
   always @*	
				case (adr)
					3'b000: exp_dm = exp[0];
					3'b001: exp_dm = exp[1];
					3'b010: exp_dm = exp[2];
					3'b011: exp_dm = exp[3];
					3'b100: exp_dm = exp[4];
					3'b101: exp_dm = exp[5];
					3'b110: exp_dm = exp[6];
					3'b111: exp_dm = exp[7];
				endcase

   always @*	
				case (adr)
					3'b000: mask_dm = mask[0];
					3'b001: mask_dm = mask[1];
					3'b010: mask_dm = mask[2];
					3'b011: mask_dm = mask[3];
					3'b100: mask_dm = mask[4];
					3'b101: mask_dm = mask[5];
					3'b110: mask_dm = mask[6];
					3'b111: mask_dm = mask[7];
				endcase


	wire fail_dm;
   always @(posedge clk or negedge reset)
			if (!reset) fail <= 8'b00;
			else
				case (adr)
					3'b000: fail[0] <= fail_dm;
					3'b001: fail[1] <= fail_dm;
					3'b010: fail[2] <= fail_dm;
					3'b011: fail[3] <= fail_dm;
					3'b100: fail[4] <= fail_dm;
					3'b101: fail[5] <= fail_dm;
					3'b110: fail[6] <= fail_dm;
					3'b111: fail[7] <= fail_dm;
				endcase

   always @(posedge clk)
				case (adr)
					3'b000: meas[0] = tdi;
					3'b001: meas[1] = tdi;
					3'b010: meas[2] = tdi;
					3'b011: meas[3] = tdi;
					3'b100: meas[4] = tdi;
					3'b101: meas[5] = tdi;
					3'b110: meas[6] = tdi;
					3'b111: meas[7] = tdi;
				endcase

	assign fail_dm = (exp_dm ^ tdi) & mask_dm;

	reg fail_flag;  // updated on posedge of tck
	always @(posedge clk)
		if (tck & tdo_en & fail_dm) fail_flag <= 1;
		else fail_flag <= 0;

//	always @(fail)
//			if (fail > 0) fail_flag <= 1;
//			else fail_flag <= 0;

endmodule

										

