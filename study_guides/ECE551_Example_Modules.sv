// Complete modules extracted from ECE551_Midterm_Code_Examples.md.
// Alternative fragments and the external SPI master are not included.

module dff_plain(input logic clk,d,
                 output logic q);
  always_ff @(posedge clk)
    q <= d;
endmodule

module job_controller(
  input  logic clk,rst_n,start,finished,
  output logic launch,busy,done_pulse
);
  typedef enum logic [1:0]
    {IDLE,RUN,FINISH} state_t;
  state_t state,nxt_state;

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) state <= IDLE;
    else        state <= nxt_state;

  always_comb begin
    nxt_state = state;
    launch = 0; busy = 0; done_pulse = 0;
    case (state)
      IDLE: if (start) begin
        launch = 1;
        nxt_state = RUN;
      end
      RUN: begin
        busy = 1;
        if (finished) nxt_state = FINISH;
      end
      FINISH: begin
        busy = 1;
        done_pulse = 1;
        nxt_state = IDLE;
      end
      default: nxt_state = IDLE;
    endcase
  end
endmodule

module a2d_sequence(
  input logic clk,rst_n,strt_cnv,done,
  input logic [2:0] chnnl,
  input logic [15:0] rd_data,
  output logic wrt,cnv_cmplt,
  output logic [15:0] cmd,
  output logic [11:0] res
);
  typedef enum logic [1:0]
    {IDLE,CHNNL,WAIT,RESP} state_t;
  state_t state,nxt_state;
  logic set_cc;

  assign cmd = {2'b00,chnnl,11'b0};
  assign res = rd_data[11:0];

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) state <= IDLE;
    else        state <= nxt_state;

  always_comb begin
    nxt_state = state; wrt = 0; set_cc = 0;
    case (state)
      IDLE: if (strt_cnv) begin
        wrt = 1; nxt_state = CHNNL;
      end
      CHNNL: if (done) nxt_state = WAIT;
      WAIT: begin
        wrt = 1; nxt_state = RESP;
      end
      RESP: if (done) begin
        set_cc = 1; nxt_state = IDLE;
      end
      default: nxt_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) cnv_cmplt <= 0;
    else if (strt_cnv) cnv_cmplt <= 0;
    else if (set_cc) cnv_cmplt <= 1;
endmodule

module steer_reference(
  input logic clk,rst_n,tmr_full,
  input logic sum_gt_min,sum_lt_min,
  input logic diff_gt_1_4,diff_gt_15_16,
  output logic clr_tmr,en_steer,rider_off
);
  typedef enum logic [1:0]
    {OFF,BALANCE,ON} state_t;
  state_t state,nxt_state;

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) state <= OFF;
    else        state <= nxt_state;

  always_comb begin
    nxt_state = state;
    clr_tmr = 0; en_steer = 0; rider_off = 0;
    case (state)
      OFF: begin
        clr_tmr = 1; rider_off = 1;
        if (sum_gt_min && !sum_lt_min)
          nxt_state = BALANCE;
      end
      BALANCE: begin
        if (sum_lt_min) begin
          rider_off = 1; clr_tmr = 1;
          nxt_state = OFF;
        end else if (diff_gt_1_4)
          clr_tmr = 1;
        else if (tmr_full)
          nxt_state = ON;
      end
      ON: begin
        if (sum_lt_min) begin
          rider_off = 1; clr_tmr = 1;
          nxt_state = OFF;
        end else if (diff_gt_15_16) begin
          clr_tmr = 1; nxt_state = BALANCE;
        end else en_steer = 1;
      end
      default: begin
        nxt_state = OFF;
        clr_tmr = 1; rider_off = 1;
      end
    endcase
  end
endmodule

module sync_edges #(parameter bit IDLE=1'b1)(
  input logic clk,rst_n,async_in,
  output logic rise,fall
);
  logic meta,synced,prev;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      meta <= IDLE; synced <= IDLE; prev <= IDLE;
    end else begin
      meta <= async_in;
      synced <= meta;
      prev <= synced;
    end
  assign rise = synced & ~prev;
  assign fall = ~synced & prev;
endmodule

module pattern_match(
  input logic clk,rst_n,in_stream,
  output logic match
);
  logic [7:0] shft_reg;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) shft_reg <= 8'h00;
    else shft_reg <= {shft_reg[6:0],in_stream};
  assign match = (shft_reg == 8'hAB);
endmodule

module reset_sync(
  input logic clk,RST_n,
  output logic rst_n
);
  logic stage;
  always_ff @(negedge clk or negedge RST_n)
    if (!RST_n) begin stage <= 0; rst_n <= 0; end
    else begin stage <= 1; rst_n <= stage; end
endmodule

module pwm8(
  input logic clk,rst_n,
  input logic [7:0] mag,
  output logic intensity
);
  logic [7:0] cntr;
  logic set_pwm,clear_pwm;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) cntr <= '0;
    else cntr <= cntr + 8'd1;

  assign set_pwm = ~|cntr;
  assign clear_pwm = (cntr >= mag);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) intensity <= 1'b0;
    else if (clear_pwm) intensity <= 1'b0;
    else if (set_pwm) intensity <= 1'b1;
endmodule

module counter #(parameter int W=8)(
  input logic clk,rst_n,en,clr,
  output logic [W-1:0] count,
  output logic terminal
);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) count <= '0;
    else if (clr) count <= '0;
    else if (en) count <= count + 1'b1;
  assign terminal = &count;
endmodule
// Instance inside another module:
// counter #(.W(11)) u_cnt(.clk(clk),...);

`timescale 1ns/1ps
module adder_reference_tb;
  logic [3:0] A,B,S;
  logic cin,co;
  logic [4:0] expected;
  assign {co,S} = {1'b0,A}+{1'b0,B}+cin;
  initial begin
    for (int i=0;i<512;i++) begin
      {A,B,cin} = i[8:0];
      expected = int'(A)+int'(B)+int'(cin);
      #1; // let combinational logic settle
      if ({co,S} !== expected)
        $fatal(1,"adder mismatch at case %0d",i);
    end
    $display("PASS: 512 cases");
    $finish;
  end
endmodule
