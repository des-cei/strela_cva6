// Can be interesting as reference: https://github.com/pulp-platform/axi/blob/master/src/axi_fifo.sv


// See axi_mem_if/src/axi2mem.sv for example use of AXI_BUS interface (as a slave that is)

module cgra_axi_master #(
    parameter int unsigned AXI_ID_WIDTH      = 10,
    parameter int unsigned AXI_ADDR_WIDTH    = 64,
    parameter int unsigned AXI_DATA_WIDTH    = 64,
    parameter int unsigned AXI_USER_WIDTH    = 10
) (
    input   logic       clk_i,
    input   logic       rst_ni,
    AXI_BUS.Master      axi_master_port  
);
    // Default values. See "Table A10-1 Master interface write channel signals and default signal values"

    // // AXI write address channel
    assign axi_master_port.aw_id = '0;
    // assign axi_master_port.aw_addr;
    assign axi_master_port.aw_len = '0;         // Number of beats in burst - 1
    assign axi_master_port.aw_size = 3'b010;    // Number of bytes per beat, 3'b011 for 8 bytes -- Let 4 bytes for 32b access
    assign axi_master_port.aw_burst = 0'b00;    // Burst type FIXED (0'b00)
    assign axi_master_port.aw_lock = '0;
    assign axi_master_port.aw_cache = '0;
    assign axi_master_port.aw_prot = 3'b0;       // Unpriviledged access
    assign axi_master_port.aw_qos = '0;
    assign axi_master_port.aw_region = '0;
    assign axi_master_port.aw_atop = '0;        // Configures atomic operations (AXI 5)
    assign axi_master_port.aw_user = '0;
    // assign axi_master_port.aw_valid;
    // assign axi_master_port.aw_ready;         // Input

    // // AXI write data channel
    // assign axi_master_port.w_data;
    assign axi_master_port.w_strb = '1;         // Strobe, byte enable
    assign axi_master_port.w_last = 1'b1;       // Single beat
    assign axi_master_port.w_user = '0;
    // assign axi_master_port.w_valid;
    // assign axi_master_port.w_ready;          // Input

    // // AXI write response channel
    // assign axi_master_port.b_id;             // Input
    // assign axi_master_port.b_resp;           // Input
    // assign axi_master_port.b_user;           // Input
    // assign axi_master_port.b_valid;          // Input
    // assign axi_master_port.b_ready;
 
    // // AXI read address channel
    assign axi_master_port.ar_id = '0;
    // assign axi_master_port.ar_addr;
    assign axi_master_port.ar_len = '0;         // Number of beats in burst - 1
    assign axi_master_port.ar_size = 3'b010;    // Number of bytes per beat, let 4 bytes for 32b access
    assign axi_master_port.ar_burst = 2'b00;    // Burst type FIXED
    assign axi_master_port.ar_lock = '0;
    assign axi_master_port.ar_cache = '0;
    assign axi_master_port.ar_prot = 3'b0;       // Unpriviledged access
    assign axi_master_port.ar_qos = '0;
    assign axi_master_port.ar_region = '0;
    assign axi_master_port.ar_user = '0;
    // assign axi_master_port.ar_valid; 
    // assign axi_master_port.ar_ready; // Input

    // // AXI read data channel
    // assign axi_master_port.r_id;     // Input
    // assign axi_master_port.r_data;   // Input
    // assign axi_master_port.r_resp;   // Input
    // assign axi_master_port.r_last;   // Input
    // assign axi_master_port.r_user;   // Input
    // assign axi_master_port.r_valid;  // Input
    // assign axi_master_port.r_ready;  

    initial begin
        
        @(posedge rst_ni);
        
        @(negedge clk_i); // Negedge because verilator does not handle posedge correctly.
        axi_master_port.ar_addr <= 64'h00000001;
        axi_master_port.ar_valid <= 1'b1;

        // Wait for ar_valid on clock edge
        @(negedge clk_i);// iff (axi_master_port.ar_ready == 1'b1));
        axi_master_port.ar_valid <= 1'b0;

        @(negedge clk_i);
        axi_master_port.r_ready <= 1'b1;

        // Wait for ar_valid on clock edge
        //@(negedge clk_i iff  (axi_master_port.r_valid == 1'b1));
        axi_master_port.r_ready <= 1'b0;
        
        @(posedge clk_i);
        @(posedge clk_i);
        //assign axi_master_port.r_ready = 1'b1;
        $finish;

    end

    

endmodule
