// V0.3
// V0.4 - I2C support
// V0.5 - llc pwr relays
// V0.6 - exec_states debug1 and disabled not used any more
// V0.7 - firmware_version added
//		  - vec compiler and vec format read from vec file header
// V0.8 - imax for pwr_ctrl added
// V0.9 - sxr_retry supported
// V1.0 - timeout for current watch
// V1.1 - scanpath commands

	parameter firmware_version				= 16'h0007;

// I2C 
	// main bus
	parameter muxer_addr 					= 8'h20;
	parameter rel_tap_1_addr 				= 8'h40;
	parameter rel_tap_2_addr 				= 8'h42;
	parameter drv_char_1_tck_tms_addr 	= 8'h60;
	parameter drv_char_1_tdo_trst_addr	= 8'h62;
	parameter drv_char_2_tck_tms_addr 	= 8'h64;
	parameter drv_char_2_tdo_trst_addr	= 8'h66;
	parameter rel_tap_1_all_off_data		= 8'hFF;
	parameter rel_tap_2_all_off_data		= 8'hFF;	
	
	
	parameter enable_bus_1_data	= 8'b00001000; //	;enable sub-bus 1 (bit 3 enable/disable, bit 2:0 bus number)
	parameter enable_bus_2_data	= 8'b00001001;
	parameter enable_bus_3_data	= 8'b00001010;
	parameter enable_bus_4_data	= 8'b00001011;
	
	// sub-bus 1
	parameter cmp_tdi_1_addr = 8'h58;
	parameter cmp_tdi_2_addr = 8'h5A;
	parameter vcc_tap_1_addr = 8'h5C;	
	parameter vcc_tap_2_addr = 8'h5E;
	parameter dac_cmd 		 = 8'h00; // for MAX517, MAX519

	// sub-bus 2
	parameter pwr_relays_addr			= 8'h4E; // temp. in V0.5 // this is an 8 bit write address !
	parameter imax_timeout_1_adr 		= 8'h50; // ins V1.0	// this is an 8 bit write address !
	parameter imax_timeout_2_adr		= 8'h52; // ins V1.0	// this is an 8 bit write address !
	parameter imax_timeout_3_adr		= 8'h54; // ins V1.0	// this is an 8 bit write address !

	parameter command_byte_imax_dac	= 8'h00; // for MAX517, MAX519
	
	parameter pwr_relay_on_1_data		= 8'hFE;	// L-active output of I2C-expander
	parameter pwr_relay_on_2_data		= 8'hFD;	// L-active output of I2C-expander
	parameter pwr_relay_on_3_data		= 8'hFB;	// L-active output of I2C-expander	
	parameter pwr_relay_on_all_data	= 8'hF0;	// L-active output of I2C-expander		
	parameter pwr_relay_on_gnd_data	= 8'hF7;	// L-active output of I2C-expander

	parameter pwr_relay_off_1_data	= 8'h01;	// L-active output of I2C-expander
	parameter pwr_relay_off_2_data	= 8'h02;	// L-active output of I2C-expander
	parameter pwr_relay_off_3_data	= 8'h04;	// L-active output of I2C-expander	
	parameter pwr_relay_off_all_data	= 8'h0F;	// L-active output of I2C-expander		
	parameter pwr_relay_off_gnd_data	= 8'h08;	// L-active output of I2C-expander
	
	// sub-bus 3
	parameter address_imax_dac_1		= 8'h58;
	parameter address_imax_dac_2		= 8'h5A;
	parameter address_imax_dac_3		= 8'h5C;	
	
// RAM size
	parameter ram_top = 19'hFFFFF;	// top address of output RAM HM628512 (7FFFFh)
	
// on fail action
/*	parameter pwr_off			= 8'h00;
	parameter tap_off			= 8'h01;
	parameter tap_reset		= 8'h02;	
	parameter finish_test	= 8'h03;
	parameter finish_sxr		= 8'h04;	
	parameter halt_sxr		= 8'h00;*/
	
// step width
	parameter no_step			= 4'h0;
	parameter tck_step		= 4'h1;
	parameter sxr_step		= 4'h2;

