`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:43:11 12/15/2011
// Design Name:   pulse_maker
// Module Name:   /home/luno/ise-projects/bsc_v3/executor/pm_sim.v
// Project Name:  exec_v2
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: pulse_maker
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module pm_sim;

	// Inputs
	reg clk;
	reg reset;
	reg in;

	// Outputs
	wire out;

	// Instantiate the Unit Under Test (UUT)
	pulse_maker3 uut (
		.clk(clk), 
		.reset(reset), 
		.in(in), 
		.out(out)
	);

	initial begin
		clk = 1'b0;
		forever #20 clk = ~clk;
		end

	initial begin
		// Initialize Inputs
		reset = 1;
		in = 1;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		reset = 0;
		#100;
		reset = 1;
		#90;
		// ready
		
		in = 0;

		
		#220 in = 1;
		#200 in = 0;
		#220 in = 1;
		#200 reset = 0;

	end
      
endmodule

