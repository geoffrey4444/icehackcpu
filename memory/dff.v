`default_nettype none

// dff: on clock edge, set out to in. Otherwise, out is stable.
module dff(input wire clock, input wire in, output reg out);
always @(posedge clock) begin
  out <= in;
end
endmodule  // dff

// pedagogical: build up an equivalent dff from gates
// behavior: set q=1 when not_set = 0; set q=0 when not_reset=0;
//           hold value when not_set = not_reset = 1
module latch_for_learning(
  input wire not_set,
  input wire not_reset,
  output wire q
);
wire not_q; // not an output wire because I only care about q
nand2 u_nand2_s(.a(not_set), .b(not_q), .y(q));
nand2 u_nand2_r(.a(q), .b(not_reset), .y(not_q));
endmodule  // latch_for_learning

// pedagogical: d-latch
// inputs: d, en
// output: q
// Use a latch, but this time we want the following behavior:
// when EN=1: q tracks d; when EN=0, q holds its previous value
//
// So we want not_set = not_reset = 1 (hold) when EN=0.
// When EN=1, we want 1 if d is 1 and 0 if d is 0, so we want
// not_set to be zero if d is 1, and not_reset to be zero if d is 0.
//
// Solution: 
//   not_set = ~(d & en) ... 0 only if d & en = 1, so en = 1 and d = 1
//   not_reset = ~(~d & en) ... 0 only if en=1 and d=0 (so ~d=1).
// Note: if en=0, not_set = not_reset=1
// Also not: ~(A & B) = NOT(A AND B) = NAND(A AND B)
module d_latch_for_learning(
  input wire d, 
  input wire en, 
  output wire q
);
wire not_d;
wire not_set;
wire not_reset;
not1 u_not_d(.a(d), .y(not_d));
nand2 u_nand_for_not_set(.a(d), .b(en), .y(not_set));
nand2 u_nand_for_not_reset(.a(not_d), .b(en), .y(not_reset));
latch_for_learning u_latch(.not_set(not_set), .not_reset(not_reset), .q(q));
endmodule  // d_latch_for_learning

// pedagogical dff
// Do not use this at scale or for anything except learning.
// Will not work on the physical icebreaker fpga board.
// For anything real, use dff.
module dff_for_learning(
  input wire clock,
  input wire in,
  output wire out
);
wire not_clock;
wire out_latch_1;

not1 u_not_clock(.a(clock), .y(not_clock));
d_latch_for_learning u_latch_1(.d(in), .en(not_clock), .q(out_latch_1));
d_latch_for_learning u_latch_2(.d(out_latch_1), .en(clock), .q(out));
endmodule  // dff_for_learning