// low_level_cmd_cmd (llcc) (the cmd itself) or the parameter for llct

	// 30h-llct parameter for scanpath (tap) operations (on executor)
	parameter hs_trst	= 8'h80; // applies for all chains
	parameter s_trst	= 8'h81; // applies for all chains
	parameter h_trst	= 8'h82;	// applies for all chains
	parameter scanpath_reset   = 8'h83; // applies for all chains // ins V1.1
	parameter scanpath_idle    = 8'h84; // applies for all chains // ins V1.1
	parameter scanpath_drpause = 8'h85; // applies for all chains // ins V1.1
	parameter scanpath_irpause = 8'h86; // applies for all chains // ins V1.1
	
	// 40h-llct parameter for tap relay operations (on tranceiver)
	parameter connect_port_1		= 8'h81;
	parameter disconnect_port_1	= 8'h01;
	parameter connect_port_2		= 8'h82;
	parameter disconnect_port_2	= 8'h02;

	parameter set_muxer_sub_bus_1	= 8'h11;	
	parameter set_muxer_sub_bus_2	= 8'h12;
	parameter set_muxer_sub_bus_3	= 8'h13;
	parameter set_muxer_sub_bus_4	= 8'h14;	
	
	// 40h-llct parameter for power relay operations (on tranceiver)
	parameter pwr_relay_on_1		= 8'h83;
	parameter pwr_relay_on_2		= 8'h84;
	parameter pwr_relay_on_3		= 8'h85;
	parameter pwr_relay_on_all		= 8'h86;	
	parameter pwr_relay_on_gnd		= 8'h87;
	
	parameter pwr_relay_off_1		= 8'h03;
	parameter pwr_relay_off_2		= 8'h04;
	parameter pwr_relay_off_3		= 8'h05;
	parameter pwr_relay_off_all	= 8'h06;	
	parameter pwr_relay_off_gnd	= 8'h07;
	
	
	
// low_level_cmd_type (llct)
	parameter time_operation			= 8'h20;  // NOTE: llcc holds delay value (time base 0.1 sec)
	parameter tap_operation				= 8'h30;
	parameter i2c_operation				= 8'h40;
	parameter xi2c_operation_imax_1	= 8'h41; // ins V0.8
	parameter xi2c_operation_imax_2	= 8'h42; // ins V0.8
	parameter xi2c_operation_imax_3	= 8'h43; // ins V0.8	
	parameter xi2c_operation_imax_timeout_1	= 8'h44; // ins V1.0
	parameter xi2c_operation_imax_timeout_2	= 8'h45; // ins V1.0
	parameter xi2c_operation_imax_timeout_3	= 8'h46; // ins V1.0	
	
