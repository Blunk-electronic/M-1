`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   08:26:14 07/21/2011
// Design Name:   executor
// Module Name:   /home/luno/ise-projects/BSC_V2/ex_sim.v
// Project Name:  BSC_v2
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: executor
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module ex_sim;

	`include "parameters.v"

	// Inputs
	reg [23:0] start_addr;
	reg [7:0] ram_data;
	reg clk;
	reg [7:0] mode;
	reg tdi_1;
	reg tdi_2;
	reg start;	// L-active
	reg stop;		// L-active
	reg reset;

	// Outputs
	wire active;
	wire [23:0] ram_addr;
	wire [2:0] selected_bit;
	wire [15:0] step_id;
	wire bit_data;
	wire tdo_1;
	wire tdo_2;
	wire tms_1;
	wire tms_2;
	wire tck_1;
	wire tck_2;
	wire trst_1;
	wire trst_2;
	wire exp_1;
	wire [7:0] exec_state;
	wire run;
	wire [7:0] debug;
	
	tri1 scl;
	
	// BIDIRs
	tri1 sda;
	
	// Instantiate the Unit Under Test (UUT)
	executor uut (
		.reset(reset),
		.start(start),	// L-active
		.stop(stop),		// L-active
		.active(active), 
		.start_addr(start_addr), 
		.ram_addr(ram_addr), 
		.ram_data(ram_data), 
		.tdo_1(tdo_1), 
		.tdo_2(tdo_2), 
		.tdi_1(tdi_1), 
		.tdi_2(tdi_2), 
		.tms_1(tms_1), 
		.tms_2(tms_2), 
		.tck_1(tck_1), 
		.tck_2(tck_2),
		.trst_1(trst_1),
		.trst_2(trst_2),
		.fail_1(fail_1),
		.fail_2(fail_2),
		.exp_1(exp_1),
		.fail_any_chain(fail_any_chain),
		.clk(clk), 
		.mode(mode), 
		.exec_state(exec_state), 
		.run(run), 
		.debug(debug),
		.step_id(step_id),
		.pass(pass),
		.sda(sda),
		.scl(scl)
	);
	
	wire [7:0] muxer_data_out;
	// Instantiate the Unit Under Test (UUT) -> the I2C slave in this case
	I2CslaveWith8bitsIO is1(
		.SDA(sda),
		.SCL(scl),
		.IOout(muxer_data_out),
		.ADR(muxer_addr)
		);
		


	reg [7:0] ram_out[0:1024];

	initial begin
		load_virtual_output_ram(1024);	
	end

	initial begin
		//ram_data = 8'hzz;
		//ram_data = 8'h04; //active ? 8'hzz : ram_out[ram_addr];
		//always 
			assign ram_data = active ? 8'hzz : ram_out[ram_addr];
		//	ram_data = 8'h01; //ram_out[ram_addr];
	end
	
	initial begin
		clk = 1'b0;
		forever #10 clk = ~clk;
		end

	reg fault;
	initial
		begin
			fault = 1'b1;
			#740000 fault = 1'b0;
			//#100000 fault = 1'b1;
		end

	initial 
		forever
		begin
			@(negedge tck_1)
				begin
					case (debug[3:0])
						shift_ir,
						shift_dr		:	tdi_1 = fault & exp_1;
						exit1_ir,
						exit1_dr		:	tdi_1 = 1;
					endcase
				end
		end

	initial begin
		mode = 8'hFF;
		reset = 1;
		start = 1;
		stop = 1;
		start_addr = 24'h000000;

		#95
		reset = 0;
		#50 reset = 1;
		#50 mode = 8'h10;
		
		#200000;
		start = 0;
		#1000;
		start = 1;
		
		//tdi_1 = 0;
		//tdi_2 = 1;		
		
		//#500000;
		//stop = 0;
		//#1000;
		//stop = 1;
		
		#2000000;
		mode = 8'hFF;
		#100;
		end

///////////////////////////////////////////////////////////////////////////////////7
		task load_virtual_output_ram;
				input integer bytes;
				//integer bytes;
				reg [7:0] input_file_data_byte;
				integer input_file_name;
				//reg [23:0] ram_address;
				integer file_pointer;

			begin
		
			//input_file_name = $fopen("/home/luno/rechner/server_scratch/osc_test.vec", "rb");
			input_file_name = $fopen("/home/luno/rechner/server_scratch/infra.vec", "rb");
			//input_file_name = $fopen("/home/luno/bst_v2/MMU_V101/infra/infra.vec", "rb");

			//	input_file_name = $fopen("vec/infra2.vec", "rb"); // last
			//input_file_name = $fopen("vec/infra1.vec", "rb");

				for (file_pointer = 0; file_pointer < bytes ; file_pointer = file_pointer + 1 )
					begin
						input_file_data_byte = $fgetc(input_file_name);
						//ram_address = file_pointer;
						ram_out[file_pointer] = input_file_data_byte;
					end
			end
		endtask

/////////////////////////////////////////////////////////////////////////////////////////////////
	
			
endmodule

