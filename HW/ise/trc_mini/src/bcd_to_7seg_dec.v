module bcd_to_7seg_dec (bcd_in, segments_out, invert);

    output reg	[6:0] segments_out;
    input		[3:0] bcd_in;
	input		invert;


// 7-segment encoding
//      0
//     ---
//  5 |   | 1
//     --- <--6
//  4 |   | 2
//     ---
//      3


	reg [6:0] seg_reg;

	always @*
      case (bcd_in)
		// this is the decoding for common anode displays:
          4'b0001 : seg_reg = 7'b1111001;   // 1
          4'b0010 : seg_reg = 7'b0100100;   // 2
          4'b0011 : seg_reg = 7'b0110000;   // 3
          4'b0100 : seg_reg = 7'b0011001;   // 4
          4'b0101 : seg_reg = 7'b0010010;   // 5
          4'b0110 : seg_reg = 7'b0000010;   // 6
          4'b0111 : seg_reg = 7'b1111000;   // 7
          4'b1000 : seg_reg = 7'b0000000;   // 8 -> all on
          4'b1001 : seg_reg = 7'b0010000;   // 9
          4'b1010 : seg_reg = 7'b0001000;   // A
          4'b1011 : seg_reg = 7'b0000011;   // b
          4'b1100 : seg_reg = 7'b1000110;   // C
          4'b1101 : seg_reg = 7'b0100001;   // d
          4'b1110 : seg_reg = 7'b0000110;   // E
          4'b1111 : seg_reg = 7'b0001110;   // F
          default : seg_reg = 7'b1000000;   // 0
      endcase

	always @*
		case (invert)
			1'b1 : segments_out = seg_reg; // do not invert segments for common anode display
			1'b0 : segments_out = ~seg_reg; // invert segments for common cathode display
		endcase
	
endmodule 
