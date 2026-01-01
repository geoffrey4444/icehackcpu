`default_nettype none

// dff: on clock edge, set out to in. Otherwise, out is stable.
module dff(input wire clock, input wire in, output reg out);
always @(posedge clock) begin
  out <= in;
end
endmodule  // dff

