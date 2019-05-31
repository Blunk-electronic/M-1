// todo

module sim_conditioner();

// INPUTS

// OUTPUTS

// INOUTS
	
    `include "parameters_global.v"	
    //`include "parameters_ram.v"

// SIGNAL DECLARATIONS EXTERNAL
    reg CLK_MASTER;
    reg CPU_RESET_N;


    reg PWR_CTRL_PWR_FAIL_N;
    wire uut_pwr_fail;    
    
    
    
    initial
        begin
            CLK_MASTER = 0;
            CPU_RESET_N = 1;
            PWR_CTRL_PWR_FAIL_N = 1;

            #20 
            CPU_RESET_N = 0;
            #80 
            CPU_RESET_N = 1;

            #200
            PWR_CTRL_PWR_FAIL_N = 0;
            #100
            PWR_CTRL_PWR_FAIL_N = 1;            
            
        end
        
        
    always #10 CLK_MASTER = ~CLK_MASTER; // 50Mhz main clock // period 20ns    
   
           
    conditioner co1 (
        .clk(CLK_MASTER),
        .reset_n(CPU_RESET_N),
        .input_async(PWR_CTRL_PWR_FAIL_N), // driven by pwr_ctrl. if HL-edge -> power fail alarm
        .output_edge(uut_pwr_fail), // H for one clock period when edge detected
        .edge_detect(edge_falling) // input, set to edge_detect falling edge
        );
            
    
endmodule
