`timescale 1ns/1ps
module code_reference_tb;
  logic clk=0;
  always #5 clk=~clk;
  logic rst_n=1, d=0, rst=1, en=0, pre_n=1, S=0, R=0;
  logic T=0,J=0,K=0;
  wire qsync,qasync,qpreset,qen,qsr;
  wire qhigh,qT,qJK;
  ff_case_2 u2(.*,.q(qsync));
  ff_case_4 u4(.*,.q(qasync));
  ff_case_5 u5(.*,.q(qhigh));
  ff_case_6 u6(.*,.q(qpreset));
  ff_case_7 u7(.*,.q(qen));
  ff_case_9 u9(.*,.q(qsr));
  ff_case_T uT(.*,.q(qT));
  ff_case_JK uJK(.*,.q(qJK));
  logic start=0,finished=0;
  wire launch,busy,done_pulse;
  job_controller job(.*);
  logic strt_cnv=0,done=0;
  logic [2:0] chnnl=5;
  logic [15:0] rd_data=16'hA123;
  wire wrt,cnv_cmplt;
  wire [15:0] cmd;
  wire [11:0] res;
  a2d_sequence seq(.*);
  logic sum_gt_min=0,sum_lt_min=0;
  logic diff_gt_1_4=0,diff_gt_15_16=0,tmr_full=0;
  wire clr_tmr,en_steer,rider_off;
  steer_reference steer(.*);
  logic async_in=1;
  wire rise,fall;
  sync_edges edges(.*);
  logic in_stream=0;
  wire match;
  pattern_match pattern(.*);
  wire rst_sync_out;
  reset_sync rs(.clk(clk),.RST_n(rst_n),.rst_n(rst_sync_out));
  logic [7:0] mag=0;
  wire intensity;
  pwm8 pwm(.*);
  logic counter_en=0,clr=0;
  wire [3:0] count;
  wire terminal;
  counter #(.W(4)) cnt(.clk(clk),.rst_n(rst_n),.en(counter_en),.*);

  task step;
    @(posedge clk); #1;
  endtask
  task require(input logic ok, input string message);
    if (ok !== 1'b1) $fatal(1,"%s",message);
  endtask

  initial begin
    #2; rst_n=0; pre_n=0; #1;
    require(qasync===0 && qen===0 && qsr===0 && qpreset===1 && qT===0 && qJK===0,
            "asynchronous clear and preset");
    require(wrt===0 && cnv_cmplt===0 && !busy && !done_pulse,
            "FSM reset state and completion");
    require(rider_off && clr_tmr && !en_steer && !intensity,
            "steering and PWM reset");
    #1; rst_n=1; pre_n=1;
    @(negedge clk); #1;
    require(rst_sync_out===0,"reset release before second negedge");
    @(negedge clk); #1;
    require(rst_sync_out===1,"reset release after second negedge");

    // Synchronous reset acts on an edge; enable holds; clear wins over set.
    d=1; rst=0; en=1; S=1; R=0;
    step;
    require(qsync && qasync && qen && qsr,"FF capture and synchronous set");
    @(negedge clk); d=0; en=0; S=1; R=1; rst=1;
    #1; require(qsync===1 && qhigh===0,"sync reset waits for edge; async high reset acts now");
    step;
    require(qsync===0 && qen===1 && qsr===0,"sync clear, enable hold, SR priority");
    @(negedge clk); rst=0; S=0; R=0;

    T=1; J=1; K=0; step;
    require(qT && qJK,"T toggle and JK synchronous set");
    @(negedge clk); T=0; J=0; K=1; step;
    require(qT && !qJK,"T hold and JK reset");
    @(negedge clk); T=1; J=1; K=1; step;
    require(!qT && qJK,"T toggle and JK both-input toggle");
    @(negedge clk); T=0; J=0; K=0; step;
    require(!qT && qJK,"T and JK hold");
    @(negedge clk);

    // Pulse controller: launch -> RUN -> FINISH -> IDLE.
    start=1; #1; require(launch && !busy,"Mealy launch while idle");
    step; require(busy && !launch && !done_pulse,"RUN outputs");
    @(negedge clk); start=0; finished=1;
    step; require(done_pulse && busy,"FINISH full-state done pulse");
    @(negedge clk); finished=0;
    step; require(!done_pulse && !busy,"return IDLE after one done cycle");

    // Q16's first and second transaction starts are separated by WAIT.
    @(negedge clk); strt_cnv=1; #1;
    require(wrt && cmd==16'h2800 && res==12'h123,"channel command/launch/widths");
    step; require(!wrt && !cnv_cmplt,"first transaction wait");
    @(negedge clk); strt_cnv=0; done=1;
    step; require(wrt && !cnv_cmplt,"WAIT asserts second start");
    @(negedge clk); done=0;
    step; require(!wrt && !cnv_cmplt,"RESP entered after one WAIT cycle");
    @(negedge clk); done=1;
    step; require(cnv_cmplt && !wrt,"second done sets completion");
    @(negedge clk); done=0;
    step; require(cnv_cmplt,"completion sticky in idle");
    @(negedge clk); strt_cnv=1;
    step; require(!cnv_cmplt,"new request clears completion");
    @(negedge clk); strt_cnv=0;

    // Timed qualification prioritizes imbalance over timer and removal over step-off.
    sum_gt_min=1; step;
    require(!rider_off && !en_steer,"known rider enters BALANCE");
    @(negedge clk); tmr_full=1; diff_gt_1_4=1;
    step; require(clr_tmr && !en_steer,"imbalance wins over expiry");
    @(negedge clk); diff_gt_1_4=0;
    step; require(en_steer,"balanced rider enables steering");
    @(negedge clk); sum_lt_min=1; diff_gt_15_16=1; #1;
    require(!en_steer && rider_off,"Mealy removal withdraws steering immediately");
    step; require(rider_off && steer.state==0,"removal priority returns OFF");
    @(negedge clk); sum_gt_min=0; sum_lt_min=0;
    diff_gt_15_16=0; tmr_full=0;

    // Two synchronization stages and a one-cycle edge pulse.
    async_in=0; step; require(!fall,"fall cannot bypass synchronization");
    step; require(fall && !rise,"fall after second synchronization stage");
    step; require(!fall,"fall pulse clears after history catches up");
    @(negedge clk); async_in=1;
    step; require(!rise,"rise cannot bypass synchronization");
    step; require(rise && !fall,"rise after second stage");
    step; require(!rise,"rise pulse exactly one cycle");

    for (int k=7;k>=0;k--) begin
      @(negedge clk); in_stream=(8'hAB>>k)&1;
      step;
      if (k!=0) require(!match,"no premature AB match");
    end
    require(match,"eight samples produce AB match");
    @(negedge clk); in_stream=0;
    step; require(!match,"sliding window advances past match");

    // Enabled four-bit counter wraps and synchronous clear outranks enable.
    @(negedge clk); counter_en=1;
    for (int i=1;i<=16;i++) begin
      step; require(count===i[3:0],"parameterized counter count and wrap");
      require(terminal===(count==15),"terminal decode");
    end
    @(negedge clk); counter_en=0;
    step; require(count===0,"disabled count holds");
    @(negedge clk); counter_en=1; clr=1;
    step; require(count===0,"clear outranks enable");
    @(negedge clk); counter_en=0; clr=0;

    // At every old counter value, a steady PWM has exactly mag high samples.
    for (int test=0;test<4;test++) begin
      wait(pwm.cntr==0);
      @(negedge clk);
      case(test) 0:mag=0; 1:mag=1; 2:mag=7; 3:mag=255; endcase
      for(int i=0;i<256;i++) begin
        step;
        require(intensity===(i<mag),"PWM stable duty and clear/set priority");
      end
    end
    $display("PASS: FF reset/hold/priority; job and A2D FSMs; steering; synchronization; pattern; counter; PWM");
    $finish;
  end
  initial begin #20000; $fatal(1,"timeout"); end
endmodule
