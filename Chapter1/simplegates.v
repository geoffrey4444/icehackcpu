`default_nettype none

module top(
  input wire CLK,
  input wire BTN1,
  input wire BTN2,
  output wire LED1,
  output wire LED2
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
  .a(nand2out),
  .y(not1out)
);

// Clock loop just to dim LEDs (only light 1/32nd of the time)
reg [7:0] clk_leds = 0; // 8-bit clock for leds
always @(posedge CLK) begin
  clk_leds <= clk_leds + 1;
end

// Set LED lights
assign LED1 = (clk_leds < 8) & nand2out;
assign LED2 = (clk_leds < 8) & not1out;
endmodule  // top

// nand2
module nand2(
  input wire a,
  input wire b,
  output wire y
);
assign y = ~(a & b);
endmodule

// not1
module not1(
  input wire a,
  output wire y
);
nand2 u_nand2(
  .a(a),
  .b(a),
  .y(y)
);
endmodule
