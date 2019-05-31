// todo

module sim_router_mmu();

// INPUTS

// OUTPUTS

// INOUTS
	
    `include "parameters_global.v"	
    //`include "parameters_ram.v"

// SIGNAL DECLARATIONS EXTERNAL
    reg CLK_MASTER;
    reg CPU_RESET_N;

    // panel
    reg PANEL_START_N; // input // debouncer
    reg PANEL_STOP_N; // input // debouncer
    //wire PANEL_PASS;
    //wire PANEL_FAIL;
    
    // transceiver select
    reg TRC_SEL; // If tied to GND via jumper, new transceiver is selected.
    
    // ex outputs
    wire [`chain_length_width-1:0] bits_processed_chain_1;
    wire [`chain_length_width-1:0] sxr_length_chain_1;
    wire [`chain_length_width-1:0] bits_processed_chain_2;
    wire [`chain_length_width-1:0] sxr_length_chain_2;    
    wire [`step_id_width-1:0] step_id;
    //CS: wire [`ram_data_width-1:0] tck_frequency; // may be used to override frequency compiled in vector file
    wire [`executor_state_width-1:0] executor_state;
    wire [`tap_state_width-1:0] tap_state_1;
    wire [`tap_state_width-1:0] tap_state_2;    
    wire [`byte_width-1:0] shifter_state_1;
    wire [`byte_width-1:0] shifter_state_2;   
    wire [`timer_scan_state_width-1:0] scan_clock_timer_state_1;
    wire [`timer_scan_state_width-1:0] scan_clock_timer_state_2;   
    
    // breakpoint sent by register file
    reg [`step_id_width-1:0] breakpoint_sxr_id;
    reg [`chain_length_width-1:0] breakpoint_bit_position;

  
    // i2c
    wire I2C_SCL;
    wire I2C_SDA;    
    
    // tap
    wire TAP_1_TDO;
    wire TAP_1_TMS;
    wire TAP_1_TCK;
    wire TAP_1_TRST;
    reg  TAP_1_TDI;

    wire TAP_2_TDO;
    wire TAP_2_TMS;
    wire TAP_2_TCK;
    wire TAP_2_TRST;
    reg  TAP_2_TDI;
        
    wire tap_1_mask;
    wire tap_1_exp;
    wire TAP_1_FAIL;

    wire tap_2_mask;
    wire tap_2_exp;
    wire TAP_2_FAIL;
    
    wire [`scanpath_count_max:1] ex_sp_trst;    
    wire [`scanpath_count_max:1] ex_sp_tms;    
    wire [`scanpath_count_max:1] ex_sp_tck;    
    wire [`scanpath_count_max:1] ex_sp_tdo;
    wire [`scanpath_count_max:1] ex_sp_tdi;
    
    wire [`scanpath_count_max:1] ex_sp_exp;    
    wire [`scanpath_count_max:1] ex_sp_mask;    
    wire [`scanpath_count_max:1] ex_sp_fail;
    
    assign TAP_1_TRST   = ex_sp_trst[1];    
    assign TAP_1_TMS    = ex_sp_tms[1];    
    assign TAP_1_TCK    = ex_sp_tck[1];    
    assign TAP_1_TDO    = ex_sp_tdo[1];
    assign tap_1_exp    = ex_sp_exp[1];
    assign tap_1_mask   = ex_sp_mask[1];
    assign TAP_1_FAIL   = ex_sp_fail[1];    
    assign ex_sp_tdi[1] = TAP_1_TDI;
    
    assign TAP_2_TRST   = ex_sp_trst[2];    
    assign TAP_2_TMS    = ex_sp_tms[2];    
    assign TAP_2_TCK    = ex_sp_tck[2];    
    assign TAP_2_TDO    = ex_sp_tdo[2];
    assign tap_2_exp    = ex_sp_exp[2];
    assign tap_2_mask   = ex_sp_mask[2];
    assign TAP_2_FAIL   = ex_sp_fail[2];
    assign ex_sp_tdi[2] = TAP_2_TDI;
           
    //wire clk_scan;
    wire [`byte_width-1:0] lcp_state;
    wire [`byte_width-1:0] i2c_master_state;
    wire [`timer_state_width-1:0] timer_state;    
    
    // misc
    wire PWR_CTRL_EMRGCY_PWR_OFF_N;
    //reg PWR_CTRL_PWR_FAIL_N;
    wire MISC_RESET_2_N;
    
    
    // rf outputs
    reg [`path_width-1:0] data_path; // driven by rf
    reg [`command_width-1:0] command;   // driven by rf 
    //reg [7:0] start_stop_from_rf; // AA/55 CS: should be replaced by command decoder outputs // obsolete
    reg ram_data_write_strobe;
    reg [`ram_addr_width_max-1:0] rf_ram_addr_out;    
    reg [`ram_data_width-1:0] rf_ram_data_out;

    // ex output
    wire [`ram_addr_width-1:0] ex_ram_addr_out;
    //reg [`ram_data_width-1:0] ex_ram_data_out; // not used

    // rf inputs
    wire [`ram_addr_width_max-1:0] rf_ram_addr_in;
    assign rf_ram_addr_in[(`ram_addr_width_max-1):`ram_addr_width] = `ram_addr_width_excess'b0;
    wire [`ram_data_width-1:0] rf_ram_data_in;

    wire [`ram_addr_width-1:0] ex_ram_addr_in;
    wire [`ram_data_width-1:0] ex_ram_data_in;

    wire [`ram_addr_width-1:0] ram_addr;
    wire [`ram_data_width-1:0] ram_data;

    wire [`mmu_state_width-1:0] mmu_state;
    //wire data_ready_for_ex;
    //reg data_acknowledge_from_ex; // indicates that ex has acknowledged data reception from mmu
    wire mem_clear;

    
    // OUTPUT RAM MODEL    
    // CS: model read cycle time of 70ns
    wire ram_oe_n;
    wire ram_we_n;
    wire ram_cs_in_n;
    wire ram_cs_out_n;
    
    reg [`ram_data_width-1:0] ram_out[0:'h4000];
    reg ram_data_enable;

    always @(posedge ram_we_n)
        begin
            if (ram_oe_n && ~ram_cs_out_n)
                ram_out[ram_addr] = ram_data;
        end
    always @(ram_oe_n or ram_cs_out_n or ram_we_n)
        begin
            if (~ram_oe_n && ~ram_cs_out_n && ram_we_n)
                ram_data_enable = 1;
            else
                ram_data_enable = 0;
        end
    assign ram_data = ram_data_enable ? ram_out[ram_addr] : `ram_data_width'hz;

    // TASKS
	task load_ram_out;
        input integer bytes;
		reg [7:0] input_file_data_byte;
		integer input_file_name;
		integer file_pointer;
		begin
            data_path = path_null; // invalid data path		
            #100
            $display("time: %d : fill ram_out with vector file ", $time);
            
            // NOTE: MIND FILE AND RAM SIZE WHEN CALLING THIS TASK !
            `ifdef testbench_local
                //input_file_name = $fopen("/home/luno/tmp/testbench/mmu/infra/infra.vec", "rb");
				input_file_name = $fopen("/home/luno/tmp/stmdk/osc_25m/osc_25m.vec", "rb");
            `else
            // NOTE: MIND FILE AND RAM SIZE WHEN CALLING THIS TASK !
                input_file_name = $fopen("/mnt/cad/M-1/uut/sn_002/m-1_interconnections/infra/infra.vec","rb");
                //input_file_name = $fopen("/mnt/xchange/mario/testbench/mmu/osc/osc.vec", "rb");
                //input_file_name = $fopen("/mnt/cad/M-1/uut/stmdk/infra/infra.vec", "rb");
                //input_file_name = $fopen("/mnt/xchange/mario/testbench/mmu/infra/infra.vec", "rb");
                //input_file_name = $fopen("/mnt/xchange/mario/testbench/mmu/sram_ic202/sram_ic202.vec", "rb");
                //input_file_name = $fopen("/mnt/xchange/mario/testbench/mmu/osc/osc.vec", "rb");
            `endif

			for (file_pointer = 0 ; file_pointer < bytes ; file_pointer = file_pointer + 1 )
				begin
					input_file_data_byte = $fgetc(input_file_name);
					ram_out[file_pointer + 'h1800] = input_file_data_byte;
				end
		end
	endtask
				
    

    task rf_writes_in_ram;
        //output [`ram_addr_width-1:0] addr;
        //output [`ram_data_width-1:0] data;
        input [`ram_addr_width_max-1:0] addr;
        input [`ram_data_width-1:0] data;
        begin
            @(posedge CLK_MASTER);
            //#100
            $display("time: %d : rf writes data in ram ", $time);
            data_path = path_rf_writes_ram; // rf drives data and address in ram
            //$display("time: %d :  set data path %hh ", $time, data_path);            
            #100
            rf_ram_addr_out = addr;
            rf_ram_data_out = data;
            #50
            ram_data_write_strobe = 0;
            #200
            ram_data_write_strobe = 1; 
            #200
            ram_data_write_strobe = 0;            
        end
    endtask
    
    task rf_sets_null_path;
        begin
            $display("time: %d : set null path ", $time);
            data_path = path_null; // invalid data path
            #300
            data_path = path_null; // invalid data path            
        end
    endtask

    
    task rf_reads_data_from_ram;
        input [`ram_addr_width-1:0] addr;
        //output [`ram_data_width-1:0] data;        
        begin
            @(posedge CLK_MASTER);
            $display("time: %d : rf reads data from ram ", $time);
            data_path = path_rf_reads_ram; // rf reads from ram            
            #100
            //rf_ram_addr_out = {`ram_addr_width_max-`ram_addr_width'b0, addr[`ram_addr_width:0]};
            rf_ram_addr_out = addr;            
            //data = rf_ram_data_in;
        end
    endtask

    
