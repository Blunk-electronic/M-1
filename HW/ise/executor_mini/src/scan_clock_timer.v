// - outputs high on output "done" after delay
// - if step mode "tck" is active, waits for go_step_tck signal AFTER delay
// - delay is fixed for simulation, otherwise taken from vector file

module scan_clock_timer (
    clk, // input
    reset_n, // input asynchronous
    reset, // input sychronous
    delay, // input
    start, // input
    done, // output
    step_mode_tck, // input
    go_step_tck, // input
    timer_scan_state // output
    );

`include "parameters_global.v"


    input       clk; // 50Mhz
    input       reset_n;
    input       reset;
    
    input       [`byte_width-1:0] delay; // high nibble is multiplier, low nibble is exponent
    input       start;
    output reg  done;
    
    input       step_mode_tck;
    input       go_step_tck;
    
    wire        [3:0] multiplier;
    assign      multiplier = delay[7:4];

    wire        [3:0] exponent;
    assign      exponent = delay[3:0];
    
`define counter_a_width 4
    reg         [`counter_a_width-1:0] counter_a; // holds up to 15 ticks

`define counter_b_width 26
    reg         [`counter_b_width-1:0] counter_b; // holds up to 67.108.863 ticks
    reg         [`counter_b_width-1:0] counter_b_init;    


    output reg  [`timer_scan_state_width-1:0] timer_scan_state;

    always @(posedge clk or negedge reset_n) begin
        if (~reset_n)
            begin
                counter_a           <= #`DEL `counter_a_width'b0;
                counter_b           <= #`DEL `counter_b_width'b0;
                counter_b_init      <= #`DEL `counter_b_width'b0;                
                done                <= #`DEL 0;
                timer_scan_state    <= #`DEL TIMER_SCAN_IDLE;
            end
        else
            begin
                if (reset)
                    begin
                        counter_a           <= #`DEL `counter_a_width'b0;
                        counter_b           <= #`DEL `counter_b_width'b0;
                        counter_b_init      <= #`DEL `counter_b_width'b0;                
                        done                <= #`DEL 0;
                        timer_scan_state    <= #`DEL TIMER_SCAN_IDLE;
                    end
                else
                    begin
                        case (timer_scan_state) // synthesis parallel_case
                            TIMER_SCAN_IDLE:
                                begin
                                    done    <= #`DEL 0; // clear done signal after timeout
                                    if (start) // if start signal given from lcp, compute init value for counter b (10^exponent)
                                                // the init value is required on reloading counter b
                                                // the exponent is limited to 10^7 ticks
                                        begin
                                            `ifdef tck_frequency_sim
                                                counter_a           <= #`DEL `counter_a_width'h2;
                                                counter_b_init      <= #`DEL `counter_b_width'd2;
                                            `else
                                                case (exponent) // synthesis parallel_case
                                                    4'h0    :   counter_b_init <= #`DEL `counter_b_width'd10**0;
                                                    4'h1    :   counter_b_init <= #`DEL `counter_b_width'd10**1 - 3;
                                                    4'h2    :   counter_b_init <= #`DEL `counter_b_width'd10**2;
                                                    4'h3    :   counter_b_init <= #`DEL `counter_b_width'd10**3;
                                                    4'h4    :   counter_b_init <= #`DEL `counter_b_width'd10**4;
                                                    4'h5    :   counter_b_init <= #`DEL `counter_b_width'd10**5;
                                                    4'h6    :   counter_b_init <= #`DEL `counter_b_width'd10**6;
                                                    4'h7    :   counter_b_init <= #`DEL `counter_b_width'd10**7;
                                                    default :   counter_b_init <= #`DEL `counter_b_width'd10**7;
                                                endcase         

                                                // multiplier must be corrected if exponent is zero
                                                case (exponent) // synthesis parallel_case
                                                    4'h0    :   counter_a      <= #`DEL multiplier - 2;
                                                    default :   counter_a      <= #`DEL multiplier;
                                                endcase         
                                                
                                                
                                            `endif
                                            
                                            timer_scan_state    <= #`DEL TIMER_SCAN_STATE_1; // proceed to next state
                                        end
                                end
                                
                            TIMER_SCAN_STATE_1: // 1h 
                                // - as long as counter_a (multiplier) is greater zero,
                                //   reload counter_b and proceed with next state.
                                // - on zero count of counter_a, signal lcp done and return to idle state
                                
                                // - if step mode tck active, go to TIMER_SCAN_WAIT and wait for step signal
                                // - otherwise signal executor that wait cycle is finished and go back to TIMER_SCAN_IDLE
                                
                                // - if exponent (counter_b_init) is zero, there is no need to decrement counter_b.
                                // - so state TIMER_SCAN_STATE_2 can be skipped.
                                begin
                                    if (counter_b_init > 1)
                                        begin
                                            if (counter_a > 0)
                                                begin
                                                    counter_b           <= #`DEL counter_b_init;
                                                    timer_scan_state    <= #`DEL TIMER_SCAN_STATE_2; //  2h
                                                end
                                            else // wait cycle done
                                            
                                                if (step_mode_tck)
                                                    begin
                                                        timer_scan_state    <= #`DEL TIMER_SCAN_WAIT; // 3h
                                                    end
                                                else
                                                    begin
                                                        done                <= #`DEL 1;
                                                        timer_scan_state    <= #`DEL TIMER_SCAN_IDLE; // 0h
                                                    end
                                        end
                                        
                                    else
                                        begin
                                            if (counter_a > 1) // in order to reduce overhead, no need to wait until zero count
                                                begin
                                                    counter_a           <= #`DEL counter_a - 1;
                                                end
                                            else // wait cycle done
                                            
                                                if (step_mode_tck)
                                                    begin
                                                        timer_scan_state    <= #`DEL TIMER_SCAN_WAIT; // 3h
                                                    end
                                                else
                                                    begin
                                                        done                <= #`DEL 1;
                                                        timer_scan_state    <= #`DEL TIMER_SCAN_IDLE; // 0h
                                                    end                                
                                        end
                                end
                                
                                
                            TIMER_SCAN_STATE_2: // 2h // as long as counter_b is greater zero decrement counter_b
                                // - on zero count of counter_b, decrement multiplier and return to TIMER_SCAN_STATE_1
                                // - this state is entered as many times as defined by counter_a (multiplier)
                                begin
                                    if (counter_b > 0)
                                        begin
                                            counter_b           <= #`DEL counter_b - 1;
                                        end
                                    else
                                        begin
                                            counter_a           <= #`DEL counter_a - 1;
                                            timer_scan_state    <= #`DEL TIMER_SCAN_STATE_1;
                                        end
                                end
                                
                            TIMER_SCAN_WAIT: // 3h
                                // wait for step signal, then signal executor "done" and return to idle state
                                begin
                                    if (go_step_tck)
                                        begin
                                            done                <= #`DEL 1;
                                            timer_scan_state    <= #`DEL TIMER_SCAN_IDLE;
                                        end
                                end

                            
                            
                        endcase
                    end
            end
    end
    
endmodule 
