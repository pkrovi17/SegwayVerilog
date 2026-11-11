`timescale 1ns/1ps

module mult_accum_tb();

reg clk, clr, en;
reg [15:0] A, B;
wire [63:0] accum_original, accum_gated;
reg [31:0] expected_product;
reg [63:0] expected_accum;
reg previous_en;
integer i, tests;

mult_accum iOriginal(.clk(clk), .clr(clr), .en(en), .A(A), .B(B), .accum(accum_original));
mult_accum_gated iGated(.clk(clk), .clr(clr), .en(en), .A(A), .B(B), .accum(accum_gated));

initial clk = 0;
always #5 clk = ~clk;

// Check the pipeline against an arithmetic reference after register updates.
always @(posedge clk) begin
  if (clr)
    expected_accum = 0;
  else if (previous_en)
    expected_accum = expected_accum + expected_product;
  if (en)
    expected_product = A * B;
  previous_en = en;
  #1;
  if ((accum_original !== expected_accum) || (accum_gated !== expected_accum)) begin
    $display("ERROR: check %0d original=%h gated=%h expected=%h",
             tests, accum_original, accum_gated, expected_accum);
    $stop();
    $finish();
  end
  tests = tests + 1;
end

// A gated clock must never rise while the source clock is low.
always @(posedge iGated.prod_clk or posedge iGated.accum_clk)
  if (clk !== 1'b1) begin
    $display("ERROR: gated clock rose while source clock was low");
    $stop();
    $finish();
  end

initial begin
  tests = 0;
  previous_en = 0;
  expected_product = 0;
  expected_accum = 0;
  clr = 1; en = 0; A = 0; B = 0;
  @(negedge clk); #1;
  clr = 0; en = 1; A = 16'hffff; B = 16'hffff;
  repeat (4) @(negedge clk);
  #1; en = 0;
  repeat (3) @(negedge clk); // Drain the last enabled product, then hold.
  #1; clr = 1; // Clear must work with both enables otherwise inactive.
  @(negedge clk); #1; clr = 0;

  for (i = 0; i < 40; i = i + 1) begin
    @(negedge clk); #1;
    en = (i % 3 != 0);
    clr = (i % 11 == 0);
    A = 16'hff00 + i;
    B = i * 97;
  end

  // Change both controls during the high phase: no new gated edge is allowed.
  @(negedge clk); #1; clr = 0; en = 0;
  repeat (2) @(negedge clk);
  @(posedge clk); #2;
  en = 1; clr = 1;
  #1;
  if ((iGated.prod_clk !== 0) || (iGated.accum_clk !== 0)) begin
    $display("ERROR: high-phase enable change caused a clock pulse");
    $stop();
    $finish();
  end
  @(negedge clk);
  @(posedge clk); #2;
  en = 0; clr = 0;
  #1;
  if ((iGated.prod_clk !== 1) || (iGated.accum_clk !== 1)) begin
    $display("ERROR: high-phase disable truncated a clock pulse");
    $stop();
    $finish();
  end
  repeat (3) @(negedge clk);
  $display("Pranav Krovi (pkrovi): all %0d multiply-accumulate checks passed!", tests);
  $finish();
end

endmodule
