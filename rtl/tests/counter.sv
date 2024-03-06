module counter(
    input       logic       clk_i,
    output      logic [7:0] count
);

    always_ff @(posedge clk_i) begin
        count <= count + 1;
    end

endmodule
