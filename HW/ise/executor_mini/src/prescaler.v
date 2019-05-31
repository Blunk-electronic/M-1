//`timescale 1ns / 1ps

module prescaler (clk, out_25, out_24, out_23, out_22, out_21, out_3, out_2, reset_n);

    input       clk;
    output      out_3;  // 50 MHz / 16 = 3.15Mhz
    output      out_2;  // 50 MHz / 4 = 12.5Mhz    
    output      out_21; // about 16hz    
    output      out_22; // about 8hz        
    output      out_23; // about 4hz
    output      out_24; // about 2hz    
    output      out_25; // about 1hz
    input       reset_n;
    
    reg         [27:0] counter;
    assign      out_25 = counter[25];
    assign      out_24 = counter[24];
    assign      out_23 = counter[23];
    assign      out_22 = counter[22];                
    assign      out_21 = counter[21];    
    assign      out_3 = counter[3];
    assign      out_2 = counter[1];    


    always @(posedge clk) begin
        if (~reset_n)
            counter <= -1;
        else
            counter <= counter + 1;
    end
endmodule 
