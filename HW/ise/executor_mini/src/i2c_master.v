module i2c_master(
    clk,        // input
    reset_n,    // input asynchronous
    reset,      // input synchronous
    
    sda,        // inout
    scl,        // inout
    
    tx_byte,    // input, byte to send to slave, the payload
    rx_byte,    // output, byte received from slave, the payload
    
    tx_start_condition,     // input, high, when i2c master is to send a start signal
    tx_stop_condition,      // input, high, when i2c master is to send a stop signal
    tx_data,                // input, high, when i2c master is to send a byte as given in tx_byte
    rx_data,                // input, high, when i2c master is to receive a byte and output it in rx_byte    
    
    start,      // input, starts i2c master
    done,        // output, high when i2c master done
    
    i2c_master_state // output, read by rf
    );
    
    `include "parameters_global.v"        

	input clk;
	input reset_n;
	input reset;
	
	inout sda, scl;
    
	input [`byte_width-1:0] tx_byte;
	output reg [`byte_width-1:0] rx_byte;
	
	input tx_start_condition;
	input tx_stop_condition;
    input tx_data;
    input rx_data;
	
	input start;	
	output reg done;
	
    output reg [`byte_width-1:0] i2c_master_state;
    reg [`byte_width-1:0] i2c_master_state_last, i2c_wait_count;
    
    `define bit_pointer_width 4 // must count up to 9 bits during tx or rx
    reg [`bit_pointer_width-1:0] bit_pointer;
    parameter bit_pointer_init = `bit_pointer_width'h7;
    
    `define sda_sample_width 3
    reg [`sda_sample_width-1:0] sda_sample; // holds 3 samples of sda / before rising scl, after rising scl, after setting scl
    parameter all_sda_samples_zero = `sda_sample_width'b000;
		
    parameter i2c_driver_off        = 1'b1;
    parameter i2c_driver_on         = 1'b0; 
		
    reg driver_scl;
    reg driver_sda;
    assign scl = driver_scl ? 1'bz  : 1'b0;
    assign sda = driver_sda ? 1'bz  : 1'b0;    
		
    always @(posedge clk or negedge reset_n) begin
        if (~reset_n)
            begin
                done                <= #`DEL 1'b0;
                i2c_master_state    <= #`DEL I2C_MASTER_STATE_IDLE;
                i2c_wait_count      <= #`DEL i2c_wait_count_init;
                driver_scl          <= #`DEL i2c_driver_off;
                driver_sda          <= #`DEL i2c_driver_off;
                bit_pointer         <= #`DEL bit_pointer_init;
                sda_sample          <= #`DEL `sda_sample_width'b000;
            end
        else
            begin
                if (reset)
                    begin
                        done                <= #`DEL 1'b0;
                        i2c_master_state    <= #`DEL I2C_MASTER_STATE_IDLE;
                        i2c_wait_count      <= #`DEL i2c_wait_count_init;
                        driver_scl          <= #`DEL i2c_driver_off;
                        driver_sda          <= #`DEL i2c_driver_off;
                        bit_pointer         <= #`DEL bit_pointer_init;
                        sda_sample          <= #`DEL `sda_sample_width'b000;                    
                    end
                else
                    begin
                        case (i2c_master_state) // synthesis parallel_case
                        // RESET / IDLE
                            I2C_MASTER_STATE_IDLE:
                                begin
                                    //i2c_wait_count      <= #`DEL i2c_wait_count_init;
                                    done                <= #`DEL 1'b0;
                                    if (start) 
                                        begin
                                            if (tx_stop_condition)
                                                begin
                                                    i2c_master_state    <= #`DEL I2C_MASTER_STATE_STOP_1; // 2h
                                                end
                                            else if (tx_start_condition)
                                                begin
                                                    i2c_master_state    <= #`DEL I2C_MASTER_STATE_START_1; // 4h
                                                end
                                            else if (tx_data)
                                                begin
                                                    i2c_master_state    <= #`DEL I2C_MASTER_STATE_TX_1; // 6h
                                                end
        //                                     else if (rx_data)
        //                                         begin
        //                                             i2c_master_state    <= #`DEL I2C_MASTER_STATE_RX_1;
        //                                         end
                                        
                                        end
                                end
                                
                        // WAIT STATES
                            I2C_MASTER_STATE_WAIT: // 1h
                                begin
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state    <= #`DEL i2c_master_state_last;
                                        end
                                    else
                                        begin
                                            i2c_wait_count      <= #`DEL i2c_wait_count - 1;
                                        end                        
                                end
                                
                                
        // NOTE: FOR THE FOLLOWING STATES THIS RULE APPLIES: ACT,WAIT -> NEXT STATE -> ACT,WAIT -> NEXT STATE ...                        
                                
                        // SEND STOP CONDITION
                            I2C_MASTER_STATE_STOP_1: // 2h
                                begin
                                    driver_scl      <= #`DEL i2c_driver_off;

                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_STOP_2; // 03h
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;                                    
                                        end
                                    else
                                        begin
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                        end
                                end                        
                                
                            I2C_MASTER_STATE_STOP_2: // 03h
                                begin
                                    driver_sda      <= #`DEL i2c_driver_off;
                                    
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_IDLE;
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                            done                    <= #`DEL 1'b1;
                                        end
                                    else
                                        begin
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT;
                                        end                            
                                end

                        // SEND START CONDITION
                            I2C_MASTER_STATE_START_1: // 4h
                                begin
                                    driver_sda      <= #`DEL i2c_driver_on;

                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_START_2; // 5h
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;                                    
                                        end
                                    else
                                        begin
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                        end
                                end                        
                                
                            I2C_MASTER_STATE_START_2: // 5h
                                begin
                                    driver_scl      <= #`DEL i2c_driver_on;
                                    
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_IDLE; // 00h
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                            done                    <= #`DEL 1'b1;                                    
                                        end
                                    else
                                        begin
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                        end                            
                                end

                        // DATA TX
                            I2C_MASTER_STATE_TX_1: // 6h
                                begin
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_TX_2;
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                        end
                                    else
                                        begin
                                            driver_sda              <= #`DEL tx_byte[bit_pointer];
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                        end                            
                                end

                            I2C_MASTER_STATE_TX_2:
                                begin
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_TX_3;
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                        end
                                    else
                                        begin
                                            driver_scl              <= #`DEL i2c_driver_off;                                
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                        end                            
                                end

                            I2C_MASTER_STATE_TX_3:
                                begin
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_TX_4;
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                        end
                                    else
                                        begin
                                            driver_scl              <= #`DEL i2c_driver_on;
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                        end                            
                                end
                                
                            I2C_MASTER_STATE_TX_4: // 09h 
                                begin
                                    if (bit_pointer == 0) // if last bit processed (LSB)
                                        begin
                                            driver_sda              <= #`DEL i2c_driver_off; // release sda
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_TX_5;
                                        end
                                    else
                                        begin // if not last bit processed, advance bit pointer one bit towards LSB (right)
                                            bit_pointer             <= #`DEL bit_pointer - 1;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_TX_1; // start sending next bit
                                        end
                                end
                                            
                            I2C_MASTER_STATE_TX_5: // 0Ah // wait until sda is stable , slave should be sending acknowledge (zero) already
                                begin
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_TX_6;
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                            sda_sample[0]           <= #`DEL sda; // take sample #1 from sda
                                        end
                                    else
                                        begin
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                        end                            
                                end
                                            
                            I2C_MASTER_STATE_TX_6: // 0Bh // register acknowledge from slave // acknowledge clock cycle begin
                                // sample sda while scl posedge 
                                begin
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_TX_7;
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                        end
                                    else
                                        begin
                                            driver_scl              <= #`DEL i2c_driver_off; // scl L-H edge
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                            sda_sample[1]           <= #`DEL sda; // take sample #2 from sda                                    
                                        end                            
                                end

                            I2C_MASTER_STATE_TX_7: // 0Ch // register acknowledge from slave // acknowledge clock cycle end
                                // sample sda while scl negedge
                                begin
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_TX_8;
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                        end
                                    else
                                        begin
                                            driver_scl              <= #`DEL i2c_driver_on; // scl H-L edge
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                            sda_sample[2]           <= #`DEL sda; // take sample #2 from sda                                    
                                        end                            
                                end

                            I2C_MASTER_STATE_TX_8: // 0Dh // evaluate acknowledge bit received from slave
                                begin
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_TX_9; // 0Eh
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                            bit_pointer             <= #`DEL bit_pointer_init;
                                            //done                    <= #`DEL 1'b1;
                                        end
                                    else 
                                        begin // all sda samples must be zero, otherwise no acknowledge received -> error
                                            if (sda_sample == all_sda_samples_zero)
                                                begin
                                                    i2c_master_state_last   <= #`DEL i2c_master_state;
                                                    i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                                end
                                            else
                                                begin
                                                    i2c_master_state        <= #`DEL I2C_MASTER_STATE_ERROR;
                                                end
                                        end
                                end
                                
                            I2C_MASTER_STATE_TX_9: // 0Eh // finish write cycle by driving sda low
                                begin
                                    if (i2c_wait_count == 0)
                                        begin
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_IDLE;
                                            i2c_wait_count          <= #`DEL i2c_wait_count_init;
                                            //bit_pointer             <= #`DEL bit_pointer_init;
                                            done                    <= #`DEL 1'b1;
                                        end
                                    else 
                                        begin // drive sda low
                                            driver_sda              <= #`DEL i2c_driver_on; // sda L
                                            i2c_master_state_last   <= #`DEL i2c_master_state;
                                            i2c_master_state        <= #`DEL I2C_MASTER_STATE_WAIT; // 01h
                                        end
                                end
                                                
                        endcase
                    end
            end
    end
    
		
endmodule
