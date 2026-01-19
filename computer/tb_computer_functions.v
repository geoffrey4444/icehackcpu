`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb_computer;
// Wires and registers
reg CLK = 1'b0;
reg FLASH_IO1 = 1'b0;
reg BTN1 = 1'b0;

wire FLASH_SCK, FLASH_SSB, FLASH_IO0, FLASH_IO2, FLASH_IO3;
wire TX;

// Parts

top computer(
   .CLK(CLK),             // System clock (12 MHz)
   .FLASH_IO1(FLASH_IO1),       // Receive bits from flash storage,
   .BTN1(BTN1),            // Button will control reset on cpu
   .FLASH_SCK(FLASH_SCK),       // Clock for flash storage
   .FLASH_SSB(FLASH_SSB),       // Set low to start a flash conversation
   .FLASH_IO0(FLASH_IO0),       // Send bits to flash storage
   .FLASH_IO2(FLASH_IO2),      // /WP unused, hold high
   .FLASH_IO3(FLASH_IO3),      // /HOLD unused, hold high
   .TX(TX)             // Send bits to UART transmitter
);

// 12 MHz Clock
// 12 MHz = 83.333 ns / cycle = 41.666 ns / toggle
always #41.666 CLK = ~CLK;

initial begin
  // Read in a program in .hack format
  // Each line is 16 bits, expressed in ASCII as 1s and 0s
  string test_vm_program_file;
  integer i;
  test_vm_program_file = "./computer/test_vm_functions.hack";

  // $dumpfile("tb_computer.vcd");
  // $dumpvars(0, tb_computer);

  // Reset the computer. Time must pass before releasing the button for
  // reset to actually occur.
  BTN1 = 1'b1;
  @(posedge CLK);
  @(posedge CLK);
  BTN1 = 1'b0;

  // Reset is over, now force some cpu inputs for a tick to jump
  // to state 19 (START_CPU_LOOP).
  force computer.rom_load = 1'b0;
  force computer.ram_load = 1'b0;
  force computer.hold = 1'b1;
  force computer.state = 16'd19; // START_CPU_LOOP

  force computer.flash_reader_is_active = 1'b0;
  force computer.FLASH_SCK = 1'b0;
  force computer.FLASH_SSB = 1'b1;
  force computer.FLASH_IO0 = 1'b0;

  force computer.power_on_reset_counter = 8'hFF;

  // Zero RAM so all addresses are at least defined
  for (i=0; i < 100000; i = i + 1) begin
    computer.u_ram.u_ram_low.data[i] = 16'h0000;
  end

  // Read test program (no more than 16K instructions) into 
  // register backing simulated ROM
  $readmemb(test_vm_program_file, computer.u_rom.u_ram_low.data, 0, 661);
  //$readmemb("./computer/test_jne.hack", computer.u_rom.u_ram_low.data, 0, 23);

  // Tick once with forced values
  @(posedge CLK);  

  // Release forced wires/registers to computer control after initialization.
  // Note: I keep reset counter and flash pins held.
  release computer.state;
  release computer.hold;
  release computer.rom_load;
  release computer.ram_load;

  // Run for 100k ticks
  for (i=0; i < 20000; i = i + 1) begin
    @(posedge CLK);
  end

  // Examine computer state  
  // if (computer.u_ram.u_ram_low.data[17] != 16'd4) $fatal;
  if (computer.u_ram.u_ram_low.data[5] != 16'd7) $fatal;
  if (computer.u_ram.u_ram_low.data[6] != 16'd15) $fatal;
  if (computer.u_ram.u_ram_low.data[7] != 16'd4) $fatal;
  // $display("TEMP[0] = %0d", computer.u_ram.u_ram_low.data[5]);
  // $display("TEMP[1] = %0d", computer.u_ram.u_ram_low.data[6]);
  // $display("TEMP[2] = %0d", computer.u_ram.u_ram_low.data[7]);

  // reset computer and load second program

  // tests complete
  $display("OK");
  $finish;
end

endmodule  // tb_computer