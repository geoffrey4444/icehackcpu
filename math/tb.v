`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb;
reg a, b, c;
reg [15:0] a16;
reg [15:0] b16;
wire [15:0] sum16;
wire sum, carry, full_sum, full_carry;
integer i, j, k;

half_adder u_half_adder(.a(a), .b(b), .sum(sum), .carry(carry));
full_adder u_full_adder(.a(a), .b(b), .c(c), .sum(full_sum), .carry(full_carry));
add16 u_add16(.a(a16), .b(b16), .sum(sum16));

initial begin
for (i = 0; i < 2; ++i) begin
  for (j = 0; j < 2; ++j) begin
    for (k = 0; k < 2; ++k) begin
      a = i;
      b = j;
      c = k;
      #1;

      if (k == 0) begin
        if ((a == 0) & (b == 0) & ((carry != 0) | (sum != 0))) $fatal;
        if ((a == 0) & (b == 1) & ((carry != 0) | (sum != 1))) $fatal;
        if ((a == 1) & (b == 0) & ((carry != 0) | (sum != 1))) $fatal;
        if ((a == 1) & (b == 1) & ((carry != 1) | (sum != 0))) $fatal; 
      end
      if ((a == 0) & (b == 0) & (c == 0) & ((full_carry != 0) | (full_sum != 0))) $fatal;
      if ((a == 0) & (b == 0) & (c == 1) & ((full_carry != 0) | (full_sum != 1))) $fatal;
      if ((a == 0) & (b == 1) & (c == 0) & ((full_carry != 0) | (full_sum != 1))) $fatal;
      if ((a == 0) & (b == 1) & (c == 1) & ((full_carry != 1) | (full_sum != 0))) $fatal;
      if ((a == 1) & (b == 0) & (c == 0) & ((full_carry != 0) | (full_sum != 1))) $fatal;
      if ((a == 1) & (b == 0) & (c == 1) & ((full_carry != 1) | (full_sum != 0))) $fatal;
      if ((a == 1) & (b == 1) & (c == 0) & ((full_carry != 1) | (full_sum != 0))) $fatal;
      if ((a == 1) & (b == 1) & (c == 1) & ((full_carry != 1) | (full_sum != 1))) $fatal;
    end   
  end
end

// Test full adder

repeat (1000) begin
  a16 = $random;
  b16 = 16'b0;
  #1;
  if (sum16 != a16) $fatal;

  // more tests, including negation via 2's complement
  // a + (-a) = 0
  // (-1) + 1 = 0
  // 1 + 1 = 2, 2 + 2 = 4
  // MAX + 0, MIN + 0, MAX + 1, MIN + 1, MIN + (-1), MAX + MAX, MIN + MIN = -1, MIN + (-MIN == MIN);
  // Carry checks: 1+1, F+1, FF + 1, FFF + 1, 7FFF+1, FFFF+1, AAAA+5555 = FFFF, 5555 + 5555 = AAAA
  // 1 + (-1), 2 + (-1), 1 + (-2);
  // 30000 + (-1), 32767 + (-100), -30000 + 1, -32768 + 100

  // Random tests from special values
  // Commutivity, associativity mod 2^16
  // a + (~a + 1) == 0 (mod 2^16).

  // Random tests from random values

end

end
endmodule  // tb