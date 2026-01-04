`default_nettype none

// Send a pulse for 1 clock-cycle at the baud rate
module baud_tick(
  input wire clock,
  output reg tick = 1'b0
);
parameter CLK_FREQ = 12000000;
parameter BAUD = 115200;
// BAUD does not divide evenly, but the remainder is (1/6)/(104) = 0.1%,
// within tolerance for UART
localparam integer DIV = CLK_FREQ / BAUD;
localparam integer COUNTER_SIZE = $clog2(DIV);

reg [COUNTER_SIZE-1:0] count = 0;
always @(posedge clock) begin
  if ((count == DIV - 1)) begin
    tick <= 1;
    count <= 0;
  end else begin
    tick <= 0;
    count <= count + 1;
  end
end
endmodule  // baud_tick

// Sends one byte over serial (uart tx)
module uart_tx(
  input wire clock,
  input wire baud_tick,
  input wire [7:0] byte_to_send,
  input wire valid,
  output reg ready,
  output reg tx
);
localparam integer IDLE = 0;
localparam integer ARM = 1;
localparam integer START = 2;
localparam integer DATA = 3;
localparam integer STOP = 4;

reg [2:0] state = IDLE;
reg [7:0] shift = 8'b0;
reg [2:0] which_bit_to_send = 3'b0;
wire accept = valid && ready;
always @(posedge clock) begin
  case (state)
    IDLE: begin
      ready <= 1;
      tx <= 1;      
      if (accept) begin
        state <= ARM;
        ready <= 0;
        shift <= byte_to_send;
      end
    end
    // ARM: wait until baud tick, so everything lines up
    // with baud ticks while sending bytes
    ARM: begin
      tx <= 1;
      ready <= 0;
      if (baud_tick == 1) begin
        state <= START;
      end
    end
    // START: in this state, emit the start bit for one baud tick.
    // Since prev state (ARM) guarantees START begins on a baud tick,
    // just emit until the next baud_tick.
    START: begin
      tx <= 0; // start bit
      ready <= 0;
      if (baud_tick == 1) begin
        state <= DATA; 
        which_bit_to_send <= 0;      
      end
    end
    DATA: begin
      ready <= 0;

      // I could do 
      // tx <= shift[which_bit_to_send];
      // But shifting and always sending bit 0 is the canonical way
      // ... maybe realizes as simpler hardware, even though if software
      // these would be the same.
      tx <= shift[0];
      
      // Send for 1 baud tick. So on each baud tick, either send the next
      // bit, or if all bits have been sent (including the stop bit),
      // go back to IDLE state.
      if (baud_tick == 1) begin
        if (which_bit_to_send == 3'b111) begin
          state <= STOP;          
        end else begin
          shift <= {1'b0, shift[7:1]}; // shift right
          which_bit_to_send <= which_bit_to_send + 1;
        end
      end
    end
    STOP: begin
      ready <= 0;
      tx <= 1; // stop bit
      if (baud_tick == 1) begin
        state <= IDLE;
      end
    end
  endcase
end
endmodule  // uart_tx
