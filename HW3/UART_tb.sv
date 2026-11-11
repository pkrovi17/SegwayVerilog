`timescale 1ns/1ps

module UART_tb();

reg clk, rst_n, trmt, clr_rdy;
reg [7:0] tx_data;
wire TX, tx_done, rdy;
wire [7:0] rx_data;
integer tests;

UART_tx iTX(.clk(clk), .rst_n(rst_n), .trmt(trmt), .tx_data(tx_data),
             .TX(TX), .tx_done(tx_done));
UART_rx iRX(.clk(clk), .rst_n(rst_n), .RX(TX), .clr_rdy(clr_rdy),
             .rx_data(rx_data), .rdy(rdy));

initial clk = 0;
always #10 clk = ~clk;

task send_and_check;
  input [7:0] data;
  input clear_after;
  integer cycle;
  begin
    @(negedge clk); tx_data = data; trmt = 1;
    @(posedge clk); #1; trmt = 0;
    if (tx_done !== 0) begin
      $display("ERROR: tx_done did not clear on a new request");
      $stop();
    end
    // rx finishes mid stop
    for (cycle = 1; cycle <= 52080; cycle = cycle + 1) begin
      @(posedge clk); #1;
      if (tx_done !== (cycle == 52080)) begin
        $display("ERROR: incorrect tx_done timing, clock=%0d", cycle);
        $stop();
      end
      // allow srncro to settle
      if ((cycle >= 4) && (cycle < 49476) && (rdy !== 0)) begin
        $display("ERROR: stale or early rdy, clock=%0d", cycle);
        $stop();
      end
      if ((cycle >= 49480) && ((rdy !== 1) || (rx_data !== data))) begin
        $display("ERROR: sent=%h received=%h rdy=%b", data, rx_data, rdy);
        $stop();
      end
    end
    repeat (3) begin
      @(posedge clk); #1;
      if ((rdy !== 1) || (tx_done !== 1) || (rx_data !== data)) begin
        $display("ERROR: data or completion flags did not hold in idle");
        $stop();
      end
    end
    if (clear_after) begin
      @(negedge clk); clr_rdy = 1;
      @(posedge clk); #1;
      if ((rdy !== 0) || (rx_data !== data) || (tx_done !== 1)) begin
        $display("ERROR: clr_rdy should only clear the receiver flag");
        $stop();
      end
      @(negedge clk); clr_rdy = 0;
      repeat (3) begin
        @(posedge clk); #1;
        if (rdy !== 0) begin
          $display("ERROR: rdy reasserted without a new frame");
          $stop();
        end
      end
    end
    tests = tests + 1;
    $display("PASS: sent=0x%h received=0x%h, clr_rdy tested=%b", data, rx_data, clear_after);
  end
endtask

initial begin
  $dumpfile("UART.vcd");
  $dumpvars(0, TX, tx_data, rx_data, trmt, tx_done, rdy, clr_rdy, rst_n);
  tests = 0;
  rst_n = 1; trmt = 0; clr_rdy = 0; tx_data = 0;
  #2; rst_n = 0;
  #1;
  if ((TX !== 1) || (tx_done !== 0) || (rdy !== 0)) begin
    $display("ERROR: asynchronous reset");
    $stop();
  end
  @(negedge clk); rst_n = 1;
  repeat (5) @(negedge clk);
  if (rdy !== 0) begin
    $display("ERROR: receiver reported data on an idle line");
    $stop();
  end

  send_and_check(8'h00, 1);
  send_and_check(8'hff, 0);
  send_and_check(8'ha5, 0); // new start clears rdy
  send_and_check(8'h5a, 1);
  send_and_check(8'h01, 0);
  send_and_check(8'h80, 1);
  send_and_check(8'h3c, 0);

  // reset during acive frame and test recovery
  @(negedge clk); tx_data = 0; trmt = 1;
  @(negedge clk); trmt = 0;
  repeat (6000) @(posedge clk);
  #3; rst_n = 0;
  #1;
  if ((TX !== 1) || (tx_done !== 0) || (rdy !== 0)) begin
    $display("ERROR: reset did not abort the active frame");
    $stop();
  end
  @(negedge clk); rst_n = 1;
  send_and_check(8'h7e, 1);

  $display("Pranav Krovi (pkrovi): all %0d UART loopback tests passed!", tests);
  $finish();
end

initial begin
  #12000000;
  $display("ERROR: UART test timed out");
  $stop();
end

endmodule
