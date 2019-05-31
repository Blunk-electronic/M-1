// syncronizes and detects edge

module conditioner(
    clk,
    reset_n,
    input_async,
    output_edge,
    edge_detect
    );

    `include "parameters_global.v" 
        
    input clk;
    input reset_n;
    input input_async;
    input edge_detect;
    output output_edge;
    //assign output_edge = 1;

    // SYNCRONIZING
    wire sync;
    syncronizer sy1 (
    .clk(clk),
    .reset_n(reset_n),
    .input_async(input_async),
    .output_sync(output_sync)
    );

    // EDGE DETECTION
	edge_detector ed1 (
		.clk(clk),
		.reset_n(reset_n),
		.out(output_edge),
		.in(output_sync),
        .edge_detect(edge_detect)
		
	);

endmodule
