`include "parameters_rs232.v"	


module sim_rs232_timer;

	// Inputs
	reg clk;
	reg reset_n;
	reg start;

	// Outputs
	wire done;
	wire [`timer_state_width-1:0] state;

	// Instantiate the Unit Under Test (UUT)
	rs232_timer uut (
		.clk(clk), 
		.reset_n(reset_n), 
		.start(start), 
		.done(done), 
		.state(state)
	);

	
    task start_timer;
        begin
            @(posedge clk);
            $display("time: %d : start timer", $time);
            start = 1;
            #30
            start = 0;
        end 
    endtask
	
	
	initial begin
		// Initialize Inputs
		clk = 0;
		reset_n = 0;
		start = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		reset_n = 1;
		#100;		
		
        start_timer;
        
        #300;
        start_timer;
        
	end

    always #10 clk = ~clk; // 50Mhz main clock // period 20ns 
	
endmodule

