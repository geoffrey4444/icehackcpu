`default_nettype none

// A 1-bit register
module bit_register(
  input wire clock,
  input wire in,
  input wire load,
  output wire out);
wire mux_out;
// mux selects .b when sel==1
mux u_mux(.a(out), .b(in), .sel(load), .y(mux_out));
dff u_dff(.clock(clock), .in(mux_out), .out(out));
endmodule  // bit

// A 16-bit register
module register16(
  input wire clock,
  input wire [15:0] in,
  input wire load,
  output wire [15:0] out
);
genvar i;
generate
  for (i = 0; i < 16; ++i) begin : gen_bits
    bit_register u_bit_reg(.clock(clock), .in(in[i]), .load(load), .out(out[i]));
  end
endgenerate
endmodule  //register16

// 8x16-bit-register RAM
module ram8(
  input wire clock,
  input wire [15:0] in,
  input wire load,
  input wire [2:0] address,
  output wire [15:0] out
);
wire [7:0] load_n;
wire [15:0] out_0;
wire [15:0] out_1;
wire [15:0] out_2;
wire [15:0] out_3;
wire [15:0] out_4;
wire [15:0] out_5;
wire [15:0] out_6;
wire [15:0] out_7;
dmux8way u_dmux8way(.in(load), 
         .sel(address),
         .a(load_n[0]), 
         .b(load_n[1]),
         .c(load_n[2]),
         .d(load_n[3]),
         .e(load_n[4]),
         .f(load_n[5]),
         .g(load_n[6]),
         .h(load_n[7]));
register16 u_reg0(.clock(clock), .in(in), .load(load_n[0]), .out(out_0));
register16 u_reg1(.clock(clock), .in(in), .load(load_n[1]), .out(out_1));
register16 u_reg2(.clock(clock), .in(in), .load(load_n[2]), .out(out_2));
register16 u_reg3(.clock(clock), .in(in), .load(load_n[3]), .out(out_3));
register16 u_reg4(.clock(clock), .in(in), .load(load_n[4]), .out(out_4));
register16 u_reg5(.clock(clock), .in(in), .load(load_n[5]), .out(out_5));
register16 u_reg6(.clock(clock), .in(in), .load(load_n[6]), .out(out_6));
register16 u_reg7(.clock(clock), .in(in), .load(load_n[7]), .out(out_7));
mux8way16 u_mux_for_out(
  .a(out_0),
  .b(out_1),
  .c(out_2),
  .d(out_3),
  .e(out_4),
  .f(out_5),
  .g(out_6),
  .h(out_7),
  .sel(address),
  .y(out)
);

endmodule  // ram8

module counter16(
  input wire clock,
  input wire[15:0] in,
  input wire increment,
  input wire load,
  input wire reset,
  output wire[15:0] out
);

wire reset_or_increment, load_register;
wire [15:0] input_to_register;
wire [15:0] out_plus_one;
wire [1:0] which_output;
wire not_reset, not_increment, not_load;
wire load_or_not_increment;

or2 u_reset_or_increment(.a(reset), .b(increment), .y(reset_or_increment));
or2 u_load_register(.a(reset_or_increment), .b(load), .y(load_register));

// select which output
// 00 = reset, 01 = load, 10 = inc, 11 = nothing
// bit 1 (left bit): only = 1 when reset = 0 and load = 0
// bit 0 (right bit): only = 1 when reset = 0 and 
// (load=1 or inc=0). 
not1 u_not_reset(.a(reset), .y(not_reset));
not1 u_not_load(.a(load), .y(not_load));
not1 u_not_increment(.a(increment), .y(not_increment));
or2 u_load_or_not_increment(.a(load), .b(not_increment), .y(load_or_not_increment));
and2 u_bit1(.a(not_reset), .b(not_load), .y(which_output[1]));
and2 u_bit0(.a(not_reset), .b(load_or_not_increment), .y(which_output[0]));

// incremented value
inc16 u_out_plus_one(.a(out), .sum(out_plus_one));

mux4way16 u_mux(
  .a(16'b0),
  .b(in),
  .c(out_plus_one),
  .d(16'b1), // should never be used
  .sel(which_output), 
  .y(input_to_register));

register16 u_reg(
  .clock(clock), 
  .in(input_to_register),
  .load(load_register),
  .out(out));
endmodule  // counter16
