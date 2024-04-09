
`include "register_interface/assign.svh"
`include "register_interface/typedef.svh"


module axi_cgra_top #(
    parameter int unsigned AXI_ID_WIDTH_MASTER  = -1,
    parameter int unsigned AXI_ID_WIDTH_SLAVE   = -1,
    parameter int unsigned AXI_ADDR_WIDTH       = -1,
    parameter int unsigned AXI_DATA_WIDTH       = -1,
    parameter int unsigned AXI_USER_WIDTH       = -1
) (
    input   logic       clk_i,
    input   logic       rst_ni,
    AXI_BUS.Slave       axi_slave_port,
    AXI_BUS.Master      axi_master_port
);

    localparam INPUT_NODES_NUM = 4;
    localparam OUTPUT_NODES_NUM = 4;

    logic test_cgra_execute_input;
    logic test_cgra_execute_output;

    // For simulation only
    logic [31:0] count_q;
    always_ff @(posedge clk_i) begin
        if(!rst_ni)
            count_q <= '0;

        // Default
        count_q <= count_q + 1;

        case(count_q)
            0:  begin
                test_cgra_execute_input <= 0;
                test_cgra_execute_output <= 0;
            end

            10: begin
                test_cgra_execute_input <= 1;
                test_cgra_execute_output <= 1;
            end
            11: begin
                test_cgra_execute_input <= 0;
                test_cgra_execute_output <= 0;
            end

            // 12: test_cgra_execute_output <= 1;
            // 13: test_cgra_execute_output <= 0;
            
        endcase
    end

    // define types regbus_req_t, regbus_rsp_t
    `REG_BUS_TYPEDEF_ALL(regbus, logic[31:0], logic[31:0], logic[3:0])
    regbus_req_t regbus_req;
    regbus_rsp_t regbus_rsp;

    AXI_LITE #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH        ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH        )
    ) axi_lite_bus();




    axi_slave_to_reg_adapter #(
        .AXI_ID_WIDTH_MASTER    ( AXI_ID_WIDTH_MASTER   ),
        .AXI_ID_WIDTH_SLAVE     ( AXI_ID_WIDTH_SLAVE    ),
        .AXI_ADDR_WIDTH         ( AXI_ADDR_WIDTH        ),
        .AXI_DATA_WIDTH         ( AXI_DATA_WIDTH        ),
        .AXI_USER_WIDTH         ( AXI_USER_WIDTH        ),
        .regbus_req_t           ( regbus_req_t          ),
        .regbus_rsp_t           ( regbus_rsp_t          )
    ) i_axi_slave_to_reg_adapter (
        .clk_i                  ( clk_i             ),
        .rst_ni                 ( rst_ni            ),
        .axi_slave_port         ( axi_slave_port    ),
        .regbus_req_o           ( regbus_req        ),
        .regbus_rsp_i           ( regbus_rsp        )
    );


    axi_lite_to_axi_intf #(
        .AXI_DATA_WIDTH (64)
    ) i_axi_lite_to_axi_adpter (
        .in             ( axi_lite_bus      ),
        .slv_aw_cache_i ( '0                ),
        .slv_ar_cache_i ( '0                ),
        .out            ( axi_master_port   )
    );


    logic [31:0] test_r_address;
    logic [31:0] test_r_data_w;
    logic [31:0] test_r_data_r;
    logic test_start_read;
    logic test_start_write;

    test_csr #(
        .reg_req_t      ( regbus_req_t      ),
        .reg_rsp_t      ( regbus_rsp_t      )
    ) i_test_reg_interface (
        .clk_i          ( clk_i             ),
        .rst_ni         ( rst_ni            ),
        .reg_req_i      ( regbus_req        ),
        .reg_rsp_o      ( regbus_rsp        ),

        .r_address_o    ( test_r_address    ),
        .r_data_o       ( test_r_data_w     ),
        .r_data_i       ( test_r_data_r     ),
        .start_read_o   ( test_start_read   ),
        .start_write_o  ( test_start_write  )
    );

    logic [32*INPUT_NODES_NUM-1:0] cgra_data_input_data;
    logic [INPUT_NODES_NUM-1:0] cgra_data_input_valid;
    logic [INPUT_NODES_NUM-1:0] cgra_data_input_ready;

    logic [32*OUTPUT_NODES_NUM-1:0] cgra_data_output_data;
    logic [OUTPUT_NODES_NUM-1:0] cgra_data_output_valid;
    logic [OUTPUT_NODES_NUM-1:0] cgra_data_output_ready;

    test_state_machines i_test_state_machines (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .axi_master_port (axi_lite_bus),

        // Execute
        .execute_input_i(test_cgra_execute_input),
        .execute_output_i(test_cgra_execute_output),

        // CGRA input data signals
        .data_input_o        ( cgra_data_input_data ),
        .data_input_valid_o  ( cgra_data_input_valid ),
        .data_input_ready_i  ( cgra_data_input_ready ),
        .data_input_addr_i   ('{32'h8300000C,32'h82000008,32'h81000004,32'h80000000}),
        .data_input_size_i   ('{16'h8, 16'h8, 16'h8, 16'h8}), // '{16'h20, 16'h10, 16'h20, 16'h10}
        .data_input_stride_i ('{16'h8, 16'h8, 16'h8, 16'h8}),

        // CGRA output data signals
        .data_output_i       ( cgra_data_output_data ),
        .data_output_valid_i ( cgra_data_output_valid ),
        .data_output_ready_o ( cgra_data_output_ready ),
        .data_output_addr_i  ( '{32'h9300005C,32'h92000058,32'h91000054,32'h90000050}),
        .data_output_size_i  ( '{16'h04, 16'h04, 16'h04, 16'h04}), // '{16'h10, 16'h08, 16'h10, 16'h08}
        .data_output_done_o  ( )
    );


    mock_CGRA cgra_i
    (
        .clk                ( clk_i ),
        .rst_n              (  ),
        .clk_bs             (  ),
        .rst_n_bs           (  ),
        .data_in            ( cgra_data_input_data   ),
        .data_in_valid      ( cgra_data_input_valid  ),
        .data_in_ready      ( cgra_data_input_ready  ),
        .data_out           ( cgra_data_output_data  ),
        .data_out_valid     ( cgra_data_output_valid ),
        .data_out_ready     ( cgra_data_output_ready ),
        .config_bitstream   (  ),
        .bitstream_enable_i (  ),
        .execute_i          (  )
    );

endmodule
