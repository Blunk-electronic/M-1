// executor restart states

    //CS: init ram_addr_to_mmu_bak ,ram_addr_to_mmu

    lcp_abort                   <= #`DEL 1'b0;

    compiler_version_major      <= #`DEL `byte_width'h0;
    compiler_version_minor      <= #`DEL `byte_width'h0;    
    vec_format_version_major    <= #`DEL `byte_width'h0;
    vec_format_version_minor    <= #`DEL `byte_width'h0;
    active_scanpaths            <= #`DEL `byte_width'h0;
        
    step_mode_sxr           <= #`DEL 1'b0;
    step_mode_tck           <= #`DEL 1'b0;    
    //go_step_test_ack        <= #`DEL 1'b0;
    //test_abort_ack          <= #`DEL 1'b0;        
    
    //data_acknowledge_to_mmu <= #`DEL 1'b0;
    data_request_to_mmu     <= #`DEL 1'b0;
    //test_fail               <= #`DEL 1'b0;
    //test_pass               <= #`DEL 1'b0;
    
    scanpath_pointer            <= #`DEL `scanpath_pointer_width'h0;
    scanpath_base_address[1]    <= #`DEL `scanpath_base_address_width'h0;
    scanpath_base_address[2]    <= #`DEL `scanpath_base_address_width'h0;
//     scanpath_base_address[3]    <= #`DEL `scanpath_base_address_width'h0;
//     scanpath_base_address[4]    <= #`DEL `scanpath_base_address_width'h0;
//     scanpath_base_address[5]    <= #`DEL `scanpath_base_address_width'h0;
//     scanpath_base_address[6]    <= #`DEL `scanpath_base_address_width'h0;
//     scanpath_base_address[7]    <= #`DEL `scanpath_base_address_width'h0;    
//     scanpath_base_address[8]    <= #`DEL `scanpath_base_address_width'h0;        
    
    scanpath_address[1]         <= #`DEL `scanpath_base_address_width'h0;
    scanpath_address[2]         <= #`DEL `scanpath_base_address_width'h0;    

    scanpath_address_retry[1]   <= #`DEL `scanpath_base_address_width'h0;
    scanpath_address_retry[2]   <= #`DEL `scanpath_base_address_width'h0;    
    
//     scanpath_address[3]         <= #`DEL `scanpath_base_address_width'h0;    
//     scanpath_address[4]         <= #`DEL `scanpath_base_address_width'h0;    
//     scanpath_address[5]         <= #`DEL `scanpath_base_address_width'h0;
//     scanpath_address[6]         <= #`DEL `scanpath_base_address_width'h0;    
//     scanpath_address[7]         <= #`DEL `scanpath_base_address_width'h0;    
//     scanpath_address[8]         <= #`DEL `scanpath_base_address_width'h0;    
//    scanpath_address_tmp        <= #`DEL `scanpath_base_address_width'h0;
//     scanpath_data[1]            <= #`DEL `byte_width'h0;
//     scanpath_data[2]            <= #`DEL `byte_width'h0;    
//     scanpath_data[3]            <= #`DEL `byte_width'h0;
//     scanpath_data[4]            <= #`DEL `byte_width'h0;    
//     scanpath_data[5]            <= #`DEL `byte_width'h0;
//     scanpath_data[6]            <= #`DEL `byte_width'h0;    
//     scanpath_data[7]            <= #`DEL `byte_width'h0;
//     scanpath_data[8]            <= #`DEL `byte_width'h0;    
    
    lcp_cmd                     <= #`DEL `byte_width'h0;
    lcp_arg1                    <= #`DEL `byte_width'h0;
    lcp_arg2                    <= #`DEL `byte_width'h0;    
    lcp_start                   <= #`DEL 1'b0;
    //low_level_command_executed  <= #`DEL 1'b0;
    
//     sxr_length[1]           <= #`DEL `chain_length_width'b0;
//     sxr_length[2]           <= #`DEL `chain_length_width'b0;
    
    sxr_drv[1]              <= #`DEL `byte_width'h0;
    sxr_drv[2]              <= #`DEL `byte_width'h0;
    
    sxr_msk[1]              <= #`DEL `byte_width'h0;
    sxr_msk[2]              <= #`DEL `byte_width'h0;    
    
    sxr_exp[1]              <= #`DEL `byte_width'h0;
    sxr_exp[2]              <= #`DEL `byte_width'h0;    

    sxr_byte_count_total[1]     <= #`DEL `chain_byte_count_width'b0;
    sxr_byte_count_total[2]     <= #`DEL `chain_byte_count_width'b0;
    sxr_byte_count_current[1]   <= #`DEL `chain_byte_count_width'b0;
    sxr_byte_count_current[2]   <= #`DEL `chain_byte_count_width'b0;
    
    sxr_zero_byte_count[1]      <= #`DEL 1'b0;
    sxr_zero_byte_count[2]      <= #`DEL 1'b0;        
    
    shifter_start               <= #`DEL 1'b0;

    test_step_ct_total      <= #`DEL `test_step_ct_width'b0;
    test_step_ct_current    <= #`DEL `test_step_ct_width'b0;
    //step_id                 <= #`DEL `step_id_width'b0;
    
    //ram_addr_to_mmu         <= #`DEL `ram_addr_width'b0;
    
    reset_timer_n           <= #`DEL 1'b1;    

    sp_trst                 <= #`DEL init_state_trst;
    sp_tms                  <= #`DEL init_state_tms;    
    sp_tck                  <= #`DEL init_state_tck;
    sp_tdo                  <= #`DEL init_state_tdo;
    
    //sp_exp                  <= #`DEL init_state_exp;
    sp_mask                 <= #`DEL init_state_mask;
    //sp_fail                 <= #`DEL init_state_fail;    

    tap_state[1]            <= #`DEL TAP_TEST_LOGIG_RESET;
    tap_state[2]            <= #`DEL TAP_TEST_LOGIG_RESET;
    
    shifter_halt            <= #`DEL 1'b0;

    sxr_type                <= #`DEL `byte_width'h0;
    retry_count_max         <= #`DEL `byte_width'h0;    
    retry_count             <= #`DEL `byte_width'h0;
    delay_before_retry      <= #`DEL `byte_width'h0;
    retry_sxr_failed        <= #`DEL 0;
    ram_addr_for_retry      <= #`DEL `ram_addr_width'h0;
    

    shifter_data_request_cache              <= #`DEL `byte_width'h0;
    
    latch_byte_ct_lowest_active_scanpath    <= #`DEL 0;
    
