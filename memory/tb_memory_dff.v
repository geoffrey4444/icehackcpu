`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb_memory_dff;
reg clock = 0; 
reg in = 0;
reg load;
wire out;
reg run_clock = 1;
reg run_clock16 = 1;

reg [15:0] in16;
reg [15:0] out16;
reg load16;

bit_register u_bit(.clock(clock), .in(in), .load(load), .out(out));
register16 u_register16(.clock(clock), .in(in16), .load(load16), .out(out16));

// postedge (clock from 0 to 1) at t=5ns, 15ns, 25ns, ...
initial begin : clock_generate
  while (run_clock | run_clock16) #5 clock = ~clock;
end

// Test bit
initial begin
  clock = 0;
  in = 0;
  load = 0;
  @(posedge clock);
  #1; // advance one "delta order", stay at same time, ensure updates happen
  if (out != 0) $fatal;
  @(negedge clock);
  in = 1;
  load = 1;
  if (out != 0) $fatal;
  @(posedge clock);
  #1;
  if (out != 1'b1) $fatal;
  @(negedge clock);
  load = 0;
  in = 0;
  @(posedge clock);
  #1;
  if (out != 1'b1) $fatal;
  @(posedge clock);
  #1;
  if (out != 1'b1) $fatal;
  @(negedge clock);
  load = 1;
  in = 0;
  @(posedge clock);
  #1;
  if (out != 1'b0) $fatal;
  @(negedge clock);
  load = 0;
  in = 1;
  @(posedge clock);
  #1;
  if (out != 1'b0) $fatal;

  run_clock = 0;
end

// Test register16
initial begin
  in16 = 16'b0;
  load16 = 0;
  #15;
  @(posedge clock);
  #1;
  if (out16 != 16'b0) $fatal;
  @(negedge clock);
  in16 = $random;
  load16 = 1;
  if (out16 != 16'b0) $fatal;
  @(posedge clock);
  #1;
  if (out16 != in16) $fatal;
  @(negedge clock);
  load16 = 0;
  @(posedge clock);
  #1;
  if (out16 != in16) $fatal;
  @(negedge clock);
  in16 = 16'sd3456;
  load16 = 0;
  @(posedge clock);
  #1;
  if (out16 == in16) $fatal;
  @(negedge clock);
  load16 = 1;
  @(posedge clock);
  #1;
  if (out16 != in16) $fatal;

  run_clock16 = 0;
end
endmodule  // tb
