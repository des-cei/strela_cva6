module sim_top(
    input       logic       clk_i,
    input       logic       rst_ni,
    output      logic [31:0] count
);

logic [31:0] count_q, count_d;

assign count = count_q;

always_ff @(posedge clk_i) begin
    if(!rst_ni)
        count_q <= '0;
    else begin
        count_q <= count_d;
    end

    // Default
    count_d = count_q + 1;

    case(count_q)

        // 10: begin

        //     slave[0].aw_addr <= 32'h9000_0000;
        //     slave[0].w_data  <= 64'haaaa_bbbb_cccc_dddd;
            
            
        //     slave[0].aw_size <= 3'b011;
        //     slave[0].w_strb <= 8'b11110000;
        //     slave[0].w_last <= 1'b1;

        //     slave[0].aw_valid <= 1;
        //     slave[0].w_valid <= 1;

        //     slave[0].b_ready <= 1;

        // end


        // 0: begin
        //     master[ariane_soc::DRAM].aw_ready <= 1'b1;
        //     master[ariane_soc::DRAM].w_ready <= 1'b1;
        //     master[ariane_soc::DRAM].b_valid <= 1'b1;
        // master[ariane_soc::DRAM].b_id <= 'h20;
        // end

        // Address   32'h5000_0014
        // Wdata     32'h5000_0018
        // Start     32'h5000_001C


        10: begin

            slave[0].aw_addr <= 32'h5000_0010;
            slave[0].w_data  <= 32'h9000_0004;
            
            
            slave[0].aw_size <= 3'b010;
            slave[0].w_strb <= '1;
            slave[0].w_last <= 1'b1;

            slave[0].aw_valid <= 1;
            slave[0].w_valid <= 1;

            slave[0].b_ready <= 1;

        end

        20: begin

            slave[0].aw_addr <= 32'h5000_0020;
            slave[0].w_data  <= 32'h2424_4242;
            
        end

        30: begin

            slave[0].aw_addr <= 32'h5000_0028;
            slave[0].w_data  <= 32'h0000_0001;
            
        end


        
        200: $finish;
    endcase
end





AXI_BUS #(
.AXI_ADDR_WIDTH ( AxiAddrWidth     ),
.AXI_DATA_WIDTH ( AxiDataWidth     ),
.AXI_ID_WIDTH   ( AxiIdWidthMaster ),
.AXI_USER_WIDTH ( AxiUserWidth     )
) axi_bus_interface();


localparam NBSlave = 3; // debug, ariane + CGRA // MODIFIED: Increased from 2 to 3
localparam AxiAddrWidth = 64;
localparam AxiDataWidth = 64;
localparam AxiIdWidthMaster = 4;
localparam AxiIdWidthSlaves = AxiIdWidthMaster + $clog2(NBSlave); // 5
localparam AxiUserWidth = 64; //ariane_pkg::AXI_USER_WIDTH;


AXI_BUS #(
.AXI_ADDR_WIDTH ( AxiAddrWidth     ),
.AXI_DATA_WIDTH ( AxiDataWidth     ),
.AXI_ID_WIDTH   ( AxiIdWidthMaster ),
.AXI_USER_WIDTH ( AxiUserWidth     )
) slave[NBSlave-1:0]();

AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) master[ariane_soc::NB_PERIPHERALS-1:0]();

// ---------------
// AXI Xbar
// ---------------

axi_pkg::xbar_rule_64_t [ariane_soc::NB_PERIPHERALS-1:0] addr_map;

assign addr_map = '{
'{ idx: ariane_soc::Debug,    start_addr: ariane_soc::DebugBase,    end_addr: ariane_soc::DebugBase + ariane_soc::DebugLength       },
'{ idx: ariane_soc::ROM,      start_addr: ariane_soc::ROMBase,      end_addr: ariane_soc::ROMBase + ariane_soc::ROMLength           },
'{ idx: ariane_soc::CLINT,    start_addr: ariane_soc::CLINTBase,    end_addr: ariane_soc::CLINTBase + ariane_soc::CLINTLength       },
'{ idx: ariane_soc::PLIC,     start_addr: ariane_soc::PLICBase,     end_addr: ariane_soc::PLICBase + ariane_soc::PLICLength         },
'{ idx: ariane_soc::UART,     start_addr: ariane_soc::UARTBase,     end_addr: ariane_soc::UARTBase + ariane_soc::UARTLength         },
'{ idx: ariane_soc::Timer,    start_addr: ariane_soc::TimerBase,    end_addr: ariane_soc::TimerBase + ariane_soc::TimerLength       },
'{ idx: ariane_soc::SPI,      start_addr: ariane_soc::SPIBase,      end_addr: ariane_soc::SPIBase + ariane_soc::SPILength           },
'{ idx: ariane_soc::Ethernet, start_addr: ariane_soc::EthernetBase, end_addr: ariane_soc::EthernetBase + ariane_soc::EthernetLength },
'{ idx: ariane_soc::GPIO,     start_addr: ariane_soc::GPIOBase,     end_addr: ariane_soc::GPIOBase + ariane_soc::GPIOLength         },
'{ idx: ariane_soc::DRAM,     start_addr: ariane_soc::DRAMBase,     end_addr: ariane_soc::DRAMBase + ariane_soc::DRAMLength         },
'{ idx: ariane_soc::Accelerator,     start_addr: ariane_soc::AcceleratorBase,     end_addr: ariane_soc::AcceleratorBase + ariane_soc::AcceleratorLength}
};

