`default_nettype none

// nand2
module nand2(
  input wire a,
  input wire b,
  output wire y
);
assign y = ~(a & b);
endmodule  // nand2

// not1
module not1(
  input wire a,
  output wire y
);
nand2 u_nand2(
  .a(a),
  .b(a),
  .y(y)
);
endmodule  // not1

// and2
module and2(
  input wire a,
  input wire b,
  output wire y
);
wire u_nand2_ab;
nand2 u_nand2(
  .a(a),
  .b(b),
  .y(u_nand2_ab)
);
not1 u_not1(
  .a(u_nand2_ab),
  .y(y)
);
endmodule  // and2

// or2 = NAND(not(A),not(B))
module or2(
  input wire a,
  input wire b,
  output wire y
);
wire not_1a;
not1 u_not1_a(
  .a(a),
  .y(not_1a)
);
wire not_1b;
not1 u_not1_b(
  .a(b),
  .y(not_1b)
);
nand2 result(
  .a(not_1a),
  .b(not_1b),
  .y(y)
);
endmodule  // or2

// xor2 = AND(OR(A,B),NAND(A,B))
module xor2(
  input wire a,
  input wire b,
  output wire y
);
wire or_ab;
or2 u_or_ab(
  .a(a),
  .b(b),
  .y(or_ab)
);

wire nand_ab;
nand2 u_nand_ab(
  .a(a),
  .b(b),
  .y(nand_ab)
);

and2 u_result(
  .a(or_ab),
  .b(nand_ab),
  .y(y)
);
endmodule  // xor2
