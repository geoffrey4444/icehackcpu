`default_nettype none

module top(
  input wire CLK,
  input wire BTN1,
  input wire BTN2,
  output wire LED1
);

// Logic gates to build and test
wire nand2out;
nand2 gate1(
  .a(BTN1),
  .b(BTN2),
  .y(nand2out)
);

// Clock loop just to dim LEDs (only light 1/8th of the time)
reg [7:0] clk_leds = 0; // 8-bit clock for leds
always @(posedge CLK) begin
  clk_leds <= clk_leds + 1;

  LED1 <= (clk_leds == 0) & nand2out;
end
endmodule  // top

// nand2
module nand2(
  input wire a,
  input wire b,
  output wire y
);
assign y = ~(a & b);
endmodule
