module rs232(
    reset_n,
    clk,

    // TRANSMITTER
    tx_ready,
    tx_data,
    tx_start,
    cts,    
    txd,

    // RECEIVER    
    rts,
    rxd,
    rx_data, 
    rx_ready,
    rx_ack,
    
    debug
    );
    
    `include "parameters_global.v"	

    input reset_n;
    input clk;

    // TRANSMITTER
    output reg tx_ready;
    input [`uart_data_width-1:0] tx_data;
    input tx_start;
    input cts;    
    output reg txd;

    // RECEIVER    
    output reg rts;
    input rxd;
    output reg [`uart_data_width-1:0] rx_data; 
    output reg rx_ready;
    input rx_ack;
    
    output [`uart_data_width-1:0] debug;
    assign debug = rx_data;
    
    reg [`rs232_state_tx_width-1:0] rs232_state_tx;
    reg [`rs232_state_rx_width-1:0] rs232_state_rx;   
   
    // SYNCRONIZING
    wire cts_sync;
    syncronizer sy1 (
        .clk(clk),
        .reset_n(reset_n),
        .input_async(cts),
        .output_sync(cts_sync)
        );

    wire rxd_sync;
    syncronizer sy2 (
        .clk(clk),
        .reset_n(reset_n),
        .input_async(rxd),
        .output_sync(rxd_sync)
        );
        
    
    // TRANSMITTER    
    reg timer_tx_start;
    rs232_timer timer_tx(
        .clk(clk),
        .reset_n(reset_n),
        .start(timer_tx_start),
        .done(timer_tx_done),
        .extra_delay(1'b0) // no extra delay
    );

    reg [`uart_data_width-1:0] tx_latch; 
    //reg [2:0] tx_bit_pos;

    always @(posedge clk or negedge reset_n) begin : fsm_tx
        if (~reset_n) 
            begin
                rs232_state_tx  <= #`DEL RS232_STATE_TX_RESET;
                tx_latch        <= #`DEL `uart_data_width'b0;
                txd             <= #`DEL 1;
                timer_tx_start     <= #`DEL 0; 
                //tx_bit_pos      <= #`DEL 3'b0;
                tx_ready        <= #`DEL 0;
            end
        else
            begin
                case (rs232_state_tx) // synthesis parallel_case
                    RS232_STATE_TX_RESET, RS232_STATE_TX_IDLE:
                        begin
                            if (cts_sync == cts_asserted) // transmission may start when host signals "clear to send"
                                begin
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_CTS;
                                    tx_ready        <= #`DEL 1;
                                end
                        end
                    
                    RS232_STATE_TX_CTS:
                        begin
                            if (tx_start) // transmission start on tx_start
                                begin
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_START;
                                    tx_latch        <= #`DEL tx_data;
                                    tx_ready        <= #`DEL 0; 
                                end
                        end
                        
                    RS232_STATE_TX_START: // send start bit
                        begin
                            txd                 <= #`DEL 0; 
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_DATA_0a;
                        end
                        
                    RS232_STATE_TX_DATA_0a:
                        begin
                            timer_tx_start      <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    txd             <= #`DEL tx_latch[0];
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_DATA_0b;                                    
                                end
                        end
                    RS232_STATE_TX_DATA_0b:
                        begin
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_DATA_1a;
                        end

                    RS232_STATE_TX_DATA_1a:
                        begin
                            timer_tx_start      <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    txd             <= #`DEL tx_latch[1];
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_DATA_1b; 
                                end
                        end
                    RS232_STATE_TX_DATA_1b:
                        begin
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_DATA_2a;
                        end

                    RS232_STATE_TX_DATA_2a:
                        begin
                            timer_tx_start      <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    txd             <= #`DEL tx_latch[2];
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_DATA_2b; 
                                end
                        end
                    RS232_STATE_TX_DATA_2b:
                        begin
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_DATA_3a;
                        end
                        
                    RS232_STATE_TX_DATA_3a:
                        begin
                            timer_tx_start      <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    txd             <= #`DEL tx_latch[3];
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_DATA_3b; 
                                end
                        end
                    RS232_STATE_TX_DATA_3b:
                        begin
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_DATA_4a;
                        end

                    RS232_STATE_TX_DATA_4a:
                        begin
                            timer_tx_start      <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    txd             <= #`DEL tx_latch[4];
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_DATA_4b; 
                                end
                        end
                    RS232_STATE_TX_DATA_4b:
                        begin
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_DATA_5a;
                        end
                        
                        
                    RS232_STATE_TX_DATA_5a:
                        begin
                            timer_tx_start     <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    txd             <= #`DEL tx_latch[5];
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_DATA_5b; 
                                end
                        end
                    RS232_STATE_TX_DATA_5b: // 15h
                        begin
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_DATA_6a;
                        end

                    RS232_STATE_TX_DATA_6a:
                        begin
                            timer_tx_start     <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    txd             <= #`DEL tx_latch[6];
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_DATA_6b; 
                                end
                        end
                    RS232_STATE_TX_DATA_6b:
                        begin
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_DATA_7a;
                        end
                        
                    RS232_STATE_TX_DATA_7a:
                        begin
                            timer_tx_start      <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    txd             <= #`DEL tx_latch[7];
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_DATA_7b; 
                                end
                        end
                    RS232_STATE_TX_DATA_7b:
                        begin
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_STOPa;
                        end
                        
                    RS232_STATE_TX_STOPa: // send stop bit
                        begin
                            timer_tx_start      <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    txd             <= #`DEL 1;
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_STOPb; 
                                end
                        end
                    RS232_STATE_TX_STOPb:
                        begin
                            timer_tx_start      <= #`DEL 1;
                            rs232_state_tx      <= #`DEL RS232_STATE_TX_STOPc;
                        end
                    RS232_STATE_TX_STOPc:
                        begin
                            timer_tx_start      <= #`DEL 0;
                            if (timer_tx_done)
                                begin
                                    tx_ready        <= #`DEL 1; 
                                    rs232_state_tx  <= #`DEL RS232_STATE_TX_IDLE; 
                                end
                        end
                endcase
            end
    end

    
    
    
    // RECEIVER
    reg rxd_previous;
    reg timer_rx_extra_delay;
    
    reg timer_rx_start;
    rs232_timer timer_rx(
        .clk(clk),
        .reset_n(reset_n),
        .start(timer_rx_start),
        .done(timer_rx_done),
        .extra_delay(timer_rx_extra_delay)
    );

    
   	always @(posedge clk or negedge reset_n) begin : fsm_rx
        if (~reset_n) 
            begin
                rs232_state_rx  <= #`DEL RS232_STATE_RX_RESET;
                timer_rx_start  <= #`DEL 0;
                timer_rx_extra_delay  <= #`DEL 0;                
                rx_ready        <= #`DEL 0;
                rx_data         <= #`DEL `uart_data_width'b0;
                rts             <= #`DEL ~rts_asserted;
                rxd_previous    <= #`DEL 0;
            end
        else
            begin
                rxd_previous    <= #`DEL rxd_sync;            
                case (rs232_state_rx) // synthesis parallel_case
                    RS232_STATE_RX_RESET, RS232_STATE_RX_IDLE:
                        begin
                            rts             <= #`DEL rts_asserted;
                            rs232_state_rx  <= #`DEL RS232_STATE_RX_RTS;
                        end
                    
                    RS232_STATE_RX_RTS: // wait for start bit (H-L transition on rxd_sync)
                        begin
                            if ((rxd_previous == 1) && (rxd_sync == 0))
                                begin
//                                     timer_rx_extra_delay    <= #`DEL 1; 
//                                     // a half bit time extra is required until lsb is sampled
                                    
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_START;                                    
                                end
                        end
                        
                    RS232_STATE_RX_START:
                        begin
                            timer_rx_start          <= #`DEL 1;
                            timer_rx_extra_delay    <= #`DEL 1; 
                            // a half bit time extra is required until lsb is sampled
                            
                            rs232_state_rx          <= #`DEL RS232_STATE_RX_DATA_0a;
                        end
                        
                    RS232_STATE_RX_DATA_0a: // 4h // sample bit 0 after 1.5 timer delays
                        begin
                            timer_rx_start          <= #`DEL 0;
                            timer_rx_extra_delay    <= #`DEL 0;                            
                            if (timer_rx_done)
                                begin
                                    rx_data[0]              <= #`DEL rxd_sync;
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_DATA_0b;   
                                end
                        end
                    RS232_STATE_RX_DATA_0b: // 5h
                        begin
                            timer_rx_start     <= #`DEL 1;
                            rs232_state_rx     <= #`DEL RS232_STATE_RX_DATA_1a;
                        end

                    RS232_STATE_RX_DATA_1a: // sample bit 1 after 1.0 timer delay
                        begin
                            timer_rx_start     <= #`DEL 0;
                            if (timer_rx_done)
                                begin
                                    rx_data[1]              <= #`DEL rxd_sync;
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_DATA_1b;   
                                end
                        end
                    RS232_STATE_RX_DATA_1b:
                        begin
                            timer_rx_start     <= #`DEL 1;
                            rs232_state_rx     <= #`DEL RS232_STATE_RX_DATA_2a;
                        end

                    RS232_STATE_RX_DATA_2a: // sample bit 2 after 1.0 timer delay
                        begin
                            timer_rx_start     <= #`DEL 0;
                            if (timer_rx_done)
                                begin
                                    rx_data[2]              <= #`DEL rxd_sync;
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_DATA_2b;   
                                end
                        end
                    RS232_STATE_RX_DATA_2b:
                        begin
                            timer_rx_start     <= #`DEL 1;
                            rs232_state_rx     <= #`DEL RS232_STATE_RX_DATA_3a;
                        end
            
                    RS232_STATE_RX_DATA_3a: // sample bit 3 after 1.0 timer delay
                        begin
                            timer_rx_start     <= #`DEL 0;
                            if (timer_rx_done)
                                begin
                                    rx_data[3]              <= #`DEL rxd_sync;
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_DATA_3b;   
                                end
                        end
                    RS232_STATE_RX_DATA_3b:
                        begin
                            timer_rx_start     <= #`DEL 1;
                            rs232_state_rx     <= #`DEL RS232_STATE_RX_DATA_4a;
                        end

                    RS232_STATE_RX_DATA_4a: // sample bit 4 after 1.0 timer delay
                        begin
                            timer_rx_start     <= #`DEL 0;
                            if (timer_rx_done)
                                begin
                                    rx_data[4]              <= #`DEL rxd_sync;
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_DATA_4b;   
                                end
                        end
                    RS232_STATE_RX_DATA_4b:
                        begin
                            timer_rx_start     <= #`DEL 1;
                            rs232_state_rx     <= #`DEL RS232_STATE_RX_DATA_5a;
                        end
                        
                    RS232_STATE_RX_DATA_5a: // sample bit 5 after 1.0 timer delay
                        begin
                            timer_rx_start     <= #`DEL 0;
                            if (timer_rx_done)
                                begin
                                    rx_data[5]              <= #`DEL rxd_sync;
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_DATA_5b;   
                                end
                        end
                    RS232_STATE_RX_DATA_5b:
                        begin
                            timer_rx_start     <= #`DEL 1;
                            rs232_state_rx     <= #`DEL RS232_STATE_RX_DATA_6a;
                        end

                    RS232_STATE_RX_DATA_6a: // sample bit 6 after 1.0 timer delay
                        begin
                            timer_rx_start     <= #`DEL 0;
                            if (timer_rx_done)
                                begin
                                    rx_data[6]              <= #`DEL rxd_sync;
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_DATA_6b;   
                                end
                        end
                    RS232_STATE_RX_DATA_6b:
                        begin
                            timer_rx_start     <= #`DEL 1;
                            rs232_state_rx     <= #`DEL RS232_STATE_RX_DATA_7a;
                        end

                    RS232_STATE_RX_DATA_7a: // sample bit 7 after 1.0 timer delay
                        begin
                            timer_rx_start     <= #`DEL 0;
                            if (timer_rx_done)
                                begin
                                    rx_data[7]              <= #`DEL rxd_sync;
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_DATA_7b;   
                                end
                        end
                    RS232_STATE_RX_DATA_7b: // 19d
                        begin
                            timer_rx_start     <= #`DEL 1;
                            rs232_state_rx     <= #`DEL RS232_STATE_RX_STOPa;
                        end
                        
                    RS232_STATE_RX_STOPa: // 20d / 14h 
                    // - wait for stop bit (L-H transition on rxd_sync)
                    // - signal host, that data is available (rx_ready)
                        begin
                            timer_rx_start     <= #`DEL 0;
                            if (timer_rx_done)
                                begin
                                    //if ((~rxd_previous) && (rxd_sync))
                                    if (rxd_sync)
                                        begin
                                            rx_ready                <= #`DEL 1; 
                                            rs232_state_rx          <= #`DEL RS232_STATE_RX_STOPb;
                                        end
                                end
                            //else // stop bit not found -> handle error
                                
                        end
                        
                    RS232_STATE_RX_STOPb:
                    // wait until host acknowledges new data
                        begin
                            if (rx_ack)
                                begin
                                    rx_ready                <= #`DEL 0;
                                    rs232_state_rx          <= #`DEL RS232_STATE_RX_IDLE;
                                end                       
                        end
                endcase
                
            
            end
    end
    
endmodule

            
            
            
