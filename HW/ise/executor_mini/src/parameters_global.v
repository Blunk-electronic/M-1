////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////


//`define simulation // comment if NO simulation
//`define testbench_local // comment if NO local testbench
//`define tck_frequency_sim // UNcomment if tck frequency is to be static (independed of vec file)
`define respect_fail // comment if fails are to be ignored. CAUTION !!!
    
parameter firmware_version = 16'h0013;

// DEFINES
 // external defines
`define hardware_ex_v22_sub_v10

`define cpu_addr_width 16
`define cpu_data_width 8
`define cpu_reserved_width 8

`define ram_addr_width_max 24
`define ram_addr_width 19
`define ram_addr_width_excess 5 // 24-19
`define ram_data_width 8

`define gpio_width 4

`define debug_width 3 // used for debug and status LEDS

 // internal defines
`define byte_width 8    
`define nibble_width 4
`define command_width 8

// RAM INIT
`ifdef simulation
    `define highest_addr_to_init 4 // FOR SIMULATION
`else
    `define highest_addr_to_init (2**`ram_addr_width)-1 // FOR REAL MODE
`endif

`define chain_length_max (2**32)-1
`define chain_length_width 32
`define chain_byte_count_width 29 // due to divison of chain length by 8 // must be chain_length_width - 3
`define step_id_width 16
`define test_step_ct_width 16
`define executor_state_width 8
`define tap_state_width 4
`define tdi_diagnosis_tap_1_2_width 8

`define ram_wait_states_we 1 // keeps WE for 100ns low @ 50Mhz master clock

`define DEL 1

`define mmu_state_width 4
`define path_width 4

`define executor_state_width 8

////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////

`define compiler_version_major_width 8
`define compiler_version_minor_width 8
parameter compiler_version_major_required = `compiler_version_major_width'h05; // currently v05
parameter compiler_version_minor_required = `compiler_version_minor_width'h00; // currently don't care

`define vector_format_version_major_width 8
`define vector_format_version_minor_width 8
parameter vec_format_version_major_required = `vector_format_version_major_width'h00; // currently v00
parameter vec_format_version_minor_required = `vector_format_version_minor_width'h00; // currently don't care

`define scanpath_count_max 2 //CS: currently only two scanpaths supported
`define scanpath_pointer_width 2 // NOTE: scanpath_count_max is 2**scanpath_pointer_width
parameter scanpath_count_max = `scanpath_pointer_width'd`scanpath_count_max;
`define active_scanpath_width 8 // applies for reading the active_scanpath byte in vec file
`define active_scanpath_max 3 // bit set if scanpath active // currently 3 -> means scanport 1 and 2
parameter active_scanpath_max = `active_scanpath_width'd`active_scanpath_max; 

`define scanpath_base_address_width 32

//`define scan_clock_prescale_width 16

parameter init_state_trst   = -1; 
parameter init_state_tck    = 0; 
parameter init_state_tms    = -1; // safety measure that moves all tap state machines to test-logic-reset
parameter init_state_tdo    = -1; // safety measure that sets all bics in bypass (if tck running)
parameter init_state_exp    = -1;
parameter init_state_mask   = -1;
parameter init_state_fail   = 0;

///MMU/////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////

parameter [`mmu_state_width-1:0] 
    MMU_STATE_IDLE              =  0,
    MMU_STATE_INIT1             =  1,
    MMU_STATE_INIT2             =  2,        
    MMU_STATE_INIT3             =  3,
    MMU_STATE_INIT4             =  8,
    MMU_STATE_ROUT1             =  4,
    MMU_STATE_RF_WRITE_RAM1     =  5,
    MMU_STATE_RF_WRITE_RAM2     = 10,
    MMU_STATE_RF_WRITE_RAM_WAIT = 13, // Dh
    MMU_STATE_EX_READ_RAM_WAIT  = 14, // Eh
    MMU_STATE_EX_READ_RAM1      =  6,        
    MMU_STATE_EX_READ_RAM2      =  7,
    MMU_STATE_RF_READ_RAM       =  9,
    MMU_STATE_WAIT1             = 11, // Bh
    MMU_STATE_WAIT_CYCLE        = 12; // Ch


parameter [`path_width-1:0]
    path_rf_writes_ram  = 4'h0,
    path_rf_reads_ram   = 4'h1,    
    path_ex_reads_ram   = 4'h5,
    path_null           = 4'hF; // breaks all paths
    

    
    
///EXECUTOR///////////////////////////////////////////////////////////////////////////////////////    

////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////
    
parameter [`command_width-1:0]
    //cmd_null            = `command_width'h00,
    cmd_null            = `command_width'hFF,
    cmd_clear_ram       = `command_width'h20,
    //cmd_test_start      = `command_width'h01, // CS: add to bsc.asm header
    cmd_test_halt       = `command_width'h02,
    cmd_test_abort      = `command_width'h03,
    cmd_step_test       = `command_width'h10, //low nibble of mode determines step width
    cmd_step_tck        = `command_width'h11, //low nibble of mode determines step width    
    cmd_step_sxr        = `command_width'h12; //low nibble of mode determines step width
    
// EXECUTOR STATES 
parameter [`executor_state_width-1:0]
    EX_STATE_IDLE                   = `executor_state_width'h00,
    EX_STATE_SET_START_ADR          = `executor_state_width'h01,
    
    EX_STATE_RD_COMP_VER_MAJOR      = `executor_state_width'h02,
    EX_STATE_RD_COMP_VER_MINOR      = `executor_state_width'h03,
    EX_STATE_CHK_VER_COMP           = `executor_state_width'h04,    
    EX_STATE_ERROR_COMPILER_1       = `executor_state_width'hF0,
    EX_STATE_ERROR_COMPILER_2       = `executor_state_width'hF1,

    EX_STATE_RD_VEC_FRMT_MAJOR      = `executor_state_width'h05,
    EX_STATE_RD_VEC_FRMT_MINOR      = `executor_state_width'h06,
    EX_STATE_CHK_VER_FRMT           = `executor_state_width'h07,
	EX_STATE_ERROR_FRMT_1           = `executor_state_width'hF2,
    EX_STATE_ERROR_FRMT_2           = `executor_state_width'hF3,
    
    EX_STATE_RD_ACT_SCNPT           = `executor_state_width'h09,
    EX_STATE_CHK_ACT_SCNPT          = `executor_state_width'h0A,
    EX_STATE_ERROR_ACT_SCNPT_1      = `executor_state_width'h0B,
    EX_STATE_ERROR_ACT_SCNPT_2      = `executor_state_width'h08,    
    
    EX_STATE_INC_SCNPT_PTR          = `executor_state_width'h0C,
    EX_STATE_RD_BASE_ADDR_BYTE_0    = `executor_state_width'h0D,
    EX_STATE_RD_BASE_ADDR_BYTE_1    = `executor_state_width'h0E,    
    EX_STATE_RD_BASE_ADDR_BYTE_2    = `executor_state_width'h0F,
    EX_STATE_RD_BASE_ADDR_BYTE_3    = `executor_state_width'h10,        

    EX_STATE_RD_FRQ_TCK             = `executor_state_width'h11,
    EX_STATE_SET_FRQ_TCK            = `executor_state_width'h12,
    
    EX_STATE_RD_THRSHLD_TDI_1       = `executor_state_width'h14,
    EX_STATE_SET_THRSHLD_TDI_1      = `executor_state_width'h15,
    EX_STATE_RD_THRSHLD_TDI_2       = `executor_state_width'h16,
    EX_STATE_SET_THRSHLD_TDI_2      = `executor_state_width'h17,    
    
    EX_STATE_RD_VLTG_OUT_SP_1       = `executor_state_width'h18,
    EX_STATE_SET_VLTG_OUT_SP_1      = `executor_state_width'h19,    
    EX_STATE_RD_VLTG_OUT_SP_2       = `executor_state_width'h1A,
    EX_STATE_SET_VLTG_OUT_SP_2      = `executor_state_width'h1B,    
    
    EX_STATE_RD_DRV_TMS_TCK_SP_1    = `executor_state_width'h1C,
    EX_STATE_SET_DRV_TMS_TCK_SP_1   = `executor_state_width'h1D,        
    EX_STATE_RD_DRV_TRST_TDO_SP_1   = `executor_state_width'h1E,
    EX_STATE_SET_DRV_TRST_TDO_SP_1  = `executor_state_width'h1F,        

    EX_STATE_RD_DRV_TMS_TCK_SP_2    = `executor_state_width'h20,
    EX_STATE_SET_DRV_TMS_TCK_SP_2   = `executor_state_width'h21,        
    EX_STATE_RD_DRV_TRST_TDO_SP_2   = `executor_state_width'h22,
    EX_STATE_SET_DRV_TRST_TDO_SP_2  = `executor_state_width'h23,        
    
    EX_STATE_RD_TEST_STP_CT_TOT_1   = `executor_state_width'h24,
    EX_STATE_RD_TEST_STP_CT_TOT_2   = `executor_state_width'h25, 
    
////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////    
        
    EX_STATE_RD_STEP_ID_BYTE_0      = `executor_state_width'h26,
    EX_STATE_RD_STEP_ID_BYTE_1      = `executor_state_width'h27,
    EX_STATE_EVAL_STEP_ID           = `executor_state_width'h28,
    
    EX_STATE_RD_LC_BYTE_0           = `executor_state_width'h29,
    EX_STATE_RD_LC_BYTE_1           = `executor_state_width'h2A,
    EX_STATE_RD_LC_BYTE_2           = `executor_state_width'h2B,    
    EX_STATE_EXCT_LC                = `executor_state_width'h2C,

    EX_STATE_EVAL_RETRY_0           = `executor_state_width'h2F,
    //EX_STATE_SET_LC_BYTE_2          = `executor_state_width'h31,

    EX_STATE_RETRY_DELAY_1          = `executor_state_width'h30,
    EX_STATE_RD_SXR_TYPE            = `executor_state_width'h40,
    EX_STATE_EVAL_SXR_TYPE          = `executor_state_width'h41,
    EX_STATE_RD_RETRY               = `executor_state_width'h13,    
    EX_STATE_RD_DELAY               = `executor_state_width'h42,
    
    
    EX_STATE_RD_SXR_SP_ID_1         = `executor_state_width'h43,
    EX_STATE_RD_SXR_SP_ID_2         = `executor_state_width'h44,
    EX_STATE_RD_SXR_SP_ID_3         = `executor_state_width'h45,
    EX_STATE_RD_SXR_SP_ID_4         = `executor_state_width'h46,    
    EX_STATE_ERROR_RD_SXR_SP_ID_1   = `executor_state_width'h47,
    EX_STATE_ERROR_RD_SXR_SP_ID_2   = `executor_state_width'h5E,    
    
    EX_STATE_RD_SXR_LENGTH_1        = `executor_state_width'h48,
    EX_STATE_RD_SXR_LENGTH_2        = `executor_state_width'h49,
    EX_STATE_RD_SXR_LENGTH_3        = `executor_state_width'h4A,
    EX_STATE_RD_SXR_LENGTH_4        = `executor_state_width'h4B,
    EX_STATE_RD_SXR_LENGTH_5        = `executor_state_width'h4C,
    EX_STATE_RD_SXR_LENGTH_6        = `executor_state_width'h4D,    
    EX_STATE_RD_SXR_LENGTH_7        = `executor_state_width'h4E,    
    EX_STATE_RD_SXR_LENGTH_8        = `executor_state_width'h4F,
    EX_STATE_RD_SXR_LENGTH_9        = `executor_state_width'h50,
    
    EX_STATE_RD_SXR_DRV_MSK_EXP_1   = `executor_state_width'h51,
    EX_STATE_RD_SXR_DRV_MSK_EXP_2   = `executor_state_width'h52,    
    EX_STATE_RD_SXR_DRV_MSK_EXP_3   = `executor_state_width'h53,
    EX_STATE_RD_SXR_DRV_MSK_EXP_4   = `executor_state_width'h54,     
    EX_STATE_RD_SXR_DRV_MSK_EXP_5   = `executor_state_width'h55,    
    EX_STATE_RD_SXR_DRV_MSK_EXP_6   = `executor_state_width'h56,
    EX_STATE_RD_SXR_DRV_MSK_EXP_7   = `executor_state_width'h57,
    EX_STATE_RD_SXR_DRV_MSK_EXP_8   = `executor_state_width'h58,
    EX_STATE_RD_SXR_DRV_MSK_EXP_9   = `executor_state_width'h59,        
    
    EX_STATE_SHIFT_DRV_MSK_EXP_1    = `executor_state_width'h5A,
    EX_STATE_SHIFT_DRV_MSK_EXP_2    = `executor_state_width'h5B,
    EX_STATE_WAIT_STEP_SXR          = `executor_state_width'h5C,        
    
    EX_STATE_RD_SXR_LENGTH_10       = `executor_state_width'h5D,    
    
    EX_STATE_END_OF_TEST            = `executor_state_width'hE0,
    EX_STATE_TEST_FAIL_1            = `executor_state_width'hE1,
    EX_STATE_TEST_FAIL_2            = `executor_state_width'hE2,
    EX_STATE_TEST_FAIL_3            = `executor_state_width'hE3,
    EX_STATE_TEST_FAIL_4            = `executor_state_width'hEA,
    EX_STATE_TEST_FAIL_5            = `executor_state_width'hEB,
    
    EX_STATE_TEST_ABORT_1           = `executor_state_width'hE4,
    EX_STATE_TEST_ABORT_2           = `executor_state_width'hE5,
    EX_STATE_TEST_ABORT_3           = `executor_state_width'hE6,
    EX_STATE_TEST_ABORT_4           = `executor_state_width'hE7, 
    EX_STATE_TEST_ABORT_5           = `executor_state_width'hE8,
    EX_STATE_TEST_ABORT_6           = `executor_state_width'hE9,       
    
    EX_STATE_NOP                    = `executor_state_width'hFF;   
    
parameter [`step_id_width-1:0]
    step_id_low_level_cmd           = `step_id_width'h0000,
    step_id_label                   = `step_id_width'h8000;
    
///LOW LEVEL COMMAND PROCESSOR////////////////////////////////////////////////////////////////////    

////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////
    
// LOW LEVEL COMMAND PROCESSOR STATES
parameter [`byte_width-1:0] 
    LCP_STATE_IDLE                  = `byte_width'h00,
    LCP_STATE_SET_FRQ               = `byte_width'h01,
    LCP_STATE_I2C_RDY               = `byte_width'h02,
    
    LCP_STATE_SET_SUB_BUS_1_DAC_1   = `byte_width'h03,
    LCP_STATE_SET_SUB_BUS_1_DAC_2   = `byte_width'h04,
    LCP_STATE_SET_SUB_BUS_1_DAC_3   = `byte_width'h05,
    LCP_STATE_SET_SUB_BUS_1_DAC_4   = `byte_width'h06,        
    LCP_STATE_SET_SUB_BUS_1_DAC_5   = `byte_width'h07,
    LCP_STATE_SET_SUB_BUS_1_DAC_6   = `byte_width'h08,
    LCP_STATE_SET_SUB_BUS_1_DAC_7   = `byte_width'h09,
    LCP_STATE_SET_SUB_BUS_1_DAC_8   = `byte_width'h0A,
    LCP_STATE_SET_SUB_BUS_1_DAC_9   = `byte_width'h0B,
    
    LCP_STATE_SET_MAIN_DRV_CHAR_1   = `byte_width'h0C,
    LCP_STATE_SET_MAIN_DRV_CHAR_2   = `byte_width'h0D,
    LCP_STATE_SET_MAIN_DRV_CHAR_3   = `byte_width'h0E,
    LCP_STATE_SET_MAIN_DRV_CHAR_4   = `byte_width'h0F,
    
    LCP_STATE_START_TIMER_1         = `byte_width'h10,
    LCP_STATE_START_TIMER_2         = `byte_width'h11,
    
    LCP_STATE_SET_SUB_BUS_2_PWR_1   = `byte_width'h12,
    LCP_STATE_SET_SUB_BUS_2_PWR_2   = `byte_width'h13,
    LCP_STATE_SET_SUB_BUS_2_PWR_3   = `byte_width'h14,
    LCP_STATE_SET_SUB_BUS_2_PWR_4   = `byte_width'h15,
    LCP_STATE_SET_SUB_BUS_2_PWR_5   = `byte_width'h16,
    LCP_STATE_SET_SUB_BUS_2_PWR_6   = `byte_width'h17,
    LCP_STATE_SET_SUB_BUS_2_PWR_7   = `byte_width'h18,
    LCP_STATE_SET_SUB_BUS_2_PWR_8   = `byte_width'h19,
    LCP_STATE_SET_SUB_BUS_2_PWR_9   = `byte_width'h1A, 

    LCP_STATE_TAP_TRST_1            = `byte_width'h1B,
    LCP_STATE_TAP_TRST_2            = `byte_width'h1C,
    LCP_STATE_TAP_TRST_3            = `byte_width'h1D,
    LCP_STATE_TAP_TRST_4            = `byte_width'h1E,    
    
    LCP_STATE_SET_MAIN_DRV_VLTGE_1  = `byte_width'h1F,
    LCP_STATE_SET_MAIN_DRV_VLTGE_2  = `byte_width'h20,
    LCP_STATE_SET_MAIN_DRV_VLTGE_3  = `byte_width'h21,
    LCP_STATE_SET_MAIN_DRV_VLTGE_4  = `byte_width'h22,
    
	LCP_STATE_SEND_DONE_TO_EX		= `byte_width'h23,
    // states 24h - 29h not used
    
////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////    
    
    LCP_STATE_SET_SUB_BUS_3_DAC_1   = `byte_width'h2A,
    LCP_STATE_SET_SUB_BUS_3_DAC_2   = `byte_width'h2B,    
    LCP_STATE_SET_SUB_BUS_3_DAC_3   = `byte_width'h2C,    
    LCP_STATE_SET_SUB_BUS_3_DAC_4   = `byte_width'h2D,
    LCP_STATE_SET_SUB_BUS_3_DAC_5   = `byte_width'h2E,
    LCP_STATE_SET_SUB_BUS_3_DAC_6   = `byte_width'h2F,
    LCP_STATE_SET_SUB_BUS_3_DAC_7   = `byte_width'h30,    
    LCP_STATE_SET_SUB_BUS_3_DAC_8   = `byte_width'h31,
    LCP_STATE_SET_SUB_BUS_3_DAC_9   = `byte_width'h32,
    
    LCP_STATE_SET_SUB_BUS_2_TIMEOUT_1   = `byte_width'h33,
    LCP_STATE_SET_SUB_BUS_2_TIMEOUT_2   = `byte_width'h34,
    LCP_STATE_SET_SUB_BUS_2_TIMEOUT_3   = `byte_width'h35,
    LCP_STATE_SET_SUB_BUS_2_TIMEOUT_4   = `byte_width'h36,
    LCP_STATE_SET_SUB_BUS_2_TIMEOUT_5   = `byte_width'h37,
    LCP_STATE_SET_SUB_BUS_2_TIMEOUT_6   = `byte_width'h38,
    LCP_STATE_SET_SUB_BUS_2_TIMEOUT_7   = `byte_width'h39,
    LCP_STATE_SET_SUB_BUS_2_TIMEOUT_8   = `byte_width'h3A,
    
    LCP_STATE_SET_MAIN_CONNECT_1    = `byte_width'h3B,
    LCP_STATE_SET_MAIN_CONNECT_2    = `byte_width'h3C,
    LCP_STATE_SET_MAIN_CONNECT_3    = `byte_width'h3D,
    LCP_STATE_SET_MAIN_CONNECT_4    = `byte_width'h3E,
   
    LCP_STATE_ERROR_ARG1            = `byte_width'hF1,        
    LCP_STATE_ERROR_ARG2            = `byte_width'hF2,        
    LCP_STATE_ERROR_CMD             = `byte_width'hFC,    
    LCP_STATE_NOP                   = `byte_width'hFF;

// LOW LEVEL COMMAND HEADERS (passed to low level command processor as command byte)   
// NOTE: SOME COMMANDS HAVE NO EFFECT SINCE THIS HW DOES NOT FEATURE POWER RELAYS. CURRENT MONITORING AND SCANPORT RELAYS !
parameter lc_set_frq_tck            = `byte_width'h01;
parameter lc_set_sp_thrshld_tdi     = `byte_width'h02; // arg1 specifies scanport id, arg2 -> DAC value
parameter lc_set_sp_vltg_out        = `byte_width'h03; // arg1 specifies scanport id, arg2 -> DAC value
parameter lc_set_drv_chr_tms_tck    = `byte_width'h04; // arg1 specifies scanport id, arg2 -> characteristic
parameter lc_set_drv_chr_trst_tdo   = `byte_width'h05; // arg1 specifies scanport id, arg2 -> characteristic

parameter lc_delay                  = `byte_width'h06; // arg1 specifies delay. arg1 * 0.1s = delay, arg2 = lc_delay_arg2 (always zero)
parameter lc_power_on_off           = `byte_width'h07; // arg1 specifies pwr channel id, arg2 -> on/off    
parameter lc_set_imax               = `byte_width'h08; // arg1 specifies pwr channel id, arg2 -> imax
parameter lc_set_timeout            = `byte_width'h09; // arg1 specifies pwr channel id, arg2 -> timeout
parameter lc_connect_disconnect     = `byte_width'h0A; // arg1 specifies scanport id, arg2 -> on/off
parameter lc_tap_state              = `byte_width'h0B; // arg1 specifies targeted tap state (applies for all scanports)
parameter lc_tap_pulse_tck          = `byte_width'h0C; // arg1 specifies number of clk pulses, arg2 -> multiplier 10^arg2

// LOW LEVEL COMMANDS ARGUMENT 1

// argument 1 for command lc_connect_disconnect // CS: lc_all for (dis)connecting all scanports at once -> rework of trc required,
//                                                     because of differing i2c slave addresses of relay drivers.
parameter lc_scanport_1             = `byte_width'h01;
parameter lc_scanport_2             = `byte_width'h02;

// argument 1 for command lc_power_on_off
parameter lc_pwr_gnd                = `byte_width'h00;
parameter lc_pwr_1                  = `byte_width'h01;
parameter lc_pwr_2                  = `byte_width'h02;
parameter lc_pwr_3                  = `byte_width'h03;
parameter lc_pwr_all                = `byte_width'hFF;

// argument 1 for command lc_tap_state
parameter lc_tap_trst               = `byte_width'h00;
parameter lc_tap_strst              = `byte_width'h01;
parameter lc_tap_htrst              = `byte_width'h02;
parameter lc_tap_rti                = `byte_width'h03;
parameter lc_tap_pdr                = `byte_width'h04;
parameter lc_tap_pir                = `byte_width'h05;

// LOW LEVEL COMMAND ARGUMENT 2
parameter lc_off                    = `byte_width'h00;
parameter lc_on                     = `byte_width'h01;
parameter lc_delay_arg2             = `byte_width'h00; // always zero

parameter lc_null_argument          = `byte_width'h00;

////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////

///I2C/////////////////////////////////////////////////////////////////////////////////////////////

// I2C PARAMETERS
`ifdef simulation
    parameter i2c_wait_count_init   = `byte_width'h01; // FOR SIMULATION
`else
    parameter i2c_wait_count_init   = `byte_width'h44; // FOR REAL MODE // 1.4us longest time required for DACs //CS: check all slaves
`endif


// I2C MASTER STATES
parameter [`byte_width-1:0]
    I2C_MASTER_STATE_IDLE       = `byte_width'h00,
    I2C_MASTER_STATE_WAIT       = `byte_width'h01,
    I2C_MASTER_STATE_STOP_1     = `byte_width'h02, 
    I2C_MASTER_STATE_STOP_2     = `byte_width'h03,
    I2C_MASTER_STATE_START_1    = `byte_width'h04, 
    I2C_MASTER_STATE_START_2    = `byte_width'h05,
    I2C_MASTER_STATE_TX_1       = `byte_width'h06,
    I2C_MASTER_STATE_TX_2       = `byte_width'h07,
    I2C_MASTER_STATE_TX_3       = `byte_width'h08,
    I2C_MASTER_STATE_TX_4       = `byte_width'h09,
    I2C_MASTER_STATE_TX_5       = `byte_width'h0A,
    I2C_MASTER_STATE_TX_6       = `byte_width'h0B,
    I2C_MASTER_STATE_TX_7       = `byte_width'h0C,
    I2C_MASTER_STATE_TX_8       = `byte_width'h0D,
    I2C_MASTER_STATE_TX_9       = `byte_width'h0E,    
    I2C_MASTER_STATE_ERROR      = `byte_width'h0F,                
    I2C_MASTER_STATE_NOP        = `byte_width'hFF;
    
// I2C BUS 
//  WRITE ACCESS SLAVE ADDRESSES (lsb cleared for write access)
parameter [`byte_width-1:0] 
    i2c_addr_main_muxer                    = `byte_width'h20,
	i2c_addr_main_relays_tap_1             = `byte_width'h40,
	i2c_addr_main_relays_tap_2             = `byte_width'h42,
	i2c_addr_main_drv_char_tck_tms_tap_1   = `byte_width'h60,
	i2c_addr_main_drv_char_tdo_trst_tap_1  = `byte_width'h62,
	i2c_addr_main_drv_char_tck_tms_tap_2   = `byte_width'h64,
	i2c_addr_main_drv_char_tdo_trst_tap_2  = `byte_width'h66,

    i2c_addr_vltg_tap_1						= `byte_width'h5C,
	i2c_addr_vltg_tap_2						= `byte_width'h5E,
	
    tap_driver_vltg_1V5                    = `byte_width'd115, // equals (1V5 * 255)/3V3
    tap_driver_vltg_1V8                    = `byte_width'd139, // equals (1V8 * 255)/3V3
    tap_driver_vltg_2V5                    = `byte_width'd193, // equals (2V5 * 255)/3V3
    tap_driver_vltg_3V3                    = `byte_width'd255, // equals (3V3 * 255)/3V3
    
    i2c_data_driver_vltg_1V5               = `byte_width'b00000001, // sets V to 1V5
    i2c_data_driver_vltg_1V8               = `byte_width'b00000010, // sets V to 1V8
    i2c_data_driver_vltg_2V5               = `byte_width'b00000100, // sets V to 2V5
    i2c_data_driver_vltg_3V3               = `byte_width'b00000000, // sets V to 3V3    
	
	i2c_data_muxer_select_sub_bus_1        = `byte_width'h08, // bit 3 enable/disable, bit 2:0 bus number
	i2c_data_muxer_select_sub_bus_2        = `byte_width'h09,	
	i2c_data_muxer_select_sub_bus_3        = `byte_width'h0A,
	i2c_data_muxer_select_sub_bus_4        = `byte_width'h0B,
	
	i2c_data_relays_off                    = `byte_width'hFF, // scanpath relays !
	i2c_data_relays_on                     = `byte_width'hFC, // relay gnd, tap on // CS: dio, aio ?	
	
    i2c_addr_thrshld_tdi_1                 = `byte_width'h58,
    i2c_addr_thrshld_tdi_2                 = `byte_width'h5A,
    
	// command byte for DAC MAX517 and MAX519 (general use when addressing DACs of this kind)
	i2c_data_dac_cmd                       = `byte_width'h00;     
    
 