localparam axi_pkg::xbar_cfg_t AXI_XBAR_CFG = '{
    NoSlvPorts:         ariane_soc::NrSlaves,
    NoMstPorts:         ariane_soc::NB_PERIPHERALS,
    MaxMstTrans:        2, // Probably requires update
    MaxSlvTrans:        2, // Probably requires update
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_PORTS, //  axi_pkg::NO_LATENCY, // 
    AxiIdWidthSlvPorts: AxiIdWidthMaster,
    AxiIdUsedSlvPorts:  AxiIdWidthMaster,
    UniqueIds:          1'b0,
    AxiAddrWidth:       AxiAddrWidth,
    AxiDataWidth:       AxiDataWidth,
    NoAddrRules:        ariane_soc::NB_PERIPHERALS
};

axi_xbar_intf #(
.AXI_USER_WIDTH ( AxiUserWidth            ),
.Cfg            ( AXI_XBAR_CFG            ),
.rule_t         ( axi_pkg::xbar_rule_64_t )
) i_axi_xbar (
.clk_i                 ( clk_i      ), // clk
.rst_ni                ( rst_ni     ), // ndmreset_n 
.test_i                ( 1'b0       ), // test_en
.slv_ports             ( slave      ),
.mst_ports             ( master     ),
.addr_map_i            ( addr_map   ),
.en_default_mst_port_i ( '0         ),
.default_mst_port_i    ( '0         )
);


/////////////////// MASTER SLAVE TEST ///////////////////////////
axi_master_slave_test #(
    .AXI_ID_WIDTH_MASTER   ( AxiIdWidthMaster ),
    .AXI_ID_WIDTH_SLAVE    ( AxiIdWidthSlaves ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) i_axi_master_slave_test (
    .clk_i                  ( clk_i      ), // clk
    .rst_ni                 ( rst_ni     ), // ndmreset_n 
    .axi_slave_port         (master[ariane_soc::Accelerator]),
    .axi_master_port        (slave[2])
);





////////////// AXI to memory ///////////////

logic ram_req = '0;
logic ram_we = '0;
logic [7:0] ram_be = '0;
logic [63:0] ram_addr = '0;
logic [63:0] ram_rdata;
logic [63:0] ram_wdata = '0;


axi2mem #(
.AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
.AXI_ADDR_WIDTH ( AxiAddrWidth     ),
.AXI_DATA_WIDTH ( AxiDataWidth     ),
.AXI_USER_WIDTH ( AxiUserWidth     )
) i_axi2rom (
    .clk_i  ( clk_i                   ),
    .rst_ni ( rst_ni                  ),
    .slave  ( master[ariane_soc::DRAM]), // axi_bus_interface ///////////////////////////////////////////////
    .req_o  ( ram_req                 ),
    .we_o   ( ram_we                  ),
    .addr_o ( ram_addr                ),
    .be_o   ( ram_be                  ),
    .data_o ( ram_wdata               ),
    .data_i ( ram_rdata               ),
    .user_i (                         ),
    .user_o (                         )
);

test_ram_64 i_test_ram(
    .clk_i      (clk_i),
    .req_i      (ram_req),
    .we_i       (ram_we),
    .be_i       (ram_be),
    .addr_i     (ram_addr),
    .rdata_o    (ram_rdata),
    .wdata_i    (ram_wdata)
);

endmodule


/////////////////// SLAVE TEST ///////////////////////////
// axi_slave_test #(
//     .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
//     .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
//     .AXI_DATA_WIDTH ( AxiDataWidth     ),
//     .AXI_USER_WIDTH ( AxiUserWidth     )
// ) i_axi_slave_test (
//     .clk_i                 ( clk_i      ), // clk
//     .rst_ni                ( rst_ni     ), // ndmreset_n 
//     .axi_slave_port         (master[ariane_soc::Accelerator])
// );

/////////////////// MASTER TEST //////////////////////////
// axi_master_test #(
//     .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
//     .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
//     .AXI_DATA_WIDTH ( AxiDataWidth     ),
//     .AXI_USER_WIDTH ( AxiUserWidth     ),
//     .ADDRESS('h9000_0008),
//     .DATA('h1234)
// ) axi_master_test_2_i (
//     .clk_i  (clk_i),
//     .rst_ni (rst_ni),
//     .axi_master_port (slave[0]) // Slave port in xbar // axi_bus_interface
// );

// axi_master_test #(
//     .AXI_ID_WIDTH   ( AxiIdWidthMaster ),
//     .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
//     .AXI_DATA_WIDTH ( AxiDataWidth     ),
//     .AXI_USER_WIDTH ( AxiUserWidth     ),
//     .ADDRESS('h9000_0004),
//     .DATA('hABCD)
// ) axi_master_test_i (
//     .clk_i  (clk_i),
//     .rst_ni (rst_ni),
//     .axi_master_port (slave[2]) // Slave port in xbar // axi_bus_interface
// );




// initial begin
    
//     //@(posedge rst_ni);

//     @(negedge clk_i);
//     repeat(10) @(negedge clk_i);

//     $finish;

//     // repeat(1) @(negedge clk_i);
//     // ram_req = 1'b1;
//     // @(negedge clk_i);
//     // ram_req = 1'b1;
//     // ram_addr = 'd8;
//     // @(negedge clk_i);
//     // ram_req = 1'b0;

//     // @(negedge clk_i);
//     // ram_we = 1'b1;
//     // ram_wdata = 64'h0123_4567_89AB_CDEF;

//     // @(negedge clk_i);
//     // ram_we = 1'b0;
//     // ram_req = 1'b1;

// end

// cgra_axi_master #(
//     .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
//     .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
//     .AXI_DATA_WIDTH ( AxiDataWidth     ),
//     .AXI_USER_WIDTH ( AxiUserWidth     )
// ) cgra_axi_master_i (
//     .clk_i  (clk_i),
//     .rst_ni (rst_ni),
//     .axi_master_port (axi_bus_interface)
// );

