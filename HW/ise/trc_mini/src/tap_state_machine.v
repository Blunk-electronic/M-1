module tap_state_machine (tck, tms, trst_n, state);

    `include "parameters_global.v"

    input 	tck;
	input	tms;
	input	trst_n;

	output reg [`tap_state_width-1:0] state;

// 	assign state = 4'b0000;

	always @(posedge tck or negedge trst_n) begin
		if (~trst_n)
			begin
				state <= #`DEL TAP_TEST_LOGIG_RESET;
			end
		else
			begin
				case (state) // synthesis parallel_case
					// HEAD LOOP
					TAP_TEST_LOGIG_RESET:
						if (tms == 0)
							begin
								state <= #`DEL TAP_RUN_TEST_IDLE;
							end
						else
							begin
								state <= #`DEL TAP_TEST_LOGIG_RESET;
							end

					TAP_RUN_TEST_IDLE:
						if (tms == 1)
							begin
								state <= #`DEL TAP_SELECT_DR_SCAN;
							end
						else
							begin
								state <= #`DEL TAP_RUN_TEST_IDLE;
							end

					TAP_SELECT_DR_SCAN:
						if (tms == 1)
							begin
								state <= #`DEL TAP_SELECT_IR_SCAN;
							end
						else
							begin
								state <= #`DEL TAP_CAPTURE_DR;
							end

					TAP_SELECT_IR_SCAN:
						if (tms == 1)
							begin
								state <= #`DEL TAP_TEST_LOGIG_RESET;
							end
						else
							begin
								state <= #`DEL TAP_CAPTURE_IR;
							end

					// DR SCAN BRANCH
					TAP_CAPTURE_DR:
						if (tms == 0)
							begin
								state <= #`DEL TAP_SHIFT_DR;
							end
						else
							begin
								state <= #`DEL TAP_EXIT1_DR;
							end

					TAP_SHIFT_DR:
						if (tms == 1)
							begin
								state <= #`DEL TAP_EXIT1_DR;
							end
						else
							begin
								state <= #`DEL TAP_SHIFT_DR;
							end

					TAP_EXIT1_DR:
						if (tms == 1)
							begin
								state <= #`DEL TAP_UPDATE_DR;
							end
						else
							begin
								state <= #`DEL TAP_PAUSE_DR;
							end

					TAP_PAUSE_DR:
						if (tms == 1)
							begin
								state <= #`DEL TAP_EXIT2_DR;
							end
						else
							begin
								state <= #`DEL TAP_PAUSE_DR;
							end

					TAP_EXIT2_DR:
						if (tms == 0)
							begin
								state <= #`DEL TAP_SHIFT_DR;
							end
						else
							begin
								state <= #`DEL TAP_UPDATE_DR;
							end

					TAP_UPDATE_DR:
						if (tms == 1)
							begin
								state <= #`DEL TAP_SELECT_DR_SCAN;
							end
						else
							begin
								state <= #`DEL TAP_RUN_TEST_IDLE;
							end

					// IR SCAN BRANCH
					TAP_CAPTURE_IR:
						if (tms == 0)
							begin
								state <= #`DEL TAP_SHIFT_IR;
							end
						else
							begin
								state <= #`DEL TAP_EXIT1_IR;
							end

					TAP_SHIFT_IR:
						if (tms == 1)
							begin
								state <= #`DEL TAP_EXIT1_IR;
							end
						else
							begin
								state <= #`DEL TAP_SHIFT_IR;
							end

					TAP_EXIT1_IR:
						if (tms == 1)
							begin
								state <= #`DEL TAP_UPDATE_IR;
							end
						else
							begin
								state <= #`DEL TAP_PAUSE_IR;
							end

					TAP_PAUSE_IR:
						if (tms == 1)
							begin
								state <= #`DEL TAP_EXIT2_IR;
							end
						else
							begin
								state <= #`DEL TAP_PAUSE_IR;
							end

					TAP_EXIT2_IR:
						if (tms == 0)
							begin
								state <= #`DEL TAP_SHIFT_IR;
							end
						else
							begin
								state <= #`DEL TAP_UPDATE_IR;
							end

					TAP_UPDATE_IR:
						if (tms == 1)
							begin
								state <= #`DEL TAP_SELECT_DR_SCAN;
							end
						else
							begin
								state <= #`DEL TAP_RUN_TEST_IDLE;
							end

				endcase
			end			
	end
endmodule 
