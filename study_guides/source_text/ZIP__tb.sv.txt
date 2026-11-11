`timescale 1ns/1ps

module tb;

    reg d;
    reg clk;
    wire q;

    dff dut (
        .d(d),
        .clk(clk),
        .q(q)
    );

    // Clock period = 10 ns
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        d = 0;

        #7  d = 1;
        #10 d = 0;
        #10 d = 1;
        #10 d = 0;

        #10 $finish;
    end

endmodule