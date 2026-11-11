module synch_detect (
    input  asynch_sig_in,
    input  clk,
    input  rst_n,
    output rise_edge
);

    wire sync_ff1;
    wire sync_ff2;

    // prev synchroed values
    wire sync_ff2_dly;
    wire sync_ff2_dly_n;

    // samples async
    dff ff_sync1 (
        .D   (asynch_sig_in),
        .clk (clk),
        .PRN (rst_n),
        .Q   (sync_ff1)
    );

    // complete synchro
    dff ff_sync2 (
        .D   (sync_ff1),
        .clk (clk),
        .PRN (rst_n),
        .Q   (sync_ff2)
    );

    // delay for edge
    dff ff_delay (
        .D   (sync_ff2),
        .clk (clk),
        .PRN (rst_n),
        .Q   (sync_ff2_dly)
    );

    // high for when rising edge detected
    not inv_prev (sync_ff2_dly_n, sync_ff2_dly);
    and and_rise (rise_edge, sync_ff2, sync_ff2_dly_n);

endmodule
