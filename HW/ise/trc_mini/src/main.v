module main (

	input SYS_RESET,
		// synthesis attribute SCHMITT_TRIGGER of SYS_RESET is true;
		// synthesis attribute PULLUP of SYS_RESET is true;
	input SP_1_TCK_FPGA,
	input SP_2_TCK_FPGA,
	input SP_1_TMS_FPGA,
	input SP_2_TMS_FPGA,
	input SP_1_TDO_FPGA,
	input SP_2_TDO_FPGA,
	input SP_1_TRST_FPGA,
	input SP_2_TRST_FPGA,
	output SP_1_TDI_FPGA,
	output SP_2_TDI_FPGA,

// 	inout [3:0] GPIO, // former DIO 1 AND 2 -> not used currently


	// I2C MAIN BUS
	inout SDA,
		// synthesis attribute SCHMITT_TRIGGER of SDA is true;
		// synthesis attribute FLOAT of SDA is true;
	input SCL,
		 // synthesis attribute SCHMITT_TRIGGER of SCL is true;		
		 // synthesis attribute FLOAT of SCL is true;

	output [7:0] SEG_OUT_1, // H..A  //  CS rename to disp_1_seg_x ?
	output [7:0] SEG_OUT_2, // H..A
	 
	// DEBUG
	//output [7:0] DBG, // currently not used. rework indexes !

	// SCANPORTS
	input SP_1_TDI_COMP,
	input SP_2_TDI_COMP,
	output reg SP_1_TRST_N,
	output reg SP_2_TRST_N,	
	output reg SP_1_TCK,
	output reg SP_2_TCK,	
	output reg SP_1_TMS,	
	output reg SP_2_TMS,		
	output reg SP_1_TDO,	
	output reg SP_2_TDO,		

	// This DIO group has adjustable voltage // currently not used
// 	inout SP_1_DIO_1_ADJ, 
// 	inout SP_1_DIO_2_ADJ,
// 	inout SP_2_DIO_1_ADJ,
// 	inout SP_2_DIO_2_ADJ,

	// This DIO group has fixed voltage // currently not used
// 	inout SP_1_DIO_1_P3V3,
// 	inout SP_1_DIO_2_P3V3,
// 	inout SP_2_DIO_1_P3V3,
// 	inout SP_2_DIO_2_P3V3,


	// VCCIO ADJUSTMENT
	output SP_1_VCC_P1V5_SET,
	output SP_1_VCC_P1V8_SET,
	output SP_1_VCC_P2V5_SET,

	output SP_2_VCC_P1V5_SET,
	output SP_2_VCC_P1V8_SET,
	output SP_2_VCC_P2V5_SET

   );

    `include "parameters_global.v"
	
	// gpio coming from EX passed right through to UUT
// 	assign SP_1_DIO_1_ADJ = GPIO[0];
// 	assign SP_1_DIO_2_ADJ = GPIO[1];
// 	assign SP_2_DIO_1_ADJ = GPIO[2];
// 	assign SP_2_DIO_2_ADJ = GPIO[3];
// 
// 	assign SP_1_DIO_1_P3V3 = GPIO[0];
// 	assign SP_1_DIO_2_P3V3 = GPIO[1];
// 	assign SP_2_DIO_1_P3V3 = GPIO[2];
// 	assign SP_2_DIO_2_P3V3 = GPIO[3];

	// yellow flashes if at least one relay is on
// 	assign DBG[1] = ~(clk_led & ( GND1_REL | GND2_REL | TAP1_REL | TAP2_REL | DIO1_REL | DIO2_REL | AIO1_REL | AIO2_REL ));

	
	// TDI signals coming from SCANPORTS are passed right through to EX
	assign SP_1_TDI_FPGA = SP_1_TDI_COMP;
	assign SP_2_TDI_FPGA = SP_2_TDI_COMP;	

	
	wire [7:0] drv_char_tap1a_data;
	i2c_slave is4(
		.sda (SDA),
		.scl (SCL),
		.ioout (drv_char_tap1a_data),
		.adr (drv_char_tap1a_adr),	 // write address 60h
		.reset (SYS_RESET)
		);

	wire [7:0] drv_char_tap1b_data;
	i2c_slave is5(
		.sda (SDA),
		.scl (SCL),
		.ioout (drv_char_tap1b_data),
		.adr (drv_char_tap1b_adr),	 // write address 62h
		.reset (SYS_RESET)		
		);

	wire [7:0] drv_char_tap2a_data;
	i2c_slave is6(
		.sda (SDA),
		.scl (SCL),
		.ioout (drv_char_tap2a_data),
		.adr (drv_char_tap2a_adr),   // write address 64h	
		.reset (SYS_RESET)		
		);

	wire [7:0] drv_char_tap2b_data;
	i2c_slave is7(
		.sda (SDA),
		.scl (SCL),
		.ioout (drv_char_tap2b_data), 
		.adr (drv_char_tap2b_adr),  // write address 66h
		.reset (SYS_RESET)
		);

	// VCCIO SLAVES AND MAPPING
	wire [2:0] vccio_1_data;
	i2c_slave is8(
		.sda (SDA),
		.scl (SCL),
		.ioout (vccio_1_data), 
		.adr (vltg_tap_1),  // write address 5Ch
		.reset (SYS_RESET)
		);

	assign SP_1_VCC_P1V5_SET = vccio_1_data[0];
	assign SP_1_VCC_P1V8_SET = vccio_1_data[1];
	assign SP_1_VCC_P2V5_SET = vccio_1_data[2];

	wire [2:0] vccio_2_data;
	i2c_slave is9(
		.sda (SDA),
		.scl (SCL),
		.ioout (vccio_2_data), 
		.adr (vltg_tap_2),  // write address 5Eh
		.reset (SYS_RESET)
		);

	assign SP_2_VCC_P1V5_SET = vccio_2_data[0];
	assign SP_2_VCC_P1V8_SET = vccio_2_data[1];
	assign SP_2_VCC_P2V5_SET = vccio_2_data[2];


	// SCANPORT DRIVERS

	// PORT 1
	
	// tck driver
	always @*
		begin
			case (drv_char_tap1a_data[2:0])   			// write address 60h
				3'b001	: SP_1_TCK = SP_1_TCK_FPGA;
				3'b010	: SP_1_TCK = SP_1_TCK_FPGA;
				3'b011	: SP_1_TCK = 1'bz;				// high-z
				3'b100	: SP_1_TCK = 1'b0;				// tie low	
				3'b101	: SP_1_TCK = 1'b1;				// tie high				
				3'b110 	: SP_1_TCK = SP_1_TCK_FPGA;		// push-pull
				default	: SP_1_TCK = 1'bz;				// high-z
			endcase
		end

	// tms driver
	always @*
		begin
			case (drv_char_tap1a_data[5:3])   			// write address 60h
				3'b001	: SP_1_TMS = SP_1_TMS_FPGA;
				3'b010	: SP_1_TMS = SP_1_TMS_FPGA;
				3'b011	: SP_1_TMS = 1'bz;				// high-z
				3'b100	: SP_1_TMS = 1'b0;				// tie low	
				3'b101	: SP_1_TMS = 1'b1;				// tie high				
				3'b110 	: SP_1_TMS = SP_1_TMS_FPGA;		// push-pull
				default	: SP_1_TMS = 1'bz;				// high-z
			endcase
		end

	// tdo driver
	always @*
		begin
			case (drv_char_tap1b_data[2:0])   			// write address 62h
				3'b001	: SP_1_TDO = SP_1_TDO_FPGA;
				3'b010	: SP_1_TDO = SP_1_TDO_FPGA;
				3'b011	: SP_1_TDO = 1'bz;				// high-z
				3'b100	: SP_1_TDO = 1'b0;				// tie low	
				3'b101	: SP_1_TDO = 1'b1;				// tie high				
				3'b110 	: SP_1_TDO = SP_1_TDO_FPGA;		// push-pull
				default	: SP_1_TDO = 1'bz;				// high-z
			endcase
		end

	// trst driver
	always @*
		begin
			case (drv_char_tap1b_data[5:3])   // write address 62h
				3'b001	: SP_1_TRST_N = SP_1_TRST_FPGA;
				3'b010	: SP_1_TRST_N = SP_1_TRST_FPGA;
				3'b011	: SP_1_TRST_N = 1'bz;			// high-z
				3'b100	: SP_1_TRST_N = 1'b0;			// tie low	
				3'b101	: SP_1_TRST_N = 1'b1;			// tie high				
				3'b110 	: SP_1_TRST_N = SP_1_TRST_FPGA;	// push-pull
				default	: SP_1_TRST_N = 1'bz;			// high-z
			endcase
		end


	// PORT 2

	// tck driver
	always @*
		begin
			case (drv_char_tap2a_data[2:0])   			// write address 64h
				3'b001	: SP_2_TCK = SP_2_TCK_FPGA;
				3'b010	: SP_2_TCK = SP_2_TCK_FPGA;
				3'b011	: SP_2_TCK = 1'bz;				// high-z
				3'b100	: SP_2_TCK = 1'b0;				// tie low	
				3'b101	: SP_2_TCK = 1'b1;				// tie high				
				3'b110 	: SP_2_TCK = SP_2_TCK_FPGA;		// push-pull
				default	: SP_2_TCK = 1'bz;				// high-z
			endcase
		end

	// tms driver
	always @*
		begin
			case (drv_char_tap2a_data[5:3])	 			// write address 64h
				3'b001	: SP_2_TMS = SP_2_TMS_FPGA;
				3'b010	: SP_2_TMS = SP_2_TMS_FPGA;
				3'b011	: SP_2_TMS = 1'bz;				// high-z
				3'b100	: SP_2_TMS = 1'b0;				// tie low	
				3'b101	: SP_2_TMS = 1'b1;				// tie high				
				3'b110 	: SP_2_TMS = SP_2_TMS_FPGA;		// push-pull
				default	: SP_2_TMS = 1'bz;				// high-z
			endcase
		end

	// tdo driver
	always @*
		begin
			case (drv_char_tap2b_data[2:0])   			// write address 66h
				3'b001	: SP_2_TDO = SP_2_TDO_FPGA;
				3'b010	: SP_2_TDO = SP_2_TDO_FPGA;
				3'b011	: SP_2_TDO = 1'bz;				// high-z
				3'b100	: SP_2_TDO = 1'b0;				// tie low	
				3'b101	: SP_2_TDO = 1'b1;				// tie high				
				3'b110 	: SP_2_TDO = SP_2_TDO_FPGA;		// push-pull
				default	: SP_2_TDO = 1'bz;				// high-z
			endcase
		end

	// trst driver
	always @*
		begin
			case (drv_char_tap2b_data[5:3])   			// write address 66h
				3'b001	: SP_2_TRST_N = SP_2_TRST_FPGA;
				3'b010	: SP_2_TRST_N = SP_2_TRST_FPGA;
				3'b011	: SP_2_TRST_N = 1'bz;			// high-z
				3'b100	: SP_2_TRST_N = 1'b0;			// tie low	
				3'b101	: SP_2_TRST_N = 1'b1;			// tie high				
				3'b110 	: SP_2_TRST_N = SP_2_TRST_FPGA;	// push-pull
				default	: SP_2_TRST_N = 1'bz;			// high-z
			endcase
		end




	// SCANPATH MONITORS

	wire [`tap_state_width:0] tap_1_state;
	wire [`tap_state_width:0] tap_2_state;
	

	tap_state_machine tsm_1 (
		.tck (SP_1_TCK),
		.tms (SP_1_TMS),
		.trst_n (SP_1_TRST_N),
		.state (tap_1_state)
		);

	tap_state_machine tsm_2 (
		.tck (SP_2_TCK),
		.tms (SP_2_TMS),
		.trst_n (SP_2_TRST_N),
		.state (tap_2_state)
		);


	bcd_to_7seg_dec bcd_dec_1 (
		.bcd_in (tap_1_state),
		.segments_out (SEG_OUT_1),
		.invert (common_anode) // see parameters
		);

	bcd_to_7seg_dec bcd_dec_2 (
		.bcd_in (tap_2_state),
		.segments_out (SEG_OUT_2),
		.invert (common_anode) // see parameters
		);

endmodule
