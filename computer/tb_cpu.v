`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb_cpu;

// States

// Registers and wires
reg clock = 0;
reg [15:0] in_m = 16'h0000;
reg [15:0] instruction = 16'h0000;
reg reset = 0;
reg hold = 0;

wire [15:0] out_m;
wire write_m;
wire [14:0] address_m;
wire [14:0] pc;

wire [15:0] out_m_latch;
wire write_m_latch;
wire [14:0] address_m_latch;

// Parts
cpu u_cpu(
  .clock(clock),
  .in_m(in_m),
  .instruction(instruction),
  .reset(reset),
  .hold(hold),
  .out_m(out_m),
  .write_m(write_m), 
  .address_m(address_m),
  .pc(pc),
  .out_m_latch(out_m_latch),
  .write_m_latch(write_m_latch),
  .address_m_latch(address_m_latch)
);

// Clock runs
always #5 clock = ~clock;

// Step clock
task step;
  begin
    @(posedge clock);
    #1;
  end
endtask

// test
initial begin: test
  // Reset and PC
  reset = 1;
  hold = 0;
  step();
  if (pc !== 15'b0) $fatal;

  reset = 0;
  step();
  if (pc !== 15'b1) $fatal;

  hold=1;
  repeat (1000) begin
    step();
    if (pc !== 15'b1) $fatal;
    if (write_m !== 1'b0) $fatal;
  end

  // A-instruction @123
  instruction = 16'b0000000001111011;
  hold = 0;
  step();
  if (address_m !== 15'd123) $fatal;
  if (write_m !== 0) $fatal;
  if (pc !== 15'h2) $fatal;
  if (u_cpu.u_a_register.out !== 16'd123) $fatal;

  // C instruction D=A
  instruction = 16'b1110110000010000;
  step();
  if (address_m !== 15'd123) $fatal;
  if (write_m !== 1'b0) $fatal;
  if (pc !== 15'h3) $fatal;
  if (u_cpu.u_d_register.out !== 16'd123) $fatal;

  // C instruction D=D+A
  instruction = 16'b1110000010010000;
  step();
  if (address_m !== 15'd123) $fatal;
  if (write_m !== 1'b0) $fatal;
  if (pc !== 15'h4) $fatal;
  if (u_cpu.u_d_register.out !== 16'd246) $fatal;  

  // C instruction A=D
  instruction = 16'b1110001100100000;
  step();
  if (address_m !== 15'd246) $fatal;
  if (write_m !== 1'b0) $fatal;
  if (pc !== 15'h5) $fatal;
  if (u_cpu.u_a_register.out !== 16'd246) $fatal;

  // C instruction M=D
  instruction = 16'b1110001100001000;
  step();
  if (address_m !== 15'd246) $fatal;
  if (write_m !== 1'b1) $fatal;
  if (pc !== 15'h6) $fatal;
  if (out_m !== 16'd246) $fatal;

  // Confirm write_m pulse (hold=0)
  // If next instruction is not also writing to memory, write_m should go back
  // to zero. The next instruction is A=A+1.
  instruction = 16'b1110110111100000;
  step();
  if (address_m !== 15'd247) $fatal;
  if (write_m !== 1'b0) $fatal;
  if (pc !== 15'h7) $fatal;
  if (u_cpu.u_a_register.out !== 16'd247) $fatal;

  // Confirm write_m is zero when hold=1, even if
  // instruction is trying to write to tb_memory_spram

  // Jump tests
  // Try a few different jumps based on comparison
  // and also 0;JMP
  // Check that PC loads A if condition satisfied,
  // Doesn't if not
  // @0
  instruction = 16'b0000000000000000;
  step();
  if (u_cpu.u_a_register.out !== 16'h0000) $fatal;

  // D=A
  instruction = 16'b1110110000010000;
  step();
  if (u_cpu.u_d_register.out !== 16'h0000) $fatal;
  
  // @4
  instruction = 16'b0000000000000100;
  step();
  if (u_cpu.u_a_register.out !== 16'h0004) $fatal;  

  // 0;JMP
  instruction = 16'b1110101010000111;
  step();
  if (pc !== 15'h4) $fatal;



  // @44
  instruction = 16'd44;
  step();
  if (address_m !== 15'd44) $fatal;

  // D=D+1
  instruction = 16'b1110011111010000;
  step();
  
  if (u_cpu.u_d_register.out !== 16'h0001) $fatal;

  // D;JEQ
  instruction = 16'b1110001100000010;
  step();
  if (pc === 15'd44) $fatal;

  // D;JLT
  instruction = 16'b1110001100000100;
  step();
  if (pc === 15'h44) $fatal;

  // D;JGT
  instruction = 16'b1110001100000001;
  step();
  if (pc !== 15'd44) $fatal;

  // @4444;
  instruction = 16'b0001000101011100;
  step();

  // @D=-D
  instruction = 16'b1110001111010000;
  step();
  if (u_cpu.u_d_register.out !== 16'hffff) $fatal;

  // JGE
  instruction = 16'b1110001100000011;
  step();
  if (pc === 15'd4444) $fatal;

  // JLE
  instruction = 16'b1110001100000110;
  step();
  if (pc !== 15'd4444) $fatal;

  // Hold correctness test
  // Store instruction that would assert write_m
  // run with hold=1 for many cycles
  // Check: PC does not change, write_m stays 0
  // A/D do not change while held
  // Then release hold and verify write test
  // completed successfully
  // 
  // Run this program: put 123 on D, 456 on A. Then run a bunch of cycles
  // @123
  // D=A
  // @456
  // ADM=D+1
  //
  // Expect out_m == 125, write_m == 0, address_m = 124,
  //        out_m_latch == 124, write_m_latch == 1, address_m_latch == 456
  hold = 0;
  instruction = 16'b0000000001111011;
  step();
  hold = 1;
  step();

  hold = 0;
  instruction = 16'b1110110000010000;
  step();
  hold = 1;
  step();

  hold = 0;
  instruction = 16'b0000000111001000;
  step();
  hold = 1;
  step();

  hold = 0;
  instruction = 16'b1110011111111000;
  step();
  hold = 1;
  step();
  repeat (100) begin
    step();
  end
  if (write_m !== 1'b0) $fatal;
  if (write_m_latch !== 1'b1) $fatal;
  if (address_m !== 15'd124) $fatal;
  if (address_m_latch !== 15'd456) $fatal;
  if (out_m_latch !== 16'd124) $fatal;
  if (out_m !== 16'd125) $fatal; // it reflects the instruction D+1 on 124


  $display("OK");
  $finish;
end
endmodule  // tb_cpu
