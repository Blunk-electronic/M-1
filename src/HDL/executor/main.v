`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Dependencies: 
//
// Revision : 2012-01-25
//					- llc h/s/hs-trst supported
//					- llc delay supported

// Revision : V0.1
//					- tck frequency set by executor
//					- i2c supported
//	

// Revision : V0.2
//					- UUT pwr off on fail

// Revision : V0.3
//					- UUT_PWR_OFF_x and UUT_PWR_FAIL_x renamed

// V0.4
//		- 16bit firmware constant added (read from register file)

// V0.5
//		- output reset_2 used to reset timer in current watcher on pwr_ctrl

// V0.6
//		- uut_pwr_fail driven by pwr_ctrl is evaluated

// V0.7
// 	- pass LED shows heartbeat on power up or reset

// V0.8
//		- machine status register added
//		- RAM is cleared upon reset or external cpu command

// V009
//    - clock_slow added
`define hardware_vecex_23_sub_v11

//////////////////////////////////////////////////////////////////////////////////
module main(
				//CPU
				a_cpu,
				d_cpu,wr_cpu,rd_cpu,io_req_cpu,
				reset_cpu,
				clk_cpu,
				iei,ieo,
				m1_cpu,
				int_cpu,
				nmi_cpu,
				mem_req_cpu,
				rfsh_cpu,
				halt_cpu,
				wait_cpu,
				bus_req_cpu,
				bus_ack_cpu,
				reserved_cpu,
				
				watchdog,
				
				//OSC
				clk_scan, 
				clk_slow, // ins V009
				//RAM
				a_ram,
				d_ram,
				oe_ram,
				wr_ram,
				cs_ram_out,
				cs_ram_in,
				
			
				//TAP 1
				tdo_1,
				tck_1,
				tms_1,
				trst_1,
				tdi_1,
				fail_1,

				//TAP 2
				tdo_2,
				tck_2,
				tms_2,
				trst_2,
				tdi_2,
				fail_2,

				//GPIO
				gpio,
				
				//DEBUG
				debug,
				
				// start/stop/sts front panel
				start,
						// synthesis attribute PULLUP of start isTRUE;
				stop,
						// synthesis attribute PULLUP of stop isTRUE;
				pass,
				fail,
	
				// UUT pwr control
				//uut_pwr_on_1,
				emrgcy_pwr_off,  // L-active
				//uut_pwr_on_2,
				spare_1,
				//uut_pwr_fail_1,
				uut_pwr_fail,		// H-active
				//uut_pwr_fail_2,		
				reset_2, // L-active
				// synthesis attribute PULLUP of reset_2 isTRUE;
				
				// watchdog
				//watchdog,
				
				//pwr_good
				//pwr_good,
	
				//I2C
				sda,
				scl,
				
				rsv_16
							
				);
	
	// CPU
	input [15:0] a_cpu;
	inout [7:0] d_cpu; 
   input wr_cpu;
	input reset_cpu;
	input rd_cpu;
   input io_req_cpu;
	input clk_cpu;
	input iei;
	input	ieo;
	input m1_cpu;
	output int_cpu;
	assign int_cpu = 1'bz;  //temporarily
	output nmi_cpu;
	assign nmi_cpu = 1'bz;  //temporarily
	input mem_req_cpu;
	input rfsh_cpu;
	input	halt_cpu;
	output wait_cpu;
	assign wait_cpu = 1'bz; //temporarily
	input bus_req_cpu;	//CS: not sure , check !
	input bus_ack_cpu;	//CS: not sure , check !
	input [7:0] reserved_cpu;

	input watchdog;
		
	//RAM
   output oe_ram;
   output wr_ram;
	output cs_ram_out;
	output cs_ram_in;
	assign cs_ram_in = 1'b1; //temporarily

  output reg [18:0] a_ram; // changed from 23:0 to 18:0 in v009

		// synthesis attribute PULLUP of a_ram isTRUE;
   inout [7:0] d_ram;
		// synthesis attribute PULLUP of d_ram isTRUE;


	// GPIO
	inout [3:0] gpio;
	
	// tap 1
   output tdo_1;
	output tms_1;
   output tck_1;
   output trst_1;
	input tdi_1;
	output fail_1;
	//assign fail_1 = 1'bz;  //temporarily

	// tap 2
   output tdo_2;
	output tms_2;
   output tck_2;
   output trst_2;
	input tdi_2;
	output fail_2;
	assign fail_2 = 1'bz;  //temporarily	
	
	// OSC
   input clk_scan;
	input clk_slow; // ins V009
	 
	
	//rsv
	input rsv_16;	 // 1 hz clock
	 
	 
	// debug
	output [7:0] debug;
	//assign debug[7:3] = 6'h00;  //temporarily
	//assign debug[2] = !tck_1; //blue
	//assign debug[0] = !fail_1; //rsv_16; //red

	// start/stop/sts front panel
	input start;
	input stop;
	output pass;
	output fail;	

	
	// UUT pwr control
	output emrgcy_pwr_off; // driven by exexutor
	//assign emrgcy_pwr_off = 1'b1; //temporarily
	
	//output uut_pwr_on_2; // now driven by executor in V0.2
	input spare_1;
	//assign uut_pwr_on_2 = 1'bz; //temporarily, rm in V0.2
	
	input uut_pwr_fail;	
	//assign uut_pwr_fail = 1'bz; //temporarily
	output reset_2;		
	//assign reset_2 = 1'b1; //temporarily  // rm V0.5
	
	// watchdog
	//input watchdog;
	
	//pwr_good
	//input pwr_good;
	
	//I2C
	inout sda;
	output scl;
	
	
	
