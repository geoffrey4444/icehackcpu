`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb;
reg a, b, c;
wire sum, carry, full_sum, full_carry;
integer i, j, k;

half_adder u_half_adder(.a(a), .b(b), .sum(sum), .carry(carry));
full_adder u_full_adder(.a(a), .b(b), .c(c), .sum(full_sum), .carry(full_carry));

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
end

endmodule  // tb