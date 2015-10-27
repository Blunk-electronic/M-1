`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
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
// Revision 4.0
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module tdi_router ( 
					rf_mask,rf_exp,
					dm_fail,dm_meas,
					ram_mask,ram_exp,ram_fail,ram_meas,
					oe_ram_mask,oe_ram_exp,oe_ram_meas,oe_ram_fail,
					state,reset
					);

 input reset;
 input [3:0] state;
 input [7:0] rf_mask;
 input [7:0] rf_exp;  
 input [7:0] dm_meas;
 input [7:0] dm_fail;

 output reg [7:0] ram_mask;
 output reg [7:0] ram_exp;
 output reg [7:0] ram_meas;
 output reg [7:0] ram_fail;
 
 output reg oe_ram_mask;
 output reg oe_ram_exp;
 output reg oe_ram_meas;
 output reg oe_ram_fail; 

   parameter tlr = 4'b0000;
   parameter rti = 4'b0001;
   parameter seldr = 4'b0010;
   parameter selir = 4'b0011;
   parameter capdr = 4'b0100;
   parameter capir = 4'b0101;
   parameter shdr = 4'b0110;
   parameter shir = 4'b0111;
   parameter ex1dr = 4'b1000;
   parameter ex1ir = 4'b1001;
   parameter padr = 4'b1010;
   parameter pair = 4'b1011;
   parameter ex2dr = 4'b1100;
   parameter ex2ir = 4'b1101;
   parameter updr = 4'b1110;
   parameter upir = 4'b1111;

 
 always @(state or reset)
	begin
		if (!reset) begin		//reset derived from cpu reset
							oe_ram_fail <= 1;		// outputs fail ram off
							oe_ram_meas <= 1;		// outputs meas ram off
							ram_fail <= 8'hzz;	// release fail ram data bus
							ram_meas <= 8'hzz;	// release meas ram data bus

							oe_ram_mask <= 1;		// outputs mask ram off			 
							oe_ram_exp  <= 1;		// outputs exp ram off			 
							ram_mask <= 8'hzz;	// release mask ram data bus	
							ram_exp  <= 8'hzz;	// release exp ram data bus
						end
		else
		case (state)
			tlr,rti:
						begin
							oe_ram_fail <= 0;		// fail ram drives			 
							oe_ram_meas <= 0;		// meas ram drives			 
							ram_fail <= 8'hzz;	// release fail ram data bus
							ram_meas <= 8'hzz;	// release meas ram data bus
							
							oe_ram_mask <= 1;		// outputs mask ram off to allow ram loading
							oe_ram_exp  <= 1;		// outputs exp ram off to allow ram loading 
							ram_mask <= rf_mask;	// rf drives on mask ram data bus	
							ram_exp  <= rf_exp;	// rf drives on exp ram data bus	
						end
						
			capdr,capir:
						begin
							oe_ram_fail <= 1;		// outputs fail ram off
							oe_ram_meas <= 1;		// outputs meas ram off
							ram_fail <= 8'hzz;	// release fail ram data bus
							ram_meas <= 8'hzz;	// release meas ram data bus

							oe_ram_mask <= 1;		// outputs mask ram off
							oe_ram_exp  <= 1;		// outputs exp ram off 
							ram_mask <= 8'hzz;	// release mask ram data bus
							ram_exp  <= 8'hzz;	// release exp ram data bus
						end
						
			shdr,shir :
						begin
							oe_ram_fail <= 1;		// outputs fail ram off
							oe_ram_meas <= 1;		// outputs meas ram off
							ram_fail <= dm_fail;	// drive on fail ram data bus
							ram_meas <= dm_meas;	// drive on meas ram data bus

							oe_ram_mask <= 0;		// outputs mask ram on
							oe_ram_exp  <= 0;		// outputs exp ram on
							ram_mask <= 8'hzz;	// release mask ram data bus
							ram_exp  <= 8'hzz;	// release exp ram data bus
						end
						
			updr,upir:
						begin
							oe_ram_fail <= 1;		// outputs fail ram off
							oe_ram_meas <= 1;		// outputs meas ram off
							ram_fail <= 8'hzz;	// release fail ram data bus
							ram_meas <= 8'hzz;	// release meas ram data bus

							oe_ram_mask <= 1;		// outputs mask ram off
							oe_ram_exp  <= 1;		// outputs exp ram off
							ram_mask <= 8'hzz;	// release mask ram data bus
							ram_exp  <= 8'hzz;	// release exp ram data bus
						end
						
			default:
						begin
							oe_ram_fail <= 1;		// outputs fail ram off
							oe_ram_meas <= 1;		// outputs meas ram off
							ram_fail <= 8'hzz;	// release fail ram data bus
							ram_meas <= 8'hzz;	// release meas ram data bus

							oe_ram_mask <= 1;		// outputs mask ram off			 
							oe_ram_exp  <= 1;		// outputs exp ram off			 
							ram_mask <= 8'hzz;	// release mask ram data bus	
							ram_exp  <= 8'hzz;	// release exp ram data bus
						end
		endcase
	end

 
endmodule

										

