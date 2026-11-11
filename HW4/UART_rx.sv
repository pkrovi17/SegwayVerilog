module UART_rx(clk, rst_n, RX, clr_rdy, rx_data, rdy);

input clk, rst_n, RX, clr_rdy;
output [7:0] rx_data;
output reg rdy;

localparam IDLE = 1'b0, RECEIVE = 1'b1;
reg state, nxt_state;
reg RX_meta, RX_sync, RX_prev;
reg [8:0] rx_shft_reg;
reg [12:0] baud_cnt;
reg [3:0] bit_cnt;
reg start, receiving, set_rdy;
wire shift;

// 2 flops to syncronize, 3rd flop to store previous value
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) begin
    RX_meta <= 1'b1;
    RX_sync <= 1'b1;
    RX_prev <= 1'b1;
  end else begin
    RX_meta <= RX;
    RX_sync <= RX_meta;
    RX_prev <= RX_sync;
  end

assign shift = receiving && (baud_cnt == 13'd0);
assign rx_data = rx_shft_reg[7:0];

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;

// default values prevent latches
always_comb begin
  nxt_state = state;
  start = 0;
  receiving = 0;
  set_rdy = 0;
  case (state)
    IDLE: begin
      if (RX_prev && !RX_sync) begin
        start = 1;
        nxt_state = RECEIVE;
      end
    end
    RECEIVE: begin
      receiving = 1;
      if (shift && (bit_cnt == 4'd9)) begin
        set_rdy = 1;
        nxt_state = IDLE;
      end
    end
    default: nxt_state = IDLE;
  endcase
end

// wait full bit for samples, only half for starting
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    baud_cnt <= 13'd0;
  else if (start)
    baud_cnt <= 13'd2603;
  else if (shift)
    baud_cnt <= 13'd5207;
  else if (receiving)
    baud_cnt <= baud_cnt - 13'd1;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    bit_cnt <= 4'd0;
  else if (start)
    bit_cnt <= 4'd0;
  else if (shift)
    bit_cnt <= bit_cnt + 4'd1;

// 10 shifts, stop at 8, data is in bits 7:0
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    rx_shft_reg <= 9'd0;
  else if (shift)
    rx_shft_reg <= {RX_sync, rx_shft_reg[8:1]};

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    rdy <= 1'b0;
  else if (start || clr_rdy)
    rdy <= 1'b0;
  else if (set_rdy)
    rdy <= 1'b1;

endmodule
