/*********************************************************/
// MODULE:         Hamming Code Decoder
//                 for 8-bit data
//
// FILE NAME:      hamdec.v
// VERSION:        1.1
// DATE:           Mon Oct 19 07:47:10 1998
// AUTHOR:         HAMDEC.EXE
// MODIFIED:       Mario Blunk / Blunk electronic
// DATE:           2016-12-14
//
// CODE TYPE:      Register Transfer Level
//
// DESCRIPTION:    This module defines an error detector and
// corrector of single bit errors using Hamming codes.
//
/*********************************************************/


// TOP MODULE
module hamdec(
        data_in,
        edc_in,
        data_out,
        error);
        
    `include "parameters_global.v"	        

    // INPUTS
    input [`uart_data_width-1:0] data_in;                   // Input data
    input [`uart_rx_hamming_decoder_edc_width-1:0] edc_in;  // EDC bits

    // OUTPUTS
    output reg [`uart_data_width-1:0] data_out; // data output
    output reg error;                           // Did an error occur?


    // SIGNAL DECLARATIONS
//     wire [7:0]    data_in;
//     wire [3:0]    edc_in;
//     reg  [7:0]    data_out;
//     reg           error;

    wire [3:0]    syndrome;

    // PARAMETERS

    // ASSIGN STATEMENTS
    assign #`DEL syndrome[0] = edc_in[3] ^ data_in[7] ^ data_in[6] ^ data_in[4] ^ data_in[3] ^ data_in[1];
    assign #`DEL syndrome[1] = edc_in[2] ^ data_in[7] ^ data_in[5] ^ data_in[4] ^ data_in[2] ^ data_in[1];
    assign #`DEL syndrome[2] = edc_in[1] ^ data_in[6] ^ data_in[5] ^ data_in[4] ^ data_in[0];
    assign #`DEL syndrome[3] = edc_in[0] ^ data_in[3] ^ data_in[2] ^ data_in[1] ^ data_in[0];

    // MAIN CODE

    always @(syndrome or data_in) begin
        data_out = data_in;

        case (syndrome)     // synthesis parallel_case full_case
            4'h0: begin
                error = 0;
            end
            4'h1: begin
                error = 1;
            end
            4'h2: begin
                error = 1;
            end
            4'h4: begin
                error = 1;
            end
            4'h8: begin
                error = 1;
            end
            4'h3: begin
                data_out[7] = ~data_in[7];
                error = 1;
            end
            4'h5: begin
                data_out[6] = ~data_in[6];
                error = 1;
            end
            4'h6: begin
                data_out[5] = ~data_in[5];
                error = 1;
            end
            4'h7: begin
                data_out[4] = ~data_in[4];
                error = 1;
            end
            4'h9: begin
                data_out[3] = ~data_in[3];
                error = 1;
            end
            4'ha: begin
                data_out[2] = ~data_in[2];
                error = 1;
            end
            4'hb: begin
                data_out[1] = ~data_in[1];
                error = 1;
            end
            4'hc: begin
                data_out[0] = ~data_in[0];
                error = 1;
            end
            
            // CS: default: error = 1 ???
        endcase
    end
endmodule       // HamDec
