// WARNING: FULLY ASYNCHRONOUS DESIGN !

module i2c_slave (sda, scl, ioout, adr, reset, debug);

	inout sda;	// address or data input on sda is sampled on posedge of scl
	input scl;
	input reset;
	input [6:0] adr; // the device address is always 7 bits wide !
	output reg [7:0] ioout;
	output debug;
			
	reg start = 1; // l-active, must default to 1 on power up !
	reg adr_match = 1; // defaults to 1 on power up	
	reg [4:0] ct = -1; // must default to -1 on power up (all bit set) !	
	reg [6:0] address = -1;
	reg [7:0] data_rx = -1;	

	// delay m1_pre by 2 negator propagation delays
	wire ct_reset;
	wire m1_pre_neg /* synthesis keep = 1 */;
	assign m1_pre_neg = !ct_reset;
	wire m1 /* synthesis keep = 1 */;
	assign m1 = !m1_pre_neg;

   always @(negedge sda or negedge m1)
      if (!m1) begin		// !m1 sets start register
         start <= 1'b1;
      end else 
		begin
         start <= !scl;	// on bus starting, start goes low for a very short time until set back to high by negedge of m1 
      end

	//assign debug = start;
	//reg debug;
	//always @*
	//	begin
	//		if (ct == 5'h1f) debug <= 1;
	//			else debug <= 0;
	//	end
		

	always @(posedge scl or negedge reset) // or negedge start)
		begin
			if (!reset)
				begin
					ioout <= -1;
					address <= -1;
					data_rx <= -1;
				end
			else 
			begin
					case (ct)
						5'h00	: address[6] <= sda;
						5'h01	: address[5] <= sda;
						5'h02	: address[4] <= sda;
						5'h03	: address[3] <= sda;
						5'h04	: address[2] <= sda;
						5'h05	: address[1] <= sda;
						5'h06	: address[0] <= sda;
						//5'h07	: rw_bit <= sda;
									
						5'h09	: data_rx[7] <= sda;
						5'h0a	: data_rx[6] <= sda;
						5'h0b	: data_rx[5] <= sda;
						5'h0c	: data_rx[4] <= sda;
						5'h0d	: data_rx[3] <= sda;
						5'h0e	: data_rx[2] <= sda;
						5'h0f	: data_rx[1] <= sda;
						5'h10	: data_rx[0] <= sda;
								
						5'h11	: if (address == adr) ioout <= data_rx;
					endcase
			end
		end

	assign ct_reset = start & reset; // ored zeroes
	always @(negedge scl or negedge ct_reset)
		begin
			if (!ct_reset) ct <= -1;
			else ct <= ct +1;  // posedge scl increments counter ct
		end
		

	always @(ct, adr, address)
		begin
			case (ct)
				5'h08	: if (address == adr) adr_match <= 0;  // address acknowledge
						
				5'h11	: if (address == adr) adr_match <= 0;  // data acknowledge
								
				default	: 	adr_match <= 1;							
			endcase
		end

	assign debug = adr_match;
		
	assign sda = adr_match ? 1'bz : 1'b0;
	

endmodule
