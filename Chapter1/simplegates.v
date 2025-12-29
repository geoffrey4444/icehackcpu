`default_nettype none

module top(
  input wire CLK,
  output wire LEDG_N
);

// Clock loop just to dim LEDs (only light 1/8th of the time)
reg [7:0] clk_leds = 0; // 8-bit clock for leds
always @(posedge CLK) begin
  clk_leds <= clk_leds + 1;

  LEDG_N = clk_leds & 1'b1;
end
endmodule  // top

