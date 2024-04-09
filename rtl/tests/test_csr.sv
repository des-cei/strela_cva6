module test_csr #(
    parameter type reg_req_t  = logic,
    parameter type reg_rsp_t  = logic,
    parameter INPUT_NODES_NUM = 4,
    parameter OUTPUT_NODES_NUM = 4
) (
    input  logic clk_i,   // Clock
    input  logic rst_ni,  // Asynchronous reset active low
    
    // Bus Interface
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    // To memory
    output logic [31:0] data_input_addr_o [INPUT_NODES_NUM-1:0],
    output logic [15:0] data_input_size_o [INPUT_NODES_NUM-1:0],
    output logic [15:0] data_input_stride_o [INPUT_NODES_NUM-1:0],

    output logic [31:0] data_output_addr_o [OUTPUT_NODES_NUM-1:0],
    output logic [15:0] data_output_size_o [OUTPUT_NODES_NUM-1:0],

    input  logic test_done_i,
    output logic execute_o
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
            // Test
            8'h00: reg_rsp_o.rdata = op_a;
            8'h04: reg_rsp_o.rdata = op_b;
            8'h08: reg_rsp_o.rdata = op_a + op_b;

            // Input
            8'h10: reg_rsp_o.rdata = data_input_addr_o[0];
            8'h14: reg_rsp_o.rdata = {data_input_stride_o[0], data_input_size_o[0]};

            8'h18: reg_rsp_o.rdata = data_input_addr_o[1];
            8'h1C: reg_rsp_o.rdata = {data_input_stride_o[1], data_input_size_o[1]};

            8'h20: reg_rsp_o.rdata = data_input_addr_o[2];
            8'h24: reg_rsp_o.rdata = {data_input_stride_o[2], data_input_size_o[2]};

            8'h28: reg_rsp_o.rdata = data_input_addr_o[3];
            8'h2C: reg_rsp_o.rdata = {data_input_stride_o[3], data_input_size_o[3]};

            // Output
            8'h30: reg_rsp_o.rdata = data_output_addr_o[0];
            8'h34: reg_rsp_o.rdata = data_output_size_o[0];

            8'h38: reg_rsp_o.rdata = data_output_addr_o[1];
            8'h3C: reg_rsp_o.rdata = data_output_size_o[1];

            8'h40: reg_rsp_o.rdata = data_output_addr_o[2];
            8'h44: reg_rsp_o.rdata = data_output_size_o[2];

            8'h48: reg_rsp_o.rdata = data_output_addr_o[3];
            8'h4C: reg_rsp_o.rdata = data_output_size_o[3];

            // Control/status
            8'h50: reg_rsp_o.rdata = test_done_i;

            default: reg_rsp_o.rdata = '0;
        endcase
    end

    // Register write
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            op_a <= '0;
            op_b <= '0;

            data_input_addr_o <= '{32'h8300000C,32'h82000008,32'h81000004,32'h80000000};
            data_input_size_o <= '{16'h8, 16'h8, 16'h8, 16'h8};
            data_input_stride_o <= '{16'h8, 16'h8, 16'h8, 16'h8};

            data_output_addr_o <= '{32'h9300005C,32'h92000058,32'h91000054,32'h90000050};
            data_output_size_o <= '{16'h04, 16'h04, 16'h04, 16'h04};


        end else begin
            if(reg_we) begin
            case(reg_addr)
                8'h00: op_a <= reg_req_i.wdata;
                8'h04: op_b <= reg_req_i.wdata;

                // Input
                8'h10: data_input_addr_o[0] <= reg_req_i.wdata;
                8'h14: {data_input_stride_o[0], data_input_size_o[0]} <= reg_req_i.wdata;

                8'h18: data_input_addr_o[1] <= reg_req_i.wdata;
                8'h1C: {data_input_stride_o[1], data_input_size_o[1]} <= reg_req_i.wdata;

                8'h20: data_input_addr_o[2] <= reg_req_i.wdata;
                8'h24: {data_input_stride_o[2], data_input_size_o[2]} <= reg_req_i.wdata;

                8'h28: data_input_addr_o[3] <= reg_req_i.wdata;
                8'h2C: {data_input_stride_o[3], data_input_size_o[3]} <= reg_req_i.wdata;

                // Output
                8'h30: data_output_addr_o[0] <= reg_req_i.wdata;
                8'h34: data_output_size_o[0] <= reg_req_i.wdata;

                8'h38: data_output_addr_o[1] <= reg_req_i.wdata;
                8'h3C: data_output_size_o[1] <= reg_req_i.wdata;

                8'h40: data_output_addr_o[2] <= reg_req_i.wdata;
                8'h44: data_output_size_o[2] <= reg_req_i.wdata;

                8'h48: data_output_addr_o[3] <= reg_req_i.wdata;
                8'h4C: data_output_size_o[3] <= reg_req_i.wdata;

                // Control/status
                8'h50: execute_o <= reg_req_i.wdata;

            endcase
            end else begin
                execute_o <= 0;
            end
        end
    end

endmodule
