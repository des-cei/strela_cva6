// An AXI-Lite master
// Reads data from memory and stores it in FIFOs, where the CGRA reads from.
// Receives data from CGRA, stores in further FIFOs and from there to memory.

// Input data FIFOs
//  -----------------<< From memory
//  |   |   |   |
// |_| |_| |_| |_|
//  |___|___|___|  data_input_o
// |    CGRA     |
// |_____________|
//  |   |   |   |  data_output_i
// |_| |_| |_| |_|
//  |   |   |   |
//  ----------------->> To memory
// Output data FIFOs

// See axi_mem_if/src/axi2mem.sv for example use of AXI_BUS interface (as a slave that is)

module test_state_machines #(
    parameter int unsigned INPUT_NODES_NUM = 4,
    parameter int unsigned OUTPUT_NODES_NUM = 4
) (
    input   logic       clk_i,
    input   logic       rst_ni,
    AXI_LITE.Master     axi_master_port,

    // Execute
    input   logic execute_input_i,
    input   logic execute_output_i,

    // CGRA input data signals
    output  logic [32*INPUT_NODES_NUM-1:0] data_input_o,
    output  logic [INPUT_NODES_NUM-1:0] data_input_valid_o,
    input   logic [INPUT_NODES_NUM-1:0] data_input_ready_i,

    input   logic [31:0] data_input_addr_i [INPUT_NODES_NUM-1:0],
    input   logic [15:0] data_input_size_i [INPUT_NODES_NUM-1:0],
    input   logic [15:0] data_input_stride_i [INPUT_NODES_NUM-1:0],

    // CGRA output data signals
    input   logic [32*OUTPUT_NODES_NUM-1:0] data_output_i,
    input   logic [OUTPUT_NODES_NUM-1:0] data_output_valid_i,
    output  logic [OUTPUT_NODES_NUM-1:0] data_output_ready_o,

    input   logic [31:0] data_output_addr_i [OUTPUT_NODES_NUM-1:0],
    input   logic [15:0] data_output_size_i [OUTPUT_NODES_NUM-1:0],

    output  logic data_output_done_o
);

    localparam MAX_OUTSTANDING = 4;
    localparam INPUT_FIFO_DEPTH = 10;
    localparam OUTPUT_FIFO_DEPTH = 10;

    typedef struct packed
    {
        logic [INPUT_NODES_NUM-1:0] pe_one_hot;
        logic odd_not_even_word;
    } trans_info_t;

    // AXI Lite signals:
    // aw_addr       w_data       b_resp       ar_addr      r_data
    // aw_prot       w_strb       b_valid      ar_prot      r_resp
    // aw_valid      w_valid      b_ready      ar_valid     r_valid
    // aw_ready      w_ready                   ar_ready     r_ready

    // Constant AXI signals
    assign axi_master_port.aw_prot = '0;    // Unpriviledged access
    assign axi_master_port.b_ready = 1'b1;  // No error checking on write response
    assign axi_master_port.ar_prot = '0;    // Unpriviledged access


    /*********************************************
    *                INPUT DATA                  *
    **********************************************/
    // Execute
    logic data_input_execute_d, data_input_execute_q;

    // Data input address calculation
    logic [31:0] data_input_addr_offs_d [INPUT_NODES_NUM-1:0];
    logic [31:0] data_input_addr_offs_q [INPUT_NODES_NUM-1:0];

    logic [31:0] axi_read_adress_d, axi_read_adress_q;

    // Data input arbitration
    logic [INPUT_NODES_NUM-1:0] data_input_arb_request;
    logic data_input_arb_enable;
    logic [INPUT_NODES_NUM-1:0] data_input_arb_grant_one_hot;

    // AXI address read
    logic ar_master_free;
    logic new_ar_trans;

    logic wait_ar_q, wait_ar_d;

    // Input data FIFOs
    logic [$clog2(INPUT_FIFO_DEPTH)-1:0] data_input_fifo_count [INPUT_NODES_NUM-1:0];

    logic [32:0] data_input_fifo_in [INPUT_NODES_NUM-1:0];
    logic [INPUT_NODES_NUM-1:0] data_input_fifo_push;
    logic [INPUT_NODES_NUM-1:0] data_input_fifo_full;

    logic [32:0] data_input_fifo_out [INPUT_NODES_NUM-1:0];
    logic [INPUT_NODES_NUM-1:0] data_input_fifo_pop;
    logic [INPUT_NODES_NUM-1:0] data_input_fifo_empty;

    // Input outstanding FIFO  
    trans_info_t input_outst_fifo_in;   
    logic input_outst_fifo_push;
    logic [$clog2(MAX_OUTSTANDING)-1:0] input_outst_fifo_count;
    trans_info_t input_outst_fifo_out;
    logic input_outst_fifo_pop;
    logic input_outst_fifo_empty;
    logic input_outst_fifo_full;



    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(!rst_ni) begin
            data_input_execute_q <= 1'b0;
            wait_ar_q <= 1'b0;
            axi_read_adress_q <= '0;
            data_input_addr_offs_q <= '{default: '0};
        end else begin
            data_input_execute_q <= data_input_execute_d;
            wait_ar_q <= wait_ar_d;
            axi_read_adress_q <= axi_read_adress_d;
            data_input_addr_offs_q <= data_input_addr_offs_d;            
        end

    end

    // Execute
    always_comb begin
        data_input_execute_d = data_input_execute_q;
        if(execute_input_i)
            data_input_execute_d = 1'b1;
        else if (input_outst_fifo_empty)
            data_input_execute_d = 1'b0;
    end

    // Read address arbitration
    always_comb begin
        // Request
        for(int i=0; i < INPUT_NODES_NUM; i++) begin
            data_input_arb_request[i] = (data_input_fifo_count[i] < (INPUT_FIFO_DEPTH - MAX_OUTSTANDING)) &&
                                        (data_input_addr_offs_q[i] < data_input_size_i[i]);
        end

        data_input_arb_enable = data_input_execute_d & ar_master_free & !input_outst_fifo_full;
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
        input_outst_fifo_in.pe_one_hot = data_input_arb_grant_one_hot;
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
            data_input_fifo_push = input_outst_fifo_out.pe_one_hot;
            input_outst_fifo_pop = 1'b1;
        end else begin
            data_input_fifo_push = '0;
            input_outst_fifo_pop = 1'b0;
        end

        assert((data_input_fifo_push & data_input_fifo_full) == 0) else $error("Pushing to Input FIFO FULL!!");
    end

    // Input FIFO interface with CGRA
    always_comb begin
        for(int i=0; i<INPUT_NODES_NUM; i++)
            data_input_o[32*i+:32] = data_input_fifo_out[i];

        data_input_valid_o = ~data_input_fifo_empty;
        data_input_fifo_pop = data_input_valid_o & data_input_ready_i;
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

    // Input Outstanding transactions FIFO
    fifo_v3 #(
        .DEPTH(MAX_OUTSTANDING),
        .dtype(trans_info_t)
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


    /*********************************************
    *              OUTPUT DATA                   *
    **********************************************/
    // Execute
    logic data_output_execute_d, data_output_execute_q;

    // Data output address calculation
    logic [31:0] data_output_addr_offs_d [OUTPUT_NODES_NUM-1:0];
    logic [31:0] data_output_addr_offs_q [OUTPUT_NODES_NUM-1:0];

    logic [31:0] axi_write_adress_d, axi_write_adress_q;

    // Data output arbitration
    logic [OUTPUT_NODES_NUM-1:0] data_output_arb_request;
    logic data_output_arb_enable;
    logic [OUTPUT_NODES_NUM-1:0] data_output_arb_grant_one_hot;

    // AXI address write
    logic aw_master_free;
    logic new_aw_trans;

    logic wait_aw_q, wait_aw_d;


    // Output data FIFOs
    logic [$clog2(OUTPUT_FIFO_DEPTH)-1:0] data_output_fifo_count [OUTPUT_NODES_NUM-1:0];

    logic [32:0] data_output_fifo_in [OUTPUT_NODES_NUM-1:0];
    logic [OUTPUT_NODES_NUM-1:0] data_output_fifo_push;
    logic [OUTPUT_NODES_NUM-1:0] data_output_fifo_full;

    logic [32:0] data_output_fifo_out [INPUT_NODES_NUM-1:0];
    logic [OUTPUT_NODES_NUM-1:0] data_output_fifo_pop;
    logic [OUTPUT_NODES_NUM-1:0] data_output_fifo_empty;

    // Fifo unsent data counters
    logic [$clog2(OUTPUT_FIFO_DEPTH)-1:0] data_output_fifo_unsent_count [OUTPUT_NODES_NUM-1:0];

    // Output outstanding FIFO  
    trans_info_t output_outst_fifo_in;   
    logic output_outst_fifo_push;
    logic [$clog2(MAX_OUTSTANDING)-1:0] output_outst_fifo_count;
    trans_info_t output_outst_fifo_out;
    logic output_outst_fifo_pop;
    logic output_outst_fifo_empty;
    logic output_outst_fifo_full;



    always_ff @(posedge clk_i or negedge rst_ni) begin

        if(!rst_ni) begin
            data_output_execute_q <= 0;
            wait_aw_q <= 0;
            axi_write_adress_q <= '0;
            data_output_addr_offs_q <= '{default: '0};
        end else begin
            data_output_execute_q <= data_output_execute_d;
            wait_aw_q <= wait_aw_d;
            axi_write_adress_q <= axi_write_adress_d;
            data_output_addr_offs_q <= data_output_addr_offs_d;         
        end

    end

    logic [OUTPUT_NODES_NUM-1:0] data_output_address_under_size;

    // Address comparators
    always_comb begin
        for(int i=0; i < OUTPUT_NODES_NUM; i++)
            data_output_address_under_size[i] = data_output_addr_offs_q[i] < data_output_size_i[i];
    end

    // Execute
    always_comb begin
        data_output_execute_d = data_output_execute_q;
        if(execute_output_i)
            data_output_execute_d = 1'b1;
        else if (&(~data_output_address_under_size) && output_outst_fifo_empty)
            data_output_execute_d = 1'b0;

        data_output_done_o =  !data_output_execute_q;
    end

    // Write address arbitration
    always_comb begin
        // Request
        for(int i=0; i < OUTPUT_NODES_NUM; i++) begin
            data_output_arb_request[i] = (data_output_fifo_unsent_count[i] != 0) &&
                                         (data_output_address_under_size[i]);
        end

        data_output_arb_enable = data_output_execute_d & aw_master_free & !output_outst_fifo_full;
        new_aw_trans = (data_output_arb_grant_one_hot != 0);

        // Increment addresses
        axi_write_adress_d = axi_write_adress_q; 
        data_output_addr_offs_d = data_output_addr_offs_q;

        for(int i=0; i<OUTPUT_NODES_NUM; i++) begin
            if(data_output_arb_grant_one_hot[i]) begin
                axi_write_adress_d = data_output_addr_offs_q[i] + data_output_addr_i[i];
                data_output_addr_offs_d[i] = data_output_addr_offs_q[i] + 32'h4;
            end
        end

        // Save transaction in outstanding FIFO
        output_outst_fifo_in.pe_one_hot = data_output_arb_grant_one_hot;
        output_outst_fifo_in.odd_not_even_word = axi_write_adress_d[2]; // Even or odd 32 bit word for 64 bit access.
        output_outst_fifo_push = new_aw_trans;
    end
    
    // AXI write address
    always_comb begin
        wait_aw_d = wait_aw_q;

        aw_master_free = 1'b0;
        if (wait_aw_q) begin
            axi_master_port.aw_valid = 1'b1;
            if(axi_master_port.aw_ready) begin // Wait for ready
                aw_master_free = 1'b1;
                wait_aw_d = new_aw_trans;
            end
        end else begin
            axi_master_port.aw_valid = 1'b0;
            aw_master_free = 1'b1;
            wait_aw_d = new_aw_trans;
        end

        axi_master_port.aw_addr = {axi_write_adress_q[31:3], 3'b000};
    end

    // Send output data
    always_comb begin
        logic [31:0] axi_w_data_word = '0;

        axi_master_port.w_valid = |output_outst_fifo_out.pe_one_hot && !output_outst_fifo_empty;

        // Output data FIFO mux
        for(int i=0; i<OUTPUT_NODES_NUM; i++) begin // Note, maybe there is a better way to do this without implying priority.
            if(output_outst_fifo_out.pe_one_hot[i])
                axi_w_data_word = data_output_fifo_out[i];
        end

        // Data and strobe for 32 bit write on 64 bit bus.
        axi_master_port.w_data = {axi_w_data_word, axi_w_data_word};
        axi_master_port.w_strb = output_outst_fifo_out.odd_not_even_word ? 8'hF0 : 8'h0F;

        // Pop from appropriate FIFO when write data and pop outstanding
        if(axi_master_port.w_valid && axi_master_port.w_ready) begin
            data_output_fifo_pop = output_outst_fifo_out.pe_one_hot;
            output_outst_fifo_pop = 1'b1;
        end else begin
            data_output_fifo_pop = '0;
            output_outst_fifo_pop = 1'b0;
        end

        assert((data_output_fifo_pop & data_output_fifo_empty) == 0) else $error("Poping from Output FIFO EMPTY!!");
    end

    // Output FIFO interface with CGRA
    always_comb begin
        for(int i=0; i<OUTPUT_NODES_NUM; i++)
            data_output_fifo_in[i] = data_output_i[32*i+:32];

        data_output_ready_o = ~data_output_fifo_full;
        data_output_fifo_push = data_output_ready_o & data_output_valid_i;
    end


    round_robin_arbiter #(
        .WIDTH(OUTPUT_NODES_NUM)
    ) i_data_output_arbiter (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .request_i(data_output_arb_request),
        .grant_o(data_output_arb_grant_one_hot),
        .enable_i(data_output_arb_enable)
    );


    // Output data FIFOs
    generate
    for(genvar i = 0; i < OUTPUT_NODES_NUM; i++) begin : data_output_fifos
        fifo_v3 #(
            .DEPTH(OUTPUT_FIFO_DEPTH),
            .dtype(logic [31:0])
        ) i_data_output_fifo (
            .clk_i        ( clk_i                   ),
            .rst_ni       ( rst_ni                  ),
            .flush_i      ( 1'b0                    ),
            .testmode_i   ( 1'b0                    ),
            .usage_o      ( data_output_fifo_count[i]   ),
            .data_i       ( data_output_fifo_in[i]      ),
            .push_i       ( data_output_fifo_push[i]    ),
            .full_o       ( data_output_fifo_full[i]    ),
            .data_o       ( data_output_fifo_out[i]     ),
            .pop_i        ( data_output_fifo_pop[i]     ),
            .empty_o      ( data_output_fifo_empty[i]   ) 
        );
    end
    endgenerate

    // Unsent output data counter (i.e., sent write address but not yet write data)
    generate
    for(genvar i = 0; i < OUTPUT_NODES_NUM; i++) begin : data_output_fifo_unsent_counters
        up_down_counter #(
            .WIDTH($clog2(OUTPUT_FIFO_DEPTH))
        ) i_up_down_counter (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .up_i(data_output_fifo_push[i]),
            .down_i(data_output_arb_grant_one_hot[i]),
            .count_o(data_output_fifo_unsent_count[i])
        );
    end
    endgenerate

    // Output outstanding transactions FIFO
    fifo_v3 #(
        .DEPTH(MAX_OUTSTANDING),
        .dtype(trans_info_t)
    ) i_output_outstanding_fifo (
        .clk_i        ( clk_i                   ),
        .rst_ni       ( rst_ni                  ),
        .flush_i      ( 1'b0                    ),
        .testmode_i   ( 1'b0                    ),
        .usage_o      ( output_outst_fifo_count  ),
        .data_i       ( output_outst_fifo_in     ),
        .push_i       ( output_outst_fifo_push   ),
        .full_o       ( output_outst_fifo_full   ),
        .data_o       ( output_outst_fifo_out    ),
        .pop_i        ( output_outst_fifo_pop    ),
        .empty_o      ( output_outst_fifo_empty  )
    );


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



module up_down_counter # (
    parameter WIDTH=-1
) (
    input   logic   clk_i,
    input   logic   rst_ni,
    input   logic   up_i,
    input   logic   down_i,
    output  logic [$clog2(WIDTH)-1:0] count_o
);
    always_ff @(posedge clk_i) begin
        if (!rst_ni)
            count_o <= '0;
        else begin // If both up and down do not change count
            if ({up_i, down_i} == 2'b10)
                count_o <= count_o + 1;
            else if ({up_i, down_i} == 2'b01)
                count_o <= count_o - 1;
        end
    end
endmodule
