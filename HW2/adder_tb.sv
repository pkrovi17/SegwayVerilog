`timescale 1ns/1ps

module adder_tb();

reg [3:0] A, B;
reg cin;
wire [3:0] Sum;
wire co;
integer a, b, carry_in;
integer expected;
integer tests;

adder iDUT(.A(A), .B(B), .cin(cin), .Sum(Sum), .co(co));

initial begin
  tests = 0;
  // try all 16 * 16 * 2 = 512 inputs
  for (a = 0; a < 16; a = a + 1) begin
    for (b = 0; b < 16; b = b + 1) begin
      for (carry_in = 0; carry_in < 2; carry_in = carry_in + 1) begin
        A = a;
        B = b;
        cin = carry_in;

        // integer addition is done in 32 bits
        expected = a + b + carry_in;
        #1; // let the combinational output settle
        // check both sum and carry
        if ({co, Sum} !== expected[4:0]) begin
          $display("ERROR: A=%0d B=%0d cin=%b: Sum=%0d co=%b, expected Sum=%0d co=%b",
                   A, B, cin, Sum, co, expected[3:0], expected[4]);
          $stop();
        end
        tests = tests + 1;
      end
    end
  end

  $display("All %0d adder tests passed!", tests);
  $finish();
end

endmodule
