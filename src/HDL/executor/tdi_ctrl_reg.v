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
// Revision 10.1
// Additional Comments: 
//////////////////////////////////////////////////////////////////////////////////

module tdi_ctrl_reg(a_cpu,d_cpu,wr_cpu,rd_cpu,io_req_cpu,m1_cpu,iei_cpu,int_cpu,nmi_cpu,
					mask,exp,fail,meas,state,gpio_0,reset,
					tck_scaler,
					tck_step_ctrl,
					fail_flag,
					dm_fail,
					clk_cpu
					//wr_clk_meas_fail
					);

    input [7:0] a_cpu;
	 inout [7:0] d_cpu;
    input wr_cpu;
    input reset;	 
    input rd_cpu;	 
    input io_req_cpu;
	 input m1_cpu;
	 input iei_cpu;
	 input clk_cpu;
	 //input wr_clk_meas_fail;
	 output int_cpu;
	 output nmi_cpu;
	 
	 output [7:0] exp;
	 output [7:0] mask;	 	 
	 output [23:0] tck_scaler;		// 0 - lowest freq / FFFFFF highest freq
	 output [7:0] tck_step_ctrl;	// controls tck step mode

	 reg [7:0] tck_step_ctrl;	// controls tck step mode
	 reg [23:0] tck_scaler;
	 reg [7:0] exp;
	 reg [7:0] mask;	
	 reg [7:0] gpio_data_0;
	 reg fail_sts;

	 input [7:0] meas;
	 input [7:0] fail;
	 input [7:0] dm_fail;	
	 input fail_flag;

	input [3:0] state;

	parameter BASE_ADR = 8'hA0;
	parameter ADR_EXP  = BASE_ADR+0;
	parameter ADR_MASK = BASE_ADR+1;
	parameter ADR_FAIL = BASE_ADR+2;
	parameter ADR_MEAS = BASE_ADR+3;
	parameter ADR_STATE = BASE_ADR+4;
	parameter FAIL_STS = BASE_ADR+5;

	parameter GPIO_DATA_0 = BASE_ADR+6; // A6
	
	parameter TCK_STEP_MODE = BASE_ADR+7; //A7

// 				4 = 1 -> tck_step_ctrl[0] = clk_out -> single tck step mode
// 				1 = scan_clk tdi_reader
// 				0 = clk_out -> tck
	
	parameter TCK_SCALER_0 = BASE_ADR+8; //A8 
	parameter TCK_SCALER_1 = BASE_ADR+9; //A9 
	parameter TCK_SCALER_2 = BASE_ADR+10; //AA
	
	parameter DM_FAIL = BASE_ADR+11; //AB
		
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


// writing to register file

	wire ioreq_or_wr;
	assign ioreq_or_wr = io_req_cpu | wr_cpu;

	reg clear_fail;
	
//	always @(negedge ioreq_or_wr or negedge reset)	
	always @(posedge clk_cpu)	
			begin
				casex ({reset,ioreq_or_wr})
					2'b0x :	begin
									gpio_data_0 [7:0] <= 8'hFF;
									exp [7:0] <= 8'hff;
									mask [7:0] <= 8'hff;
									tck_scaler [23:0] <= 24'hFFFF00;	// default tck freq = osc/1000
									tck_step_ctrl [7:0] <= 8'h00;		// default free running tck
									clear_fail <= 1'b0; 					
								end 
					2'b10 :	begin
									if (a_cpu == ADR_EXP) exp <= d_cpu;
									if (a_cpu == ADR_MASK) mask <= d_cpu;
									if (a_cpu == GPIO_DATA_0) gpio_data_0 [7:0] <= d_cpu;	
									if (a_cpu == TCK_STEP_MODE) tck_step_ctrl [7:0] <= d_cpu;
									if (a_cpu == TCK_SCALER_0) tck_scaler [7:0] <= d_cpu;
									if (a_cpu == TCK_SCALER_1) tck_scaler [15:8] <= d_cpu;
									if (a_cpu == TCK_SCALER_2) tck_scaler [23:16] <= d_cpu;
									if (a_cpu == FAIL_STS) clear_fail <= 1'b1;  // any write here clears fail flag
								end
					2'b11 :	begin
									clear_fail <= 1'b0;
								end

				endcase
			end

	inout [7:0] gpio_0;

