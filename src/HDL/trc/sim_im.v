`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:08:31 09/23/2011
// Design Name:   i2c_master
// Module Name:   /home/luno/ise-projects/transceiver/sim_im.v
// Project Name:  transceiver
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: i2c_master
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module sim_im;

	// Inputs
	reg clk;
	reg [7:0] data_tx;
	reg [6:0] addr;
	reg reset;
	reg start;

	// Outputs
	wire ack_fail;
	wire ready;
	tri1 scl;

	// Bidirs
	tri1 sda;

	// Instantiate the Unit Under Test (UUT)
	i2c_master uut (
		.clk(clk), 
		.data_tx(data_tx), 
		.addr(addr), 
		.reset(reset), 
		.ack_fail(ack_fail), 
		.ready(ready),
		.start(start),
		.sda(sda), 
		.scl(scl)
	);

	initial begin
		clk = 1'b0;
		forever #10 clk = ~clk;
	end

	initial begin
		// Initialize Inputs
//		clk = 0;
		data_tx = 8'hEE;
		addr = 7'h03;
		reset = 1'b1;
		start = 1'b1;

		// Wait 100 ns for global reset to finish
		#100 reset = 1'b0;        
		#60 reset = 1'b1;        		
		// Add stimulus here
		//#540 force sda = 1'b0;
		//#570 release sda;
		
		#100 start = 0;
		//#120 start = 1;
		
		#3000 reset = 1'b0;        
		#60 reset = 1'b1;        		

	end
      
endmodule

