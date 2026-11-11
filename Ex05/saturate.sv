module saturate(unsigned_err, unsigned_err_sat, signed_err, signed_err_sat,
                signed_D_diff, signed_D_diff_sat);

input [15:0] unsigned_err;
output [9:0] unsigned_err_sat;
input signed [15:0] signed_err;
output signed [9:0] signed_err_sat;
input signed [9:0] signed_D_diff;
output signed [6:0] signed_D_diff_sat;

wire err_too_pos, err_too_neg;
wire diff_too_pos, diff_too_neg;

//value greater 1023?
assign unsigned_err_sat = (|unsigned_err[15:10]) ? 10'h3ff : unsigned_err[9:0];

// singed value fits if upper bits match
assign err_too_pos = ~signed_err[15] & (|signed_err[14:9]);
assign err_too_neg = signed_err[15] & (~&signed_err[14:9]);
assign signed_err_sat = err_too_pos ? 10'h1ff :  // 511
                        err_too_neg ? 10'h200 :  // -512
                        signed_err[9:0];

assign diff_too_pos = ~signed_D_diff[9] & (|signed_D_diff[8:6]);
assign diff_too_neg = signed_D_diff[9] & (~&signed_D_diff[8:6]);
assign signed_D_diff_sat = diff_too_pos ? 7'h3f :  // 63
                           diff_too_neg ? 7'h40 :  // -64
                           signed_D_diff[6:0];

endmodule
