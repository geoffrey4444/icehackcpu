`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb_memory_spram;

// States
localparam integer START = 0;
localparam integer WAIT1 = 1;
localparam integer WAIT2 = 2;
localparam integer WRITE = 3;
localparam integer FIRST_CLOCK_AFTER_WRITE = 4;
localparam integer SECOND_CLOCK_AFTER_WRITE = 5;
localparam integer THIRD_CLOCK_AFTER_WRITE = 6;
localparam integer FOURTH_CLOCK_AFTER_WRITE = 7;
localparam integer DONE = 8;

// Registers and wires
reg [7:0] state = START;
reg run_clock;

reg clock;
reg load;
reg [15:0] in;
wire [15:0] out;
reg [13:0] address;

reg [15:0] random_byte;
reg [15:0] read_byte;

// Parts
ram16k u_ram16k(
  .clock(clock),
  .in(in),
  .load(load),
  .address(address),
  .out(out)
);

initial begin: clock_generate
  run_clock = 1;
  clock = 0;
  load = 1;
  in = 16'h0000;
  random_byte = $random;
  address = $random;
  read_byte = $random;
  while (run_clock) #5 clock = ~clock;
end

initial begin: test
  forever begin
    @(posedge clock) begin
      case (state)
        START: begin                          
          load <= 0;          
          state <= WAIT1;
        end
        WAIT1: begin          
          state <= WAIT2;
        end
        WAIT2: begin            
          if (out !== 16'h0000) $fatal;
          state <= WRITE;
          load <= 1;
          in <= random_byte;
        end
        WRITE: begin          
          if (out !== 16'h0000) $fatal;
          load <= 0;
          state <= FIRST_CLOCK_AFTER_WRITE;
        end
        FIRST_CLOCK_AFTER_WRITE: begin          
          if (out !== 16'h0000) $fatal;      
          state <= SECOND_CLOCK_AFTER_WRITE;
        end
        SECOND_CLOCK_AFTER_WRITE: begin         
          if (out !== random_byte) $fatal;
          state <= THIRD_CLOCK_AFTER_WRITE;
        end
        THIRD_CLOCK_AFTER_WRITE: begin
          if (out !== random_byte) $fatal;
          read_byte <= out;
          state <= FOURTH_CLOCK_AFTER_WRITE;
        end
        FOURTH_CLOCK_AFTER_WRITE: begin          
          if (out !== random_byte) $fatal;
          if (read_byte !== random_byte) $fatal;
          state <= DONE;
        end
        DONE: begin  
          $display("OK");
          run_clock <= 0;
          $finish;
        end
      endcase
    end
  end
end
endmodule  // tb_memory_spram