// NOTE: this task is now obsolete, since ex drives ram address
//     task ex_reads_from_ram;
//         input [`ram_addr_width-1:0] addr;
//         begin
//             @(posedge CLK_MASTER);
//             //#50
//             $display("at time %d : ex reads from ram ", $time);            
//             ex_ram_addr_out = addr; 
//             // NOTE: ram address must be ready before next clock that samples data output by ram
//         end
//     endtask

    task start_test;
        input [`ram_addr_width-1:0] start_addr;
        input [`command_width-1:0] cmd;        
        begin
            @(posedge CLK_MASTER);
            $display("time: %d : init test ", $time);
            //data_path = path_null;
            //#100
            
            // set test start address
            rf_ram_addr_out = start_addr; 
            // - the mmu is waiting in state MMU_STATE_ROUT1
            // - the address output by rf gets permanently registered
            //   and should appear at the mmu output addr_to_ex now
                        
            // direct address from executor to ram (execution mode)
            #100
            data_path = path_ex_reads_ram; // 5h

            #100
            //$display("time: %d : null command ", $time);         
            command = cmd_null; // FFh
            
            #100
            case (cmd)
                cmd_step_tck: $display("time: %d : start step width tck ", $time);
                cmd_step_sxr: $display("time: %d : start step width sxr ", $time);
                cmd_step_test: $display("time: %d : start step width test ", $time);                
            endcase
            
            command = cmd;
