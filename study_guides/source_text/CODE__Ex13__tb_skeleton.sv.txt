// -----------------------------------------------------------------------------
// tb_skeleton.sv  --  Starter testbench for the sync FIFO exercise
// Fill in the three sections marked YOUR CODE. Do not change PROVIDED sections.
// Rename to tb_sync_fifo.sv when you start.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_sync_fifo #(
  parameter int WIDTH = 8,
  parameter int DEPTH = 16
);

  // ================================================================ PROVIDED
  // Signals, clock, DUT
  logic             clk = 1'b0;
  logic             rst_n;
  logic             wr_en, rd_en;
  logic [WIDTH-1:0] wr_data;
  logic [WIDTH-1:0] rd_data;
  logic             full, empty, overflow, underflow;
  logic [$clog2(DEPTH+1)-1:0] count;   // holds 0..DEPTH

  always #5 clk = ~clk;

  sync_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (.*);

  // Reference model state. The checker below compares the DUT against these.
  logic [WIDTH-1:0] model_q[$];     // contents, oldest at index 0. [$] is a SystemVerilog queue.
  logic [WIDTH-1:0] exp_rd_data;    // expected rd_data
  bit               exp_overflow;   // expected overflow
  bit               exp_underflow;  // expected underflow

  // ============================================================ YOUR CODE (1)
  // Reference model: update model_q and exp_* on every rising edge,
  // and clear them when rst_n goes low.
  always @(posedge clk or negedge rst_n) begin


  end

  // ================================================================ PROVIDED
  // Checker: compares every DUT output to the model on every falling edge.
  // Race-free because all DUT outputs depend only on registered state.
  int unsigned errors = 0;
  int unsigned checks = 0;
  bit          check_en = 1'b0;

  task automatic report(string name, longint got, longint exp);
    errors++;
    if (errors <= 20)
      $display("ERROR [%0t] %s mismatch: DUT=%0h expected=%0h (model size=%0d)",
               $time, name, got, exp, model_q.size());
  endtask

  always @(negedge clk) begin
    if (check_en) begin
      checks++;
      if (count     !== model_q.size())              report("count",     count,     model_q.size());
      if (full      !== (model_q.size() == DEPTH)) report("full",      full,      model_q.size() == DEPTH);
      if (empty     !== (model_q.size() == 0))     report("empty",     empty,     model_q.size() == 0);
      if (rd_data   !== exp_rd_data)               report("rd_data",   rd_data,   exp_rd_data);
      if (overflow  !== exp_overflow)              report("overflow",  overflow,  exp_overflow);
      if (underflow !== exp_underflow)             report("underflow", underflow, exp_underflow);
    end
  end

  // ================================================================ PROVIDED
  // Scenario coverage: the summary FAILS if any of these never happened.
  int unsigned hit_full, hit_overflow, hit_underflow, hit_rw_full, hit_rw_empty;

  always @(posedge clk) begin
    if (check_en && rst_n) begin
      if (full)                    hit_full++;
      if (wr_en && full && !rd_en) hit_overflow++;
      if (rd_en && empty)          hit_underflow++;
      if (wr_en && rd_en && full)  hit_rw_full++;
      if (wr_en && rd_en && empty) hit_rw_empty++;
    end
  end

  // ================================================================ PROVIDED
  // Assertion helper and one example assertion
  function automatic void sva_fail(string msg);
    errors++;
    $display("ERROR [%0t] SVA: %s", $time, msg);
  endfunction

  a_not_full_and_empty: assert property (@(posedge clk) disable iff (!rst_n)
    !(full && empty))
    else sva_fail("full and empty both high");

  // ============================================================ YOUR CODE (2)
  // Add at least one more assertion.



  // ================================================================ PROVIDED
  // Driver tasks. Each call drives inputs on the falling edge = one clock cycle.
  task automatic cycle(bit w, bit r, logic [WIDTH-1:0] d = '0);
    @(negedge clk);
    wr_en   = w;
    rd_en   = r;
    wr_data = d;
  endtask

  task automatic idle(int n = 1);                 repeat (n) cycle(0, 0); endtask
  task automatic write(logic [WIDTH-1:0] d);      cycle(1, 0, d);         endtask
  task automatic read();                          cycle(0, 1);            endtask
  task automatic write_read(logic [WIDTH-1:0] d); cycle(1, 1, d);         endtask

  // ================================================================ PROVIDED
  // Test sequence
  initial begin
    rst_n = 1'b0; wr_en = 0; rd_en = 0; wr_data = '0;
    repeat (3) @(negedge clk);
    rst_n    = 1'b1;
    check_en = 1'b1;
    idle(2);

    // ========================================================== YOUR CODE (3)
    // Directed tests (required): fill to full, write while full, read+write
    // while full, drain to empty, read while empty, read+write while empty.



    // Stretch goal: random traffic (at least 1000 cycles)


    // ============================================================== PROVIDED
    idle(3);
    check_en = 1'b0;
    $display("\n=========================== SUMMARY ===========================");
    $display(" cycles checked: %0d", checks);
    $display(" cycles at full: %0d  overflows: %0d  underflows: %0d",
             hit_full, hit_overflow, hit_underflow);
    $display(" rd+wr at full:  %0d  rd+wr at empty: %0d", hit_rw_full, hit_rw_empty);
    if (hit_full == 0 || hit_overflow == 0 || hit_underflow == 0 ||
        hit_rw_full == 0 || hit_rw_empty == 0) begin
      $display("ERROR: coverage hole -- a required scenario was never exercised");
      errors++;
    end
    if (errors == 0) $display(" RESULT: PASS");
    else             $display(" RESULT: FAIL (%0d errors)", errors);
    $display("===============================================================");
    $finish;
  end

  initial begin
    #1ms;
    $fatal(1, "Timeout");
  end

endmodule
