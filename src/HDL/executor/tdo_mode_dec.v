`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    03:56:42 11/09/2009 
// Design Name: 
// Module Name:
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: decodes mode_0 register
//					
//									  
// Dependencies: 
//
// Revision: 
// Revision 2.1
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module tdo_mode_dec(mode,adr,dat,a_ram,d_ram,oe_ram,d_mux,a_ag,cs_ram_drv,//wr_ram,
							state,tdo_req,wrstrb);
				
   input [7:0] mode;
	input [3:0] state;
	input tdo_req;
	input wrstrb;
	
   input [20:0] adr;	 
	input [7:0] dat;

   output [23:3] a_ram;	
	inout [7:0] d_ram;
	output oe_ram;
	output cs_ram_drv;
//	output wr_ram;

	output [7:0] d_mux;

	input [23:3] a_ag;	

   parameter tlr = 4'b0000; // 0
   parameter rti = 4'b0001; // 1
   parameter seldr = 4'b0010; // 2
   parameter selir = 4'b0011; // 3
   parameter capdr = 4'b0100; // 4
   parameter capir = 4'b0101; //5
   parameter shdr = 4'b0110;	// 6
   parameter shir = 4'b0111;  // 7
   parameter ex1dr = 4'b1000; // 8
   parameter ex1ir = 4'b1001; // 9
   parameter padr = 4'b1010;	// A
   parameter pair = 4'b1011;  // B
   parameter ex2dr = 4'b1100; // C
   parameter ex2ir = 4'b1101; // D
   parameter updr = 4'b1110;  // E
   parameter upir = 4'b1111;  // F

	reg [23:3] a_ram;
   always @*
      if (mode[7]==1)
				a_ram <= adr;
		else 
      if (mode[7]==0)
				a_ram <= a_ag;

	reg [7:0] d_mux;		
	always @*
      if (mode[6]==1)
				d_mux <= dat;
		else 
      if (mode[6]==0)
				d_mux <= d_ram;



	//kritisch weil ram und register kurzzeitig gleichzeitig treiben ?
	//assign oe_ram = mode[5];	
	//assign d_ram = mode[5] ? dat : 8'hzz;
	
	// data path for drv ram loading
	assign d_ram = ((state == tlr) | (state == rti)) ? dat : 8'hzz;
	
	// data path for sir / sdr
	assign oe_ram = (!tdo_req) ? 1'b1 : 1'b0;
	
	
	
	
	reg cs_ram_drv;
	always @*
		if (a_ram < 21'h80000) // defines end of 512k x 8 RAM bank 1
			cs_ram_drv <= 0;
		else
			cs_ram_drv <= 1;


//	reg cs_ram_1;
//	always @*
//		if (a_ram >= 21'h80000) // beginning of 512k x 8 RAM bank 2
//			begin
//				if (a_ram < 21'h100000) //end+1 of bank 2
//				cs_ram_1 <= 0;
//			end
//		else
//				cs_ram_1 <= 1;


// writing to ram
//	assign wr_ram = mode[4];
//	assign wr_ram = wrstrb;


endmodule
