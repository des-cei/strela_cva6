module counter(
    input       logic       clk_i,
    input       logic       rst_ni,
    output      logic [7:0] count
);

    always_ff @(posedge clk_i) begin
        if(!rst_ni)
            count <= '0;
        else
            count <= count + 1;
    end

    logic ram_req = '0;
    logic ram_we = '0;
    logic [63:0] ram_addr = '0;
    logic [63:0] ram_rdata;
    logic [63:0] ram_wdata = '0;

    initial begin
        @(posedge rst_ni);

        repeat(1) @(negedge clk_i);
        ram_req = 1'b1;
        @(negedge clk_i);
        ram_req = 1'b1;
        ram_addr = 'd8;
        @(negedge clk_i);
        ram_req = 1'b0;

        @(negedge clk_i);
        ram_we = 1'b1;
        ram_wdata = 64'h0123_4567_89AB_CDEF;

        @(negedge clk_i);
        ram_we = 1'b0;
        ram_req = 1'b1;

    end


    test_ram_64 i_test_ram(
        .clk_i      (clk_i),
        .req_i      (ram_req),
        .we_i       (ram_we),
        .addr_i     (ram_addr),
        .rdata_o    (ram_rdata),
        .wdata_i    (ram_wdata)
    );  

    // axi2mem #(
    // .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    // .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    // .AXI_DATA_WIDTH ( AxiDataWidth     ),
    // .AXI_USER_WIDTH ( AxiUserWidth     )
    // ) i_axi2rom (
    //     .clk_i  ( clk                     ),
    //     .rst_ni ( ndmreset_n              ),
    //     .slave  ( master[ariane_soc::ROM] ),
    //     .req_o  ( rom_req                 ),
    //     .we_o   (                         ),
    //     .addr_o ( rom_addr                ),
    //     .be_o   (                         ),
    //     .data_o (                         ),
    //     .data_i ( rom_rdata               )
    // );


endmodule
