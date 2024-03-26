module test_csr #(
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

    // For monitoring in simulation
    logic [31:0] reg_write_data;
    assign reg_write_data = reg_req_i.wdata;

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

endmodule
