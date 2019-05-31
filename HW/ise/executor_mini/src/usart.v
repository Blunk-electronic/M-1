module usart(
    reset_n,
    clk,
   
    rs232_cts,
    rs232_rts,
    rs232_txd,
    rs232_rxd,
    
    general_purpose_out,
    data_write_strobe,
    general_purpose_in,
    
    debug
    );

    `include "parameters_global.v"	

    input reset_n;
    input clk;
    
    input rs232_cts;
    output rs232_txd;
    output rs232_rts;
    input rs232_rxd;

    wire [`uart_data_width-1:0] rx_data;
    reg rs232_rx_ack;
    reg [`uart_data_width-1:0] tx_data;
    reg tx_start;
    
    output [`uart_data_width-1:0] debug; 

	output reg [111:0] general_purpose_out; // 14d write registers
    output reg data_write_strobe;
	input      [335:0] general_purpose_in; // 42d read registers
    
    rs232 rs232(
        .clk(clk),
        .reset_n(reset_n),
        
        // TRANSMITTER
        .tx_ready(rs232_tx_ready), // out
        .tx_data(tx_data), // in
        .tx_start(tx_start), // in
        .cts(rs232_cts), // in
        .txd(rs232_txd), // out
        
        // RECEIVER
        .rts(rs232_rts), // out
        .rxd(rs232_rxd), // in
        .rx_data(rx_data), // out
        .rx_ready(rs232_rx_ready), // out
        .rx_ack(rs232_rx_ack) // in

        //.debug(debug) // out
    );
    
    reg [`uart_state_width-1:0] state; // the state of the uart machine
    reg [`uart_data_width-1:0] rx_latch; // holds the raw byte provided by the rs232 receiver
    
    // UPLINK HAMMING DECODER (FOR RX DATA)
    reg [`uart_data_width-1:0] ham_decoder_data_in;
    wire [`uart_data_width-1:0] ham_decoder_data_out;
    reg [`uart_rx_hamming_decoder_edc_width:0] ham_decoder_edc_in;
    reg [`uart_rx_error_counter_width-1:0] rx_error_count; 
    wire ham_decoder_error;
    
    // the hamming decoder is fully combinatorical. no clock, no reset required.
    hamdec hd1(
        .data_in(ham_decoder_data_in),
        .edc_in(ham_decoder_edc_in),
        .data_out(ham_decoder_data_out),
        .error(ham_decoder_error)
        );        

    // DOWNLINK HAMMING ENCODER (FOR TX DATA)        
    reg [`uart_data_width-1:0] ham_encoder_data_in;
    //wire [`uart_data_width-1:0] ham_encoder_data_out;    
    wire [`uart_tx_hamming_decoder_edc_width:0] ham_encoder_edc_out;

    // the hamming encoder is fully combinatorical. no clock, no reset required.
    hamenc he1(
        .data_in(tx_data),
        //.data_out(ham_encoder_data_out),
        .edc_out(ham_encoder_edc_out)        
        );        

        
        
        
        
    reg [`uart_data_width-1:0] addr; // the register address
    
    reg [`uart_byte_type_width-1:0] byte_type; // indicates what kind of data is to expect from host
    reg write_read; // indicates direction (write/read access)
    reg [`uart_page_byte_counter_width-1:0] page_byte_counter; // when transferring a data page, it counts bytes of a page
    //assign debug = byte_type;

    wire header_write_read      = rx_latch[0]; // when write -> 0, when read -> 1
    wire header_page            = rx_latch[1]; // when page of data is to transfer -> 1
   
    
    always @(posedge clk or negedge reset_n) begin : fsm_uart_rx
        if (~reset_n) 
            begin
                state           <= #`DEL UART_STATE_IDLE;
                addr            <= #`DEL `uart_data_width'b0;
                rx_latch        <= #`DEL `uart_data_width'b0;
                
                ham_decoder_data_in <= #`DEL `uart_data_width'b0;
                ham_decoder_edc_in  <= #`DEL `uart_rx_hamming_decoder_edc_width'b0;
                rx_error_count      <= #`DEL `uart_rx_error_counter_width'b0;
                ham_encoder_data_in <= #`DEL `uart_data_width'b0;
                
                rs232_rx_ack    <= #`DEL 0;
                tx_data         <= #`DEL `uart_data_width'b0;
                tx_start        <= #`DEL 0;
                byte_type       <= #`DEL UART_TYPE_HEADER;
                write_read      <= #`DEL 0;
                
                page_byte_counter           <= #`DEL `uart_page_byte_counter_width'b0;
                
                general_purpose_out[63:0]   <= #`DEL -1;
                general_purpose_out[111:64] <= #`DEL 0; // this is breakpoint data, must be cleared on reset
                data_write_strobe           <= #`DEL 1'b0;
            end
        else
            begin
                case (state) // synthesis parallel_case
                    UART_STATE_IDLE:
                        if (rs232_rx_ready) // if data available -> latch it in ham_decoder_data_in
                            begin
                                rs232_rx_ack        <= #`DEL 1; // acknowledge data reception to rs232
                                ham_decoder_data_in <= #`DEL rx_data;
                                data_write_strobe   <= #`DEL 1'b0;
                                state               <= #`DEL UART_STATE_RX_HAM_EDC_1;
                            end

                    UART_STATE_RX_HAM_EDC_1:
                        begin
                            rs232_rx_ack    <= #`DEL 0; // clear acknowledge                    
                            state           <= #`DEL UART_STATE_RX_HAM_EDC_2;
                        end

                    UART_STATE_RX_HAM_EDC_2: // await edc codes
                        if (rs232_rx_ready) // if data available -> latch in ham_decoder_edc_in
                            begin
                                rs232_rx_ack        <= #`DEL 1; // acknowledge data reception to rs232
                                ham_decoder_edc_in  <= #`DEL rx_data[`uart_rx_hamming_decoder_edc_width-1:0];
                                state               <= #`DEL UART_STATE_COUNT_RX_ERRORS;
                            end
                        
                    UART_STATE_COUNT_RX_ERRORS:
                        begin
                            rs232_rx_ack    <= #`DEL 0; // clear acknowledge                    
                            rx_latch        <= #`DEL ham_decoder_data_out; // latch hamming decoder output in rx_latch
                            //rx_latch        <= #`DEL ham_decoder_data_in; // tempoarily
                            
                            state           <= #`DEL UART_STATE_READY;
                            if (ham_decoder_error) // count rx errors
                                begin
                                    rx_error_count  <= #`DEL rx_error_count + 1;
                                end                                
                        end
                            
                    UART_STATE_READY:
                            begin
                                //rs232_rx_ack    <= #`DEL 0; // clear acknowledge
                                
                                case (byte_type) // synthesis parallel_case
                                    UART_TYPE_HEADER:
                                        begin                             
                                            if (header_write_read == UART_DIR_READ)  // if direction is read
                                                begin
                                                    write_read  <= #`DEL UART_DIR_READ;
                                                end
                                            else // direction is write
                                                begin
                                                    write_read  <= #`DEL UART_DIR_WRITE;
                                                end

                                            if (header_page) // if page bit set in header, assume next byte is first byte in data page
                                                begin
                                                    byte_type   <= #`DEL UART_TYPE_DATA_PAGE;
                                                end
                                            else // no page, default mode assumes next byte is address
                                                begin
                                                    byte_type   <= #`DEL UART_TYPE_ADDRESS; // next byte is address
                                                end
                                                
                                            state       <= #`DEL UART_STATE_IDLE; // wait for next byte
                                        end
                                        
                                    UART_TYPE_ADDRESS:
                                        begin
                                            addr            <= #`DEL rx_latch;
                                            if (write_read == UART_DIR_READ)
                                                begin
                                                    byte_type   <= #`DEL UART_TYPE_HEADER; // next byte (to receive) is header
                                                    state       <= #`DEL UART_STATE_TX_1;
                                                end
                                            else
                                                begin
                                                    byte_type   <= #`DEL UART_TYPE_DATA; // next byte is data
                                                    state       <= #`DEL UART_STATE_IDLE; // wait for next byte
                                                end
                                        end
                                        
                                    UART_TYPE_DATA:
                                        begin               
                                            case (addr) // synthesis parallel_case
                                                UART_REG_0:
                                                    begin // while write cycle to data channel (80h), write strobe is low, write strobe goes high when cycle ends
                                                        general_purpose_out [7:0]    <= #`DEL rx_latch;
                                                        data_write_strobe            <= #`DEL 1'b1; // notify mmu that data is available
                                                    end
                                                UART_REG_1:     general_purpose_out [15:8]      <= #`DEL rx_latch;  // 81h address lowbyte
                                                UART_REG_2:     general_purpose_out [23:16]     <= #`DEL rx_latch;  // 82h 
                                                UART_REG_3:     general_purpose_out [31:24]     <= #`DEL rx_latch;  // 83h address highbyte
                                                UART_REG_4:     general_purpose_out [39:32]     <= #`DEL rx_latch; //cmd channel 84h
                                                UART_REG_B:     general_purpose_out [47:40]     <= #`DEL rx_latch; //signal path 8Bh
                                                UART_REG_C:     general_purpose_out [55:48]     <= #`DEL rx_latch; //frequency 8Ch
                                                UART_REG_18:    general_purpose_out [63:56]     <= #`DEL rx_latch; //test start/stop 89
                                                UART_REG_27:    general_purpose_out [71:64]     <= #`DEL rx_latch; // breakpoint / step id lowbyte // A7h
                                                UART_REG_28:    general_purpose_out [79:72]     <= #`DEL rx_latch; // breakpoint / step id highbyte // A8h
                                                UART_REG_29:    general_purpose_out [87:80]     <= #`DEL rx_latch; // breakpoint / bit position lowbyte // A9h
                                                UART_REG_2A:    general_purpose_out [95:88]     <= #`DEL rx_latch; // breakpoint / bit position lowbyte+1 // AAh
                                                UART_REG_2B:    general_purpose_out [103:96]    <= #`DEL rx_latch; // breakpoint / bit position lowbyte+2 // ABh
                                                UART_REG_2C:    general_purpose_out [111:104]   <= #`DEL rx_latch; // breakpoint / bit position highbyte // ACh
                                            endcase
                                            
                                            byte_type       <= #`DEL UART_TYPE_HEADER; // next byte is header
                                            state           <= #`DEL UART_STATE_IDLE; // wait for next byte
                                        end
                                        
                                    UART_TYPE_DATA_PAGE:
                                        begin   // On every sent to the mmu, count bytes in page_byte_counter. 
                                                // page_byte_counter assumes 1 after the first byte was sent to the mmu.
                                                // page_byte_counter assumes 255 after the 255th byte was sent to the mmu.                                                
                                                
                                                // The 256th (UART_PAGE_SIZE) byte causes page_byte_counter to reset.
                                                // The page end has been reached.
                                                // The byte_type to expect is UART_TYPE_HEADER.
                                                
                                            if (page_byte_counter < UART_PAGE_SIZE - 1)
                                                begin                                           
                                                    page_byte_counter           <= #`DEL page_byte_counter + 1;
                                                end
                                            else // end of page. last byte
                                                begin
                                                    page_byte_counter           <= #`DEL `uart_page_byte_counter_width'b0;
                                                    byte_type                   <= #`DEL UART_TYPE_HEADER;
                                                end

                                            general_purpose_out [7:0]   <= #`DEL rx_latch;
                                            data_write_strobe           <= #`DEL 1'b1; // notify mmu that data is available                                              
                                            state                       <= #`DEL UART_STATE_IDLE; // wait for next byte                                                
                                        end
                                    
                                endcase
                            end
                    
                    UART_STATE_TX_1:
                            begin
                                case (addr) // synthesis parallel_case
                                    UART_REG_0:
                                        begin
                                            tx_data <= #`DEL general_purpose_in  [7:0];	    // 80 (data channel)
                                            
                                            // reading from data channel increments address
                                            general_purpose_out [31:8] <= #`DEL general_purpose_out [31:8] + 1;
                                        end
                                        
                                    UART_REG_1:     tx_data <= #`DEL general_purpose_out [15:8];    // 81
                                    UART_REG_2:     tx_data <= #`DEL general_purpose_out [23:16];   // 82
                                    UART_REG_3:     tx_data <= #`DEL general_purpose_out [31:24];   // 83
                                    UART_REG_4:     tx_data <= #`DEL general_purpose_out [39:32];   // 84
                                    UART_REG_5:     tx_data <= #`DEL general_purpose_in  [15:8];  
                                    UART_REG_6:     tx_data <= #`DEL general_purpose_in  [23:16];
                                    UART_REG_7:     tx_data <= #`DEL general_purpose_in  [31:24];
                                    UART_REG_8:     tx_data <= #`DEL general_purpose_in  [39:32];
                                    UART_REG_9:     tx_data <= #`DEL general_purpose_in  [47:40];		
                                    UART_REG_A:     tx_data <= #`DEL general_purpose_in  [55:48];	// 8A		
                                    UART_REG_B:     tx_data <= #`DEL general_purpose_out [47:40];	// 8B
                                    UART_REG_C:     tx_data <= #`DEL general_purpose_in  [63:56];	// 8C
                                    UART_REG_D:     tx_data <= #`DEL general_purpose_in  [71:64];			
                                    UART_REG_E:     tx_data <= #`DEL general_purpose_in  [79:72];			
                                    UART_REG_F:     tx_data <= #`DEL general_purpose_in  [87:80];	// 8F
                                    UART_REG_10:    tx_data <= #`DEL general_purpose_in  [95:88];	// 90
                                    UART_REG_11:    tx_data <= #`DEL general_purpose_in  [103:96];	
                                    UART_REG_12:    tx_data <= #`DEL general_purpose_in  [111:104];				
                                    UART_REG_13:    tx_data <= #`DEL general_purpose_in  [119:112];	// 93		
                                    UART_REG_14:    tx_data <= #`DEL general_purpose_in  [127:120];	// 94
                                    UART_REG_15:    tx_data <= #`DEL general_purpose_in  [135:128];	// 95
                                    UART_REG_16:    tx_data <= #`DEL general_purpose_in  [143:136];	// 96					
                                    UART_REG_17:    tx_data <= #`DEL general_purpose_in  [151:144];	// 97
                                    UART_REG_18:    tx_data <= #`DEL general_purpose_in  [159:152];	// 98
                                    UART_REG_19:    tx_data <= #`DEL general_purpose_in  [167:160];	// 99
                                    UART_REG_1A:    tx_data <= #`DEL general_purpose_in  [175:168];	// 9A
                                    UART_REG_1B:    tx_data <= #`DEL general_purpose_in  [183:176];	// 9B
                                    UART_REG_1C:    tx_data <= #`DEL general_purpose_in  [191:184];	// 9C
                                    UART_REG_1D:    tx_data <= #`DEL general_purpose_in  [199:192];	// 9D
                                    UART_REG_1E:    tx_data <= #`DEL general_purpose_in  [207:200];	// 9E
                                    UART_REG_1F:    tx_data <= #`DEL general_purpose_in  [215:208];	// 9F		
                                    UART_REG_20:    tx_data <= #`DEL general_purpose_in  [223:216];	// A0		
                                    UART_REG_21:    tx_data <= #`DEL general_purpose_in  [231:224];	// A1			
                                    UART_REG_22:    tx_data <= #`DEL general_purpose_in  [239:232];	// A2
                                    UART_REG_23:    tx_data <= #`DEL general_purpose_in  [7:0];	    // A3 (data channel)
                                    UART_REG_24:    tx_data <= #`DEL general_purpose_in  [247:240];	// A4
                                    UART_REG_25:    tx_data <= #`DEL general_purpose_in  [255:248];	// A5
                                    UART_REG_26:    tx_data <= #`DEL general_purpose_in  [263:256];	// A6
                                    UART_REG_27:    tx_data <= #`DEL general_purpose_in  [271:264];	// A7
                                    UART_REG_28:    tx_data <= #`DEL general_purpose_in  [279:272];	// A8
                                    UART_REG_29:    tx_data <= #`DEL general_purpose_in  [287:280];	// A9
                                    UART_REG_2A:    tx_data <= #`DEL general_purpose_in  [295:288];	// AA
                                    UART_REG_2B:    tx_data <= #`DEL general_purpose_in  [303:296];	// AB
                                    UART_REG_2C:    tx_data <= #`DEL general_purpose_in  [311:304];	// AC
                                    UART_REG_2D:    tx_data <= #`DEL general_purpose_in  [319:312];	// AD
                                    UART_REG_2E:    tx_data <= #`DEL general_purpose_in  [327:320];	// AE
                                    UART_REG_2F:    tx_data <= #`DEL general_purpose_in  [335:328];	// AF
                                    
                                    UART_REG_30:    tx_data <= #`DEL rx_error_count  [7:0];	// B0h // NOTE: Mind `uart_rx_error_counter_width
                                    UART_REG_31:    tx_data <= #`DEL rx_error_count [15:8];	// B1h                                    
                                    
                                    // all other addresses return "null" (00h) // CS: better FFh ?
                                    default:        tx_data <= #`DEL `uart_data_width'h00;
                                endcase                                                             

                                state       <= #`DEL UART_STATE_TX_2;
                            end
                            
                    UART_STATE_TX_2:
                            begin
                                if (rs232_tx_ready)
                                    begin
                                        tx_start    <= #`DEL 1; // initiate sending of data (in tx_data)
                                        state       <= #`DEL UART_STATE_TX_3; 
                                        
                                        ham_encoder_data_in <= #`DEL tx_data;
                                    end
                            end
                    
                    UART_STATE_TX_3:
                            begin
                                tx_start    <= #`DEL 0;
                                //state       <= #`DEL UART_STATE_IDLE;

                                tx_data     <= #`DEL ham_encoder_edc_out;                                
                                state       <= #`DEL UART_STATE_TX_EDC_1;
                            end

                    UART_STATE_TX_EDC_1:
                            begin
                                if (rs232_tx_ready)
                                    begin
                                        tx_start    <= #`DEL 1; // initiate sending of edc (in tx_data)
                                        state       <= #`DEL UART_STATE_TX_EDC_2; 
                                    end
                            end

                    UART_STATE_TX_EDC_2:
                            begin
                                tx_start    <= #`DEL 0;
                                state       <= #`DEL UART_STATE_IDLE;
                            end
                            
                endcase
            end
    end
    
endmodule

