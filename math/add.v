`default_nettype none

// half adder
module half_adder(
  input wire a,
  input wire b,
  output wire sum,
  output wire carry
);
xor2 u_xor2(.a(a), .b(b), .y(sum));
and2 u_and2(.a(a), .b(b), .y(carry));
endmodule  //half_adder

// full adder
module full_adder(
  input wire a,
  input wire b,
  input wire c,
  output wire sum,
  output wire carry
);

wire sum_bc, not_sum_bc, carry_bc, or_carry_bc;

xor2 u_xorsum(.a(b), .b(c), .y(sum_bc));
not1 u_notsum(.a(sum_bc), .y(not_sum_bc));

and2 u_andcarry(.a(b), .b(c), .y(carry_bc));
or2 u_orcarry(.a(b), .b(c), .y(or_carry_bc));

mux u_mux_sum(.a(sum_bc), .b(not_sum_bc), .sel(a), .y(sum));
mux u_mux_carry(.a(carry_bc), .b(or_carry_bc), .sel(a), .y(carry));
endmodule  // full_adder

// add16 16-bit adder

// inc16 16-bit incrementer
