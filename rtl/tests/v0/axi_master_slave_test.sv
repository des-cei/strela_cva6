`include "register_interface/assign.svh"
`include "register_interface/typedef.svh"

module axi_master_slave_test #(
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
        .AXI4_ID_WIDTH      ( AXI_ID_WIDTH_SLAVE   ),
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



    logic [31:0] test_r_address;
    logic [31:0] test_r_data_w;
    logic [31:0] test_r_data_r;
    logic test_start_read;
    logic test_start_write;

    test_reg_interface #(
        .reg_req_t   ( regbus_req_t            ),
        .reg_rsp_t   ( regbus_rsp_t            )
    ) i_test_reg_interface (
        .clk_i            (clk_i),
        .rst_ni           (rst_ni),
        .reg_req_i        ( regbus_req    ),
        .reg_rsp_o        ( regbus_rsp    ),

        .r_address_o (test_r_address),
        .r_data_o (test_r_data_w),
        .r_data_i (test_r_data_r),
        .start_read_o (test_start_read),
        .start_write_o (test_start_write)
    );

    test_axi_master #(
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_MASTER ),
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH      ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH      ),
        .ADDRESS('h9000_0000),
        .DATA('hABCD)
    ) axi_master_test_i (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .axi_master_port (axi_master_port),

        .r_address_i (test_r_address),
        .r_data_i (test_r_data_w),
        .r_data_o (test_r_data_r),
        .start_read_i (test_start_read),
        .start_write_i (test_start_write)
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
  output reg_rsp_t reg_rsp_o,

  // Test
  output logic [31:0] r_address_o,
  output logic [31:0] r_data_o,
  input  logic [31:0] r_data_i,
  output logic start_read_o,
  output logic start_write_o
);

// Register interface signals

// reg_req_i.addr
// reg_req_i.write
// reg_req_i.wdata
// reg_req_i.wstrb
// reg_req_i.valid

// reg_rsp_o.rdata
// reg_rsp_o.error
// reg_rsp_o.ready

    logic [7:0]     reg_addr;
    logic           reg_we;
    
    assign reg_rsp_o.ready = 1'b1;
    assign reg_rsp_o.error = 1'b0;

    assign reg_addr = reg_req_i.addr;
    assign reg_we = reg_req_i.valid & reg_req_i.write;

    logic [31:0] reg_write_data;

    assign reg_write_data = reg_req_i.wdata; //////

    // Some registers
    logic [31:0] op_a;
    logic [31:0] op_b;


    // Register read
    always_comb begin
        case(reg_addr)
            8'h00: reg_rsp_o.rdata = op_a;
            8'h04: reg_rsp_o.rdata = op_b;
            8'h08: reg_rsp_o.rdata = op_a + op_b;

            8'h10: reg_rsp_o.rdata = r_address_o;
            8'h18: reg_rsp_o.rdata = r_data_i;
            8'h20: reg_rsp_o.rdata = r_data_o;

            default: reg_rsp_o.rdata = '0;
        endcase
    end

    // Register write
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            op_a <= '0;
            op_b <= '0;
        end else begin
            if(reg_we) begin
            case(reg_addr)
                8'h00: op_a <= reg_req_i.wdata;
                8'h04: op_b <= reg_req_i.wdata;

                8'h10: r_address_o <= reg_req_i.wdata;
                8'h20: r_data_o <= reg_req_i.wdata;

                8'h28:  {start_read_o, start_write_o} <= reg_req_i.wdata[1:0]; 

            endcase
            end else begin
                {start_read_o, start_write_o} <= 2'b00;
            end
        end
    end

    //assign reg_rsp_o.rdata = 32'hAAAA_5555;
endmodule

// A test to integrate an AXI master in the CVA6 APU
// Just writes some values in a memory range.

// See axi_mem_if/src/axi2mem.sv for example use of AXI_BUS interface (as a slave that is)

module test_axi_master #(
    parameter int unsigned AXI_ID_WIDTH      = -1,
    parameter int unsigned AXI_ADDR_WIDTH    = -1,
    parameter int unsigned AXI_DATA_WIDTH    = -1,
    parameter int unsigned AXI_USER_WIDTH    = -1,
    parameter logic [31:0] ADDRESS,
    parameter logic [31:0] DATA
) (
    input   logic       clk_i,
    input   logic       rst_ni,
    AXI_BUS.Master      axi_master_port,

    // Test
    input logic [31:0] r_address_i,
    input logic [31:0] r_data_i,
    output logic [31:0] r_data_o,
    input logic start_read_i,
    input logic start_write_i
);
    // Default values. See "Table A10-1 Master interface write channel signals and default signal values"

    // // AXI write address channel
    assign axi_master_port.aw_id = '0;
    // assign axi_master_port.aw_addr;
    assign axi_master_port.aw_len = '0;         // Number of beats in burst - 1
    assign axi_master_port.aw_size = 3'b011;    // Number of bytes per beat, 3'b011 for 8 bytes -- Let 4 bytes for 32b access
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
    // assign axi_master_port.w_strb = '1;         // Strobe, byte enable
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
    assign axi_master_port.ar_size = 3'b011;    // Number of bytes per beat, let 4 bytes for 32b access
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

    // -----------------------------------




    // logic [3:0] timer_aw_q, timer_aw_d;
    // logic [3:0] timer_w_q, timer_w_d;
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

    // r_address_islave[0]
    // r_data_i
    // r_data_o
    // start_read_i
    // start_write_i


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


        // Write data 

        // CAREFUL: When writing to register interface,
        // from 64 bit AXI bus, data for odd addresses
        // must be on higher halfword.
        // E.g. : Address: 32'h5000_0010 Data: 32'h9000_0000
        //        Address: 32'h5000_0014 Data: 64'h9000_0000_0000_0000 

        // axi_master_port.aw_addr = 32'h5000_0010;
        // axi_master_port.aw_size = 3'b010;
        // axi_master_port.aw_valid = 1;

        // axi_master_port.w_data  = 32'h9000_0000;
        // axi_master_port.w_strb = '1;
        // axi_master_port.w_last = 1'b1;
        // axi_master_port.w_valid = 1;

        // axi_master_port.b_ready = 1;



        // // Read data:
        // axi_master_port.ar_addr = 'h5000_0000;
        // axi_master_port.ar_valid = 1'b1;

        // axi_master_port.r_ready = 1'b1;
        
    end

endmodule



        // // Write address
        // if (timer_aw_q == 0) begin
        //     // Wait for transaction
        //     axi_master_port.aw_valid = 1'b1;
        //     if(!axi_master_port.aw_ready) // Wait for ready
        //         timer_aw_d = timer_aw_q;
        // end

        // // Write data
        // if (timer_w_q == 0) begin
        //     // Wait for transaction
        //     axi_master_port.w_valid = 1'b1;
        //     if(!axi_master_port.w_ready) // Wait for ready
        //         timer_w_d = timer_w_q;
        // end
    // Write to a memory range

    // Write same data always

    //assign axi_master_port.w_valid = 1'b1; 
 
    //logic [63:0] write_address_d, write_address_q;
    //localparam start_address = 32'h9000_0000;
    //localparam end_address   = 32'h9000_0100;
    // localparam start_address = 32'h0000_0000;
    // localparam end_address   = 32'h0000_0032;



    // always_ff @(posedge clk_i) begin
    //     if(!rst_ni) begin
    //         write_address_q <= ADRESS;
    //     end else begin
    //         timer_q <= timer_d + 1;
    //         axi_master_port.w_valid <= 1'b1;
    //         axi_master_port.aw_valid <= 1'b1;
    //     end
    // end
