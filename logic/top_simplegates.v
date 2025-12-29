`default_nettype none

module top(
  input wire CLK,
  input wire BTN1,
  input wire BTN2,
  input wire BTN3,
  output wire LED1,
  output wire LED2,
  output wire LED3,
  output wire LED4,
  output wire LED5,
);

// Logic gates to build and test
wire nand2out;
nand2 my_nand2_gate(
  .a(BTN1),
  .b(BTN2),
  .y(nand2out)
);

wire not1out;
not1 my_not1_gate(
  .a(BTN1),
  .y(not1out)
);

wire and2out;
and2 my_and2_gate(
  .a(BTN1),
  .b(BTN2),
  .y(and2out)
);

wire or2out;
or2 my_or2_gate(
  .a(BTN1),
  .b(BTN2),
  .y(or2out)
);


wire xor2out;
xor2 my_xor2_gate(
  .a(BTN1),
  .b(BTN2),
  .y(xor2out)
);

// Clock loop just to dim LEDs (only light 1/32nd of the time)
reg [7:0] clk_leds = 0; // 8-bit clock for leds
always @(posedge CLK) begin
  clk_leds <= clk_leds + 1;
end

// Set LED lights
assign LED1 = (clk_leds < 8) & nand2out;
assign LED2 = (clk_leds < 8) & not1out;
assign LED3 = (clk_leds < 8) & and2out;
assign LED4 = (clk_leds < 8) & or2out;
assign LED5 = (clk_leds < 8) & xor2out;
endmodule  // top
