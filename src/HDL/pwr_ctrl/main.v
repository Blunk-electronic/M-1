`timescale 1ns / 1ps

`define debug

// V1.1	- uut_pwr_x signals renamed
// V1.2	- 3 x i2c slave register for current watch timer
// V1.3	- reset behaviour improved
// V1.4	- OVERLOAD causes countdown of timer if relay requested

//////////////////////////////////////////////////////////////////////////////////
module main(
    output reg LED_P1,
    output reg LED_P2,
    output reg LED_P3,
    output LED_PGND,

    output reg PWR_1 = 0,
    output reg PWR_2 = 0,
    output reg PWR_3 = 0,
    output reg PWR_GND = 0,

    input OVERLOAD_1,
    input OVERLOAD_2,
    input OVERLOAD_3,
	 
    //output UUT_PWR_FAIL_1, // rm V1.1
    //output UUT_PWR_FAIL_2, // rm V1.1
    //input UUT_PWR_ON_1, // rm V1.1
    //input UUT_PWR_ON_2, // rm V1.1

	 input emrgcy_pwr_off,  	// ins V1.1
	 output spare_1,			  	// ins V1.1
	 output uut_pwr_fail,	  	// ins V1.1
	 input reset_2,			  	// ins V1.1  // resets timer_x
	 
    inout SDA1,
		// synthesis attribute PULLUP of SDA1 is true;
    input SCL1,
		// synthesis attribute PULLUP of SCL1 is true;
		// synthesis attribute SCHMITT_TRIGGER of SCL1 is true;
		
    inout SDA2,
		// synthesis attribute PULLUP of SDA2 is true;
    input SCL2,
		// synthesis attribute PULLUP of SCL2 is true;	 
		// synthesis attribute SCHMITT_TRIGGER of SCL2 is true;	
		
    inout SDA3,
	 	// synthesis attribute PULLUP of SDA3 is true;
    input SCL3,
		// synthesis attribute PULLUP of SCL3 is true;	 
		// synthesis attribute SCHMITT_TRIGGER of SCL3 is true;	
		
    inout SDA4,
	 	// synthesis attribute PULLUP of SDA4 is true;
    input SCL4,
		// synthesis attribute PULLUP of SCL4 is true;	 
		// synthesis attribute SCHMITT_TRIGGER of SCL4 is true;	 

    input RESET,
		// synthesis attribute SCHMITT_TRIGGER of RESET is true;

    input OSC_RC,
		 // synthesis attribute SCHMITT_TRIGGER of OSC_RC is true;	 
    output OSC_OUT,  // outputs app. 12,5 khz

    output DBG0,
    output DBG1,
    output DBG2,
    output DBG3,
    output DBG4,
    output DBG5,
    output DBG6,
    output DBG7
    );
	 

	assign OSC_OUT = !OSC_RC;
	assign clk = OSC_RC;
	
	prescaler ps ( // on posedge of clk updating
		.clk(clk),
		.q1(clk_timer),  // outputs 50 Hz
		.qe(clk_warning),
		.qf(clk_test)
	);
	

	
	//assign DBG0 = clk_test;	// green LED shows heartbeat
	assign DBG1 = !clk_test;  // green LED

	//assign DBG0 = !emrgcy_pwr_off; // red LED

	//reg pwr_off_all;
	//reg LED_P1;
	//reg LED_P2;
	//reg LED_P3;
	//reg LED_PGND;
	

		

	// sub-bus 2
	parameter pwr_relays_adr 		= 7'h27; // 8 bit write address is 4Eh
	parameter imax_timeout_1_adr 	= 7'h28; // ins V1.2 // 8 bit write address is 50h
	parameter imax_timeout_2_adr 	= 7'h29; // ins V1.2 // 8 bit write address is 52h
	parameter imax_timeout_3_adr 	= 7'h2A; // ins V1.2 // 8 bit write address is 54h	

	wire [3:0] pwr_relays_data;
`ifdef debug
	I2C_slave_8_io_ver_4_1 is0(
		.sda(SDA2),
		.scl(SCL2),
		.io(pwr_relays_data),
		.adr(pwr_relays_adr),
		.reset(RESET) //pwr_off_all)
		//.debug(DBG7)
		);
`else
	I2CslaveWith8bitsIO is0(
		.SDA(SDA2),
		.SCL(SCL2),
		.IOout(pwr_relays_data),
		.ADR(pwr_relays_adr),
		.reset(RESET) //pwr_off_all)
		);