// llc_state
	parameter llc_unknown		= 8'hFE;
	parameter llc_idle			= 8'h00;
	
	parameter hs_trst_a		 	= 8'h01;
	parameter hs_trst_b		 	= 8'h02;
	parameter hs_trst_c		 	= 8'h03;
	parameter hs_trst_d		 	= 8'h04;
	parameter hs_trst_e		 	= 8'h05;
	parameter hs_trst_f		 	= 8'h06;
	parameter hs_trst_g		 	= 8'h07;
	parameter hs_trst_h		 	= 8'h08;
	parameter hs_trst_i		 	= 8'h09;
	parameter hs_trst_j		 	= 8'h0A;
	parameter hs_trst_k		 	= 8'h0B;	
	parameter hs_trst_j1		 	= 8'h0C;
	parameter hs_trst_k1		 	= 8'h0D;	
	parameter hs_trst_l		 	= 8'h0E;

	parameter h_trst_a		 	= 8'h11;
	parameter h_trst_b		 	= 8'h12;
	parameter h_trst_c		 	= 8'h13;
	parameter h_trst_d		 	= 8'h14;
	parameter h_trst_e		 	= 8'h15;
	parameter h_trst_f		 	= 8'h16;
	parameter h_trst_g		 	= 8'h17;
	parameter h_trst_h		 	= 8'h18;
	parameter h_trst_i		 	= 8'h19;
	parameter h_trst_j		 	= 8'h1A;
	parameter h_trst_k		 	= 8'h1B;	
	parameter h_trst_l		 	= 8'h1C;
   // 1D - 2F free
	parameter scanpath_go_from_tlr_to_tlr				= 8'h37;
	parameter scp_0_a		=	8'h35; // tms up
	parameter scanpath_go_from_tlr_or_rti_to_idle	= 8'h30;
	parameter scp_1_a		=	8'h32; // tms down
	parameter scp_1_b		=	8'h33; // tck up
	parameter scp_1_c		=	8'h34; // tck down, tms down
	// 36 free
	parameter scanpath_go_from_rti_to_tlr				= 8'h38;
	parameter scp_2_a		=	8'h3A; // tms up
	parameter scp_2_b		=	8'h3B; // tck up (enter select-dr-scan)
	parameter scp_2_c		=	8'h3C; // tck down
	parameter scp_2_d		=	8'h3D; // tck up
	parameter scp_2_e		=	8'h3E; // tck down
	parameter scp_2_f		=	8'h3F; // tck up
	parameter scp_2_g		=	8'h40; // tck down

	parameter scanpath_go_from_pause_to_idle			= 8'h31;
	parameter scp_4_a		=	8'h47; // tms up
	parameter scp_4_b		=	8'h48; // tck up (enter exit2-xr)
	parameter scp_4_c		=	8'h49; // tck down
	parameter scp_4_d		=	8'h4A; // tck up (enter update-xr)
	parameter scp_4_e		=	8'h4B; // tck down,tms down
	// 4C free
	
	parameter scanpath_go_from_pause_to_tlr			= 8'h39;
	parameter scp_3_a		=	8'h41; // tms up
	parameter scp_3_b		=	8'h42; // tck up (enter exit2-xr)
	parameter scp_3_c		=	8'h43; // tck down
	parameter scp_3_d		= 	8'h44; // tck up (enter update-xr)
	parameter scp_3_e		= 	8'h45; // tck down
	// 46 free
	
	parameter scanpath_go_from_tlr_to_drpause 		= 8'h4D;
	parameter scp_5_a		=	8'h4E;  // tms down
	parameter scp_5_b		=	8'h4F;  // tck up (enter rti)
	parameter scp_5_c		=	8'h50;  // tck down, tms up
	parameter scp_5_d		=	8'h51;  // tck up (enter select-dr)
	parameter scp_5_e		=	8'h52;  // tck down, tms down
	parameter scp_5_f		=	8'h53;  // tck up (enter capture-dr)
	parameter scp_5_g		=	8'h54;  // tck down, tms up
	parameter scp_5_h		=	8'h55;  // tck up (enter exit1-dr)
	parameter scp_5_i		=	8'h56;  // tck down, tms down
   // 57 free
	
	parameter scanpath_go_from_drpause_to_drpause	= 8'h58;
	parameter scp_6_a		=	8'h59;  // tms up
	parameter scp_6_b		=	8'h5A;  // tck up (enter exit2-dr)
	parameter scp_6_c		=	8'h5B;  // tck down
	parameter scp_6_d		=	8'h5C;  // tck up (enter update-dr)
	parameter scp_6_e		=	8'h5D;  // tck down
	// 5E free
	
	parameter scanpath_go_from_tlr_to_irpause		=	8'h5F;
	parameter scp_7_a		=	8'h60;  // tms down
	parameter scp_7_b		=	8'h61;  // tck up (enter rti)
	parameter scp_7_c		=	8'h62;  // tck down, tms up
	parameter scp_7_d		=	8'h63;  // tck up (enter select-dr)
	parameter scp_7_e		=	8'h64;  // tck down
	// 65 free
	
	parameter scanpath_go_from_irpause_to_irpause	= 8'h66;
	parameter scp_8_a		=	8'h67;  // tms up
	parameter scp_8_b		=	8'h68;  // tck up (enter exit2-ir)
	parameter scp_8_c		=	8'h69;  // tck down
	parameter scp_8_d		=	8'h6A;  // tck up (enter update-ir)
	parameter scp_8_e		=	8'h6B;  // tck down
	
	
	parameter llc_ending_a		= 8'hFC;
	parameter llc_ending_b	 	= 8'hFD;	
	

// vec_state_1
	parameter sxr_idle			= 8'h00;
	parameter sxr_unknown		= 8'hFE;
	parameter chk_chain_state	= 8'hCC;
	parameter tck_up			= 8'hC1;
	parameter tms_up			= 8'hC2;
	parameter tms_down			= 8'hC3;
	
	parameter tms_down_rti		= 8'hC4;
	parameter tck_up_rti		= 8'hC5;
	parameter tms_up_sel_dr		= 8'hC6;
	parameter tck_up_sel_dr		= 8'hC7;

//	parameter sir_default_a		= 8'h81;
//	parameter sir_default_b		= 8'h82;
//	parameter sir_default_c		= 8'h83;
//	parameter sir_default_d		= 8'h84;

	parameter vec_pause			= 8'hA0;

	parameter vec_error			= 8'hE0;
	parameter vec_fail 			= 8'hFA;
	
