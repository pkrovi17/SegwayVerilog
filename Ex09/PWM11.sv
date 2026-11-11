module PWM11(clk, rst_n, duty, PWM1, PWM2, PWM_synch, ovr_I_blank);

input clk, rst_n;
input [10:0] duty;
output reg PWM1, PWM2;
output PWM_synch, ovr_I_blank;

localparam [10:0] NONOVERLAP = 11'h040;
reg [10:0] cnt;
wire [11:0] pwm2_start;

// keep carry: no wrap at 2048
assign pwm2_start = {1'b0, duty} + {1'b0, NONOVERLAP};

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    cnt <= 11'd0;
  else
    cnt <= cnt + 11'd1;

// reset takes priority
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    PWM1 <= 1'b0;
  else if (cnt >= duty)
    PWM1 <= 1'b0;
  else if (cnt >= NONOVERLAP)
    PWM1 <= 1'b1;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    PWM2 <= 1'b0;
  else if (&cnt)
    PWM2 <= 1'b0;
  else if ({1'b0, cnt} >= pwm2_start)
    PWM2 <= 1'b1;

assign PWM_synch = ~|cnt;

// strict range compare
assign ovr_I_blank = ((cnt > NONOVERLAP) &&
                      ({1'b0, cnt} < ({1'b0, NONOVERLAP} + 12'd128))) ||
                      (({1'b0, cnt} > pwm2_start) &&
                      ({1'b0, cnt} < (pwm2_start + 12'd128)));

endmodule
