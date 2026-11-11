module dff (
    input  wire d,
    input  wire clk,
    output wire q
);

    wire md, mq, sd;
    wire nclk;

    // Inverted clock
    not (nclk, clk);

    // Master latch
    notif1 t1(md, d, nclk);
    not    i1(mq, md);
    not (weak1, weak0) keep1(md, mq);

    // Slave latch
    notif1 t2(sd, mq, clk);
    not    i2(q, sd);
    not (weak1, weak0) keep2(sd, q);

endmodule