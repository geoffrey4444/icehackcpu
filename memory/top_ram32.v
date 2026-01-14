`default_nettype none

module top(
  input wire CLK,
  output wire LED1,
  output wire LED2,
  output wire LED3,
  output wire LED4,
  output wire LED5
);

// States
localparam integer START = 0;
localparam integer WRITE_0 = 1;
localparam integer FIRST_CLOCK_AFTER_WRITE_0 = 2;
localparam integer SECOND_CLOCK_AFTER_WRITE_0 = 3;
localparam integer THIRD_CLOCK_AFTER_WRITE_0 = 4;
localparam integer WRITE_1 = 5;
localparam integer FIRST_CLOCK_AFTER_WRITE_1 = 6;
localparam integer SECOND_CLOCK_AFTER_WRITE_1 = 7;
localparam integer THIRD_CLOCK_AFTER_WRITE_1 = 8;
localparam integer READ_2 = 9;
localparam integer FIRST_CLOCK_AFTER_READ_2 = 10;
localparam integer SECOND_CLOCK_AFTER_READ_2 = 11;
localparam integer THIRD_CLOCK_AFTER_READ_2 = 12;
localparam integer DONE = 13;

localparam [15:0] VALUE_0 = 16'd4;
localparam [15:0] VALUE_1 = 16'd44;
localparam [15:0] ADDRESS = 15'd50000;
localparam [15:0] ADDRESS2 = 15'd50001;

// Wires and registers
reg [15:0] state = START;
reg [15:0] rom_in = 16'h0000;
reg [14:0] rom_address = 15'b0;
reg rom_load = 1'b0;
reg [15:0] rom_out;

reg led_1;
reg led_2;
reg led_3;
reg led_4;
reg led_5;

assign LED1 = led_1;
assign LED2 = led_2;
assign LED3 = led_3;
assign LED4 = led_4;
assign LED5 = led_5;

// Parts
ram32k u_rom(
  .clock(CLK),
  .in(rom_in),
  .load(rom_load),
  .address(rom_address),
  .out(rom_out)
);



always @(posedge CLK) begin
  case (state)
    START: begin
      rom_load <= 1'b1;
      rom_in <= VALUE_0;
      rom_address <= ADDRESS;
      state <= WRITE_0;
    end
    WRITE_0: begin
      rom_load <= 1'b0;
      state <= FIRST_CLOCK_AFTER_WRITE_0;      
    end
    FIRST_CLOCK_AFTER_WRITE_0: begin
      state <= SECOND_CLOCK_AFTER_WRITE_0;
    end
    SECOND_CLOCK_AFTER_WRITE_0: begin
      state <= THIRD_CLOCK_AFTER_WRITE_0;
    end
    THIRD_CLOCK_AFTER_WRITE_0: begin
      rom_load <= 1'b1;
      rom_in <= VALUE_1;
      rom_address <= ADDRESS2;
      state <= WRITE_1;
    end
    WRITE_1: begin
      rom_load <= 1'b0;      
      state <= FIRST_CLOCK_AFTER_WRITE_1;      
    end
    FIRST_CLOCK_AFTER_WRITE_1: begin
      state <= SECOND_CLOCK_AFTER_WRITE_1;
      led_1 <= (rom_out == VALUE_0);  // ON
      // led_2 <= (rom_out == VALUE_1);  // OFF
    end
    SECOND_CLOCK_AFTER_WRITE_1: begin
      state <= THIRD_CLOCK_AFTER_WRITE_1;
      // led_3 <= (rom_out == VALUE_0); // OFF
      led_4 <= (rom_out == VALUE_1); // ON
    end
    THIRD_CLOCK_AFTER_WRITE_1: begin
      state <= READ_2;
      rom_address <= ADDRESS;
      led_5 <= (rom_out == VALUE_1); // ON
    end
    READ_2: begin
      state <= FIRST_CLOCK_AFTER_READ_2;
      led_2 <= (rom_out == VALUE_0);
    end
    FIRST_CLOCK_AFTER_READ_2: begin
      state <= SECOND_CLOCK_AFTER_READ_2;
      led_3 <= (rom_out == VALUE_0);
    end
    SECOND_CLOCK_AFTER_READ_2: begin
      state <= THIRD_CLOCK_AFTER_READ_2;
    end
    THIRD_CLOCK_AFTER_READ_2: begin
      state <= DONE;
    end
    DONE: begin
      state <= DONE;
    end
  endcase
end

endmodule  // top