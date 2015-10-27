`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:18:56 11/09/2009 
// Design Name: 
// Module Name:  
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision 3.0
// 
// V3.1
//		- 16bit firmware read only register added
// V3.2
// 	- machine status register added
//		- gpo register defaults to signal path ri->ram
//		- on read access ram address increment
// V3.3
//		- ram_out2 register added, a read access does not increment a_ram_rf (83-81)
//////////////////////////////////////////////////////////////////////////////////

module reg_file_z80(a_cpu,d_cpu,wr_cpu,rd_cpu,io_req_cpu,clk_cpu,
					general_purpose_out,
					general_purpose_in,
					data_write_strobe,
					//data_read_strobe,
					reset_cpu);

	input [7:0] a_cpu;
	inout [7:0] d_cpu;
	input wr_cpu;
	input rd_cpu;	 
	input io_req_cpu;
	input reset_cpu;
	input clk_cpu;
	 
	output [63:0] general_purpose_out; // updated on posedge of cpu_clk
	reg [63:0] general_purpose_out;	
	//input [231:0] general_purpose_in; // rm V3.2
	input [239:0] general_purpose_in; // ins V3.2
	
	output data_write_strobe;
	//output data_read_strobe;

	parameter BASE_ADR = 8'h80;
	parameter reg_0 = BASE_ADR+0;
	parameter reg_1 = BASE_ADR+1;
	parameter reg_2 = BASE_ADR+2;
	parameter reg_3 = BASE_ADR+3;
	parameter reg_4 = BASE_ADR+4;
	parameter reg_5 = BASE_ADR+5;
	parameter reg_6 = BASE_ADR+6;
	parameter reg_7 = BASE_ADR+7;
	parameter reg_8 = BASE_ADR+8;
	parameter reg_9 = BASE_ADR+9;	
	parameter reg_A = BASE_ADR+10; // 8A	  	
	parameter reg_B = BASE_ADR+11; // 8B
	parameter reg_C = BASE_ADR+12; // 8C
	parameter reg_D = BASE_ADR+13; // 8D
	parameter reg_E = BASE_ADR+14; // 8E
	parameter reg_F = BASE_ADR+15; // 8F	
	parameter reg_10 = BASE_ADR+16; // 90	
	parameter reg_11 = BASE_ADR+17; // 91	
	parameter reg_12 = BASE_ADR+18; // 92	
	parameter reg_13 = BASE_ADR+19; // 93		
	parameter reg_14 = BASE_ADR+20; // 94
	parameter reg_15 = BASE_ADR+21; // 95
	parameter reg_16 = BASE_ADR+22; // 96
	parameter reg_17 = BASE_ADR+23; // 97
	parameter reg_18 = BASE_ADR+24; // 98	
	parameter reg_19 = BASE_ADR+25; // 99	
	parameter reg_1A = BASE_ADR+26; // 9A	
	parameter reg_1B = BASE_ADR+27; // 9B	
	parameter reg_1C = BASE_ADR+28; // 9C	
	parameter reg_1D = BASE_ADR+29; // 9D
	parameter reg_1E = BASE_ADR+30; // 9E	
	parameter reg_1F = BASE_ADR+31; // 9F	
	parameter reg_20 = BASE_ADR+32; // A0	
	parameter reg_21 = BASE_ADR+33; // A1		
	parameter reg_22 = BASE_ADR+34; // A2 // ins V3.2			
	parameter reg_23 = BASE_ADR+35; // A3 // ins V3.3
	
	// writing to register file related
	wire ioreq_or_wr;
	assign ioreq_or_wr = io_req_cpu | wr_cpu;	// io write access when io_req and wr_cpu are low
	reg data_write_strobe;
	reg data_read_strobe;	// ins V3.2

	// reading from register file related
	wire ioreq_or_rd;
	assign ioreq_or_rd = io_req_cpu | rd_cpu;	//  io read access when ioreq and rd are low
	//reg [33:0] read_en; // rm V3.2
	reg [39:0] read_en; // ins V3.2
	
	always @(posedge clk_cpu)
			begin
				
				casex ({reset_cpu,ioreq_or_wr,ioreq_or_rd})
					3'b0xx :	begin
									//general_purpose_out [63:0] <= 64'hFF00FFFFFFFFFFFF; //bits 55:48 default to 00h (fmr frequency settings, unused now) // rm v3.2
									general_purpose_out [63:0] <= 64'hFF00FAFFFFFFFFFF; //bits 55:48 default to 00h (fmr frequency settings, unused now) // ins v3.2
									data_write_strobe <= 1'b1;	// enable address incrementing on write access to 80h
									data_read_strobe  <= 1'b1;	// enable address incrementing on read access to 80h // ins V3.2
									read_en <= 32'hFFFFFFFF;
								end 
								
					3'b101 :	begin				//	writing to register file
									// CS: rewrite this case block as case construct
									if (a_cpu == reg_0) 
										begin
											general_purpose_out [7:0] <= d_cpu;
											// increment address
											if (data_write_strobe) general_purpose_out [31:8] <= general_purpose_out [31:8] + 1;
											data_write_strobe <= 1'b0; // disable address incrementing 
										end
									if (a_cpu == reg_1) general_purpose_out [15:8] <= d_cpu;
									if (a_cpu == reg_2) general_purpose_out [23:16] <= d_cpu;
									if (a_cpu == reg_3) general_purpose_out [31:24] <= d_cpu;
									if (a_cpu == reg_4) general_purpose_out [39:32] <= d_cpu; //cmd channel 84h
									if (a_cpu == reg_B) general_purpose_out [47:40] <= d_cpu; //signal path 8Bh
									if (a_cpu == reg_C) general_purpose_out [55:48] <= d_cpu; //frequency 8Ch
									if (a_cpu == reg_18) general_purpose_out [63:56] <= d_cpu; //test start/stop 89
								end
					
					3'b110 : begin 			//	reading from register file
									case(a_cpu)
										reg_23: read_en[0] <= 0; // read from A3 // ins V3.3
										reg_0:	begin
														read_en[0] <= 0;	// 80h
														// increment address
														if (data_read_strobe) general_purpose_out [31:8] <= general_purpose_out [31:8] + 1; // ins V3.2
														data_read_strobe <= 1'b0; // disable address incrementing // ins V3.2
													end
										reg_1: read_en[1] <= 0;
										reg_2: read_en[2] <= 0;
										reg_3: read_en[3] <= 0;
										reg_4: read_en[4] <= 0;
										reg_5: read_en[5] <= 0;
										reg_6: read_en[6] <= 0;
										reg_7: read_en[7] <= 0;
										reg_8: read_en[8] <= 0;
										reg_9: read_en[9] <= 0;										
										reg_A: read_en[10] <= 0;
										reg_B: read_en[11] <= 0;
										reg_C: read_en[12] <= 0;
										reg_D: read_en[13] <= 0;
										reg_E: read_en[14] <= 0;										
										reg_F: read_en[15] <= 0;										
										reg_10: read_en[16] <= 0;										
										reg_11: read_en[17] <= 0;										
										reg_12: read_en[18] <= 0;
										reg_13: read_en[19] <= 0;										
										reg_14: read_en[20] <= 0;																				
										reg_15: read_en[21] <= 0;
										reg_16: read_en[22] <= 0;											
										reg_17: read_en[23] <= 0;																												
										reg_18: read_en[24] <= 0;										
										reg_19: read_en[25] <= 0;										
										reg_1A: read_en[26] <= 0;
										reg_1B: read_en[27] <= 0;										
										reg_1C: read_en[28] <= 0;																				
										reg_1D: read_en[29] <= 0;
										reg_1E: read_en[30] <= 0;											
										reg_1F: read_en[31] <= 0;																												
										reg_20: read_en[32] <= 0;											
										reg_21: read_en[33] <= 0;																												
										reg_22: read_en[34] <= 0; // ins V3.2
									endcase
								end

					default : 
								begin
								//	general_purpose_out [39:0] <= 40'hFFFFFFFFFF;
									data_write_strobe <= 1'b1;	// enable address incrementing
									data_read_strobe  <= 1'b1;	// enable address incrementing // ins V3.2
								//	read_en <= 34'hFFFFFFFFF; // rm V3.2
									read_en <= 40'hFFFFFFFFFF; // ins V3.2
								end 
				endcase
			end


	//assign debug = data_write_strobe;




	//assign data_read_strobe = read_en[0];

	// selected register content is placed on cpu data bus, otherwise place high-z
	assign d_cpu = read_en[0] ? 8'hzz : general_purpose_in [7:0];	// read data channel 80h or A3
	assign d_cpu = read_en[1] ? 8'hzz : general_purpose_out [15:8];  // 81
	assign d_cpu = read_en[2] ? 8'hzz : general_purpose_out [23:16]; // 82
	assign d_cpu = read_en[3] ? 8'hzz : general_purpose_out [31:24]; // 83
	assign d_cpu = read_en[4] ? 8'hzz : general_purpose_out [39:32]; // 84
	assign d_cpu = read_en[5] ? 8'hzz : general_purpose_in [15:8];  
	assign d_cpu = read_en[6] ? 8'hzz : general_purpose_in [23:16];
	assign d_cpu = read_en[7] ? 8'hzz : general_purpose_in [31:24];
	assign d_cpu = read_en[8] ? 8'hzz : general_purpose_in [39:32];
	assign d_cpu = read_en[9] ? 8'hzz : general_purpose_in [47:40];		
	assign d_cpu = read_en[10] ? 8'hzz : general_purpose_in [55:48];	// 8A		
	assign d_cpu = read_en[11] ? 8'hzz : general_purpose_out [47:40];	// 8B

	assign d_cpu = read_en[12] ? 8'hzz : general_purpose_in [63:56];	// 8C
	assign d_cpu = read_en[13] ? 8'hzz : general_purpose_in [71:64];				
	assign d_cpu = read_en[14] ? 8'hzz : general_purpose_in [79:72];				
	assign d_cpu = read_en[15] ? 8'hzz : general_purpose_in [87:80];	// 8F				

	assign d_cpu = read_en[16] ? 8'hzz : general_purpose_in [95:88];		// 90
	assign d_cpu = read_en[17] ? 8'hzz : general_purpose_in [103:96];				
	assign d_cpu = read_en[18] ? 8'hzz : general_purpose_in [111:104];				
	assign d_cpu = read_en[19] ? 8'hzz : general_purpose_in [119:112];	// 93				
	
	assign d_cpu = read_en[20] ? 8'hzz : general_purpose_in [127:120];	// 94					
	assign d_cpu = read_en[21] ? 8'hzz : general_purpose_in [135:128];	// 95						

  	assign d_cpu = read_en[22] ? 8'hzz : general_purpose_in [143:136];	// 96					
	
	assign d_cpu = read_en[23] ? 8'hzz : general_purpose_in [151:144];	// 97
	assign d_cpu = read_en[24] ? 8'hzz : general_purpose_in [159:152];	// 98	
	assign d_cpu = read_en[25] ? 8'hzz : general_purpose_in [167:160];	// 99
	assign d_cpu = read_en[26] ? 8'hzz : general_purpose_in [175:168];	// 9A		

	assign d_cpu = read_en[27] ? 8'hzz : general_purpose_in [183:176];	// 9B
	assign d_cpu = read_en[28] ? 8'hzz : general_purpose_in [191:184];	// 9C	
	assign d_cpu = read_en[29] ? 8'hzz : general_purpose_in [199:192];	// 9D	
	assign d_cpu = read_en[30] ? 8'hzz : general_purpose_in [207:200];	// 9E

	assign d_cpu = read_en[31] ? 8'hzz : general_purpose_in [215:208];	// 9F		
	
	assign d_cpu = read_en[32] ? 8'hzz : general_purpose_in [223:216];	// A0		
	assign d_cpu = read_en[33] ? 8'hzz : general_purpose_in [231:224];	// A1			
	
	assign d_cpu = read_en[34] ? 8'hzz : general_purpose_in [239:232];	// A2				
endmodule

