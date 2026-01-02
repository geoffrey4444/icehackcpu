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
