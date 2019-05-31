module executor(
		reset_n, // input
		clk,  // input
		ex_state, // output

        go_step_tck, // input from command decoder
        go_step_sxr, // input from command decoder        
        //go_step_yxz
        go_step_test, // input from command decoder
        //go_step_test_ack, // acknowledge to command decoder
        
        breakpoint_sxr_id, // input from rf
        breakpoint_bit_position, // input from rf
        
        test_halt, // input from command decoder
        
        test_abort, // input from command decoder
        //test_abort_ack, // acknowledge to command decoder
		//start_stop_from_rf, // input , CS: see above // obsolete
        
		data_ready_from_mmu, // input
		//data_acknowledge_to_mmu, // output
		data_request_to_mmu, // output

		start_from_panel, // input
		//stop_from_panel, // input
		//test_pass, // output
		//test_fail, // output
		
        bits_processed_chain_1, // output
        sxr_length_chain_1, // output
        bits_processed_chain_2, // output        
        sxr_length_chain_2, // output
        step_id, // output
        
        tap_state_1, // output
        tap_state_2, // output        
        
        //tck_frequency, // CS: not used , may be used to override frequency compiled in vector file
        ram_addr_to_mmu, // output
        ram_data_from_mmu, // input
        start_addr_in, // input
        
		sda, // bidir
		scl, // bidir
		emergency_pwr_off_n, // output
		//uut_pwr_fail_from_pwr_ctrl, // input		
		reset_timer_n, // output
		        
        sp_trst, // output
        sp_tms, // output
        sp_tck, // output
        sp_tdo, // output        
        sp_tdi, // input
        
        sp_exp, // output
        sp_mask, // output
        sp_fail, // output
        
        //clk_scan, // output, for simulation only
        lcp_state, // output, read by rf
        i2c_master_state, // output, read by rf
        timer_state, // output
        shifter_state_1, // output
        shifter_state_2, // output        
        
        scan_clock_timer_state_1, // output
        scan_clock_timer_state_2 // output        
    );
    
    `include "parameters_global.v"  
    
	 
    input reset_n;
	input clk;

	input go_step_tck;
	input go_step_sxr;
	input go_step_test;
	//output reg go_step_test_ack;
	
	input [`step_id_width-1:0] breakpoint_sxr_id;
    input [`chain_length_width-1:0] breakpoint_bit_position;

	
	input test_halt;
	input test_abort;
	//output reg test_abort_ack;

	input data_ready_from_mmu;
	//output reg data_acknowledge_to_mmu;
    output reg data_request_to_mmu;
	//input [`ram_data_width-1:0] start_stop_from_rf; // AAh start /55h stop test driven by rf // obsolete
    input start_from_panel;
    //input stop_from_panel;
    //output reg test_pass;
    //output reg test_fail;
    //input uut_pwr_fail_from_pwr_ctrl;
    
    // ROUTING FROM sxr_length_chain_x TO ARRAY sxr_length
    reg [`chain_length_width-1:0] sxr_length [1:scanpath_count_max]; // holds the sxr length
    output [`chain_length_width-1:0] sxr_length_chain_1; // output
    assign sxr_length_chain_1 = sxr_length[1][`chain_length_width-1:0];
    output [`chain_length_width-1:0] sxr_length_chain_2; // output
    assign sxr_length_chain_2 = sxr_length[2][`chain_length_width-1:0];

    // NOTE: the byte count of an sxr is required for advancing the scanpath_address when shifters request data
    reg [`chain_byte_count_width-3:0] sxr_byte_count_total      [1:scanpath_count_max]; // holds byte count of an sxr (after division of length by 8)
    reg [`chain_byte_count_width-3:0] sxr_byte_count_current    [1:scanpath_count_max]; // holds current byte count of sxr   
    reg sxr_zero_byte_count [1:scanpath_count_max]; // holds a 1 when no more bytes left while sxr execution
    
    reg [`byte_width-1:0] sxr_drv [1:scanpath_count_max];
    reg [`byte_width-1:0] sxr_msk [1:scanpath_count_max];
    reg [`byte_width-1:0] sxr_exp [1:scanpath_count_max];    

    
    // ROUTING bits_processed
    output reg [`chain_length_width-1:0] bits_processed_chain_1; // output    
    output reg [`chain_length_width-1:0] bits_processed_chain_2; // output
    reg bp_retry_send; // This flag switches between the sources.
    
    // Source #1 of bits_processed are the shifters. Used if a non-retry sxr failed.
    wire [`chain_length_width-1:0] bits_processed [1:scanpath_count_max]; // driven by shifter

    // Source #2 is bits_processed_retry. Used at test end if a retry sxr failed.    
    reg [`chain_length_width-1:0] bits_processed_retry [1:scanpath_count_max]; // used to backup bits_processed in retry-SXRs

    // Switching by combinatorial logic:
    always @(bp_retry_send,bits_processed[1],bits_processed_retry[1],bits_processed[2],bits_processed_retry[2]) // ise requires all elements in sensitivity list
        if (~bp_retry_send) // if bp_retry_send cleared (default) bits_processed sent by shifters active
            begin
                bits_processed_chain_1 = bits_processed[1];
                bits_processed_chain_2 = bits_processed[2];    
            end
        else // if bp_retry_send set (when retry-sxr failed), failed bit position of retry-sxr active
            begin
                bits_processed_chain_1 = bits_processed_retry[1];
                bits_processed_chain_2 = bits_processed_retry[2];      
            end
  
    
    output reg [`step_id_width-1:0] step_id; // output // points to the sxr id 
    reg [`test_step_ct_width-1:0] test_step_ct_total; // holds number of steps (incl. low level commands)
    reg [`test_step_ct_width-1:0] test_step_ct_current; // holds number of steps processed (incl. low level commands)
    
    // TAP STATES MONITOR
    reg [`nibble_width-1:0] tap_state [1:scanpath_count_max];    

    // ROUTING FROM ARRAY tap_state to tap_state_x
    output [`nibble_width-1:0] tap_state_1; // output
    output [`nibble_width-1:0] tap_state_2; // output    
    assign tap_state_1 = tap_state[1];
    assign tap_state_2 = tap_state[2];

    
    output reg [`ram_addr_width-1:0] ram_addr_to_mmu;
    reg [`ram_addr_width-1:0] ram_addr_to_mmu_bak;
    reg [`ram_addr_width-1:0] ram_addr_for_retry;    
    input [`ram_data_width-1:0] ram_data_from_mmu;
    input [`ram_addr_width-1:0] start_addr_in;

    inout sda;
    inout scl;
    
    output reg emergency_pwr_off_n; // CS: H or L active ?
    
    output reg [`scanpath_count_max:1] sp_trst;
    output reg [`scanpath_count_max:1] sp_tms;
    output reg [`scanpath_count_max:1] sp_tck;
    output reg [`scanpath_count_max:1] sp_tdo;
    input      [`scanpath_count_max:1] sp_tdi;
    
    output reg [`scanpath_count_max:1] sp_exp;
    output reg [`scanpath_count_max:1] sp_mask;
    output reg [`scanpath_count_max:1] sp_fail;
    reg [`scanpath_count_max:1] sp_fail_retry; // serves as backup of failed scanports when processing retry-sxr

    reg shifter_halt; // causes the shifters to halt while keeping all its registers unchanged
    
    //output clk_scan;
    output [`byte_width-1:0] lcp_state;
    
    output reg [`executor_state_width-1:0] ex_state;
    //reg [`executor_state_width-1:0] ex_state_next;    
    //reg delay_bit;
    
    reg [`byte_width-1:0] compiler_version_major;
    reg [`byte_width-1:0] compiler_version_minor;
    
    reg [`byte_width-1:0] vec_format_version_major;
    reg [`byte_width-1:0] vec_format_version_minor;
    
    reg [`byte_width-1:0] active_scanpaths; // has a bit set for every active scanpath
    reg [`scanpath_pointer_width-1:0] scanpath_pointer; // points to a scanpath being processed (zero based)
    //reg [`scanpath_base_address_width-1:0] scanpath_base_address [1:active_scanpath_max]; // CS: should be [1:scanpath_count_max];
    reg [`scanpath_base_address_width-1:0] scanpath_base_address [1:scanpath_count_max];    
    //reg [`scanpath_base_address_width-1:0] scanpath_address [1:active_scanpath_max];
    reg [`scanpath_base_address_width-1:0] scanpath_address [1:scanpath_count_max];
    reg [`scanpath_base_address_width-1:0] scanpath_address_retry [1:scanpath_count_max];        
    //reg [`byte_width-1:0] scanpath_data [1:active_scanpath_max];
    //reg [`byte_width-1:0] scanpath_data [1:scanpath_count_max];
    //reg [`scanpath_base_address_width-1:0] scanpath_address_tmp;

    //input [`ram_data_width-1:0] tck_frequency; // CS: not used, may be used to override frequency compiled in vector file
    //reg [`byte_width-1:0] scratch;

    reg [`byte_width-1:0] lcp_cmd;
    reg [`byte_width-1:0] lcp_arg1;
    reg [`byte_width-1:0] lcp_arg2;    
    reg lcp_start;
    //reg low_level_command_executed;
    
    output reg reset_timer_n;
    
    wire [`scanpath_count_max:1] lcp_sp_trst;
    wire [`scanpath_count_max:1] lcp_sp_tms;
    wire [`scanpath_count_max:1] lcp_sp_tck;
    wire [`scanpath_count_max:1] lcp_sp_tdo;    
    
	output [`byte_width-1:0] i2c_master_state;
	output [`timer_state_width-1:0] timer_state;	
	wire [`nibble_width-1:0] lcp_tap_state_send [1:scanpath_count_max]; // holds all tap states send from lcp
	wire [`byte_width-1:0] scan_clock_frequency;
	reg lcp_abort;
	
    low_level_command_processor lcp (
        .clk(clk), // input
        .reset_n(reset_n), // input
        .reset(lcp_abort), // input
        .start(lcp_start), // input
        .done(lcp_done), // output
        .command(lcp_cmd), // input
        .arg1(lcp_arg1),   // input / lowbyte
        .arg2(lcp_arg2),   // input / highbyte
        
        .sda(sda), // inout
        .scl(scl),  // inout
        
        .sp_trst(lcp_sp_trst), // output
        .sp_tms(lcp_sp_tms), // output
        .sp_tck(lcp_sp_tck), // output
        .sp_tdo(lcp_sp_tdo), // output        
        
        //.clk_scan(clk_scan), // output
        .lcp_state(lcp_state), // output, read by rf
        .i2c_master_state(i2c_master_state), // output, read by rf
        .timer_state(timer_state), // output
        .tap_states_feedback({tap_state[2], tap_state[1]}), // input // holds all tap states // from tap states monitor // inside lcp not used
        .tap_states_send({lcp_tap_state_send[2], lcp_tap_state_send[1]}), // output // to tap states monitor
        .scan_clock_frequency(scan_clock_frequency) // output
        );
        
    reg [`byte_width-1:0] sxr_type;        
    `include "include_sxr_type.v" // wire to bit assignments 
    
    reg [`byte_width-1:0] retry_count_max;  // holds the retry count as specified in vector file
    reg [`byte_width-1:0] retry_count;      // incremented after each failed retry-sxr
    reg [`byte_width-1:0] delay_before_retry;    
    reg retry_sxr_failed;
        
    reg [`byte_width-1:0] sxr_scanpath_id; 
    
    reg shifter_start; // starts all shifter modules
    wire shifter_data_req    [1:scanpath_count_max]; // set when shifter has processed a triplet
    wire shifter_sxr_done       [1:scanpath_count_max]; // set when shifter has processed all bits of sxr
    wire [`nibble_width-1:0] shifter_tap_state_send [1:scanpath_count_max]; // holds all tap states send from shifters

    // ROUTING SHIFTER STATES
    wire [`byte_width-1:0] shifter_state_wire [1:scanpath_count_max]; // holds all shifter states
    output [`byte_width-1:0] shifter_state_1;
    output [`byte_width-1:0] shifter_state_2;    
    assign shifter_state_1 = shifter_state_wire[1];
    assign shifter_state_2 = shifter_state_wire[2];    

    //wire [`scanpath_count_max:1] shifter_sp_trst;
    wire [`scanpath_count_max:1] shifter_sp_tms;
    wire [`scanpath_count_max:1] shifter_sp_tck;
    wire [`scanpath_count_max:1] shifter_sp_tdo;
    //wire [`scanpath_count_max:1] shifter_sp_tdi;
    wire [`scanpath_count_max:1] shifter_sp_exp;    
    wire [`scanpath_count_max:1] shifter_sp_msk;    
   
    // STEP MODE CIRCUITRY
    reg step_mode_sxr;
    reg step_mode_tck;
   
    // wire pause_request is the result of ORing shifter_busy signals
    // means: if any shifter is busy, it signals other shifters to pause for that time
    wire pause_request;
    wire shifter_busy [1:scanpath_count_max];
    
    // ROUTING SCAN CLOCK TIMER STATES
    wire [`timer_scan_state_width-1:0] scan_clock_timer_state_wire [1:scanpath_count_max]; // holds all scan clock timer states
    output [`timer_scan_state_width-1:0] scan_clock_timer_state_1;
    output [`timer_scan_state_width-1:0] scan_clock_timer_state_2;
    assign scan_clock_timer_state_1 = scan_clock_timer_state_wire[1];
    assign scan_clock_timer_state_2 = scan_clock_timer_state_wire[2];    
   
    // If shifters are halted in step mode (that is tck step width).
    // Any go_step command or start_from_panel cause them to resume operation. therefore they are ORed here.
    wire shifter_step = go_step_test | go_step_sxr | go_step_tck | start_from_panel;
    //wire shifter_step = go_step_test | go_step_sxr | go_step_tck;
    
    reg shifter_restart; // used to restart shifters on test start (required when restarting test)
    
    shifter sh1 (
        .clk(clk), // input
        .reset_n(reset_n), // input
        .enable(active_scanpaths[0]), // input, shifters are enabled if corresponding scanport is active
        .start(shifter_start), // input
        .halt(shifter_halt), // input
        .restart(shifter_restart), // input
        .step_mode_tck(step_mode_tck), // input
        .go_step_tck(shifter_step), // input
        .data_req(shifter_data_req[1]), // output
        .sxr_done(shifter_sxr_done[1]), // output
        .busy(shifter_busy[1]), // output
        .pause_request(pause_request), // input
        
        .drive(sxr_drv[1]), // input
        .mask(sxr_msk[1]),  // input
        .expect(sxr_exp[1]),// input
        
        .sp_tms(shifter_sp_tms[1]), // output
        .sp_tck(shifter_sp_tck[1]), // output
        .sp_tdo(shifter_sp_tdo[1]), // output        
        .sp_exp(shifter_sp_exp[1]), // output
        .sp_msk(shifter_sp_msk[1]), // output        
        
        .sxr_type(sxr_type), // input        
        .sxr_length(sxr_length[1]), // input
        .bits_processed(bits_processed[1]), // output
        
        .tap_state_feedback(tap_state[1]), // input, holds latest tap state // from tap states monitor
        .tap_state_send(shifter_tap_state_send[1]), // output, // to tap states monitor
        .shifter_state(shifter_state_wire[1]), // output, read by rf for monitoring
        .scan_clock_frequency(scan_clock_frequency), // input, driven by lcp
        .scan_clock_timer_state(scan_clock_timer_state_wire[1]) // output
        );
        
    shifter sh2 (
        .clk(clk), // input
        .reset_n(reset_n), // input
        .enable(active_scanpaths[1]), // input, shifters are enabled if corresponding scanport is active        
        .start(shifter_start), // input
        .halt(shifter_halt), // input        
        .restart(shifter_restart), // input        
        .step_mode_tck(step_mode_tck), // input        
        .go_step_tck(shifter_step), // input        
        .data_req(shifter_data_req[2]), // output
        .sxr_done(shifter_sxr_done[2]), // output
        .busy(shifter_busy[2]), // output
        .pause_request(pause_request), // input        
        
        .drive(sxr_drv[2]), // input
        .mask(sxr_msk[2]),  // input
        .expect(sxr_exp[2]),// input
        
        .sp_tms(shifter_sp_tms[2]), // output
        .sp_tck(shifter_sp_tck[2]), // output
        .sp_tdo(shifter_sp_tdo[2]), // output        
        .sp_exp(shifter_sp_exp[2]), // output
        .sp_msk(shifter_sp_msk[2]), // output        
        
        .sxr_type(sxr_type), // input        
        .sxr_length(sxr_length[2]), // input
        .bits_processed(bits_processed[2]), // output
        
        .tap_state_feedback(tap_state[2]), // input, holds latest tap state // from tap states monitor
        .tap_state_send(shifter_tap_state_send[2]), // output, // to tap states monitor
        .shifter_state(shifter_state_wire[2]), // output, read by rf for monitoring
        .scan_clock_frequency(scan_clock_frequency), // input, driven by lcp
        .scan_clock_timer_state(scan_clock_timer_state_wire[2]) // output        
        );

    // - as long as any shifter is shifting, pause_request goes active
    // shifters clear shifter_busy when they reach pause-xr state
    // - shifters sample pause_request in state pause-xr and remain there until pause_request goes inactive
    assign pause_request = (shifter_busy[1] | shifter_busy[2]);
    
    wire [`scanpath_count_max:1] shifter_data_request; // one-based !
    assign shifter_data_request = {shifter_data_req[2], shifter_data_req[1]}; // add further scanpaths here
    reg [`scanpath_count_max:1] shifter_data_request_cache; // holds shifter data request tempoarily

    wire [`scanpath_count_max:1] shifter_done; // one-based !
    assign shifter_done = {shifter_sxr_done[2], shifter_sxr_done[1]}; // add further scanpaths here
     
    reg latch_byte_ct_lowest_active_scanpath;
    
	always @(posedge clk or negedge reset_n) begin : fsm2
        if (~reset_n) 
            begin
                `include "include_executor_restart.v"
                emergency_pwr_off_n		<= #`DEL `emergency_pwr_off_release;
                step_id                 <= #`DEL `step_id_width'b0;            
                ram_addr_to_mmu         <= #`DEL `ram_addr_width'b0;
                sxr_length[1]           <= #`DEL `chain_length_width'b0;
                sxr_length[2]           <= #`DEL `chain_length_width'b0;
                shifter_restart         <= #`DEL 1'b0;
                sp_fail                 <= #`DEL init_state_fail;
                sp_fail_retry           <= #`DEL init_state_fail; 
                bp_retry_send           <= #`DEL 1'b0;
				bits_processed_retry[1] <= #`DEL `chain_length_width'b0;
				bits_processed_retry[2] <= #`DEL `chain_length_width'b0;
                ex_state                <= #`DEL EX_STATE_IDLE; // 0h
            end
        else
            begin
                if (test_abort)
                    begin
                        // CS: for unknown reason, ise requires the follwing two lines
                        scanpath_address[1]         <= #`DEL `scanpath_base_address_width'h0;
                        scanpath_address[2]         <= #`DEL `scanpath_base_address_width'h0;    

                        // CS: emergency_pwr_off_n		    <= #`DEL `emergency_pwr_off_release;
                        lcp_abort               <= #`DEL 1'b1; // abort any running low level command
                        shifter_halt            <= #`DEL 1; // halt all shifters
                        ex_state                <= #`DEL EX_STATE_TEST_ABORT_1; // E4h

