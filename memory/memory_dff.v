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
