module A2D_intf(clk, rst_n, nxt, lft_ld, rght_ld, steer_pot, batt,
                SS_n, SCLK, MOSI, MISO);

input clk, rst_n, nxt, MISO;
output reg [11:0] lft_ld, rght_ld, steer_pot, batt;
output SS_n, SCLK, MOSI;

localparam IDLE = 3'd0, WAIT_CONVERT = 3'd1, START_READ = 3'd2,
           WAIT_READ = 3'd3, UPDATE = 3'd4;
reg [2:0] state, nxt_state;
reg [1:0] channel_idx;
reg [2:0] channel;
reg wrt;
wire done;
wire [15:0] rd_data, wt_data;

// ADC128S command: 2 zeros 3 channel 11 zeros
// second command is ignored
assign wt_data = {2'b00, channel, 11'h000};

SPI_main iSPI(.clk(clk), .rst_n(rst_n), .wrt(wrt), .wt_data(wt_data),
  .done(done), .rd_data(rd_data), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));

always_comb begin
  case (channel_idx)
    0: channel = 3'd0;
    1: channel = 3'd4;
    2: channel = 3'd5;
    3: channel = 3'd6;
    default: channel = 3'd0;
  endcase
end

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;

always_comb begin
  nxt_state = state;
  wrt = 0;
  case (state)
    IDLE: begin
      if (nxt) begin
        wrt = 1;
        nxt_state = WAIT_CONVERT;
      end
    end
    WAIT_CONVERT: begin
      if (done)
        nxt_state = START_READ;
    end
    START_READ: begin
      // 1 start state seperates the 2 requests and clears done
      wrt = 1;
      nxt_state = WAIT_READ;
    end
    WAIT_READ: begin
      if (done)
        nxt_state = UPDATE;
    end
    UPDATE: nxt_state = IDLE;
    default: nxt_state = IDLE;
  endcase
end

// 2nd transaction updates holding register
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) begin
    channel_idx <= 0;
    lft_ld <= 0;
    rght_ld <= 0;
    steer_pot <= 0;
    batt <= 0;
  end else if (state == UPDATE) begin
    case (channel_idx)
      0: lft_ld <= rd_data[11:0];
      1: rght_ld <= rd_data[11:0];
      2: steer_pot <= rd_data[11:0];
      3: batt <= rd_data[11:0];
    endcase
    channel_idx <= channel_idx + 2'd1;
  end

endmodule
