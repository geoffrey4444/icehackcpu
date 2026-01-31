`default_nettype none

module top(
  input wire CLK,  
  input wire BTN_N,
  input wire BTN1,
  input wire BTN2,
  input wire BTN3,
  output wire LED_RED_N,
  output wire LED_GRN_N,
  output wire LED_BLU_N,
  output reg LED2,
  output reg LED3,
  output reg LED4
);
// constants
localparam integer CLOCK_FREQ = 12000000;
localparam integer DIV = CLOCK_FREQ / 100;

// wires and registers
reg [15:0] control_red = 16'h0000;
reg [15:0] control_grn = 16'h0000;
reg [15:0] control_blu = 16'h0000;

reg [15:0] status_red;
reg [15:0] status_grn;
reg [15:0] status_blu;

reg [7:0] counter_for_brightness = 0;
reg [31:0] counter_for_slow_clock = 0;

reg prev_BTN1 = 1'b0;
reg prev_BTN2 = 1'b0;
reg prev_BTN3 = 1'b0;
reg prev_BTN_N = 1'b1;

// parts
rgb_led u_rgb_led(
  .clock(CLK),
  .reset(BTN_N),
  .control_red(control_red),
  .control_grn(control_grn),
  .control_blu(control_blu),
  .red(LED_RED_N), // _N means "negative", i.e. active_low
  .grn(LED_GRN_N),
  .blu(LED_BLU_N),
  .status_red(status_red),
  .status_grn(status_grn),
  .status_blu(status_blu)  
);


// time dependence
always @(posedge CLK) begin
  if (counter_for_slow_clock == DIV) begin
    counter_for_slow_clock <= 0;
    if (BTN1 == 1'b1 && prev_BTN1 == 1'b0) begin
      if (control_red == 16'h0000) begin
        control_red <= control_red + 8'd33;
        status_red <= 16'b1;
      end else if (control_red < 16'd257) begin
        control_red <= control_red + 8'd32;
        status_red <= 16'b1;
      end else begin
        control_red <= 16'd0;
        status_red <= 16'b0;
      end
    end

    if (BTN2 == 1'b1 && prev_BTN2 == 1'b0) begin
      if (control_grn == 16'h0000) begin
        control_grn <= control_grn + 8'd33;
        status_grn <= 16'b1;
      end else if (control_grn < 16'd257) begin
        control_grn <= control_grn + 8'd32;
        status_grn <= 16'b1;
      end else begin
        control_grn <= 16'd0;
        status_grn <= 16'b0;
      end
    end

    if (BTN3 == 1'b1 && prev_BTN3 == 1'b0) begin
      if (control_blu == 16'h0000) begin
        control_blu <= control_blu + 8'd33;
        status_blu <= 16'b1;
      end else if (control_blu < 16'd257) begin
        control_blu <= control_blu + 8'd32;
        status_blu <= 16'b1;
      end else begin
        control_blu <= 16'd0;
        status_blu <= 16'b0;
      end
    end

    // counter       
    prev_BTN1 <= BTN1;
    prev_BTN2 <= BTN2;
    prev_BTN3 <= BTN3;
    
  end else begin
    counter_for_slow_clock <= counter_for_slow_clock + 1;
  end

  if (counter_for_brightness > 224) begin
    LED2 <= control_red[0];
    LED3 <= control_grn[0];
    LED4 <= control_blu[0];
  end else begin
    LED2 <= 0;
    LED3 <= 0;
    LED4 <= 0;
  end 
  counter_for_brightness <= counter_for_brightness + 1;  
end

endmodule  // top
