// A test to integrate an AXI master in the CVA6 APU
// Just writes some values in a memory range.

// See axi_mem_if/src/axi2mem.sv for example use of AXI_BUS interface (as a slave that is)

module test_state_machines #(
) (
    input   logic       clk_i,
    input   logic       rst_ni,
    AXI_LITE.Master     axi_master_port,

    // Test
    input logic [31:0] r_address_i,
    input logic [31:0] r_data_i,
    output logic [31:0] r_data_o,
    input logic start_read_i,
    input logic start_write_i
);

    // AXI Lite signals:
    // aw_addr       w_data       b_resp       ar_addr      r_data
    // aw_prot       w_strb       b_valid      ar_prot      r_resp
    // aw_valid      w_valid      b_ready      ar_valid     r_valid
    // aw_ready      w_ready                   ar_ready     r_ready

    // Constant signals
    assign axi_master_port.aw_prot = '0;    // Unpriviledged access
    assign axi_master_port.b_ready = 1'b1;  // No error checking on write response
    assign axi_master_port.ar_prot = '0;    // Unpriviledged access


    logic wait_aw_q, wait_aw_d;
    logic wait_w_q, wait_w_d;

    logic wait_ar_q, wait_ar_d;
    logic wait_r_q, wait_r_d;

    logic [31:0] read_data_q, read_data_d;

    assign r_data_o = read_data_q;


    always_ff @(posedge clk_i) begin
        if(!rst_ni) begin
            wait_aw_q <= 0;
            wait_w_q  <= 0;
            wait_ar_q <= 0;
            wait_r_q  <= 0;

            read_data_q <= 0;
            
            
        end else begin

            wait_aw_q <= wait_aw_d;
            wait_w_q  <= wait_w_d;
            wait_ar_q <= wait_ar_d;
            wait_r_q  <= wait_r_d;
                        
            read_data_q <= read_data_d;
        
        end

    end


    always_comb begin
        // Defaults
        // Set data and strobes to write high or low word
        axi_master_port.aw_addr = {r_address_i[31:3], 3'b000};
        axi_master_port.w_data = {r_data_i, r_data_i};
        axi_master_port.w_strb = r_address_i[2] ? 8'hF0 : 8'h0F;

        axi_master_port.ar_addr = {r_address_i[31:3], 3'b000};
        
        axi_master_port.aw_valid = 1'b0;
        axi_master_port.w_valid = 1'b0;

        axi_master_port.ar_valid = 1'b0;
        axi_master_port.r_ready = 1'b0;
        
        wait_aw_d = wait_aw_q;
        wait_w_d = wait_w_q;
        wait_ar_d = wait_ar_q;
        wait_r_d = wait_r_q;

        read_data_d = read_data_q;

        if(start_write_i) begin
            wait_aw_d = 1;
            wait_w_d = 1;
        end

        if(start_read_i) begin
            wait_ar_d = 1;
            wait_r_d = 1;
        end

        
        // Write address
        if (wait_aw_q) begin
            // Wait for transaction
            axi_master_port.aw_valid = 1'b1;
            if(axi_master_port.aw_ready) // Wait for ready
                wait_aw_d  = 0;
        end

        // Write data
        if (wait_w_q) begin
            // Wait for transaction
            axi_master_port.w_valid = 1'b1;
            if(axi_master_port.w_ready) // Wait for ready
                wait_w_d  = 0;
        end

        // Read address
        if (wait_ar_q) begin
            // Wait for transaction
            axi_master_port.ar_valid = 1'b1;
            if(axi_master_port.ar_ready) // Wait for ready
                wait_ar_d  = 0;
        end

        // Read data
        if (wait_r_q) begin
            // Wait for transaction
            axi_master_port.r_ready = 1'b1;
            if(axi_master_port.r_valid) begin// Wait for ready
                wait_r_d  = 0;
                // Read in high or low word
                read_data_d = r_address_i[2] ? axi_master_port.r_data[63:32] : axi_master_port.r_data[31:0];
            end
        end
        
    end

endmodule
