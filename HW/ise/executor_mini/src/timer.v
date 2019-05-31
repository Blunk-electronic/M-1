module timer(
    // outputs high on output "done" after delay*0.1s
    
    
    // inputs
    clk, 
    reset_n, // asynchronous
    delay, start,
    reset, // synchronous

    // outputs
    done, 
    timer_state
    );

    `include "parameters_global.v"

    input clk;
    input reset_n;
    input reset;    
    input start;
    input [`byte_width-1:0] delay; // multiply by 0.1s = timeout
    output reg done;
    
    reg [`byte_width-1:0] time_unit_count; // incremented every 0.1s
    
    output reg [`timer_state_width-1:0] timer_state; // the state machine itself requires 3 states only

    reg [`timer_counter_width-1:0] counter; // incremented every 20ns @ 50Mhz master clock
    
    always @(posedge clk or negedge reset_n) begin
        if (~reset_n)
            begin
                timer_state     <= #`DEL TIMER_STATE_IDLE;
                counter         <= #`DEL `timer_counter_width'h0;
                time_unit_count <= #`DEL `byte_width'h0;
                done            <= #`DEL 0;
            end
        else
            begin
                if (reset)
                    begin
                        timer_state     <= #`DEL TIMER_STATE_IDLE;
                        counter         <= #`DEL `timer_counter_width'h0;
                        time_unit_count <= #`DEL `byte_width'h0;
                        done            <= #`DEL 0;
                    end
                else
                    begin
                        case (timer_state) // synthesis parallel_case
                            TIMER_STATE_IDLE: // 0h
                                begin
                                    done    <= #`DEL 0;
                                    if (start) // sample start signal. when high -> start timer
                                        begin
                                            timer_state <= #`DEL TIMER_STATE_1;
                                        end
                                end
                                
                            TIMER_STATE_1: // 1h
                                // increment counter until timer_ticks_for_0_1_sec_timeout reached, then increment time_unit_count
                                // and proceed with next state
                                begin
                                    if (counter == timer_ticks_for_0_1_sec_timeout)
                                        begin
                                            counter         <= #`DEL 0;
                                            time_unit_count <= #`DEL time_unit_count + 1;
                                            timer_state     <= #`DEL TIMER_STATE_2;
                                        end
                                    else
                                        begin
                                            counter         <= #`DEL counter + 1;
                                        end            
                                end
                                
                            TIMER_STATE_2: // 2h
                                // if time_unit_count as defined by "delay" reached, raise done signal to notify lcp that timer has reached timeout (done)
                                // as long as no timeout reached, go back to TIMER_STATE_1 to count another 0.1s
                                begin
                                    if (time_unit_count == delay)
                                        begin
                                            done            <= #`DEL 1'b1; // signal lcp done
                                            time_unit_count <= #`DEL `byte_width'h0; // reset for next time the timer is started
                                            timer_state     <= #`DEL TIMER_STATE_IDLE;
                                        end
                                    else
                                        begin
                                            timer_state     <= #`DEL TIMER_STATE_1; // 1h 
                                        end
                                
                                end
                                
                        endcase
                    end
            
            end
    
    end
    
endmodule
