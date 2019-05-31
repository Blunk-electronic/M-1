`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   18:07:35 10/15/2016
// Design Name:   main
// Module Name:   /home/luno/git/BEL/M-1_HW/ise/trc_v002/src/sim_main.v
// Project Name:  trc_v002
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: main
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module sim_main;

`include "parameters_global.v"	
    
	// Inputs
	reg SPARE;
	reg RESET_2;
	reg TRC_RESET;
	reg TCK_1;
	reg TCK_2;
	reg TMS_1;
	reg TMS_2;
	reg TDO_1;
	reg TDO_2;
	reg TRST_1;
	reg TRST_2;
	reg SCL;
	reg OSC_RC;
	reg TDI1_COMP;
	reg TDI2_COMP;

	// Outputs
	wire TDI_1;
	wire TDI_2;
	wire OSC_OUT;
	wire I2C_EN;
	wire I2C_SEL_0;
	wire I2C_SEL_1;
	wire I2C_SEL_2;
	wire DBG;
	wire GND1_REL;
	wire GND2_REL;
	wire TAP1_REL;
	wire TAP2_REL;
	wire DIO1_REL;
	wire DIO2_REL;
	wire AIO1_REL;
	wire AIO2_REL;
	wire TRM_DIO1_REL;
	wire TRM_DIO2_REL;
	wire TRM_TDI_REL;
	wire TRST1_DRV;
	wire TRST2_DRV;
	wire TCK1_DRV;
	wire TCK2_DRV;
	wire TMS1_DRV;
	wire TMS2_DRV;
	wire TDO1_DRV;
	wire TDO2_DRV;
	wire ADJ_VCCIO_1_1V5;
	wire ADJ_VCCIO_1_1V8;
	wire ADJ_VCCIO_1_2V5;
	wire ADJ_VCCIO_2_1V5;
	wire ADJ_VCCIO_2_1V8;
	wire ADJ_VCCIO_2_2V5;

	// Bidirs
	wire [3:0] GPIO;
	wire SDA;
	wire DIO11_DRV;
	wire DIO12_DRV;
	wire DIO21_DRV;
	wire DIO22_DRV;

	// Instantiate the Unit Under Test (UUT)
	main uut (
		.SPARE(SPARE), 
		.RESET_2(RESET_2), 
		.TRC_RESET(TRC_RESET), 
		.TCK_1(TCK_1), 
		.TCK_2(TCK_2), 
		.TMS_1(TMS_1), 
		.TMS_2(TMS_2), 
		.TDO_1(TDO_1), 
		.TDO_2(TDO_2), 
		.TRST_1(TRST_1), 
		.TRST_2(TRST_2), 
		.TDI_1(TDI_1), 
		.TDI_2(TDI_2), 
		.GPIO(GPIO), 
		.SDA(SDA), 
		.SCL(SCL), 
		.OSC_RC(OSC_RC), 
		.OSC_OUT(OSC_OUT), 
		.I2C_EN(I2C_EN), 
		.I2C_SEL_0(I2C_SEL_0), 
		.I2C_SEL_1(I2C_SEL_1), 
		.I2C_SEL_2(I2C_SEL_2), 
		.DBG(DBG), 
		.GND1_REL(GND1_REL), 
		.GND2_REL(GND2_REL), 
		.TAP1_REL(TAP1_REL), 
		.TAP2_REL(TAP2_REL), 
		.DIO1_REL(DIO1_REL), 
		.DIO2_REL(DIO2_REL), 
		.AIO1_REL(AIO1_REL), 
		.AIO2_REL(AIO2_REL), 
		.TRM_DIO1_REL(TRM_DIO1_REL), 
		.TRM_DIO2_REL(TRM_DIO2_REL), 
		.TRM_TDI_REL(TRM_TDI_REL), 
		.TDI1_COMP(TDI1_COMP), 
		.TDI2_COMP(TDI2_COMP), 
		.TRST1_DRV(TRST1_DRV), 
		.TRST2_DRV(TRST2_DRV), 
		.TCK1_DRV(TCK1_DRV), 
		.TCK2_DRV(TCK2_DRV), 
		.TMS1_DRV(TMS1_DRV), 
		.TMS2_DRV(TMS2_DRV), 
		.TDO1_DRV(TDO1_DRV), 
		.TDO2_DRV(TDO2_DRV), 
		.DIO11_DRV(DIO11_DRV), 
		.DIO12_DRV(DIO12_DRV), 
		.DIO21_DRV(DIO21_DRV), 
		.DIO22_DRV(DIO22_DRV), 
		.ADJ_VCCIO_1_1V5(ADJ_VCCIO_1_1V5), 
		.ADJ_VCCIO_1_1V8(ADJ_VCCIO_1_1V8), 
		.ADJ_VCCIO_1_2V5(ADJ_VCCIO_1_2V5), 
		.ADJ_VCCIO_2_1V5(ADJ_VCCIO_2_1V5), 
		.ADJ_VCCIO_2_1V8(ADJ_VCCIO_2_1V8), 
		.ADJ_VCCIO_2_2V5(ADJ_VCCIO_2_2V5)
	);

	initial begin
		// Initialize Inputs
		SPARE = 0;
		RESET_2 = 0;
		TRC_RESET = 1;
		TCK_1 = 0;
		TCK_2 = 0;
		TMS_1 = 0;
		TMS_2 = 0;
		TDO_1 = 0;
		TDO_2 = 0;
		TRST_1 = 0;
		TRST_2 = 0;
		SCL = 0;
		OSC_RC = 1;
		TDI1_COMP = 0;
		TDI2_COMP = 0;

		// Wait 100 ns for global reset to finish
		#100;
        TRC_RESET = 0;
		#100;
        TRC_RESET = 1;
        
		// Add stimulus here

	end
	
    always #10 OSC_RC = ~OSC_RC; // main clock // period
      
endmodule

