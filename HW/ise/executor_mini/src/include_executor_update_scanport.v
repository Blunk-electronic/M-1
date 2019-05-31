    // UPDATE SCANPORT OUTPUTS
    //sp_trst <= #`DEL lcp_sp_trst;
    sp_tms  <= #`DEL shifter_sp_tms;
    sp_tck  <= #`DEL shifter_sp_tck;
    sp_tdo  <= #`DEL shifter_sp_tdo;
    
    sp_exp  <= #`DEL shifter_sp_exp;
    sp_mask <= #`DEL shifter_sp_msk;       
                                        
    // UPDATE TAP STATES MONITOR
    tap_state[1]    <= #`DEL shifter_tap_state_send[1];
    tap_state[2]    <= #`DEL shifter_tap_state_send[2]; // add further scanpaths here

    // EVALUATE TDI 1
    // when tap state is shift-xr on a L-H-edge of tck
    if (tap_state[1] == TAP_SHIFT_DR || tap_state[1] == TAP_SHIFT_IR)
        begin
            if (sp_tck[1] == 0 && shifter_sp_tck[1] == 1)
                begin
                    sp_fail[1] <= #`DEL (sp_tdi[1] ^ sp_exp[1]) & sp_mask[1];
                end
        end                                    

    // EVALUATE TDI 2
    // when tap state is shift-xr on a L-H-edge of tck
    if (tap_state[2] == TAP_SHIFT_DR || tap_state[2] == TAP_SHIFT_IR)
        begin
            if (sp_tck[2] == 0 && shifter_sp_tck[2] == 1)
                begin
                    sp_fail[2] <= #`DEL (sp_tdi[2] ^ sp_exp[2]) & sp_mask[2];
                end
        end
        
    // whenever any sp_fail bit is set:
    //  - halt shifters
    //  - go to EX_STATE_TEST_FAIL_1

`ifdef respect_fail
    if (sp_fail != 0)
        if (~sxr_type_retry)
        // If a non-retry sxr is being processed, halt shifters and start fail processing.
            begin
                shifter_halt    <= #`DEL 1;
                ex_state        <= #`DEL EX_STATE_TEST_FAIL_1; // E1h
            end
        else
        // If a retry-sxr is being processed, set retry_sxr_failed flag. This enables counting 
        // of failed sxrs.
        // The fail register sp_fail must be backup in sp_fail_retry. Required on test end to tell the
        // CPU which scanpath had failed.
        // On H-L edge of tck, the register bits_processed must be backup. Required on test end to tell
        // the CPU the position of the failed bit.
            begin
                retry_sxr_failed    <= #`DEL 1;
                sp_fail_retry       <= #`DEL sp_fail;
                
                if (sp_tck[1] == 1 && shifter_sp_tck[1] == 0)
                    begin
                        bits_processed_retry[1] <= #`DEL bits_processed[1];
                    end
                if (sp_tck[2] == 1 && shifter_sp_tck[2] == 0)                
                    begin
                        bits_processed_retry[2] <= #`DEL bits_processed[2];
                    end
            end
`endif
        
        
