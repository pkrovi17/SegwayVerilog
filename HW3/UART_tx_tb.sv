`timescale 1ns/1ps

module UART_tx_tb();

reg clk, rst_n, trmt;
reg [7:0] tx_data;
wire TX, tx_done;
integer tests;

UART_tx iDUT(.clk(clk), .rst_n(rst_n), .trmt(trmt), .tx_data(tx_data),
             .TX(TX), .tx_done(tx_done));

initial clk = 0;
always #10 clk = ~clk; // 50 MHz

task send_and_check;
  input [7:0] data;
  reg [9:0] frame;
  integer bit_num, cycle;
  begin
    frame = {1'b1, data, 1'b0}; // Stop, data, start; bit 0 goes first.
    @(negedge clk);
    tx_data = data;
    trmt = 1;
    @(posedge clk); #1;
    trmt = 0;
    tx_data = ~data; // The accepted byte must have been captured.

    // Check every clock, including all start and stop bit clocks.
    for (bit_num = 0; bit_num < 10; bit_num = bit_num + 1) begin
      for (cycle = 0; cycle < 5208; cycle = cycle + 1) begin
        if ((TX !== frame[bit_num]) || (tx_done !== 0)) begin
          $display("ERROR: byte=%h bit=%0d clock=%0d TX=%b expected=%b done=%b",
                   data, bit_num, cycle, TX, frame[bit_num], tx_done);
          $stop();
        end
        // A request while busy must not replace the current frame.
        if ((bit_num == 3) && (cycle == 0)) trmt = 1;
        if ((bit_num == 3) && (cycle == 1)) trmt = 0;
        @(posedge clk); #1;
      end
    end
    if ((TX !== 1) || (tx_done !== 1)) begin
      $display("ERROR: missing completion after the full stop bit");
      $stop();
    end
    repeat (3) begin
      @(posedge clk); #1;
      if ((TX !== 1) || (tx_done !== 1)) begin
        $display("ERROR: idle TX or sticky tx_done");
        $stop();
      end
    end
    tests = tests + 1;
    $display("PASS: byte=0x%h, 10 bits, 5208 clocks/bit", data);
  end
endtask

initial begin
  $dumpfile("UART_tx.vcd");
  // Record interface signals without dumping every counter transition.
  $dumpvars(0, rst_n, trmt, tx_data, TX, tx_done);
  tests = 0;
  rst_n = 1;
  trmt = 0;
  tx_data = 0;
  #2; rst_n = 0;
  #1;
  if ((TX !== 1) || (tx_done !== 0)) begin
    $display("ERROR: asynchronous reset must set TX high and clear done");
    $stop();
  end
  @(negedge clk); rst_n = 1;
  repeat (3) begin
    @(posedge clk); #1;
    if ((TX !== 1) || (tx_done !== 0)) begin
      $display("ERROR: initial idle state");
      $stop();
    end
  end

  send_and_check(8'h00);
  send_and_check(8'hff);
  send_and_check(8'ha5);
  send_and_check(8'h3c);
  send_and_check(8'h81);

  // Abort an active frame with reset, then transmit again.
  @(negedge clk); tx_data = 0; trmt = 1;
  @(posedge clk); #1; trmt = 0;
  repeat (100) @(posedge clk);
  #3; rst_n = 0;
  #1;
  if ((TX !== 1) || (tx_done !== 0)) begin
    $display("ERROR: reset did not immediately abort transmission");
    $stop();
  end
  @(negedge clk); rst_n = 1;
  send_and_check(8'h7e);

  $display("Pranav Krovi (pkrovi): all %0d UART frames passed (312480 bit-clock checks)!", tests);
  $finish();
end

// Stop a broken test instead of waiting forever.
initial begin
  #10000000;
  $display("ERROR: UART test timed out");
  $stop();
end

endmodule
