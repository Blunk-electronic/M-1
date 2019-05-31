// 	SXR MARKER (8 bit) --
// 	bit meaning:
// 	7 (MSB) : 1 -> sir, 0 -> sdr
// 	6       : 1 -> end state RTI, 0 -> end state Pause-XR
// 	5       : 1 -> on fail: hstrst
// 	4       : 1 -> on fail: power down (priority in executor)
// 	3       : 1 -> on fail: finish sxr (CS: not implemented yet)
// 	2       : 1 -> retry on, 0 -> retry off
// 	1:0     : not used yet

    
    wire sxr_type_sir                   = sxr_type[7]; 
    wire sxr_type_end_state_rti         = sxr_type[6];
    wire sxr_type_on_fail_hstrst        = sxr_type[5];
    wire sxr_type_on_fail_pwr_down      = sxr_type[4];    
    wire sxr_type_on_fail_finish_sxr    = sxr_type[3];
    wire sxr_type_retry                 = sxr_type[2];
    wire sxr_type_not_used_1            = sxr_type[1];
    wire sxr_type_not_used_0            = sxr_type[0];    