`endif
	//assign PWR_1 	= !pwr_relays_data[0];
	//assign PWR_2 	= !pwr_relays_data[1];
	//assign PWR_3 	= !pwr_relays_data[2];	
	//assign PWR_GND	= !pwr_relays_data[3];		



	wire [7:0] imax_timeout_1_data;
`ifdef debug
	I2C_slave_8_io_ver_4_1 is1(
		.sda(SDA2),
		.scl(SCL2),
		.io(imax_timeout_1_data),
		.adr(imax_timeout_1_adr),
		.reset(RESET)
		);
`else
	I2CslaveWith8bitsIO is1(
		.SDA(SDA2),
		.SCL(SCL2),
		.IOout(imax_timeout_1_data),
		.ADR(imax_timeout_1_adr),
		.reset(RESET)
		);
`endif

	wire [7:0] imax_timeout_2_data;
`ifdef debug
	I2C_slave_8_io_ver_4_1 is2(
		.sda(SDA2),
		.scl(SCL2),
		.io(imax_timeout_2_data),
		.adr(imax_timeout_2_adr),
		.reset(RESET)
		);
`else
	I2CslaveWith8bitsIO is2(
		.SDA(SDA2),
		.SCL(SCL2),
		.IOout(imax_timeout_2_data),
		.ADR(imax_timeout_2_adr),
		.reset(RESET)
		);
`endif

	wire [7:0] imax_timeout_3_data;
`ifdef debug
	I2C_slave_8_io_ver_4_1 is3(
		.sda(SDA2),
		.scl(SCL2),
		.io(imax_timeout_3_data),
		.adr(imax_timeout_3_adr),
		.reset(RESET)
		);
