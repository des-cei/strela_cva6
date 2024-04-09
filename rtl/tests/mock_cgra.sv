module mock_CGRA # (
    parameter int DATA_WIDTH = 32
) (
    // Clock and reset
    input  logic                        clk,
    input  logic                        clk_bs,
    input  logic                        rst_n,
    input  logic                        rst_n_bs,

    // Input data
    input  logic [4*DATA_WIDTH-1:0]     data_in,
    input  logic [3:0]                  data_in_valid,
    output logic [3:0]                  data_in_ready,

    // Output data
    output logic [4*DATA_WIDTH-1:0]     data_out,
    output logic [3:0]                  data_out_valid,
    input  logic [3:0]                  data_out_ready,

    // Configuration
    input  logic [159:0]                config_bitstream,
    input  logic                        bitstream_enable_i,
    input  logic                        execute_i
);

always_comb begin

    data_out = data_in;
    data_out_valid = data_in_valid;
    data_in_ready = data_out_ready;

end


endmodule
