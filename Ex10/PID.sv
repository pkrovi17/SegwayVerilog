module PID(clk, rst_n, vld, ptch, ptch_rt, pwr_up, rider_off, PID_cntrl, ss_tmr);

input clk, rst_n, vld, pwr_up, rider_off;
input signed [15:0] ptch, ptch_rt;
output signed [11:0] PID_cntrl;
output [7:0] ss_tmr;

localparam signed [4:0] P_COEFF = 5'sh09;

wire signed [9:0] ptch_err_sat;
wire signed [14:0] P_term, I_term;
wire signed [12:0] D_term;
wire signed [15:0] PID_sum;
wire ptch_too_pos, ptch_too_neg;
wire sum_too_pos, sum_too_neg;
reg signed [17:0] integrator;
wire signed [17:0] integrator_sum;
wire integrator_ov;
reg [26:0] long_tmr;

// saturate pitch to 10 bits
assign ptch_too_pos = ~ptch[15] & (|ptch[14:9]);
assign ptch_too_neg = ptch[15] & (~&ptch[14:9]);
assign ptch_err_sat = ptch_too_pos ? 10'h1ff :
                      ptch_too_neg ? 10'h200 : ptch[9:0];
assign P_term = ptch_err_sat * P_COEFF;

// add valid pitch eror to integrator
assign integrator_sum = integrator + {{8{ptch_err_sat[9]}}, ptch_err_sat};
assign integrator_ov = (integrator[17] == ptch_err_sat[9]) &&
                       (integrator_sum[17] != integrator[17]);

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    integrator <= 18'd0;
  else if (rider_off)
    integrator <= 18'd0;
  else if (vld && !integrator_ov)
    integrator <= integrator_sum;

// soft start timer
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    long_tmr <= 27'd0;
  else if (!pwr_up)
    long_tmr <= 27'd0;
  else if (!(&long_tmr[26:19]))
    long_tmr <= long_tmr + 27'd1;

assign ss_tmr = long_tmr[26:19];

// drop 6 low bits
assign D_term = -{{3{ptch_rt[15]}}, ptch_rt[15:6]};
assign PID_sum = {P_term[14], P_term} + {I_term[14], I_term} +
                 {{3{D_term[12]}}, D_term};

// saturate sum to range
assign sum_too_pos = ~PID_sum[15] & (|PID_sum[14:11]);
assign sum_too_neg = PID_sum[15] & (~&PID_sum[14:11]);
assign PID_cntrl = sum_too_pos ? 12'h7ff :
                   sum_too_neg ? 12'h800 : PID_sum[11:0];

endmodule