//                         emergency_pwr_off_n		<= #`DEL `emergency_pwr_off_release;
//                         sxr_length[1]           <= #`DEL `chain_length_width'b0;
//                         sxr_length[2]           <= #`DEL `chain_length_width'b0;
//                         sp_fail                 <= #`DEL init_state_fail;                            
//                         ex_state                <= #`DEL EX_STATE_IDLE; // 0h
                    end
                else
                    begin
                        case (ex_state) // synthesis parallel_case
                            // CS: MAKE SURE EXECUTOR STARTS AFTER RAM INIT
                            EX_STATE_IDLE, // 0h
                            EX_STATE_ERROR_COMPILER_2, // F1h
                            EX_STATE_ERROR_FRMT_2, // F3h
                            EX_STATE_ERROR_ACT_SCNPT_2, // 08h
                            EX_STATE_ERROR_RD_SXR_SP_ID_2, // 5Eh
                            EX_STATE_TEST_FAIL_3, // E3h
                            EX_STATE_TEST_ABORT_4, // E7h
                            EX_STATE_END_OF_TEST: // E0h
                            //EX_STATE_EXCT_LC: // 2Ch // LCP freezes, restart from here is allowed
                                begin
                                    // - test start is triggered by any go_step signal or by start_from_panel
                                    // - if go_step_sxr triggered, set step_mode_sxr flag -> execution will halt 
                                    //   after the first executed sxr in state EX_STATE_WAIT_STEP_SXR (5Ch)
                                    // - if go_step_tck triggered, set step_mode_tck flag -> execution will halt
                                    //   after the first tck transition (shifters are halted)
                                    
									// - uut emergency power down must be unlocked
									// - shifter halt must be unlocked

									//if (go_step_test || go_step_sxr || go_step_tck)
                                    if (go_step_test || go_step_sxr || go_step_tck || start_from_panel)
                                        begin                                        
                                            if (go_step_sxr)
                                                begin
                                                    step_mode_sxr      <= #`DEL 1'b1;
                                                end

                                            if (go_step_tck)
                                                begin
                                                    step_mode_tck      <= #`DEL 1'b1;
                                                end
                                                
                                            ex_state                    <= #`DEL EX_STATE_SET_START_ADR; // 1h
                                            //go_step_test_ack            <= #`DEL 1'b1;  // send command decoder confirmation of test start command
                                            ram_addr_to_mmu             <= #`DEL start_addr_in; // register start address as driven by rf (via mmu)
                                            reset_timer_n               <= #`DEL 1'b0; // reset timers on power monitor
                                            emergency_pwr_off_n			<= #`DEL `emergency_pwr_off_unlock; // unlock UUT emergency shutdown
                                            step_id                     <= #`DEL `step_id_width'b0;
                                            shifter_restart             <= #`DEL 1'b1;
                                            sp_fail                     <= #`DEL init_state_fail; 
                                            sp_fail_retry               <= #`DEL init_state_fail;
                                            bp_retry_send               <= #`DEL 1'b0;
											bits_processed_retry[1] 	<= #`DEL `chain_length_width'b0;
											bits_processed_retry[2] 	<= #`DEL `chain_length_width'b0;

                                            // CS:                         sxr_length[1]           <= #`DEL `chain_length_width'b0;
                                            //                         sxr_length[2]           <= #`DEL `chain_length_width'b0;

                                        end
                                end
                                
                        // SET TEST START ADDRESS
                            EX_STATE_SET_START_ADR: // 1h
                                begin
                                    //go_step_test_ack        <= #`DEL 1'b0; // clear command acknowledge
                                    data_request_to_mmu     <= #`DEL 1'b1; // request new data from mmu
                                    reset_timer_n           <= #`DEL 1'b1;
                                    shifter_restart         <= #`DEL 1'b0;
                                    ex_state                <= #`DEL EX_STATE_RD_COMP_VER_MAJOR; // 2h
                                end
                                
                                
                        // COMPILER VERSION CHECK         
                            EX_STATE_RD_COMP_VER_MAJOR: // 2h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0; // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address for next data fetch
                                            data_request_to_mmu         <= #`DEL 1'b1; // request new data from location ram_addr_to_mmu
                                            ex_state                    <= #`DEL EX_STATE_RD_COMP_VER_MINOR; // 3h
                                            compiler_version_major      <= #`DEL ram_data_from_mmu;
                                        end
                                end

                                
                            EX_STATE_RD_COMP_VER_MINOR: // 3h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0; // clear data request                                
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            //ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            //data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            ex_state                    <= #`DEL EX_STATE_CHK_VER_COMP; // 4h
                                            compiler_version_minor      <= #`DEL ram_data_from_mmu;
                                        end
                                end
                                 
                            EX_STATE_CHK_VER_COMP: // 4h
                                begin
                                    //data_request_to_mmu         <= #`DEL 1'b0;                                
                                    if (compiler_version_major == compiler_version_major_required) // CS: up/down compatibilty check ?
                                        // NOTE: CS: minor version ignored currently
                                        //&& (compiler_version_minor == compiler_version_minor_required))
                                        begin
                                            ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            ex_state                    <= #`DEL EX_STATE_RD_VEC_FRMT_MAJOR; // 5h
                                        end
                                    else // if vec file has been compiled with a wrong compiler -> shutdown uut
                                        begin
                                            //`include "include_executor_reset.v"
											// start lcp to power down the uut
                                            `include "include_executor_shutdown.v"
                                            ex_state                    <= #`DEL EX_STATE_ERROR_COMPILER_1; // F0h
                                        end
                                end

							EX_STATE_ERROR_COMPILER_1: // F0h
								begin
									lcp_start       <= #`DEL 1'b0; // clear low level command start signal
									if (lcp_done) // wait until lcp is ready
										begin
                                            `include "include_executor_restart.v"										
											ex_state                    <= #`DEL EX_STATE_ERROR_COMPILER_2; // F1h
										end
								end

                                 
                        // VECTOR FORMAT CHECK:                                
                            EX_STATE_RD_VEC_FRMT_MAJOR: // 5h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            vec_format_version_major    <= #`DEL ram_data_from_mmu;
                                            ex_state                    <= #`DEL EX_STATE_RD_VEC_FRMT_MINOR; // 6h
                                        end
                                end
 
                            EX_STATE_RD_VEC_FRMT_MINOR: // 6h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            //ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            //data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            vec_format_version_minor    <= #`DEL ram_data_from_mmu;
                                            ex_state                    <= #`DEL EX_STATE_CHK_VER_FRMT; // 7h
                                        end
                                end

                            EX_STATE_CHK_VER_FRMT: // 7h
                                begin
                                    if (vec_format_version_major == vec_format_version_major_required) // CS: up/down compatibilty check ?
                                        // NOTE: CS: minor version ignored currently
                                        begin
                                            ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            ex_state                    <= #`DEL EX_STATE_RD_ACT_SCNPT; // 9h
                                        end
                                    else // when vector file format invalid, shutdown uut
                                        begin
                                            //`include "include_executor_reset.v"
											// start lcp to power down the uut
                                            `include "include_executor_shutdown.v"
                                            ex_state                    <= #`DEL EX_STATE_ERROR_FRMT_1; // F2h
                                        end
                                end

							EX_STATE_ERROR_FRMT_1: // F2h
								begin
									lcp_start       <= #`DEL 1'b0; // clear low level command start signal
									if (lcp_done) // wait until lcp is ready
										begin
                                            `include "include_executor_restart.v"										
											ex_state                    <= #`DEL EX_STATE_ERROR_FRMT_2; // F3h
										end
								end

                                
                        // SCANPATH COUNT CHECK: 
                            EX_STATE_RD_ACT_SCNPT: // 9h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            //ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            //data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            active_scanpaths    <= #`DEL ram_data_from_mmu;                                            
                                            ex_state            <= #`DEL EX_STATE_CHK_ACT_SCNPT; // Ah
                                        end
                                end

                            EX_STATE_CHK_ACT_SCNPT: // Ah
                                begin
                                    if (active_scanpaths <= active_scanpath_max) // both have a bit set for every active scanpath
                                        begin
                                            ex_state            <= #`DEL EX_STATE_INC_SCNPT_PTR; // Ch
                                        end
                                    else // if more scanpaths are set active than allowed -> shutdown
                                        begin
                                            //`include "include_executor_reset.v"
											// start lcp to power down the uut
                                            `include "include_executor_shutdown.v"                                         
                                            ex_state            <= #`DEL EX_STATE_ERROR_ACT_SCNPT_1; // Bh
                                        end
                                end
                                
							EX_STATE_ERROR_ACT_SCNPT_1: // Bh
								begin
									lcp_start       <= #`DEL 1'b0; // clear low level command start signal
									if (lcp_done) // wait until lcp is ready
										begin
                                            `include "include_executor_restart.v"
											ex_state                    <= #`DEL EX_STATE_ERROR_ACT_SCNPT_2; // 8h
										end
								end
                                
                                         
                        // READ SCANPATHS BASE ADDRESSES
                            EX_STATE_INC_SCNPT_PTR: // Ch
                                begin
