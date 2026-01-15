`default_nettype none

module top(
  input wire CLK,             // System clock (12 MHz)
  input wire FLASH_IO1,       // Receive bits from flash storage,
  input wire BTN1,            // Button will control reset on cpu
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

localparam DEBUG_DUMP_ROM = 1'b0;
localparam integer START_UART_SEND = 13;
localparam integer SEND_UART = 14;
localparam integer END_UART_SEND = 15;
localparam integer START_UART_SEND_2 = 16;
localparam integer SEND_UART_2 = 17;
localparam integer END_UART_SEND_2 = 18;

localparam integer START_CPU_LOOP = 19;
localparam integer START_NEXT_CPU_LOOP_ROUND = 20;
localparam integer SET_INSTRUCTION_FROM_ROM = 21;
localparam integer SET_INM_FROM_RAM = 22;
localparam integer SET_CPU_RUN = 23;
localparam integer EXECUTE_CPU_CYCLE = 24;
localparam integer GATHER_CPU_OUTPUTS_FOR_NEXT_INSTRUCTION = 25;
localparam integer START_UART_LOOP_SEND = 26;
localparam integer SEND_UART_LOOP = 27;
localparam integer END_UART_LOOP = 28;

// States for sending bits to the flash controller
localparam [31:0] BYTES_TO_READ = 32'd65536; // Read 

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

// Other constants
localparam TX_ADDRESS = 15'd24577;

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

// For ROM
reg [15:0] rom_in = 16'b0;
reg [14:0] rom_address = 15'b0;
reg rom_load = 1'b0;
wire [15:0] rom_out;

// For RAM
reg [15:0] ram_in = 16'b0;
reg [14:0] ram_address = 15'b0;
reg ram_load = 1'b0;
wire [15:0] ram_out;

// For UART
reg [7:0] pending_byte = 8'b0;
reg byte_is_pending = 0;
reg [31:0] bytes_sent = 0;
wire baud_clock;  // driven by u_baud_tick
wire valid = byte_is_pending;
wire ready;       // driven by uart_tx
reg uart_tx_seen_busy = 1'b0;

// For CPU
reg [15:0] in_m;
reg [15:0] instruction;
reg [15:0] out_m;
reg write_m;
reg [14:0] address_m;
reg [14:0] pc;

reg write_m_q;
reg [14:0] address_m_q;

reg hold;

wire reset;
assign reset = BTN1;

// Parts
// RAM and ROM
ram32k u_rom(
  .clock(CLK),
  .in(rom_in),
  .load(rom_load),
  .address(rom_address),
  .out(rom_out)
);

cpu u_cpu(
  .clock(CLK),
  .in_m(in_m),
  .instruction(instruction),
  .reset(reset),
  .hold(hold),
  .out_m(out_m),
  .write_m(write_m),
  .address_m(address_m),
  .pc(pc)
);

ram32k u_ram(
  .clock(CLK),
  .in(ram_in),
  .load(ram_load),
  .address(ram_address),
  .out(ram_out)
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
      // Initialize CPU and input registers. CPU is held.
      in_m <= 16'b0;
      instruction <= 16'b0;
      hold <= 1'b1; // CPU is held initially

      // Initialize RAM input registers. Only CPU in main loop will load RAM.
      ram_load <= 1'b0;
      ram_in <= 16'b0;
      ram_address <= 15'b0;

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
      rom_address <= words_read_from_flash[14:0];
      rom_in <= word_read_from_flash;
      rom_load <= 1'b1;
      state <= END_WRITE_WORD_TO_ROM;
    end
    END_WRITE_WORD_TO_ROM: begin
      rom_load <= 1'b0;
      if (DEBUG_DUMP_ROM) begin
        state <= WAIT_TO_READ_WORD_FROM_ROM;
      end else begin
        words_read_from_flash <= words_read_from_flash + 1;
        if (bytes_read_from_flash == BYTES_TO_READ) begin
          // Done reading instructions, start the main CPU loop
          state <= START_CPU_LOOP;
        end else begin
          // read another pair of bytes
          flash_reader_is_active <= 1;
          state <= READ_FLASH_BYTE;
        end
      end
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
          uart_tx_seen_busy <= 1'b0;
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
      if (!ready) begin
        uart_tx_seen_busy <= 1'b1;
      end else if ((uart_tx_seen_busy == 1) && (ready == 1)) begin
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
          uart_tx_seen_busy <= 1'b0;
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
      if (!ready) begin
        uart_tx_seen_busy <= 1'b1;
      end else if ((uart_tx_seen_busy == 1) && (ready == 1)) begin
        bytes_sent <= bytes_sent + 1;
        state <= END_UART_SEND_2;
      end
    end
    END_UART_SEND_2: begin
      if (bytes_sent == BYTES_TO_READ) begin
        // Done reading instructions, start the main CPU loop
        state <= START_CPU_LOOP;
      end else begin
        // read another pair of bytes
        flash_reader_is_active <= 1;
        state <= READ_FLASH_BYTE;
      end
    end
    START_CPU_LOOP: begin
      // This state executes once, handing over control to the main
      // loop from the boot sequence.
      // ROM no longer writeable; default address is first instruction
      rom_in <= 16'b0;
      rom_load <= 1'b0;
      rom_address <= 15'b0;  // start at instruction 0 on first run.

      // First instruction should not be to read from RAM, because RAM is
      // currently empty (nothing to read there). A and D registers are
      // also empty, so first instruction should not involve writing to
      // RAM, either. 
      state <= START_NEXT_CPU_LOOP_ROUND;
    end
    START_NEXT_CPU_LOOP_ROUND: begin
      // In this state, ROM inputs are set to read next instruction.
      // ROM output (i.e, the instruction) will be valid next tick
      // (state SET_INSTRUCTION_FROM_ROM).
      //
      // RAM inputs are now set to read in_m, possibly after
      // updating its value (stored at address_m). Write (if done) valid
      // next tick (SET_INSTRUCTION_FROM_ROM). Read (of possibly updated 
      // value) valid tick after that at latest (SET_INM_FROM_RAM).
      state <= SET_INSTRUCTION_FROM_ROM;
    end
    SET_INSTRUCTION_FROM_ROM: begin
      // ROM output now contains the next instruction.
      instruction <= rom_out;
      state <= SET_INM_FROM_RAM;
    end
    SET_INM_FROM_RAM: begin
      // ram_out now contains the value of RAM at address_m.
      in_m <= ram_out;
      state <= SET_CPU_RUN;
    end
    SET_CPU_RUN: begin
      // All CPU inputs now valid. 
      // Lift hold; hold will be false next tick (EXECUTE_CPU_CYCLE).
      hold <= 1'b0;
      state <= EXECUTE_CPU_CYCLE;
    end
    EXECUTE_CPU_CYCLE: begin
      // CPU inputs are valid and CPU is not held this cycle. 
      // Execute the instruction and capture the outputs now, while CPU is
      // running. Next cycle, CPU should be held once more.     
      hold <= 1'b1;

      // Gather updates to RAM using current (not updated values) for 
      // write_m, out_m, address_m. RAM update happens next tick,
      // updated value available 2 ticks from now.
      ram_load <= write_m;
      ram_in <= out_m;
      ram_address <= address_m;

      // Save current values of write_m and address_m to determine whether
      // to output a byte to TX.
      write_m_q <= write_m;
      address_m_q <= address_m;

      state <= GATHER_CPU_OUTPUTS_FOR_NEXT_INSTRUCTION;
    end
    GATHER_CPU_OUTPUTS_FOR_NEXT_INSTRUCTION: begin
      // CPU is now held. address_m, pc updated. RAM has been updated if 
      // the instruction updated RAM. Now get read address for next tick.
      rom_address <= pc;
      ram_load <= 1'b0; // just read the next address; don't edit it
      ram_address <= address_m;     

      // Are we writing to TX (15'd24577)? If so, go to START_UART_LOOP_SEND
      // to write the byte out. Else, go back to START_NEXT_CPU_LOOP_ROUND.
      if ((address_m_q == TX_ADDRESS) & (write_m_q == 1)) begin
        state <= START_UART_LOOP_SEND;
      end else begin
        state <= START_NEXT_CPU_LOOP_ROUND;
      end
    end
    START_UART_LOOP_SEND: begin
      // If no pending byte, set pending byte until ready
      if (!byte_is_pending) begin
        if (ready) begin
          // For now, just write the bottom byte of TX_ADDRESS.
          // TX expects one byte at a time. This could be improved later on,
          // e.g. to always or optionally write both bytes.
          pending_byte <= ram_in[7:0];
          byte_is_pending <= 1;
          uart_tx_seen_busy <= 1'b0;
        end
      end else begin
        // now have a single pending byte, wait for ready to accept
        if (ready) begin
          // accept happens this cycle, so byte won't be pending next tick
          byte_is_pending <= 1'b0;
          state <= SEND_UART_LOOP;
        end
      end
    end
    SEND_UART_LOOP: begin
      // Wait until ready shown again, meaning byte has been written
      if (!ready) begin
        uart_tx_seen_busy <= 1'b1;
      end else if ((uart_tx_seen_busy == 1) && (ready == 1)) begin
        state <= END_UART_LOOP;
      end
    end
    END_UART_LOOP: begin
      // Done sending byte, back to main CPU loop
      state <= START_NEXT_CPU_LOOP_ROUND;
    end
  endcase
end

endmodule  // top