// sxr types
	parameter sdr_default	=	8'h01;	// sdr going through RTI, on_fail hstrst
	parameter sir_default	=	8'h02;	// sir going through RTI, on_fail hstrst
	parameter sdr_on_fail_pwr_off	=	8'h03;	// sdr going through RTI, on_fail pwr off
	parameter sir_on_fail_pwr_off	=	8'h04;	// sir going through RTI, on_fail pwr off
	parameter sdr_retry_default	=	8'h05;	// sdr retry going through RTI, on_fail hstrst
	parameter sir_retry_default	=	8'h06;	// sir retry going through RTI, on_fail hstrst
	parameter sdr_retry_pwr_off	=	8'h07;	// sdr retry going through RTI, on_fail pwr off
	parameter sir_retry_pwr_off	=	8'h08;	// sir retry going through RTI, on_fail pwr off

// exec_state
	//parameter debug1 								= 8'h00;
	//parameter disabled 							= 8'hFF;
	parameter idle 								= 8'hFF; //01;
	parameter test_start							= 8'h02;

	parameter test_fail_set_muxer_pwr_off			= 8'hF3;
	parameter test_fail_set_muxer_pwr_off_done	= 8'hF4;
	parameter test_fail_all_pwr_relays_off			= 8'hF5;
	parameter test_fail_all_pwr_relays_off_done	= 8'hF6;
	
	parameter test_fail_disconnect_port_1			= 8'hEF;
	parameter test_fail_disconnect_port_1_done	= 8'hF0;
	parameter test_fail_disconnect_port_2			= 8'hF1;
	parameter test_fail_disconnect_port_2_done	= 8'hF2;	
	
	parameter test_fail_pwr_off				= 8'hF7;
	parameter test_fail_hstrst_init			= 8'hF8;
	parameter test_fail_hstrst_ready			= 8'hF9;	

	parameter test_fail							= 8'hFA;
	parameter test_done							= 8'hE0;

	parameter test_fetch_chain_ct	 				= 8'h03;
	parameter test_fetch_chain_ct_done 			= 8'h04;

	parameter test_fetch_chain_1_base_addr				= 8'h05;
	parameter test_fetch_chain_1_base_addr_0			= 8'h06;
	parameter test_fetch_chain_1_base_addr_0_done	= 8'h07;
	parameter test_fetch_chain_1_base_addr_1			= 8'h08;
	parameter test_fetch_chain_1_base_addr_1_done	= 8'h09;
	parameter test_fetch_chain_1_base_addr_2			= 8'h0A;
	parameter test_fetch_chain_1_base_addr_2_done	= 8'h0B;
	parameter test_fetch_chain_1_base_addr_3			= 8'h0C;
	parameter test_fetch_chain_1_base_addr_3_done	= 8'h0D;
	parameter test_fetch_chain_1_base_addr_done		= 8'h0E;

	parameter test_fetch_chain_2_base_addr				= 8'h21;
	parameter test_fetch_chain_2_base_addr_0			= 8'h22;
	parameter test_fetch_chain_2_base_addr_0_done	= 8'h23;
	parameter test_fetch_chain_2_base_addr_1			= 8'h24;
	parameter test_fetch_chain_2_base_addr_1_done	= 8'h25;
	parameter test_fetch_chain_2_base_addr_2			= 8'h26;
	parameter test_fetch_chain_2_base_addr_2_done	= 8'h27;
	parameter test_fetch_chain_2_base_addr_3			= 8'h28;
	parameter test_fetch_chain_2_base_addr_3_done	= 8'h29;
	parameter test_fetch_chain_2_base_addr_done		= 8'h2A;

	parameter test_fetch_global_conf					= 8'h0F;
	parameter test_fetch_global_conf_0				= 8'h10;
	parameter test_fetch_global_conf_0_done		= 8'h11;
	
	parameter test_set_i2c_muxer						= 8'hA3;
	parameter test_set_i2c_muxer_done				= 8'hA4;	
	
	parameter test_fetch_global_conf_1				= 8'h12;
	parameter test_fetch_global_conf_1_tx			= 8'hA1;			
	parameter test_fetch_global_conf_1_done		= 8'h13;		

	parameter test_fetch_global_conf_2				= 8'h14;
	parameter test_fetch_global_conf_2_tx			= 8'hA2;			
	parameter test_fetch_global_conf_2_done		= 8'h15;
	
	parameter test_fetch_global_conf_3				= 8'h16;
	parameter test_fetch_global_conf_3_tx			= 8'hA5;				
	parameter test_fetch_global_conf_3_done		= 8'h17;		
	
	parameter test_fetch_global_conf_4				= 8'h18;
	parameter test_fetch_global_conf_4_tx			= 8'hA6;				
	parameter test_fetch_global_conf_4_done		= 8'h19;		
	
	parameter test_fetch_global_conf_5				= 8'h1A;
	parameter test_fetch_global_conf_5_tx			= 8'hA7;					
	parameter test_fetch_global_conf_5_done		= 8'h1B;		
	
	parameter test_fetch_global_conf_6				= 8'h1C;
	parameter test_fetch_global_conf_6_tx			= 8'hA8;					
	parameter test_fetch_global_conf_6_done		= 8'h1D;		
	
	parameter test_fetch_global_conf_7				= 8'h1E;
	parameter test_fetch_global_conf_7_tx			= 8'hA9;		
	parameter test_fetch_global_conf_7_done		= 8'h1F;		

	parameter test_fetch_global_conf_8				= 8'hAA;
	parameter test_fetch_global_conf_8_tx			= 8'hAB;		
	parameter test_fetch_global_conf_8_done		= 8'hAC;		

	parameter test_fetch_global_conf_9				= 8'hAD;
	parameter test_fetch_global_conf_9_tx			= 8'hAE;		
	parameter test_fetch_global_conf_9_done		= 8'hAF;		

	parameter test_fetch_global_conf_10				= 8'hB0;
	parameter test_fetch_global_conf_10_tx			= 8'hB1;		
	parameter test_fetch_global_conf_10_done		= 8'hB2;		

	parameter test_fetch_global_conf_done			= 8'h20;


	parameter test_fetch_step							= 8'h2B;
	parameter test_fetch_id								= 8'h2C;
	parameter test_fetch_id_0							= 8'h2D;
	parameter test_fetch_id_0_done					= 8'h2E;
	parameter test_fetch_id_1							= 8'h2F;
	parameter test_fetch_id_1_done					= 8'h30;
	parameter test_fetch_id_done						= 8'h31;

	parameter test_fetch_low_level_cmd							= 8'h32;
	parameter test_fetch_low_level_cmd_type					= 8'h33;
	parameter test_fetch_low_level_cmd_type_done				= 8'h34;
	parameter test_fetch_low_level_cmd_chain_number			= 8'h35;
	parameter test_fetch_low_level_cmd_chain_number_done	= 8'h36;
	parameter test_fetch_low_level_cmd_cmd						= 8'h37;
	parameter test_fetch_low_level_cmd_cmd_done				= 8'h38;
	parameter test_fetch_low_level_cmd_done					= 8'h39;

	parameter test_fetch_sxr								= 8'h3A;
	parameter test_fetch_sxr_type							= 8'h3B;
	parameter test_fetch_sxr_type_done					= 8'h3C;
	parameter test_fetch_sxr_chain						= 8'h3D;
	parameter test_fetch_sxr_chain_done					= 8'h3E;
	parameter test_fetch_sxr_chain_1_length_0			= 8'h3F;
	parameter test_fetch_sxr_chain_1_length_0_done	= 8'h40;
	parameter test_fetch_sxr_chain_1_length_1			= 8'h41;
	parameter test_fetch_sxr_chain_1_length_1_done	= 8'h42;
	parameter test_fetch_sxr_chain_1_length_2			= 8'h43;
	parameter test_fetch_sxr_chain_1_length_2_done	= 8'h44;
	parameter test_fetch_sxr_chain_1_length_3			= 8'h45;
	parameter test_fetch_sxr_chain_1_length_3_done	= 8'h46;

	parameter test_fetch_sxr_chain_2_length_0			= 8'h47;
	parameter test_fetch_sxr_chain_2_length_0_done	= 8'h48;
	parameter test_fetch_sxr_chain_2_length_1			= 8'h49;
	parameter test_fetch_sxr_chain_2_length_1_done	= 8'h4A;
	parameter test_fetch_sxr_chain_2_length_2			= 8'h4B;
	parameter test_fetch_sxr_chain_2_length_2_done	= 8'h4C;
	parameter test_fetch_sxr_chain_2_length_3			= 8'h4D;
	parameter test_fetch_sxr_chain_2_length_3_done	= 8'h4E;

