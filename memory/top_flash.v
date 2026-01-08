`default_nettype none

module top(
  input wire CLK,
  input wire FLASH_IO1,  // receive bits from flash
  output reg FLASH_SCK, // clock for flash ops
  output reg FLASH_SSB, // set low to start a flash conversation
  output reg FLASH_IO0, // send bits to flash,
  output wire FLASH_IO2, // /WP unused, hold high
  output wire FLASH_IO3, // /HOLD unused, hold high
  output wire TX,        // send bits to uart tx output
);
// States for FSM to read and echo bytes from flash
localparam integer START = 0;
localparam integer RESET_FLASH_PART_1 = 1;
localparam integer RESET_FLASH_PART_2 = 2;
localparam integer WAIT_AFTER_FLASH_RESET = 3;
localparam integer START_FLASH_READ = 4;
localparam integer SEND_FLASH_READ_COMMAND = 5;
localparam integer SEND_FLASH_ADDRESS = 6;
localparam integer READ_FLASH_BYTE = 7;
localparam integer END_FLASH_READ = 8;
localparam integer START_UART_SEND = 9;
localparam integer SEND_UART = 10;
localparam integer END_UART_SEND = 11;
localparam integer STOP = 12;

// States for sending bits to the flash controller
localparam integer SENDFLASH_SELECT = 100;
localparam integer SENDFLASH_START_SCK = 101;
localparam integer SENDFLASH_SEND_BITS = 102;
localparam integer SENDFLASH_STOP_SCK = 103;
localparam integer SENDFLASH_UNSELECT = 104;
localparam integer FLASH_DEBUG = 201;

// Other constants
localparam integer TICKS_PER_FLASH_CLOCK_TOGGLE = 8;

localparam [7:0] RESET_COMMAND_1 = 8'h66;
localparam [7:0] RESET_COMMAND_2 = 8'h99;
localparam [7:0] TICKS_TO_WAIT_AFTER_RESET = 400;
localparam [7:0] READ_COMMAND = 8'h3;
localparam [23:0] READ_OFFSET = 24'h100000;

localparam [31:0] BYTES_TO_READ = 32'h4;

// Wires and registers
reg [15:0] state = START;
reg [15:0] sendflash_state = SENDFLASH_SELECT;
reg [15:0] sendflash_wait_counter = 16'b0;

reg flash_reader_is_active = 1'b0;
reg [7:0] divider_counter = 8'b0;
reg flash_clock_rise = 1'b0;
reg flash_clock_fall = 1'b0;
reg [7:0] command_to_send = RESET_COMMAND_1;
reg [23:0] flash_offset_address = READ_OFFSET;
reg [23:0] flash_address = 24'b0;  // reset to offset address before each use
reg [7:0] byte_read_from_flash = 8'b0;
reg [23:0] bits_sent_to_flash = 24'b0;
reg [4:0] bits_read_from_flash = 5'b0;

reg [7:0] pending_byte = 8'b0;
reg byte_is_pending = 0;
reg [31:0] bytes_sent = 0;  // big so I can read later on read many bytes

wire flash_sck_toggle = flash_reader_is_active && 
                        (divider_counter == TICKS_PER_FLASH_CLOCK_TOGGLE - 1);

wire baud_clock;  // driven by u_baud_tick
wire valid = byte_is_pending;
wire ready;  // driven by uart_tx

assign FLASH_IO2 = 1'b1;
assign FLASH_IO3 = 1'b1;

// Parts
baud_tick u_baud_tick(.clock(CLK), .tick(baud_clock));

uart_tx u_uart_tx(
  .clock(CLK),
  .baud_tick(baud_clock),
  .byte_to_send(pending_byte),
  .valid(valid),
  .ready(ready),
  .tx(TX)
);

// Time logic
always @(posedge CLK) begin
  // Time logic
  // First,  rise and fall 0 by default, will be zero, except they can be 1 
  // next cycle if we set them this cycle
  flash_clock_rise <= 1'b0;
  flash_clock_fall <= 1'b0;
  if (!flash_reader_is_active) begin
    FLASH_SCK <= 1'b0;  // hold flash clock at 0 when inactie (not reading bits)
    FLASH_IO0 <= 0;     // write bit should be ignored, but set to zero anyway
    divider_counter <= 0;  // ready to start new cycle when reader next active
  end else begin    
    // figure out if the next toggle is a rise or a fall
    // the idea is to cleanly separate sends to flash and reads from flash
    if (flash_sck_toggle) begin
      divider_counter <= 0;
      if (FLASH_SCK == 1'b0) begin
        flash_clock_rise <= 1'b1;
      end else begin
        flash_clock_fall <= 1'b1;
      end
      FLASH_SCK <= ~FLASH_SCK; // toggle the clock
    end else begin
      divider_counter <= divider_counter + 1;
    end
  end

  // Actions depending on state
  case (state)
    START: begin
      FLASH_SSB <= 1;
      flash_reader_is_active <= 0;
      byte_is_pending <= 0;
      bytes_sent <= 0;      
      sendflash_state <= SENDFLASH_SELECT;
      state <= RESET_FLASH_PART_1;
    end
    RESET_FLASH_PART_1: begin
      case (sendflash_state)
        SENDFLASH_SELECT: begin
          FLASH_SSB <= 1'b0; // FLASH_SSB is active low
          bits_sent_to_flash <= 0;
          command_to_send <= RESET_COMMAND_1;          
          sendflash_state <= SENDFLASH_START_SCK;
        end
        SENDFLASH_START_SCK: begin
          flash_reader_is_active <= 1'b1;
          FLASH_IO0 <= command_to_send[7];  // preload first byte
          sendflash_state <= SENDFLASH_SEND_BITS;
        end
        SENDFLASH_SEND_BITS: begin
          if (flash_clock_fall) begin
            FLASH_IO0 <= command_to_send[7]; // send MSB (next bit)
            command_to_send <= {command_to_send[6:0], 1'b0}; // shift left
          end
          // count bits on rise
          if (flash_clock_rise) begin
            if (bits_sent_to_flash == 7) begin
              // last bit sent
              bits_sent_to_flash <= 0;
              command_to_send <= RESET_COMMAND_2;
              sendflash_state <= SENDFLASH_STOP_SCK;
            end else begin
              bits_sent_to_flash <= bits_sent_to_flash + 1;
            end
          end
        end
        SENDFLASH_STOP_SCK: begin
          flash_reader_is_active <= 1'b0;
          sendflash_state <= SENDFLASH_UNSELECT;
        end
        SENDFLASH_UNSELECT: begin
          FLASH_SSB <= 1'b1;
          sendflash_state <= SENDFLASH_SELECT;
          state <= RESET_FLASH_PART_2;
        end
      endcase 
    end
    RESET_FLASH_PART_2: begin
      case (sendflash_state)
        SENDFLASH_SELECT: begin
          FLASH_SSB <= 1'b0; // FLASH_SSB is active low
          bits_sent_to_flash <= 0;
          command_to_send <= RESET_COMMAND_2;
          sendflash_state <= SENDFLASH_START_SCK;
        end
        SENDFLASH_START_SCK: begin
          flash_reader_is_active <= 1'b1;
          FLASH_IO0 <= command_to_send[7];  // preload next bit
          sendflash_state <= SENDFLASH_SEND_BITS;
        end
        SENDFLASH_SEND_BITS: begin
          if (flash_clock_fall) begin
            FLASH_IO0 <= command_to_send[7]; // send next bit (MSB)
            command_to_send <= {command_to_send[6:0], 1'b0}; // shift left
          end
          // count bits on rise
          if (flash_clock_rise) begin
            if (bits_sent_to_flash == 7) begin
              // last bit sent
              bits_sent_to_flash <= 0;
              command_to_send <= READ_COMMAND;
              FLASH_IO0 <= command_to_send[7]; // preload first (MSB) bit
              sendflash_state <= SENDFLASH_STOP_SCK;
            end else begin
              bits_sent_to_flash <= bits_sent_to_flash + 1;
            end
          end
        end
        SENDFLASH_STOP_SCK: begin
          flash_reader_is_active <= 1'b0;
          sendflash_state <= SENDFLASH_UNSELECT;
        end
        SENDFLASH_UNSELECT: begin
          FLASH_SSB <= 1'b1;
          sendflash_state <= SENDFLASH_SELECT;
          state <= WAIT_AFTER_FLASH_RESET;
        end
      endcase 
    end
    WAIT_AFTER_FLASH_RESET: begin
      // to-do: just wait
      if (sendflash_wait_counter == 400) begin
        sendflash_wait_counter <= 16'b0;
        state <= START_FLASH_READ;
      end else begin
        sendflash_wait_counter <= sendflash_wait_counter + 1;
      end
    end
    START_FLASH_READ: begin
      FLASH_SSB <= 1'b0; // should be low until done reading bits
      flash_reader_is_active <= 1;  
      bits_sent_to_flash <= 0;
      bits_read_from_flash <= 0;
      flash_address <= flash_offset_address; 
      command_to_send <= READ_COMMAND;
      FLASH_IO0 <= READ_COMMAND[7]; // preload MSB for first read
      state <= SEND_FLASH_READ_COMMAND;
    end
    SEND_FLASH_READ_COMMAND: begin
      // After rising edge, flash has latched the current FLASH_IO0 bit
      if (flash_clock_rise) begin
        if (bits_sent_to_flash == 7) begin
          // last bit sent
          bits_sent_to_flash <= 0;
          command_to_send <= READ_COMMAND; // reset in case used again
          state <= SEND_FLASH_ADDRESS;
        end else begin
          bits_sent_to_flash <= bits_sent_to_flash + 1;
        end
      end

      // After falling edge, prepare next bit      
      if (flash_clock_fall) begin
        // Set next bit, so it's ready to latch on next rise
        FLASH_IO0 <= command_to_send[6]; // send MSB
        command_to_send <= {command_to_send[6:0], 1'b0}; // shift left        
      end       
    end
    SEND_FLASH_ADDRESS: begin      
      if (flash_clock_fall) begin
        FLASH_IO0 <= flash_address[23];
        flash_address <= {flash_address[22:0], 1'b0}; // shift left
      end

      // Count bits on rises (flash latches address on rise)
      if (flash_clock_rise) begin
        if (bits_sent_to_flash == 23) begin
          // Last bit sent
          bits_sent_to_flash <= 0;
          FLASH_IO0 <= 0;  // zero input to flash: unused after this state exits
          bits_read_from_flash <= 0;
          byte_read_from_flash <= 0;
          flash_address <= flash_offset_address;  // reset in case using again
          state <= READ_FLASH_BYTE;
        end else begin
          bits_sent_to_flash <= bits_sent_to_flash + 1;
        end
      end
    end
    READ_FLASH_BYTE: begin   
      // DO shifts on fall   
      if (flash_clock_fall) begin
        byte_read_from_flash <= {byte_read_from_flash[6:0], FLASH_IO1};
        if (bits_read_from_flash == 7) begin
          // last bit of the byte has been read
          bits_read_from_flash <= 0;
          state <= END_FLASH_READ;
        end else begin
          bits_read_from_flash <= bits_read_from_flash + 1;
        end
      end
    end
    END_FLASH_READ: begin
      flash_reader_is_active <= 0; // hold flash clock during uart tx
      state <= START_UART_SEND;
    end
    START_UART_SEND: begin
      // If no pending byte, set pending byte until ready
      if (!byte_is_pending) begin
        if (ready) begin
          pending_byte <= byte_read_from_flash;
          byte_is_pending <= 1;
        end
      end else begin
        // now have a pending byte, wait for ready as well to accept
        if (ready) begin
          // accept happens this cycle
          byte_is_pending <= 1'b0;          
          state <= SEND_UART;
        end
      end
    end
    SEND_UART: begin
      // Just wait in this state until uart says ready again, which is after
      // the byte has been written.
      if (ready) begin                   
        bytes_sent <= bytes_sent + 1;
        state <= END_UART_SEND;
      end
    end
    END_UART_SEND: begin
      if (bytes_sent == BYTES_TO_READ) begin
        // We have read all of the bytes requested; we're done      
        state <= STOP;
      end else begin
        // need to read another byte
        flash_reader_is_active <= 1;  // resume flash clock
        state <= READ_FLASH_BYTE;
      end
    end
    STOP: begin
      FLASH_SSB <= 1'b1; // we are done using flash (SSB==0 when using, 1 when not)
      flash_reader_is_active <= 0;
      state <= STOP;  // infinite loop in final state
    end
  endcase
end
endmodule  // top
