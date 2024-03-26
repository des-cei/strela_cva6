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
    assign axi_master_port.b_ready = 1'b1;      // No error checking
 
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

    enum logic [1:0]
    {
        S_IDLE = 2'b00,
        S_ADDR = 2'b01
    } state_ra_d, state_ra_q;

    typedef struct packed
    {
        logic [1:0] input_pe_idx;
        logic odd_not_even_word;
    } input_trans_info_t;

    localparam MAX_OUTSTANDING = 4;
    localparam INPUT_FIFO_DEPTH = 8;
    
    // Simulated inputs
    logic execute_i;
    logic [31:0] input_addr_i;
    logic [15:0] input_size_i;
    logic [15:0] input_stride_i;

    logic [15:0] addr_offset_d, addr_offset_q;

    // Read outstanding FIFO
    input_trans_info_t input_outst_fifo_in;
    input_trans_info_t input_outst_fifo_out;

    logic input_outst_fifo_push;
    logic input_outst_fifo_pop;

    logic input_outst_fifo_empty;
    logic input_outst_fifo_full;

    // Input data FIFO

    logic [31:0] input_data_fifo_in;
    logic [31:0] input_data_fifo_out;

    logic input_data_fifo_push;
    logic input_data_fifo_pop;

    logic input_data_fifo_empty;
    logic input_data_fifo_full;

    logic [3:0] input_data_fifo_count;

    logic input_data_fifo_pop_enable;

    //logic input_data_fifo_



    initial begin

        // Test FIFO

        // @(posedge rst_ni);
        // @(negedge clk_i);
        // test_fifo_push = 1'b0;
        // test_fifo_push = 1'b0;
        

        // @(negedge clk_i);

        // test_fifo_push = 1'b1;
        // test_fifo_input = '{input_pe_idx: 1, odd_not_even_word: 1'b1};

        // @(negedge clk_i);

        // test_fifo_push = 1'b1;
        // test_fifo_input = '{input_pe_idx: 2, odd_not_even_word: 1'b0};

        // @(negedge clk_i);
        // @(negedge clk_i);
        // test_fifo_pop = 1'b1;
        


        // Test generate address
        input_addr_i = '0;
        input_stride_i = 16;
        input_size_i = 100;
        execute_i = 0;

        @(posedge rst_ni);

        @(negedge clk_i);
        @(negedge clk_i);
        execute_i = 1;

        repeat(15) @(posedge clk_i);

        input_data_fifo_pop_enable = 1'b1;

        repeat(20) @(posedge clk_i);

        $finish;



    end

    assign input_data_fifo_pop = !input_data_fifo_empty & input_data_fifo_pop_enable;


    // TEST
    assign axi_master_port.r_ready = 1'b1;

    // Outstanding fifo
    fifo_v3 #(
        .DEPTH(MAX_OUTSTANDING),
        .dtype(input_trans_info_t)
    ) input_trans_outstanding_fifo (
        .clk_i        ( clk_i                   ),
        .rst_ni       ( rst_ni                  ),
        .flush_i      ( 1'b0                    ),
        .testmode_i   ( 1'b0                    ),
        .usage_o      (                         ),
        .data_i       ( input_outst_fifo_in     ),
        .push_i       ( input_outst_fifo_push   ),
        .full_o       ( input_outst_fifo_full   ),
        .data_o       ( input_outst_fifo_out    ),
        .pop_i        ( input_outst_fifo_pop    ),
        .empty_o      ( input_outst_fifo_empty  )
    );
    
    /**********************************
    *           Read data
    **********************************/
    
    // axi_master_port.r_data


    fifo_v3 #(
        .DEPTH(INPUT_FIFO_DEPTH),
        .dtype(logic [31:0])
    ) input_data_fifo (
        .clk_i        ( clk_i                   ),
        .rst_ni       ( rst_ni                  ),
        .flush_i      ( 1'b0                    ),
        .testmode_i   ( 1'b0                    ),
        .usage_o      ( input_data_fifo_count   ),
        .data_i       ( input_data_fifo_in      ),
        .push_i       ( input_data_fifo_push    ),
        .full_o       ( input_data_fifo_full    ),
        .data_o       ( input_data_fifo_out     ),
        .pop_i        ( input_data_fifo_pop     ),
        .empty_o      ( input_data_fifo_empty   ) 
    );


    always_comb begin

        // Write incomming data into input data FIFO, extract transaction
        // from outstanding FIFO.
        axi_master_port.r_ready = !input_data_fifo_full;

        input_data_fifo_push = axi_master_port.r_valid && axi_master_port.r_ready;
        input_outst_fifo_pop = input_data_fifo_push;

        if(input_outst_fifo_out.odd_not_even_word)
            input_data_fifo_in = axi_master_port.r_data[63:32];
        else
            input_data_fifo_in = axi_master_port.r_data[31:00];

    end


    /**********************************
    *           Read address
    **********************************/

    always_ff @(posedge clk_i) begin
        if(~rst_ni) begin
            addr_offset_q <= '0;
            state_ra_q <= S_IDLE;
        end else begin
            addr_offset_q <= addr_offset_d;
            state_ra_q <= state_ra_d;
        end
    end

    

    always_comb begin
        // Read address
        axi_master_port.ar_addr = input_addr_i + addr_offset_q;

        // Defaults
        addr_offset_d = addr_offset_q;
        axi_master_port.ar_valid = 1'b0;

        // Outstanding FIFO
        input_outst_fifo_push = 1'b0;
        input_outst_fifo_in.input_pe_idx = '0; // TEST
        input_outst_fifo_in.odd_not_even_word = axi_master_port.ar_addr[2]; // Even or odd 32 bit word for 64 bit access.

        unique case (state_ra_q)
            S_IDLE: begin
                addr_offset_d = 0;

                if(execute_i & input_size_i != 0)
                    state_ra_d = S_ADDR;
                else
                    state_ra_d = S_IDLE;
            end

            S_ADDR: begin
                // If ready keep sending addresses until done.

                axi_master_port.ar_valid = !input_outst_fifo_full &&
                                        (input_data_fifo_count < (INPUT_FIFO_DEPTH - MAX_OUTSTANDING)); // Send address if below outstanding limit

                if(axi_master_port.ar_ready && axi_master_port.ar_valid) begin
                    addr_offset_d = addr_offset_q + input_stride_i; // Increment adress
                    input_outst_fifo_push = 1'b1;                   // Save transaction in oustanding FIFO
                end
                
                if(addr_offset_d >= input_size_i)
                    state_ra_d = S_IDLE;
                else
                    state_ra_d = S_ADDR;
            end

        endcase

    end




   



    // initial begin
        
    //     state = S_ADDR;

    //     @(posedge rst_ni);
        
    //     @(negedge clk_i); // Negedge because verilator does not handle posedge correctly.
    //     axi_master_port.ar_addr <= 64'h00000001;
    //     axi_master_port.ar_valid <= 1'b1;

    //     // Wait for ar_valid on clock edge
    //     @(negedge clk_i);// iff (axi_master_port.ar_ready == 1'b1));
    //     axi_master_port.ar_valid <= 1'b0;

    //     @(negedge clk_i);
    //     axi_master_port.r_ready <= 1'b1;

    //     // Wait for ar_valid on clock edge
    //     //@(negedge clk_i iff  (axi_master_port.r_valid == 1'b1));
    //     axi_master_port.r_ready <= 1'b0;
        
    //     @(posedge clk_i);
    //     @(posedge clk_i);
    //     //assign axi_master_port.r_ready = 1'b1;
    //     $finish;

    // end





    

endmodule
