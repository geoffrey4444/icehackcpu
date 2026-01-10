`default_nettype none

module top(
  input wire CLK,
  output wire LED1,
  output wire LED2,
  output wire LED3,
  output wire LED4,
  output wire LED5,
  output wire TX
);

// States for my FSM
localparam integer WRITE = 0;
localparam integer FIRST_CLOCK_AFTER_WRITE = 10;
localparam integer SECOND_CLOCK_AFTER_WRITE = 11;
localparam integer THIRD_CLOCK_AFTER_WRITE = 12;
localparam integer FOURTH_CLOCK_AFTER_WRITE = 13;
localparam integer LATCH_TO_LEDs = 2;
localparam integer DONE = 3;

// Wires and registers
wire [15:0] data_to_write = 16'hac58;
wire [13:0] address = 14'h7;
wire [15:0] spram_data_out; // driven by module; don't assign default value

reg [3:0] state = WRITE;
wire write_enable = (state == WRITE);
reg [15:0] data_to_show;  // hold read value

assign LED1 = data_to_show[0];
assign LED2 = data_to_show[1];
assign LED3 = data_to_show[2];
assign LED4 = data_to_show[3];
assign LED5 = data_to_show[4];

reg [7:0] other_byte = 8'b0;
reg [7:0] pending_byte = 8'b0;
reg byte_is_pending = 0;
reg [31:0] bytes_sent = 0;  // big so I can read later on read many bytes
wire baud_clock;  // driven by u_baud_tick
wire valid = byte_is_pending;
wire ready;  // driven by uart_tx

// parts
baud_tick u_baud_tick(.clock(CLK), .tick(baud_clock));

uart_tx u_uart_tx(
  .clock(CLK),
  .baud_tick(baud_clock),
  .byte_to_send(pending_byte),
  .valid(valid),
  .ready(ready),
  .tx(TX)
);

SB_SPRAM256KA spram(
  .CLOCK(CLK),
  .CHIPSELECT(1'b1),
  .WREN(write_enable),
  .ADDRESS(address),
  .DATAIN(data_to_write),
  .MASKWREN(4'b1111), // write all 4 nibbles for the 16-bit value
  .DATAOUT(spram_data_out),
  .STANDBY(1'b0),
  .SLEEP(1'b0),
  .POWEROFF(1'b1)
);

always @(posedge CLK) begin
  case (state)
    WRITE: begin
      data_to_show <= 16'b0;
      state <= FIRST_CLOCK_AFTER_WRITE;
    end
    FIRST_CLOCK_AFTER_WRITE: begin
      // If uncommented below: output byte is 0x00
      // pending_byte <= spram_data_out;
      // byte_is_pending <= 1;       
      state <= SECOND_CLOCK_AFTER_WRITE;
    end
    SECOND_CLOCK_AFTER_WRITE: begin
      // If uncommented below: output byte is 0x58 'X'
      // This means when writing, out is the new byte 2 cycles later
      // pending_byte <= spram_data_out;
      // byte_is_pending <= 1;
      state <= THIRD_CLOCK_AFTER_WRITE;
    end
    THIRD_CLOCK_AFTER_WRITE: begin
      // Read the byte from RAM into another register
      other_byte <= spram_data_out;
      state <= FOURTH_CLOCK_AFTER_WRITE;
    end
    FOURTH_CLOCK_AFTER_WRITE: begin
      // If uncommented below: output byte is 0x58 'X'
      // This means that when reading, out is the new byte 1 cycle later
      pending_byte <= other_byte;
      byte_is_pending <= 1; 
      state <= LATCH_TO_LEDs;
    end
    LATCH_TO_LEDs: begin         
      data_to_show <= spram_data_out;
      state <= DONE; 
    end
    DONE: begin
      byte_is_pending <= 0;
      state <= DONE;
    end
  endcase
end
endmodule  // top