//                                     ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address for next data fetch
//                                     data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu (from location ram_addr_to_mmu)

                                    if (scanpath_pointer < scanpath_count_max) 
                                    // loop here for every available scanpath (regardless if active or not)
                                        begin
                                            scanpath_pointer    <= #`DEL scanpath_pointer + 1; // advance scanpath_pointer (zero based !)
                                            // if scanpath is active (the corresponding bit is set in active_scanpaths)
                                            if (active_scanpaths[scanpath_pointer] == 1)
                                                begin
                                                    ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address for next data fetch
                                                    data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu (from location ram_addr_to_mmu)
                                                    ex_state            <= #`DEL EX_STATE_RD_BASE_ADDR_BYTE_0; // Dh
                                                end
                                        end
                                    else
                                        begin
                                            scanpath_pointer    <= #`DEL `scanpath_pointer_width'h0; // reset scanpath_pointer
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address for next data fetch
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu (from location ram_addr_to_mmu)
                                            ex_state            <= #`DEL EX_STATE_RD_FRQ_TCK; // 11h
                                        end
                                end
                            
                            EX_STATE_RD_BASE_ADDR_BYTE_0: // Dh
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            //scanpath_pointer    <= #`DEL scanpath_pointer + 1;
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            scanpath_base_address[scanpath_pointer][7:0]    <= #`DEL ram_data_from_mmu;
                                            scanpath_address[scanpath_pointer][7:0]         <= #`DEL ram_data_from_mmu;
                                            ex_state                                        <= #`DEL EX_STATE_RD_BASE_ADDR_BYTE_1; // Eh
                                        end
                                end
                                    
                            EX_STATE_RD_BASE_ADDR_BYTE_1: // Eh
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            //scanpath_pointer    <= #`DEL scanpath_pointer + 1;
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            scanpath_base_address[scanpath_pointer][15:8]   <= #`DEL ram_data_from_mmu;
                                            scanpath_address[scanpath_pointer][15:8]        <= #`DEL ram_data_from_mmu;                                    
                                            ex_state                                        <= #`DEL EX_STATE_RD_BASE_ADDR_BYTE_2; // Fh
                                        end
                                end

                            EX_STATE_RD_BASE_ADDR_BYTE_2: // Fh
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            //scanpath_pointer    <= #`DEL scanpath_pointer + 1;
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            scanpath_base_address[scanpath_pointer][23:16]  <= #`DEL ram_data_from_mmu;
                                            scanpath_address[scanpath_pointer][23:16]       <= #`DEL ram_data_from_mmu;                                    
                                            ex_state                                        <= #`DEL EX_STATE_RD_BASE_ADDR_BYTE_3; // 10h
                                        end
                                end
                            
                            EX_STATE_RD_BASE_ADDR_BYTE_3: // 10h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            //scanpath_pointer    <= #`DEL scanpath_pointer + 1;
                                            //ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            //data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            scanpath_base_address[scanpath_pointer][31:24]  <= #`DEL ram_data_from_mmu;
                                            scanpath_address[scanpath_pointer][31:24]       <= #`DEL ram_data_from_mmu;                                    
                                            ex_state                                        <= #`DEL EX_STATE_INC_SCNPT_PTR; // Ch
                                        end
                                end

                                
                        // READ AND SET TCK FREQUENCY
                            EX_STATE_RD_FRQ_TCK: // 11h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            lcp_start       <= #`DEL 1'b1;
                                            lcp_cmd         <= #`DEL lc_set_frq_tck;
                                            lcp_arg1        <= #`DEL ram_data_from_mmu;                                            
                                            lcp_arg2        <= #`DEL `byte_width'h00; // not required, fixed to zero
                                            ex_state        <= #`DEL EX_STATE_SET_FRQ_TCK; // 12h
                                        end
                                end
                                 
                            EX_STATE_SET_FRQ_TCK: // 12h
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_THRSHLD_TDI_1; // 14h
                                        end
                                end

                        // READ AND SET THRESHOLDS
                            EX_STATE_RD_THRSHLD_TDI_1: // 14h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            lcp_start       <= #`DEL 1'b1;                                            
                                            lcp_cmd         <= #`DEL lc_set_sp_thrshld_tdi;
                                            lcp_arg1        <= #`DEL lc_scanport_1;
                                            lcp_arg2        <= #`DEL ram_data_from_mmu; // dac value
                                            ex_state        <= #`DEL EX_STATE_SET_THRSHLD_TDI_1; // 15h
                                        end
                                end
                                
                            EX_STATE_SET_THRSHLD_TDI_1: // 15h
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_THRSHLD_TDI_2; // 16h
                                        end
                                end

                            EX_STATE_RD_THRSHLD_TDI_2: // 16h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            lcp_start       <= #`DEL 1'b1;                                            
                                            lcp_cmd         <= #`DEL lc_set_sp_thrshld_tdi;
                                            lcp_arg1        <= #`DEL lc_scanport_2;
                                            lcp_arg2        <= #`DEL ram_data_from_mmu; // dac value
                                            ex_state        <= #`DEL EX_STATE_SET_THRSHLD_TDI_2; // 17h
                                        end
                                end

                            EX_STATE_SET_THRSHLD_TDI_2: // 17h
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_VLTG_OUT_SP_1; // 18h
                                        end
                                end
                                
                                
                        // READ AND SET SCANPORT OUTPUT VOLTAGES
                            // scanport 1
                            EX_STATE_RD_VLTG_OUT_SP_1: // 18h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            lcp_start       <= #`DEL 1'b1;                                            
                                            lcp_cmd         <= #`DEL lc_set_sp_vltg_out;
                                            lcp_arg1        <= #`DEL lc_scanport_1;
                                            lcp_arg2        <= #`DEL ram_data_from_mmu; // dac value
                                            ex_state        <= #`DEL EX_STATE_SET_VLTG_OUT_SP_1; // 19h
                                        end
                                end
                            
                            EX_STATE_SET_VLTG_OUT_SP_1: // 19h
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_VLTG_OUT_SP_2; // 1Ah
                                        end
                                end
                            
                            // scanport 2
                            EX_STATE_RD_VLTG_OUT_SP_2: // 1Ah
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            lcp_start       <= #`DEL 1'b1;                                            
                                            lcp_cmd         <= #`DEL lc_set_sp_vltg_out;
                                            lcp_arg1        <= #`DEL lc_scanport_2;
                                            lcp_arg2        <= #`DEL ram_data_from_mmu; // dac value
                                            ex_state        <= #`DEL EX_STATE_SET_VLTG_OUT_SP_2; // 1Bh
                                        end
                                end
                            
                            EX_STATE_SET_VLTG_OUT_SP_2: // 1Bh
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_DRV_TMS_TCK_SP_1; // 1Ch
                                        end
                                end
                                                             
                                
                        // READ AND SET DRIVER CHARACTERISTICS
                            // scanport 1
                            EX_STATE_RD_DRV_TMS_TCK_SP_1: // 1Ch
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            lcp_start       <= #`DEL 1'b1;                                            
                                            lcp_cmd         <= #`DEL lc_set_drv_chr_tms_tck;
                                            lcp_arg1        <= #`DEL lc_scanport_1;
                                            lcp_arg2        <= #`DEL ram_data_from_mmu; // driver characteristics
                                            ex_state        <= #`DEL EX_STATE_SET_DRV_TMS_TCK_SP_1; // 1Dh
                                        end
                                end
                            
                            EX_STATE_SET_DRV_TMS_TCK_SP_1: // 1Dh
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_DRV_TRST_TDO_SP_1; // 1Eh
                                        end
                                end
                                                             
                            EX_STATE_RD_DRV_TRST_TDO_SP_1: // 1Eh
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            lcp_start       <= #`DEL 1'b1;                                            
                                            lcp_cmd         <= #`DEL lc_set_drv_chr_trst_tdo;
                                            lcp_arg1        <= #`DEL lc_scanport_1;
                                            lcp_arg2        <= #`DEL ram_data_from_mmu; // driver characteristics
                                            ex_state        <= #`DEL EX_STATE_SET_DRV_TRST_TDO_SP_1; // 1Fh
                                        end
                                end

                            EX_STATE_SET_DRV_TRST_TDO_SP_1: // 1Fh
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_DRV_TMS_TCK_SP_2; // 20h
                                        end
                                end

                            // scanport 2
                            EX_STATE_RD_DRV_TMS_TCK_SP_2: // 20h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            lcp_start       <= #`DEL 1'b1;                                            
                                            lcp_cmd         <= #`DEL lc_set_drv_chr_tms_tck;
                                            lcp_arg1        <= #`DEL lc_scanport_2;
                                            lcp_arg2        <= #`DEL ram_data_from_mmu; // driver characteristics
                                            ex_state        <= #`DEL EX_STATE_SET_DRV_TMS_TCK_SP_2; // 21h
                                        end
                                end
                            
                            EX_STATE_SET_DRV_TMS_TCK_SP_2: // 21h
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_DRV_TRST_TDO_SP_2; // 22h
                                        end
                                end
                                                             
                            EX_STATE_RD_DRV_TRST_TDO_SP_2: // 22h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            lcp_start       <= #`DEL 1'b1;                                            
                                            lcp_cmd         <= #`DEL lc_set_drv_chr_trst_tdo;
                                            lcp_arg1        <= #`DEL lc_scanport_2;
                                            lcp_arg2        <= #`DEL ram_data_from_mmu; // driver characteristics
                                            ex_state        <= #`DEL EX_STATE_SET_DRV_TRST_TDO_SP_2; // 23h
                                        end
                                end

                            EX_STATE_SET_DRV_TRST_TDO_SP_2: // 23h
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_TEST_STP_CT_TOT_1; // 24h
                                        end
                                end


                        // READ TEST STEP COUNT TOTAL
                            EX_STATE_RD_TEST_STP_CT_TOT_1: // 24h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            // save lowbyte of test step count total
                                            test_step_ct_total[`test_step_ct_width-1-`byte_width:0] <= #`DEL ram_data_from_mmu;
                                            
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_TEST_STP_CT_TOT_2; // 25h
                                        end
                                end

                            EX_STATE_RD_TEST_STP_CT_TOT_2: // 25h
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            // save highbyte of test step count total
                                            test_step_ct_total[`test_step_ct_width-1:`byte_width] <= #`DEL ram_data_from_mmu;
                                        
                                            ram_addr_to_mmu     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address for next data fetch
                                            
                                            ram_addr_for_retry  <= #`DEL ram_addr_to_mmu + 1;  // save ram address in case the next step is a retry-sxr
                                            `include "include_save_retry_addr.v"                                            

                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_STEP_ID_BYTE_0; // 26h
                                        end
                                end
                                
                                
                        
                    // SEQUENCE EXECUTION
                        // READ STEP ID                                   
                        
                            // - this step is repeated every time a new step is to be executed
                            
                            // - after execution of a low level command or an sxr, the test_step_ct_current increments
                            // - if test_step_ct_current reaches test_step_ct_total (see state EX_STATE_RD_TEST_STP_CT_TOT_1/2) the test
                            //   is regarded as finished -> transit to EX_STATE_END_OF_TEST
                            
                            // - since the step id is the same for all scanpaths, ram_data_from_mmu can be read (regardless which and how many scanpaths are active)
                            // - from now on, the array of scanpath_address must be incremented on every data fetch (see include_executor_scanpath_addr_inc.v)
                            // - NOTE: step id is read from first active scanpath data block (others ignored)
                            // - NOTE: sxr type is read from first active scanpath data block (others ignored) 
                            EX_STATE_RD_STEP_ID_BYTE_0: // 26h // fetch step id (lowbyte first)
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    
                                    if (test_step_ct_current < test_step_ct_total)
                                        begin                                 
                                            if (data_ready_from_mmu) // wait here until mmu signals data ready
                                                begin
                                                    `include "include_executor_scanpath_addr_inc.v"
                                                    ram_addr_to_mmu                         <= #`DEL ram_addr_to_mmu + 1; // increment ram address for next data fetch
                                                    
                                                    // - backup ram address (points to step id lowbyte)
                                                    // - on end of sxr ram_addr_to_mmu is restored with the backup
                                                    // - this ensures the next sxr (id and type) are read from the right location
                                                    ram_addr_to_mmu_bak                     <= #`DEL ram_addr_to_mmu; 
                                                                                                
                                                    data_request_to_mmu                     <= #`DEL 1'b1; // request new data from mmu
                                                    step_id[`step_id_width-1-`byte_width:0] <= #`DEL ram_data_from_mmu;   // save lowbyte
                                                    ex_state                                <= #`DEL EX_STATE_RD_STEP_ID_BYTE_1; // 27h
                                                end
                                        end
                                    else
                                        begin
                                            `include "include_executor_restart.v"
                                            ex_state    <= #`DEL EX_STATE_END_OF_TEST; // E0h
                                        end
                                end

                            EX_STATE_RD_STEP_ID_BYTE_1: // 27h // fetch step id (highbyte last)
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin                                  
                                            step_id[`step_id_width-1:`byte_width]   <= #`DEL ram_data_from_mmu;   // save highbyte
                                            ex_state                                <= #`DEL EX_STATE_EVAL_STEP_ID; // 28h
                                        end
                                end

                            EX_STATE_EVAL_STEP_ID: // 28h
                                // evaluate step id
                                begin
                                    `include "include_executor_scanpath_addr_inc.v"
                                    ram_addr_to_mmu                 <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                    data_request_to_mmu             <= #`DEL 1'b1; // request new data from mmu
                                
                                    case (step_id)
                                        step_id_low_level_cmd:
                                            begin
