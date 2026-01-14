`default_nettype none

module top(
  input wire CLK,             // System clock (12 MHz)
  input wire FLASH_IO1,       // Receive bits from flash storage
  output reg FLASH_SCK,       // Clock for flash storage
  output reg FLASH_SSB,       // Set low to start a flash conversation
  output reg FLASH_IO0,       // Send bits to flash storage
  output wire FLASH_IO2,      // /WP unused, hold high
  output wire FLASH_IO3,      // /HOLD unused, hold high
  output wire TX,             // Send bits to UART transmitter
);
// Top-level state machine states
localparam integer START = 0;

localparam integer RESET_FLASH_PART_1 = 1;
localparam integer RESET_FLASH_PART_2 = 2;
localparam integer WAIT_AFTER_FLASH_RESET = 3;
localparam integer START_FLASH_READ = 4;
localparam integer SEND_FLASH_READ_COMMAND = 5;
localparam integer SEND_FLASH_ADDRESS = 6;
localparam integer READ_FLASH_BYTE = 7;
localparam integer END_FLASH_READ = 8;

localparam integer WRITE_WORD_TO_ROM = 9;
localparam integer END_WRITE_WORD_TO_ROM = 10;
localparam integer WAIT_TO_READ_WORD_FROM_ROM = 11;
localparam integer READ_WORD_FROM_ROM = 12;

localparam integer START_UART_SEND = 13;
localparam integer SEND_UART = 14;
localparam integer END_UART_SEND = 15;
localparam integer START_UART_SEND_2 = 16;
localparam integer SEND_UART_2 = 17;
localparam integer END_UART_SEND_2 = 18;

localparam integer STOP = 19;

// States for sending bits to the flash controller
localparam [31:0] BYTES_TO_READ = 32'h4;

localparam integer SENDFLASH_SELECT = 100;
localparam integer SENDFLASH_START_SCK = 101;
localparam integer SENDFLASH_SEND_BITS = 102;
localparam integer SENDFLASH_STOP_SCK = 103;
localparam integer SENDFLASH_UNSELECT = 104;
localparam [7:0] RESET_COMMAND_1 = 8'h66;
localparam [7:0] RESET_COMMAND_2 = 8'h99;
localparam [7:0] TICKS_TO_WAIT_AFTER_RESET = 400;
localparam [7:0] READ_COMMAND = 8'h3;
localparam [23:0] READ_OFFSET = 24'h100000;
localparam integer TICKS_PER_FLASH_CLOCK_TOGGLE = 8;

// Wires and registers
reg [15:0] state = START;

// For flash storage
reg [15:0] sendflash_state = SENDFLASH_SELECT;
reg [15:0] sendflash_wait_counter = 16'b0;

reg flash_reader_is_active = 1'b0;
reg [7:0] flash_div_counter = 8'b0;
reg flash_clock_rise = 1'b0;
reg flash_clock_fall = 1'b0;
reg [7:0] command_to_send = READ_COMMAND;
reg [23:0] flash_offset_address = READ_OFFSET;
reg [23:0] flash_address = 24'b0;  // reset to offset address before each use

reg [7:0] byte_read_from_flash = 8'b0;
reg [15:0] word_read_from_flash = 16'b0;
reg [15:0] word_read_from_spram = 16'b0;
reg [23:0] bits_sent_to_flash = 24'b0;
reg [4:0] bits_read_from_flash = 5'b0;
reg next_byte_completes_word = 1'b0;
reg [31:0] bytes_read_from_flash = 32'b0;
reg [31:0] words_read_from_flash = 32'b0;

wire flash_sck_toggle;

assign FLASH_IO2 = 1'b1;
assign FLASH_IO3 = 1'b1;
assign flash_sck_toggle = flash_reader_is_active && 
                        (flash_div_counter == TICKS_PER_FLASH_CLOCK_TOGGLE - 1);

// For RAM and ROM
reg [15:0] rom_in = 16'b0;
reg [13:0] rom_address = 14'b0;
reg rom_load = 1'b0;
wire [15:0] rom_out;

// For UART
reg [7:0] pending_byte = 8'b0;
reg byte_is_pending = 0;
reg [31:0] bytes_sent = 0;
wire baud_clock;  // driven by u_baud_tick
wire valid = byte_is_pending;
wire ready;       // driven by uart_tx

// Parts
// RAM and ROM
ram32k u_rom(
  .clock(CLK),
  .in(rom_in),
  .load(rom_load),
  .address(rom_address),
  .out(rom_out)
);

// UART
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
  ///////////////////////////////////////////////////////////////////////////
  // Boot code
  //
  // This code reads bytes from flash and loads into ROM
  //
  ///////////////////////////////////////////////////////////////////////////
  // Flash clock logic
  // Hold flash clock at zero when inactive (not reading bits)
  // Override these if it's a flash clock toggle this tick of CLK
  flash_clock_rise <= 1'b0;
  flash_clock_fall <= 1'b0;
  if (!flash_reader_is_active) begin
    // Hold wires at known values when flash reader is not active
    FLASH_SCK <= 1'b0;
    FLASH_IO0 <= 0;
    flash_div_counter <= 0;
  end else begin
    // Is this tick of CLK also a tick of FLASH_SCK?
    if (flash_sck_toggle) begin
      flash_div_counter <= 0;
      // Is this tick a rise (0->1) or a fall (1->0) of FLASH_SCK?
      if (FLASH_SCK == 1'b0) begin
        flash_clock_rise <= 1'b1;
      end else begin
        flash_clock_fall <= 1'b1;
      end
      FLASH_SCK <= ~FLASH_SCK; // toggle flash clock
    end else begin
      // Not a tick of FLASH_SCK; increment flash_div_counter
      flash_div_counter <= flash_div_counter + 1;
    end
  end

  case (state)
    START: begin
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
      flash_reader_is_active <= 1;
      FLASH_SSB <= 1'b0; // active low until done reading bits
      bits_sent_to_flash <= 0;
      bits_read_from_flash <= 0;
      bytes_read_from_flash <= 0;
      words_read_from_flash <= 0;
      next_byte_completes_word <= 1'b0;
      byte_read_from_flash <= 0;
      word_read_from_flash <= 0;
      flash_address <= flash_offset_address;
      command_to_send <= READ_COMMAND;
      FLASH_IO0 <= READ_COMMAND[7]; // preload MSB for first read
      state <= SEND_FLASH_READ_COMMAND;
    end
    SEND_FLASH_READ_COMMAND: begin
      // Rising edge: flash has latched the bit currently on FLASH_IO0
      // So count here how many bits have been sent to the flash chip
      if (flash_clock_rise) begin
        if (bits_sent_to_flash == 7) begin
          // last bit has been sent
          bits_sent_to_flash <= 0;
          command_to_send <= READ_COMMAND; // reset in case used again
          state <= SEND_FLASH_ADDRESS;
        end else begin
          bits_sent_to_flash <= bits_sent_to_flash + 1;
        end
      end

      //Falling edge: put next bit on FLASH_IO0 and shift command_to_send
      if (flash_clock_fall) begin
        FLASH_IO0 <= command_to_send[6]; // send what next tick will be MSB
        command_to_send <= {command_to_send[6:0], 1'b0}; 
      end
    end
    SEND_FLASH_ADDRESS: begin
      // Rising edge: count bits sent
      if (flash_clock_rise) begin
        if (bits_sent_to_flash == 23) begin
          // last bit has been sent
          bits_sent_to_flash <= 0; 
          FLASH_IO0 <= 0; // after this state ends, FLASHIO0 unused, hold low
          flash_address <= flash_offset_address;  // reset in case used again
          state <= READ_FLASH_BYTE;
        end else begin
          bits_sent_to_flash <= bits_sent_to_flash + 1;
        end
      end        
      // Falling edge: Update bit to send and shift
      if (flash_clock_fall) begin
        FLASH_IO0 <= flash_address[23];
        // QUESTION: WHY SEND 23 here, but 6 instead of 7 for command above?
        flash_address <= {flash_address[22:0], 1'b0};
      end
    end
    READ_FLASH_BYTE: begin
      // Read on clock fall
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
      // hold flash clock until ready to read next byte
      flash_reader_is_active <= 0;
           
      // If this is an even byte read, load memory and update words read
      if (next_byte_completes_word == 1) begin
        // big endian: this is the second byte of the pair: put low           
        word_read_from_flash[7:0] <= byte_read_from_flash;
        state <= WRITE_WORD_TO_ROM;
      end else begin
        // big endian: this is the first byte of the pair, put high
        word_read_from_flash[15:8] <= byte_read_from_flash;  
        // Read next byte  
        flash_reader_is_active <= 1'b1;    
        state <= READ_FLASH_BYTE;
      end

      bytes_read_from_flash <= bytes_read_from_flash + 1;
      next_byte_completes_word <= ~next_byte_completes_word;
    end
    WRITE_WORD_TO_ROM: begin
      rom_address <= words_read_from_flash[13:0];
      rom_in <= word_read_from_flash;
      rom_load <= 1'b1;
      state <= END_WRITE_WORD_TO_ROM;
    end
    END_WRITE_WORD_TO_ROM: begin
      rom_load <= 1'b0;
      state <= WAIT_TO_READ_WORD_FROM_ROM;
    end
    WAIT_TO_READ_WORD_FROM_ROM: begin
      state <= READ_WORD_FROM_ROM;
    end
    READ_WORD_FROM_ROM: begin
      word_read_from_spram <= rom_out;
      words_read_from_flash <= words_read_from_flash + 1;
      state <= START_UART_SEND;
    end
    START_UART_SEND: begin
      // If no pending byte, set pending byte until ready
      // QUESTION: why ! and not ~ here?
      if (!byte_is_pending) begin
        if (ready) begin
          pending_byte <= word_read_from_spram[15:8];
          byte_is_pending <= 1;
        end
      end else begin
        // now have a single pending byte, wait for ready to accept
        if (ready) begin
          // accept happens this cycle, so byte won't be pending next tick
          byte_is_pending <= 1'b0;
          state <= SEND_UART;
        end
      end
    end
    SEND_UART: begin
      // Wait until ready shown again, meaning byte has been written
      if (ready) begin
        bytes_sent <= bytes_sent + 1;
        state <= END_UART_SEND;
      end
    end
    END_UART_SEND: begin
      state <= START_UART_SEND_2;
    end
    START_UART_SEND_2: begin
      // If no pending byte, set pending byte until ready
      // QUESTION: why ! and not ~ here?
      if (!byte_is_pending) begin
        if (ready) begin
          pending_byte <= word_read_from_spram[7:0];
          byte_is_pending <= 1;
        end
      end else begin
        // now have a single pending byte, wait for ready to accept
        if (ready) begin
          // accept happens this cycle, so byte won't be pending next tick
          byte_is_pending <= 1'b0;
          state <= SEND_UART_2;
        end
      end
    end
    SEND_UART_2: begin
      // Wait until ready shown again, meaning byte has been written
      if (ready) begin
        bytes_sent <= bytes_sent + 1;
        state <= END_UART_SEND_2;
      end
    end
    END_UART_SEND_2: begin
      if (bytes_sent == BYTES_TO_READ) begin
        state <= STOP;
      end else begin
        // read another pair of bytes
        flash_reader_is_active <= 1;
        state <= READ_FLASH_BYTE;
      end
    end
    STOP: begin
      FLASH_SSB <= 1'b0;
      state <= STOP; // infinite loop in final state
    end
  endcase
end

endmodule  // top
