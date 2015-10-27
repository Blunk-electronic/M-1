`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    03:56:42 11/09/2009 
// Design Name: 	 TDI_READ
// Module Name:    tdi_read
// Project Name: 
// Target Devices: XC2C384-7-TQ144
// Tool versions:  ISE 10.1
// Description: 
//					write register expect address A0h
//					write register mask   address A1h
//					read register fail   address A2h
//					read register meas	address A3h
//					read register state  address A4h
//					gpio_d register		address A6h

// Dependencies: 
//
// Revision 11.0

// Additional Comments: for Z80 bus

//////////////////////////////////////////////////////////////////////////////////
module tdi_read(//a_cpu,d_cpu,wr_cpu,rd_cpu,io_req_cpu,reset_cpu,clk_cpu,
				//tck_gen,
				//d_ram_exp,
				//d_ram_meas,
				//d_ram_mask,
				//d_ram_fail,
				//oe_ram_mask,oe_ram_exp,oe_ram_meas,oe_ram_fail,
				//dmux_sel,
				//state,
				//wr_ram_meas_fail,
		//		wr_ram_fail,
				master_clk,
				clk_tdo_gen,
				//tdo_en,  // driven by tdo_gen , H active
				//tdi_gen,
				led_red
				//ext_iei,m1_cpu,int_cpu,nmi_cpu
				);
				
//	 inout [7:0] gpio_d;
//	 input ext_iei;
//	 input m1_cpu;
//	 output int_cpu;
//	 output nmi_cpu;
		
//    input [15:0] a_cpu;
//    inout [7:0] d_cpu;
//    input wr_cpu;
//	 input reset_cpu;
//	 input rd_cpu;
//    input io_req_cpu;
//	 input clk_cpu;

//    input tdo_en;
	 input master_clk;
//  output oe_ram;
//	 output cs_ram_0;
//	 output cs_ram_1;
//  output [23:3] a_ram;

//	output oe_ram_mask;
//	output oe_ram_exp;
//	output oe_ram_meas;
//	output oe_ram_fail; 

//	output wr_ram_meas_fail; // drives RAM /WR for MEAS & FAIL RAM
//	output wr_ram_fail;
	output clk_tdo_gen;
	output led_red;

//    inout [7:0] d_ram_exp;
//	 inout [7:0] d_ram_meas;
//	 inout [7:0] d_ram_mask;
//	 inout [7:0] d_ram_fail;
//   output wr_ram;

//    input tck_gen;
//	 input tdi_gen;
//	 input [2:0] dmux_sel;
//	 input [3:0] state;


	prescaler ps1(
		.clk(master_clk),
		.qe(clk_tdo_gen) // 80 khz at 2,5Mhz CPU clk
		//.ticker(led_red)
		);

	assign led_red = 1'b1;
	
endmodule
