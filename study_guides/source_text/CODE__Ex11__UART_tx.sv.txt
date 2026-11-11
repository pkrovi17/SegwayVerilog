module UART_tx(clk, rst_n, trmt, tx_data, TX, tx_done);

input clk, rst_n, trmt;
input [7:0] tx_data;
output TX;
output reg tx_done;

localparam IDLE = 1'b0, TRANSMIT = 1'b1;
localparam [12:0] BAUD_MAX = 13'd5207; // 5208 clocks per bit
reg state, nxt_state;
reg [8:0] tx_shft_reg;
reg [12:0] baud_cnt;
reg [3:0] bit_cnt;
reg load, transmitting, set_done;
wire shift;

assign TX = tx_shft_reg[0];
assign shift = transmitting && (baud_cnt == BAUD_MAX);

// register with current state
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;

// next state and data path logics
always_comb begin
  nxt_state = state;
  load = 0;
  transmitting = 0;
  set_done = 0;
  case (state)
    IDLE: begin
      if (trmt) begin
        load = 1;
        nxt_state = TRANSMIT;
      end
    end
    TRANSMIT: begin
      transmitting = 1;
      // 0 start, 1-8 data, 9 stop
      if (shift && (bit_cnt == 4'd9)) begin
        set_done = 1;
        nxt_state = IDLE;
      end
    end
    default: nxt_state = IDLE;
  endcase
end

// load start bit and data with ones for stop
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    tx_shft_reg <= 9'h1ff;
  else if (load)
    tx_shft_reg <= {tx_data, 1'b0};
  else if (shift)
    tx_shft_reg <= {1'b1, tx_shft_reg[8:1]};

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    baud_cnt <= 13'd0;
  else if (load || shift)
    baud_cnt <= 13'd0;
  else if (transmitting)
    baud_cnt <= baud_cnt + 13'd1;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    bit_cnt <= 4'd0;
  else if (load)
    bit_cnt <= 4'd0;
  else if (shift)
    bit_cnt <= bit_cnt + 4'd1;

// stays high until next load signal
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    tx_done <= 1'b0;
  else if (load)
    tx_done <= 1'b0;
  else if (set_done)
    tx_done <= 1'b1;

endmodule
