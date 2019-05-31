// todo

module router_mmu(

// INPUTS
    reset_n,
    clk,
    
    path,
    request_clear_mem,
    
    // inputs that read from rf and/or ex
    addr_from_rf, data_from_rf,
    data_from_rf_write_strobe,
    addr_from_ex, 
    //data_from_ex, // not used

    data_request_from_ex, // indicates that ex needs data
    //data_acknowledge_from_ex, // indicates that ex has acknowledged data reception from mmu

// OUTPUTS
    mmu_state, // state of the module
    mem_clear, // status of ram, high when ram cleared
    //request_clear_mem_ack, // acknowledges command reception to cmd decoder
    data_ready_to_ex, // indicates valid data is available for executor
    
    // outputs that drive to rf and/or ex
    addr_to_rf, data_to_rf,
    addr_to_ex, // drives start address to executor
    data_to_ex,

// INOUTS
    // ram data is bidir (inout)
    ram_data, 
    
// OUTPUTS
    // ram addr and control is driven by mmu
    ram_addr,
    ram_cs_in_n,
    ram_cs_out_n,
    ram_we_n,
    ram_oe_n,
    
    test_abort // high, when upload starts. safety measure
	);
	
    `include "parameters_global.v"	
    //`include "parameters_ram.v"

// INPUTS
 	input reset_n;
 	input clk;
 	input [3:0] path;
 	//input [`command_width-1:0] command;
 	input request_clear_mem;
