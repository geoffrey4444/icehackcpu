`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb;
reg a, b, sel, in;
reg aaa, bbb, ccc, ddd;
reg aaaa, bbbb, cccc, dddd, eeee, ffff, gggg, hhhh;
integer aa, bb, cc, dd, ee, ff, gg, hh;
reg [15:0] a16;
reg [15:0] b16;
reg [15:0] c16;
reg [15:0] d16;
reg [15:0] e16;
reg [15:0] f16;
reg [15:0] g16;
reg [15:0] h16;
reg [15:0] y16_not16;
reg [15:0] y16_and16;
reg [15:0] y16_or16;
reg [15:0] y16_mux16;
reg [15:0] y16_mux4way16;
reg [15:0] y16_mux8way16;
integer s;
reg [1:0] sel2;
reg [2:0] sel3;
reg y_or8way;
integer i;
integer j;
reg [15:0] test_16bit_values [17:0];
reg [4:0] bi;
wire y_nand, y_not, y_and, y_or, y_xor, y_mux;
wire a_out, b_out;

nand2 u_nand2(.a(a), .b(b), .y(y_nand));
not1 u_not1(.a(a), .y(y_not));
and2 u_and2(.a(a), .b(b), .y(y_and));
or2 u_or2(.a(a), .b(b), .y(y_or));
xor2 u_xor2(.a(a), .b(b), .y(y_xor));
mux u_mux(.a(a), .b(b), .sel(sel), .y(y_mux));
dmux u_dmux(.in(in), .sel(sel), .a(a_out), .b(b_out));

// Multibit
not16 u_not16(.a(a16), .y(y16_not16));
and16 u_and16(.a(a16), .b(b16), .y(y16_and16));
or16 u_or16(.a(a16), .b(b16), .y(y16_or16));
mux16 u_mux16(.a(a16), .b(b16), .sel(sel), .y(y16_mux16));

// Multiway
or8way u_or8way(.a(a16[7:0]), .y(y_or8way));
mux4way16 u_mux4way16(.a(a16), .b(b16), .c(c16), .d(d16), .sel(sel2), .y(y16_mux4way16));
mux8way16 u_mux8way16(.a(a16), .b(b16), .c(c16), .d(d16), .e(e16), .f(f16), .g(g16), .h(h16), .sel(sel3), .y(y16_mux8way16));
dmux4way u_dmux4way(.in(in), .sel(sel2), .a(aaa), .b(bbb), .c(ccc), .d(ddd));
dmux8way u_dmux8way(.in(in), .sel(sel3), .a(aaaa), .b(bbbb), .c(cccc), .d(dddd), .e(eeee), .f(ffff), .g(gggg), .h(hhhh));

initial begin // run once at simulation starting

// Test basic gates
a = 0; b = 0; #1;
if (y_nand != 1) $fatal;
if (y_not != 1) $fatal;
if (y_and != 0) $fatal;
if (y_or != 0) $fatal;
if (y_xor != 0) $fatal;

a = 0; b = 1; #1;
if (y_nand != 1) $fatal;
if (y_and != 0) $fatal;
if (y_or != 1) $fatal;
if (y_xor != 1) $fatal;

a = 1; b = 0; #1;
if (y_nand != 1) $fatal;
if (y_not != 0) $fatal;
if (y_and != 0) $fatal;
if (y_or != 1) $fatal;
if (y_xor != 1) $fatal;

a = 1; b = 1; #1;
if (y_nand != 0) $fatal;
if (y_and != 1) $fatal;
if (y_or != 1) $fatal;
if (y_xor != 0) $fatal;

// mux
a = 0; b = 0; sel = 0; #1;
if (y_mux != 0) $fatal;
a = 0; b = 1; sel = 0; #1;
if (y_mux != 0) $fatal;
a = 1; b = 0; sel = 0; #1;
if (y_mux != 1) $fatal;
a = 1; b = 1; sel = 0; #1;
if (y_mux != 1) $fatal;
a = 0; b = 0; sel = 1; #1;
if (y_mux != 0) $fatal;
a = 0; b = 1; sel = 1; #1;
if (y_mux != 1) $fatal;
a = 1; b = 0; sel = 1; #1;
if (y_mux != 0) $fatal;
a = 1; b = 1; sel = 1; #1;
if (y_mux != 1) $fatal;

// dmux
sel = 0; in = 0; #1;
if (a_out != 0 | b_out != 0) $fatal;

sel = 0; in = 1; #1;
if (a_out != 1 | b_out != 0) $fatal;

sel = 1; in = 0; #1;
if (a_out != 0 | b_out != 0) $fatal;

sel = 1; in = 1; #1;
if (a_out != 0 | b_out != 1) $fatal;

// Multibit gates
// test values designed to catch corner cases
// by codex
test_16bit_values[0]  = 16'h0000;
test_16bit_values[1]  = 16'hFFFF;
test_16bit_values[2]  = 16'h0001;
test_16bit_values[3]  = 16'h8000;
test_16bit_values[4]  = 16'h7FFF;
test_16bit_values[5]  = 16'h00FF;
test_16bit_values[6]  = 16'hFF00;
test_16bit_values[7]  = 16'h0F0F;
test_16bit_values[8]  = 16'hF0F0;
test_16bit_values[9]  = 16'h3333;
test_16bit_values[10] = 16'hCCCC;
test_16bit_values[11] = 16'hAAAA;
test_16bit_values[12] = 16'h5555;
test_16bit_values[13] = 16'h1234;
test_16bit_values[14] = 16'hFEDC;
test_16bit_values[15] = 16'h00F0;
test_16bit_values[16] = 16'h0F00;
test_16bit_values[17] = 16'h1357;

// Test special values
for (i = 0; i < 18; ++i) begin
  a16 = test_16bit_values[i];
  #1;
  if (y16_not16 != ~a16) $fatal;
  for (j = 0; j < 18; ++j) begin
    b16 = test_16bit_values[j];
    #1;    
    if (y16_and16 != (a16 & b16)) $fatal;
    if (y16_or16 != (a16 | b16)) $fatal;

    sel = 0;
    #1;
    if (y16_mux16 != a16) $fatal;
    sel = 1;
    #1;
    if (y16_mux16 != b16) $fatal;
  end
end

// Test some random values
repeat (1000) begin
  a16  = $random;
  b16 = $random;
  #1;
  if (y16_not16 != ~a16) $fatal;
  if (y16_and16 != (a16 & b16)) $fatal;
  if (y16_or16 != (a16 | b16)) $fatal;
  
  sel = 0;
  #1;
  if (y16_mux16 != a16) $fatal;
  sel = 1;
  #1;
  if (y16_mux16 != b16) $fatal;

  if (y_or8way != |(a16[7:0])) $fatal;
end

// test 4-way mux with some random values
repeat (1000) begin
  a16 = $random;
  b16 = $random;
  c16 = $random;
  d16 = $random;
  e16 = $random;
  f16 = $random;
  g16 = $random;
  h16 = $random;
  for (s = 0; s < 8; ++s) begin
    sel2 = s[1:0];
    sel3 = s[2:0];
    #1;
    if (s < 4) begin
      if ((sel2 == 2'b0) & (y16_mux4way16 != a16)) $fatal;
      if ((sel2 == 2'b1) & (y16_mux4way16 != b16)) $fatal;
      if ((sel2 == 2'b10) & (y16_mux4way16 != c16)) $fatal;
      if ((sel2 == 2'b11) & (y16_mux4way16 != d16)) $fatal;
    end
    if ((sel3 == 3'b0) & (y16_mux8way16 != a16)) $fatal;
    if ((sel3 == 3'b1) & (y16_mux8way16 != b16)) $fatal;
    if ((sel3 == 3'b10) & (y16_mux8way16 != c16)) $fatal;
    if ((sel3 == 3'b11) & (y16_mux8way16 != d16)) $fatal;
    if ((sel3 == 3'b100) & (y16_mux8way16 != e16)) $fatal;
    if ((sel3 == 3'b101) & (y16_mux8way16 != f16)) $fatal;
    if ((sel3 == 3'b110) & (y16_mux8way16 != g16)) $fatal;
    if ((sel3 == 3'b111) & (y16_mux8way16 != h16)) $fatal;
  end
end

// Test multi-way dmux
for (j=0; j < 2; ++j) begin
  in = j;
  for (s = 0; s < 8; ++s) begin
    sel2 = s[1:0];
    sel3 = s[2:0];
    #1;
    if (s < 4) begin
      if ((sel2 == 2'b00) & ((aaa != in) | (bbb != 0) | (ccc != 0) | (ddd != 0) )) $fatal;
      if ((sel2 == 2'b01) & ((aaa != 0) | (bbb != in) | (ccc != 0) | (ddd != 0) )) $fatal;
      if ((sel2 == 2'b10) & ((aaa != 0) | (bbb != 0) | (ccc != in) | (ddd != 0) )) $fatal;
      if ((sel2 == 2'b11) & ((aaa != 0) | (bbb != 0) | (ccc != 0) | (ddd != in) )) $fatal;
    end
    if ((sel3 == 3'b000) & ((aaaa != in) | (bbbb != 0) | (cccc != 0) | (dddd != 0) | (eeee != 0) | (ffff != 0) | (gggg != 000) | (hhhh != 000) )) $fatal;
    if ((sel3 == 3'b001) & ((aaaa != 0) | (bbbb != in) | (cccc != 0) | (dddd != 0) | (eeee != 0) | (ffff != 0) | (gggg != 000) | (hhhh != 000) )) $fatal;
    if ((sel3 == 3'b010) & ((aaaa != 0) | (bbbb != 0) | (cccc != in) | (dddd != 0) | (eeee != 0) | (ffff != 0) | (gggg != 000) | (hhhh != 000) )) $fatal;
    if ((sel3 == 3'b011) & ((aaaa != 0) | (bbbb != 0) | (cccc != 0) | (dddd != in) | (eeee != 0) | (ffff != 0) | (gggg != 000) | (hhhh != 000) )) $fatal;
    if ((sel3 == 3'b100) & ((aaaa != 0) | (bbbb != 0) | (cccc != 0) | (dddd != 0) | (eeee != in) | (ffff != 0) | (gggg != 000) | (hhhh != 000) )) $fatal;
    if ((sel3 == 3'b101) & ((aaaa != 0) | (bbbb != 0) | (cccc != 0) | (dddd != 0) | (eeee != 0) | (ffff != in) | (gggg != 000) | (hhhh != 000) )) $fatal;
    if ((sel3 == 3'b110) & ((aaaa != 0) | (bbbb != 0) | (cccc != 0) | (dddd != 0) | (eeee != 0) | (ffff != 0) | (gggg != in) | (hhhh != 000) )) $fatal;
    if ((sel3 == 3'b111) & ((aaaa != 0) | (bbbb != 0) | (cccc != 0) | (dddd != 0) | (eeee != 0) | (ffff != 0) | (gggg != 000) | (hhhh != in) )) $fatal;
  end
end

end
endmodule  // tb
