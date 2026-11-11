`timescale 1ns/1ps

module A2D_tb();
reg clk, rst_n, nxt;
wire SS_n, SCLK, MOSI, MISO;
wire [11:0] lft_ld, rght_ld, steer_pot, batt;
reg [11:0] expected_lft, expected_rght, expected_steer, expected_batt;
reg [15:0] serial_command;
reg [2:0] expected_channel;
integer reading, tests, frames, edges, first_frame;
time first_end;

A2D_intf iDUT(.clk(clk), .rst_n(rst_n), .nxt(nxt), .lft_ld(lft_ld),
  .rght_ld(rght_ld), .steer_pot(steer_pot), .batt(batt),
  .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));
ADC128S iADC(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));

initial clk = 0;
always #10 clk = ~clk;

always @(negedge SS_n) begin
  serial_command = 0;
  edges = 0;
  frames = frames + 1;
end
always @(posedge SCLK)
  if (!SS_n) begin
    serial_command = {serial_command[14:0], MOSI};
    edges = edges + 1;
  end
always @(posedge SS_n)
  if (rst_n && edges != 0) begin
    if ((edges != 16) || (serial_command !== {2'b00, expected_channel, 11'h000})) begin
      $display("ERROR: edges=%0d command=%h expected channel=%0d", edges, serial_command, expected_channel);
      $stop(); $finish();
    end
  end

task check_values;
  begin
    if ({lft_ld,rght_ld,steer_pot,batt} !==
        {expected_lft,expected_rght,expected_steer,expected_batt}) begin
      $display("ERROR: reading=%0d got=%h %h %h %h, expected=%h %h %h %h",
        reading,lft_ld,rght_ld,steer_pot,batt,
        expected_lft,expected_rght,expected_steer,expected_batt);
      $stop(); $finish();
    end
  end
endtask

task convert_next;
  reg [11:0] expected_value;
  begin
    case (reading % 4)
      0: expected_channel = 0;
      1: expected_channel = 4;
      2: expected_channel = 5;
      3: expected_channel = 6;
    endcase
    expected_value = 12'hc00 - reading * 16 + expected_channel;
    first_frame = frames;
    @(negedge clk); #1; nxt = 1;
    @(negedge clk); #1; nxt = 0;
    // extra request while busy should no advance
    repeat (10) @(negedge clk);
    #1; nxt = 1;
    @(negedge clk); #1; nxt = 0;

    @(posedge SS_n); #1;
    first_end = $time;
    check_values; // discard 1st SPI response preserve outputs
    @(negedge SS_n); #1;
    if ($time - first_end != 40) begin
      $display("ERROR: unexpected inter-transaction timing: %0t", $time-first_end);
      $stop(); $finish();
    end
    @(posedge SS_n); #1;
    check_values;
    case (reading % 4)
      0: expected_lft = expected_value;
      1: expected_rght = expected_value;
      2: expected_steer = expected_value;
      3: expected_batt = expected_value;
    endcase
    repeat (3) @(negedge clk);
    #1; check_values;
    if ((frames != first_frame + 2) || (iDUT.state !== 0)) begin
      $display("ERROR: expected exactly two transactions and return to idle");
      $stop(); $finish();
    end
    repeat (8) @(negedge clk);
    #1; check_values;
    if ((SS_n !== 1) || (frames != first_frame + 2)) begin
      $display("ERROR: unexpected conversion without a new request");
      $stop(); $finish();
    end
    tests = tests + 1;
    $display("PASS: conversion %0d channel=%0d value=%h, two transactions", reading, expected_channel, expected_value);
  end
endtask

initial begin
  tests = 0; frames = 0; edges = 0; nxt = 0; reading = 0;
  expected_channel = 0;
  expected_lft = 0; expected_rght = 0; expected_steer = 0; expected_batt = 0;
  rst_n = 1;
  #2; rst_n = 0;
  #1; check_values;
  repeat (3) @(negedge clk);
  #1; rst_n = 1;
  repeat (8) @(negedge clk);
  #1; check_values;
  if (frames != 0) begin
    $display("ERROR: SPI ran without a request"); $stop(); $finish();
  end
  for (reading = 0; reading < 12; reading = reading + 1)
    convert_next;

  // reset interface and ADC while transaction active
  expected_channel = 0;
  @(negedge clk); #1; nxt = 1;
  @(negedge clk); #1; nxt = 0;
  repeat (20) @(negedge clk);
  #1; rst_n = 0;
  expected_lft = 0; expected_rght = 0; expected_steer = 0; expected_batt = 0;
  #1; check_values;
  if ((SS_n !== 1) || (SCLK !== 1)) begin
    $display("ERROR: reset did not stop the SPI interface"); $stop(); $finish();
  end
  repeat (3) @(negedge clk);
  #1; rst_n = 1;
  reading = 0;
  convert_next;
  $display("Pranav Krovi (pkrovi): all %0d A2D conversion tests passed!", tests);
  $finish();
end

initial begin
  #500000;
  $display("ERROR: A2D test timed out");
  $stop();
end

endmodule