//  	wire request_clear_mem_pulse;
//  	pulse_maker pm( // CS: should move to command decoder module
//         .clk(clk),
//         .reset_n(reset_n),
//         .in(request_clear_mem),
//         .out(request_clear_mem_pulse)
//         );
	
    input [`ram_addr_width-1:0] addr_from_rf, addr_from_ex;
    input data_from_rf_write_strobe;
    reg data_from_rf_write_strobe_previous;
    input [`ram_data_width-1:0] data_from_rf;
    //input [`ram_data_width-1:0] data_from_ex; // not used
    
    output reg [`ram_addr_width-1:0] addr_to_rf;
    output reg [`ram_addr_width-1:0] addr_to_ex;
    output reg [`ram_data_width-1:0] data_to_rf, data_to_ex;

 	
 	inout [`ram_data_width-1:0] ram_data;
 	//output reg [`ram_addr_width_physical-1:0] ram_addr;
    output reg [`ram_addr_width-1:0] ram_addr; 	
 	output reg ram_cs_in_n;
 	output reg ram_cs_out_n; 	
 	output reg ram_oe_n;
 	output reg ram_we_n;
 	
 	input data_request_from_ex; // if executor requests data
 	output reg data_ready_to_ex; // indicates to ex that data from ram is ready
    
// MAIN CODE
    output reg [`mmu_state_width-1:0] mmu_state;
    reg [`mmu_state_width-1:0] mmu_state_last; // used for return from wait cycle
    output reg mem_clear;
        
    reg [1:0] wait_count;

    reg [`ram_data_width-1:0] ram_data_local;
       
    reg ram_addr_incrementing_started;
    
    output reg test_abort;
    reg test_abort_enable;
        
    always @(posedge clk or negedge reset_n) begin : fsm
        if (~reset_n)
            begin
                mmu_state               <= #`DEL MMU_STATE_IDLE;
                mmu_state_last          <= #`DEL MMU_STATE_IDLE;
                mem_clear   <= #`DEL 1'b0;
                ram_addr                <= #`DEL -1; //`ram_addr_width_physical'b1;
                ram_data_local          <= #`DEL -1; //`ram_data_width'b1;            
                ram_cs_in_n             <= #`DEL 1'b1;
                ram_cs_out_n            <= #`DEL 1'b1;
                ram_we_n                <= #`DEL 1'b1;
                ram_oe_n                <= #`DEL 1'b1;
                data_ready_to_ex        <= #`DEL 1'b0;
                data_from_rf_write_strobe_previous  <= #`DEL 1'b1;
                ram_addr_incrementing_started       <= #`DEL 1'b0;
                addr_to_rf              <= #`DEL -1; 
                data_to_rf              <= #`DEL -1; 
                
                wait_count              <= #`DEL `ram_wait_states_we;
                
                test_abort              <= #`DEL 1'b0; 
                test_abort_enable       <= #`DEL 1'b0; 
            end
        else
            begin
                // memory clearing can be initiated also if requested from outside
                // this also cancels a write or read access
                if (request_clear_mem)
                    begin
                        //request_clear_mem_ack   <= #`DEL 1'b1; // acknowledge command
                        mmu_state               <= #`DEL MMU_STATE_INIT4; // 8h
                    end
                else
                case (mmu_state) // synthesis parallel_case
                    MMU_STATE_IDLE: // 0h
                        begin
                            ram_addr_incrementing_started   <= #`DEL 1'b0;
                            
                            // on power-up, memory is not initialized (indicated by mem_clear)
                            // so the ram init steps are executed only once after power-up
                            if (~mem_clear)
                                mmu_state <=  #`DEL MMU_STATE_INIT1;
                            else
                            // after memory init, set desired routing
                                mmu_state <=  #`DEL MMU_STATE_ROUT1;
                        end
                    // INIT
                    MMU_STATE_INIT1: // 1h
                        begin
                            mmu_state       <= #`DEL MMU_STATE_WAIT1; // Bh
                            // on transition to WAIT1 do this:
                            // increment address, set data to zero, enable all rams,
                            // set we to zero
                            ram_addr        <= #`DEL ram_addr + 1;
                            ram_data_local  <= #`DEL `ram_data_width'b0;
                            ram_cs_in_n     <= #`DEL 1'b0;
                            ram_cs_out_n    <= #`DEL 1'b0;
                            ram_we_n        <= #`DEL 1'b0;
                        
                            //ram_oe_n        <= #`DEL 1'b1;
                            // CS: insert ram wait states if clock increases
                        end


                    MMU_STATE_WAIT1: // Bh
                        begin
                            // initially wait_count is greater zero. so we go to WAIT_CYCLE and backup this mmu_state
                            // on return form WAIT_CYCLE we proceed here
                            if (wait_count == 0)
                                begin
                                    // on return from WAIT_CYCLE, wait_count is zero. transit to INIT2 and reload wait_count
                                    mmu_state       <= #`DEL MMU_STATE_INIT2; // 2h
                                    wait_count      <= #`DEL `ram_wait_states_we;                                    
                                end
                            else
                                begin
                                    // if wait_count unequal zero (initially), transit to WAIT_CYCLE
                                    mmu_state       <= #`DEL MMU_STATE_WAIT_CYCLE; // Ch
                                    mmu_state_last  <= #`DEL mmu_state; // backup this mmu state                                    
                                end
                        end                        

                    MMU_STATE_WAIT_CYCLE: // Ch
                        begin
                            // on wait_count = zero, return to mmu_state you came from
                            // else decrement wait_count until zero count reached
                            if (wait_count == 0)
                                begin
                                    mmu_state       <= #`DEL mmu_state_last;
                                end
                            else
                                begin
                                    wait_count      <= #`DEL wait_count - 1;
                                end
                        end                        


                        
                    MMU_STATE_INIT2: // 2h
                        begin
                            mmu_state       <= #`DEL MMU_STATE_INIT3; // 3h
                            // on transition to INIT3 do this:
                            // set we to high, RAM write strobe duration 80ns
                            ram_we_n        <= #`DEL 1'b1; 
                            // CS: insert ram wait states if clock increases                            
                        end
                        

                    MMU_STATE_INIT3: // 3h
                        begin
                            // on transition to next state do this:
                            if (ram_addr == `highest_addr_to_init)
                                // when last memory location cleared:
                                // set address and data high, set mem_clear flag
                                // turn off all rams
                                begin
                                    mmu_state               <= #`DEL MMU_STATE_IDLE;
                                    // on transition to IDLE do this:                                
                                    ram_data_local          <= #`DEL -1;
                                    ram_addr                <= #`DEL -1;
                                    mem_clear   <= #`DEL 1'b1;
                                    ram_cs_in_n             <= #`DEL 1'b1;
                                    ram_cs_out_n            <= #`DEL 1'b1;
                                    //ram_oe_n        <= #`DEL 1'b1;
                                end
                            else
                                // when ram not fully cleared yet, go to INII1 on next clock
                                begin
                                    mmu_state       <= #`DEL MMU_STATE_INIT1;
                                end
                        end
                        // CS: insert ram wait states if clock increases
                        
                    // ROUTING
                    MMU_STATE_ROUT1: // 4h // cycle here until a valid path has been set
                        begin                     
                            addr_to_ex  <= #`DEL addr_from_rf; // pass (test start)address from rf to ex
                            // NOTE: this can be done permanently here, ex assumes this as start address when required
                            
                            case (path)
                                path_rf_writes_ram : // 0h
                                    begin
                                        mmu_state       <= #`DEL MMU_STATE_RF_WRITE_RAM1; // 5h
                                        // on transition to ROUT2 do this:
                                        // rf drives data and address in ram
                                        ram_cs_out_n    <= #`DEL 1'b0;
                                        ram_oe_n        <= #`DEL 1'b1;
//                                         ram_we_n        <= #`DEL 1'b0; 
//                                         ram_addr        <= #`DEL addr_from_rf; // rf drives ram addr
//                                         ram_data_local  <= #`DEL data_from_rf; // rf drives ram data

                                        // The test abort signal must be sent only once. The flag test_abort_enable is 
                                        // cleared after asserting test_abort. It will be set when path_ex_reads_ram is 
                                        // selected.
                                        if (test_abort_enable)
                                            begin
                                                test_abort          <= #`DEL 1'b1; // abort a running test
                                                test_abort_enable   <= #`DEL 1'b0; // disable further asserting of test_abort
                                            end
                                    end
                                path_rf_reads_ram : // 1h
                                    begin
                                        mmu_state       <= #`DEL MMU_STATE_RF_READ_RAM; // 9h
                                        // on transition to RF_READ_RAM do this:
                                        // rf drives address in ram and reads data from ram
                                        // here and in next state: ram address is continuously updated as driven by rf
                                        // here and in next state: data_to_rf is continuously updated as driven by ram
                                        // no wait states required because address update from rf is very slow
                                        ram_cs_out_n    <= #`DEL 1'b0;
                                        ram_oe_n        <= #`DEL 1'b0;
                                        ram_we_n        <= #`DEL 1'b1; 
                                        ram_addr        <= #`DEL addr_from_rf; // rf drives ram addr
                                        addr_to_rf      <= #`DEL addr_from_rf; // rf reads back address
                                        data_to_rf      <= #`DEL ram_data; // rf reads ram data
                                        
                                        //test_abort      <= #`DEL 1'b1; // CS ???
                                     end
                                path_ex_reads_ram : // 5h // -> TEST IS BEING EXECUTED !
                                    begin
                                        test_abort_enable   <= #`DEL 1'b1; // enable test abort when an upload starts
                                        test_abort          <= #`DEL 1'b0; // allow tests to start
                                        if (data_request_from_ex)
                                            begin
                                                mmu_state       <= #`DEL MMU_STATE_EX_READ_RAM_WAIT; // Eh
                                                // on transition to EX_READ_RAM_WAIT do this:
                                                // update ram address as driven by ex
                                                // ex reads data from ram / drives address in ram
                                                ram_cs_out_n    <= #`DEL 1'b0;
                                                ram_oe_n        <= #`DEL 1'b0;
                                                ram_we_n        <= #`DEL 1'b1; 
                                                ram_addr        <= #`DEL addr_from_ex; // ex drives address
                                            end
                                    end                                            
                                default : // null path or invalid path requests
                                    begin // disables all RAMs
                                        mmu_state       <= #`DEL mmu_state;
                                        ram_cs_out_n    <= #`DEL 1'b1;
                                        ram_cs_in_n     <= #`DEL 1'b1;
                                        ram_oe_n        <= #`DEL 1'b1;
                                        ram_we_n        <= #`DEL 1'b1; 
                                        
                                        //test_abort      <= #`DEL 1'b1; // abort any running test
                                    end
                            endcase
                        end

                    MMU_STATE_RF_WRITE_RAM1: // 5h // wait for rising edge of write strobe (from rf) (L-H-sensitive)
                        begin
                            test_abort      <= #`DEL 1'b0; // release test abort signal
                            if (path == path_rf_writes_ram) // as long as path is path_rf_writes_ram cycle here
                                begin
                                    // Wait for rising edge of write strobe (from rf) (L-H-sensitive)
                                    // by comparing previous and current state.
                                    // Then clear ram we, wait and set ram we to latch ram_data_local into ram.
                                    // NOTE: ram_data_local is sent through a buffer (see assignment below)                            
                                    if (~data_from_rf_write_strobe_previous && data_from_rf_write_strobe)
                                        begin
                                            mmu_state               <= #`DEL MMU_STATE_RF_WRITE_RAM_WAIT; // Dh
                                            ram_data_local          <= #`DEL data_from_rf; // register data driven by rf
                                            ram_we_n                <= #`DEL 1'b0; // clear we. will be set after wait cycle

                                            //if this is the first write cycle, register address driven by rf
                                            //otherwise increment address
                                            if (ram_addr_incrementing_started == 0)
                                                ram_addr            <= #`DEL addr_from_rf;
                                            else
                                                ram_addr            <= #`DEL ram_addr + 1; // increment ram addr
                                        end

                                    // save current state of strobe for next sample
                                    data_from_rf_write_strobe_previous <= #`DEL data_from_rf_write_strobe;
                                end
                            else // if path changes, abort write cycle
                                begin
                                    mmu_state                       <= #`DEL MMU_STATE_ROUT1; // 4h 
                                    ram_addr_incrementing_started   <= #`DEL 1'b0;
                                end
                        end

                    MMU_STATE_RF_WRITE_RAM_WAIT: // Dh
                        begin
                            // initially wait_count is greater zero. so we go to WAIT_CYCLE and backup this mmu_state
                            // on return form WAIT_CYCLE we proceed here
                            if (wait_count == 0)
                                begin
                                    // on return from WAIT_CYCLE, wait_count is zero. transit to RF_WRITE_RAM2 and reload wait_count
                                    mmu_state       <= #`DEL MMU_STATE_RF_WRITE_RAM2; // Ah
                                    wait_count      <= #`DEL `ram_wait_states_we;                                    
                                end
                            else
                                begin
                                    // if wait_count unequal zero (initially), transit to WAIT_CYCLE
                                    mmu_state       <= #`DEL MMU_STATE_WAIT_CYCLE; // Ch
                                    mmu_state_last  <= #`DEL mmu_state; // backup this mmu state                                    
                                end
                        end                        
                            
                            
                    MMU_STATE_RF_WRITE_RAM2: // Ah
                        begin
                            mmu_state                           <= #`DEL MMU_STATE_ROUT1; // 4h
                            // on transition to RF_WRITE_RAM3 do this:
                            ram_we_n                            <= #`DEL 1'b1; // raise we to latch data into ram
                            mem_clear                           <= #`DEL 1'b0; // once a write access has occured, we assume the memory is assumed as not clear anymore  
                            ram_addr_incrementing_started       <= #`DEL 1'b1; // set flag ram_addr_incrementing_started so that in RF_WRITE_RAM1 the address gets incremented                           
                        end
                        
                    MMU_STATE_RF_READ_RAM: // 9h // rf reads data from ram / drives address in ram
                        begin 
                            // rf monitors address and data
                            mmu_state           <= #`DEL MMU_STATE_ROUT1; // 4h
                            // on transition to ROUT1 do this:                            
                            // sample ram address and data so that rf gets valid address and data from ram
                            addr_to_rf          <= #`DEL addr_from_rf; // rf reads ram address
                            data_to_rf          <= #`DEL ram_data; // rf reads ram data
                            // CS: data_ready_to_rf   <= #`DEL 1'b1;
                        end

                    MMU_STATE_EX_READ_RAM_WAIT: // Eh
                        begin
                            // initially wait_count is greater zero. so we go to WAIT_CYCLE and backup this mmu_state
                            // on return form WAIT_CYCLE we proceed here
                            if (wait_count == 0)
                                begin
                                    // on return from WAIT_CYCLE, wait_count is zero. transit to RF_WRITE_RAM2 and reload wait_count
                                    mmu_state       <= #`DEL MMU_STATE_EX_READ_RAM1; // 6h
                                    wait_count      <= #`DEL `ram_wait_states_we;                                    
                                end
                            else
                                begin
                                    // if wait_count unequal zero (initially), transit to WAIT_CYCLE
                                    mmu_state       <= #`DEL MMU_STATE_WAIT_CYCLE; // Ch
                                    mmu_state_last  <= #`DEL mmu_state; // backup this mmu state                                    
                                end
                        end                        
                        
                    MMU_STATE_EX_READ_RAM1: // 6h // ex reads data from ram / drives address in ram
                        begin 
                            // rf monitors address and data
                            mmu_state           <= #`DEL MMU_STATE_EX_READ_RAM2; // 7h
                            // on transition to ROUT1 do this:                            
                            // sample ram address and data so that destinations rf and ex get valid address and data from ram
                            addr_to_rf          <= #`DEL ram_addr; // rf reads ram address
                            data_to_rf          <= #`DEL ram_data; // rf reads ram data
                            data_to_ex          <= #`DEL ram_data; // ex reads ram data
                            data_ready_to_ex    <= #`DEL 1'b1;
                        end
                           
                        
                    MMU_STATE_EX_READ_RAM2: // 7h // wait for acknowledge from ex
                        begin
                            // cycle here until acknowledge arrives
                            //if (data_acknowledge_from_ex) // indicates that ex has acknowledged data reception from mmu
                            //    begin
                                    mmu_state           <= #`DEL MMU_STATE_ROUT1; // 4h
                                    // on transition to ROUT1 do this:                            
                                    data_ready_to_ex    <= #`DEL 1'b0; // deassert data ready signal to ex
                            //    end
                        end
                        
                    MMU_STATE_INIT4: // 8h // on request clear mem
                        begin 
                            //request_clear_mem_ack   <= #`DEL 1'b0; // clear acknowledge command                        
                            mmu_state               <= #`DEL MMU_STATE_INIT1; // 1h
                            // on transition to INIT1 do this:
                            ram_addr                <= #`DEL -1;
                            ram_data_local          <= #`DEL `ram_data_width'b0;
                            ram_oe_n                <= #`DEL 1'b1;
                            data_ready_to_ex        <= #`DEL 1'b0;
                            //CS: ? data_from_rf_write_strobe_previous    <= #`DEL 1'b1;                            
                        end
                        
                    default: mmu_state <= #`DEL MMU_STATE_IDLE;
                endcase
            end
    end // fsm

//     always @(path)
//         begin
//             case (path)
//                 path_rf_writes_ram:
//                     begin
//                         ram_addr    = #`DEL addr_from_rf; // rf drives ram addr
//                     end
//                 path_rf_reads_ram:
//                     begin
//                         ram_addr    = #`DEL addr_from_rf; // rf drives ram addr
//                     end
//                 path_ex_reads_ram:
//                     begin
//                         ram_addr    = #`DEL addr_from_ex; // ex drives address
//                     end
//             endcase
//         end
    
    // ram_data is bidirectional !!
    // if ram outputs active AND any ram selected, data bus drivers must be in highz
 	assign ram_data = (~ram_oe_n & (~ram_cs_in_n | ~ram_cs_out_n)) ? `ram_data_width'hzz : ram_data_local;    

endmodule