/// TIMER /////////////////////////////////////////////////////////////////////////////
`define timer_counter_width 23 // sufficient to count until timer_ticks_for_0_1_sec_timeout

parameter [`timer_counter_width-1:0] 
// clocks required for 0.1 seconds @ 50Mhz master clock
`ifdef simulation
    timer_ticks_for_0_1_sec_timeout = `timer_counter_width'd10; 
`else
    timer_ticks_for_0_1_sec_timeout = `timer_counter_width'd5000000; 
`endif

`define timer_state_width 2
parameter [`byte_width-1:0]
    TIMER_STATE_IDLE        = `byte_width'h00,
    TIMER_STATE_1           = `byte_width'h01,
    TIMER_STATE_2           = `byte_width'h02;  
    
/// SXR EXECUTION ////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////

// SXR TYPES
// parameter [`byte_width-1:0]
//     mark_sir_hstrst			        = `byte_width'h02,
// 	mark_sir_hstrst_retry	        = `byte_width'h06,
// 	mark_sdr_hstrst			        = `byte_width'h01,
// 	mark_sdr_hstrst_retry	        = `byte_width'h05,
// 	mark_sir_pwrdown		        = `byte_width'h04,
// 	mark_sir_pwrdown_retry	        = `byte_width'h08,
// 	mark_sdr_pwrdown		        = `byte_width'h03,
// 	mark_sdr_pwrdown_retry	        = `byte_width'h07,
// 
// //	mark_sxr_offset			: unsigned_8	:= 16#10#;
// 
// 	mark_sir_hstrst_end_pir			= `byte_width'h12,
// 	mark_sir_hstrst_end_pir_retry	= `byte_width'h16,
// 	mark_sdr_hstrst_end_pdr			= `byte_width'h11,
// 	mark_sdr_hstrst_end_pdr_retry	= `byte_width'h15,
// 	mark_sir_pwrdown_end_pir		= `byte_width'h14,
// 	mark_sir_pwrdown_end_pir_retry	= `byte_width'h18,
// 	mark_sdr_pwrdown_end_pdr		= `byte_width'h13,
// 	mark_sdr_pwrdown_end_pdr_retry	= `byte_width'h17;

// 	SXR MARKER (8 bit) --
// 	bit meaning:
// 	7 (MSB) : 1 -> sir, 0 -> sdr
// 	6       : 1 -> end state RTI, 0 -> end state Pause-XR
// 	5       : 1 -> on fail: hstrst
// 	4       : 1 -> on fail: power down (priority in executor)
// 	3       : 1 -> on fail: finish sxr (CS: not implemented yet)
// 	2       : 1 -> retry on, 0 -> retry off
// 	1:0     : not used yet


	
/// SHIFTER ///////////////////////////////////////////////////////////////////////////////

parameter [`byte_width-1:0]
    SHIFTER_STATE_IDLE                  = `byte_width'h00,
    
    // SXR SCAN INITIAL PHASE
    SHIFTER_STATE_EVAL_TAP_STATE        = `byte_width'h01,
    SHIFTER_STATE_TLR_TO_SELDR_1        = `byte_width'h02,    
    SHIFTER_STATE_TLR_TO_SELDR_2        = `byte_width'h03,    
    SHIFTER_STATE_TLR_TO_SELDR_3        = `byte_width'h04,    
    SHIFTER_STATE_TLR_TO_SELDR_4        = `byte_width'h05,    

    SHIFTER_STATE_EVAL_SXR_TYPE         = `byte_width'h06,
    
    // DR SCAN BRANCH OF TAP CONTROLLER
    SHIFTER_STATE_SELDR_TO_SHIFTDR_1    = `byte_width'h07,
    SHIFTER_STATE_SELDR_TO_SHIFTDR_2    = `byte_width'h08,
    SHIFTER_STATE_SELDR_TO_SHIFTDR_3    = `byte_width'h09,
    
    SHIFTER_STATE_SHIFTDR_1             = `byte_width'h0A,
    SHIFTER_STATE_SHIFTDR_2             = `byte_width'h0B,
    SHIFTER_STATE_SHIFTDR_3             = `byte_width'h0C,
    SHIFTER_STATE_SHIFTDR_4             = `byte_width'h0D,       
    
    SHIFTER_STATE_EXIT1DR_1             = `byte_width'h0E,
    SHIFTER_STATE_PAUSEDR_1             = `byte_width'h0F,
    SHIFTER_STATE_PAUSEDR_2             = `byte_width'h10,
    SHIFTER_STATE_PAUSEDR_3             = `byte_width'h11,        
    SHIFTER_STATE_EXIT2DR_1             = `byte_width'h12,
    SHIFTER_STATE_EXIT2DR_2             = `byte_width'h13,
    SHIFTER_STATE_UPDATEDR_1            = `byte_width'h14,
    SHIFTER_STATE_UPDATEDR_2            = `byte_width'h15,    
    
    // RETURN FROM UPDATE-XR TO RTI OR SELECT-DR-SCAN
    SHIFTER_STATE_RTI_1                 = `byte_width'h16,
    SHIFTER_STATE_RTI_2                 = `byte_width'h17,

    // IR SCAN BRANCH OF TAP CONTROLLER    
    SHIFTER_STATE_SELDR_TO_SELIR        = `byte_width'h18,
    SHIFTER_STATE_SELIR_TO_SHIFTIR_1    = `byte_width'h19,
    SHIFTER_STATE_SELIR_TO_SHIFTIR_2    = `byte_width'h1A,
    SHIFTER_STATE_SELIR_TO_SHIFTIR_3    = `byte_width'h1B,
    SHIFTER_STATE_SELIR_TO_SHIFTIR_4    = `byte_width'h1C,
    SHIFTER_STATE_SHIFTIR_1             = `byte_width'h1D,
    SHIFTER_STATE_SHIFTIR_2             = `byte_width'h1E,
    SHIFTER_STATE_SHIFTIR_3             = `byte_width'h1F,
    SHIFTER_STATE_SHIFTIR_4             = `byte_width'h20,    
    
    SHIFTER_STATE_EXIT1IR_1             = `byte_width'h21,
    SHIFTER_STATE_PAUSEIR_1             = `byte_width'h22,
    SHIFTER_STATE_PAUSEIR_2             = `byte_width'h23,
    SHIFTER_STATE_PAUSEIR_3             = `byte_width'h24,        
    SHIFTER_STATE_EXIT2IR_1             = `byte_width'h25,
    SHIFTER_STATE_EXIT2IR_2             = `byte_width'h26,
    SHIFTER_STATE_UPDATEIR_1            = `byte_width'h27,
    SHIFTER_STATE_UPDATEIR_2            = `byte_width'h28,    

    //SHIFTER_STATE_FAIL                  = `byte_width'hEF,    
    
    SHIFTER_STATE_ERROR_0               = `byte_width'hF0,
    SHIFTER_STATE_ERROR_1               = `byte_width'hF1,
    SHIFTER_STATE_ERROR_2               = `byte_width'hF2,    
    SHIFTER_STATE_ERROR_3               = `byte_width'hF3,
    SHIFTER_STATE_ERROR_4               = `byte_width'hF4,
    SHIFTER_STATE_ERROR_5               = `byte_width'hF5,
    SHIFTER_STATE_ERROR_6               = `byte_width'hF6,
    SHIFTER_STATE_ERROR_7               = `byte_width'hF7,        
    SHIFTER_STATE_ERROR_8               = `byte_width'hF8,
    //SHIFTER_STATE_ERROR_9               = `byte_width'hF9, // with new sxr_type mechanism not required any more
    //SHIFTER_STATE_ERROR_10              = `byte_width'hFA, // with new sxr_type mechanism not required any more
    SHIFTER_STATE_ERROR_11              = `byte_width'hFB,
    SHIFTER_STATE_NOP                   = `byte_width'hFF;        
    

////////////////////////////////////////////////////////////////////
// CAUTION: UPDATE M1_FIRMWARE.ADS WHEN CHANGING ANYTHING HERE !
////////////////////////////////////////////////////////////////////    
    
/// TAP STATES // CS: adopt proposed values from IEEE1149.1
parameter [`tap_state_width-1:0]
    TAP_TEST_LOGIG_RESET            = `nibble_width'h0,
    TAP_RUN_TEST_IDLE               = `nibble_width'h1,

    TAP_SELECT_DR_SCAN              = `nibble_width'h2,
    TAP_CAPTURE_DR                  = `nibble_width'h3,            
    TAP_SHIFT_DR                    = `nibble_width'h4,
    TAP_EXIT1_DR                    = `nibble_width'h5,
    TAP_PAUSE_DR                    = `nibble_width'h6,
    TAP_EXIT2_DR                    = `nibble_width'h7,
    TAP_UPDATE_DR                   = `nibble_width'h8,    
        
    TAP_SELECT_IR_SCAN              = `nibble_width'h9,
    TAP_CAPTURE_IR                  = `nibble_width'hA,            
    TAP_SHIFT_IR                    = `nibble_width'hB,
    TAP_EXIT1_IR                    = `nibble_width'hC,
    TAP_PAUSE_IR                    = `nibble_width'hD,
    TAP_EXIT2_IR                    = `nibble_width'hE,
    TAP_UPDATE_IR                   = `nibble_width'hF;    
    
    
/// SCAN CLOCK TIMER STATES
`define timer_scan_state_width 2
parameter   [`timer_scan_state_width-1:0]
    TIMER_SCAN_IDLE     = `timer_scan_state_width'h0,
    TIMER_SCAN_STATE_1  = `timer_scan_state_width'h1,
    TIMER_SCAN_STATE_2  = `timer_scan_state_width'h2,
    TIMER_SCAN_WAIT     = `timer_scan_state_width'h3;



////////////////////////////////////////////////////////////////////
/// UUT POWER CONTROL

`define emergency_pwr_off_release 1
`define emergency_pwr_off_unlock 0


////////////////////////////////////////////////////////////////////
/// PUSH BUTTON DEBOUNCERS

`ifdef simulation
    `define debouncer_counter_width 3
    `define debouncer_counter_end 5
`else
    // at 50 Mhz master clock, we must count 5 Mio ticks until 0.1s has elapsed.
    `define debouncer_counter_width 23
    `define debouncer_counter_end 5000000
`endif

parameter edge_falling = 1'b0;
parameter edge_rising = 1'b1;


////////////////////////////////////////////////////////////////////
/// USART
`define uart_data_width 8

`define uart_state_width 5

parameter [`uart_state_width-1:0] 
    UART_STATE_IDLE              =  0,
    UART_STATE_RX_HAM_EDC_1      =  1,
    UART_STATE_RX_HAM_EDC_2      =  2,    
    UART_STATE_COUNT_RX_ERRORS   =  3,
    UART_STATE_READY             =  4,
    UART_STATE_TX_1              =  5,    
    UART_STATE_TX_2              =  6,        
    UART_STATE_TX_3              =  7, 
    UART_STATE_TX_EDC_1          =  8,
    UART_STATE_TX_EDC_2          =  9;    

`define uart_rx_hamming_decoder_edc_width 4    
`define uart_rx_error_counter_width 16
`define uart_tx_hamming_decoder_edc_width 4    
    
`define rs232_state_tx_width 5
`define rs232_state_rx_width 5    

parameter rts_asserted = 1'b0;
parameter cts_asserted = 1'b0;

parameter [`rs232_state_tx_width-1:0] 
    RS232_STATE_TX_RESET            =  0,
    RS232_STATE_TX_IDLE             =  1,
    RS232_STATE_TX_CTS              =  2,
    RS232_STATE_TX_START            =  3,
    RS232_STATE_TX_DATA_0a          =  4,
    RS232_STATE_TX_DATA_0b          =  5,        
    RS232_STATE_TX_DATA_1a          =  6,
    RS232_STATE_TX_DATA_1b          =  7,
    RS232_STATE_TX_DATA_2a          =  8,
    RS232_STATE_TX_DATA_2b          =  9,        
    RS232_STATE_TX_DATA_3a          = 10,
    RS232_STATE_TX_DATA_3b          = 11,        
    RS232_STATE_TX_DATA_4a          = 12,
    RS232_STATE_TX_DATA_4b          = 13,        
    RS232_STATE_TX_DATA_5a          = 14,
    RS232_STATE_TX_DATA_5b          = 15,        
    RS232_STATE_TX_DATA_6a          = 16,
    RS232_STATE_TX_DATA_6b          = 17,
    RS232_STATE_TX_DATA_7a          = 18,
    RS232_STATE_TX_DATA_7b          = 19,        
    RS232_STATE_TX_STOPa            = 20,
    RS232_STATE_TX_STOPb            = 21,
    RS232_STATE_TX_STOPc            = 22;


parameter [`rs232_state_rx_width-1:0] 
    RS232_STATE_RX_RESET            =  0,    
    RS232_STATE_RX_IDLE             =  1,
    RS232_STATE_RX_RTS              =  2,
    RS232_STATE_RX_START            =  3,
    RS232_STATE_RX_DATA_0a          =  4,
    RS232_STATE_RX_DATA_0b          =  5,
    RS232_STATE_RX_DATA_1a          =  6,
    RS232_STATE_RX_DATA_1b          =  7,
    RS232_STATE_RX_DATA_2a          =  8,
    RS232_STATE_RX_DATA_2b          =  9,
    RS232_STATE_RX_DATA_3a          = 10,
    RS232_STATE_RX_DATA_3b          = 11,
    RS232_STATE_RX_DATA_4a          = 12,
    RS232_STATE_RX_DATA_4b          = 13,
    RS232_STATE_RX_DATA_5a          = 14,
    RS232_STATE_RX_DATA_5b          = 15,
    RS232_STATE_RX_DATA_6a          = 16,
    RS232_STATE_RX_DATA_6b          = 17,
    RS232_STATE_RX_DATA_7a          = 18,
    RS232_STATE_RX_DATA_7b          = 19,
    RS232_STATE_RX_STOPa            = 20, // 14h
    RS232_STATE_RX_STOPb            = 21;


`define rs232_timer_counter_width 13

// USART data rate
//                         1
// data_rate = -----------------------------   [ bits/sec ]
//             rs232_delay * 20ns * 10**(-9)
//
//                             1
// rs232_delay = ---------------------------
//               data_rate * 20ns * 10**(-9)
//
// rs232_delay = 5200 for data_rate   9600
// rs232_delay = 1302 for data_rate  38400
// rs232_delay =  868 for data_rate  57600
// rs232_delay =  434 for data_rate 115200
//
// rs232_extra_delay = rs232_delay * 0,5

`ifdef simulation
    parameter [`rs232_timer_counter_width-1:0] rs232_delay = 4;
    parameter [`rs232_timer_counter_width-1:0] rs232_extra_delay = 2;        
`else
//     parameter [`rs232_timer_counter_width-1:0] rs232_delay = 5200;
//     parameter [`rs232_timer_counter_width-1:0] rs232_extra_delay = 2600;
    parameter [`rs232_timer_counter_width-1:0] rs232_delay = 434;
    parameter [`rs232_timer_counter_width-1:0] rs232_extra_delay = rs232_delay / 2;
`endif


`define rs232_timer_state_width 8

parameter [`rs232_timer_state_width-1:0]
    RS232_TIMER_STATE_IDLE      =  0,
    RS232_TIMER_STATE_RUNNING   =  1,
    RS232_TIMER_STATE_DONE      =  2;

`define uart_byte_type_width 3
parameter [`uart_byte_type_width-1:0]
    UART_TYPE_HEADER     = 0,
    UART_TYPE_ADDRESS    = 1,
    UART_TYPE_DATA       = 2,
    UART_TYPE_DATA_PAGE  = 3;    

parameter UART_DIR_WRITE = 1'b0;
parameter UART_DIR_READ  = 1'b1;

parameter UART_PAGE_MODE_OFF    = 1'b0;
parameter UART_PAGE_MODE_ON     = 1'b1;

`define uart_page_byte_counter_width 10
parameter UART_PAGE_SIZE        = 256;

// register names translated from hex notation to names
parameter UART_REG_BASE_ADR = 8'h80;
parameter UART_REG_0 = UART_REG_BASE_ADR+0;
parameter UART_REG_1 = UART_REG_BASE_ADR+1;
parameter UART_REG_2 = UART_REG_BASE_ADR+2;
parameter UART_REG_3 = UART_REG_BASE_ADR+3;
parameter UART_REG_4 = UART_REG_BASE_ADR+4;
parameter UART_REG_5 = UART_REG_BASE_ADR+5;
parameter UART_REG_6 = UART_REG_BASE_ADR+6;
parameter UART_REG_7 = UART_REG_BASE_ADR+7;
parameter UART_REG_8 = UART_REG_BASE_ADR+8;
parameter UART_REG_9 = UART_REG_BASE_ADR+9;	
parameter UART_REG_A = UART_REG_BASE_ADR+10; // 8A	  	
parameter UART_REG_B = UART_REG_BASE_ADR+11; // 8B
parameter UART_REG_C = UART_REG_BASE_ADR+12; // 8C
parameter UART_REG_D = UART_REG_BASE_ADR+13; // 8D
parameter UART_REG_E = UART_REG_BASE_ADR+14; // 8E
parameter UART_REG_F = UART_REG_BASE_ADR+15; // 8F	
parameter UART_REG_10 = UART_REG_BASE_ADR+16; // 90	
parameter UART_REG_11 = UART_REG_BASE_ADR+17; // 91	
parameter UART_REG_12 = UART_REG_BASE_ADR+18; // 92	
parameter UART_REG_13 = UART_REG_BASE_ADR+19; // 93		
parameter UART_REG_14 = UART_REG_BASE_ADR+20; // 94
parameter UART_REG_15 = UART_REG_BASE_ADR+21; // 95
parameter UART_REG_16 = UART_REG_BASE_ADR+22; // 96
parameter UART_REG_17 = UART_REG_BASE_ADR+23; // 97
parameter UART_REG_18 = UART_REG_BASE_ADR+24; // 98	
parameter UART_REG_19 = UART_REG_BASE_ADR+25; // 99	
parameter UART_REG_1A = UART_REG_BASE_ADR+26; // 9A	
parameter UART_REG_1B = UART_REG_BASE_ADR+27; // 9B	
parameter UART_REG_1C = UART_REG_BASE_ADR+28; // 9C	
parameter UART_REG_1D = UART_REG_BASE_ADR+29; // 9D
parameter UART_REG_1E = UART_REG_BASE_ADR+30; // 9E	
parameter UART_REG_1F = UART_REG_BASE_ADR+31; // 9F	
parameter UART_REG_20 = UART_REG_BASE_ADR+32; // A0	
parameter UART_REG_21 = UART_REG_BASE_ADR+33; // A1		
parameter UART_REG_22 = UART_REG_BASE_ADR+34; // A2
parameter UART_REG_23 = UART_REG_BASE_ADR+35; // A3
parameter UART_REG_24 = UART_REG_BASE_ADR+36; // A4
parameter UART_REG_25 = UART_REG_BASE_ADR+37; // A5
parameter UART_REG_26 = UART_REG_BASE_ADR+38; // A6

parameter UART_REG_27 = UART_REG_BASE_ADR+39; // A7
parameter UART_REG_28 = UART_REG_BASE_ADR+40; // A8
parameter UART_REG_29 = UART_REG_BASE_ADR+41; // A9
parameter UART_REG_2A = UART_REG_BASE_ADR+42; // AA
parameter UART_REG_2B = UART_REG_BASE_ADR+43; // AB
parameter UART_REG_2C = UART_REG_BASE_ADR+44; // AC

parameter UART_REG_2D = UART_REG_BASE_ADR+45; // AD
parameter UART_REG_2E = UART_REG_BASE_ADR+46; // AE

parameter UART_REG_2F = UART_REG_BASE_ADR+47; // AF

parameter UART_REG_30 = UART_REG_BASE_ADR+48; // B0
parameter UART_REG_31 = UART_REG_BASE_ADR+49; // B1

