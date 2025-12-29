`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb;
reg a, b, sel, in;
reg [15:0] a16;
reg [15:0] b16;
reg [15:0] y16_not16;
reg [15:0] y16_and16;
reg [15:0] y16_or16;
reg [15:0] y16_mux16;
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
mux16 u_mux16(.a(a16), .b(b16), .y(y16_mux16));

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
    if (y16_mux16 != a16) $fatal;
    sel = 1;
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
  if (y16_mux16 != a16) $fatal;
  sel = 1;
  if (y16_mux16 != b16) $fatal;
end

end
endmodule  // tb
