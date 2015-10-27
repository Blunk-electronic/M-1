`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:59:09 09/29/2011
// Design Name:   i2c_controller
// Module Name:   /home/luno/ise-projects/transceiver/sim_ic.v
// Project Name:  transceiver
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: i2c_controller
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module sim_ic;

	// Inputs
	reg clk;
	reg [7:0] data_tx1;
	reg [7:0] data_tx2;
	reg [7:0] data_tx3;
	reg [6:0] addr_slave1;
	reg [6:0] addr_slave2;
	reg [6:0] addr_slave3;
	reg reset;

	// Outputs
	wire ack_fail;
	tri1 scl;

	// Bidirs
	tri1 sda;

	// Instantiate the Unit Under Test (UUT)
	i2c_controller uut (
		.clk(clk), 
		.data_tx1(data_tx1), 
		.data_tx2(data_tx2), 
		.data_tx3(data_tx3), 
		.addr_slave1(addr_slave1), 
		.addr_slave2(addr_slave2), 
		.addr_slave3(addr_slave3), 
		.reset(reset), 
		.ack_fail(ack_fail), 
		.sda(sda), 
		.scl(scl)
	);


	initial begin
		clk = 1'b0;
		forever #10 clk = ~clk;
	end


	initial begin
		// Initialize Inputs
		addr_slave1 = 6'h01;
		addr_slave2 = 6'h02;
		addr_slave3 = 6'h03;
		data_tx1 = 7'h10;
		data_tx2 = 7'h20;
		data_tx3 = 7'h80;

		reset = 0;

		// Wait 100 ns for global reset to finish
		#100;
		reset = 1;        
		// Add stimulus here

		#4000 reset = 0;
		
	end
      
endmodule

