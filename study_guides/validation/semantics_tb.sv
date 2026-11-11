`timescale 1ns/1ps
module semantics_tb;
reg a=0; wire #5 w=a;
reg transport=0;
always @(a) transport <= #5 a;
reg EN, osc_b, osc_nb;
always @(EN or osc_b) osc_b = #15 (EN ? ~osc_b : 1'b1);
always @(EN or osc_nb) osc_nb <= #15 (EN ? ~osc_nb : 1'b1);
integer nb_edges=0,b_edges=0;
always @(osc_nb) if(EN) nb_edges=nb_edges+1;
always @(osc_b) if(EN) b_edges=b_edges+1;
reg clk=0, q1=0, q2=1, d=1;
always #10 clk=~clk;
always @(posedge clk) begin q1<=d; q2<=q1; end
initial begin
 EN=0;
 #10; #1;
 if(q1!==1 || q2!==0) $fatal(1,"NBA pipeline mismatch");
 #9; a=1; #2; a=0;
 #4;
 if(w!==0 || transport!==1) $fatal(1,"delay behavior mismatch");
 #2;
 if(transport!==0) $fatal(1,"transport falling edge mismatch");
 #12; EN=1;
 #100;
 if(nb_edges<5 || b_edges!=1) $fatal(1,"oscillator behavior mismatch");
 $display("PASS: old-value NBA pipeline; inertial net delay; transport NBA; ring self-trigger");
 $display("ring transitions after EN: blocking=%0d nonblocking=%0d",b_edges,nb_edges);
 $finish;
end
endmodule
