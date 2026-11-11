module SPI_main(clk, rst_n, wrt, wt_data, done, rd_data, SS_n, SCLK, MOSI, MISO);

input clk, rst_n, wrt, MISO;
input [15:0] wt_data;
output reg done, SS_n;
output [15:0] rd_data;
output SCLK, MOSI;
//inits
localparam IDLE = 2'b00, FRONT = 2'b01, TRANSFER = 2'b10;
reg [1:0] state, nxt_state;
reg [3:0] SCLK_div, bit_cnt;
reg [15:0] shft_reg;
reg MISO_smpl;
reg init, shft, ld_SCLK, set_done;
wire smpl, shft_imm;

assign SCLK = SCLK_div[3];
assign MOSI = shft_reg[15];
assign rd_data = shft_reg;
assign smpl = (state == TRANSFER) && (SCLK_div == 4'h7);
assign shft_imm = (SCLK_div == 4'hf);
//ff
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;












































always_comb begin
  nxt_state = state;
  init = 0;
  shft = 0;
  ld_SCLK = 1;
  set_done = 0;
  case (state)
    IDLE: begin
      if (wrt) begin
        init = 1;
        nxt_state = FRONT;
      end
    end
    FRONT: begin
      ld_SCLK = 0;
      // First SCLK fall sends the loaded MSB without shifting it away.
      if (shft_imm)
        nxt_state = TRANSFER;
    end
    TRANSFER: begin
      ld_SCLK = 0;
      if (shft_imm) begin
        shft = 1;
        if (&bit_cnt) begin
          // Shift in the final sampled bit, but keep SCLK high.
          ld_SCLK = 1;
          set_done = 1;
          nxt_state = IDLE;
        end
      end
    end
    default: nxt_state = IDLE;
  endcase
end

// All datapath registers use the system clock, not SCLK.
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    SCLK_div <= 4'b1011;
  else if (ld_SCLK)
    SCLK_div <= 4'b1011;
  else
    SCLK_div <= SCLK_div + 4'd1;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    MISO_smpl <= 1'b0;
  else if (smpl)
    MISO_smpl <= MISO;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    shft_reg <= 16'd0;
  else if (init)
    shft_reg <= wt_data;
  else if (shft)
    shft_reg <= {shft_reg[14:0], MISO_smpl};

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    bit_cnt <= 4'd0;
  else if (init)
    bit_cnt <= 4'd0;
  else if (shft)
    bit_cnt <= bit_cnt + 4'd1;

// Registered select prevents glitches; completion stays high until a request.
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) begin
    SS_n <= 1'b1;
    done <= 1'b0;
  end else if (init) begin
    SS_n <= 1'b0;
    done <= 1'b0;
  end else if (set_done) begin
    SS_n <= 1'b1;
    done <= 1'b1;
  end

endmodule
