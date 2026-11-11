`timescale 1ns/1ps

module PWM11_test_tb();

reg clk, RST_n, inc;
wire [7:0] LED;
integer press, expected_count;

// use wrapper and 4 modules
PWM11_test iDUT(.clk(clk), .RST_n(RST_n), .inc(inc), .LED(LED));

initial clk = 0;
always #10 clk = ~clk;

initial begin
  RST_n = 1;
  inc = 1;
  #2; RST_n = 0;
  #1;
  if ((iDUT.rst_n !== 0) || (LED !== 8'h00) || (iDUT.btn_release !== 0)) begin
    $display("ERROR: asynchronous reset or button preset");
    $stop();
  end
  #2; RST_n = 1;
  @(negedge clk); #1;
  if (iDUT.rst_n !== 0) begin
    $display("ERROR: reset released before two falling edges");
    $stop();
  end
  @(negedge clk); #1;
  if (iDUT.rst_n !== 1) begin
    $display("ERROR: reset did not release after two falling edges");
    $stop();
  end
  repeat (4) @(posedge clk);
  #1;
  if ((LED[7:4] !== 4'd0) || (iDUT.btn_release !== 0)) begin
    $display("ERROR: spurious button event after reset");
    $stop();
  end


  expected_count = 0;
  for (press = 1; press <= 32; press = press + 1) begin
    @(negedge clk); #2; inc = 0;
    repeat (4) begin
      @(posedge clk); #1;
      if ((iDUT.btn_release !== 0) || (LED[7:4] !== expected_count[3:0])) begin
        $display("ERROR: button press changed counter or generated release");
        $stop();
      end
    end
    @(negedge clk); #2; inc = 1;
    @(posedge clk); #1;
    if (iDUT.btn_release !== 0) begin
      $display("ERROR: release pulse before two synchronization stages");
      $stop();
    end
    @(posedge clk); #1;
    if ((iDUT.btn_release !== 1) || (LED[7:4] !== expected_count[3:0])) begin
      $display("ERROR: missing release pulse or early count");
      $stop();
    end
    if (press <= 15)
      expected_count = press;
    else if (press <= 30)
      expected_count = 30 - press;
    else
      expected_count = press - 30;
    // counter takes release pulse on next pos edge
    repeat (4) begin
      @(posedge clk); #1;
      if ((iDUT.btn_release !== 0) || (LED[7:4] !== expected_count[3:0])) begin
        $display("ERROR: release %0d: count=%0d, expected %0d",
                 press, LED[7:4], expected_count);
        $stop();
      end
    end
  end

  #2; RST_n = 0;
  #1;
  if ((iDUT.rst_n !== 0) || (LED !== 8'h00) || (iDUT.dwn !== 0)) begin
    $display("ERROR: reset did not clear the running wrapper");
    $stop();
  end
  $display("All reset, button, and up/down counter tests passed (32 releases)!");
  $finish();
end

endmodule
