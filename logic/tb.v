`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb;
reg a, b;
wire y_nand, y_not, y_and, y_or, y_xor;

nand2 u_nand2(.a(a), .b(b), .y(y_nand));
not1 u_not1(.a(a), .y(y_not));
and2 u_and2(.a(a), .b(b), .y(y_and));
or2 u_or2(.a(a), .b(b), .y(y_or));
xor2 u_xor2(.a(a), .b(b), .y(y_xor));

initial begin // run once at simulation starting
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

end
endmodule  // tb
