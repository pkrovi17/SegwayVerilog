module ff_case_2(input logic clk,d,rst,rst_n,en,pre_n,S,R,T,J,K, output logic q);
always_ff @(posedge clk)
  if (rst) q <= 1'b0;
  else     q <= d;
endmodule

module ff_case_4(input logic clk,d,rst,rst_n,en,pre_n,S,R,T,J,K, output logic q);
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) q <= 1'b0;
  else        q <= d;
endmodule

module ff_case_5(input logic clk,d,rst,rst_n,en,pre_n,S,R,T,J,K, output logic q);
always_ff @(posedge clk or posedge rst)
  if (rst) q <= 1'b0;
  else     q <= d;
endmodule

module ff_case_6(input logic clk,d,rst,rst_n,en,pre_n,S,R,T,J,K, output logic q);
always_ff @(posedge clk or negedge pre_n)
  if (!pre_n) q <= 1'b1;
  else        q <= d;
endmodule

module ff_case_7(input logic clk,d,rst,rst_n,en,pre_n,S,R,T,J,K, output logic q);
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) q <= 1'b0;
  else if (en) q <= d;
// en=0: hold q; no final else required.
endmodule

module ff_case_9(input logic clk,d,rst,rst_n,en,pre_n,S,R,T,J,K, output logic q);
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) q <= 1'b0;
  else if (R) q <= 1'b0;
  else if (S) q <= 1'b1;
endmodule

module ff_case_T(input logic clk,d,rst,rst_n,en,pre_n,S,R,T,J,K, output logic q);
// T FF: T=1 toggles; T=0 holds.
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) q <= 1'b0;
  else if (T) q <= ~q;


endmodule

module ff_case_JK(input logic clk,d,rst,rst_n,en,pre_n,S,R,T,J,K, output logic q);
// JK FF: 00 hold; 01 reset; 10 set; 11 toggle.
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) q <= 1'b0;
  else case ({J,K})
    2'b00: ;
    2'b01: q <= 1'b0;
    2'b10: q <= 1'b1;
    2'b11: q <= ~q;
    default: q <= 1'bx; // expose unknown controls
  endcase
endmodule
