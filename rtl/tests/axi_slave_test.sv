module axi_slave_test #(
    parameter int unsigned AXI_ID_WIDTH      = -1,
    parameter int unsigned AXI_ADDR_WIDTH    = -1,
    parameter int unsigned AXI_DATA_WIDTH    = -1,
    parameter int unsigned AXI_USER_WIDTH    = -1,
) (
    input   logic       clk_i,
    input   logic       rst_ni,
    AXI_BUS.Slave       axi_slave_port
);

//                         _______________                  ____________                    ___________
// <--- AXI_BUS.Slave --->| axi2apb_64_32 |<---APB bus --->| apb_to_reg |<---- reg_bus --->| Registers |
//                        |_______________|                |____________|                  |___________|

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus (clk_i);

    // APB bus signals
    logic         apb_penable;
    logic         apb_pwrite;
    logic [31:0]  apb_paddr;
    logic         apb_psel;
    logic [31:0]  apb_pwdata;
    logic [31:0]  apb_prdata;
    logic         apb_pready;
    logic         apb_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI4_RDATA_WIDTH   ( AXI_DATA_WIDTH ),
        .AXI4_WDATA_WIDTH   ( AXI_DATA_WIDTH ),
        .AXI4_ID_WIDTH      ( AXI_ID_WIDTH   ),
        .AXI4_USER_WIDTH    ( AXI_USER_WIDTH ),
        .BUFF_DEPTH_SLAVE   ( 2              ),
        .APB_ADDR_WIDTH     ( 32             )
    ) i_axi2apb_64_32_accelerator (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( axi_slave_port.aw_id     ),
        .AWADDR_i  ( axi_slave_port.aw_addr   ),
        .AWLEN_i   ( axi_slave_port.aw_len    ),
        .AWSIZE_i  ( axi_slave_port.aw_size   ),
        .AWBURST_i ( axi_slave_port.aw_burst  ),
        .AWLOCK_i  ( axi_slave_port.aw_lock   ),
        .AWCACHE_i ( axi_slave_port.aw_cache  ),
        .AWPROT_i  ( axi_slave_port.aw_prot   ),
        .AWREGION_i( axi_slave_port.aw_region ),
        .AWUSER_i  ( axi_slave_port.aw_user   ),
        .AWQOS_i   ( axi_slave_port.aw_qos    ),
        .AWVALID_i ( axi_slave_port.aw_valid  ),
        .AWREADY_o ( axi_slave_port.aw_ready  ),
        .WDATA_i   ( axi_slave_port.w_data    ),
        .WSTRB_i   ( axi_slave_port.w_strb    ),
        .WLAST_i   ( axi_slave_port.w_last    ),
        .WUSER_i   ( axi_slave_port.w_user    ),
        .WVALID_i  ( axi_slave_port.w_valid   ),
        .WREADY_o  ( axi_slave_port.w_ready   ),
        .BID_o     ( axi_slave_port.b_id      ),
        .BRESP_o   ( axi_slave_port.b_resp    ),
        .BVALID_o  ( axi_slave_port.b_valid   ),
        .BUSER_o   ( axi_slave_port.b_user    ),
        .BREADY_i  ( axi_slave_port.b_ready   ),
        .ARID_i    ( axi_slave_port.ar_id     ),
        .ARADDR_i  ( axi_slave_port.ar_addr   ),
        .ARLEN_i   ( axi_slave_port.ar_len    ),
        .ARSIZE_i  ( axi_slave_port.ar_size   ),
        .ARBURST_i ( axi_slave_port.ar_burst  ),
        .ARLOCK_i  ( axi_slave_port.ar_lock   ),
        .ARCACHE_i ( axi_slave_port.ar_cache  ),
        .ARPROT_i  ( axi_slave_port.ar_prot   ),
        .ARREGION_i( axi_slave_port.ar_region ),
        .ARUSER_i  ( axi_slave_port.ar_user   ),
        .ARQOS_i   ( axi_slave_port.ar_qos    ),
        .ARVALID_i ( axi_slave_port.ar_valid  ),
        .ARREADY_o ( axi_slave_port.ar_ready  ),
        .RID_o     ( axi_slave_port.r_id      ),
        .RDATA_o   ( axi_slave_port.r_data    ),
        .RRESP_o   ( axi_slave_port.r_resp    ),
        .RLAST_o   ( axi_slave_port.r_last    ),
        .RUSER_o   ( axi_slave_port.r_user    ),
        .RVALID_o  ( axi_slave_port.r_valid   ),
        .RREADY_i  ( axi_slave_port.r_ready   ),
        .PENABLE   ( apb_penable   ),
        .PWRITE    ( apb_pwrite    ),
        .PADDR     ( apb_paddr     ),
        .PSEL      ( apb_psel      ),
        .PWDATA    ( apb_pwdata    ),
        .PRDATA    ( apb_prdata    ),
        .PREADY    ( apb_pready    ),
        .PSLVERR   ( apb_pslverr   )
    );

    apb_to_reg i_apb_to_reg (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( apb_penable ),
        .pwrite_i  ( apb_pwrite  ),
        .paddr_i   ( apb_paddr   ),
        .psel_i    ( apb_psel    ),
        .pwdata_i  ( apb_pwdata  ),
        .prdata_o  ( apb_prdata  ),
        .pready_o  ( apb_pready  ),
        .pslverr_o ( apb_pslverr ),
        .reg_o     ( reg_bus      )
    );

    // define reg type according to REG_BUS above
    `REG_BUS_TYPEDEF_ALL(regbus, logic[31:0], logic[31:0], logic[3:0])
    regbus_req_t regbus_req;
    regbus_rsp_t regbus_rsp;

    // assign REG_BUS.out to (req_t, rsp_t) pair
    `REG_BUS_ASSIGN_TO_REQ(regbus_req, reg_bus)
    `REG_BUS_ASSIGN_FROM_RSP(reg_bus, regbus_rsp)

    plic_top #(
      .N_SOURCE    ( ariane_soc::NumSources  ),
      .N_TARGET    ( ariane_soc::NumTargets  ),
      .MAX_PRIO    ( ariane_soc::MaxPriority ),
      .reg_req_t   ( regbus_req_t            ),
      .reg_rsp_t   ( regbus_rsp_t            )
    ) i_plic (
      .clk_i,
      .rst_ni,
      .req_i         ( regbus_req    ),
      .resp_o        ( regbus_rsp    ),
      .le_i          ( '0          ), // 0:level 1:edge
      .irq_sources_i ( irq_sources ),
      .eip_targets_o ( irq_o       )
    );


endmodule


module test_reg_interface #(
    parameter type reg_req_t  = logic,
    parameter type reg_rsp_t  = logic
) (
  input  logic clk_i,   // Clock
  input  logic rst_ni,  // Asynchronous reset active low
  // Bus Interface
  input  reg_req_t reg_req_i,
  output reg_rsp_t reg_rsp_o
);




endmodule