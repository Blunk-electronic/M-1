`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

//
// Revision: 
// Revision 0.2
// - power up value of registers defaults to 1 
// - i2c slave modules support asynchronous reset
// - trc_reset is SCHMITT_TRIGGER input
// - sda / scl have PULLUPs

//////////////////////////////////////////////////////////////////////////////////
module main(

	//vec_executor
	input trc_reset,
		// synthesis attribute SCHMITT_TRIGGER of trc_reset is true;
   inout sda,
		// synthesis attribute PULLUP of sda is true;
   input scl,
		 // synthesis attribute SCHMITT_TRIGGER of scl is true;		
		 // synthesis attribute PULLUP of scl is true;		 
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
	
	 
	// led front panel
	inout sda_pf,
	output scl_pf,
	
	// I2C MUX
	output i2c_en,
	output i2c_sel_0,
	output i2c_sel_1,
	output i2c_sel_2,
	
	// debug
	output [7:0] dbg,
	
	// relais
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
	
	// UUT
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
	inout dio22_drv
   );
	
	// gpio coming from EX passed right through to UUT
	assign dio11_drv = gpio[0];
	assign dio12_drv = gpio[1];
	assign dio21_drv = gpio[2];
	assign dio22_drv = gpio[3];	
	
	prescaler ps (
		.clk(osc_rc),
		.qe(clk_ed),			// outputs input clock div by 2^10
		.qf(clk_test)
	);

	assign osc_out = !osc_rc;
	//assign dbg[0] = clk_test; // green shows heartbeat
	assign dbg[1] = !(clk_test & ( gnd1_rel | gnd2_rel | tap1_rel | tap2_rel | dio1_rel | dio2_rel | aio1_rel | aio2_rel ));	// yellow flashes if at least one relay is on
	
	// TDI signals coming from UUT are passed right through to EX
	assign tdi_1 = tdi1_comp;
	assign tdi_2 = tdi2_comp;	

	//assign dbg[5] = tdi_1;
	//assign dbg[6] = tdi_2;	

	//I2C slave addresses of primary bus
	//WARNING: bus 1 addresses already in use by external ICs: 2Ch - 2Fh
	parameter i2c_mux_adr = 7'h10;	  // write address 20h
	parameter tap_relais1_adr = 7'h20; // write address 40h
	parameter tap_relais2_adr = 7'h21; // write address 42h	
	parameter drv_char_tap1a_adr = 7'h30; // write address 60h	
	parameter drv_char_tap1b_adr = 7'h31; // write address 62h	
	parameter drv_char_tap2a_adr = 7'h32; // write address 64h	
	parameter drv_char_tap2b_adr = 7'h33; // write address 66h	

	//assign dbg[3] = sda;
	//assign dbg[4] = scl;	

	wire [7:0] tap_relais1_data;
	I2CslaveWith8bitsIO_m1 is2(
		.SDA(sda),
		.SCL(scl),
		.IOout(tap_relais1_data),
		.ADR(tap_relais1_adr),
		.reset(trc_reset)
		);

	wire [7:0] tap_relais2_data;
	I2CslaveWith8bitsIO_m1 is3(
		.SDA(sda),
		.SCL(scl),
		.IOout(tap_relais2_data),
		.ADR(tap_relais2_adr),
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

	
//	assign gnd2_rel = tap_relais1_data[1];
//	assign tap1_rel = tap_relais1_data[2];
//	assign tap2_rel = tap_relais1_data[3];
//	assign dio1_rel = tap_relais1_data[4]; 
//	assign dio2_rel = tap_relais1_data[5];
//	assign aio1_rel = tap_relais1_data[6];
//	assign aio2_rel = tap_relais1_data[7];

//	assign trm_dio1_rel = tap_relais2_data[2];
//	assign trm_dio2_rel = tap_relais2_data[1];
//	assign trm_tdi_rel = tap_relais2_data[0];
	
	
	
	wire [7:0] i2c_mux_data;
	I2CslaveWith8bitsIO_m1 is1(
		.SDA(sda),
		.SCL(scl),
		.IOout(i2c_mux_data),
		.ADR(i2c_mux_adr),
		.reset(trc_reset),
		.debug(dbg[4])
		);
		
	assign dbg[0] = dbg[4];
	
	// write addr 20h
	assign i2c_en = i2c_mux_data[3];
	assign i2c_sel_0 = !i2c_mux_data[0];	// INVERTED !
	assign i2c_sel_1 = !i2c_mux_data[1];	// INVERTED !
	assign i2c_sel_2 = !i2c_mux_data[2];	// INVERTED !

	//assign dbg[0] = clk_ed; //red
	//assign dbg[1] = tck1_drv; //!i2c_mux_data[1]; //clk_ed; //red
	//assign dbg[2] = tck2_drv; //!i2c_mux_data[2]; //clk_ed; //red	
	
	wire [7:0] drv_char_tap1a_data;
	I2CslaveWith8bitsIO_m1 is4(
		.SDA(sda),
		.SCL(scl),
		.IOout(drv_char_tap1a_data),
		.ADR(drv_char_tap1a_adr),	 // write address 60h
		.reset(trc_reset)
		);

	wire [7:0] drv_char_tap1b_data;
	I2CslaveWith8bitsIO_m1 is5(
		.SDA(sda),
		.SCL(scl),
		.IOout(drv_char_tap1b_data),
		.ADR(drv_char_tap1b_adr),	 // write address 62h
		.reset(trc_reset)		
		);

	wire [7:0] drv_char_tap2a_data;
	I2CslaveWith8bitsIO_m1 is6(
		.SDA(sda),
		.SCL(scl),
		.IOout(drv_char_tap2a_data),
		.ADR(drv_char_tap2a_adr),   // write address 64h	
		.reset(trc_reset)		
		);

	wire [7:0] drv_char_tap2b_data;
	I2CslaveWith8bitsIO_m1 is7(
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

	
	// edge detectors
	wire [9:0] edge_det_out;
	
	// TAP 1
	edge_detector ed1 (
		.out(edge_det_out[0]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(tck1_drv),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
		);

	edge_detector ed2 (
		.out(edge_det_out[1]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(tms1_drv),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
		);

	edge_detector ed3 (
		.out(edge_det_out[2]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(tdo1_drv),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
		);

	edge_detector ed4 (
		.out(edge_det_out[3]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(trst1_drv),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
	);

	edge_detector ed5 (
		.out(edge_det_out[4]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(tdi1_comp),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
		);

	// TAP 2
	edge_detector ed6 (
		.out(edge_det_out[5]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(tck2_drv),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
		);

	edge_detector ed7 (
		.out(edge_det_out[6]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(tms2_drv),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
		);

	edge_detector ed8 (
		.out(edge_det_out[7]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(tdo2_drv),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
		);

	edge_detector ed9 (
		.out(edge_det_out[8]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(trst2_drv),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
	);

	edge_detector ed10 (
		.out(edge_det_out[9]),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(tdi2_comp),			// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
		);



	// LED FRONT PANEL
	
	wire [31:0] i2c_data_tx;

//	assign i2c_data_tx[7:0] = edge_det_out[7:0];
//	assign i2c_data_tx[9:8] = edge_det_out[9:8];
//	assign i2c_data_tx[10]	= tck1_drv;
//	assign i2c_data_tx[11]	= tms1_drv;
//	assign i2c_data_tx[12]	= tdo1_drv;
//	assign i2c_data_tx[13]	= trst1_drv;
//	assign i2c_data_tx[14]	= tdi1_comp;
//	assign i2c_data_tx[15]	= tck2_drv;
//	assign i2c_data_tx[16]	= tms2_drv;
//	assign i2c_data_tx[17]	= tdo2_drv;
//	assign i2c_data_tx[18]	= trst2_drv;
//	assign i2c_data_tx[19]	= tdi2_comp;
	//edge_det_out[2]

	//write addr 40h
	assign i2c_data_tx[7]	= edge_det_out[4]; // TDI1_pulse // old ://edge_det_out[2]; // TDO1_pulse
	assign i2c_data_tx[6]	= tdi1_comp; // TDI1 // old: //tdo1_drv; // TDO1
	assign i2c_data_tx[5]	= edge_det_out[3]; // TRST1_pulse
	assign i2c_data_tx[4]	= trst1_drv; // TRST1
	assign i2c_data_tx[3]	= dio11_drv; // DIO11	
	assign i2c_data_tx[2]	= 1'b0; // DIO11_pulse	 // edge detector needed
	assign i2c_data_tx[1]	= 1'b0; // DIO12_pulse  // edge detector needed
	assign i2c_data_tx[0]	= dio12_drv; // DIO12		

	//write addr 42h
	assign i2c_data_tx[15]	= edge_det_out[9]; // TDI2_pulse // old: edge_det_out[7]; // TDO2_pulse
	assign i2c_data_tx[14]	= tdi2_comp; // TDI2		// old : tdo2_drv; // TDO2
	assign i2c_data_tx[13]	= edge_det_out[8]; // TRST2_pulse
	assign i2c_data_tx[12]	= trst2_drv; //TRST2
	assign i2c_data_tx[11]	= 1'b0; // DIO21_pulse  // edge detector needed	
	assign i2c_data_tx[10]	= dio21_drv; // DIO21	
	assign i2c_data_tx[9]	= 1'b0; // DIO22_pulse // edge detector needed
	assign i2c_data_tx[8]	= dio22_drv; // DIO22		

	//write addr 44h
	assign i2c_data_tx[23]	= 1'b0; // rsv
	assign i2c_data_tx[22]	= 1'b0; // rsv
	assign i2c_data_tx[21]	= edge_det_out[5]; // TCK2_pulse
	assign i2c_data_tx[20]	= tck2_drv; // TCK2
	assign i2c_data_tx[19]	= edge_det_out[6]; // TMS2_pulse	
	assign i2c_data_tx[18]	= tms2_drv; // TMS2	
	assign i2c_data_tx[17]	= edge_det_out[7]; // TDO2_pulse // old: edge_det_out[9]; // TDI2_pulse
	assign i2c_data_tx[16]	= tdo2_drv; // TDO2 // old : tdi2_comp; // TDI2		
	
	//write addr 46h	
	assign i2c_data_tx[31]	= 1'b0; // rsv
	assign i2c_data_tx[30]	= 1'b0; // rsv
	assign i2c_data_tx[29]	= edge_det_out[0]; // TCK1_pulse
	assign i2c_data_tx[28]	= tck1_drv; // TCK1
	assign i2c_data_tx[27]	= edge_det_out[1]; // TMS1_pulse	
	assign i2c_data_tx[26]	= tms1_drv; // TMS1	
	assign i2c_data_tx[25]	= edge_det_out[2]; // TDO1_pulse //  old: //edge_det_out[4]; // TDI1_pulse
	assign i2c_data_tx[24]	= tdo1_drv; // TDO1 // old: //tdi1_comp; // TDI1		
	

	//assign dbg[0] = i2c_data_tx[0];


	parameter i2c_addr_1 = 7'h20; //write addr 40h
	parameter i2c_addr_2 = 7'h21; //write addr 42h
	parameter i2c_addr_3 = 7'h22; //write addr 44h	
	parameter i2c_addr_4 = 7'h23; //write addr 46h	
	parameter i2c_addr_5 = 7'h24; //write addr 48h	- not used	

	// led front panel controller
	i2c_controller ic (
		.clk(osc_rc),
		.data_tx1(~i2c_data_tx[7:0]),
		.data_tx2(~i2c_data_tx[15:8]),		
		.data_tx3(~i2c_data_tx[23:16]),		
		.data_tx4(~i2c_data_tx[31:24]),				
		.addr_slave1(i2c_addr_1),
		.addr_slave2(i2c_addr_2),		
		.addr_slave3(i2c_addr_3),
		.addr_slave4(i2c_addr_4),
		.reset(trc_reset),
		.ack_fail(i2c_ack_fail),
		.sda(sda_pf),
		.scl(scl_pf)
		);


	edge_detector ed11 (
		.out(i2c_ack_fail_ed),			// outputs H on edge detection
		.clk(clk_ed),	
		.in(i2c_ack_fail),	// input signal
		.edge_sel(1'b1),		// H posedge detection mode, L negedge detection mode
		.ext_rst_en(1'b0),	// H= manual reset, L= auto reset
		.reset(1'b1)			// L resets detector in manual reset mode - don't care here
		);


	//assign dbg = i2c_addr_1;

	assign dbg[2] = !i2c_ack_fail_ed; // LED red



endmodule
