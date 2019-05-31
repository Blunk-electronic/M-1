module shifter(
    clk, // input
    reset_n, // input
    enable, // input, used to enable the shifter. if low, no start or restart possible
    start, // input, asserted by executor when new triplet available
    halt, // input, goes high on test fail. causes the shifter to halt while keeping all its registers unchanged
    restart, // input, used to restart shifter on restarting a test
    step_mode_tck, // input // high when step mode "tck" active
    go_step_tck, // input // high-pulse causes the scan clock timer to resume (if halted in step mode)
    
    data_req, // output
    sxr_done, // output
    busy, // output
    pause_request, // input
    
    drive,  // input
    mask,   // input
    expect, // input
    
    sxr_type, // input
    sxr_length, // input
    bits_processed, // output
    
    //fail,   // output
    
    sp_tms, // output
    sp_tck, // output
    sp_tdo, // output    
    //sp_tdi, // input
    sp_exp, // output
    sp_msk, // output
    
    scan_clock_frequency, // input
    
    tap_state_feedback, // input // holds tap state read from tap state monitor (in executor module)
                        // IMPORTANT: THIS IS THE REALTIME TAP STATE OF THE TARGET !
    tap_state_send, // output // sends tap state to tap state monitor (in executor module)
    shifter_state, // output, read by rf
    scan_clock_timer_state // output
    );
    
    `include "parameters_global.v"  
    
    input clk;
    input reset_n;
    input enable;
    input start;
    input halt;
    input restart;
    
    input step_mode_tck; 
    input go_step_tck;  
    
    output reg data_req;
    output reg sxr_done; 
    output reg busy;
    input pause_request;
    
    input [`byte_width-1:0] drive;
    input [`byte_width-1:0] mask;
    input [`byte_width-1:0] expect;    
    
    input [`byte_width-1:0] sxr_type;
    `include "include_sxr_type.v" // wire to bit assignments     
    
    input [`chain_length_width-1:0] sxr_length;
    output reg [`chain_length_width-1:0] bits_processed;    
    
    input [`byte_width-1:0] scan_clock_frequency; // driven by lcp

    output reg sp_tms;
    output reg sp_tck;
    output reg sp_tdo;
    output reg sp_exp;    
    output reg sp_msk;        
    //input sp_tdi;
    
    input [`nibble_width-1:0] tap_state_feedback;
    output reg [`nibble_width-1:0] tap_state_send;
    output reg [`byte_width-1:0] shifter_state;
    output [`timer_scan_state_width-1:0] scan_clock_timer_state;
    
    reg ignore_sxr_type;
    
    reg sct_start;
    scan_clock_timer sct ( // CS: restart input ?
        .clk(clk), // input
        .reset_n(reset_n), // input
        .delay(scan_clock_frequency), // input
        .start(sct_start), // input
        .done(sct_done), // output
        .step_mode_tck(step_mode_tck), // input
        .go_step_tck(go_step_tck), // input, ignored when step_mode_tck is cleared
        .timer_scan_state(scan_clock_timer_state) // output
        );
        
     
    always @(posedge clk or negedge reset_n) begin
        if (~reset_n)
            begin
                data_req                <= #`DEL 1'b0;
                sxr_done                <= #`DEL 1'b0;                
                busy                    <= #`DEL 1'b0;
                sct_start               <= #`DEL 1'b0;
                sp_tms                  <= #`DEL init_state_tms;
                sp_tck                  <= #`DEL init_state_tck;
                sp_tdo                  <= #`DEL init_state_tdo;
                sp_exp                  <= #`DEL init_state_exp;
                sp_msk                  <= #`DEL init_state_mask;                
                bits_processed          <= #`DEL `chain_length_width'b0;
                shifter_state           <= #`DEL SHIFTER_STATE_IDLE;
                tap_state_send          <= #`DEL TAP_TEST_LOGIG_RESET;
                ignore_sxr_type         <= #`DEL 0;
            end
        else
            begin
                //if (enable && restart)
                if (restart)
                    begin
                        data_req                <= #`DEL 1'b0;
                        sxr_done                <= #`DEL 1'b0;                
                        busy                    <= #`DEL 1'b0;
                        sct_start               <= #`DEL 1'b0;
                        sp_tms                  <= #`DEL init_state_tms;
                        sp_tck                  <= #`DEL init_state_tck;
                        sp_tdo                  <= #`DEL init_state_tdo;
                        sp_exp                  <= #`DEL init_state_exp;
                        sp_msk                  <= #`DEL init_state_mask;                
                        bits_processed          <= #`DEL `chain_length_width'b0;
                        shifter_state           <= #`DEL SHIFTER_STATE_IDLE;
                        tap_state_send          <= #`DEL TAP_TEST_LOGIG_RESET;
                        ignore_sxr_type         <= #`DEL 0;
                    end
                else
                    begin
                        if (halt)
                            begin
                                shifter_state <= #`DEL SHIFTER_STATE_IDLE;
                            end
                        else
                            begin
                            
                                case (shifter_state) // synthesis parallel_case
                        
                                    SHIFTER_STATE_IDLE: //0h
                                        begin
                                            data_req    <= #`DEL 1'b0;
                                            sxr_done    <= #`DEL 1'b0; // clear sxr done (has been set one state before)
                                            if (enable && start) // starting is allowed if enabled
                                                begin
                                                    shifter_state <= #`DEL SHIFTER_STATE_EVAL_TAP_STATE;
                                                end
                                        end

                                    SHIFTER_STATE_EVAL_TAP_STATE: // 01h
                                        begin
                                            case (tap_state_feedback) // synthesis parallel_case
                                                TAP_TEST_LOGIG_RESET:
                                                    begin
                                                        if (bits_processed == 0)
                                                            begin
                                                                sct_start       <= #`DEL 1; // start scan clock timer
                                                                shifter_state   <= #`DEL SHIFTER_STATE_TLR_TO_SELDR_1; // 02h // next rti
                                                            end
                                                        else
                                                            begin
                                                                shifter_state   <= #`DEL SHIFTER_STATE_ERROR_0;
                                                            end
                                                    end
                                                
                                                TAP_RUN_TEST_IDLE:
                                                    begin
                                                        if (bits_processed == 0)
                                                            begin
                                                                sct_start       <= #`DEL 1; // start scan clock timer
                                                                shifter_state   <= #`DEL SHIFTER_STATE_TLR_TO_SELDR_3; // 04h // next sel-dr
                                                            end
                                                        else
                                                            begin
                                                                shifter_state   <= #`DEL SHIFTER_STATE_ERROR_1;
                                                            end
                                                    end

                                                    
                                                // DR SCAN BRANCH
                                                
                                                TAP_SHIFT_DR:
                                                    begin // in this case a triplet has been provided by executor
                                                        if (bits_processed < sxr_length)
                                                            begin
                                                                sct_start       <= #`DEL 1; // start scan clock timer
                                                                shifter_state   <= #`DEL SHIFTER_STATE_SHIFTDR_1; // 0Ah // next shift-dr
                                                            end
                                                        else
                                                            begin
                                                                shifter_state   <= #`DEL SHIFTER_STATE_ERROR_2;
                                                            end
                                                    end
                                                
                                                TAP_PAUSE_DR:
                                                    begin   // A start signal here is accepted if no bits have been processed yet.
                                                            // In other words: If a new sxr starts.                                                            
                                                        if (bits_processed == 0)
                                                            begin
                                                                sct_start       <= #`DEL 1; // start scan clock timer
                                                                shifter_state   <= #`DEL SHIFTER_STATE_EXIT2DR_1; // 12h

                                                                if (~sxr_type_sir && ~sxr_type_end_state_rti) // sdr AND end state pause-dr requested
                                                                    begin
                                                                        ignore_sxr_type <= #`DEL 0;
                                                                    end
                                                                else
                                                                    begin
                                                                        ignore_sxr_type <= #`DEL 1;
                                                                    end
                                                            end
                                                        else
                                                            begin
                                                                shifter_state   <= #`DEL SHIFTER_STATE_ERROR_3; // F3h
                                                            end
                                                            
                                                    end
                                                
                                                
                                                // IR SCAN BRANCH
                                                
                                                TAP_SHIFT_IR:
                                                    begin // in this case a triplet has been provided by executor
                                                        if (bits_processed < sxr_length)
                                                            begin
                                                                sct_start       <= #`DEL 1; // start scan clock timer
                                                                shifter_state   <= #`DEL SHIFTER_STATE_SHIFTIR_1; // 1Dh // next shift-ir
                                                            end
                                                        else
                                                            begin
                                                                shifter_state   <= #`DEL SHIFTER_STATE_ERROR_7; // F7
                                                            end
                                                    end
                                                
                                                TAP_PAUSE_IR:
                                                    begin   // A start signal here is accepted if no bits have been processed yet.
                                                            // In other words: If a new sxr starts.
                                                        if (bits_processed == 0)
                                                            begin
                                                                sct_start       <= #`DEL 1; // start scan clock timer
                                                                shifter_state   <= #`DEL SHIFTER_STATE_EXIT2IR_1; // 25h

                                                                if (sxr_type_sir && ~sxr_type_end_state_rti) // sir AND end state pause-ir requested
                                                                    begin
                                                                        ignore_sxr_type <= #`DEL 0;
                                                                    end
                                                                else
                                                                    begin
                                                                        ignore_sxr_type <= #`DEL 1;
                                                                    end                                                             
                                                            end
                                                        else
                                                            begin
                                                                shifter_state   <= #`DEL SHIFTER_STATE_ERROR_6; // F6h
                                                            end
                                                            
                                                    end
                                                
                                                default: // a start command received in other states is invalid:
                                                    begin
                                                        shifter_state   <= #`DEL SHIFTER_STATE_ERROR_8; // F8h
                                                    end
                                                
                                            endcase
                                        end
                                        
                                    ////////////////////////////////////////////////////////////////////////////////////////
                                                
                                    // SXR SCAN INITIAL PHASE                        
                                    
                                    SHIFTER_STATE_TLR_TO_SELDR_1: // 02h
                                        begin // clear tms to prepare transition to rti
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tms          <= #`DEL 0;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_TLR_TO_SELDR_2;
                                                end
                                        end

                                    SHIFTER_STATE_TLR_TO_SELDR_2: // 03h
                                        begin // set tck to latch tms -> target assumes tap state rti
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_RUN_TEST_IDLE;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_TLR_TO_SELDR_3; // 04h
                                                end
                                        end
                                        
                                    SHIFTER_STATE_TLR_TO_SELDR_3: // 04h
                                        begin // clear tck, set tms to prepare transition to select-dr-scan
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tms          <= #`DEL 1;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_TLR_TO_SELDR_4;
                                                end
                                        end

                                    SHIFTER_STATE_TLR_TO_SELDR_4: // 05h
                                        begin // set tck to latch tms -> target assumes tap state select-dr-scan
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_SELECT_DR_SCAN;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_EVAL_SXR_TYPE;
                                                end
                                        end

                                    SHIFTER_STATE_EVAL_SXR_TYPE: // 06h
                                        begin // clear tck, clear/set tms according to sxr type to prepare transition to capture-dr or select-ir-scan
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    
                                                    if (~sxr_type_sir) 
                                                    // if any kind of dr-scan, clear tms to prepare transition to capture-dr
                                                        begin
                                                            sp_tms          <= #`DEL 0;
                                                            shifter_state   <= #`DEL SHIFTER_STATE_SELDR_TO_SHIFTDR_1; // 07h
                                                        end
                                                    else
                                                    // if any kind of ir-scan, set tms to prepare transition to select-ir-scan
                                                        begin
                                                            sp_tms          <= #`DEL 1;
                                                            shifter_state   <= #`DEL SHIFTER_STATE_SELDR_TO_SELIR; // 18h
                                                        end
                                                        
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                end
                                        end
                                
                                ///////////////////////////////////////////////////////////////////////////////////////////////

                                // DR SCAN BRANCH OF TAP CONTROLLER
                                                
                                    SHIFTER_STATE_SELDR_TO_SHIFTDR_1: // 07h
                                        begin // set tck to latch tms -> target assumes tap state capture-dr
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_CAPTURE_DR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SELDR_TO_SHIFTDR_2;
                                                end
                                        end
                                    
                                    SHIFTER_STATE_SELDR_TO_SHIFTDR_2: // 08h
                                        begin // clear tck, clear tms to prepare transition to shift-dr-scan
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tms          <= #`DEL 0;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SELDR_TO_SHIFTDR_3;
                                                end
                                        end

                                    SHIFTER_STATE_SELDR_TO_SHIFTDR_3: // 09h                 
                                        begin // set tck to latch tms -> target assumes tap state shift-dr
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_SHIFT_DR;
                                                    busy            <= #`DEL 1'b1; // notify other shifters to wait in pause-dr
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SHIFTDR_1;
                                                end
                                        end

                                    SHIFTER_STATE_SHIFTDR_1: // 0Ah
                                        begin   // clear tck -> target outputs (first) scan data bit (selected by bits 2:0 of bits_processed).
                                                // if bits_processed < sxr_length-1 -> clear tms to prepare transition to shift-dr (means stay in shift-dr)
                                                // otherwise set tms to prepare transition to exit-1-dr (means leave shift-dr)
                                                
                                                // in shift-xr state these rules apply:
                                                // 1) tck falling edge -> tdo updates to bit 0,1,2,...
                                                // 2) tck rising edge  -> tdi samples    bit 0,1,2,...
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tdo          <= #`DEL drive[bits_processed[2:0]];
                                                    sp_exp          <= #`DEL expect[bits_processed[2:0]];
                                                    sp_msk          <= #`DEL mask[bits_processed[2:0]];                                    
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    
                                                    // for all bits_processed except second-to-last and last:
                                                    if (bits_processed < sxr_length - 1) 
                                                        begin
                                                            sp_tms          <= #`DEL 0;
                                                            shifter_state   <= #`DEL SHIFTER_STATE_SHIFTDR_2; // 0Bh // sample bit, stay in shift-dr
                                                        end
                                                    else
                                                    if (bits_processed == sxr_length - 1) // if second-to-last bit beeing processed
                                                        begin
                                                            sp_tms          <= #`DEL 1;
                                                            shifter_state   <= #`DEL SHIFTER_STATE_SHIFTDR_4; // sample last bit, prepare transition to exit-1-dr
                                                        end
                                                    else
                                                        begin
                                                            shifter_state   <= #`DEL SHIFTER_STATE_ERROR_11; // FBh
                                                        end
                                                end
                                        end
                                        
                                    SHIFTER_STATE_SHIFTDR_2:  // 0Bh
                                        begin   // set tck to latch tms -> target remains in tap state shift-dr / target samples tdi / bit processed
                                                // on rising tck edge, increment bits_processed
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_SHIFT_DR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    bits_processed  <= #`DEL bits_processed + 1;
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SHIFTDR_3; // evaluate bits_processed
                                                end
                                        end
                                        
                                    SHIFTER_STATE_SHIFTDR_3:  // 0Ch
                                        begin   // if 8 bits have been processed, go to idle state and wait for next start signal
                                                // target remains in shift-dr while next triplet is being provided
                                                // otherwise proceed with next bit
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            
                                            if (bits_processed[2:0] == 0) // || bits_processed[3:0] == 0) 
                                                // the lowest nibble of bits_processed is 8 after 8 processed bits
                                                // they overflow to zero after another 8 bits                                
                                                
                                                begin
                                                    //tap_state_send  <= #`DEL TAP_SHIFT_DR;
                                                    data_req        <= #`DEL 1'b1; // notify executor that triplet has been processed
                                                    shifter_state   <= #`DEL SHIFTER_STATE_IDLE;
                                                end
                                            else
                                                begin
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SHIFTDR_1; // 0Ah
                                                end
                                        end

                                    SHIFTER_STATE_SHIFTDR_4:  // 0Dh 
                                        begin // set tck to latch tms -> target assumes tap state exit-1-dr / target samples tdi one last time / last bit processed
                                                // on rising tck edge, increment bits_processed
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_EXIT1_DR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    bits_processed  <= #`DEL bits_processed + 1;
                                                    shifter_state   <= #`DEL SHIFTER_STATE_EXIT1DR_1; // 0Eh
                                                end
                                        end
                                        
                                    SHIFTER_STATE_EXIT1DR_1: // 0Eh
                                        begin // clear tck, clear tms to prepare transition to pause-dr
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tms          <= #`DEL 0;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_PAUSEDR_1;
                                                end
                                        end
                                        
                                    SHIFTER_STATE_PAUSEDR_1:  // 0Fh 
                                        begin // set tck to latch tms -> target assumes tap state pause-dr
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_PAUSE_DR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_PAUSEDR_2;
                                                end
                                        end

                                    // NOTE: in pause-dr: tck halts (no toggeling)
                                    // tck continues once all shifters have cleared their busy output 
                                    // (all busy signals are ORed in executor to signal pause_request)
                                    // this ensures a synchronized proceeding of all shifters
                                        
                                        
                                    SHIFTER_STATE_PAUSEDR_2: // 10h                      
                                        begin   // clear busy signal so that other waiting shfiters can proceed
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    busy            <= #`DEL 1'b0; // notify other shifters that shifting is complete
                                                    shifter_state   <= #`DEL SHIFTER_STATE_PAUSEDR_3; // 11h
                                                end
                                        end
                                        
                                    SHIFTER_STATE_PAUSEDR_3: // 11h
                                        begin // if no more pause requests, proceed to exit2-dr (if endstate rti) or idle (if endstate pause-dr)
                                            if (pause_request == 0)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tms          <= #`DEL 1;
                                                    
                                                    if (sxr_type_end_state_rti)
                                                    // if endstate is rti, proceed to exit2-dr
                                                        begin
                                                            sct_start       <= #`DEL 1; // start scan clock timer
                                                            shifter_state   <= #`DEL SHIFTER_STATE_EXIT2DR_1; // 12h
                                                        end
                                                    else
                                                    // if endstate is pause-dr, proceed to idle and wait for start signal
                                                        begin
                                                            sxr_done        <= #`DEL 1'b1;  // notify executor, that sxr is done
                                                            bits_processed  <= #`DEL 0; // clear bit counter
                                                            shifter_state   <= #`DEL SHIFTER_STATE_IDLE; // 00h
                                                        end
                                                end
                                        end
                                        
                                    SHIFTER_STATE_EXIT2DR_1:  // 12h 
                                        begin // set tck to latch tms -> target assumes tap state exit2-dr
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_EXIT2_DR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_EXIT2DR_2;
                                                end
                                        end
                                        
                                    SHIFTER_STATE_EXIT2DR_2: // 13h
                                        begin   // clear tck.
                                                // set tms to prepare transition to update-dr
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    sp_tms          <= #`DEL 1;
                                                    shifter_state   <= #`DEL SHIFTER_STATE_UPDATEDR_1;
                                                end
                                        end
                                        
                                    SHIFTER_STATE_UPDATEDR_1:  // 14h 
                                        begin // set tck to latch tms -> target assumes tap state update-dr
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_UPDATE_DR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_UPDATEDR_2; // 15h
                                                end
                                        end

                                    SHIFTER_STATE_UPDATEDR_2: // 15h
                                        begin   // clear tck.
                                                // according to required end state, clear/set tms to prepare transition to rti or select-dr-scan
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    
                                                    if (ignore_sxr_type)
                                                        begin
                                                            sp_tms          <= #`DEL 1;
                                                            shifter_state   <= #`DEL SHIFTER_STATE_TLR_TO_SELDR_4; // 05h // next: select-dr-scan
                                                        end
                                                    else
                                                        begin                                                            
                                                            if (sxr_type_end_state_rti)
                                                            // if end state (of ending sxr) is run-test/idle, clear tms to prepare transition to run-test/idle
                                                                begin
                                                                    sp_tms          <= #`DEL 0;
                                                                    shifter_state   <= #`DEL SHIFTER_STATE_RTI_1; // 16h // next: rti
                                                                end
                                                            else
                                                            // if end state (of begining sxr) is pause-dr, set tms to prepare transition to select-dr-scan
                                                                begin
                                                                    sp_tms          <= #`DEL 1;
                                                                    shifter_state   <= #`DEL SHIFTER_STATE_TLR_TO_SELDR_4; // 05h // next: select-dr-scan
                                                                end
                                                        end
                                                        
                                                    ignore_sxr_type <= #`DEL 0; 
                                                end
                                        end

                                /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                
                                // RETURN FROM UPDATE-XR TO RTI OR SELECT-DR-SCAN
                                
                                    SHIFTER_STATE_RTI_1: // 16h
                                        begin // set tck to latch tms -> target assumes tap state rti (coming from update-dr)
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_RUN_TEST_IDLE;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_RTI_2; // 17h
                                                end
                                        end
                                        
                                    SHIFTER_STATE_RTI_2: // 17h   
                                        begin   // clear tck.
                                                // whatever endstate is required, go to SHIFTER_STATE_IDLE and wait for start signal
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tms          <= #`DEL 1;
                                                    bits_processed  <= #`DEL 0; // clear bit counter                                    
                                                    sxr_done        <= #`DEL 1'b1; // notify executor, that sxr is done
                                                    shifter_state   <= #`DEL SHIFTER_STATE_IDLE;                                            
                                                end
                                        end
                                        
                                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                        
                                // IR SCAN BRANCH OF TAP CONTROLLER
                                    SHIFTER_STATE_SELDR_TO_SELIR: // 18h                        
                                        begin // set tck to latch tms -> target assumes tap state select-ir-scan
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_SELECT_IR_SCAN;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SELIR_TO_SHIFTIR_1; // 19h
                                                end
                                        end

                                    SHIFTER_STATE_SELIR_TO_SHIFTIR_1: // 19h
                                        begin // clear tck, clear/set tms according to sxr type to prepare transition to capture-ir (or test-logic-reset ?)
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    
                                                    if (sxr_type_sir)
                                                    // if any kind of ir-scan, set tms to prepare transition to capture-ir
                                                        begin
                                                            sp_tms          <= #`DEL 0;
                                                            shifter_state   <= #`DEL SHIFTER_STATE_SELIR_TO_SHIFTIR_2; // 1Ah
                                                        end
                                                    else
                                                    // other sxr types drive the executor in error state // CS: move to tlr instead ?
                                                        begin
                                                            shifter_state   <= #`DEL SHIFTER_STATE_ERROR_4; // F4h
                                                        end

                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                end
                                        end
                                        
                                    SHIFTER_STATE_SELIR_TO_SHIFTIR_2: // 1Ah
                                        begin // set tck to latch tms -> target assumes tap state capture-ir
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_CAPTURE_IR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SELIR_TO_SHIFTIR_3; // 1Bh
                                                end
                                        end
                                    
                                    SHIFTER_STATE_SELIR_TO_SHIFTIR_3: // 1Bh
                                        begin // clear tck, clear tms to prepare transition to shift-ir-scan
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tms          <= #`DEL 0;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SELIR_TO_SHIFTIR_4; // 1Ch
                                                end
                                        end

                                    SHIFTER_STATE_SELIR_TO_SHIFTIR_4: // 1Ch                 
                                        begin // set tck to latch tms -> target assumes tap state shift-ir
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_SHIFT_IR;
                                                    busy            <= #`DEL 1'b1; // notify other shifters to wait in pause-ir
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SHIFTIR_1; // 1Dh
                                                end
                                        end

                                    SHIFTER_STATE_SHIFTIR_1: // 1Dh
                                        begin   // clear tck -> target outputs (first) scan data bit (selected by bits 2:0 of bits_processed).
                                                // if bits_processed < sxr_length-1 -> clear tms to prepare transition to shift-ir (means stay in shift-ir)
                                                // otherwise set tms to prepare transition to exit-1-ir (means leave shift-ir)
                                                
                                                // in shift-xr state these rules apply:
                                                // 1) tck falling edge -> tdo updates to bit 0,1,2,...
                                                // 2) tck rising edge  -> tdi samples    bit 0,1,2,...
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tdo          <= #`DEL drive[bits_processed[2:0]];
                                                    sp_exp          <= #`DEL expect[bits_processed[2:0]];
                                                    sp_msk          <= #`DEL mask[bits_processed[2:0]];                                           
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    
                                                    // for all bits_processed except second-to-last and last:
                                                    if (bits_processed < sxr_length - 1) 
                                                        begin
                                                            sp_tms          <= #`DEL 0;
                                                            shifter_state   <= #`DEL SHIFTER_STATE_SHIFTIR_2; // 1Eh // sample bit, stay in shift-ir
                                                        end
                                                    else
                                                    if (bits_processed == sxr_length - 1) // if second-to-last bit beeing processed
                                                        begin
                                                            sp_tms          <= #`DEL 1;
                                                            shifter_state   <= #`DEL SHIFTER_STATE_SHIFTIR_4; // 20h // sample last bit, prepare transition to exit-1-ir
                                                        end
                                                    else
                                                        begin
                                                            shifter_state   <= #`DEL SHIFTER_STATE_ERROR_5; // F5h
                                                        end
                                                end
                                        end
                                        
                                    SHIFTER_STATE_SHIFTIR_2:  // 1Eh
                                        begin   // set tck to latch tms -> target remains in tap state shift-ir / target samples tdi / bit processed
                                                // on rising tck edge, increment bits_processed
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_SHIFT_IR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    bits_processed  <= #`DEL bits_processed + 1;
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SHIFTIR_3; // 1Fh // evaluate bits_processed
                                                end
                                        end
                                        
                                    SHIFTER_STATE_SHIFTIR_3:  // 1Fh
                                        begin   // if 8 bits have been processed, go to idle state and wait for next start signal
                                                // target remains in shift-ir while next triplet is being provided
                                                // otherwise proceed with next bit
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            
                                            if (bits_processed[2:0] == 0) // || bits_processed[3:0] == 0) 
                                                // the lowest nibble of bits_processed is 8 after 8 processed bits
                                                // they overflow to zero after another 8 bits                                
                                                
                                                begin
                                                    data_req        <= #`DEL 1'b1; // notify executor that triplet has been processed
                                                    shifter_state   <= #`DEL SHIFTER_STATE_IDLE;
                                                end
                                            else
                                                begin
                                                    shifter_state   <= #`DEL SHIFTER_STATE_SHIFTIR_1; // 1Dh
                                                end
                                        end

                                    SHIFTER_STATE_SHIFTIR_4:  // 20h 
                                        begin // set tck to latch tms -> target assumes tap state exit-1-ir / target samples tdi one last time / last bit processed
                                                // on rising tck edge, increment bits_processed
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_EXIT1_IR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    bits_processed  <= #`DEL bits_processed + 1;
                                                    shifter_state   <= #`DEL SHIFTER_STATE_EXIT1IR_1; // 21h
                                                end
                                        end
                                        
                                    SHIFTER_STATE_EXIT1IR_1: // 21h
                                        begin // clear tck, clear tms to prepare transition to pause-ir
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tms          <= #`DEL 0;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_PAUSEIR_1; // 22h
                                                end
                                        end
                                        
                                    SHIFTER_STATE_PAUSEIR_1:  // 22h 
                                        begin // set tck to latch tms -> target assumes tap state pause-ir
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_PAUSE_IR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_PAUSEIR_2; // 23h
                                                end
                                        end

                                    // NOTE: in pause-dr: tck halts (no toggeling)
                                    // tck continues once all shifters have cleared their busy output 
                                    // (all busy signals are ORed in executor to signal pause_request)
                                    // this ensures a synchronized proceeding of all shifters
                                        
                                        
                                    SHIFTER_STATE_PAUSEIR_2: // 23h                      
                                        begin   // clear busy signal so that other waiting shfiters can proceed
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    busy            <= #`DEL 1'b0; // notify other shifters that shifting is complete
                                                    shifter_state   <= #`DEL SHIFTER_STATE_PAUSEIR_3; // 24h
                                                end
                                        end
                                        
                                    SHIFTER_STATE_PAUSEIR_3: // 24h
                                        begin // if no more pause requests, proceed to exit2-ir (if endstate rti) or idle (if endstate pause-ir)
                                            if (pause_request == 0)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sp_tms          <= #`DEL 1;
                                                    
                                                    if (sxr_type_end_state_rti)
                                                    // if endstate is rti, proceed to exit2-ir
                                                        begin
                                                            sct_start       <= #`DEL 1; // start scan clock timer
                                                            shifter_state   <= #`DEL SHIFTER_STATE_EXIT2IR_1; // 25h
                                                        end
                                                    else
                                                    // if endstate is pause-ir, proceed to idle and wait for start signal
                                                        begin
                                                            sxr_done        <= #`DEL 1'b1;  // notify executor, that sxr is done
                                                            bits_processed  <= #`DEL 0; // clear bit counter
                                                            shifter_state   <= #`DEL SHIFTER_STATE_IDLE; // 00h
                                                        end
                                                end
                                        end
                                        
                                    SHIFTER_STATE_EXIT2IR_1:  // 25h 
                                        begin // set tck to latch tms -> target assumes tap state exit2-ir
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_EXIT2_IR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_EXIT2IR_2; // 26h
                                                end
                                        end
                                        
                                    SHIFTER_STATE_EXIT2IR_2: // 26h
                                        begin   // clear tck.
                                                // set tms to prepare transition to update-ir
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    sp_tms          <= #`DEL 1;
                                                    shifter_state   <= #`DEL SHIFTER_STATE_UPDATEIR_1; // 27h
                                                end
                                        end
                                        
                                    SHIFTER_STATE_UPDATEIR_1:  // 27h 
                                        begin // set tck to latch tms -> target assumes tap state update-ir
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 1;
                                                    tap_state_send  <= #`DEL TAP_UPDATE_IR;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    shifter_state   <= #`DEL SHIFTER_STATE_UPDATEIR_2; // 28h
                                                end
                                        end

                                    SHIFTER_STATE_UPDATEIR_2: // 28h
                                        begin   // clear tck.
                                                // according to required end state, clear/set tms to prepare transition to rti or select-dr-scan
                                            sct_start       <= #`DEL 0; // clear scan clock timer start signal
                                            if (sct_done)
                                                begin
                                                    sp_tck          <= #`DEL 0;
                                                    sct_start       <= #`DEL 1; // start scan clock timer
                                                    
                                                    if (ignore_sxr_type)
                                                        begin
                                                            sp_tms          <= #`DEL 1;
                                                            shifter_state   <= #`DEL SHIFTER_STATE_TLR_TO_SELDR_4; // 05h // next: select-dr-scan
                                                        end
                                                    else
                                                        begin
                                                            if (sxr_type_end_state_rti)
                                                            // if end state run-test/idle required, clear tms to prepare transition to run-test/idle
                                                                begin
                                                                    sp_tms          <= #`DEL 0;
                                                                    shifter_state   <= #`DEL SHIFTER_STATE_RTI_1; // 16h // next: rti
                                                                end
                                                            else
                                                            // if end state pause-ir required, set tms to prepare transition to select-dr-scan
                                                                begin
                                                                    sp_tms          <= #`DEL 1;
                                                                    shifter_state   <= #`DEL SHIFTER_STATE_TLR_TO_SELDR_4; // 05h // next: select-dr-scan
                                                                end
                                                        end
                                                        
                                                    ignore_sxr_type <= #`DEL 0;                                                         
                                                end
                                        end
                                        
                                        
                                endcase
                            end
                    end
            end
    end

endmodule
