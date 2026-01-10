`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb;

// registers and modules here
reg signed [15:0] x;
reg signed [15:0] y;
reg zx;
reg nx;
reg zy;
reg ny;
reg f;
reg no;
wire signed [15:0] out;
wire zr;
wire ng;

alu u_alu(.x(x), .y(y), .zx(zx), .nx(nx), .zy(zy), .ny(ny), .f(f), .no(no), .out(out), .zr(zr), .ng(ng));

initial begin

repeat (100) begin
  x = $random;
  y = $random;
  zx = 1; nx = 0; zy = 1; ny = 0; f = 1; no = 0;
  #1;
  if (out != 16'sd0 | zr != 1  | ng != 0) $fatal;

  zx = 1; nx = 1; zy = 1; ny = 1; f = 1; no = 1;
  #1;
  if (out != 16'sd1 | zr != 0 | ng != 0) $fatal;

  zx = 1; nx = 1; zy = 1; ny = 0; f = 1; no = 0;
  #1;
  if (out != -16'sd1 | zr != 0 | ng != 1) $fatal;
  
  zx = 0; nx = 0; zy = 1; ny = 1; f = 0; no = 0;
  #1;
  if (out != x | ng != x[15]) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 1; nx = 1; zy = 0; ny = 0; f = 0; no = 0;
  #1;
  if (out != y | ng != y[15]) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 0; nx = 0; zy = 1; ny = 1; f = 0; no = 1;
  #1;
  if (out != ~x | ng != ~x[15]) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 1; nx = 1; zy = 0; ny = 0; f = 0; no = 1;
  #1;
  if (out != ~y | ng != ~y[15]) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 0; nx = 0; zy = 1; ny = 1; f = 1; no = 1;
  #1;
  if (out != -x) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 1; nx = 1; zy = 0; ny = 0; f = 1; no = 1;
  #1;
  if (out != -y) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 0; nx = 1; zy = 1; ny = 1; f = 1; no = 1;
  #1;
  if (out != x + 16'sd1) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 1; nx = 1; zy = 0; ny = 1; f = 1; no = 1;
  #1;
  if (out != y + 16'sd1) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 0; nx = 0; zy = 1; ny = 1; f = 1; no = 0;
  #1;
  if (out != x - 16'sd1) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 1; nx = 1; zy = 0; ny = 0; f = 1; no = 0;
  #1;
  if (out != y - 16'sd1) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 0; nx = 0; zy = 0; ny = 0; f = 1; no = 0;
  #1;
  if (out != x + y) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 0; nx = 1; zy = 0; ny = 0; f = 1; no = 1;
  #1;
  if (out != x - y) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 0; nx = 0; zy = 0; ny = 1; f = 1; no = 1;
  #1;
  if (out != y - x) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;

  zx = 0; nx = 0; zy = 0; ny = 0; f = 0; no = 0;
  #1;
  if (out != (x & y)) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;


  zx = 0; nx = 1; zy = 0; ny = 1; f = 0; no = 1;
  #1;
  if (out != (x | y)) $fatal;
  if (out[15] != ng) $fatal;
  if ((out == 16'sd0 & zr != 1) | (out != 16'sd0 & zr != 0)) $fatal;



end
$display("OK");
end

endmodule  // tb