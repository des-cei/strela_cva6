// A test to integrate an AXI master in the CVA6 APU

// See axi_mem_if/src/axi2mem.sv for example use of AXI_BUS interface (as a slave that is)

module test_state_machines #(
    parameter int unsigned INPUT_NODES_NUM = 4
) (
    input   logic       clk_i,
    input   logic       rst_ni,
    AXI_LITE.Master     axi_master_port,

    // Execute
    input execute_i,

    // CGRA input data signals
    output  logic [32*INPUT_NODES_NUM-1:0] data_input_o,
    output  logic [INPUT_NODES_NUM-1:0] data_input_valid_o,
    input   logic [INPUT_NODES_NUM-1:0] data_input_ready_i,

    input   logic [31:0] data_input_addr_i [INPUT_NODES_NUM-1:0],
    input   logic [15:0] data_input_size_i [INPUT_NODES_NUM-1:0],
    input   logic [15:0] data_input_stride_i [INPUT_NODES_NUM-1:0],

    // Test
    input logic [31:0] r_address_i,
    input logic [31:0] r_data_i,
    output logic [31:0] r_data_o,
    input logic start_read_i,
    input logic start_write_i
);

    localparam MAX_OUTSTANDING = 6;
    localparam INPUT_FIFO_DEPTH = 10;

    typedef struct packed
    {
        logic [INPUT_NODES_NUM-1:0] input_pe_one_hot;
        logic odd_not_even_word;
    } input_trans_info_t;

    // AXI Lite signals:
    // aw_addr       w_data       b_resp       ar_addr      r_data
    // aw_prot       w_strb       b_valid      ar_prot      r_resp
    // aw_valid      w_valid      b_ready      ar_valid     r_valid
    // aw_ready      w_ready                   ar_ready     r_ready

    // Constant AXI signals
    assign axi_master_port.aw_prot = '0;    // Unpriviledged access
    assign axi_master_port.b_ready = 1'b1;  // No error checking on write response
    assign axi_master_port.ar_prot = '0;    // Unpriviledged access


    // Data input address calculation
    logic [31:0] data_input_addr_offs_d [INPUT_NODES_NUM-1:0];
    logic [31:0] data_input_addr_offs_q [INPUT_NODES_NUM-1:0];

    logic [31:0] axi_read_adress_d, axi_read_adress_q;

    // Data input arbitration
    logic [INPUT_NODES_NUM-1:0] data_input_arb_request;
    logic data_input_arb_enable;
    logic [INPUT_NODES_NUM-1:0] data_input_arb_grant_one_hot;
    logic [$clog2(INPUT_NODES_NUM)-1:0] data_input_arb_grant_idx;

    // AXI address read
    logic ar_master_free;
    logic new_ar_trans;

    logic wait_ar_q, wait_ar_d;
    logic wait_r_q, wait_r_d;


    // Input data FIFOs
    logic [INPUT_NODES_NUM-1:0] data_input_fifo_count [INPUT_NODES_NUM-1:0];

    logic [32:0] data_input_fifo_in [INPUT_NODES_NUM-1:0];
    logic [INPUT_NODES_NUM-1:0] data_input_fifo_push;
    logic [INPUT_NODES_NUM-1:0] data_input_fifo_full;

    logic [32:0] data_input_fifo_out [INPUT_NODES_NUM-1:0];
    logic [INPUT_NODES_NUM-1:0] data_input_fifo_pop;
    logic [INPUT_NODES_NUM-1:0] data_input_fifo_empty;

    // Input outstanding FIFO  
    input_trans_info_t input_outst_fifo_in;   
    logic input_outst_fifo_push;

    logic [$clog2(MAX_OUTSTANDING)-1:0] input_outst_fifo_count;

    input_trans_info_t input_outst_fifo_out;
    logic input_outst_fifo_pop;
    logic input_outst_fifo_empty;
    logic input_outst_fifo_full;



    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(!rst_ni) begin
            wait_ar_q <= 0;
            axi_read_adress_q <= '0;
            data_input_addr_offs_q <= '{default: '0};
        end else begin
            wait_ar_q <= wait_ar_d;
            axi_read_adress_q <= axi_read_adress_d;
            data_input_addr_offs_q <= data_input_addr_offs_d;            
        end

    end

    // Read address arbitration
    always_comb begin
        // Request
        for(int i=0; i < INPUT_NODES_NUM; i++) begin
            data_input_arb_request[i] = (data_input_fifo_count[i] < (INPUT_FIFO_DEPTH - MAX_OUTSTANDING)) &&
                                        (data_input_addr_offs_q[i] < data_input_size_i[i]);
        end

        data_input_arb_enable = ar_master_free & !input_outst_fifo_full;
        new_ar_trans = (data_input_arb_grant_one_hot != 0);

        // Increment addresses
        axi_read_adress_d = axi_read_adress_q; 
        data_input_addr_offs_d = data_input_addr_offs_q;

        for(int i=0; i<INPUT_NODES_NUM; i++) begin
            if(data_input_arb_grant_one_hot[i]) begin
                axi_read_adress_d = data_input_addr_offs_q[i] + data_input_addr_i[i];
                data_input_addr_offs_d[i] = data_input_addr_offs_q[i] + data_input_stride_i[i];
            end
        end

        
        // Save transaction in outstanding FIFO
        input_outst_fifo_in.input_pe_one_hot = data_input_arb_grant_one_hot;
        input_outst_fifo_in.odd_not_even_word = axi_read_adress_d[2]; // Even or odd 32 bit word for 64 bit access.
        input_outst_fifo_push = new_ar_trans;
    end
    
    // AXI read address
    always_comb begin
        wait_ar_d = wait_ar_q;

        ar_master_free = 1'b0;
        if (wait_ar_q) begin
            axi_master_port.ar_valid = 1'b1;
            if(axi_master_port.ar_ready) begin // Wait for ready
                ar_master_free = 1'b1;
                wait_ar_d = new_ar_trans;
            end
        end else begin
            axi_master_port.ar_valid = 1'b0;
            ar_master_free = 1'b1;
            wait_ar_d = new_ar_trans;
        end

        axi_master_port.ar_addr = {axi_read_adress_q[31:3], 3'b000};
    end

    // Input data reception
    always_comb begin
        logic [31:0] axi_r_data_word;

        axi_master_port.r_ready = 1'b1;

        // All input FIFOs read from the same bus
        axi_r_data_word = input_outst_fifo_out.odd_not_even_word ?
                    axi_master_port.r_data[63:32] : axi_master_port.r_data[31:0];

        for(int i=0; i<INPUT_NODES_NUM; i++)
            data_input_fifo_in[i] = axi_r_data_word;

        // Push to appropriate FIFO when new read data and pop outstanding
        if(axi_master_port.r_valid) begin
            data_input_fifo_push = input_outst_fifo_out.input_pe_one_hot;
            input_outst_fifo_pop = 1'b1;
        end else begin
            data_input_fifo_push = '0;
            input_outst_fifo_pop = 1'b0;
        end

        assert((data_input_fifo_push & data_input_fifo_full) == 0) else $error("Pushing to Input FIFO FULL!!");
    end


    round_robin_arbiter #(
        .WIDTH(INPUT_NODES_NUM)
    ) i_data_input_arbiter (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .request_i(data_input_arb_request),
        .grant_o(data_input_arb_grant_one_hot),
        .enable_i(data_input_arb_enable)
    );

    one_hot_to_bin # (
        .WIDTH(4)
    ) i_oh2b (
        .one_hot_i(data_input_arb_grant_one_hot),
        .bin_val_o(data_input_arb_grant_idx)
    );


    // Input data FIFOs
    generate
    for(genvar i = 0; i < INPUT_NODES_NUM; i++) begin : data_input_fifos
        fifo_v3 #(
            .DEPTH(INPUT_FIFO_DEPTH),
            .dtype(logic [31:0])
        ) i_data_input_fifo (
            .clk_i        ( clk_i                   ),
            .rst_ni       ( rst_ni                  ),
            .flush_i      ( 1'b0                    ),
            .testmode_i   ( 1'b0                    ),
            .usage_o      ( data_input_fifo_count[i]   ),
            .data_i       ( data_input_fifo_in[i]      ),
            .push_i       ( data_input_fifo_push[i]    ),
            .full_o       ( data_input_fifo_full[i]    ),
            .data_o       ( data_input_fifo_out[i]     ),
            .pop_i        ( data_input_fifo_pop[i]     ),
            .empty_o      ( data_input_fifo_empty[i]   ) 
        );
    end
    endgenerate

    // Outstanding transactions FIFO
    fifo_v3 #(
        .DEPTH(MAX_OUTSTANDING),
        .dtype(input_trans_info_t)
    ) i_input_outstanding_fifo (
        .clk_i        ( clk_i                   ),
        .rst_ni       ( rst_ni                  ),
        .flush_i      ( 1'b0                    ),
        .testmode_i   ( 1'b0                    ),
        .usage_o      ( input_outst_fifo_count  ),
        .data_i       ( input_outst_fifo_in     ),
        .push_i       ( input_outst_fifo_push   ),
        .full_o       ( input_outst_fifo_full   ),
        .data_o       ( input_outst_fifo_out    ),
        .pop_i        ( input_outst_fifo_pop    ),
        .empty_o      ( input_outst_fifo_empty  )
    );






    // // AXI Lite signals:
    // // aw_addr       w_data       b_resp       ar_addr      r_data
    // // aw_prot       w_strb       b_valid      ar_prot      r_resp
    // // aw_valid      w_valid      b_ready      ar_valid     r_valid
    // // aw_ready      w_ready                   ar_ready     r_ready

    // // Constant signals
    // assign axi_master_port.aw_prot = '0;    // Unpriviledged access
    // assign axi_master_port.b_ready = 1'b1;  // No error checking on write response
    // assign axi_master_port.ar_prot = '0;    // Unpriviledged access


    // logic wait_aw_q, wait_aw_d;
    // logic wait_w_q, wait_w_d;

    // logic wait_ar_q, wait_ar_d;
    // logic wait_r_q, wait_r_d;

    // logic [31:0] read_data_q, read_data_d;

    // assign r_data_o = read_data_q;


    // always_ff @(posedge clk_i) begin
    //     if(!rst_ni) begin
    //         wait_aw_q <= 0;
    //         wait_w_q  <= 0;
    //         wait_ar_q <= 0;
    //         wait_r_q  <= 0;

    //         read_data_q <= 0;
            
            
    //     end else begin

    //         wait_aw_q <= wait_aw_d;
    //         wait_w_q  <= wait_w_d;
    //         wait_ar_q <= wait_ar_d;
    //         wait_r_q  <= wait_r_d;
                        
    //         read_data_q <= read_data_d;
        
    //     end

    // end


    // always_comb begin
    //     // Defaults
    //     // Set data and strobes to write high or low word
    //     axi_master_port.aw_addr = {r_address_i[31:3], 3'b000};
    //     axi_master_port.w_data = {r_data_i, r_data_i};
    //     axi_master_port.w_strb = r_address_i[2] ? 8'hF0 : 8'h0F;

    //     axi_master_port.ar_addr = {r_address_i[31:3], 3'b000};
        
    //     axi_master_port.aw_valid = 1'b0;
    //     axi_master_port.w_valid = 1'b0;

    //     axi_master_port.ar_valid = 1'b0;
    //     axi_master_port.r_ready = 1'b0;
        
    //     wait_aw_d = wait_aw_q;
    //     wait_w_d = wait_w_q;
    //     wait_ar_d = wait_ar_q;
    //     wait_r_d = wait_r_q;

    //     read_data_d = read_data_q;

    //     if(start_write_i) begin
    //         wait_aw_d = 1;
    //         wait_w_d = 1;
    //     end

    //     if(start_read_i) begin
    //         wait_ar_d = 1;
    //         wait_r_d = 1;
    //     end

        
    //     // Write address
    //     if (wait_aw_q) begin
    //         // Wait for transaction
    //         axi_master_port.aw_valid = 1'b1;
    //         if(axi_master_port.aw_ready) // Wait for ready
    //             wait_aw_d  = 0;
    //     end

    //     // Write data
    //     if (wait_w_q) begin
    //         // Wait for transaction
    //         axi_master_port.w_valid = 1'b1;
    //         if(axi_master_port.w_ready) // Wait for ready
    //             wait_w_d  = 0;
    //     end

    //     // Read address
    //     if (wait_ar_q) begin
    //         // Wait for transaction
    //         axi_master_port.ar_valid = 1'b1;
    //         if(axi_master_port.ar_ready) // Wait for ready
    //             wait_ar_d  = 0;
    //     end

    //     // Read data
    //     if (wait_r_q) begin
    //         // Wait for transaction
    //         axi_master_port.r_ready = 1'b1;
    //         if(axi_master_port.r_valid) begin// Wait for ready
    //             wait_r_d  = 0;
    //             // Read in high or low word
    //             read_data_d = r_address_i[2] ? axi_master_port.r_data[63:32] : axi_master_port.r_data[31:0];
    //         end
    //     end
        
    // end

endmodule


module one_hot_to_bin # (
    parameter WIDTH=-1
) (
    input   logic [WIDTH-1:0] one_hot_i,
    output  logic [$clog2(WIDTH)-1:0] bin_val_o
);
    // One-hot to binary encoder (no priority)
    always_comb begin
        bin_val_o = 0;
        for(int i=0; i<WIDTH; i++) begin
            if(one_hot_i[i])
                bin_val_o |= i;
        end
    end

endmodule


module round_robin_arbiter #(
    parameter WIDTH = -1
) (
    input   logic   clk_i,
    input   logic   rst_ni,
    input   logic   [WIDTH-1:0] request_i,
    output  logic   [WIDTH-1:0] grant_o,
    input   logic   enable_i
);

    logic [WIDTH-1:0] rol_prev_grant_d, rol_prev_grant_q;
    logic [2*WIDTH-1:0] double_req;
    logic [2*WIDTH-1:0] double_grant;

    always_ff @(posedge clk_i) begin
        if(!rst_ni)
            rol_prev_grant_q <= WIDTH'(1);
        else begin
            rol_prev_grant_q <= rol_prev_grant_d;
        end
    end

    // Set grant_o to first bit set in request_i at or to the left of
    // the bit set in rol_prev_grant_q.
    always_comb begin
        // Subtraction of a one-hot vector from a value changes the first bit at or
        // to the left of the hot bit from 1 to 0.
        // Then: grant = request & ~(request - rotated_left_prev_grant) sets that bit to 1 in grant.
        // req and grant are doubled to handle wrap-around, e.g., double_grant = 0001_0000 --> grant_o = 0001
        double_req = {request_i, request_i};
        double_grant = double_req & ~(double_req-{WIDTH'(0),rol_prev_grant_q});

        if(enable_i)
            grant_o = double_grant[WIDTH-1:0] | double_grant[2*WIDTH-1:WIDTH];
        else
            grant_o = 0;

        if(grant_o != 0) // Rotate left previous grant output
            rol_prev_grant_d = {grant_o[WIDTH-2:0], grant_o[WIDTH-1]};
        else
            rol_prev_grant_d = rol_prev_grant_q;
    end

endmodule


// // One-hot vs binary....
//         for(int i=0; i<INPUT_NODES_NUM; i++) begin
//             if(data_input_arb_grant_one_hot[i]) begin
//                 axi_read_adress_d = data_input_addr_offs_q[i];
//                 data_input_addr_offs_d[i] = data_input_addr_offs_q[i] + data_input_stride_i[i];
//             end
//         end

//         axi_read_adress_d = data_input_addr_offs_q[data_input_arb_grant_idx];
