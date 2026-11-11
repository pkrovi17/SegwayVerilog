// sync_fifo variant 1
`timescale 1ns/1ps

module sync_fifo #(
  parameter int WIDTH = 8,
  parameter int DEPTH = 16
)(
  input  logic                       clk,
  input  logic                       rst_n,
  input  logic                       wr_en,
  input  logic [WIDTH-1:0]           wr_data,
  input  logic                       rd_en,
  output logic [WIDTH-1:0]           rd_data,
  output logic                       full,
  output logic                       empty,
  output logic [$clog2(DEPTH+1)-1:0] count,
  output logic                       overflow,
  output logic                       underflow
);

  localparam int AW = $clog2(DEPTH);

  initial begin
    assert (DEPTH >= 2 && (DEPTH & (DEPTH - 1)) == 0)
      else $fatal(1, "sync_fifo: DEPTH (%0d) must be a power of 2 and >= 2", DEPTH);
  end

  logic [WIDTH-1:0] mem [DEPTH];
  logic [AW-1:0]    wr_ptr, rd_ptr;

  assign full  = (count == DEPTH - 1);
  assign empty = (count == 0);

  logic do_rd, do_wr;
  assign do_rd = rd_en && !empty;
  assign do_wr = wr_en && (!full || rd_en);

  always_ff @(posedge clk) begin
    if (do_wr)
      mem[wr_ptr] <= wr_data;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      wr_ptr <= '0;
    else if (do_wr)
      wr_ptr <= wr_ptr + 1'b1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr  <= '0;
      rd_data <= '0;
    end else if (do_rd) begin
      rd_data <= mem[rd_ptr];
      rd_ptr  <= rd_ptr + 1'b1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      count <= '0;
    else if (do_wr != do_rd)
      count <= do_wr ? count + 1'b1 : count - 1'b1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      overflow  <= 1'b0;
      underflow <= 1'b0;
    end else begin
      overflow  <= wr_en && full && !rd_en;
      underflow <= rd_en && empty;
    end
  end

endmodule
