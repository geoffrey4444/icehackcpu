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

// Receive one byte over serial (uart rx)
module uart_rx(
  input wire clock,
  input wire rx,
  input wire ready,
  output reg [7:0] byte_received = 8'h00,
  output reg valid = 1'b0
);

// Parameters and local parameters
localparam integer IDLE = 0;
localparam integer START = 1;
localparam integer DATA = 2;
localparam integer STOP = 3;
localparam integer HOLD = 4;

parameter CLK_FREQ = 12000000;
parameter BAUD = 115200;
localparam integer DIV = CLK_FREQ / BAUD;
localparam integer HALF_DIV = DIV / 2;
localparam integer COUNTER_SIZE = $clog2(DIV);

// Wires and registers
reg [COUNTER_SIZE-1:0] counter = 0;

reg [3:0] state = IDLE;
reg [7:0] shift = 8'b0;
reg [3:0] bits_read = 4'b0;

reg rx_temp = 1'b1; // start high (no data being received)
reg rx_sync = 1'b1; // pass rx through two flipflops to avoid glitches
reg rx_prev = 1'b1;  // previous state = previous cycles rx_sync

// Time-dependent circuits
always @(posedge clock) begin
  // First, handle events that happen on every clock edge
  // Pass rx through to sync (cost is 2 clock ticks of latency)
  rx_temp <= rx;
  rx_sync <= rx_temp;
  rx_prev <= rx_sync;

  case (state)
    IDLE: begin
      if ((rx_sync == 1'b0) && (rx_prev == 1'b1)) begin
       state <= START;
       // Edge: rx has just gone low
       counter <= 0;
      end
    end
    START: begin
      // Wait HALF_DIV to get to middle of a the start pulse
      if (counter == HALF_DIV - 1) begin
        // Sanity check: unless the low was a glitch, rx should still be low
        if (rx_sync == 1'b1) begin
          // Just a glitch: go back to IDLE
          counter <= 0;
          state <= IDLE;
        end else begin
          // Looks like a real start bit: begin processing
          bits_read <= 4'b0;
          counter <= 0;
          shift <= 8'b0;
          state <= DATA;
        end
      end else begin
        counter <= counter + 1;
      end
      
    end
    DATA: begin
      if (bits_read == 8) begin
        counter <= 0;
        state <= STOP;
      end else if (counter == DIV - 1) begin        
        shift[bits_read] <= rx_sync;
        counter <= 0;
        bits_read <= bits_read + 1;       
      end else begin
        counter <= counter + 1;
      end
    end
    STOP: begin
      if (counter == DIV - 1) begin
        // check for stop bit...should be high
        if (rx_sync == 1'b0) begin
          // frame error: discard read byte
          state <= IDLE;
          counter <= 0;
        end else begin
          valid <= 1'b1;
          byte_received <= shift;
          state <= HOLD;
        end
      end else begin
        counter <= counter + 1;
      end
    end
    HOLD: begin
      if (ready == 1'b1) begin
        valid <= 1'b0;
        counter <= 0;
        state <= IDLE;
      end
    end
  endcase
end

endmodule  // uart_rx