//	assign gpio_0[0] = gpio_data_0[0] ? 1'bz : 1'b0;
   assign gpio_0[1] = gpio_data_0[1] ? 1'bz : 1'b0;
   assign gpio_0[2] = gpio_data_0[2] ? 1'bz : 1'b0;
   assign gpio_0[3] = gpio_data_0[3] ? 1'bz : 1'b0;
   assign gpio_0[4] = gpio_data_0[4] ? 1'bz : 1'b0;
   assign gpio_0[5] = gpio_data_0[5] ? 1'bz : 1'b0;
   assign gpio_0[6] = gpio_data_0[6] ? 1'bz : 1'b0;
   assign gpio_0[7] = gpio_data_0[7] ? 1'bz : 1'b0;


//reading from register file and gpio

	wire ioreq_or_rd;
	assign ioreq_or_rd = io_req_cpu | rd_cpu;

	reg [5:0] reg_en;
	always @*
			begin
				casex({reset,ioreq_or_rd})
					2'b0x : reg_en <= 6'b111111;
					
					2'b10 : 	begin
									case(a_cpu)
										ADR_FAIL:		reg_en[0] <= 0;
										ADR_MEAS:		reg_en[1] <= 0;
										ADR_STATE:		reg_en[2] <= 0;
										GPIO_DATA_0:	reg_en[3] <= 0;	
										FAIL_STS:		reg_en[4] <= 0;	
										DM_FAIL:			reg_en[5] <= 0;	
									endcase
								end
								
					default : reg_en <= 6'b111111;			
					
				endcase
			end	

	
	assign d_cpu = reg_en[0] ? 8'hzz : fail;					
	assign d_cpu = reg_en[1] ? 8'hzz : meas;					
	assign d_cpu = reg_en[2] ? 8'hzz : state;					
	assign d_cpu = reg_en[3] ? 8'hzz : gpio_0;
	assign d_cpu = reg_en[5] ? 8'hzz : dm_fail;	

	
//// int handler //////////////////////////////////////////////////////

	// while shir or shdr set_fail=fail_dm
	// BS: set_fail besser abhaenging von tdo_req machen ?

	//updated on posedge of wr_clk_meas_fail:
	assign set_fail = ((state == shir) | (state == shdr)) ? fail_flag : 1'b0; 

	assign d_cpu[0] = reg_en[4] ? 1'hz : fail_sts;	
	assign d_cpu[1] = reg_en[4] ? 1'bz : set_fail;	

	always @(posedge set_fail or posedge clear_fail)	
		begin
			if (set_fail) fail_sts <= 1'b1;	// set_fail	overrides clear_fail !
			else	fail_sts <= 1'b0;
		end
	assign gpio_0[0] = !fail_sts; // on fail turn red LED on

	assign vec_done_state = ((state == tlr) | (state == rti) | (state == pair) | (state == padr));


	// int source collector:
	//assign int_req = fail_sts | vec_done_state;
	assign int_req = vec_done_state;
	

	// cpu requests interrupt vector:
	assign cpu_vec_req = iei_cpu & (!m1_cpu & !io_req_cpu); // posedge sets /int back to 1

	// regular interrupt requestor
	reg int;
	always @(posedge int_req or posedge cpu_vec_req)
		begin
			if (cpu_vec_req) int <= 1'b1;
			else if (iei_cpu) int <= 1'b0;
		end

	// NMI requestor
	reg nmi;
	reg [1:0] ct;
	wire reset_nmi = ct[1]; //(!m1_cpu & !rd_cpu);
	always @(posedge fail_sts or posedge reset_nmi)
		begin
			if (reset_nmi) nmi <= 1'b1;
			else nmi <= 1'b0;
		end


	always @(negedge clk_cpu)
		begin
			if (!nmi) ct <= ct + 1;
			else ct <= 2'b00;
		end
	
	
   assign int_cpu = int ? 1'bz : 1'b0; //int_cpu is open drain output
//	assign int_cpu = 1'bz;
	assign nmi_cpu = nmi ? 1'bz : 1'b0; //nmi_cpu is open drain output

	// irq vector placing on cpu data bus upon int ack by cpu
//	assign d_cpu = (cpu_vec_req & fail_sts) ? 8'h20 : 8'hzz;
	assign d_cpu = (cpu_vec_req & vec_done_state) ? 8'h22 : 8'hzz;

endmodule

