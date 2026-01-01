`default_nettype none

// Demonstration of module that slow-blinks and LED directly
module slowblink(input wire clock, output reg out);
localparam integer CLK_FREQ = 12000000;
localparam integer TICK_FREQ = 1;
localparam integer DIV = CLK_FREQ / TICK_FREQ;

reg [31:0] count = 0;
always @(posedge clock) begin
if ((count == 2 * DIV - 1)) begin
  out <= 0;
  count <= 0;
end else if (count == DIV - 1) begin
  out <= 1;
  count <= count + 1;
end else begin
  count <= count + 1;
end
end
endmodule  // slowblink

module top(
  input wire CLK,  
  input wire BTN1,
  output wire LED1,
  output wire LED2,
  output wire LED3
);

// slowblink module
slowblink u_slowblink(.clock(CLK), .out(LED2));

// single dff demo, passing in a slow clock so I can see the effects
localparam integer CLK_FREQ = 12000000;
localparam integer TICK_FREQ = 1;
localparam integer DIV = CLK_FREQ / TICK_FREQ;
reg [31:0] count = 0;
reg slow_clock = 0;
dff u_dff(.clock(slow_clock), .in(BTN1), .out(LED1));

always @(posedge CLK) begin
if ((count == DIV - 1)) begin
  slow_clock <= ~slow_clock;
  count <= 0;
end else begin
  count <= count + 1;
end
end
endmodule  // top
