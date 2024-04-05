module test_tb();
logic clk = 1'b0;
logic rst_n = 1'b0;

logic [7:0] count;

initial begin
    $dumpfile("waveform.vcd");
    for(int i=0; i<200; i++) begin
        #1
        clk = ~ clk;
        if(i > 5 && clk == 1'b0)
            rst_n = 1'b1;
        $dumpvars();
    end
    $finish;
end

    counter count1 (.clk_i(clk), .rst_ni(rst_n), .count(count));

endmodule