//             #110
//             $display("time: %d : null command ", $time);         
//             command = cmd_null;
        end 
    endtask

    task start_button_pressed;
        begin
            @(posedge CLK_MASTER);
            $display("time: %d : start button pressed ", $time);
            PANEL_START_N = 1'b0;
            #200
            $display("time: %d : start button released", $time);            
            PANEL_START_N = 1'b1;            
        end 
    endtask

    task stop_button_pressed;
        begin
            @(posedge CLK_MASTER);
            $display("time: %d : stop button pressed ", $time);
            PANEL_STOP_N = 1'b0;
            #200
            $display("time: %d : stop button released", $time);            
            PANEL_STOP_N = 1'b1;            
        end 
    endtask
    
    
    task abort_test;
        begin
            @(posedge CLK_MASTER);
            $display("time: %d : abort test ", $time);
            command = cmd_null; // FFh
            #100
            command = cmd_test_abort;
            #100
            data_path = path_null;
        end
    endtask
    
    // confirmation of memory clear request
    // NOTE: CS: rf should issue null-command instead
//     always @(posedge CLK_MASTER)
//         begin
//             if (mem_clear)
//                 command = cmd_null;
//         end
    
    task clear_mem;
        begin
            @(posedge CLK_MASTER);
            $display("time: %d : clear mem start", $time);
            command = cmd_clear_ram;
            #1000
            $display("time: %d : clear mem finished", $time);            
            command = cmd_null;
            //#200
            //request_clear_mem = 0;
        end
    endtask    
    
    task set_breakpoint;
        input [`step_id_width-1:0] sxr_id;
        input [`chain_length_width-1:0] bit_position;
        begin
            @(posedge CLK_MASTER);
            $display("time: %d : set breakpoint", $time);
            breakpoint_sxr_id = sxr_id;
            breakpoint_bit_position = bit_position;
        end
    endtask
    
    
    initial
        begin
            CLK_MASTER = 0;
            CPU_RESET_N = 1;
            PANEL_START_N = 1;
            PANEL_STOP_N = 1;
            TRC_SEL = 1;
            ram_data_write_strobe = 1;
            command = cmd_null;
            //start_stop_from_rf = start_stop_null;
            #20 
            CPU_RESET_N = 0;
            #80 
            CPU_RESET_N = 1;
            #1000
            
            // BASIC I/O FUNCTIONS
