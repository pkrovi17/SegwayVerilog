module steer_en_SM(clk, rst_n, tmr_full, sum_gt_min, sum_lt_min,
                   diff_gt_1_4, diff_gt_15_16, clr_tmr, en_steer, rider_off);

input clk, rst_n;
input tmr_full, sum_gt_min, sum_lt_min, diff_gt_1_4, diff_gt_15_16;
output reg clr_tmr, en_steer, rider_off;

// 2 weighted bits
localparam WAIT_RIDER = 2'b00, WAIT_BALANCE = 2'b01, STEERING = 2'b10;
reg [1:0] state, nxt_state;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= WAIT_RIDER;
  else
    state <= nxt_state;

// blocking assignment to avoid latches in logic
always_comb begin
  nxt_state = state;
  clr_tmr = 0;
  en_steer = 0;
  rider_off = 0;
  case (state)
    WAIT_RIDER: begin
      rider_off = 1;
      clr_tmr = 1; // start timer when rider steps on
      if (sum_gt_min && !sum_lt_min)
        nxt_state = WAIT_BALANCE;
    end
    WAIT_BALANCE: begin
      if (sum_lt_min) begin
        rider_off = 1;
        clr_tmr = 1;
        nxt_state = WAIT_RIDER;
      end else if (diff_gt_1_4)
        clr_tmr = 1; // imbalnces causes restart
      else if (tmr_full)
        nxt_state = STEERING;
    end
    STEERING: begin
      // rider knocked off >> stepping off
      if (sum_lt_min) begin
        rider_off = 1;
        clr_tmr = 1;
        nxt_state = WAIT_RIDER;
      end else if (diff_gt_15_16) begin
        clr_tmr = 1;
        nxt_state = WAIT_BALANCE;
      end else
        en_steer = 1;
    end
    default: begin
      nxt_state = WAIT_RIDER;
      rider_off = 1;
      clr_tmr = 1;
    end
  endcase
end

endmodule
