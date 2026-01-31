`default_nettype none

module rgb_led(
  input wire clock,
  input wire reset, // active_low
  input wire [15:0] control_red,
  input wire [15:0] control_grn,
  input wire [15:0] control_blu,
  output reg red, // active low
  output reg grn, // active low
  output reg blu, // active low
  output reg [15:0] status_red,
  output reg [15:0] status_grn,
  output reg [15:0] status_blu
);

// wires and registers
reg [7:0] counter_for_brightness;
wire [7:0] target_brightness_red;
assign target_brightness_red = control_red[8:1];
wire [7:0] target_brightness_grn;
assign target_brightness_grn = control_grn[8:1];
wire [7:0] target_brightness_blu;
assign target_brightness_blu = control_blu[8:1];

// parts

// time dependence
always @(posedge clock) begin
  if (reset == 1'b0) begin
    red <= 1'b1;
    grn <= 1'b1;
    blu <= 1'b1;
    status_red <= 16'b0;
    status_grn <= 16'b0;
    status_blu <= 16'b0;
    counter_for_brightness <= 8'b0;
  end else begin
    // handle red
    if (control_red[0] == 1'b0) begin
      red <= 1'b1;
      status_red <= 16'b0;
    end else begin
      status_red <= 16'b1;
      if (counter_for_brightness < target_brightness_red) begin
        red <= 1'b0;
      end else begin
        red <= 1'b1;
      end
    end

    // handle green
    if (control_grn[0] == 1'b0) begin
      grn <= 1'b1;
      status_grn <= 16'b0;
    end else begin
      status_grn <= 16'b1;
      if (counter_for_brightness < target_brightness_grn) begin
        grn <= 1'b0;
      end else begin
        grn <= 1'b1;
      end
    end

    // handle blue
    if (control_blu[0] == 1'b0) begin
      blu <= 1'b1;
      status_blu <= 16'b0;
    end else begin
      status_blu <= 16'b1;
      if (counter_for_brightness < target_brightness_blu) begin
        blu <= 1'b0;
      end else begin
        blu <= 1'b1;
      end
    end

    // handle counter_for_brightness
    // dim the LEDs by only having them active some of the time
    counter_for_brightness <= counter_for_brightness + 1;
  end
end

endmodule  // rgb_led