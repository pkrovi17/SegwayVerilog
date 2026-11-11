module A2D_test(clk, RST_n, SEL, LED, SCLK, SS_n, MOSI, MISO);

input clk, RST_n, SEL, MISO;
output reg [7:0] LED;
output SCLK, SS_n, MOSI;

reg [18:0] conv_cnt;
reg [1:0] sel_cnt;
wire rst_n, nxt, en_2bit;
wire [11:0] lft_ld, rght_ld, steer_pot, batt;

// request every 2^19 clks 
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    conv_cnt <= 19'd0;
  else
    conv_cnt <= conv_cnt + 19'd1;
assign nxt = &conv_cnt;

// button release selects next measure for LEDs
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    sel_cnt <= 2'd0;
  else if (en_2bit)
    sel_cnt <= sel_cnt + 2'd1;

always_comb begin
  case (sel_cnt)
    0: LED = lft_ld[11:4];
    1: LED = rght_ld[11:4];
    2: LED = steer_pot[11:4];
    3: LED = batt[11:4];
    default: LED = 8'd0;
  endcase
end

A2D_intf iDUT(.clk(clk), .rst_n(rst_n), .nxt(nxt), .lft_ld(lft_ld),
  .rght_ld(rght_ld), .steer_pot(steer_pot), .batt(batt),
  .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));
PB_release iPB(.clk(clk), .rst_n(rst_n), .PB(SEL), .released(en_2bit));
rst_synch iRST(.clk(clk), .RST_n(RST_n), .rst_n(rst_n));

endmodule
