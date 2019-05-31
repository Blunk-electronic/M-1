// // SYNCRONIZER (with 3 DFF in the signal path)

module syncronizer(
    clk,
    reset_n,
    input_async,
    output_sync
    );
    
    `include "parameters_global.v" 
        
    input clk;
    input reset_n;
    input input_async;

    output reg output_sync;
    reg sync_1;
    reg sync_2;

	always @(posedge clk or negedge reset_n) begin
        if (~reset_n)
            begin
                output_sync                 <= #`DEL 0;
                sync_1                      <= #`DEL 0;
                sync_2                      <= #`DEL 0;                
            end
        else
            begin
                sync_1                      <= #`DEL input_async;
                sync_2                      <= #`DEL sync_1; 
                output_sync                 <= #`DEL sync_2;
            end
	end

endmodule
