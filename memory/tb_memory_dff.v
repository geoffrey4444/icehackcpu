`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb_memory_dff;
reg clock = 0; 
reg in = 0;
reg load;
wire out;
reg run_clock = 1;
reg run_clock16 = 1;
reg run_clock16_ram8 = 1;

reg [15:0] in16;
reg [15:0] out16;
reg load16;

reg [15:0] in16_ram8;
reg [15:0] out16_ram8;
reg [2:0] address_ram8;
reg load16_ram8;

integer i,j;

bit_register u_bit(.clock(clock), .in(in), .load(load), .out(out));
register16 u_register16(.clock(clock), .in(in16), .load(load16), .out(out16));
ram8 u_ram8(.in(in16_ram8), .address(address_ram8), .load(load16_ram8), .out(out16_ram8));

// postedge (clock from 0 to 1) at t=5ns, 15ns, 25ns, ...
initial begin : clock_generate
  while (run_clock | run_clock16 | run_clock16_ram8) #5 clock = ~clock;
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
  if (in16 == 0) begin
    in16 = 4; // avoid the random value being zero
  end
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
  in16 = in16 / 2;
  load16 = 0;
  @(posedge clock);
  #1;
  if (out16 == in16) $fatal;
  @(negedge clock);
  load16 = 1;
  @(posedge clock);
  #1;
  // "or" case catches the off chace the random value is zero
  if (out16 != in16) $fatal;

  run_clock16 = 0;
end

initial begin
in16_ram8 = 16'b0;
load16_ram8 = 0;
address_ram8 = 3'b0;
#15;

for (i = 0; i < 8; ++i) begin
  @(negedge clock);
  address_ram8 = i[2:0];
  in16_ram8 = $random;
  if (in16_ram8 == 0) begin
    in16_ram8 = 16'h4;
  end
  load16_ram8 = 0;
  if (out16_ram8 != 16'b0) $fatal;
  @(posedge clock);
  #1;
  if (out16_ram8 != 16'b0) $fatal;
  @(negedge clock);
  load16_ram8 = 1;
  @(posedge clock);
  #1;
  @(negedge clock);
  load16_ram8 = 0;
  in16_ram8 = 16'b0;
  @(posedge clock);
  #1;
  // confirm register still set
  if (out16_ram8 == in16_ram8) $fatal;
  @(negedge clock);
  load16_ram8 = 1;
  in16_ram8 = 16'b0;
  @(posedge clock);
  #1;
  #10;
end

// Read test ... store numbers in each address and then 
// make sure I can read each address

for (i = 0; i < 8; ++i) begin
  @(negedge clock);
  load16_ram8 = 1;
  address_ram8 = i[2:0];
  in16_ram8 = 4 * i;
  @(negedge clock);
  load16_ram8 = 0;
  @(posedge clock);
  #1;
end
#10;
@(negedge clock);
load16_ram8 = 0;
@(posedge clock);
#1;

for (i = 0; i < 8; ++i) begin
  @(negedge clock);
  load16_ram8 = 0;
  address_ram8 = i[2:0];
  in16_ram8 = 8 * i;
  @(posedge clock);
  #1;
  if (out16_ram8 != 4 * i) $fatal;
end
run_clock16_ram8 = 0;
end
endmodule  // tb
