module mult_accum_gated(clk, clr, en, A, B, accum);

input clk, clr, en;
input [15:0] A, B;
output reg [63:0] accum;

reg [31:0] prod_reg;
reg en_stg2;
reg prod_en_lat, accum_en_lat;
wire prod_clk, accum_clk;

// enables change when clk is low
always_latch
  if (!clk) begin
    prod_en_lat <= en;
    accum_en_lat <= en_stg2 | clr;
  end

assign prod_clk = clk & prod_en_lat;
assign accum_clk = clk & accum_en_lat;

// gated clock replaces mux
always_ff @(posedge prod_clk)
  prod_reg <= A * B;

// pipeline stage contiues when en is low
always_ff @(posedge clk)
  en_stg2 <= en;

// clr enables clock
always_ff @(posedge accum_clk)
  if (clr)
    accum <= 64'd0;
  else
    accum <= accum + prod_reg;

endmodule
