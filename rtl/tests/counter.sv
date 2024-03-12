module counter(
    input       logic       clk_i,
    input       logic       rst_ni,
    output      logic [7:0] count
);

    always_ff @(posedge clk_i) begin
        if(!rst_ni)
            count <= '0;
        else begin
            count <= count + 1;
        end
    end


    localparam NBSlave = 2; // debug, ariane
    localparam AxiAddrWidth = 64;
    localparam AxiDataWidth = 64;
    localparam AxiIdWidthMaster = 4;
    localparam AxiIdWidthSlaves = AxiIdWidthMaster + $clog2(NBSlave); // 5
    localparam AxiUserWidth = 64;

    AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthMaster ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
    ) axi_bus_interface();



    initial begin
        
        //@(posedge rst_ni);

        @(negedge clk_i);
        repeat(20) @(negedge clk_i);

        //$finish;

        // repeat(1) @(negedge clk_i);
        // ram_req = 1'b1;
        // @(negedge clk_i);
        // ram_req = 1'b1;
        // ram_addr = 'd8;
        // @(negedge clk_i);
        // ram_req = 1'b0;

        // @(negedge clk_i);
        // ram_we = 1'b1;
        // ram_wdata = 64'h0123_4567_89AB_CDEF;

        // @(negedge clk_i);
        // ram_we = 1'b0;
        // ram_req = 1'b1;

    end

    cgra_axi_master #(
        .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
        .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
        .AXI_DATA_WIDTH ( AxiDataWidth     ),
        .AXI_USER_WIDTH ( AxiUserWidth     )
    ) cgra_axi_master_i (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .axi_master_port (axi_bus_interface)
    );
    

  

    // AXI master will see this interface as AXI_BUS.Master 
    




    // AXI to memory -----------------------

    logic ram_req = '0;
    logic ram_we = '0;
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
        .slave  ( axi_bus_interface       ),
        .req_o  ( ram_req                 ),
        .we_o   ( ram_we                  ),
        .addr_o ( ram_addr                ),
        .be_o   (                         ),
        .data_o ( ram_wdata               ),
        .data_i ( ram_rdata               ),
        .user_i (                         ),
        .user_o (                         )
    );

    test_ram_64 i_test_ram(
        .clk_i      (clk_i),
        .req_i      (ram_req),
        .we_i       (ram_we),
        .addr_i     (ram_addr),
        .rdata_o    (ram_rdata),
        .wdata_i    (ram_wdata)
    );

endmodule
