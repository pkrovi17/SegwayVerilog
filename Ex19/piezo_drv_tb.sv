`timescale 1ns/1ps

module piezo_drv_tb();
reg clk, rst_n, en_steer, too_fast, batt_low;
wire piezo, piezo_n;
integer tests;
time tune_start, first_edge, measured_period;

piezo_drv #(.fast_sim(1)) iDUT(.clk(clk), .rst_n(rst_n), .en_steer(en_steer),
  .too_fast(too_fast), .batt_low(batt_low), .piezo(piezo), .piezo_n(piezo_n));

initial clk = 0;
always #10 clk = ~clk;

// accelerated note including its period and duration
task check_note;
  input [2:0] expected_note;
  input integer clocks;
  input integer half_period;
  begin
    if ((iDUT.state !== 1) || (iDUT.tune_note !== expected_note)) begin
      $display("ERROR: expected note %0d, got %0d in state %0d",
               expected_note, iDUT.tune_note, iDUT.state);
      $stop(); $finish();
    end
    fork
      begin
        @(posedge piezo); first_edge = $time;
        @(posedge piezo); measured_period = $time - first_edge;
        // residual accumulator gives floor/ceil clock quantization
        if ((measured_period < (2 * half_period / 64) * 20) ||
            (measured_period > ((2 * half_period + 63) / 64) * 20)) begin
          $display("ERROR: note %0d period=%0t", expected_note, measured_period);
          $stop(); $finish();
        end
      end
      begin
        repeat (clocks - 1) @(posedge clk);
        #1;
        if (iDUT.tune_note !== expected_note) begin
          $display("ERROR: note %0d ended too soon", expected_note);
          $stop(); $finish();
        end
        @(posedge clk); #1;
      end
    join
    tests = tests + 1;
    $display("PASS: note %0d, %0d fast clocks, correct frequency", expected_note, clocks);
  end
endtask

// check differential drive at a quiet point
always @(negedge clk) begin
  if (rst_n) begin
    if ((iDUT.state == 1) && (en_steer || too_fast || batt_low)) begin
      if (piezo_n !== ~piezo) begin
        $display("ERROR: active outputs are not complementary");
        $stop(); $finish();
      end
    end else if ({piezo, piezo_n} !== 2'b00) begin
      $display("ERROR: piezo must be silent when inactive or waiting");
      $stop(); $finish();
    end
  end
end

initial begin
  tests = 0;
  rst_n = 1; en_steer = 0; too_fast = 0; batt_low = 0;
  #2; rst_n = 0;
  #1;
  if ({piezo, piezo_n} !== 2'b00) begin
    $display("ERROR: reset is not silent"); $stop(); $finish();
  end
  @(negedge clk); #1; rst_n = 1;
  repeat (10) @(negedge clk);
  #1; en_steer = 1;
  @(posedge clk); #1; tune_start = $time;
  check_note(0, 131072, 15944);
  check_note(1, 131072, 11945);
  check_note(2, 131072, 9480);
  check_note(3, 196608, 7972);
  check_note(4, 65536, 9480);
  batt_low = 1; // finish the forward tune before selecting battery warning
  check_note(5, 262144, 7972);
  if (iDUT.state !== 2) begin
    $display("ERROR: normal tune did not enter its silent repeat wait");
    $stop(); $finish();
  end
  wait (iDUT.state == 1); #1;
  if ($time - tune_start != 46875000) begin
    $display("ERROR: repeat interval=%0t, expected 3 seconds / 64", $time - tune_start);
    $stop(); $finish();
  end
  // battery wins over steering
  check_note(5, 262144, 7972);
  check_note(4, 65536, 9480);
  check_note(3, 196608, 7972);
  check_note(2, 131072, 9480);
  check_note(1, 131072, 11945);
  check_note(0, 131072, 15944);

  // no input: stop and become silent
  en_steer = 0; batt_low = 0;
  @(posedge clk); #1;
  batt_low = 1;
  @(posedge clk); #1;
  if ((iDUT.reverse_tune !== 1) || (iDUT.tune_note !== 5)) begin
    $display("ERROR: battery alone did not start reverse tune");
    $stop(); $finish();
  end
  too_fast = 1;
  @(posedge clk); #1;
  if ((iDUT.alarm_mode !== 1) || (iDUT.reverse_tune !== 0)) begin
    $display("ERROR: overspeed did not preempt the battery warning");
    $stop(); $finish();
  end
  check_note(0, 131072, 15944);
  check_note(1, 131072, 11945);
  check_note(2, 131072, 9480);
  // there must be no 3-second gap
  check_note(0, 131072, 15944);
  check_note(1, 131072, 11945);
  too_fast = 0;
  check_note(2, 131072, 9480);
  if ((iDUT.state !== 1) || (iDUT.tune_note !== 5)) begin
    $display("ERROR: battery warning did not resume after overspeed");
    $stop(); $finish();
  end
  batt_low = 0;
  #1;
  if ({piezo, piezo_n} !== 2'b00) begin
    $display("ERROR: deasserting all inputs did not silence the driver");
    $stop(); $finish();
  end
  repeat (10) @(negedge clk);
  $display("Pranav Krovi (pkrovi): all %0d piezo note checks and mode/priority checks passed!", tests);
  $finish();
end

initial begin
  #120000000;
  $display("ERROR: piezo test timed out");
  $stop();
end

endmodule
