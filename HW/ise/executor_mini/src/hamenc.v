module hamenc (
    data_in,
    edc_out
    );

    `include "parameters_global.v"	

    // INPUTS
    input [`uart_data_width-1:0] data_in;                   // Input data

    // OUTPUTS
    output [`uart_rx_hamming_decoder_edc_width-1:0] edc_out;  // EDC bits

    assign #`DEL edc_out[3] = data_in[7] ^ data_in[6] ^ data_in[4] ^ data_in[3] ^ data_in[1];
    assign #`DEL edc_out[2] = data_in[7] ^ data_in[5] ^ data_in[4] ^ data_in[2] ^ data_in[1];
    assign #`DEL edc_out[1] = data_in[6] ^ data_in[5] ^ data_in[4] ^ data_in[0];
    assign #`DEL edc_out[0] = data_in[3] ^ data_in[2] ^ data_in[1] ^ data_in[0];
    
    
endmodule
