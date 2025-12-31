`default_nettype none

module alu(
  input wire [15:0] x,
  input wire [15:0] y,
  input wire zx,
  input wire nx,
  input wire zy,
  input wire ny,
  input wire f,
  input wire no,
  output wire [15:0] out,
  output wire zr,
  output wire ng
);
localparam [15:0] zero = 16'sd0;

// Stage 1a: optionally zero x
wire [15:0] x_stage_1;
mux16 u_x_stage_1(.a(x), .b(zero), .sel(zx), .y(x_stage_1));

// Stage 2a: optionally negate x
wire [15:0] not_x_stage_1;
not16 u_not_x_stage_1(.a(x_stage_1), .y(not_x_stage_1));
wire [15:0] x_stage_2;
mux16 u_x_stage_two(.a(x_stage_1), .b(not_x_stage_1), .sel(nx), .y(x_stage_2));

// Stage 1b: optionally zero y
wire [15:0] y_stage_1;
mux16 u_x_stage_2(.a(y), .b(zero), .sel(zy), .y(y_stage_1));

// Stage 2b: optionally negate y
wire [15:0] not_y_stage_1;
not16 u_not_y_stage_1(.a(y_stage_1), .y(not_y_stage_1));
wire [15:0] y_stage_2;
mux16 u_y_stage_two(.a(y_stage_1), .b(not_y_stage_1), .sel(ny), .y(y_stage_2));

// Stage 3: apply function
wire [15:0] x_plus_y;
add16 u_x_plus_y(.a(x_stage_2), .b(y_stage_2), .sum(x_plus_y));

wire [15:0] x_and_y;
and16 u_x_and_y(.a(x_stage_2), .b(y_stage_2), .y(x_and_y));

wire [15:0] out_stage_3;
mux16 u_out_stage_3(.a(x_and_y), .b(x_plus_y), .sel(f), .y(out_stage_3));

// Stage 4: optionally negate the output
wire [15:0] not_out_stage_3;
not16 u_not_out_stage_3(.a(out_stage_3), .y(not_out_stage_3));

mux16 u_out(.a(out_stage_3), .b(not_out_stage_3), .sel(no), .y(out));

// Zero flag
// True only if all bits of out are zero
wire or_low;
or8way u_or_low(.a(out[7:0]), .y(or_low));

wire or_high;
or8way u_or_high(.a(out[15:8]), .y(or_high));

wire or_all;
or2 u_or_all(.a(or_high), .b(or_low), .y(or_all));
not1 u_not_all(.a(or_all), .y(zr));

// Neg flag: true if output is negative
assign ng = out[15];
endmodule  // alu
