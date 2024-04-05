
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



    test_state_machines i_test_state_machines (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .axi_master_port (axi_lite_bus),

        .execute_i(1'b1),
        .data_input_o(),
        .data_input_valid_o(),
        .data_input_ready_i(),
        .data_input_addr_i('{32'h83000004,32'h82000000,32'h81000000,32'h80000000}),
        .data_input_size_i('{16'h20, 16'h10, 16'h20, 16'h10}),//'{default: '0}), // '{16'h8, 16'h8, 16'h8, 16'h8}
        .data_input_stride_i('{16'h8, 16'h8, 16'h8, 16'h8}), //'{16'h4, 16'h4, 16'h4, 16'h4}),

        // Test
        .r_address_i (test_r_address),
        .r_data_i (test_r_data_w),
        .r_data_o (test_r_data_r),
        .start_read_i (test_start_read),
        .start_write_i (test_start_write)
    );

endmodule
