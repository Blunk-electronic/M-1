`timescale 1ns / 1ps

// V0.1 	- initial
// V0.2	- exec_state test_sxr_delay also starts timer

module timer(
		// inputs
		reset,
		clk_timer, //10hz
		clk,
		exec_state,
		llct,
		llcc,
		
		//output
		timeout
	);

	// inputs
	input reset;
	input [7:0] exec_state;
	input clk;
	input clk_timer;
	input [7:0] llct;	//CS: applies for all chains
	input [7:0] llcc;	//CS: applies for all chains

	//outputs
	output timeout;
	
	`include "parameters.v"
	


	reg ex_llc;
	always @(negedge clk)
		begin		// start low level cmd execution depending on exec_state and if type is time_operation only
			if ((exec_state == test_fetch_low_level_cmd_done | exec_state == test_sxr_delay) & llct == time_operation) ex_llc <= 0;  // mod V0.2
				else ex_llc <= 1;
		end


	reg [7:0] timer;
	always @(posedge clk_timer or posedge ex_llc)  //count up timer on posedge clk_timer, reset timer on posedge ex_llc
		begin	
			if (ex_llc) timer <= 0; 
			else if (timer < llcc) timer <= timer + 1 ;
				else timer <= 0;
		end
			
		
	reg timeout_raw;
	always @(negedge clk)	// if timer reaches value given by llcc, output L active timeout_raw
		begin
			if (timer == llcc) timeout_raw <= 0;
				else timeout_raw <= 1;
		end
		
		
	// shrink timeout_raw signal to one clk cycle	
	pulse_maker pm_timeout(
		.clk(clk),
		.reset(reset),
		.in(timeout_raw), // L active // sampled on posedge of clk
		.out(timeout) // L active , updated on negedge of clk  -> notifies executor about timeout
		);

		
endmodule