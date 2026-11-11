`timescale 1ns/1ps

module arith_tb();

reg [7:0] A, B;
reg SUB;
wire [7:0] SUM;
wire OV;

integer a, b, op;
integer expected;
reg expected_ov;

/////// Instantiate DUT /////////
arith iDUT(.A(A), .B(B), .SUB(SUB), .SUM(SUM), .OV(OV));

initial begin
  // Try 131072 input combos
  //  a and b hold signed values from -128 through 127
  // both operations | all sign combination | and overflow
  for (op = 0; op < 2; op = op + 1) begin
    SUB = op;
    for (a = -128; a < 128; a = a + 1) begin
      for (b = -128; b < 128; b = b + 1) begin
        A = a;
        B = b;
        if (SUB)
          expected = a - b;
        else
          expected = a + b;
        expected_ov = (expected < -128) || (expected > 127);
        #1; // wait 
        //keep only the low 8 bits
        if (SUM !== expected[7:0]) begin
          $display("ERROR: A=%0d B=%0d SUB=%b: SUM=%h, expected %h",
                   a, b, SUB, SUM, expected[7:0]);
          $stop();
        end
        // the original was incorrect
        if (OV !== expected_ov) begin
          $display("ERROR: A=%0d B=%0d SUB=%b: OV=%b, expected %b",
                   a, b, SUB, OV, expected_ov);
          $stop();
        end
      end
    end
  end
  $display("all 131072 tests passed!");
  $finish();
end

endmodule
