`include "parameters_rs232.v"	

module sim_rs232;

	// Inputs
	reg reset_n;
	reg clk;
	reg [7:0] tx_data;
	reg tx_start;
	reg cts;
	reg rxd;
	reg rx_ack;

	// Outputs
	wire tx_ready;
	wire txd;
	wire rts;
	wire [7:0] rx_data;
	wire rx_ready;
	
	wire [`rs232_state_tx_width-1:0] rs232_state_tx;
	wire [`rs232_state_rx_width-1:0] rs232_state_rx;	

	// Instantiate the Unit Under Test (UUT)
	rs232 uut (
		.reset_n(reset_n), 
		.clk(clk), 
		.tx_ready(tx_ready), 
		.tx_data(tx_data), 
		.tx_start(tx_start), 
		.cts(cts), 
		.txd(txd), 
		.rts(rts), 
		.rxd(rxd), 
		.rx_data(rx_data), 
		.rx_ready(rx_ready), 
		.rx_ack(rx_ack),
		.rs232_state_tx(rs232_state_tx),
		.rs232_state_rx(rs232_state_rx)
	);

    `include "rs232_states.v"
	
    // TRANSMITTER
    task start_tx;
        begin
            @(posedge clk);
            $display("time: %d : start timer", $time);
            if (tx_ready)
                tx_start = 1;
            #30
            tx_start = 0;
        end 
    endtask

    // RECEIVER
    task start_rx;
        begin
            @(posedge clk) begin
                case (rs232_state_rx)
                    RS232_STATE_RX_RTS:
                        begin
                            rxd <= #`DEL 0;
                            $display("time: %d : start rx ", $time); 
                        end
                
                    //RS232_STATE_RX_STOPa:
                    default:
                        begin
                            rxd <= #`DEL 1;
                            $display("time: %d : stop rx ", $time);
                        end
                        
//                    default:
                    
                endcase

        //$finish;
            end
        end
    endtask
    
    
	
	initial begin
		// Initialize Inputs
		reset_n = 0;
		clk = 0;
		tx_data = 0;
		tx_start = 0;
		cts = 0;
		rxd = 1;
		rx_ack = 0;

		// Wait 100 ns for global reset to finish
		#100;
		reset_n = 1;
        #100;
        
		// Add stimulus here
		
		// TRANSMITTER
		cts = 1; // host requests data
		#100;
		tx_data = `data_width'h15;
		#100;
		start_tx;
		
 		#200;
// 		start_rx;

 		$display("time: %d : end ", $time);

	end

	
    always @(posedge clk) begin
                case (rs232_state_rx)
                    RS232_STATE_RX_RTS:
                        begin
                            rxd <= #`DEL 0;
                            $display("time: %d : start rx ", $time); 
                            #700
                            rxd <= #`DEL 1;                            
                            #500
                            rxd <= #`DEL 0; 
                        end
                
                    RS232_STATE_RX_STOPa:
                        begin
                            rxd <= #`DEL 1;
                            $display("time: %d : stop rx ", $time);
                        end

                    RS232_STATE_RX_STOPb:
                        begin
                            if (rx_ready)
                                begin
                                    rx_ack <= #`DEL 1;
                                    $display("time: %d : ack rx ", $time);
                                end
                        end
                        
                    RS232_STATE_RX_IDLE:
                        begin
                            rx_ack <= #`DEL 0;
                            //$display("time: %d : ack rx ", $time);
                        end
                        
//                    default:
                    
                endcase
	end
	
    always #10 clk = ~clk; // 50Mhz main clock // period 20ns 	
	
endmodule

