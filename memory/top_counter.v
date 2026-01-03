`default_nettype none

// Demonstration of module that slow-blinks and LED directly
module top(
  input wire CLK,  
  input wire BTN1,
  input wire BTN2,
  input wire BTN3,
  output wire LED1,
  output wire LED2,
  output wire LED3,
  output wire LED4,
  output wire LED5
);

// Set up slow clock so I can see the effects
localparam integer CLK_FREQ = 12000000;
localparam integer TICK_FREQ = 1;
localparam integer DIV = CLK_FREQ / TICK_FREQ;
reg [31:0] count = 0;
reg slow_clock = 0;

// Set up counter with hard-coded in value
wire [15:0] counter_full_out;
counter16 u_counter(
  .clock(slow_clock),
  .in(16'b100),
  .increment(BTN3),
  .load(BTN2),
  .reset(BTN1),
  .out(counter_full_out)
);

assign LED1 = counter_full_out[0];
assign LED2 = counter_full_out[1];
assign LED3 = counter_full_out[2];
assign LED4 = counter_full_out[3];
assign LED5 = counter_full_out[4];

always @(posedge CLK) begin
if ((count == DIV - 1)) begin
  slow_clock <= ~slow_clock;
  count <= 0;
end else begin
  count <= count + 1;
end
end
endmodule  // top
