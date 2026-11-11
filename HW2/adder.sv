module adder(A, B, cin, Sum, co);

input [3:0] A, B;
input cin;
output [3:0] Sum;
output co;

// keep all five result bits so the carry out is avaible
assign {co, Sum} = {1'b0, A} + {1'b0, B} + cin;

endmodule
