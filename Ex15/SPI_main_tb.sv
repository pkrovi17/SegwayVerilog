`timescale 1ns/1ps

module SPI_main_tb();

reg clk, rst_n, wrt;
reg [15:0] wt_data;
wire done, SS_n, SCLK, MOSI, MISO, INT;
wire [15:0] rd_data;
integer tests, row;
reg [95:0] expected_data [0:63];

SPI_main iDUT(.clk(clk), .rst_n(rst_n), .wrt(wrt), .wt_data(wt_data),
  .done(done), .rd_data(rd_data), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));
SPI_iNEMO1 iNEMO(.SS_n(SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI), .INT(INT));

initial clk = 0;
always #10 clk = ~clk; // 50 MHz

task transaction;
  input [15:0] command;
  input [7:0] expected_byte;
  integer cycle, falls, rises, bit_index;
  reg previous_sclk;
  reg [15:0] received;
  begin
    @(negedge clk); wt_data = command; wrt = 1;
    @(posedge clk); #1;
    wrt = 0;
    wt_data = ~command; // Check for accepted command
    if ((SS_n !== 0) || (SCLK !== 1) || (done !== 0)) begin
      $display("ERROR: transaction did not start correctly");
      $stop();
    end
    falls = 0;
    rises = 0;
    received = 0;
    previous_sclk = 1;
    // 5 clocks of front porch 16 bits final shift
    for (cycle = 1; cycle <= 261; cycle = cycle + 1) begin
      @(posedge clk); #1;
      if (cycle < 261) begin
        if ((SS_n !== 0) || (done !== 0) ||
            (SCLK !== (((11 + cycle) % 16) >= 8))) begin
          $display("ERROR: SPI timing at clock %0d", cycle);
          $stop();
        end
        if (cycle < 5)
          bit_index = 0;
        else
          bit_index = (cycle - 5) / 16;
        if (MOSI !== command[15-bit_index]) begin
          $display("ERROR: command=%h bit=%0d MOSI=%b", command, bit_index, MOSI);
          $stop();
        end
      end else if ((SS_n !== 1) || (SCLK !== 1) || (done !== 1)) begin
        $display("ERROR: completion or back porch timing");
        $stop();
      end
      if (previous_sclk && !SCLK)
        falls = falls + 1;
      if (!previous_sclk && SCLK) begin
        rises = rises + 1;
        received = {received[14:0], MISO};
      end
      previous_sclk = SCLK;
      // busy request cannot replace transaction
      if (cycle == 30) wrt = 1;
      if (cycle == 31) wrt = 0;
    end
    if ((falls != 16) || (rises != 16) ||
        (rd_data !== received) || (rd_data[7:0] !== expected_byte)) begin
      $display("ERROR: command=%h received=%h serial=%h expected low=%h edges=%0d/%0d",
               command, rd_data, received, expected_byte, falls, rises);
      $stop();
    end
    repeat (3) begin
      @(posedge clk); #1;
      if ((done !== 1) || (SS_n !== 1) || (SCLK !== 1) || (rd_data !== received)) begin
        $display("ERROR: completion, idle clock, or received data did not hold");
        $stop();
      end
    end
    tests = tests + 1;
    $display("PASS: command=%h received=%h, 16 SPI clocks, correct timing", command, rd_data);
  end
endtask

initial begin
  $dumpfile("SPI_main.vcd");
  $dumpvars(0, rst_n, wrt, wt_data, done, rd_data, SS_n, SCLK, MOSI, MISO, INT);
  $readmemh("inert_data.hex", expected_data);
  tests = 0;
  rst_n = 1; wrt = 0; wt_data = 0;
  #2; rst_n = 0;
  #1;
  if ((SS_n !== 1) || (SCLK !== 1) || (done !== 0)) begin
    $display("ERROR: reset outputs");
    $stop();
  end
  // a complete power on reset
  repeat (10) @(negedge clk);
  rst_n = 1;

  transaction(16'h8f00, 8'h6a); // WHO_AM_I
  transaction(16'h0d02, 8'ha5); // INT register
  if (iNEMO.NEMO_setup !== 1) begin
    $display("ERROR: INT register was not configured");
    $stop();
  end
  transaction(16'h8d00, 8'h02); // Rread config register

  // Rread data from hex file 
  for (row = 0; row < 2; row = row + 1) begin
    @(posedge INT); #1;
    // On row 1, read pitch first to verify ptchL clears an asserted INT.
    // On row 0, yaw is first, independently checking yawL acknowledgement.
    if (row == 1) begin
      transaction(16'ha300, expected_data[row][47:40]);
      transaction(16'ha200, expected_data[row][39:32]);
      if (INT !== 0) begin
        $display("ERROR: reading ptchL did not clear INT");
        $stop();
      end
    end
    transaction(16'ha700, expected_data[row][15:8]);
    transaction(16'ha600, expected_data[row][7:0]);
    if (INT !== 0) begin
      $display("ERROR: reading yawL did not clear INT");
      $stop();
    end
    transaction(16'ha800, expected_data[row][87:80]);
    transaction(16'ha900, expected_data[row][95:88]);
    if (row == 0) begin
      transaction(16'ha300, expected_data[row][47:40]);
      transaction(16'ha200, expected_data[row][39:32]);
    end
    if (INT !== 0) begin
      $display("ERROR: reading ptchL did not leave INT clear");
      $stop();
    end
  end

  // reset through transaction 
  // sensor has separate reset
  @(negedge clk); wt_data = 16'h8f00; wrt = 1;
  @(negedge clk); wrt = 0;
  repeat (30) @(posedge clk);
  #3; rst_n = 0;
  #1;
  if ((SS_n !== 1) || (SCLK !== 1) || (done !== 0)) begin
    $display("ERROR: asynchronous reset during transaction");
    $stop();
  end
  $display("All %0d SPI sensor transactions passed!", tests);
  $finish();
end

initial begin
  #2000000;
  $display("ERROR: SPI test timed out waiting for completion or INT");
  $stop();
end

endmodule
