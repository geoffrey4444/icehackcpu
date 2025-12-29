`default_nettype none

module top(
  input wire CLK,
  input wire BTN1,
  input wire BTN2,
  input wire BTN3,
  output wire LED1,
  output wire LED2,
  output wire LED3,
);

// Logic gates to build and test
wire mux_out;
mux my_mux_gate(
  .a(BTN1),
  .b(BTN2),
  .sel(BTN3),
  .y(mux_out)
);

wire a_out;
wire b_out;
dmux my_dmux_gate(
  .in(BTN1),
  .sel(BTN3),
  .a(a_out),
  .b(b_out)
);

// Clock loop just to dim LEDs (only light 1/32nd of the time)
reg [7:0] clk_leds = 0; // 8-bit clock for leds
always @(posedge CLK) begin
  clk_leds <= clk_leds + 1;
end

// Set LED lights
assign LED1 = (clk_leds < 8) & mux_out;
assign LED2 = (clk_leds < 8) & a_out;
assign LED3 = (clk_leds < 8) & b_out;

endmodule  // top
