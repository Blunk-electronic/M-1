`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:18:56 11/09/2009 
// Design Name: 
// Module Name:  
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 8.1
// Additional Comments: 
//////////////////////////////////////////////////////////////////////////////////

module tdo_ctrl_reg(a_cpu,d_cpu,wr_cpu,rd_cpu,io_req_cpu,clk_cpu,
					start_adr,len,adr,dat,mode,low_level_ctrl,
					gpio_0,
					gpio_1,
					gpio_2,
					wrstrb,
					d_ram_drv,
					reset);

    input [7:0] a_cpu;
	 input [7:0] d_ram_drv;	
	 inout [7:0] d_cpu;
    input wr_cpu;
    input rd_cpu;	 
    input io_req_cpu;
	 input reset;
	 input clk_cpu;
	 
    output [23:0] mode;
    output [23:0] adr;
	 output [7:0] dat;
    output [23:0] len;
	 output [23:0] start_adr;
	 output [7:0] low_level_ctrl;

    reg [23:0] mode;
    reg [23:0] adr;
	 reg [7:0] dat;
    reg [23:0] len;
	 reg [23:0] start_adr;
	 reg [7:0] low_level_ctrl;
	 reg [7:0] gpio_a;
	 reg [7:0] gpio_b;
	 reg [6:0] gpio_c;
	 output reg wrstrb;
	

	parameter BASE_ADR = 8'h80;
	parameter ADR_MODE_0 = BASE_ADR+0;
	parameter ADR_MODE_1 = BASE_ADR+1;
	parameter ADR_MODE_2 = BASE_ADR+2;
	
	parameter ADR_D_RAM_0 = BASE_ADR+3;
//	parameter ADR_D_RAM_1 = BASE_ADR+4;
//	parameter ADR_D_RAM_2 = BASE_ADR+5;
//	parameter ADR_D_RAM_3 = BASE_ADR+6;

	parameter ADR_A_RAM_0 = BASE_ADR+7;
	parameter ADR_A_RAM_1 = BASE_ADR+8;
	parameter ADR_A_RAM_2 = BASE_ADR+9;
//	parameter ADR_A_RAM_3 = BASE_ADR+10;

	parameter ADR_LEN_0 = BASE_ADR+11; //8b
	parameter ADR_LEN_1 = BASE_ADR+12; //8c
	parameter ADR_LEN_2 = BASE_ADR+13; //8d
//	parameter ADR_LEN_3 = BASE_ADR+14; //8e

	parameter ADR_START_ADR_0 = BASE_ADR+15; //8f
	parameter ADR_START_ADR_1 = BASE_ADR+16; //90
	parameter ADR_START_ADR_2 = BASE_ADR+17; //91
//	parameter ADR_START_ADR_3 = BASE_ADR+18; //92

	parameter LOW_LEVEL_CTRL = BASE_ADR+19; //93
	
	parameter GPIO_DATA_0 = BASE_ADR+20; //94
	parameter GPIO_DATA_1 = BASE_ADR+21; //95
	parameter GPIO_DATA_2 = BASE_ADR+22; //96
	
	parameter WR_STRB = BASE_ADR+23; //97
	parameter INC_ADR = BASE_ADR+24; //98
	
// writing to register file

	wire ioreq_or_wr;
	assign ioreq_or_wr = io_req_cpu | wr_cpu;
	always @(posedge clk_cpu)
			begin
				casex ({reset,ioreq_or_wr})
					2'b0x :	begin
									mode [7:0] <= 8'hFF;		//mode0 reg.
									mode [15:8] <= 8'h03;   //mode1 reg. // default path is rti -> sel_dr -> sel_ir -> tlr
									mode [23:16] <= 8'h00;	//mode2 reg.
									low_level_ctrl [7:0] <= 8'h80;
									gpio_a [7:0] <= 8'hFF;
									gpio_b [7:0] <= 8'hFF;
									gpio_c [6:0] <= 7'hFF;
									wrstrb <= 1'b1;
					//				incadr <= 1'b1;
								end 
					2'b10 :	begin
									if (a_cpu == ADR_MODE_0) mode [7:0] <= d_cpu;
									if (a_cpu == ADR_MODE_1) mode [15:8] <= d_cpu;
									if (a_cpu == ADR_MODE_2) mode [23:16] <= d_cpu;	
					
									if (a_cpu == ADR_D_RAM_0) dat [7:0] <= d_cpu;
					//				if (a_cpu == ADR_D_RAM_1) dat [15:8] <= d_cpu;
					//				if (a_cpu == ADR_D_RAM_2) dat [23:16] <= d_cpu;
					//				if (a_cpu == ADR_D_RAM_3) dat [31:24] <= d_cpu;

								//	if (a_cpu == ADR_A_RAM_0) adr [7:0] <= d_cpu;
								//	if (a_cpu == ADR_A_RAM_1) adr [15:8] <= d_cpu;
								//	if (a_cpu == ADR_A_RAM_2) adr [23:16] <= d_cpu;
					//				if (a_cpu == ADR_A_RAM_3) adr [31:24] <= d_cpu;

									if (a_cpu == ADR_LEN_0) len [7:0] <= d_cpu;
									if (a_cpu == ADR_LEN_1) len [15:8] <= d_cpu;
									if (a_cpu == ADR_LEN_2) len [23:16] <= d_cpu;
					//				if (a_cpu == ADR_LEN_3) len [31:24] <= d_cpu;

									if (a_cpu == ADR_START_ADR_0) start_adr [7:0] <= d_cpu;
									if (a_cpu == ADR_START_ADR_1) start_adr [15:8] <= d_cpu;
									if (a_cpu == ADR_START_ADR_2) start_adr [23:16] <= d_cpu;
					//				if (a_cpu == ADR_START_ADR_3) start_adr [31:24] <= d_cpu;
									if (a_cpu == LOW_LEVEL_CTRL) low_level_ctrl [7:0] <= d_cpu;
									if (a_cpu == GPIO_DATA_0) gpio_a [7:0] <= d_cpu;
									if (a_cpu == GPIO_DATA_1) gpio_b [7:0] <= d_cpu;
									if (a_cpu == GPIO_DATA_2) gpio_c [6:0] <= d_cpu;
								
									if (a_cpu == WR_STRB) wrstrb <= 1'b0;
					//				if (!wrstrb) adr <= adr + 1;
								end					
					2'b11 :	begin
									wrstrb <= 1'b1;
									mode [23:21] <= 3'b0;	// clear leave tlr, rti, paxr bits
								end
				endcase
			end

	always @(negedge ioreq_or_wr)
								begin
									if (a_cpu == ADR_A_RAM_0) adr [7:0] <= d_cpu;
									if (a_cpu == ADR_A_RAM_1) adr [15:8] <= d_cpu;
									if (a_cpu == ADR_A_RAM_2) adr [23:16] <= d_cpu;
					//				if (a_cpu == ADR_A_RAM_3) adr [31:24] <= d_cpu;

									if (a_cpu == INC_ADR) adr <= adr + 1;
								end					
	


// gpio begin
	inout [7:0] gpio_0;
	inout [7:0] gpio_1;
	inout [6:0] gpio_2;

	assign gpio_0[0] = gpio_a[0] ? 1'bz : 1'b0;
   assign gpio_0[1] = gpio_a[1] ? 1'bz : 1'b0;
   assign gpio_0[2] = gpio_a[2] ? 1'bz : 1'b0;
   assign gpio_0[3] = gpio_a[3] ? 1'bz : 1'b0;
   assign gpio_0[4] = gpio_a[4] ? 1'bz : 1'b0;
   assign gpio_0[5] = gpio_a[5] ? 1'bz : 1'b0;
   assign gpio_0[6] = gpio_a[6] ? 1'bz : 1'b0;
   assign gpio_0[7] = gpio_a[7] ? 1'bz : 1'b0;	

   assign gpio_1[0] = gpio_b[0] ? 1'bz : 1'b0;
//	assign gpio_1[1] = gpio_b[1] ? 1'bz : 1'b0;
//	assign gpio_1[2] = gpio_b[2] ? 1'bz : 1'b0;
   assign gpio_1[3] = gpio_b[3] ? 1'bz : 1'b0;
   assign gpio_1[4] = gpio_b[4] ? 1'bz : 1'b0;
   assign gpio_1[5] = gpio_b[5] ? 1'bz : 1'b0;
   assign gpio_1[6] = gpio_b[6] ? 1'bz : 1'b0;
   assign gpio_1[7] = gpio_b[7] ? 1'bz : 1'b0;	

   assign gpio_2[0] = gpio_c[0] ? 1'bz : 1'b0;
   assign gpio_2[1] = gpio_c[1] ? 1'bz : 1'b0;
   assign gpio_2[2] = gpio_c[2] ? 1'bz : 1'b0;
   assign gpio_2[3] = gpio_c[3] ? 1'bz : 1'b0;
   assign gpio_2[4] = gpio_c[4] ? 1'bz : 1'b0;
   assign gpio_2[5] = gpio_c[5] ? 1'bz : 1'b0;
   assign gpio_2[6] = gpio_c[6] ? 1'bz : 1'b0;
//   assign gpio_2[7] = gpio_c[7] ? 1'bz : 1'b0;	


	//reading from gpio and register file
	wire ioreq_or_rd;
	assign ioreq_or_rd = io_req_cpu | rd_cpu;

	reg [3:0] reg_en;
	always @*
			begin
				casex({reset,ioreq_or_rd})
					2'b0x : reg_en <= 4'b1111;
					
					2'b10 : 	begin
									case(a_cpu)
										GPIO_DATA_0: reg_en[0] <= 0;
										GPIO_DATA_1: reg_en[1] <= 0;
										GPIO_DATA_2: reg_en[2] <= 0;
									endcase
								end
								
					default : reg_en <= 4'b1111;			
					
				endcase
			end


	assign d_cpu = reg_en[0] ? 8'hzz : gpio_0;					
	assign d_cpu = reg_en[1] ? 8'hzz : gpio_1;
	assign d_cpu = reg_en[2] ? 8'hzz : gpio_2;

endmodule
