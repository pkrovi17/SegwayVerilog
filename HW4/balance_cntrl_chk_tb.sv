`timescale 1ns/1ps

module balance_cntrl_chk_tb();

reg clk, rst_n, vld, pwr_up, rider_off, en_steer;
reg signed [15:0] ptch, ptch_rt;
reg [11:0] steer_pot;
wire signed [11:0] lft_spd, rght_spd;
wire too_fast;

reg [48:0] stim [0:1499];
reg [24:0] resp [0:1499];
integer i;

balance_cntrl #(.fast_sim(1)) iDUT(
  .clk(clk), .rst_n(rst_n), .vld(vld), .ptch(ptch), .ptch_rt(ptch_rt),
  .pwr_up(pwr_up), .rider_off(rider_off), .steer_pot(steer_pot),
  .en_steer(en_steer), .lft_spd(lft_spd), .rght_spd(rght_spd), .too_fast(too_fast));

initial clk = 0;
always #5 clk = ~clk;

initial begin
  $readmemh("balance_cntrl_stim.hex", stim);
  $readmemh("balance_cntrl_resp.hex", resp);
  // test balance at full soft start gain
  force iDUT.ss_tmr = 8'hff;

  for (i = 0; i < 1500; i = i + 1) begin
    // error checking for unkowns
    if ((^stim[i] === 1'bx) || (^resp[i] === 1'bx)) begin
      $display("ERROR: missing or unknown stimulus/response at vector %0d", i);
      $stop();
      $finish();
    end
    {rst_n, vld, ptch, ptch_rt, pwr_up, rider_off, steer_pot, en_steer} = stim[i];
    @(posedge clk);
    #1; // check after settle
    if ({lft_spd, rght_spd, too_fast} !== resp[i]) begin
      $display("ERROR: vector %0d stimulus=%h", i, stim[i]);
      $display("got response=%h, expected=%h", {lft_spd, rght_spd, too_fast}, resp[i]);
      $display("left=%0d right=%0d too_fast=%b", lft_spd, rght_spd, too_fast);
      $stop();
      $finish();
    end
  end

  $display("Pranav Krovi (pkrovi): all 1500 balance control vectors passed!");
  $finish();
end

endmodule