//	parameter test_fetch_drv							= 8'h4F;
//	parameter test_fetch_drv_done						= 8'h50;

	parameter test_calc_byte_ct_chain_1						= 8'h4F;
	parameter test_calc_byte_ct_chain_1_done				= 8'h50;
	parameter test_inc_byte_ct_chain_1						= 8'h51;
	parameter test_inc_byte_ct_chain_1_done				= 8'h52;
	parameter test_fetch_vector_chain_1						= 8'h53;

	parameter test_calc_byte_ct_chain_2						= 8'h54;
	parameter test_calc_byte_ct_chain_2_done				= 8'h55;
	parameter test_inc_byte_ct_chain_2						= 8'h56;
	parameter test_inc_byte_ct_chain_2_done				= 8'h57;
	parameter test_fetch_vector_chain_2						= 8'h58;

	parameter test_fetch_vector_chain_1_drv				= 8'h59;
	parameter test_fetch_vector_chain_1_drv_done			= 8'h5A;
	parameter test_fetch_vector_chain_1_mask				= 8'h5B;
	parameter test_fetch_vector_chain_1_mask_done		= 8'h5C;
	parameter test_fetch_vector_chain_1_exp				= 8'h5D;
	parameter test_fetch_vector_chain_1_exp_done			= 8'h5E;

	parameter test_fetch_vector_chain_2_drv				= 8'h5F;
	parameter test_fetch_vector_chain_2_drv_done			= 8'h60;
	parameter test_fetch_vector_chain_2_mask				= 8'h61;
	parameter test_fetch_vector_chain_2_mask_done		= 8'h62;
	parameter test_fetch_vector_chain_2_exp				= 8'h63;
	parameter test_fetch_vector_chain_2_exp_done			= 8'h64;

	parameter test_calc_offset_chain_1						= 8'h65;
	parameter test_calc_offset_chain_2						= 8'h66;

	parameter test_vector_segments_ready					= 8'h67;
	parameter test_check_byte_counts							= 8'h68;
	parameter test_fetch_sxr_done								= 8'h69;
	
	parameter test_fetch_sxr_retries							= 8'h6A;
	parameter test_fetch_sxr_retries_done					= 8'h6B;

	parameter test_fetch_sxr_retry_delay					= 8'h6C;
	parameter test_fetch_sxr_retry_delay_done				= 8'h6D;
	parameter test_sxr_delay									= 8'h6E;
	// 6F free
	parameter error												= 8'h70;

	parameter test_fetch_vec_compiler_version_0			= 8'h71;
	parameter test_fetch_vec_compiler_version_0_done	= 8'h72;	
	parameter test_fetch_vec_compiler_version_1			= 8'h73;
	parameter test_fetch_vec_compiler_version_1_done	= 8'h74;	
	parameter test_fetch_vec_format_0						= 8'h75;
	parameter test_fetch_vec_format_0_done					= 8'h76;	
	parameter test_fetch_vec_format_1						= 8'h77;
	parameter test_fetch_vec_format_1_done					= 8'h78;
	// 79 - A0 free	
	
// exec_state end

	parameter high	= 1'b1;
	parameter low	= 1'b0;

// tap_state
	parameter tap_done										= 8'hE0;
	parameter tap_idle										= 8'hE1;
	parameter tap_error										= 8'h70;
	parameter tap_executing_low_level_cmd_trst_hs			= 8'hE2;
	parameter tap_executing_vector							= 8'hE3;

// chain_1/2_state
	parameter test_logic_reset							= 4'h0;	
	parameter run_test_idle								= 4'h1;	
	parameter select_dr_scan							= 4'h2;
	parameter select_ir_scan							= 4'h3;
  	parameter capture_dr  								= 4'h4;
  	parameter capture_ir  								= 4'h5;
  	parameter shift_dr  								= 4'h6;
   	parameter shift_ir  								= 4'h7;
   	parameter exit1_dr  								= 4'h8;
   	parameter exit1_ir  								= 4'h9;
   	parameter pause_dr  								= 4'hA;
   	parameter pause_ir  								= 4'hB;
   	parameter exit2_dr  								= 4'hC;
  	parameter exit2_ir  								= 4'hD;
   	parameter update_dr  								= 4'hE;
   	parameter update_ir  								= 4'hF;