//                                                 ram_addr_to_mmu                 <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
//                                                 data_request_to_mmu             <= #`DEL 1'b1; // request new data from mmu
                                                ex_state                        <= #`DEL EX_STATE_RD_LC_BYTE_0; // 29h 
                                            end
                                        default:
                                            begin
                                                ex_state                        <= #`DEL EX_STATE_RD_SXR_TYPE; // 40h
                                            end
                                    endcase
                                end
                                
                            EX_STATE_RD_LC_BYTE_0: // 29h // command header
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            `include "include_executor_scanpath_addr_inc.v"                                        
                                            ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            lcp_cmd                     <= #`DEL ram_data_from_mmu; // fetch lc header
                                            ex_state                    <= #`DEL EX_STATE_RD_LC_BYTE_1; // 2Ah
                                        end
                                end
                            
                            EX_STATE_RD_LC_BYTE_1: // 2Ah // arg1
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            `include "include_executor_scanpath_addr_inc.v"                                        
                                            ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            lcp_arg1                    <= #`DEL ram_data_from_mmu;
                                            ex_state                    <= #`DEL EX_STATE_RD_LC_BYTE_2; // 2Bh
                                        end
                                end

                            EX_STATE_RD_LC_BYTE_2: // 2Bh // arg2
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready -> start lcp
                                        begin
                                            //ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            //data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            lcp_arg2                    <= #`DEL ram_data_from_mmu;
                                            lcp_start                   <= #`DEL 1'b1;
                                            ex_state                    <= #`DEL EX_STATE_EXCT_LC; // 2Ch
                                        end
                                end
                                
                            EX_STATE_EXCT_LC: // 2Ch
                                begin // wait here until lcp signals done
                                    lcp_start                   <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin   // when lcp done, a new step id is to read -> inc. address and request new data
                                                // since this command has been executed successfully, test_step_ct_current increments
                                                // then return to EX_STATE_RD_STEP_ID_BYTE_0                                            
                                            `include "include_executor_scanpath_addr_inc.v" 
                                            test_step_ct_current        <= #`DEL test_step_ct_current + 1;
                                            ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            
                                            ram_addr_for_retry          <= #`DEL ram_addr_to_mmu + 1;  // save ram address in case the next step is a retry-sxr
                                            `include "include_save_retry_addr.v"
                                            
                                            data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            ex_state                    <= #`DEL EX_STATE_RD_STEP_ID_BYTE_0; // 26h 
                                        end
                                        
                                    // if currently running low level command is a tap state operation,
                                    // pass scanpath signals from lcp through to UUT
                                    if (lcp_cmd == lc_tap_state) // CS: OR lc_tap_pulse_tck
                                        begin
                                            // UPDATE SCANPORT OUTPUTS
                                            sp_trst <= #`DEL lcp_sp_trst;
                                            sp_tms  <= #`DEL lcp_sp_tms;
                                            sp_tck  <= #`DEL lcp_sp_tck;
                                            sp_tdo  <= #`DEL lcp_sp_tdo;
       
                                            // UPDATE TAP STATES MONITOR
                                            tap_state[1]    <= #`DEL lcp_tap_state_send[1];
                                            tap_state[2]    <= #`DEL lcp_tap_state_send[2];                                            
                                        end
                                end

                        // SXR EXECUTION
                            EX_STATE_RD_SXR_TYPE: // 40h                                
                                begin
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            //ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            //data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            sxr_type                    <= #`DEL ram_data_from_mmu; // fetch data from ram as addressed by ram_addr_to_mmu
                                            ex_state                    <= #`DEL EX_STATE_EVAL_SXR_TYPE; // 41h
                                        end
                                end
                                
                            EX_STATE_EVAL_SXR_TYPE: // 41h
                                begin
                                    // enable latching length of first active scanpath
                                    latch_byte_ct_lowest_active_scanpath    <= #`DEL 1; 
                                                                
									// 	SXR MARKER (8 bit) --
									// 	bit meaning:
									// 	7 (MSB) : 1 -> sir, 0 -> sdr
									// 	6       : 1 -> end state RTI, 0 -> end state Pause-XR
									// 	5       : 1 -> on fail: hstrst
									// 	4       : 1 -> on fail: power down (priority in executor)
									// 	3       : 1 -> on fail: finish sxr (CS: not implemented yet)
									// 	2       : 1 -> retry on, 0 -> retry off
									// 	1:0     : not used yet

									if (~sxr_type_retry)
                                    // non-retry types
                                        begin
                                            ex_state                                <= #`DEL EX_STATE_RD_SXR_SP_ID_1; // 43h
                                        end
                                    else
                                    // retry types
                                        begin
                                            `include "include_executor_scanpath_addr_inc.v"
                                            ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address
                                            data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu
                                            ex_state                    <= #`DEL EX_STATE_RD_RETRY; // 13h
                                        end
                                end
                                
							EX_STATE_RD_RETRY: // 13h
								begin
									data_request_to_mmu         <= #`DEL 1'b0; // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
										begin
                                            `include "include_executor_scanpath_addr_inc.v"
                                            ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address for next data fetch
                                            data_request_to_mmu         <= #`DEL 1'b1; // request new data from location ram_addr_to_mmu
                                            retry_count_max             <= #`DEL ram_data_from_mmu;
											ex_state                    <= #`DEL EX_STATE_RD_DELAY; // 42h
										end
								end                            

                            EX_STATE_RD_DELAY: // 42h
                                begin
									data_request_to_mmu         <= #`DEL 1'b0; // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
										begin
                                            //ram_addr_to_mmu             <= #`DEL ram_addr_to_mmu + 1;  // increment ram address for next data fetch
                                            //data_request_to_mmu         <= #`DEL 1'b1; // request new data from location ram_addr_to_mmu
                                            delay_before_retry          <= #`DEL ram_data_from_mmu;
											ex_state                    <= #`DEL EX_STATE_RD_SXR_SP_ID_1; // 43h
										end                                
                                end
                                
                                
                                
                                
                                // - from now on, scanpath data must be fetched for every scanpath individually.
                                // - direct ram addressing by ram_addr_to_mmu ends here
                                // - scanpath_address[scanpath_pointer] is used to address the ram 
                    
                            EX_STATE_RD_SXR_SP_ID_1: // 43h
                                // - this is a loop that reads for all active scanpaths: scanpath id, length (32bit)
                                // - after that, reading drive, mask and expect byte triplets follows
                                begin
                                    if (scanpath_pointer < scanpath_count_max) 
                                    // loop here for every available scanpath (regardless if active or not)
                                        begin
                                            scanpath_pointer    <= #`DEL scanpath_pointer + 1; // advance scanpath_pointer (zero based !)
                                            // if scanpath is active (the corresponding bit is set in active_scanpaths)
                                            if (active_scanpaths[scanpath_pointer] == 1)
                                                begin
                                                    scanpath_address[scanpath_pointer+1]    <= #`DEL scanpath_address[scanpath_pointer+1] + 1; // increment scanpath addresses for next data fetch
                                                    //ram_addr_to_mmu                     <= #`DEL ram_addr_to_mmu + 1;  // increment ram address for next data fetch
                                                    ex_state                                <= #`DEL EX_STATE_RD_SXR_SP_ID_2; // 44h
                                                end
                                        end
                                    else
                                        begin
                                            scanpath_pointer    <= #`DEL `scanpath_pointer_width'h0; // reset scanpath_pointer
                                            ex_state            <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_1; // 51h
                                        end
                                end
                                
                            EX_STATE_RD_SXR_SP_ID_2: // 44h
                                begin // set address to fetch sxr_scanpath_id from
                                    data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu (from location scanpath_address[scanpath_pointer])
                                    ram_addr_to_mmu             <= #`DEL scanpath_address[scanpath_pointer];
                                    ex_state                    <= #`DEL EX_STATE_RD_SXR_SP_ID_3; // 45h 
                                end
                                
                            EX_STATE_RD_SXR_SP_ID_3: // 45h
                                begin // read sxr_scanpath_id
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            sxr_scanpath_id     <= #`DEL ram_data_from_mmu;
                                            ex_state            <= #`DEL EX_STATE_RD_SXR_SP_ID_4; // 46h 
                                        end
                                end
                                
                            EX_STATE_RD_SXR_SP_ID_4: // 46h
                                begin // evaluate sxr_scanpath_id // scanpath id found in data block must match scanpath_pointer
                                    if (sxr_scanpath_id == scanpath_pointer)
                                        begin
                                            scanpath_address[scanpath_pointer]  <= #`DEL scanpath_address[scanpath_pointer] + 1; // increment scanpath addresses for next data fetch
                                            ex_state                            <= #`DEL EX_STATE_RD_SXR_LENGTH_1; // 48h 
                                        end
                                    else // if scanpath id is invalid -> shutdown
                                        begin
                                            //`include "include_executor_reset.v"
											// start lcp to power down the uut
                                            `include "include_executor_shutdown.v"                                                                                  
                                            ex_state                            <= #`DEL EX_STATE_ERROR_RD_SXR_SP_ID_1; // 47h 
                                        end
                                end
                                
							EX_STATE_ERROR_RD_SXR_SP_ID_1: // 47h
								begin
									lcp_start       <= #`DEL 1'b0; // clear low level command start signal
									if (lcp_done) // wait until lcp is ready
										begin
                                            `include "include_executor_restart.v"
											ex_state                    <= #`DEL EX_STATE_ERROR_RD_SXR_SP_ID_2; // 5Eh
										end
								end
                                
                    
                            EX_STATE_RD_SXR_LENGTH_1: // 48h 
                                begin // set address to fetch sxr length byte 0 from
                                    data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu (from location scanpath_address[scanpath_pointer])
                                    ram_addr_to_mmu             <= #`DEL scanpath_address[scanpath_pointer];
                                    ex_state                    <= #`DEL EX_STATE_RD_SXR_LENGTH_2; // 49h 
                                end
                            EX_STATE_RD_SXR_LENGTH_2: // 49h
                                begin // read length byte 0 (lowbyte)
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            sxr_length[scanpath_pointer][`chain_length_width-1-3*`byte_width:0*`byte_width] <= #`DEL ram_data_from_mmu; // [7:0]
                                            scanpath_address[scanpath_pointer]  <= #`DEL scanpath_address[scanpath_pointer] + 1; // increment scanpath addresses for next data fetch
                                            ex_state                            <= #`DEL EX_STATE_RD_SXR_LENGTH_3; // 4Ah 
                                        end
                                end

                            EX_STATE_RD_SXR_LENGTH_3: // 4Ah 
                                begin // set address to fetch sxr length byte 1 from
                                    data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu (from location scanpath_address[scanpath_pointer])
                                    ram_addr_to_mmu             <= #`DEL scanpath_address[scanpath_pointer];
                                    ex_state                    <= #`DEL EX_STATE_RD_SXR_LENGTH_4; // 4Bh 
                                end
                            EX_STATE_RD_SXR_LENGTH_4: // 4Bh
                                begin // read length byte 1
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            sxr_length[scanpath_pointer][`chain_length_width-1-2*`byte_width:1*`byte_width] <= #`DEL ram_data_from_mmu; // [15:8]
                                            scanpath_address[scanpath_pointer]  <= #`DEL scanpath_address[scanpath_pointer] + 1; // increment scanpath addresses for next data fetch
                                            ex_state                            <= #`DEL EX_STATE_RD_SXR_LENGTH_5; // 4Ch 
                                        end
                                end

                            EX_STATE_RD_SXR_LENGTH_5: // 4Ch 
                                begin // set address to fetch sxr length byte 2 from
                                    data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu (from location scanpath_address[scanpath_pointer])
                                    ram_addr_to_mmu             <= #`DEL scanpath_address[scanpath_pointer];
                                    ex_state                    <= #`DEL EX_STATE_RD_SXR_LENGTH_6; // 4Dh 
                                end
                            EX_STATE_RD_SXR_LENGTH_6: // 4Dh
                                begin // read length byte 2
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            sxr_length[scanpath_pointer][`chain_length_width-1-1*`byte_width:2*`byte_width] <= #`DEL ram_data_from_mmu; // [23:16]
                                            scanpath_address[scanpath_pointer]  <= #`DEL scanpath_address[scanpath_pointer] + 1; // increment scanpath addresses for next data fetch
                                            ex_state                            <= #`DEL EX_STATE_RD_SXR_LENGTH_7; // 4Eh 
                                        end
                                end

                            EX_STATE_RD_SXR_LENGTH_7: // 4Eh 
                                begin // set address to fetch sxr length byte 3 (highbyte) from
                                    data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu (from location scanpath_address[scanpath_pointer])
                                    ram_addr_to_mmu             <= #`DEL scanpath_address[scanpath_pointer];
                                    ex_state                    <= #`DEL EX_STATE_RD_SXR_LENGTH_8; // 4Fh 
                                end
                            EX_STATE_RD_SXR_LENGTH_8: // 4Fh
                                begin // read length byte 3 (highbyte)
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            sxr_length[scanpath_pointer][`chain_length_width-1-0*`byte_width:3*`byte_width] <= #`DEL ram_data_from_mmu; // [31:24]
                                            //scanpath_address[scanpath_pointer]  <= #`DEL scanpath_address[scanpath_pointer] + 1; // increment scanpath addresses for next data fetch
                                            ex_state                            <= #`DEL EX_STATE_RD_SXR_LENGTH_9; // 50h
                                        end
                                end

                            EX_STATE_RD_SXR_LENGTH_9: // 50h
                                begin // calculate byte count from sxr length (by dividing by 8, which is a right shift by 3 bits)
                                    // if remainder left, byte count is to be incremented by one
                                    // later when reading drive, mask and expect triplets, sxr_byte_count is the spacing between drive, mask and expect sectors
                                    if (sxr_length[scanpath_pointer][2:0] == 0) // if there will be a remainder after division (bits 2:0 greater zero)
                                        begin // take bits 31:3. sxr_length is a multiple of 8
                                            sxr_byte_count_total[scanpath_pointer]  <= #`DEL sxr_length[scanpath_pointer][`chain_length_width-1:3];
                                        end
                                    else
                                        begin // take bits 31:3 and add 1. sxr_length is not a multiple of 8
                                            sxr_byte_count_total[scanpath_pointer]  <= #`DEL sxr_length[scanpath_pointer][`chain_length_width-1:3] + 1;
                                        end                                       
                                    //ex_state    <= #`DEL EX_STATE_RD_SXR_SP_ID_1; // 43h
                                    ex_state    <= #`DEL EX_STATE_RD_SXR_LENGTH_10; // 5Dh
                                end

                            EX_STATE_RD_SXR_LENGTH_10: // 5Dh
                                begin
                                    // - After calculating the byte count of the first active scanpath, ram_addr_to_mmu_bak must 
                                    // advance by:
                                    //  - Eight (2 byte step_id, sxr_type, scanpath id, 4 byte length) + 3*sxr_byte_count_total.
                                    //  - If non-retry sxr.
                                    //
                                    //  - Ten (2 byte step_id, sxr_type, retry_count_max, delay_before_retry, scanpath id, 4 byte length) + 3*sxr_byte_count_total.
                                    //  - If retry sxr.
                                    //
                                    // - ram_addr_to_mmu_bak afterwards points to step id of next sxr (of first active scanpath).
                                    // - This action is done only once per sxr.
                                    // - Once the sxr is finished (see state EX_STATE_WAIT_STEP_SXR: // 5Ch), ram_addr_to_mmu is restored
                                    //   from ram_addr_to_mmu_bak.
                                    
                                    if (latch_byte_ct_lowest_active_scanpath)
                                        begin
                                            if (~sxr_type_retry)
                                                begin
                                                    // advance ram_addr_to_mmu_bak
                                                    ram_addr_to_mmu_bak <= #`DEL ram_addr_to_mmu_bak + 8 + 3*(sxr_byte_count_total[scanpath_pointer]);
                                                end
                                            else
                                                begin
                                                    // advance ram_addr_to_mmu_bak
                                                    ram_addr_to_mmu_bak <= #`DEL ram_addr_to_mmu_bak + 10 + 3*(sxr_byte_count_total[scanpath_pointer]);
                                                end                                        
                                        end
                                        
                                    // disable latching length of first active scanpath
                                    latch_byte_ct_lowest_active_scanpath    <= #`DEL 0;
                                        
                                    ex_state    <= #`DEL EX_STATE_RD_SXR_SP_ID_1; // 43h
                                end
                                

                        // READ AND PROCESS DRIVE, MASK AND EXPECT TRIPLETS 
                            // - a triplet consists of three bytes DRIVE, MASK, EXPECT
                            // - they must be processed simultaneously: DRIVE sent to UUT, pattern read from UUT to compared with EXPECT and MASK 
                            EX_STATE_RD_SXR_DRV_MSK_EXP_1: // 51h
                                // - this is a loop that reads for all active scanpaths: drive, mask and expect byte triplets
                                begin
                                    if (scanpath_pointer < scanpath_count_max) 
                                    // scanpath_pointer is zero based
                                    // scanpath_pointer is zero initially
                                    
                                    // loop here for every available scanpath (regardless if active or not)
                                        begin
                                            scanpath_pointer    <= #`DEL scanpath_pointer + 1; // advance scanpath_pointer (zero based !)
                                            // if scanpath is active (the corresponding bit is set in active_scanpaths)
                                            if (active_scanpaths[scanpath_pointer] == 1)
                                                begin                                                    
                                                    ex_state                                <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_2; // 52h
                                                end
                                        end
                                    else
                                        begin // all triplets from all scanpaths ready for shifting
                                            scanpath_pointer    <= #`DEL `scanpath_pointer_width'h0; // reset scanpath_pointer
                                            shifter_start       <= #`DEL 1'b1;
                                            ex_state            <= #`DEL EX_STATE_SHIFT_DRV_MSK_EXP_1; // 5Ah
                                        end
                                end
                                
                            EX_STATE_RD_SXR_DRV_MSK_EXP_2: // 52h
                                begin
                                                                       
                                    // - if there are triplets left, read next triplet from ram, otherwise return to EX_STATE_RD_SXR_DRV_MSK_EXP_1; // 51h
                                    //   to advance to next active scanpath
                                    // - scanpath_address advances only if triplets are left
                                    
                                    // - initially sxr_byte_count_current is zero
                                    // - after reading the mask byte, sxr_byte_count_current increments by one (see EX_STATE_RD_SXR_DRV_MSK_EXP_7)
                                    if (sxr_zero_byte_count[scanpath_pointer] == 1)
                                        begin
                                            ex_state                                <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_1; // 51h
                                        end
                                    else
                                        begin
                                            // increment scanpath addresses for next data fetch
                                            scanpath_address[scanpath_pointer]      <= #`DEL scanpath_address[scanpath_pointer] + 1;                                        
                                            ex_state                                <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_3; // 53h
                                        end
                                end

                            // DRIVE
                            EX_STATE_RD_SXR_DRV_MSK_EXP_3: // 53h
                                begin // set address to fetch DRIVE byte from (scanpath_address points to drive sector location)
                                    data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu (from location scanpath_address[scanpath_pointer])
                                    ram_addr_to_mmu             <= #`DEL scanpath_address[scanpath_pointer];
                                    ex_state                    <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_4; // 54h 
                                end                                
                            EX_STATE_RD_SXR_DRV_MSK_EXP_4: // 54h
                                begin // read DRIVE byte
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            sxr_drv[scanpath_pointer]               <= #`DEL ram_data_from_mmu;
                                            ex_state                                <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_5; // 55h 
                                        end
                                end
                                
                            // MASK
                            EX_STATE_RD_SXR_DRV_MSK_EXP_5: // 55h
                                begin // set address to fetch MASK byte from (the mask sector location is sxr_byte_count ahead of current scanpath_address)
                                    data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu (from location scanpath_address[scanpath_pointer])
                                    ram_addr_to_mmu             <= #`DEL scanpath_address[scanpath_pointer] + sxr_byte_count_total[scanpath_pointer];
                                    ex_state                    <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_6; // 56h 
                                end                                
                            EX_STATE_RD_SXR_DRV_MSK_EXP_6: // 56h
                                begin // read MASK byte
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin
                                            sxr_msk[scanpath_pointer]               <= #`DEL ram_data_from_mmu;
                                            ex_state                                <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_7; // 57h 
                                        end
                                end

                            // EXPECT
                            // NOTE: after fetching the expect-byte, increment triplet counter. in the next step, set sxr_zero_byte_count if this is the last triplet
                            EX_STATE_RD_SXR_DRV_MSK_EXP_7: // 57h
                                begin // set address to fetch EXPECT byte from (the expect sector location is 2*sxr_byte_count ahead of current scanpath_address)
                                    data_request_to_mmu         <= #`DEL 1'b1; // request new data from mmu (from location scanpath_address[scanpath_pointer])
                                    ram_addr_to_mmu             <= #`DEL scanpath_address[scanpath_pointer] + 2*sxr_byte_count_total[scanpath_pointer];
                                    ex_state                    <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_8; // 58h 
                                end                                
                            EX_STATE_RD_SXR_DRV_MSK_EXP_8: // 58h
                                begin // read EXPECT byte
                                    data_request_to_mmu         <= #`DEL 1'b0;  // clear data request
                                    if (data_ready_from_mmu) // wait here until mmu signals data ready
                                        begin                                        
                                            // in case this is the last triplet, ram_addr_to_mmu is used to update scanpath_address
                                            // so that scanpath_address points to step_id of next sxr
                                            ram_addr_to_mmu                             <= #`DEL ram_addr_to_mmu + 1;
                                            
                                            sxr_exp[scanpath_pointer]                   <= #`DEL ram_data_from_mmu;
                                            // count triplets read from ram
                                            sxr_byte_count_current[scanpath_pointer]    <= #`DEL sxr_byte_count_current[scanpath_pointer] + 1;
                                            ex_state                                    <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_9; // 59h
                                        end
                                end
                            EX_STATE_RD_SXR_DRV_MSK_EXP_9: // 59h
                                begin   // if this is the last triplet, set sxr_zero_byte_count
                                        // this ensures, that the scanpath_address is not further incremented
                                    if (sxr_byte_count_current[scanpath_pointer] == sxr_byte_count_total[scanpath_pointer])
                                        begin
                                            sxr_zero_byte_count[scanpath_pointer]   <= #`DEL 1'b1;
                                            
                                            // update scanpath_address with ram_addr_to_mmu (see comment in step before)
                                            scanpath_address[scanpath_pointer]      <= #`DEL ram_addr_to_mmu;
                                        end
                                    
                                    ex_state    <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_1; // 51h                 
                                end
                                
                                
                            EX_STATE_SHIFT_DRV_MSK_EXP_1: // 5Ah
                                begin // shift triplets
                                    // - shifters decide on bits_processed if and how to react on shifter_start signal
                                    // - btw: scanpath_pointer is cleared to zero 
                                    // - wait here until all shifters are done, then transit to EX_STATE_WAIT_STEP_SXR (5Ch)
                                    
                                    // - if step width sxr or test requested by command decoder,
                                    //   clear flag step_mode_tck so that shifters do not halt
                                    //   any more on every tck transition
                                    
                                    shifter_start     <= #`DEL 1'b0; // clear shifter start signal

                                    `include "include_executor_update_scanport.v"

                                    // First check if breakpoint at a certain bit position is set. If any scanchain reaches the targeted bit position,
                                    // enable step mode tck. Step mode tck remains active as long as bits_processed[x] matches breakpoint_bit_position.
                                    // Match persists from posedge of TCK to next posedge of TCK.
                                    // If no breakpoint set, resume operation.
                                    if (
                                        (step_id == breakpoint_sxr_id) &&
                                        (breakpoint_bit_position != 0) &&
                                        ((bits_processed[1] == breakpoint_bit_position) || (bits_processed[2] == breakpoint_bit_position))
                                        )
                                        begin
                                            step_mode_tck      <= #`DEL 1'b1;   // enable step mode tck

                                            // END OF SXR DETECTION
                                            // if any shifter is done with sxr execution (all other active shifters are done at the same instant)
                                            if (shifter_done != 0)
                                                begin
                                                    sxr_zero_byte_count[1]      <= #`DEL 0;
                                                    sxr_zero_byte_count[2]      <= #`DEL 0;                                            
                                                    sxr_byte_count_current[1]   <= #`DEL 0;
                                                    sxr_byte_count_current[2]   <= #`DEL 0; // add further scanpaths here
                                                    ex_state                    <= #`DEL EX_STATE_WAIT_STEP_SXR; // 5Ch
                                                end
                                            else
                                                begin
                                                    // if any shifter request more data, backup shifter requests to be evaluated in next state
                                                    if (shifter_data_request != 0)
                                                        begin
                                                            shifter_data_request_cache  <= #`DEL shifter_data_request;
                                                            ex_state                    <= #`DEL EX_STATE_SHIFT_DRV_MSK_EXP_2; // 5Bh
                                                        end
                                                end                                     
                                        end
                                        
                                    else 
                                        begin
                                        // no breakpoint set                                    
                                            // END OF SXR DETECTION
                                            // if any shifter is done with sxr execution (all other active shifters are done at the same instant)
                                            if (shifter_done != 0)
                                                begin
                                                    sxr_zero_byte_count[1]      <= #`DEL 0;
                                                    sxr_zero_byte_count[2]      <= #`DEL 0;                                            
                                                    sxr_byte_count_current[1]   <= #`DEL 0;
                                                    sxr_byte_count_current[2]   <= #`DEL 0; // add further scanpaths here
                                                    ex_state                    <= #`DEL EX_STATE_WAIT_STEP_SXR; // 5Ch
                                                end
                                            else
                                                begin
                                                    // if any shifter request more data, backup shifter requests to be evaluated in next state
                                                    if (shifter_data_request != 0)
                                                        begin
                                                            shifter_data_request_cache  <= #`DEL shifter_data_request;
                                                            ex_state                    <= #`DEL EX_STATE_SHIFT_DRV_MSK_EXP_2; // 5Bh
                                                        end
                                                end
                                                
                                            // disable step mode tck when step mode test or sxr requested
                                            if (go_step_test || go_step_sxr)
                                                begin
                                                    step_mode_tck      <= #`DEL 1'b0;
                                                end
                                                
                                            // While waiting here for the shifters (in tck step mode), a step sxr command
                                            // must set the step_mode_sxr flag. 
                                            // The shifters will resume operation and step mode sxr becomes active.
                                            if (go_step_sxr)
                                                begin
                                                    step_mode_sxr      <= #`DEL 1'b1;
                                                end
                                                
                                        end
                                end
                            

                            EX_STATE_SHIFT_DRV_MSK_EXP_2: // 5Bh
                                begin   // wait for other shifters until they have reached pause-xr (shifter_busy goes 0)
                                        // then fetch next triplet (state EX_STATE_RD_SXR_DRV_MSK_EXP_1)
                                        
                                    `include "include_executor_update_scanport.v"                                        

                                    // CS: do something more professional here
                                    case (shifter_data_request_cache)
                                        2'b01   :
                                                    if (shifter_busy[2] == 0)
                                                        begin
                                                            ex_state        <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_1; // 51h
                                                        end
                                        2'b10   :
                                                    if (shifter_busy[1] == 0)
                                                        begin
                                                            ex_state        <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_1; // 51h
                                                        end
                                        2'b11   :
                                                    
                                                        begin
                                                            ex_state        <= #`DEL EX_STATE_RD_SXR_DRV_MSK_EXP_1; // 51h
                                                        end
                                    endcase
                                end
                                
                                
                            EX_STATE_WAIT_STEP_SXR: // 5Ch
                                // - if step_mode_sxr is set (set on test start or in EX_STATE_SHIFT_DRV_MSK_EXP_1), 
                                //   wait for any go_step signal or for start_from_panel to proceed
                                //   NOTE: - ram_addr_to_mmu points to location of last triplet
                                //         - step id holds id of step just processed
                                
                                // - if go_step_sxr received, just start step execution
                                // - if go_step_test received, clear step_mode_sxr and start step execution. 
                                // - in case step mode sxr was active, this disables 
                                //   step mode sxr so that the test is finished without further halts

                                // - however, since this sxr has been executed successfully, test_step_ct_current increments
                                //   before returning to EX_STATE_RD_STEP_ID_BYTE_0
                                
                                // - EX_STATE_EVAL_RETRY_0 is assumed after leaving this state in order to check retry status (if set).                                
                                
                                begin
                                    // First check if breakpoint sxr has been reached and executed.
                                    // This check is relevant only, if no breakpoint for any bit position was specified.
                                    // In this case the operator has a breakpoint set with just an sxr id.
                                    if ((step_id == breakpoint_sxr_id) && (breakpoint_bit_position == 0))
                                        begin
                                            // From here, any step/start signal causes the execution to resume.
                                            if (go_step_test || go_step_sxr || go_step_tck || start_from_panel)
                                                begin
                                                    // if sxr step not requested, disable sxr step mode
                                                    if (go_step_test || go_step_tck)
                                                        begin
                                                            step_mode_sxr      <= #`DEL 1'b0;
                                                        end
                                                        
                                                    // if tck step requested, enable tck step mode
                                                    if (go_step_tck)
                                                        begin
                                                            step_mode_tck      <= #`DEL 1'b1;
                                                        end                                                        
                                                        
                                                    //test_step_ct_current   <= #`DEL test_step_ct_current + 1;
                                                    
//                                                     // ram_addr_to_mmu must be restored
//                                                     ram_addr_to_mmu        <= #`DEL ram_addr_to_mmu_bak;
                                                    // now ram_addr_to_mmu points to address of next step
                                                    
                                                    //data_request_to_mmu    <= #`DEL 1'b1; // request new data from mmu
                                                    //ex_state               <= #`DEL EX_STATE_RD_STEP_ID_BYTE_0; // 26h
                                                    ex_state               <= #`DEL EX_STATE_EVAL_RETRY_0; // 2Fh 
                                                end                                        
                                        end
                                    else
                                    // - breakpoint not reached
                                    // - if step mode sxr set, wait for step signal. otherwise proceed with next sxr
                                        begin
                                            if (step_mode_sxr)
                                                begin
                                                    if (go_step_test || go_step_sxr || go_step_tck || start_from_panel)
                                                        begin
                                                            // if sxr step not requested, disable sxr step mode
                                                            if (go_step_test || go_step_tck)
                                                                begin
                                                                    step_mode_sxr      <= #`DEL 1'b0;
                                                                end
                                                                
                                                            // if tck step requested, enable tck step mode
                                                            if (go_step_tck)
                                                                begin
                                                                    step_mode_tck      <= #`DEL 1'b1;
                                                                end                                                        
                                                                
                                                            //test_step_ct_current   <= #`DEL test_step_ct_current + 1;
                                                            
//                                                             // ram_addr_to_mmu must be restored
//                                                             ram_addr_to_mmu        <= #`DEL ram_addr_to_mmu_bak;
                                                            // now ram_addr_to_mmu points to address of next step
                                                            
                                                            //data_request_to_mmu    <= #`DEL 1'b1; // request new data from mmu
                                                            //ex_state               <= #`DEL EX_STATE_RD_STEP_ID_BYTE_0; // 26h 
                                                            ex_state               <= #`DEL EX_STATE_EVAL_RETRY_0; // 2Fh 
                                                        end
                                                end
                                            else
                                            // proceed with next sxr
                                                begin 
                                                    //test_step_ct_current   <= #`DEL test_step_ct_current + 1;
                                                
                                                    // ram_addr_to_mmu must be restored 
                                                    //ram_addr_to_mmu        <= #`DEL ram_addr_to_mmu_bak;
                                                    // now ram_addr_to_mmu points to address of next step
                                                                                                        
                                                    //data_request_to_mmu    <= #`DEL 1'b1; // request new data from mmu
                                                    //ex_state               <= #`DEL EX_STATE_RD_STEP_ID_BYTE_0; // 26h 
                                                    ex_state               <= #`DEL EX_STATE_EVAL_RETRY_0; // 2Fh 
                                                end
                                        end                                                
                                end
                           
                           
                            EX_STATE_EVAL_RETRY_0: // 2Fh 
                                begin
                                    if (sxr_type_retry)
                                        begin
                                            if (retry_sxr_failed)
                                                begin
                                                    retry_sxr_failed    <= #`DEL 0; // acknowledge failed sxr by clearing this flag
                                                    
                                                    if (retry_count < retry_count_max)
                                                        begin
                                                            retry_count <= #`DEL retry_count + 1;
                                                            
                                                            // start timer
                                                            lcp_start   <= #`DEL 1'b1;                                            
                                                            lcp_cmd     <= #`DEL lc_delay;
                                                            lcp_arg1    <= #`DEL delay_before_retry;
                                                            lcp_arg2    <= #`DEL lc_delay_arg2;

                                                            ex_state    <= #`DEL EX_STATE_RETRY_DELAY_1; // 30h 
                                                        end
                                                    else // Retry count exceeded -> test failed.
                                                        // Restore fail register sp_fail from sp_fail_retry (see include_executor_update_scanport.v)
                                                        // Set bp_retry_send to route bits_processed_retry to (CPU) register file. This enables locating 
                                                        // the failed pin later.
                                                        begin
                                                            ex_state        <= #`DEL EX_STATE_TEST_FAIL_1; // E1h
                                                            sp_fail         <= #`DEL sp_fail_retry;
                                                            bp_retry_send   <= #`DEL 1'b1;
                                                        end
                                                end
                                            else // retry-sxr without any fail -> proceed with next step
                                                begin
                                                    test_step_ct_current   <= #`DEL test_step_ct_current + 1;

                                                    // ram_addr_to_mmu must be restored
                                                    ram_addr_to_mmu        <= #`DEL ram_addr_to_mmu_bak;

                                                    // Save address of next step in case it is a retry-sxr.
                                                    // ram_addr_to_mmu_bak points to next step.
                                                    ram_addr_for_retry     <= #`DEL ram_addr_to_mmu_bak;
                                                    `include "include_save_retry_addr.v"  // save scanpath addresses
                                                    
                                                    data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                                    ex_state            <= #`DEL EX_STATE_RD_STEP_ID_BYTE_0; // 26h 
                                                end
                                                
                                        end
                                    else // non-retry sxr -> processed with next step
                                        begin
                                            test_step_ct_current   <= #`DEL test_step_ct_current + 1;
                                            
                                            // ram_addr_to_mmu must be restored
                                            ram_addr_to_mmu        <= #`DEL ram_addr_to_mmu_bak;
                                                                                        
                                            // Save address of next step in case it is a retry-sxr.
                                            // ram_addr_to_mmu_bak points to next step.
                                            ram_addr_for_retry     <= #`DEL ram_addr_to_mmu_bak;                                            
                                            `include "include_save_retry_addr.v" // save scanpath addresses
                                            
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_STEP_ID_BYTE_0; // 26h 
                                        end
                                end
                                
                            EX_STATE_RETRY_DELAY_1: // 30h
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            // Restore address so that sxr is executed again.
                                            ram_addr_to_mmu     <= #`DEL ram_addr_for_retry;  
                                            `include "include_load_retry_addr.v" // restore scanpath addresses
                                            
                                            data_request_to_mmu <= #`DEL 1'b1; // request new data from mmu
                                            ex_state            <= #`DEL EX_STATE_RD_STEP_ID_BYTE_0; // 26h 
                                        end                                    
                                end
                            
                            
                                
                        // TEST FAIL HANDLING
                            EX_STATE_TEST_FAIL_1: // E1h
                                begin
                                    if (sxr_type_on_fail_pwr_down)
                                        begin // disconnect scanport 1
                                            lcp_start       <= #`DEL 1'b1;
                                            lcp_cmd         <= #`DEL lc_connect_disconnect;
                                            lcp_arg1        <= #`DEL lc_scanport_1;
                                            lcp_arg2        <= #`DEL lc_off;
                                            ex_state        <= #`DEL EX_STATE_TEST_FAIL_4; // EAh
                                        end
                                    else if (sxr_type_on_fail_hstrst)
                                        begin 
                                            lcp_start       <= #`DEL 1'b1;
                                            lcp_cmd         <= #`DEL lc_tap_state;
                                            lcp_arg1        <= #`DEL lc_tap_trst;                                            
                                            lcp_arg2        <= #`DEL `byte_width'h00; // not required, fixed to zero
                                            ex_state        <= #`DEL EX_STATE_TEST_FAIL_2; // E2h
                                        end
                                    else // CS: finish sxr ?
                                        begin
                                            `include "include_executor_shutdown.v"
                                            ex_state        <= #`DEL EX_STATE_TEST_FAIL_2; // E2h
                                        end
                                end

                            EX_STATE_TEST_FAIL_2: // E2h
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            `include "include_executor_restart.v"
                                            ex_state            <= #`DEL EX_STATE_TEST_FAIL_3; // E3h;
                                        end

                                    // UPDATE SCANPORT OUTPUTS
                                    sp_trst <= #`DEL lcp_sp_trst;
                                    sp_tms  <= #`DEL lcp_sp_tms;
                                    sp_tck  <= #`DEL lcp_sp_tck;
                                    sp_tdo  <= #`DEL lcp_sp_tdo;

                                    // UPDATE TAP STATES MONITOR
                                    tap_state[1]    <= #`DEL lcp_tap_state_send[1];
                                    tap_state[2]    <= #`DEL lcp_tap_state_send[2];
                                end
                                
                            EX_STATE_TEST_FAIL_4: // EAh
                                begin // disconnect scanport 2
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                        if (lcp_done)
                                            begin
                                                lcp_start       <= #`DEL 1'b1;
                                                lcp_cmd         <= #`DEL lc_connect_disconnect;
                                                lcp_arg1        <= #`DEL lc_scanport_2;
                                                lcp_arg2        <= #`DEL lc_off;
                                                ex_state        <= #`DEL EX_STATE_TEST_FAIL_5; // EBh
                                            end
                                end

                            EX_STATE_TEST_FAIL_5: // EBh
                                begin // power down
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                        if (lcp_done)
                                            begin
                                                `include "include_executor_shutdown.v"                                            
                                                ex_state        <= #`DEL EX_STATE_TEST_FAIL_2; // E2h
                                            end
                                end
                                
                            
                            
                            
                                 
                        // TEST ABORTING //////////////////////////////
                            EX_STATE_TEST_ABORT_1: // E4h
                                begin
                                    lcp_abort       <= #`DEL 1'b0; // deassert lcp abort signal
                                    ex_state        <= #`DEL EX_STATE_TEST_ABORT_5; // E8h
                                end

                            // CS: Once "disconnect all" command available, use it here instead of disconnecting
                            // scanports sequentially.
                            EX_STATE_TEST_ABORT_5: // E8h
                                begin // disconnect scanport 1
                                    lcp_start       <= #`DEL 1'b1;
                                    lcp_cmd         <= #`DEL lc_connect_disconnect;
                                    lcp_arg1        <= #`DEL lc_scanport_1;
                                    lcp_arg2        <= #`DEL lc_off;
                                    ex_state        <= #`DEL EX_STATE_TEST_ABORT_6; // E9h
                                end

                            EX_STATE_TEST_ABORT_6: // E9h
                                begin // disconnect scanport 2
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                        if (lcp_done)
                                            begin
                                                lcp_start       <= #`DEL 1'b1;
                                                lcp_cmd         <= #`DEL lc_connect_disconnect;
                                                lcp_arg1        <= #`DEL lc_scanport_2;
                                                lcp_arg2        <= #`DEL lc_off;
                                                ex_state        <= #`DEL EX_STATE_TEST_ABORT_2; // E5h
                                            end
                                end
                                
                            EX_STATE_TEST_ABORT_2: // E5h
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            `include "include_executor_shutdown.v"
                                             ex_state        <= #`DEL EX_STATE_TEST_ABORT_3; // E6h
                                        end
                                end
                                
                            EX_STATE_TEST_ABORT_3: // E6h                                
                                begin
                                    lcp_start       <= #`DEL 1'b0; // clear low level command start signal
                                    if (lcp_done)
                                        begin
                                            `include "include_executor_restart.v"
                                            ex_state        <= #`DEL EX_STATE_TEST_ABORT_4; // E7h
                                        end
                                        
                                    // UPDATE SCANPORT OUTPUTS
                                    sp_trst <= #`DEL lcp_sp_trst;
                                    sp_tms  <= #`DEL lcp_sp_tms;
                                    sp_tck  <= #`DEL lcp_sp_tck;
                                    sp_tdo  <= #`DEL lcp_sp_tdo;

                                    // UPDATE TAP STATES MONITOR
                                    tap_state[1]    <= #`DEL lcp_tap_state_send[1];
                                    tap_state[2]    <= #`DEL lcp_tap_state_send[2];                                            
                                end
                                 
                            // CS: default ?
                                

                        endcase
                    end
            end
        end
        
        
endmodule
