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

// mux = OR(AND(A,NOT(SEL)),AND(B,SEL))
module mux(
  input wire a,
  input wire b,
  input wire sel,
  output wire y
);
wire not_sel, a_and_not_sel, b_and_sel;
not1 u_notsel(
  .a(sel),
  .y(not_sel)
);
and2 u_a_and_not_sel(
  .a(a),
  .b(not_sel),
  .y(a_and_not_sel)
);
and2 u_b_and_sel(
  .a(b),
  .b(sel),
  .y(b_and_sel)
);
or2 result(
  .a(a_and_not_sel),
  .b(b_and_sel),
  .y(y)
);
endmodule  // mux

// demux: in goes to a or b, depending on sel
module dmux(
  input wire in,
  input wire sel,
  output wire a,
  output wire b
);
wire not_sel;
not1 u_notsel(
  .a(sel),
  .y(not_sel)
);
and2 u_result_a(
  .a(not_sel),
  .b(in),
  .y(a)
);
and2 u_result_b(
  .a(sel),
  .b(in),
  .y(b)
);
endmodule  // dmux

module not16(
  input wire [15:0] a,
  output wire [15:0] y
);

genvar i;
generate
  for (i = 0; i < 16; ++i) begin
    not1 u_not(.a(a[i]), .y(y[i]));
  end
endgenerate

endmodule  // not16

// and16
module and16(
  input wire [15:0] a,
  input wire [15:0] b,
  output wire [15:0] y
);

genvar i;
generate
  for (i = 0; i < 16; ++i) begin
    and2 u_and(.a(a[i]), .b(b[i]), .y(y[i]));
  end
endgenerate

endmodule  // and16

// or16
module or16(
  input wire [15:0] a,
  input wire [15:0] b,
  output wire [15:0] y
);

genvar i;
generate
  for (i = 0; i < 16; ++i) begin
    or2 u_or(.a(a[i]), .b(b[i]), .y(y[i]));
  end
endgenerate

endmodule  // or16

// mux16
module mux16(
  input wire [15:0] a,
  input wire [15:0] b,
  output wire [15:0] y
);

genvar i;
generate
  for (i = 0; i < 16; ++i) begin
    mux u_mux(.a(a[i]), .b(b[i]), .y(y[i]));
  end
endgenerate

endmodule  // mux16