//             // rf writes data in ram
//             rf_writes_in_ram(`ram_addr_width_max'h000006, `ram_data_width'h44);
//             rf_writes_in_ram(`ram_addr_width_max'h000007, `ram_data_width'h45);
//             
//             // test invalid data path setting
//             rf_sets_null_path;
// 
//             //data_path = path_ex_reads_ram; // 5h            

//             clear_mem; // takes too long when whole memory is to be cleared
             
//             
//             // rf writes data in ram
//             rf_writes_in_ram(`ram_addr_width_max'h000008, `ram_data_width'hB4);
//             rf_writes_in_ram(`ram_addr_width_max'h000009, `ram_data_width'hB5);
//             
//             // rf reads data from ram
//             rf_reads_data_from_ram(`ram_addr_width_max'h000006); // data read should be 44h
//             rf_reads_data_from_ram(`ram_addr_width_max'h000007); // data read should be 45h
            
            // LOAD OUTPUT RAM WITH REAL TEST DATA
            //load_ram_out('h381); // vector file size
            load_ram_out('d5994); // vector file size            
            
            //set_breakpoint('d4,'d18);
            
            // START TEST
            #100
            //start_test('h0, cmd_step_test);
            //start_test('h0, cmd_step_sxr);
//             start_test('h0, cmd_step_tck);
// 
//             #180000
//             start_test('h0, cmd_step_tck);
//             #20000
//             start_test('h0, cmd_step_tck);            
//             #20000
//             start_test('h0, cmd_step_tck);            
//             #20000
//             start_test('h0, cmd_step_tck);            
// 
//             #20000
//             start_test('h0, cmd_step_sxr);
// 
//             #40000
//             start_test('h0, cmd_step_tck);
// 
//             #20000
//             start_test('h0, cmd_step_tck);
//             
//             #20000
//             start_test('h0, cmd_step_tck);
// 
//             #20000
//             start_test('h0, cmd_step_tck);
// 
//             #20000
//             start_test('h0, cmd_step_tck);
            
                #2000
                start_test('h1800, cmd_step_test);
//                 #4000000
//                 start_test('h0, cmd_step_sxr);
//                 #20000
//                 start_test('h0, cmd_step_sxr);
//                 #20000
//                 start_test('h0, cmd_step_sxr);
           
                //#800000
                //abort_test;                
                //stop_button_pressed;
               
                //start_button_pressed;
                //#1400000
                //stop_button_pressed;
                
                
//             start_test('h0, cmd_step_tck);
//             #50000
//             //start_test('h0, cmd_step_test);
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
//             #50000
//             start_test('h0, cmd_step_tck);
            
            
            //start_test(`ram_addr_width'h07001);
            //#400
            //stop_test;
            //#100
            //start_test('h0);
            //#1000
            //$display("at time %d : simulation finished ", $time);            
            //$finish;
        end
       
    // TDI 
    // tdi gets what is expected
    // CS: error insertion at certain positions in input data stream
    always @(posedge CLK_MASTER) begin
//        if (step_id == 5 && bits_processed_chain_1 == 371)
//            TAP_1_TDI = 1'b1;
//        else
            TAP_1_TDI = tap_1_exp;
        //TAP_1_TDI = 1'b1;         
        //TAP_2_TDI = 1'b1; 
            TAP_2_TDI = tap_2_exp; 
        //$display("time: %d : tdi ", $time); 
        //$finish;
    end
    
    // monitor executor states
    always @(posedge CLK_MASTER) begin
//        case (executor_state)
//             //EX_STATE_INC_SCNPT_PTR:         $display("time: %d : reading scanpath base addresses ", $time);
//             EX_STATE_SET_FRQ_PRSCLR:        $display("time: %d : set frequency prescaler ", $time);
//             EX_STATE_SET_THRSHLD_TDI_1:     $display("time: %d : set threshold tdi 1 ", $time);
//             EX_STATE_SET_THRSHLD_TDI_2:     $display("time: %d : set threshold tdi 2 ", $time);
//             EX_STATE_SET_VLTG_OUT_SP_1:     $display("time: %d : set voltage sp 1", $time);
//             EX_STATE_SET_VLTG_OUT_SP_2:     $display("time: %d : set voltage sp 2", $time); 
//            EX_STATE_RD_STEP_ID_BYTE_0:     $display("time: %d : fetch step id ", $time); 
//            EX_STATE_EVAL_STEP_ID:          $display("time: %d : eval step id ", $time);
//            EX_STATE_RD_SXR_LENGTH_9:       $display("time: %d : calc byte ct ", $time);
//            EX_STATE_RD_SXR_DRV_MSK_EXP_2:  $display("time: %d : fetch triplet ", $time);
//        endcase

        case (lcp_state)
            //EX_STATE_INC_SCNPT_PTR:         $display("time: %d : reading scanpath base addresses ", $time);
//             LCP_STATE_SET_FRQ:              $display("time: %d : set frequency prescaler ", $time);
//             LCP_STATE_SET_SUB_BUS_1_DAC_1:  $display("time: %d : set DAC ", $time);
//             LCP_STATE_SET_MAIN_DRV_CHAR_1:  $display("time: %d : set driver characteristics ", $time);
//             EX_STATE_SET_THRSHLD_TDI_2:     $display("time: %d : set threshold tdi 2 ", $time);
//             EX_STATE_SET_VLTG_OUT_SP_1:     $display("time: %d : set voltage sp 1", $time);
//             EX_STATE_SET_VLTG_OUT_SP_2:     $display("time: %d : set voltage sp 2", $time); 
//            LCP_STATE_START_TIMER_1:            $display("time: %d : start timer ", $time); 
            LCP_STATE_SET_SUB_BUS_2_PWR_7:   $display("time: %d : compute power relay drv pattern ", $time); 
        endcase
     end

    // i2c slave acknowledges data reception
    always @(posedge CLK_MASTER) begin
        case (i2c_master_state)
            I2C_MASTER_STATE_TX_5: // 0Ah
                begin
                    //$display("time: %d : i2c slave acknowledges ", $time);
                    force I2C_SDA = 0;
                end
            I2C_MASTER_STATE_TX_8: // 0Dh
                begin
                    //$display("time: %d : i2c slave acknowledges ", $time);
                    release I2C_SDA;
                end
        endcase
                
    end
     
        
    //always #40 clk = ~clk; // 12.5Mhz clock // period 80ns
    always #10 CLK_MASTER = ~CLK_MASTER; // 50Mhz main clock // period 20ns    
   
    prescaler prescaler(
        .clk(CLK_MASTER),
        //.out_2(clk_mmu), // 12.5Mhz clock // period 80ns
        //.out_21(clk_debouncers), // output // 16hz / period 62.8ms
        .reset_n(CPU_RESET_N)
        );
        
	debouncer db_start_button (
		.out(panel_start_debounced),
		.in(~PANEL_START_N),
		.clk(CLK_MASTER),
		.reset_n(CPU_RESET_N)
	);        
	
	debouncer db_stop_button (
		.out(panel_stop_debounced),
		.in(~PANEL_STOP_N),
		.clk(CLK_MASTER),
		.reset_n(CPU_RESET_N)
	);

    command_decoder cd (
        .clk(CLK_MASTER),
        .reset_n(CPU_RESET_N),
        .command(command),
        .request_clear_mem(request_clear_mem),
        //.request_clear_mem_ack(request_clear_mem_ack), // input, from mmu        
        .go_step_tck(go_step_tck),
        .go_step_sxr(go_step_sxr),
        .go_step_test(go_step_test),
        //.go_step_test_ack(go_step_test_ack), // input, from executor
        .test_halt(test_halt),  // output, drives to ex
        .test_abort(test_abort_cd)  // output, drives to ex
        //.test_abort_ack(test_abort_ack) // input, from executor
        );
        
    router_mmu router_mmu (
        .reset_n(CPU_RESET_N),
        //.dummy_out(debug[0]),
        .clk(CLK_MASTER),
        //.clk(clk),        
        
        // input, driven by rf to specifiy data path
        .path(data_path),
        
        // input, driven by command decoder
        .request_clear_mem(request_clear_mem),
        //.request_clear_mem_ack(request_clear_mem_ack), // output, to cmd decoder 
        .data_request_from_ex(data_request_from_ex), // input, driven by ex, indicates that ex requests data
        
        // output that indicates status of the mmu
        .mmu_state(mmu_state),
        
        .mem_clear(mem_clear), // output, high when ram cleared
        .data_ready_to_ex(data_ready_to_ex), // output
        //.data_acknowledge_from_ex(data_acknowledge_from_ex), // input   
        
        // inputs that read from rf and/or ex
        .addr_from_rf(rf_ram_addr_out[`ram_addr_width-1:0]),
        .data_from_rf(rf_ram_data_out),
        .data_from_rf_write_strobe(ram_data_write_strobe), // L on write access to 80h (data channel)
        
        .addr_from_ex(ex_ram_addr_out), // input
        //.data_in_ex(ex_ram_data_out), // not used
       
        // outputs that drive to rf and/or ex
        .addr_to_rf(rf_ram_addr_in[`ram_addr_width-1:0]),
        .data_to_rf(rf_ram_data_in),
        
        .addr_to_ex(ex_ram_addr_in), // output, drives start address to ex
        .data_to_ex(ex_ram_data_in), // output, drives data to ex
        
        // ram data is bidir (inout)
        .ram_data(ram_data),
        // ram addr is driven by mmu
        .ram_addr(ram_addr),
        .ram_cs_in_n(ram_cs_in_n),
        .ram_cs_out_n(ram_cs_out_n),
        .ram_we_n(ram_we_n),
        .ram_oe_n(ram_oe_n),
        
        .test_abort(test_abort_mmu) // output
        );
    
    executor ex (
        .reset_n(CPU_RESET_N),
        .clk(CLK_MASTER),
        .ex_state(executor_state), // output, read by rf        
        .go_step_tck(go_step_tck), // input, driven by command decoder
        .go_step_sxr(go_step_sxr), // input, driven by command decoder
        .go_step_test(go_step_test), // input, driven by command decoder
        
   		.breakpoint_sxr_id(breakpoint_sxr_id), // input, driven by rf
		.breakpoint_bit_position(breakpoint_bit_position), // input, driven by rf

        .start_from_panel(panel_start_debounced), // input
        .test_halt(test_halt), // input, driven by command decoder
        
        .test_abort(test_abort_cd | panel_stop_debounced), // input, driven by command decoder or stop button
        // NOTE: aborting by mmu signal test_abort_mmu not simulated 
        
        //.test_abort_ack(test_abort_ack), // output, to command decoder        
        //.start_stop_from_rf(start_stop_from_rf), // input driven by rf //CS: should be replaced by command decoder outputs // obsolete

        //.start_from_panel(PANEL_START), // input // debouncer not simulated
        //.stop_from_panel(PANEL_STOP), // input // debouncer not simulated
        //.test_pass(PANEL_PASS), // output
        //.test_fail(PANEL_FAIL),  // output

        .bits_processed_chain_1(bits_processed_chain_1), // output
        .sxr_length_chain_1(sxr_length_chain_1), // output
        .bits_processed_chain_2(bits_processed_chain_2), // output        
        .sxr_length_chain_2(sxr_length_chain_2), // output
        
        .step_id(step_id), // output
        
        .tap_state_1(tap_state_1), // output
        .tap_state_2(tap_state_2), // output        

        .ram_addr_to_mmu(ex_ram_addr_out), // output
        .ram_data_from_mmu(ex_ram_data_in), // input
        .data_ready_from_mmu(data_ready_to_ex),        // input
        //.data_acknowledge_to_mmu(data_acknowledge_from_ex), // output
        .data_request_to_mmu(data_request_from_ex), // output, drives to mmu       
        .start_addr_in(ex_ram_addr_in), // input, test start address driven by mmu
        
        .sda(I2C_SDA), // bidir
        .scl(I2C_SCL), // bidir
        .emergency_pwr_off_n(PWR_CTRL_EMRGCY_PWR_OFF_N), // output
        //.uut_pwr_fail_from_pwr_ctrl(~PWR_CTRL_PWR_FAIL_N), // input driven by uut power monitor/controller
        .reset_timer_n(MISC_RESET_2_N), // output

        .sp_trst(ex_sp_trst), // output
        .sp_tms(ex_sp_tms), // output
        .sp_tck(ex_sp_tck), // output
        .sp_tdo(ex_sp_tdo), // output
        .sp_tdi(ex_sp_tdi), // input
        
        .sp_exp(ex_sp_exp), // output
        .sp_mask(ex_sp_mask), // output
        .sp_fail(ex_sp_fail), // output        
        
        //.clk_scan, // output
        .lcp_state(lcp_state), // output, for simulation only
        .i2c_master_state(i2c_master_state), // output, for simulation only
        .timer_state(timer_state), // output, for simulated only
        .shifter_state_1(shifter_state_1), // output
        .shifter_state_2(shifter_state_2), // output

        .scan_clock_timer_state_1(scan_clock_timer_state_1), // output
        .scan_clock_timer_state_2(scan_clock_timer_state_2), // output
        
        .transceiver_select(TRC_SEL) // input
        
        );
            
            
    
endmodule
