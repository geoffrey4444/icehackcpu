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
  input wire sel,
  output wire [15:0] y
);

genvar i;
generate
  for (i = 0; i < 16; ++i) begin
    mux u_mux(.a(a[i]), .b(b[i]), .sel(sel), .y(y[i]));
  end
endgenerate

endmodule  // mux16

// or8way
module or8way(
  input wire [7:0] a,
  output wire y
);
wire or01, or23, or45, or67, or0123, or4567;
or2 u_or01(.a(a[0]), .b(a[1]), .y(or01));
or2 u_or23(.a(a[2]), .b(a[3]), .y(or23));
or2 u_or45(.a(a[4]), .b(a[5]), .y(or45));
or2 u_or67(.a(a[6]), .b(a[7]), .y(or67));
or2 u_or0123(.a(or01), .b(or23), .y(or0123));
or2 u_or4567(.a(or45), .b(or67), .y(or4567));
or2 u_result(.a(or0123), .b(or4567), .y(y));
endmodule  // or8way

// mux4way16
module mux4way16(
  input wire [15:0] a,
  input wire [15:0] b,
  input wire [15:0] c,
  input wire [15:0] d,
  input wire [1:0] sel,
  output wire [15:0] y
);
wire [15:0] muxab;
wire [15:0] muxcd;
mux16 u_muxab(.a(a), .b(b), .sel(sel[0]), .y(muxab));
mux16 u_muxcd(.a(c), .b(d), .sel(sel[0]), .y(muxcd));
mux16 uresult(.a(muxab), .b(muxcd), .sel(sel[1]), .y(y));
endmodule  // mux4way16

// mux8way16
module mux8way16(
  input wire [15:0] a,
  input wire [15:0] b,
  input wire [15:0] c,
  input wire [15:0] d,
  input wire [15:0] e,
  input wire [15:0] f,
  input wire [15:0] g,
  input wire [15:0] h,
  input wire [2:0] sel,
  output wire [15:0] y
);
wire [15:0] muxabcd;
wire [15:0] muxefgh;
mux4way16 u_mux4way16abcd(.a(a), .b(b), .c(c), .d(d), .sel(sel[1:0]), .y(muxabcd));
mux4way16 u_mux4way16efgh(.a(e), .b(f), .c(g), .d(h), .sel(sel[1:0]), .y(muxefgh));
mux16 u_mux16(.a(muxabcd), .b(muxefgh), .sel(sel[2]), .y(y));

endmodule  // mux8way16

module dmux4way(
  input wire in,
  input wire [1:0] sel,
  output wire a,
  output wire b,
  output wire c,
  output wire d
);
wire a_ab;
wire b_ab;
wire c_cd;
wire d_cd;

dmux muxab(.in(in), .sel(sel[0]), .a(a_ab), .b(b_ab));
dmux muxcd(.in(in), .sel(sel[0]), .a(c_cd), .b(d_cd));

wire not_sel1;
not1 u_notsel(
  .a(sel[1]),
  .y(not_sel1)
);

and2 and_a(.a(a_ab), .b(not_sel1), .y(a));
and2 and_b(.a(b_ab), .b(not_sel1), .y(b));
and2 and_c(.a(c_cd), .b(sel[1]), .y(c));
and2 and_d(.a(d_cd), .b(sel[1]), .y(d));
endmodule  // dmux4way

module dmux8way(
  input wire in,
  input wire [2:0] sel,
  output wire a,
  output wire b,
  output wire c,
  output wire d,
  output wire e,
  output wire f,
  output wire g,
  output wire h
);
wire a_abcd;
wire b_abcd;
wire c_abcd;
wire d_abcd;
wire e_efgh;
wire f_efgh;
wire g_efgh;
wire h_efgh;

dmux4way muxabcd(.in(in), .sel(sel[1:0]), .a(a_abcd), .b(b_abcd), .c(c_abcd), .d(d_abcd));
dmux4way muxefgh(.in(in), .sel(sel[1:0]), .a(e_efgh), .b(f_efgh), .c(g_efgh), .d(h_efgh));

wire not_sel2;
not1 u_notsel(
  .a(sel[2]),
  .y(not_sel2)
);

and2 and_a(.a(a_abcd), .b(not_sel2), .y(a));
and2 and_b(.a(b_abcd), .b(not_sel2), .y(b));
and2 and_c(.a(c_abcd), .b(not_sel2), .y(c));
and2 and_d(.a(d_abcd), .b(not_sel2), .y(d));
and2 and_e(.a(e_efgh), .b(sel[2]), .y(e));
and2 and_f(.a(f_efgh), .b(sel[2]), .y(f));
and2 and_g(.a(g_efgh), .b(sel[2]), .y(g));
and2 and_h(.a(h_efgh), .b(sel[2]), .y(h));
endmodule  // dmux8way
