module arith(A,B,SUB,SUM,OV);

input [7:0] A,B;		// two 8-bit quantities to be addes/subtracted
input SUB;				// if high operation is A - B, otherwise A + B
output [7:0] SUM;		// result of arithmetic operation
output OV;				// overflow if operands are interpretted as signed.

wire [7:0] B_comp;
wire both_pos,both_neg;

assign B_comp = (SUB) ? ~B : B;		// 1's complement if subtracting
assign SUM = A + B_comp + SUB;		// if subtracting we are inverting and adding 1
assign both_pos = ~A[7] & ~B_comp[7];	// both operands to adder were positive
//  A=8'h80 (-128), B=8'h01 (1), SUB=1 produces
// SUM=8'h7f (127) and must assert OV because -129 is out of range.
assign both_neg = A[7] & B_comp[7];	// both operands to adder were negative
////////////////////////////////////////////////////////////
// If both operands into adder are positive and result   //
// is negative then overflow occurred.  If both operands//
// are negative and result is positive then overflow ////
// occurred.  Overflow can't happen if operands are // 
// of different sign.                              //
////////////////////////////////////////////////////
assign OV = both_pos & SUM[7] | both_neg & ~SUM[7];

endmodule 
