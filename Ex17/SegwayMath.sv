module SegwayMath(PID_cntrl, ss_tmr, steer_pot, en_steer, pwr_up,
                  lft_spd, rght_spd, too_fast);

input signed [11:0] PID_cntrl;
input [7:0] ss_tmr;
input [11:0] steer_pot;
input en_steer, pwr_up;
output signed [11:0] lft_spd, rght_spd;
output too_fast;

localparam [12:0] MIN_DUTY = 13'h0A8;
localparam [6:0] LOW_TORQUE_BAND = 7'h2A;
localparam [3:0] GAIN_MULT = 4'h4;

wire signed [19:0] PID_product;
wire signed [11:0] PID_ss;
wire [11:0] steer_pot_sat;
wire signed [11:0] steer_offset;
wire signed [13:0] steer_product;
wire signed [12:0] steer_term;
wire signed [12:0] lft_torque, rght_torque;
wire [12:0] lft_abs, rght_abs;
wire signed [12:0] lft_torque_comp, rght_torque_comp;
wire signed [12:0] lft_shaped, rght_shaped;

// soft start
assign PID_product = PID_cntrl * $signed({1'b0, ss_tmr});
assign PID_ss = PID_product[19:8];

// clip steering,center at zero, scale by 3/16, and add/subtract to left/right torques.
assign steer_pot_sat = (steer_pot < 12'h200) ? 12'h200 :
                       (steer_pot > 12'hE00) ? 12'hE00 : steer_pot;
assign steer_offset = steer_pot_sat - 12'h7ff;
assign steer_product = steer_offset * 3'sd3;
assign steer_term = {{3{steer_product[13]}}, steer_product[13:4]};

assign lft_torque = en_steer ? {PID_ss[11], PID_ss} + steer_term :
                              {PID_ss[11], PID_ss};
assign rght_torque = en_steer ? {PID_ss[11], PID_ss} - steer_term :
                               {PID_ss[11], PID_ss};

// dead band and minimum duty cycle
assign lft_abs = lft_torque[12] ? -lft_torque : lft_torque;
assign rght_abs = rght_torque[12] ? -rght_torque : rght_torque;
assign lft_torque_comp = lft_torque[12] ? lft_torque - MIN_DUTY :
                                        lft_torque + MIN_DUTY;
assign rght_torque_comp = rght_torque[12] ? rght_torque - MIN_DUTY :
                                          rght_torque + MIN_DUTY;
assign lft_shaped = !pwr_up ? 13'd0 :
                    (lft_abs < LOW_TORQUE_BAND) ? lft_torque * $signed(GAIN_MULT) :
                    lft_torque_comp;
assign rght_shaped = !pwr_up ? 13'd0 :
                     (rght_abs < LOW_TORQUE_BAND) ? rght_torque * $signed(GAIN_MULT) :
                     rght_torque_comp;

// clip to 12 bits, saturate at 2047 and -2048
assign lft_spd = (!lft_shaped[12] & lft_shaped[11]) ? 12'h7ff :
                 (lft_shaped[12] & !lft_shaped[11]) ? 12'h800 : lft_shaped[11:0];
assign rght_spd = (!rght_shaped[12] & rght_shaped[11]) ? 12'h7ff :
                  (rght_shaped[12] & !rght_shaped[11]) ? 12'h800 : rght_shaped[11:0];

// flag if either wheel is too fast
assign too_fast = (lft_spd > 12'sd1536) | (rght_spd > 12'sd1536);

endmodule
