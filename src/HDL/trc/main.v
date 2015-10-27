`timescale 1ns / 1ps

// `define i2c_slave_int
//////////////////////////////////////////////////////////////////////////////////

//
// Revision: 
// Revision 0.2
// - power up value of registers defaults to 1 
// - i2c slave modules support asynchronous reset
// - trc_reset is SCHMITT_TRIGGER input
// - sda / scl have PULLUPs

// V0.3
// - all I2C slaves replaced by version V2

// V0.4
// - all tap relays driving I2C slaves replaced by version V4.1
// - front panel LEDs blanked when no tap relay active

// V005
// - added adj_vccio_1/2 signals
// - removed front panel signals
// - cleaned up
//////////////////////////////////////////////////////////////////////////////////
module main(

	//vec_executor
	input trc_reset,
		// synthesis attribute SCHMITT_TRIGGER of trc_reset is true;
		// synthesis attribute FLOAT of trc_reset is true;
   inout sda, // primary i2c bus
		// synthesis attribute SCHMITT_TRIGGER of sda is true;
		// synthesis attribute FLOAT of sda is true;
   input scl, // primary i2c bus
		 // synthesis attribute SCHMITT_TRIGGER of scl is true;		
		 // synthesis attribute FLOAT of scl is true;		 
		 
   input tck_1,
   input tck_2,
   input tms_1,
   input tms_2,
   input tdo_1,
   input tdo_2,
   input trst_1,
   input trst_2,
   output tdi_1,
   output tdi_2,
	inout [3:0] gpio, 
	 
	// OSC
	input osc_rc,
		 // synthesis attribute SCHMITT_TRIGGER of osc_rc is true;	
	output osc_out,
	
	// rm V005 begin
	// led front panel
	//inout sda_pf,
	//output scl_pf,
	// rm V005 end
	
	// I2C muxer channel select and enable
	output i2c_en,
	output i2c_sel_0,
	output i2c_sel_1,
	output i2c_sel_2,
	
	// debug
	output [7:0] dbg,
	
	// relay drivers
	output gnd1_rel,
	output gnd2_rel,
	output tap1_rel,
	output tap2_rel,
	output dio1_rel,
	output dio2_rel,
	output aio1_rel,
	output aio2_rel,
	output trm_dio1_rel,
	output trm_dio2_rel,
	output trm_tdi_rel,
	
	// UUT TAP signals
	input tdi1_comp,
	input tdi2_comp,
	output reg trst1_drv,
	output reg trst2_drv,	
	output reg tck1_drv,
	output reg tck2_drv,	
	output reg tms1_drv,	
	output reg tms2_drv,		
	output reg tdo1_drv,	
	output reg tdo2_drv,		
	inout dio11_drv,
	inout dio12_drv,
	inout dio21_drv,
	inout dio22_drv,
	
	// ins V005 begin
	// vccio adjust signals
	output ADJ_VCCIO_1_P1V5,	
	output ADJ_VCCIO_1_P1V8,
	output ADJ_VCCIO_1_P2V5,	
	output ADJ_VCCIO_2_P1V5,	
	output ADJ_VCCIO_2_P1V8,
	output ADJ_VCCIO_2_P2V5
	//	ins V005 end
   );
	
	// gpio coming from EX passed right through to UUT
	assign dio11_drv = gpio[0];
	assign dio12_drv = gpio[1];
	assign dio21_drv = gpio[2];
	assign dio22_drv = gpio[3];	
	
	prescaler ps (
		.clk(osc_rc),
		//.qe(clk_ed),			// outputs input clock div by 2^10
		.qf(clk_test)
	);

	assign osc_out = !osc_rc; // together with external resistor and capactior this makes an oscillator
	assign dbg[0] = clk_test; // green shows heartbeat  // ins V0.3
	assign dbg[1] = !( gnd1_rel | gnd2_rel | tap1_rel | tap2_rel | dio1_rel | dio2_rel | aio1_rel | aio2_rel );	// yellow LED on if at least one relay is on
	
	// TDI signals coming from UUT are passed right through to EX
	assign tdi_1 = tdi1_comp;
	assign tdi_2 = tdi2_comp;	

	//I2C slave addresses of primary bus
	//WARNING: bus addresses already in use by DACs: read address 2Ch - 2Dh / write address 58h - 5Ah
	parameter i2c_mux_adr = 7'h10;	  // write address 20h / data: muxer channel select bits 2:0, enable bit 3
	parameter tap_relais1_adr = 7'h20; // write address 40h
	parameter tap_relais2_adr = 7'h21; // write address 42h	
	parameter drv_char_tap1a_adr = 7'h30; // write address 60h	
	parameter drv_char_tap1b_adr = 7'h31; // write address 62h	
	parameter drv_char_tap2a_adr = 7'h32; // write address 64h	
	parameter drv_char_tap2b_adr = 7'h33; // write address 66h	
	
	// ins V005 begin
	parameter adj_vccio_1_adr = 7'h2E; // write address 5Ch / data: bits 2:0
	parameter adj_vccio_2_adr = 7'h2F; // write address 5Eh / data: bits 2:0
	wire [2:0] adj_vccio_1_data;
	wire [2:0] adj_vccio_2_data;	

	I2C_slave_8_io_ver_4_1 is10(
		.sda(sda),
		.scl(scl),
		.io(adj_vccio_1_data),
		.adr(adj_vccio_1_adr),
		.reset(trc_reset)
		);

	I2C_slave_8_io_ver_4_1 is11(
		.sda(sda),
		.scl(scl),
		.io(adj_vccio_2_data),
		.adr(adj_vccio_2_adr),
		.reset(trc_reset)
		);
		
	assign ADJ_VCCIO_1_P1V5 = adj_vccio_1_data[0];
	assign ADJ_VCCIO_1_P1V8 = adj_vccio_1_data[1];
	assign ADJ_VCCIO_1_P2V5 = adj_vccio_1_data[2];	
	assign ADJ_VCCIO_2_P1V5 = adj_vccio_2_data[0];
	assign ADJ_VCCIO_2_P1V8 = adj_vccio_2_data[1];
	assign ADJ_VCCIO_2_P2V5 = adj_vccio_2_data[2];	
	// ins V005 end
	
	wire [7:0] tap_relais1_data;
	I2C_slave_8_io_ver_4_1 is2(
		.sda(sda),
		.scl(scl),
		.io(tap_relais1_data),
		.adr(tap_relais1_adr),
		.reset(trc_reset)
		);

	wire [7:0] tap_relais2_data;
	I2C_slave_8_io_ver_4_1 is3(
		.sda(sda),
		.scl(scl),
		.io(tap_relais2_data),
		.adr(tap_relais2_adr),
		.reset(trc_reset)
		);

	assign gnd1_rel = !tap_relais1_data[0];
	assign tap1_rel = !tap_relais1_data[1];
	assign dio1_rel = !tap_relais1_data[2];	
	assign aio1_rel = !tap_relais1_data[3];
	assign trm_tdi_rel = !tap_relais1_data[4];
	assign trm_dio1_rel = !tap_relais1_data[5];

	assign gnd2_rel = !tap_relais2_data[0];
	assign tap2_rel = !tap_relais2_data[1];
	assign dio2_rel = !tap_relais2_data[2];	
	assign aio2_rel = !tap_relais2_data[3];
	assign trm_dio2_rel = !tap_relais2_data[4];
	
	
	wire [7:0] i2c_mux_data;
	I2CslaveWith8bitsIO is1(
		.SDA(sda),
		.SCL(scl),
		.IOout(i2c_mux_data),
		.ADR(i2c_mux_adr),
		.reset(trc_reset)
		//.debug(dbg[5])
		);
	
	// write addr 20h
	assign i2c_en = i2c_mux_data[3];
	assign i2c_sel_0 = !i2c_mux_data[0];	// INVERTED !
	assign i2c_sel_1 = !i2c_mux_data[1];	// INVERTED !
	assign i2c_sel_2 = !i2c_mux_data[2];	// INVERTED !


	wire [7:0] drv_char_tap1a_data;
	I2CslaveWith8bitsIO is4(
		.SDA(sda),
		.SCL(scl),
		.IOout(drv_char_tap1a_data),
		.ADR(drv_char_tap1a_adr),	 // write address 60h
		.reset(trc_reset)
		);

	wire [7:0] drv_char_tap1b_data;
	I2CslaveWith8bitsIO is5(
		.SDA(sda),
		.SCL(scl),
		.IOout(drv_char_tap1b_data),
		.ADR(drv_char_tap1b_adr),	 // write address 62h
		.reset(trc_reset)		
		);

	wire [7:0] drv_char_tap2a_data;
 	I2CslaveWith8bitsIO is6(
		.SDA(sda),
		.SCL(scl),
		.IOout(drv_char_tap2a_data),
		.ADR(drv_char_tap2a_adr),   // write address 64h	
		.reset(trc_reset)		
		);

	wire [7:0] drv_char_tap2b_data;
 	I2CslaveWith8bitsIO is7(
		.SDA(sda),
		.SCL(scl),
		.IOout(drv_char_tap2b_data), 
		.ADR(drv_char_tap2b_adr),  // write address 66h
		.reset(trc_reset)
		);


	//TAP 1
	
	// tck driver
	always @*
		begin
			case (drv_char_tap1a_data[2:0])   // write address 60h
				3'b001	: tck1_drv = tck_1 ? 1'bz : 1'b0; // pull-up
				3'b010	: tck1_drv = tck_1 ? 1'b1 : 1'bz;	// pull-down			
				3'b011	: tck1_drv = 1'bz;					// high-z
				3'b100	: tck1_drv = 1'b0;				// tie low	
				3'b101	: tck1_drv = 1'b1;				// tie high				
				3'b110 	: tck1_drv = tck_1;					// push-pull
				default	: tck1_drv = 1'bz;					// high-z
			endcase
		end

	// tms driver
	always @*
		begin
			case (drv_char_tap1a_data[5:3])   // write address 60h
				3'b001	: tms1_drv = tms_1 ? 1'bz : 1'b0; // pull-up
				3'b010	: tms1_drv = tms_1 ? 1'b1 : 1'bz;	// pull-down			
				3'b011	: tms1_drv = 1'bz;					// high-z
				3'b100	: tms1_drv = 1'b0;				// tie low	
				3'b101	: tms1_drv = 1'b1;				// tie high				
				3'b110 	: tms1_drv = tms_1;					// push-pull
				default	: tms1_drv = 1'bz;					// high-z
			endcase
		end

	// tdo driver
	always @*
		begin
			case (drv_char_tap1b_data[2:0])   // write address 62h
				3'b001	: tdo1_drv = tdo_1 ? 1'bz : 1'b0; // pull-up
				3'b010	: tdo1_drv = tdo_1 ? 1'b1 : 1'bz;	// pull-down			
				3'b011	: tdo1_drv = 1'bz;					// high-z
				3'b100	: tdo1_drv = 1'b0;				// tie low	
				3'b101	: tdo1_drv = 1'b1;				// tie high				
				3'b110 	: tdo1_drv = tdo_1;					// push-pull
				default	: tdo1_drv = 1'bz;					// high-z
			endcase
		end

	// trst driver
	always @*
		begin
			case (drv_char_tap1b_data[5:3])   // write address 62h
				3'b001	: trst1_drv = trst_1 ? 1'bz : 1'b0; // pull-up
				3'b010	: trst1_drv = trst_1 ? 1'b1 : 1'bz;	// pull-down			
				3'b011	: trst1_drv = 1'bz;					// high-z
				3'b100	: trst1_drv = 1'b0;				// tie low	
				3'b101	: trst1_drv = 1'b1;				// tie high				
				3'b110 	: trst1_drv = trst_1;					// push-pull
				default	: trst1_drv = 1'bz;					// high-z
			endcase
		end


	//TAP 2

	// tck driver
	always @*
		begin
			case (drv_char_tap2a_data[2:0])   // write address 64h
				3'b001	: tck2_drv = tck_2 ? 1'bz : 1'b0; // pull-up
				3'b010	: tck2_drv = tck_2 ? 1'b1 : 1'bz;	// pull-down			
				3'b011	: tck2_drv = 1'bz;					// high-z
				3'b100	: tck2_drv = 1'b0;				// tie low	
				3'b101	: tck2_drv = 1'b1;				// tie high				
				3'b110 	: tck2_drv = tck_2;					// push-pull
				default	: tck2_drv = 1'bz;					// high-z
			endcase
		end

	// tms driver
	always @*
		begin
			case (drv_char_tap2a_data[5:3])	 // write address 64h
				3'b001	: tms2_drv = tms_2 ? 1'bz : 1'b0; // pull-up
				3'b010	: tms2_drv = tms_2 ? 1'b1 : 1'bz;	// pull-down			
				3'b011	: tms2_drv = 1'bz;					// high-z
				3'b100	: tms2_drv = 1'b0;				// tie low	
				3'b101	: tms2_drv = 1'b1;				// tie high				
				3'b110 	: tms2_drv = tms_2;					// push-pull
				default	: tms2_drv = 1'bz;					// high-z
			endcase
		end

	// tdo driver
	always @*
		begin
			case (drv_char_tap2b_data[2:0])   // write address 66h
				3'b001	: tdo2_drv = tdo_2 ? 1'bz : 1'b0; // pull-up
				3'b010	: tdo2_drv = tdo_2 ? 1'b1 : 1'bz;	// pull-down			
				3'b011	: tdo2_drv = 1'bz;					// high-z
				3'b100	: tdo2_drv = 1'b0;				// tie low	
				3'b101	: tdo2_drv = 1'b1;				// tie high				
				3'b110 	: tdo2_drv = tdo_2;					// push-pull
				default	: tdo2_drv = 1'bz;					// high-z
			endcase
		end

	// trst driver
	always @*
		begin
			case (drv_char_tap2b_data[5:3])   // write address 66h
				3'b001	: trst2_drv = trst_2 ? 1'bz : 1'b0; // pull-up
				3'b010	: trst2_drv = trst_2 ? 1'b1 : 1'bz;	// pull-down			
				3'b011	: trst2_drv = 1'bz;					// high-z
				3'b100	: trst2_drv = 1'b0;				// tie low	
				3'b101	: trst2_drv = 1'b1;				// tie high				
				3'b110 	: trst2_drv = trst_2;					// push-pull
				default	: trst2_drv = 1'bz;					// high-z
			endcase
		end

endmodule
