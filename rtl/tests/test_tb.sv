module test_tb();
logic clk = 1'b0;
logic [7:0] count;

initial begin
    $dumpfile("waveform.vcd");
    for(int i=0; i<200; i++) begin
        #100
        clk = ~ clk;
        $dumpvars();
    end
    $finish;
end

    counter count1 (.clk_i(clk), .count(count));

endmodule
