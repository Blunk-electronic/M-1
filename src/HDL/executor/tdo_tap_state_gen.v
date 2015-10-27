`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:02:54 11/09/2009 
// Design Name: 
// Module Name:    tap_state_gen 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision 4.2
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module tdo_tap_state_gen(mode,reset,clk_scan,tdo_req,tck,tms,start_adr,len,a_ag,
								d_state
								);
	 
    input [15:0] mode;
	 input reset;
    input clk_scan;
    output tdo_req;
    output tck;
    output tms;
	 output [3:0] d_state;

   input [23:0] start_adr;
   input [23:0] len;
   output [23:0] a_ag;
   reg [23:0] a_ag;
	reg [23:0] len_ctdwn;


	reg tms;
	reg tdo_req;
	reg sel_dr;
	reg rt_idle;
	reg ex2_xr;
	
   parameter tlr = 4'b0000; // 0
   parameter rti = 4'b0001; // 1
   parameter seldr = 4'b0010; // 2
   parameter selir = 4'b0011; // 3
   parameter capdr = 4'b0100; // 4
   parameter capir = 4'b0101; //5
   parameter shdr = 4'b0110;	// 6
   parameter shir = 4'b0111;  // 7
   parameter ex1dr = 4'b1000; // 8
   parameter ex1ir = 4'b1001; // 9
   parameter padr = 4'b1010;	// A
   parameter pair = 4'b1011;  // B
   parameter ex2dr = 4'b1100; // C
   parameter ex2ir = 4'b1101; // D
   parameter updr = 4'b1110;  // E
   parameter upir = 4'b1111;  // F

	assign tck = clk_scan;

   (* FSM_ENCODING="SEQUENTIAL", SAFE_IMPLEMENTATION="YES", SAFE_RECOVERY_STATE="tlr" *) reg [3:0] state;
	always @(state) 
     begin
          case (state)
               tlr:
							begin
								sel_dr <= 0;
								rt_idle <= 0;
								ex2_xr <= 0;
							end
               rti:
							rt_idle <= 1;
					seldr:	  
							begin
								sel_dr <= 1;
								rt_idle <= 0;
							end
               capdr:
							sel_dr <= 0;
					selir:
							sel_dr <= 0;		
					ex2dr: 
							ex2_xr <= 1;
					ex2ir: 
							ex2_xr <= 1;
						
          endcase
     end



	
	//DFF
	reg leave_tlr;
   always @(posedge mode[15] or posedge rt_idle or negedge reset)
		if (!reset) leave_tlr <= 1'b0;
		else
      if (rt_idle == 1) begin
         leave_tlr <= 1'b0;
      end else begin
         leave_tlr <= 1'b1;
      end

	//DFF
	reg leave_rti;
   always @(posedge mode[14] or posedge sel_dr or negedge reset)
		if (!reset) leave_rti <= 1'b0;
		else
      if (sel_dr == 1) begin
         leave_rti <= 1'b0;
      end else begin
         leave_rti <= 1'b1;
      end

	//DFF
	reg leave_paxr;
   always @(posedge mode[13] or posedge ex2_xr or negedge reset)
		if (!reset) leave_paxr <= 1'b0;
		else
      if (ex2_xr == 1) begin
         leave_paxr <= 1'b0;
      end else begin
         leave_paxr <= 1'b1;
      end


////////////////////////////////////////////////////////////

		//leading state machine
		
		// actions occuring on rising edge of tck	
		always@(posedge clk_scan)
			begin
				if (reset == 0) state <= tlr;
				else 
				(* PARALLEL_CASE, FULL_CASE *) case (state)
            tlr : 	begin
								if (leave_tlr == 1) 
									begin
										state <= rti;
									end
								else 
									begin
										state <= tlr;
									end
							end
            rti : 	begin
								if (leave_rti == 1) 
									begin
										state <= seldr;
									end
								else 
									begin
										state <= rti;
									end
							end
            seldr : 	begin
								if (mode[1] == 0) 
									begin
										state <= capdr;
									end
								else 
									begin
										state <= selir;
									end
							end

            selir : 	begin
								if (mode[0] == 0)
									begin
										state <= capir;
									end
								else
									begin
										state <= tlr;
									end
                     end

            capdr : 	begin
								if (mode[2] == 0) 
									begin
										state <= shdr;
									end
								else
									begin
										state <= ex1dr;
									end
							end

            capir : 	begin
								if (mode[2] == 0) 
									begin
										state <= shir;
									end
								else
									begin
										state <= ex1ir;
									end
							end


            shdr : 	begin
								if (len_ctdwn == 1) 
									begin
										state <= ex1dr;
									end
								else 
									begin 
										state <= shdr;
									end
							end

            shir : 	begin
								if (len_ctdwn == 1) 
									begin
										state <= ex1ir;
									end
								else 
									begin 
										state <= shir;
									end
							end


            ex1dr : 	begin
								if (mode[3] == 0) 
									begin
										state <= padr;
									end
								else 
									begin
										state <= updr;
									end
							end

            ex1ir : 	begin
								if (mode[3] == 0) 
									begin
										state <= pair;
									end
								else 
									begin
										state <= upir;
									end
							end


            padr : 	begin
								if (leave_paxr == 1)
									begin
										state <= ex2dr;
									end
                        else 
									begin
										state <= padr;
									end
							end

            pair : 	begin
								if (leave_paxr == 1)
									begin
										state <= ex2ir;
									end
                        else 
									begin
										state <= pair;
									end
							end


            ex2dr : 	begin 
								if (mode[4] == 1)
									begin
										state <= updr;
									end
                        else 
									begin
										state <= shdr;
									end
							end

            ex2ir : 	begin 
								if (mode[4] == 1)
									begin
										state <= upir;
									end
                        else 
									begin
										state <= shir;
									end
							end


            updr : 	begin
								if (mode[5] == 1) 
									begin
										state <= seldr;
									end
								else 
									begin
										state <= rti;
									end
							end
							
            upir : 	begin
								if (mode[5] == 1) 
									begin
										state <= seldr;
									end
								else 
									begin
										state <= rti;
									end
							end

            default : state <= tlr;
                     
         endcase
		end


		// actions occuring on falling edge of tck
		always@(negedge tck)
			begin
				(* PARALLEL_CASE, FULL_CASE *) case (state)
            tlr : 	begin
										tms <= 1;
							end
            rti : 	begin
										tms <= 0; 
							end
            seldr : 	begin
										tms <= 1;
							end
            selir : 	begin
										tms <= 1;
                     end

            capdr : 	begin
										tms <= 0;
							end

            capir : 	begin
										tms <= 0;
							end

            shdr : 	begin
										tms <= 0;  
							end

            shir : 	begin
										tms <= 0;  
							end

            ex1dr : 	begin
										tms <= 1;  
							end

            ex1ir : 	begin
										tms <= 1;  
							end

            padr : 	begin
										tms <= 0;
							end

            pair : 	begin
										tms <= 0;
							end

            ex2dr : 	begin 
										tms <= 1;
							end

            ex2ir : 	begin 
										tms <= 1;
							end

            updr : 	begin
										tms <= 1;
							end
							
            upir : 	begin
										tms <= 1;
							end
                 
         endcase
		end

//////////////////////////////////////////////////////////////////

	//dummy state machine


   parameter d_tlr = 4'b0000; // 0
   parameter d_rti = 4'b0001; // 1
   parameter d_seldr = 4'b0010; // 2
   parameter d_selir = 4'b0011; // 3
   parameter d_capdr = 4'b0100; // 4
   parameter d_capir = 4'b0101; //5
   parameter d_shdr = 4'b0110;	// 6
   parameter d_shir = 4'b0111;  // 7
   parameter d_ex1dr = 4'b1000; // 8
   parameter d_ex1ir = 4'b1001; // 9
   parameter d_padr = 4'b1010;	// A
   parameter d_pair = 4'b1011;  // B
   parameter d_ex2dr = 4'b1100; // C
   parameter d_ex2ir = 4'b1101; // D
   parameter d_updr = 4'b1110;  // E
   parameter d_upir = 4'b1111;  // F

	reg [3:0] d_state;
 

		// actions occuring on rising edge of tck	
		always@(posedge clk_scan)
			begin
				if (reset == 0) d_state <= d_tlr;
				else 
				(* PARALLEL_CASE, FULL_CASE *) case (d_state)
            d_tlr : 	begin
								if (!tms) d_state <= d_rti;
								else 	d_state <= d_tlr;
							end
            d_rti : 	begin
								if (tms) d_state <= d_seldr;
								else d_state <= d_rti;
							end
            d_seldr : 	begin
								if (!tms) d_state <= d_capdr;
								else d_state <= d_selir;
							end
            d_selir :begin
								if (!tms) d_state <= d_capir;
								else d_state <= d_tlr;
                     end
				d_capdr :begin
								if (!tms) d_state <= d_shdr;
								else d_state <= d_ex1dr;
							end
            d_capir :begin
								if (!tms) d_state <= d_shir;
								else d_state <= d_ex1ir;
							end
            d_shdr : begin
								if (tms) d_state <= d_ex1dr;
								else d_state <= d_shdr;
							end
            d_shir : begin
								if (tms) d_state <= d_ex1ir;
								else d_state <= d_shir;
							end
            d_ex1dr :begin
								if (!tms) d_state <= d_padr;
								else d_state <= d_updr;
							end
            d_ex1ir :begin
								if (!tms) d_state <= d_pair;
								else d_state <= d_upir;
							end
            d_padr : begin
								if (tms) d_state <= d_ex2dr;
								else d_state <= d_padr;
							end
            d_pair : begin
								if (tms) d_state <= d_ex2ir;
								else d_state <= d_pair;
							end
            d_ex2dr :begin 
								if (tms) d_state <= d_updr;
								else d_state <= d_shdr;
							end
				d_ex2ir :begin 
								if (tms) d_state <= d_upir;
								else d_state <= d_shir;
							end
            d_updr : begin
								if (tms) d_state <= d_seldr;
								else d_state <= d_rti;
							end
            d_upir : begin
								if (tms) d_state <= d_seldr;
								else d_state <= d_rti;
							end
            default : d_state <= d_tlr;
                     
         endcase
		end


		// actions occuring on falling edge of tck
		always@(negedge tck)
			begin
				(* PARALLEL_CASE, FULL_CASE *) case (d_state)
            d_tlr : 	tdo_req <= 0;
				d_capdr: begin
									a_ag <= start_adr;
									len_ctdwn <= len;
							end
				d_capir: begin
									a_ag <= start_adr;
									len_ctdwn <= len;
							end							
            d_shdr : begin
									tdo_req <= 1;
									a_ag <= a_ag + 1;	
									len_ctdwn <= len_ctdwn -1;
							end
            d_shir : begin
									tdo_req <= 1;
									a_ag <= a_ag + 1;
									len_ctdwn <= len_ctdwn -1;
							end
				
            d_ex1dr : 	tdo_req <= 0;
            d_ex1ir : 	tdo_req <= 0;
         endcase
		end
  


							
endmodule
