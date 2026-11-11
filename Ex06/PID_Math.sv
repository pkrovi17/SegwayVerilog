module PID_Math(ptch, ptch_rt, integrator, PID_cntrl);

input signed [15:0] ptch, ptch_rt;
input signed [17:0] integrator;
output signed [11:0] PID_cntrl;

localparam signed [4:0] P_COEFF = 5'sh09;

wire signed [9:0] ptch_err_sat;
wire signed [14:0] P_term, I_term;
wire signed [12:0] D_term;
wire signed [15:0] PID_sum;
wire ptch_too_pos, ptch_too_neg;
wire sum_too_pos, sum_too_neg;

// saturate pitch to rnage
assign ptch_too_pos = ~ptch[15] & (|ptch[14:9]);
assign ptch_too_neg = ptch[15] & (~&ptch[14:9]);
assign ptch_err_sat = ptch_too_pos ? 10'h1ff :
                      ptch_too_neg ? 10'h200 : ptch[9:0];
assign P_term = ptch_err_sat * P_COEFF;

// drop six low bits and divide
assign I_term = {{3{integrator[17]}}, integrator[17:6]};
assign D_term = -{{3{ptch_rt[15]}}, ptch_rt[15:6]};

// sign extend and add
assign PID_sum = {P_term[14], P_term} + {I_term[14], I_term} +
                 {{3{D_term[12]}}, D_term};

// saturate sum to range
assign sum_too_pos = ~PID_sum[15] & (|PID_sum[14:11]);
assign sum_too_neg = PID_sum[15] & (~&PID_sum[14:11]);
assign PID_cntrl = sum_too_pos ? 12'h7ff :
                   sum_too_neg ? 12'h800 : PID_sum[11:0];

endmodule