`else
	I2CslaveWith8bitsIO is3(
		.SDA(SDA2),
		.SCL(SCL2),
		.IOout(imax_timeout_3_data),
		.ADR(imax_timeout_3_adr),
		.reset(RESET)
		);
`endif

	reg timeout_1 = 1;
	reg timeout_2 = 1;
	reg timeout_3 = 1;
	
	reg [7:0] timer_1 = -1;
	reg [7:0] timer_2 = -1;
	reg [7:0] timer_3 = -1;
	
	always @(posedge clk_timer or negedge reset_2)  // reset_2 is low driven by executor at test start
		begin
			if (!reset_2) 
				begin
					timeout_1 <= 1;	// asynchronous reset of timeout flags
					timeout_2 <= 1;
					timeout_3 <= 1;
				end
			else
			// ins V1.3 begin
			if (!RESET)
				begin
					timer_1 <= -1;
					timer_2 <= -1;
					timer_3 <= -1;					
					timeout_1 <= 1;
					timeout_2 <= 1;
					timeout_3 <= 1;
				end
			else
			// ins V1.3 end
			begin
				if (OVERLOAD_1) timer_1 <= imax_timeout_1_data; // timer preload if overload gone
				//else timer_1 <= timer_1 - 1; // otherwise start count down every 20 ms // rm V1.4
				else if (!pwr_relays_data[0]) timer_1 <= timer_1 - 1; // otherwise if relay requested (L-active), start count down every 20 ms // ins V1.4

				if (OVERLOAD_2) timer_2 <= imax_timeout_2_data; // timer preload if overload gone
				//else timer_2 <= timer_2 - 1; // rm V1.4
				else if (!pwr_relays_data[1]) timer_2 <= timer_2 - 1; // otherwise if relay requested (L-active), start count down every 20 ms // ins V1.4
				
				if (OVERLOAD_3) timer_3 <= imax_timeout_3_data; // timer preload if overload gone
				//else timer_3 <= timer_3 - 1; // rm V1.4
				else if (!pwr_relays_data[2]) timer_3 <= timer_3 - 1; // otherwise if relay requested (L-active), start count down every 20 ms // ins V1.4

				if (timer_1 == 0) timeout_1 <= 0;	// on timeout clear timeout flag (until reset by reset_2 signal
				if (timer_2 == 0) timeout_2 <= 0;
				if (timer_3 == 0) timeout_3 <= 0;
			end
		end


	assign DBG3 = clk_timer;
	






	reg alert_1 = 1;
	reg alert_2 = 1;
	reg alert_3 = 1;	
	wire alert;

	always @(negedge clk)
		begin
			if (!RESET) 
				begin
					LED_P1 <= 0;
					alert_1 <= 1;
				end
			else
				casex ({!pwr_relays_data[0], OVERLOAD_1, timeout_1}) // NOTE: pwr_relays_data is L active
					3'b111		:	begin	// no alert, no overload, no timeout, everything is fine
											LED_P1 <= alert;
											alert_1 <= 1;
										end
					3'b101		:	begin
											LED_P1 <= clk_warning;  // fast LED flashing on overload, no alarm yet
											alert_1 <= 1;
										end
					3'b100		:	begin		// slow LED flashing on timeout, alarm on
											LED_P1 <= clk_test;
											alert_1 <= 0;
										end
					3'b110		:	begin		// overload is gone but still timeout -> slow LED flashing, keep alarm on
											LED_P1 <= clk_test;
											alert_1 <= 0;
										end										
					3'b010		:	begin		// relay has been turned of by executor, overload gone, timeout still there -> slow LED flashing, alarm off
											LED_P1 <= clk_test;
											alert_1 <= 1;
										end
					3'b011		:	begin		// relay is not requested by executor, no overload, no timeout -> LED off, alarm off
											LED_P1 <= 0;
											alert_1 <= 1;
										end
					default		:	begin	
											LED_P1 <= 0;
											alert_1 <= 1;
										end
				endcase
		end

	
	always @(negedge clk)
		begin
			if (!RESET) 
				begin
					LED_P2 <= 0;
					alert_2 <= 1;
				end
			else
				casex ({!pwr_relays_data[1], OVERLOAD_2, timeout_2}) // NOTE: pwr_relays_data is L active
					3'b111		:	begin	// no alert, no overload, no timeout, everything is fine
											LED_P2 <= alert;
											alert_2 <= 1;
										end
					3'b101		:	begin
											LED_P2 <= clk_warning;  // fast LED flashing on overload, no alarm yet
											alert_2 <= 1;
										end
					3'b100		:	begin		// slow LED flashing on timeout, alarm on
											LED_P2 <= clk_test;
											alert_2 <= 0;
										end
					3'b110		:	begin		// overload is gone but still timeout -> slow LED flashing, keep alarm on
											LED_P2 <= clk_test;
											alert_2 <= 0;
										end
					3'b010		:	begin		// relay has been turned of by executor, overload gone, timeout still there -> slow LED flashing, alarm off
											LED_P2 <= clk_test;
											alert_2 <= 1;
										end
					3'b011		:	begin		// relay is not requested by executor, no overload, no timeout -> LED off, alarm off
											LED_P2 <= 0;
											alert_2 <= 1;
										end
					default		:	begin	
											LED_P2 <= 0;
											alert_2 <= 1;
										end
				endcase
		end


	always @(negedge clk)
		begin
			if (!RESET) 
				begin
					LED_P3 <= 0;
					alert_3 <= 1;
				end
			else
				casex ({!pwr_relays_data[2], OVERLOAD_3, timeout_3}) // NOTE: pwr_relays_data is L active
					3'b111		:	begin	// no alert, no overload, no timeout, everything is fine
											LED_P3 <= alert;
											alert_3 <= 1;
										end
					3'b101		:	begin
											LED_P3 <= clk_warning;  // fast LED flashing on overload, no alarm yet
											alert_3 <= 1;
										end
					3'b100		:	begin		// slow LED flashing on timeout, alarm on
											LED_P3 <= clk_test;
											alert_3 <= 0;
										end
					3'b110		:	begin		// overload is gone but still timeout -> slow LED flashing, keep alarm on
											LED_P3 <= clk_test;
											alert_3 <= 0;
										end
					3'b010		:	begin		// relay has been turned of by executor, overload gone, timeout still there -> slow LED flashing, alarm off
											LED_P3 <= clk_test;
											alert_3 <= 1;
										end
					3'b011		:	begin		// relay is not requested by executor, no overload, no timeout -> LED off, alarm off
											LED_P3 <= 0;
											alert_3 <= 1;
										end
					default		:	begin	
											LED_P3 <= 0;
											alert_3 <= 1;
										end
				endcase
		end
	

	assign alert = (alert_1 & alert_2 & alert_3);  // all L active
	//always @(negedge alert or negedge reset_2)
	always @(posedge clk)
		begin
			if (!alert) // turn all relays off on alert
				begin 
					PWR_1 <= 0;
					PWR_2 <= 0;
					PWR_3 <= 0;
					PWR_GND <= 0;
				end	
			else
				begin	// otherwise relays behave as requested by i2c slaves
					PWR_1 <= !pwr_relays_data[0];
					PWR_2 <= !pwr_relays_data[1];
					PWR_3 <= !pwr_relays_data[2];
					PWR_GND <= !pwr_relays_data[3];
				end
		end
		
	assign LED_PGND = PWR_GND;
	//assign DBG2 = alert;
	assign DBG2 = !(!alert & clk_test); // yellow LED flashes slow on alert
	assign DBG0 = !emrgcy_pwr_off; // red LED on on emergency power off

	// notify executor about power fail alert
	assign uut_pwr_fail = !alert; // uut_pwr_fail is H active for safety reasons
endmodule
