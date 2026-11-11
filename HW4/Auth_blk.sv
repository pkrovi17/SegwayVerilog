module Auth_blk(clk, rst_n, RX, rider_off, pwr_up);

input clk, rst_n, RX, rider_off;
output pwr_up;

localparam OFF = 2'b00, POWERED = 2'b01, WAIT_RIDER_OFF = 2'b10;
reg [1:0] state, nxt_state;
wire [7:0] rx_data;
wire rx_rdy, clr_rx_rdy;
wire go_cmd, stop_cmd;

UART_rx iRX(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_rdy(clr_rx_rdy),
             .rx_data(rx_data), .rdy(rx_rdy));

// acknowledge byte so that each command is processed only once
assign clr_rx_rdy = rx_rdy;
assign go_cmd = rx_rdy && (rx_data == 8'h47);   // 'G'
assign stop_cmd = rx_rdy && (rx_data == 8'h53); // 'S'
assign pwr_up = (state == POWERED) || (state == WAIT_RIDER_OFF);

//state flip-flop with asynch reset
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= OFF;
  else
    state <= nxt_state;

// only recognized commands can change auth state, other bytes are ignore
always_comb begin
  nxt_state = state;
  case (state)
    OFF: begin
      if (go_cmd)
        nxt_state = POWERED;
    end
    POWERED: begin
      if (stop_cmd) begin
        if (rider_off)
          nxt_state = OFF;
        else
          nxt_state = WAIT_RIDER_OFF;
      end
    end
    WAIT_RIDER_OFF: begin
      // a new auth cancels a previous stop request
      if (go_cmd)
        nxt_state = POWERED;
      else if (rider_off)
        nxt_state = OFF;
    end
    default: nxt_state = OFF;
  endcase
end

endmodule
