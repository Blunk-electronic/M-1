//`define simulation // comment if NO simulation
//`define testbench_local // comment if NO local testbench
    
parameter firmware_version = 16'h0002;

// DEFINES
 // external defines
`define DEL 1

 // internal defines
`define byte_width 8    
`define nibble_width 4
`define tap_state_width 4

// I2C SLAVE ADDRESSES
parameter drv_char_tap1a_adr = 7'h30; // write address 60h	
parameter drv_char_tap1b_adr = 7'h31; // write address 62h	
parameter drv_char_tap2a_adr = 7'h32; // write address 64h	
parameter drv_char_tap2b_adr = 7'h33; // write address 66h	
parameter vltg_tap_1 = 7'h2E; // write address 5Ch
parameter vltg_tap_2 = 7'h2F; // write address 5Eh

// DISPLAY
parameter common_anode = 1'b0; // means we have common cathodes

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
