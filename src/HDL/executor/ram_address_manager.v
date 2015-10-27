`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:44:33 07/05/2011 
// Design Name: 
// Module Name:    am 
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
module ram_address_manager (
    addr_in,
    addr_out,
    inc_addr,   // L active //data_rd_or_wrstrb  //80h
	ld_addr,		// L active //addr_wrstrb    // 83-81h
	reset,	// L active
	clk,
	debug
    );

    input [23:0] addr_in;
    output [23:0] addr_out;
    input inc_addr;   // L active //data_rd_or_wrstrb
	input ld_addr;		// L active //addr_wrstrb
	input reset;	// L active
	output debug;
	input clk;


	assign change_addr = (inc_addr & ld_addr ); //collect events that cause an address change
	reg [23:0] addr_out;

//	always @(negedge inc_addr) // or posedge ld_addr)
//		begin
//			if (!inc_addr) addr_out <= addr_out + 1; 
//			//else if (ld_addr) addr_out [23:0] <= addr_in [23:0]; // preload address
//		end
// OK

//	always @(posedge ld_addr) // or posedge ld_addr)
//		begin
//			if (ld_addr) addr_out [23:0] <= addr_in [23:0]; // preload address
//		end
// OK




		

	//always @(posedge change_addr)
	//	begin
		//	if (ld_addr) addr_out [23:0] <= addr_in [23:0];
		//	else if (!inc_addr) addr_out <= addr_out + 1; 
		// NG
		
		//	if (!inc_addr) addr_out <= addr_out + 1;
		//	else addr_out [23:0] <= addr_in [23:0];
		// NG
		
		//	case (inc_addr,ld_addr)
		//		2'b01 : addr_out <= addr_out + 1; 
		//		2'b11 : addr_out <= addr_in; 
		//		default : addr_out <= addr_out; 
		//	endcase
		//end


	//assign debug = inc_addr;
	//assign addr_out = addr;
			
			
endmodule