/////////////////////////////////////////////////////////////////////////////////////////

	`include "parameters.v"
	

	wire data_write_strobe;
	//wire data_read_strobe;	
	wire [63:0] gpo_rf;
//	wire [231:0] gpi_rf;  //V0.4 MSB changed from 215 to 231 // rm V0.8
	wire [239:0] gpi_rf;  // ins V0.8


	reg_file_z80 rf (
		.a_cpu(a_cpu[7:0]), 
		.d_cpu(d_cpu), 
		.wr_cpu(wr_cpu), 
		.rd_cpu(rd_cpu),
		.io_req_cpu(io_req_cpu), 
		.reset_cpu(reset_cpu),
		.clk_cpu(clk_cpu),
		.general_purpose_out(gpo_rf[63:0]),		//  [7:0] 80h -> data channel write access
														//	[31:8] 83-81h -> ram address
														// [39:32] 84h -> command channel
														// [47:40] 8Bh -> signal path //defaults to ri->ram
														// [55:48] 8Ch -> frequency //CS: not used any more
														// [63:56] 89 -> test start/stop (55/AA)
														
//		.general_purpose_in(gpi_rf[231:0]),		//  [7:0] 80h -> data channel read access // rm V0.8
		.general_purpose_in(gpi_rf[239:0]),		//  [7:0] 80h -> data channel read access // ins V0.8
														// [31:8] 87-85h -> for debug: RAM address generated by executor
														
														// [34:32] 88h -> for debug: selected bit address generated by executor
														// [35] 88h -> for debug: bit data of selected bit
														
														// [39:32] 88h -> fail_1,exp_1,tdi_1,mask_1
														
														// [47:40] 89h -> executor state
														// [55:48] 8Ah -> tap states
														// [87:56] 8F-8Ch -> bits processed chain 1
														// [119:88]	93-90 -> sxr_length_chain_1
														// [135:120] 95-94 -> step id
														// [143:136] 96 -> vec_state_1
														// [175:144] 9A-97 -> bits processed chain 2
														// [207:176] 9E-9B -> sxr_length_chain_2
														// [215:208] 9F -> vec_state_2
														// [231:216] A1-A0 -> firmware version // ins V0.4
														// [239:232] A2 -> machine status // ins V0.8
		.data_write_strobe(data_write_strobe) // L on write access to 80h (data channel)
		//.ex_halt(ex_halt)						  	// L on read access to 
	);

	assign gpi_rf[231:216] = firmware_version;
	
	wire [7:0] path;
	assign path = gpo_rf[47:40];
	
	wire [7:0] command;
	assign command = gpo_rf[39:32]; // write to 84h


	// RAM signals routing
	wire [23:0] a_ram_rf; 
	assign a_ram_rf = gpo_rf[31:8]; //rf write address 83-81h 
	wire [23:0] a_ram_ex;
	//reg [18:0] a_ram; // changed from 23:0 to 18:0 in v009 // rm v009
	//assign gpi_rf[31:8] = a_ram; // rf may read any time at 87-85h from a_ram
	assign gpi_rf[31:8] = {5'b00000, a_ram}; // rf may read any time at 87-85h from a_ram
		
	
	wire [7:0] d_ram_rf;
	assign d_ram_rf = gpo_rf[7:0];
	wire [7:0] d_ram_ex;
	assign d_ram_ex = d_ram;	// ex always reads data from RAM
	assign gpi_rf[7:0] = d_ram; // rf may read any time at 80h from d_ram;
	
	// ins V0.8 begin
	//reg a_ram_zero;
	//always @*
	//	begin
	//		if (a_ram == 0) a_ram_zero <= 0;
	//			else a_ram_zero <= 1;
	//	end
	//assign gpi_rf[232] = a_ram_zero;
	// ins V0.8 end
	
	// address
	// source is rf or ex or ri (RAM init)
		reg [23:0] a_ram_ri; // ins V0.8
		always @*
			begin
				case (path[3:2])
					2'b00	: 	a_ram = a_ram_rf[18:0]; // rf drives adr in RAM // write adr 83-81h // changed from 23:0 to 18:0 in v009
					2'b01 : 	a_ram = a_ram_ex[18:0]; // ex reads from RAM // changed from 23:0 to 18:0 in v009
					2'b10	:		a_ram = a_ram_ri[18:0]; // ins V0.8 // changed from 23:0 to 18:0 in v009
					//default : a_ram = 8'hzz; // on reset or pwr-up //  pull-ups internally // rm v0.8
					default :	a_ram = 24'hzzzzzz; // on reset or pwr-up //  pull-ups internally // ins V0.8
				endcase
			end
			

	// data
	// source is rf or output RAM or ri
	reg wr_ram_init; // ins V0.8
	reg wr_ram;
	reg oe_ram;
	reg cs_ram_out;
	reg rf_drives_to_ram = 1; // ins V0.8	
	reg ri_drives_to_ram = 1; // ins V0.8	

	always @*
		begin
			case (path[1:0])
				2'b00 : 	// rf writes in RAM
					begin
						wr_ram = data_write_strobe; // on write to rf 80h
						oe_ram = 1'b1; // RAM read forbidden
						cs_ram_out = 1'b0; // CS: should depend on ram address
						rf_drives_to_ram = 0; // ins v0.8
						ri_drives_to_ram = 1; // ins V0.8							
					end

				2'b01 : 	// reading from RAM
					begin
						wr_ram = 1'b1; // RAM write forbidden
						oe_ram = 1'b0;
						cs_ram_out = 1'b0; // CS: should depend on ram address
						rf_drives_to_ram = 1; // ins V0.8	
						ri_drives_to_ram = 1; // ins V0.8	
					end

				// ins V0.8 begin
				2'b10 : 	// RAM init
					begin
						wr_ram = wr_ram_init;
						oe_ram = 1'b1;
						cs_ram_out = 1'b0; // CS: should depend on ram address
						rf_drives_to_ram = 1; // ins V0.8
						ri_drives_to_ram = 0; // ins V0.8							
					end
				// ins V0.8 end

				default : // on reset or pwr-up 
					begin 
						wr_ram = 1'b1; 
						oe_ram = 1'b1; 
						cs_ram_out = 1'b1; 						
						rf_drives_to_ram = 1; // ins V0.8	
						ri_drives_to_ram = 1; // ins V0.8	
					end
			endcase
		end
		
	//assign d_ram = oe_ram ? d_ram_rf : 8'hzz; // drive data to RAM if oe_ram=1 , else release d_ram // rm V0.8
	reg [7:0] d_ram_ri; // ins V0.8
	assign d_ram = !rf_drives_to_ram ? d_ram_rf : 8'hzz; // ins V0.8
	assign d_ram = !ri_drives_to_ram ? d_ram_ri : 8'hzz; // ins V0.8
	
	// ins V0.8 begin
	// clear output RAM upon reset or external command via command channel
	// signal path must be set from init to ram: path=xxxx1010b
	reg [1:0] ram_init_state = -1;
	reg ram_init_done = 1;
	always @(negedge clk_cpu)
		begin
			if (!reset_cpu) // reset starts ram init
				begin
					a_ram_ri = -1;
					d_ram_ri = -1;
					wr_ram_init = 1;
					ram_init_state = 0;
					ram_init_done = 1;
				end

			else
				case (ram_init_state)
					3	:	if (command[7:4] == 4'h2) // command 2xh issued by CPU -> starts ram init
							begin
								a_ram_ri = -1;
								d_ram_ri = -1;
								wr_ram_init = 1;
								ram_init_state = 0;
								ram_init_done = 1;
							end

					0	:	begin
								a_ram_ri = a_ram_ri + 1;
								wr_ram_init = 0;
								ram_init_state = 1;
							end
					1	:	begin
								wr_ram_init = 1;
								ram_init_state = 2;
							end
					2	:	if (a_ram_ri == ram_top) 
								begin
									ram_init_state = 3;
									ram_init_done = 0;
								end
							else ram_init_state = 0;
			
				endcase
		
		end
		
		assign gpi_rf[232] = ram_init_done;
	// ins V0.8 end

	
	wire [7:0] tck_frequency;
	wire clk_timer;
	clk_divider cd (
		.clk_in(clk_scan), //from OSC
		.clk_out1(clk_test), //to executor
		.clk_out2(clk_timer), // 10Hz
		.reset(1'b1), //fmr (reset_cpu), // rm V0.1 CS:
		//.scale(gpo_rf[55:48]) //8C
		.scale(tck_frequency) // from executor
    );


	// STS LED and debug
	reg step_mode;
	wire clk_led;
	wire clk_debouncer;
	always @*
		begin
			case (command[3:0])
				tck_step	:	step_mode <= clk_led;
				sxr_step	:	step_mode <= clk_debouncer; // fast led flashing derived from debouncer clock
				default	:	step_mode <= 1;
			endcase
		end
		
	reg [7:0] debug;
	wire test_running;
	wire led;
	wire tap_ready;
	wire im_ack_fail;
	
	wire [7:0] exec_state;
	assign exec_state = gpi_rf[47:40];
	
	always @*
		begin
			casex ({path[3:0],test_running})
				5'b0001x	: 	begin
								`ifdef hardware_vecex_23_sub_v11				
									debug[1] = clk_slow; // yellow LED flashes to indicate RAM read/debug mode // ins v009
								`else									
									debug[1] = rsv_16; // yellow LED flashes to indicate RAM read/debug mode // rm  v009
								`endif
									debug[2] = 1'b1;   // blue LED off
								end
				5'b01011	: 	begin // executor idle mode
									debug[0] = 1'b1; // red off //ins V0.1
									debug[1] = 1'b1;   // yellow LED off
								`ifdef hardware_vecex_23_sub_v11									
									debug[2] = clk_slow; // blue LED flashes to indicate executor mode idle // ins v009
								`else
									debug[2] = rsv_16; // blue LED flashes to indicate executor mode idle // rm v009
								`endif
								end
				5'b01010	: 	begin // test running
									debug[1] = step_mode; // yellow flashes fast on sxr_step_width, slow on tck_step_width
									debug[2] = 1'b0; // blue LED on to indicate executor is running
									debug[0] = (im_ack_fail); // (frm !fail) red flashes on test fail, permanent on on i2c ackn fail // ins V0.1
									debug[3] = clk_test;
									//debug[4] = im_ack_fail; // idicates i2c acknowledge fail
								end
				5'b0000x	: 	begin  // ram loading
									debug[0] = 1'b1; // red off //ins V0.1
									debug[1] = 1'b0;   // yellow LED on to indicate RAM write mode
									debug[2] = 1'b1;   // blue LED off
								end
				default	: 	begin
									debug[7:6] = 2'hF;
									if (exec_state != idle) debug[5] = 1;
										else debug[5] = 0;
									debug[4] = clk_cpu;
									//debug[3:1] = 3'hF;	// blue and yellow LED off after reset or pwr up //
									debug[3:2] = 2'h3;	// blue and yellow LED off after reset or pwr up //
									debug[1] = clk_timer; // yellow LED flashes at 10Hz
									debug[0]	= reset_cpu;	// red LED on on reset
								end
								
			endcase
		end
		
		
	prescaler ps (
		.clk(clk_cpu),
		.qf(clk_debouncer),	// fast flashing leds	// updated on posedge of cpu_clk
		.qg(clk_led),			// slow flashing leds  	// updated on posedge of cpu_clk
		.qh(clk_led2)
	);
	
	
	wire [7:0] strt_stop;
	assign strt_stop = gpo_rf[63:56]; //98  // updated on posedge of cpu_clk
	reg start_rf;
	reg stop_rf;
	always @(negedge clk_cpu)
		begin
			case (strt_stop)
				8'hAA		: 	begin	// stop test
									start_rf <= 1;
									stop_rf <= 0;
								end
				8'h55		: 	begin	// start test
									start_rf <= 0;
									stop_rf <= 1;
								end
				default	: 	begin
									start_rf <= 1;
									stop_rf <= 1;
								end
			endcase
		end
				
	debouncer db_start (
		.out(start_db),  // L-active  // updated on nededge of clk
		.in(start),  // L-active  from start button front panel
		.clk(clk_debouncer)  
	);

	assign start_x = (start_rf & start_db); 	// collect start signals here  //start_x updated on negedge clk_cpu
	
	


	debouncer db_stop (
		.out(stop_db),  // L-active  // updated on nededge of clk
		.in(stop),  // L-active  from stop button front panel
		.clk(clk_debouncer)
	);

	//assign stop_x = (stop_rf & stop_db);	// collect stop signals here  //stop_x updated on negedge clk_cpu // rm V0.6
	assign stop_x = (stop_rf & stop_db & !uut_pwr_fail);	// collect L active stop signals and H active uut_pwr_fail signal here  //stop_x updated on negedge clk_cpu // ins V0.6
	

	
	
	wire [31:0] bits_processed_chain_1;
	wire [31:0] bits_processed_chain_2;	
	wire [31:0] sxr_length_chain_1;
	wire [31:0] sxr_length_chain_2;	
	wire [15:0] step_id;
	
	wire [7:0] vec_state_1;	
	wire [7:0] vec_state_2;
	wire error_flag; // ins V0.8
	
	executor ex (
		.reset(reset_cpu),
		.start(start_x),	// L-active
		.stop(stop_x),	// L-active
		.tck_frequency(tck_frequency), // scale for clock divider cd
		//.active(test_running),	//ouput; address controlled by executor ex // L active
		.start_addr(a_ram_rf), 			//driven by register file //83-81h
		.ram_addr(a_ram_ex), 			//drives output RAM address (if executor control selected)
		.ram_data(d_ram_ex),				//driven by d_ram
		//.selected_bit(gpi_rf[34:32]),	//outputs address of selected bit of RAM data
		//.bit_data(gpi_rf[36]),			//outputs selected bit data
		.tdi_1(tdi_1),
		.tdi_2(tdi_2),
		.tdo_1(tdo_1),
		.tdo_2(tdo_2),
		.tms_1(tms_1),
		.tms_2(tms_2),
		.tck_1(tck_1),
		.tck_2(tck_2),
		.trst_1(trst_1),
		.trst_2(trst_2),
		.fail_1(fail_1),  // H - active
		.fail_2(fail_2),
		.fail_any_chain(fail_any_chain), // H-active (when ex in test_fail)
		.step_id(step_id),
		.pass(pass),
		.mask_1(mask_1),
		.mask_2(mask_2),
		.exp_1(exp_1),
		.exp_2(exp_2),		
		.clk_timer(clk_timer),
		.clk(clk_test), // (rsv_16),		//CS: drive clk_tap via on board osc and prescaler
		.clk_heartbeat(clk_led2), //heartbeat), // ins V0.7
		//.mode(gpo_rf[39:32]),	//rf command channel output // 84h
		.mode(command),		//halt executor on FFh , start on 10h
		.exec_state(gpi_rf[47:40]),  //read from 89h
		.run(test_running),  // run is L-active
		.debug(gpi_rf[55:48]),  // read from 8A
		//.led(led),
		.bits_processed_chain_1(bits_processed_chain_1),
		.bits_processed_chain_2(bits_processed_chain_2),
		.sxr_length_chain_1(sxr_length_chain_1),
		.sxr_length_chain_2(sxr_length_chain_2),
		//.bit_no_1(bit_no_1),
		//.bit_no_2(bit_no_2),
		.tap_ready(tap_ready),
		.vec_state_1(vec_state_1),
		.vec_state_2(vec_state_2),
		.sda(sda),  // ins V0.1
		.scl(scl),  // ins V0.1
		.im_ack_fail(im_ack_fail), // ins V0.1
		.emrgcy_pwr_off(emrgcy_pwr_off), // ins in V0.3
		.reset_2(reset_2), // ins V0.5
		.error_flag(error_flag) // ins V0.8
		//.uut_pwr_on_2(uut_pwr_on_2)  // rm in V0.2		
	);

	// [143:136] 96 -> vec_state_1 (from tc)
	// [151:144] 97 -> bit [7:5]=0, [4:0] bit_no_2 from tc
	assign gpi_rf[143:136] = vec_state_1; // 96
	assign gpi_rf[215:208] = vec_state_2; // 9F



	//assign fail = fail_any_chain & clk_debouncer; //rm V0.8
	assign fail = ram_init_done | !error_flag | (fail_any_chain & clk_debouncer); // ins V0.8
	
	//	wire [31:0] bits_processed_chain_1_dec;
	//	assign bits_processed_chain_1_dec[31:0] = bits_processed_chain_1[31:0] -1; //on fail bits_processed_chain_1 is one bit ahead, so subtract 1

		assign gpi_rf[63:56] = bits_processed_chain_1[7:0];  // 8C
		assign gpi_rf[71:64] = bits_processed_chain_1[15:8];
		assign gpi_rf[79:72] = bits_processed_chain_1[23:16];
		assign gpi_rf[87:80] = bits_processed_chain_1[31:24];	// 8F	

		assign gpi_rf[95:88]   = sxr_length_chain_1[7:0];  	// 90
		assign gpi_rf[103:96]  = sxr_length_chain_1[15:8];
		assign gpi_rf[111:104] = sxr_length_chain_1[23:16];
		assign gpi_rf[119:112] = sxr_length_chain_1[31:24];	// 93
		
		assign gpi_rf[135:120] = step_id[15:0];	// 95-94
		
		assign gpi_rf[175:144] = bits_processed_chain_2[31:0]; // 9A-97
		assign gpi_rf[207:176] = sxr_length_chain_2[31:0]; 	// 9E-9B

		assign gpi_rf[39:32]	= {fail_2,exp_2,tdi_2,mask_2,fail_1,exp_1,tdi_1,mask_1}; //88

endmodule

