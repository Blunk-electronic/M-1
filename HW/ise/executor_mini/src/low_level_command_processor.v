module low_level_command_processor(
    clk, // input
    reset_n, // input, asynchronous
    reset, // input, syncronous
    start, // input
    done, // output
    command, // input
    arg1,   // input
    arg2,   // input
    
    sda, // inout
    scl,  // inout
    
    sp_trst, // output
    sp_tms, // output
    sp_tck, // output
    sp_tdo, // output    
    
    //clk_scan, // output
    lcp_state, // output, read by rf
    i2c_master_state, // output, read by rf
    timer_state, // output
    
    scan_clock_frequency, // output
    tap_states_feedback, // all tap states ! , input, holds tap state read from tap state monitor (in executor module)
    tap_states_send // all tap states !, output,  sends tap state to tap state monitor (in executor module)
    );
    
    `include "parameters_global.v"    
    
    input clk;
    input reset_n;
    input reset;  // propagates into all submodules
    input start;
    output reg done;
    input [`byte_width-1:0] command;
    input [`byte_width-1:0] arg1; // lowbyte
    input [`byte_width-1:0] arg2; // highbyte
    
    inout sda;
    inout scl;
    
    output reg [`scanpath_count_max:1] sp_trst;
    output reg [`scanpath_count_max:1] sp_tms;
    output reg [`scanpath_count_max:1] sp_tck;
    output reg [`scanpath_count_max:1] sp_tdo;    
    
    input [(`scanpath_count_max * `nibble_width)-1:0] tap_states_feedback; // holds all tap states
    // CS: evaluate it before executing tap state commands
    
    // CS: update it after execution of every tap state command
    output reg [(`scanpath_count_max * `nibble_width)-1:0] tap_states_send; // holds all tap states 
    
    // for trst commands
    `define tck_count_width 5 // holds up to 31 tck changes (or 15 tck cycles)
    parameter tck_count_init = `tck_count_width'd19; // equals 10 tck cycles (must be an even number)
    reg [`tck_count_width-1:0] tck_count; 


    output reg [`byte_width-1:0] scan_clock_frequency;
    reg sct_start;
    scan_clock_timer sct (
        .clk(clk), // input
        .reset_n(reset_n), // input
        .reset(reset), // input
        .delay(scan_clock_frequency), // input
        .start(sct_start), // input
        .done(sct_done), // output
        .step_mode_tck(1'b0), // input // no step mode required here
        .go_step_tck(1'b0) // input // no step mode required here
        );
        
	wire [`byte_width-1:0] i2c_rx_byte; // byte received from i2c master
	reg [`byte_width-1:0] i2c_tx_byte; // byte sent by i2c master
	
	reg i2c_tx_data, i2c_rx_data, // high indicates that i2c master is to send or receive a byte
        i2c_tx_start_condition, i2c_tx_stop_condition, // high indicates that i2c master is to send a start or stop condition
        i2c_start; // general start signal that triggers the i2c master
	
	wire i2c_done;	
	output [`byte_width-1:0] i2c_master_state;
    i2c_master im(
        .clk(clk),  // input
        .reset_n(reset_n),    // input
        .reset(reset), // input        
        .sda(sda),        // inout
        .scl(scl),        // inout
        .tx_byte(i2c_tx_byte),    // input, byte to send to slave
        .rx_byte(i2c_rx_byte),    // output, byte received from slave
        .tx_start_condition(i2c_tx_start_condition),   // input, high, when i2c master is to send a start signal
        .tx_stop_condition(i2c_tx_stop_condition),    // input, high, when i2c master is to send a stop signal
        .tx_data(i2c_tx_data),  // input, high, when i2c master is to send a byte as given in tx_byte
        .rx_data(i2c_rx_data),  // input, high, when i2c master is to receive a byte and output it in rx_byte            
        .start(i2c_start),      // input, starts i2c master
        .done(i2c_done),        // output, high when i2c master done
        .i2c_master_state(i2c_master_state) // output
        );        
    
    output reg [`byte_width-1:0] lcp_state;
    reg [`byte_width-1:0] lcp_state_last;
    reg i2c_command_executed;
    
	output [`timer_state_width-1:0] timer_state;    
    reg timer_start;
    timer ti(
        .clk(clk), // input
        .reset_n(reset_n), // input
        .reset(reset), // input        
        .delay(arg1), // input
        .start(timer_start), // input
        .done(timer_done), // output, high on timeout
        .timer_state(timer_state) // output
        );
    
    always @(posedge clk or negedge reset_n) begin
        if (~reset_n)
            begin
                done                    <= #`DEL 1'b0; // indicates executor that low level command has been executed
                i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for i2c master wait states
                i2c_tx_start_condition  <= #`DEL 1'b0;
                i2c_tx_stop_condition   <= #`DEL 1'b0;
                i2c_tx_data             <= #`DEL 1'b0;
                i2c_rx_data             <= #`DEL 1'b0;                
                i2c_start               <= #`DEL 1'b0;
                i2c_tx_byte             <= #`DEL `byte_width'h00;
                lcp_state               <= #`DEL LCP_STATE_IDLE;
                lcp_state_last          <= #`DEL LCP_STATE_IDLE;
                timer_start             <= #`DEL 1'b0;
                sct_start               <= #`DEL 1'b0;
                tck_count               <= #`DEL tck_count_init;
                sp_trst                 <= #`DEL init_state_trst;
                sp_tms                  <= #`DEL init_state_tms;
                sp_tck                  <= #`DEL init_state_tck;
                sp_tdo                  <= #`DEL init_state_tdo;
                tap_states_send         <= #`DEL {`scanpath_count_max * TAP_TEST_LOGIG_RESET}; //NOTE: TRST applies for ALL scanpaths !
                                    
            end
        else
            begin   
                if (reset) // syncronous reset has the same effect as asynchronous reset
                    begin
                        done                    <= #`DEL 1'b0; // indicates executor that low level command has been executed
                        i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for i2c master wait states
                        i2c_tx_start_condition  <= #`DEL 1'b0;
                        i2c_tx_stop_condition   <= #`DEL 1'b0;
                        i2c_tx_data             <= #`DEL 1'b0;
                        i2c_rx_data             <= #`DEL 1'b0;                
                        i2c_start               <= #`DEL 1'b0;
                        i2c_tx_byte             <= #`DEL `byte_width'h00;
                        lcp_state               <= #`DEL LCP_STATE_IDLE;
                        lcp_state_last          <= #`DEL LCP_STATE_IDLE;
                        timer_start             <= #`DEL 1'b0;
                        sct_start               <= #`DEL 1'b0;
                        tck_count               <= #`DEL tck_count_init;
                        sp_trst                 <= #`DEL init_state_trst;
                        sp_tms                  <= #`DEL init_state_tms;
                        sp_tck                  <= #`DEL init_state_tck;
                        sp_tdo                  <= #`DEL init_state_tdo;
                        tap_states_send         <= #`DEL {`scanpath_count_max * TAP_TEST_LOGIG_RESET}; //NOTE: TRST applies for ALL scanpaths !
                    end
                else
                    begin
                        case (lcp_state) // synthesis parallel_case
                        
                        // EVALUATE AND CHECK COMMAND AND ARGUMENTS
						LCP_STATE_IDLE: //0h
							begin
								done       <= #`DEL 1'b0;
								if (start) begin
									case (command) // check command. if invalid go to error state

										lc_set_frq_tck:
											begin // arg1 holds frequency, arg2 fixed to zero
												scan_clock_frequency <= #`DEL arg1;
												
												case (arg2) // synthesis parallel_case
													lc_null_argument:
														lcp_state   <= #`DEL LCP_STATE_SET_FRQ; // 01h
													default: 
														lcp_state   <= #`DEL LCP_STATE_ERROR_ARG2; // F2h
												endcase
											end
											
										lc_set_sp_thrshld_tdi: // addresses a DAC
											begin // NOTE: check argument 1 only. if invalid argument go to error state
												case (arg1) // synthesis parallel_case
													lc_scanport_1, lc_scanport_2:
														begin
															lcp_state           <= #`DEL LCP_STATE_SET_SUB_BUS_1_DAC_5;
														end
													default:
														begin
															lcp_state           <= #`DEL LCP_STATE_ERROR_ARG1; // F1h
														end
												endcase
											end

										lc_set_sp_vltg_out: 
											begin // NOTE: check argument 1 only. if invalid argument go to error state
												case (arg1) // synthesis parallel_case
													lc_scanport_1, lc_scanport_2:
														begin
															lcp_state           <= #`DEL LCP_STATE_SET_MAIN_DRV_VLTGE_1; // 1Fh // address I2C expander
														end
													default:
														begin
															lcp_state           <= #`DEL LCP_STATE_ERROR_ARG1; // F1h
														end
												endcase
											end
											
										lc_set_drv_chr_tms_tck, lc_set_drv_chr_trst_tdo: // both address an i2c expander
											begin // NOTE: check argument 1 only. if invalid argument go to error state
												// CS: checking argument 2 requires comparing with valid expander output pattern
												case (arg1) // synthesis parallel_case
													lc_scanport_1, lc_scanport_2:
														begin
															lcp_state           <= #`DEL LCP_STATE_SET_MAIN_DRV_CHAR_1; // Ch
														end
													default:
														begin
															lcp_state           <= #`DEL LCP_STATE_ERROR_ARG1; // F1h
														end
												endcase
											end
											
										lc_delay:
											begin  // check argument. if invalid argument go to error state
												case (arg2) // synthesis parallel_case
													lc_delay_arg2 : // arg2 is always zero
														begin
															lcp_state           <= #`DEL LCP_STATE_START_TIMER_1; // 10h
														end
													default:
														begin
															lcp_state           <= #`DEL LCP_STATE_ERROR_ARG2; // F2h
														end
												endcase                                            
											end
											
										lc_power_on_off:
											begin // check arguments. if invalid arguments go to error state
												case (arg1) // synthesis parallel_case
													lc_pwr_gnd, lc_pwr_1, lc_pwr_2, lc_pwr_3, lc_pwr_all:
														begin
															case (arg2) // synthesis parallel_case
																lc_off, lc_on: 
																	begin
																		// Since this HW does not feature power relays nothing will happen here:
																		lcp_state   <= #`DEL LCP_STATE_SEND_DONE_TO_EX; // 23h
																	end
																default: 
																	lcp_state   <= #`DEL LCP_STATE_ERROR_ARG2; // F2h
															endcase
														end
													default: 
														begin
															lcp_state  <= #`DEL LCP_STATE_ERROR_ARG1; // F1h
														end
												endcase
											end
										
										lc_set_imax:
											begin // check arguments. if invalid arguments go to error state
												// NOTE: check arg1 only
												case (arg1) // synthesis parallel_case
													lc_pwr_1, lc_pwr_2, lc_pwr_3:
														begin
															// since this HW does not feature current monitoring nothing will happen here:
															lcp_state   <= #`DEL LCP_STATE_SEND_DONE_TO_EX; // 23h
														end
													default:
														begin
															lcp_state  <= #`DEL LCP_STATE_ERROR_ARG1; // F1h
														end
												endcase
											end
										
										lc_set_timeout:
											begin // check arguments. if invalid arguments go to error state
												// NOTE: check arg1 only
												case (arg1) // synthesis parallel_case
													lc_pwr_1, lc_pwr_2, lc_pwr_3:
														begin
															// since this HW does not feature current monitoring nothing will happen here:
															lcp_state   <= #`DEL LCP_STATE_SEND_DONE_TO_EX; // 23h
														end
													default:
														begin
															lcp_state  <= #`DEL LCP_STATE_ERROR_ARG1; // F1h
														end
												endcase
											end
											
										lc_connect_disconnect:
											begin // check arguments. if invalid arguments go to error state
												case (arg1) // synthesis parallel_case
													lc_scanport_1, lc_scanport_2:
														begin
															case (arg2) // synthesis parallel_case
																lc_off, lc_on: 
																	begin
																		// since this HW does not feature scanport relays nothing will happen here:
																		lcp_state   <= #`DEL LCP_STATE_SEND_DONE_TO_EX; // 23h
																	end
																default: 
																	lcp_state   <= #`DEL LCP_STATE_ERROR_ARG2; // F2h
															endcase
														end
													default: 
														begin
															lcp_state  <= #`DEL LCP_STATE_ERROR_ARG1; // F1h
														end
												endcase
											end
										
										lc_tap_state:
											begin // check arguments. if invalid arguments go to error state
												case (arg1) // synthesis parallel_case
													lc_tap_trst, lc_tap_strst, lc_tap_htrst: //, lc_tap_rti, lc_tap_pdr, lc_tap_pir
														begin
															case (arg2) // synthesis parallel_case
																lc_null_argument:
																	lcp_state   <= #`DEL LCP_STATE_TAP_TRST_1; // 1Bh
																default: 
																	lcp_state   <= #`DEL LCP_STATE_ERROR_ARG2; // F2h
															endcase
														end
													default: 
														begin
															lcp_state  <= #`DEL LCP_STATE_ERROR_ARG1; // F1h
														end
												endcase
											end                                        
										
										default:
											begin // if invalid command -> error
												lcp_state       <= #`DEL LCP_STATE_ERROR_CMD;
												//done            <= #`DEL 1'b0;
											end                            
									
									endcase
								end
							end
							
						// This is a state that is used for non-featured functions. Its only purpose is to
						// signal the executor, that the command has been executed.
						// Afterward it directs the command processor to return to idle mode.
						LCP_STATE_SEND_DONE_TO_EX: // 23h
							begin
								done		<= #`DEL 1'b1; // signal executor low level command done
								lcp_state   <= #`DEL LCP_STATE_IDLE; // 0h
							end
						
                        // SET SCAN FREQUENCY // CS:
						LCP_STATE_SET_FRQ: // 01h
							begin
								done        <= #`DEL 1'b1;
								lcp_state   <= #`DEL LCP_STATE_IDLE;
							end


                        // WAIT STATE FOR I2C MASTER OPERATION
						LCP_STATE_I2C_RDY: // 02h
							begin // i2c master is running
								i2c_start   <= #`DEL 1'b0;  // reset start signal
								// wait for i2c master done with execution
								if (i2c_done) // return to last lcp state
									begin
										lcp_state               <= #`DEL lcp_state_last;
										// set i2c_command_executed so that after return, the main line can proceed
										// does not get started again
										i2c_command_executed    <= #`DEL 1'b1;
									end
							end
							
                                
                        // SET DACS
						LCP_STATE_SET_SUB_BUS_1_DAC_5: // 07h // start condition
							begin
								// initally i2c_command_executed is 0 -> starting i2c_master requried
								// on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
								if (i2c_command_executed)
									begin
										i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
										i2c_tx_start_condition  <= #`DEL 1'b0;
										i2c_start               <= #`DEL 1'b0;
										lcp_state               <= #`DEL LCP_STATE_SET_SUB_BUS_1_DAC_6; // 8h // proceed to next state
									end
								else // set inputs for i2c master and start i2c master
									begin                                                 
										i2c_tx_start_condition  <= #`DEL 1'b1; // input for i2c master
										i2c_start               <= #`DEL 1'b1; // start i2c master
										
										// backup this state for return from wait states
										lcp_state_last          <= #`DEL lcp_state;
										// go to wait state
										lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
									end
							end   
							
						LCP_STATE_SET_SUB_BUS_1_DAC_6: // 08h // address DAC
							begin
								// initally i2c_command_executed is 0 -> starting i2c_master requried
								// on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
								if (i2c_command_executed)
									begin
										i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
										i2c_tx_data             <= #`DEL 1'b0;
										i2c_start               <= #`DEL 1'b0;
										lcp_state               <= #`DEL LCP_STATE_SET_SUB_BUS_1_DAC_7; // 9h // proceed to next state
									end
								else // set inputs for i2c master and start i2c master
									begin
										case (arg1) // synthesis parallel_case // arg1 specifies the scanport
											lc_scanport_1: i2c_tx_byte     <= #`DEL i2c_addr_thrshld_tdi_1;
											lc_scanport_2: i2c_tx_byte     <= #`DEL i2c_addr_thrshld_tdi_2;
										endcase
											
										i2c_tx_data             <= #`DEL 1'b1; // input for i2c master
										i2c_start               <= #`DEL 1'b1; // start i2c master
										
										// backup this state for return from wait states
										lcp_state_last          <= #`DEL lcp_state;
										// go to wait state
										lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
									end
							end

						LCP_STATE_SET_SUB_BUS_1_DAC_7: // 09h // send command byte to DAC
							begin
								// initally i2c_command_executed is 0 -> starting i2c_master requried
								// on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
								if (i2c_command_executed)
									begin
										i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
										i2c_tx_data             <= #`DEL 1'b0;
										i2c_start               <= #`DEL 1'b0;
										lcp_state               <= #`DEL LCP_STATE_SET_SUB_BUS_1_DAC_8; // Ah // proceed to next state
									end
								else // set inputs for i2c master and start i2c master
									begin                       
										i2c_tx_byte             <= #`DEL i2c_data_dac_cmd;
										i2c_tx_data             <= #`DEL 1'b1; // input for i2c master
										i2c_start               <= #`DEL 1'b1; // start i2c master
										
										// backup this state for return from wait states
										lcp_state_last          <= #`DEL lcp_state;
										// go to wait state
										lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
									end
							end

						LCP_STATE_SET_SUB_BUS_1_DAC_8: // 0Ah // send output byte to DAC
							begin
								// initally i2c_command_executed is 0 -> starting i2c_master requried
								// on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
								if (i2c_command_executed)
									begin
										i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
										i2c_tx_data             <= #`DEL 1'b0;
										i2c_start               <= #`DEL 1'b0;
										lcp_state               <= #`DEL LCP_STATE_SET_SUB_BUS_1_DAC_9; // Bh // proceed to next state
									end
								else // set inputs for i2c master and start i2c master
									begin                       
										i2c_tx_byte             <= #`DEL arg2; // THIS IS THE DAC OUTPUT BYTE !
										i2c_tx_data             <= #`DEL 1'b1; // input for i2c master
										i2c_start               <= #`DEL 1'b1; // start i2c master
										
										// backup this state for return from wait states
										lcp_state_last          <= #`DEL lcp_state;
										// go to wait state
										lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
									end
							end                        
							
						LCP_STATE_SET_SUB_BUS_1_DAC_9: // 0Bh // stop condition
							begin
								// initally i2c_command_executed is 0 -> starting i2c_master requried
								// on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
								if (i2c_command_executed)
									begin
										i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
										i2c_tx_stop_condition   <= #`DEL 1'b0;
										i2c_start               <= #`DEL 1'b0;
										done                    <= #`DEL 1'b1; // signal executor low level command done
										lcp_state               <= #`DEL LCP_STATE_IDLE; // 00h // proceed to next state
									end
								else // set inputs for i2c master and start i2c master
									begin                                                 
										i2c_tx_stop_condition   <= #`DEL 1'b1; // input for i2c master
										i2c_start               <= #`DEL 1'b1; // start i2c master
										
										// backup this state for return from wait states
										lcp_state_last          <= #`DEL lcp_state;
										// go to wait state
										lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 3h
									end
							end
                                
                                
                        // SET SCANPORT DRIVER CHARACTERISTICS
						LCP_STATE_SET_MAIN_DRV_CHAR_1: // 0Ch // start condition
							begin
								// initally i2c_command_executed is 0 -> starting i2c_master requried
								// on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
								if (i2c_command_executed)
									begin
										i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
										i2c_tx_start_condition  <= #`DEL 1'b0;
										i2c_start               <= #`DEL 1'b0;
										lcp_state               <= #`DEL LCP_STATE_SET_MAIN_DRV_CHAR_2; // 0Dh // proceed to next state
									end
								else // set inputs for i2c master and start i2c master
									begin                                                 
										i2c_tx_start_condition  <= #`DEL 1'b1; // input for i2c master
										i2c_start               <= #`DEL 1'b1; // start i2c master
										
										// backup this state for return from wait states
										lcp_state_last          <= #`DEL lcp_state;
										// go to wait state
										lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
									end
							end
					
						LCP_STATE_SET_MAIN_DRV_CHAR_2: // 0Dh // send address of register for driver characteristics
							begin
								// initally i2c_command_executed is 0 -> starting i2c_master requried
								// on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
								if (i2c_command_executed)
									begin
										i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
										i2c_tx_data             <= #`DEL 1'b0;
										i2c_start               <= #`DEL 1'b0;
										lcp_state               <= #`DEL LCP_STATE_SET_MAIN_DRV_CHAR_3; // 0Eh // proceed to next state
									end
								else // set inputs for i2c master and start i2c master
									begin
										case (command) // synthesis parallel_case // depending on given command, the i2c expander address differs
											lc_set_drv_chr_tms_tck:
												begin
													case (arg1) // synthesis parallel_case // arg1 specifies the scanport
														lc_scanport_1: i2c_tx_byte     <= #`DEL i2c_addr_main_drv_char_tck_tms_tap_1;
														lc_scanport_2: i2c_tx_byte     <= #`DEL i2c_addr_main_drv_char_tck_tms_tap_2;
													endcase
												end
											lc_set_drv_chr_trst_tdo:
												begin
													case (arg1) // synthesis parallel_case // arg1 specifies the scanport
														lc_scanport_1: i2c_tx_byte     <= #`DEL i2c_addr_main_drv_char_tdo_trst_tap_1;
														lc_scanport_2: i2c_tx_byte     <= #`DEL i2c_addr_main_drv_char_tdo_trst_tap_2;
													endcase
												end
										endcase
											
										i2c_tx_data             <= #`DEL 1'b1; // input for i2c master
										i2c_start               <= #`DEL 1'b1; // start i2c master
										
										// backup this state for return from wait states
										lcp_state_last          <= #`DEL lcp_state;
										// go to wait state
										lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
									end
							end
							
						LCP_STATE_SET_MAIN_DRV_CHAR_3: // 0Eh // send output byte to i2c expander
							begin
								// initally i2c_command_executed is 0 -> starting i2c_master requried
								// on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
								if (i2c_command_executed)
									begin
										i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
										i2c_tx_data             <= #`DEL 1'b0;
										i2c_start               <= #`DEL 1'b0;
										lcp_state               <= #`DEL LCP_STATE_SET_MAIN_DRV_CHAR_4; // Fh // proceed to next state
									end
								else // set inputs for i2c master and start i2c master
									begin                       
										i2c_tx_byte             <= #`DEL arg2; // THIS IS THE DRIVER CHARACTERISTICS OUTPUT BYTE !
										i2c_tx_data             <= #`DEL 1'b1; // input for i2c master
										i2c_start               <= #`DEL 1'b1; // start i2c master
										
										// backup this state for return from wait states
										lcp_state_last          <= #`DEL lcp_state;
										// go to wait state
										lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
									end
							end                        
							
						LCP_STATE_SET_MAIN_DRV_CHAR_4: // 0Fh // stop condition
							begin
								// initally i2c_command_executed is 0 -> starting i2c_master requried
								// on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
								if (i2c_command_executed)
									begin
										i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
										i2c_tx_stop_condition   <= #`DEL 1'b0;
										i2c_start               <= #`DEL 1'b0;
										done                    <= #`DEL 1'b1; // signal executor: low level command done
										lcp_state               <= #`DEL LCP_STATE_IDLE; // 00h // proceed to next state
									end
								else // set inputs for i2c master and start i2c master
									begin                                                 
										i2c_tx_stop_condition   <= #`DEL 1'b1; // input for i2c master
										i2c_start               <= #`DEL 1'b1; // start i2c master
										
										// backup this state for return from wait states
										lcp_state_last          <= #`DEL lcp_state;
										// go to wait state
										lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 3h
									end
							end
                                
       
                        // SET DRIVER OUTPUT VOLTAGE
                        LCP_STATE_SET_MAIN_DRV_VLTGE_1: // 1Fh // start condition
                                begin
                                    // initally i2c_command_executed is 0 -> starting i2c_master requried
                                    // on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
                                    if (i2c_command_executed)
                                        begin
                                            i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
                                            i2c_tx_start_condition  <= #`DEL 1'b0;
                                            i2c_start               <= #`DEL 1'b0;
                                            lcp_state               <= #`DEL LCP_STATE_SET_MAIN_DRV_VLTGE_2; // 20h // proceed to next state
                                        end
                                    else // set inputs for i2c master and start i2c master
                                        begin                                                 
                                            i2c_tx_start_condition  <= #`DEL 1'b1; // input for i2c master
                                            i2c_start               <= #`DEL 1'b1; // start i2c master
                                            
                                            // backup this state for return from wait states
                                            lcp_state_last          <= #`DEL lcp_state;
                                            // go to wait state
                                            lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
                                        end
                                end
                        
                        LCP_STATE_SET_MAIN_DRV_VLTGE_2: // 20h // send address of register for adjusting driver output voltage
                                begin
                                    // initally i2c_command_executed is 0 -> starting i2c_master requried
                                    // on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
                                    if (i2c_command_executed)
                                        begin
                                            i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
                                            i2c_tx_data             <= #`DEL 1'b0;
                                            i2c_start               <= #`DEL 1'b0;
                                            lcp_state               <= #`DEL LCP_STATE_SET_MAIN_DRV_VLTGE_3; // 21h // proceed to next state
                                        end
                                    else // set inputs for i2c master and start i2c master
                                        begin
                                            case (arg1) // synthesis parallel_case // arg1 specifies the scanport
                                                lc_scanport_1: i2c_tx_byte     <= #`DEL i2c_addr_vltg_tap_1;
                                                lc_scanport_2: i2c_tx_byte     <= #`DEL i2c_addr_vltg_tap_2;
                                            endcase
                                                
                                            i2c_tx_data             <= #`DEL 1'b1; // input for i2c master
                                            i2c_start               <= #`DEL 1'b1; // start i2c master
                                            
                                            // backup this state for return from wait states
                                            lcp_state_last          <= #`DEL lcp_state;
                                            // go to wait state
                                            lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
                                        end
                                end
                        
                        LCP_STATE_SET_MAIN_DRV_VLTGE_3: // 21h // send output byte to i2c expander
                            begin
                                // initally i2c_command_executed is 0 -> starting i2c_master requried
                                // on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
                                if (i2c_command_executed)
                                    begin
                                        i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
                                        i2c_tx_data             <= #`DEL 1'b0;
                                        i2c_start               <= #`DEL 1'b0;
                                        lcp_state               <= #`DEL LCP_STATE_SET_MAIN_DRV_VLTGE_4; // 22h // proceed to next state
                                    end
                                else // set inputs for i2c master and start i2c master
                                    begin                       
                                        case (arg2) // synthesis parallel_case
                                            tap_driver_vltg_1V5: i2c_tx_byte <= #`DEL i2c_data_driver_vltg_1V5;
                                            tap_driver_vltg_1V8: i2c_tx_byte <= #`DEL i2c_data_driver_vltg_1V8;
                                            tap_driver_vltg_2V5: i2c_tx_byte <= #`DEL i2c_data_driver_vltg_2V5;
                                            tap_driver_vltg_3V3: i2c_tx_byte <= #`DEL i2c_data_driver_vltg_3V3;
                                            default:
                                                begin
                                                    lcp_state           <= #`DEL LCP_STATE_ERROR_ARG2; // F2h
                                                end
                                        endcase
                                        
                                        i2c_tx_data             <= #`DEL 1'b1; // input for i2c master
                                        i2c_start               <= #`DEL 1'b1; // start i2c master
                                        
                                        // backup this state for return from wait states
                                        lcp_state_last          <= #`DEL lcp_state;
                                        // go to wait state
                                        lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 2h
                                    end
                            end                      
                    
                        LCP_STATE_SET_MAIN_DRV_VLTGE_4: // 22h // stop condition
                            begin
                                // initally i2c_command_executed is 0 -> starting i2c_master requried
                                // on return from LCP_STATE_WAIT i2c_command_executed is 1 -> proceed with next state
                                if (i2c_command_executed)
                                    begin
                                        i2c_command_executed    <= #`DEL 1'b0; // reset i2c_command_executed for other wait states
                                        i2c_tx_stop_condition   <= #`DEL 1'b0;
                                        i2c_start               <= #`DEL 1'b0;
                                        done                    <= #`DEL 1'b1; // signal executor: low level command done
                                        lcp_state               <= #`DEL LCP_STATE_IDLE; // 00h // proceed to next state
                                    end
                                else // set inputs for i2c master and start i2c master
                                    begin                                                 
                                        i2c_tx_stop_condition   <= #`DEL 1'b1; // input for i2c master
                                        i2c_start               <= #`DEL 1'b1; // start i2c master
                                        
                                        // backup this state for return from wait states
                                        lcp_state_last          <= #`DEL lcp_state;
                                        // go to wait state
                                        lcp_state               <= #`DEL LCP_STATE_I2C_RDY; // 3h
                                    end
                            end

       
                        // START TIMER
						LCP_STATE_START_TIMER_1: // 10h
							begin
								timer_start     <= #`DEL 1'b1;
								lcp_state       <= #`DEL LCP_STATE_START_TIMER_2; // 11h
							end

						LCP_STATE_START_TIMER_2: // 11h
							begin
								timer_start     <= #`DEL 1'b0;
								if (timer_done)
									begin
										done        <= #`DEL 1'b1; // signal executor: low level command done
										lcp_state   <= #`DEL LCP_STATE_IDLE;
									end
							end

                                
                        // TAP TRST
						LCP_STATE_TAP_TRST_1: // 1Bh
						// CS: PERFORM TRST WITH A LOW STATIC TCK FREQUENCY SO THAT UUT RESETS EVEN IN WORST CONDTITIONS !
							begin
								// assert hard reset only when full trst or hard trst requried
								if (arg1 == lc_tap_trst || arg1 == lc_tap_htrst)
									begin
										sp_trst <= #`DEL 0; // assert trst
									end
								
								sct_start       <= #`DEL 1; // start scan clock timer
								lcp_state       <= #`DEL LCP_STATE_TAP_TRST_2; // 1Ch // proceed to next state
							end

						LCP_STATE_TAP_TRST_2: // 1Ch
							begin
								// wait until scan clock timer finishes pause
								sct_start       <= #`DEL 0; // clear scan clock timer start signal
								if (sct_done)
									begin
										lcp_state   <= #`DEL LCP_STATE_TAP_TRST_3; // 1Dh
									end                      
							end
							
						LCP_STATE_TAP_TRST_3: // 1Dh
							begin
								// toggle tck if full trst or soft trst requried
								if (arg1 == lc_tap_trst || arg1 == lc_tap_strst)
									begin
										if (tck_count[0] == 1)
											sp_tck      <= #`DEL -1;
										else
											sp_tck      <= #`DEL 0;
									end

								// if tck_count not zero, decement tck_count
								// on zero count, proceed with next state
								if (tck_count > 0)
									begin
										tck_count   <= #`DEL tck_count - 1;
										lcp_state   <= #`DEL LCP_STATE_TAP_TRST_2; // 1Ch // go to wait state again
									end
								else
									begin
										tck_count   <= #`DEL tck_count_init;
										lcp_state   <= #`DEL LCP_STATE_TAP_TRST_4; // 1Eh
									end
									
								sct_start   <= #`DEL 1; // start scan clock timer, regardless which state is next                         
							end
					
						LCP_STATE_TAP_TRST_4: // 1Eh
							begin
								// wait until scan clock timer finishes pause
								sct_start       <= #`DEL 0; // clear scan clock timer start signal
								if (sct_done)
									begin
										sp_trst                 <= #`DEL -1; // deassert trst, even if not asserted before (due to strst)
										done                    <= #`DEL 1'b1; // signal executor low level command done
										
										// send executor the latest tap state. NOTE: TRST applies for ALL scanpaths !
										tap_states_send         <= #`DEL {`scanpath_count_max * TAP_TEST_LOGIG_RESET}; 
										lcp_state               <= #`DEL LCP_STATE_IDLE; // 00h // proceed to next state
									end
							end
							
                        endcase
                    end
            end
    end

endmodule
