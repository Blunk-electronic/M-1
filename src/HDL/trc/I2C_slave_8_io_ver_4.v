// I2C slave written from scratch by Mario Blunk at www.train-z.de 
// send comments to marioblunk@arcor.de

// version V4.0
// imitates the NXP/PHILIPS I2C Expander PCF8574 (execption: no data read, no interrupt output)
// with asynchronous L-active reset input
// no sampling clock required
// WARNING: FULLY ASYNCHRONOUS DESIGN, NO WARRANTY, YOU GET THIS FILE AS IS !
// NOTE: Simulation never performed ! Works in real world !
// target device: Coolrunner XC2C384
// design tool: XILINX ISE 11.1.  


`timescale 1ns / 1ps


	module I2C_slave_8_io_ver_4 (sda, scl, io, adr, reset, debug);

	inout sda;	// address or data input on SDA is sampled on posedge of SCL
	input scl;
	input reset;
	input [6:0] adr; // the device address is always 7 bits wide !
	output reg [7:0] io = -1;
	output debug;
			
	reg start = 1 /* synthesis keep = 1 */;
	reg stop  = 1 /* synthesis keep = 1 */;
	
	// start detection logic
	assign start_and_reset = start & reset;
	wire start_and_reset_inverted /* synthesis keep = 1 */;
	assign start_and_reset_inverted = !start_and_reset;
	wire start_and_reset_delayed /* synthesis keep = 1 */;
	assign start_and_reset_delayed = !start_and_reset_inverted;  

   always @(negedge sda or negedge start_and_reset_delayed)
      if (!start_and_reset_delayed) start <= 1'b1;
      else start <= !scl;
     
	// stop detection logic
	assign stop_and_reset = stop & reset;
	wire stop_and_reset_inverted /* synthesis keep = 1 */;
	assign stop_and_reset_inverted = !stop_and_reset;
	wire stop_and_reset_delayed /* synthesis keep = 1 */;
	assign stop_and_reset_delayed = !stop_and_reset_inverted;  

   always @(posedge sda or negedge stop_and_reset_delayed)
      if (!stop_and_reset_delayed) stop <= 1'b1;
      else stop <= !scl;


	// address bits reading on posedge of scl
	reg [3:0] addr_ct = 0;
	reg [6:0] addr_reg = -1;
	reg rw_access = 1;
	always @(posedge scl)
		begin
			case (addr_ct)
				1	:	addr_reg[6] <= sda; // cycle 1
				2	:	addr_reg[5] <= sda;
				3	:	addr_reg[4] <= sda;
				4	:	addr_reg[3] <= sda;
				5	:	addr_reg[2] <= sda;
				6	:	addr_reg[1] <= sda;
				7	:	addr_reg[0] <= sda;
				8	:	rw_access 	<= sda; // cycle 8
			endcase
		end
		
	
	// address bit counting on negedge of scl
	assign addr_ct_reset = ( start & stop & reset );
	always @(negedge addr_ct_reset or negedge scl)
		begin
			if (!addr_ct_reset) addr_ct <= 0;
			else if (addr_ct < 10) addr_ct <= addr_ct + 1;
		end

	
	// data bits reading on posedge of scl
	reg [3:0] data_ct = 0;
	reg [7:0] data_reg = -1;
	always @(posedge scl or negedge reset)
		if (!reset) io <= -1;
		else
		begin
			case (data_ct)
				0	:	data_reg[7] <= sda; // cycle 1
				1	:	data_reg[6] <= sda;
				2	:	data_reg[5] <= sda;
				3	:	data_reg[4] <= sda;
				4	:	data_reg[3] <= sda;
				5	:	data_reg[2] <= sda;
				6	:	data_reg[1] <= sda;
				7	:	data_reg[0] <= sda;				
				8	:	io <= data_reg;
			endcase
		end

	// data bit counting on negedge of scl
	assign data_ct_reset = ( start & stop & reset );
	always @(negedge data_ct_reset or negedge scl)
		begin
			if (!data_ct_reset) data_ct <= 0;
			else if (adr == addr_reg & addr_ct == 10 & data_ct <= 9) data_ct <= data_ct + 1;
		end


	// pull sda low in 9th address cycle if address match and in 9th data cycle
	assign sda = ( data_ct == 8 | (addr_ct == 9 & adr == addr_reg)) ? 0 : 1'bz;

	endmodule
