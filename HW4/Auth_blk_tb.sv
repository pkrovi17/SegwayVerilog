`timescale 1ns/1ps

module Auth_blk_tb();

reg clk, rst_n, rider_off, trmt;
reg [7:0] tx_data;
wire RX, tx_done, pwr_up;
integer tests, bytes_sent;
reg [1:0] previous_state;
reg [8:0] visited_arcs;

UART_tx iTX(.clk(clk), .rst_n(rst_n), .trmt(trmt), .tx_data(tx_data),
             .TX(RX), .tx_done(tx_done));
Auth_blk iDUT(.clk(clk), .rst_n(rst_n), .RX(RX), .rider_off(rider_off), .pwr_up(pwr_up));

initial clk = 0;
always #10 clk = ~clk; // 50 MHz

// record transistions, include self loops after the seqential logic settles
always @(negedge clk) begin
  if (!rst_n)
    previous_state = 0;
  else if (iDUT.state <= 2) begin
    visited_arcs[previous_state * 3 + iDUT.state] = 1;
    previous_state = iDUT.state;
  end
end

task check_state;
  input [1:0] expected_state;
  begin
    #1;
    if ((iDUT.state !== expected_state) || (pwr_up !== (expected_state != 0))) begin
      $display("ERROR: check=%0d state=%b expected=%b pwr_up=%b",
               tests, iDUT.state, expected_state, pwr_up);
      $stop();
      $finish();
    end
    tests = tests + 1;
  end
endtask

task send_byte;
  input [7:0] data;
  input [1:0] expected_state;
  begin
    @(negedge clk); #1; tx_data = data; trmt = 1;
    @(negedge clk); #1; trmt = 0;
    @(posedge tx_done);
    @(negedge clk);
    check_state(expected_state);
    if (iDUT.rx_rdy !== 0) begin
      $display("ERROR: authentication FSM did not acknowledge the UART byte");
      $stop();
      $finish();
    end
    bytes_sent = bytes_sent + 1;
    $display("PASS: UART byte=0x%h state=%0d pwr_up=%b", data, expected_state, pwr_up);
  end
endtask

initial begin
  tests = 0; bytes_sent = 0; visited_arcs = 0; previous_state = 0;
  rst_n = 1; rider_off = 1; trmt = 0; tx_data = 0;
  #2; rst_n = 0;
  check_state(0);
  @(negedge clk); #1; rst_n = 1;
  repeat (4) @(negedge clk);
  check_state(0);

  send_byte(8'h00, 0); // invalid command while off
  send_byte(8'h53, 0); // s while already off
  send_byte(8'h47, 1); // g powers on immmediatly before rider
  send_byte(8'h47, 1); // repeat g holds power
  send_byte(8'h55, 1); // ingnore unrecognized bytes while powered
  @(negedge clk); #1; rider_off = 0;
  repeat (3) @(negedge clk);
  check_state(1);
  @(negedge clk); #1; rider_off = 1;
  repeat (3) @(negedge clk);
  check_state(1); // stepping off does not cancel auth
  send_byte(8'h53, 0); // s power off right after rider steps off

  @(negedge clk); #1; rider_off = 0;
  send_byte(8'h47, 1);
  send_byte(8'h53, 2); // s must preserves power with a rider
  send_byte(8'h55, 2); // invalid bytes do not change pending commands
  send_byte(8'h53, 2); // repeat s keep pending stop
  send_byte(8'h47, 1); // g cancels pending shutdown
  @(negedge clk); #1; rider_off = 1;
  repeat (3) @(negedge clk);
  check_state(1); // cancelled s must not turn power off later

  @(negedge clk); #1; rider_off = 0;
  send_byte(8'h53, 2);
  @(negedge clk); #1; rider_off = 1;
  repeat (3) @(negedge clk);
  check_state(0); // remember s until rider steps off

  // reset from each state, show UART reception recovers
  @(negedge clk); #1; rider_off = 0;
  send_byte(8'h47, 1);
  #2; rst_n = 0;
  check_state(0);
  repeat (2) @(negedge clk);
  #1; rst_n = 1;
  send_byte(8'h47, 1);
  send_byte(8'h53, 2);
  #2; rst_n = 0;
  check_state(0);
  repeat (2) @(negedge clk);
  #1; rst_n = 1;
  send_byte(8'h47, 1);
  @(negedge clk); #1; rider_off = 1;
  send_byte(8'h53, 0);
  @(negedge clk); #1;

  // all possible state arcs except off to wait_rider_off must be exercised
  if (visited_arcs !== 9'b111111011) begin
    $display("ERROR: missing FSM arc, visited=%b expected=111111011", visited_arcs);
    $stop();
    $finish();
  end
  $display("all %0d authentication checks passed (%0d UART bytes, all 8 FSM arcs)!",
           tests, bytes_sent);
  $finish();
end

initial begin
  #30000000;
  $display("ERROR: authentication test timed out");
  $stop();
end

endmodule
