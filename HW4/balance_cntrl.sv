module balance_cntrl(clk, rst_n, vld, ptch, ptch_rt, pwr_up, rider_off,
                     steer_pot, en_steer, lft_spd, rght_spd, too_fast);

parameter fast_sim = 1;

input clk, rst_n, vld, pwr_up, rider_off, en_steer;
input signed [15:0] ptch, ptch_rt;
input [11:0] steer_pot;
output signed [11:0] lft_spd, rght_spd;
output too_fast;

wire signed [11:0] PID_cntrl;
wire [7:0] ss_tmr;

// PID gies balance correctness and soft start timing
PID #(.fast_sim(fast_sim)) iPID(
  .clk(clk), .rst_n(rst_n), .vld(vld), .ptch(ptch), .ptch_rt(ptch_rt),
  .pwr_up(pwr_up), .rider_off(rider_off), .PID_cntrl(PID_cntrl), .ss_tmr(ss_tmr));

// segway math takes pid input and generates left and right motor speed
SegwayMath iMath(
  .PID_cntrl(PID_cntrl), .ss_tmr(ss_tmr), .steer_pot(steer_pot),
  .en_steer(en_steer), .pwr_up(pwr_up), .lft_spd(lft_spd),
  .rght_spd(rght_spd), .too_fast(too_fast));

endmodule
