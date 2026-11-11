module piezo_drv(clk, rst_n, en_steer, too_fast, batt_low, piezo, piezo_n);

parameter fast_sim = 1;
input clk, rst_n, en_steer, too_fast, batt_low;
output piezo, piezo_n;

localparam IDLE = 2'd0, PLAY = 2'd1, WAIT_REPEAT = 2'd2;
localparam [27:0] REPEAT_CLKS = 28'd150000000; // 3 seconds at 50 MHz
reg [1:0] state, nxt_state;
reg [2:0] note_idx;
reg reverse_tune, alarm_mode, tone;
reg [24:0] note_cnt;
reg [15:0] freq_cnt;
reg [27:0] repeat_cnt;
reg [24:0] note_duration;
reg [15:0] half_period;
reg start_tune, next_note;
wire [6:0] step;
wire [2:0] tune_note;
wire active, note_done, last_note, repeat_done;

// three timers 64 times faster simulation
generate
  if (fast_sim) begin : fast_timers
    assign step = 7'd64;
  end else begin : real_timers
    assign step = 7'd1;
  end
endgenerate

assign active = en_steer || too_fast || batt_low;
assign tune_note = reverse_tune ? 3'd5 - note_idx : note_idx;
assign note_done = (note_cnt >= note_duration - step);
assign last_note = alarm_mode ? (note_idx == 3'd2) : (note_idx == 3'd5);
assign repeat_done = (repeat_cnt >= REPEAT_CLKS - step);

// 50Mhz
// reversing uses same table
always_comb begin
  half_period = 16'd15944;
  note_duration = 25'd8388608;
  case (tune_note)
    0: begin half_period = 15944; note_duration = 8388608; end // G6
    1: begin half_period = 11945; note_duration = 8388608; end // C7
    2: begin half_period = 9480;  note_duration = 8388608; end // E7
    3: begin half_period = 7972;  note_duration = 12582912; end // G7, 2^23+2^22
    4: begin half_period = 9480;  note_duration = 4194304; end // E7, 2^22
    5: begin half_period = 7972;  note_duration = 16777216; end // G7, 2^24
    default: begin end
  endcase
end

// Boutputs low in silecne 
assign piezo = ((state == PLAY) && active) ? tone : 1'b0;
assign piezo_n = ((state == PLAY) && active) ? ~tone : 1'b0;

always_comb begin
  nxt_state = state;
  start_tune = 0;
  next_note = 0;
  if (!active)
    nxt_state = IDLE;
  else begin
    case (state)
      IDLE: begin
        start_tune = 1;
        nxt_state = PLAY;
      end
      PLAY: begin
        if (too_fast && !alarm_mode)
          start_tune = 1; // overspeed
        else if (note_done) begin
          if (!last_note)
            next_note = 1;
          else if (too_fast || alarm_mode)
            start_tune = 1; // repeat alarm
          else
            nxt_state = WAIT_REPEAT;
        end
      end
      WAIT_REPEAT: begin
        if (too_fast || repeat_done) begin
          start_tune = 1;
          nxt_state = PLAY;
        end
      end
      default: nxt_state = IDLE;
    endcase
  end
end

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) begin
    note_idx <= 0;
    reverse_tune <= 0;
    alarm_mode <= 0;
    note_cnt <= 0;
    freq_cnt <= 0;
    repeat_cnt <= 0;
    tone <= 0;
  end else if (!active || start_tune) begin
    note_idx <= 0;
    reverse_tune <= active && batt_low && !too_fast;
    alarm_mode <= active && too_fast;
    note_cnt <= 0;
    freq_cnt <= 0;
    repeat_cnt <= 0;
    tone <= 0;
  end else begin
    // repeat interval is start-to-start
    if ((state != IDLE) && (repeat_cnt < REPEAT_CLKS))
      repeat_cnt <= repeat_cnt + step;
    if (state == PLAY) begin
      if (note_done) begin
        note_cnt <= 0;
        freq_cnt <= 0;
        tone <= 0;
        if (next_note)
          note_idx <= note_idx + 3'd1;
      end else begin
        note_cnt <= note_cnt + step;
        if (freq_cnt + step >= half_period) begin
          // preserve the remainder 
          freq_cnt <= freq_cnt + step - half_period;
          tone <= ~tone;
        end else
          freq_cnt <= freq_cnt + step;
      end
    end
  end

endmodule
