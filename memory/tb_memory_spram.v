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

localparam integer INIT_32K = 8;
localparam integer WRITE_OLD0_32K = 9;
localparam integer WAIT_OLD0_32K = 10;
localparam integer WRITE_OLD1_32K = 11;
localparam integer WAIT_OLD1_32K = 12;
localparam integer READBACK_OLD0_32K = 13;
localparam integer READBACK_OLD1_32K = 14;
localparam integer WRITE_NEW_0_32K = 15;
localparam integer CHECK0_SHOULD_BE_OLD_32K = 16;
localparam integer CHECK0_SHOULD_BE_NEW_32K = 17;
localparam integer WRITE_NEW_1_32K = 18;
localparam integer CHECK1_SHOULD_BE_OLD_32K = 19;
localparam integer CHECK1_SHOULD_BE_NEW_32K = 20;
localparam integer STRESS_ALT_32K = 21;

localparam integer DONE = 22;

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

reg [15:0] low_value_32k;
reg [15:0] high_value_32k;
reg load_32k;
reg [15:0] in_32k;
wire [15:0] out_32k;
reg [14:0] address_32k;
reg [13:0] address_base_32k;
reg integer i;

// Parts
ram16k u_ram16k(
  .clock(clock),
  .in(in),
  .load(load),
  .address(address),
  .out(out)
);

ram32k u_ram32k(
  .clock(clock),
  .in(in_32k),
  .load(load_32k),
  .address(address_32k),
  .out(out_32k)
);

initial begin: clock_generate
  run_clock = 1;
  clock = 0;
  load = 1;
  in = 16'h0000;
  random_byte = $random;
  address = $random;
  read_byte = $random;
  in_32k = 16'h0000;
  load_32k = 1'b0;
  address_32k = $random;
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

          // Init values I'll need for 32K test init
          low_value_32k <= $random;
          high_value_32k <= $random;
          address_base_32k <= $random;

          state <= INIT_32K;
        end
        INIT_32K: begin
          // Set values for next state: WRITE_OLD0_32K                   
          address_32k <= {1'b0, address_base_32k};
          in_32k <= 16'h7777;
          load_32k <= 1'b1;
          state <= WRITE_OLD0_32K;
        end
        WRITE_OLD0_32K: begin
          // Values for next state
          load_32k <= 1'b0;
          state <= WAIT_OLD0_32K;
        end
        WAIT_OLD0_32K: begin
          // Values for next state
          state <= READBACK_OLD0_32K;
        end
        READBACK_OLD0_32K: begin
          if (out_32k !== 16'h7777) $fatal;
          // Values for next state
          in_32k <= 16'h4444;
          load_32k <= 1'b1;
          address_32k <= {1'b1, address_base_32k};
          state <= WRITE_OLD1_32K;
        end
        WRITE_OLD1_32K: begin
          // Values for next state
          load_32k <= 1'b0;          
          state <= WAIT_OLD1_32K;
        end
        WAIT_OLD1_32K: begin
          // Values for next state          
          state <= READBACK_OLD1_32K;
        end        
        READBACK_OLD1_32K: begin
          if (out_32k !== 16'h4444) $fatal;
          // Values for next state
          load_32k <= 1'b1;
          address_32k <= {1'b0, address_base_32k};
          in_32k <= low_value_32k;
          state <= WRITE_NEW_0_32K;          
        end
        WRITE_NEW_0_32K: begin
          // Values for next state
          load_32k <= 1'b0;
          state <= CHECK0_SHOULD_BE_OLD_32K;
        end
        CHECK0_SHOULD_BE_OLD_32K: begin
          if (out_32k !== 16'h7777) $fatal;
          // Values for next state
          state <= CHECK0_SHOULD_BE_NEW_32K;
        end
        CHECK0_SHOULD_BE_NEW_32K: begin
          if (out_32k !== low_value_32k) $fatal;
          // Values for next state
          address_32k <= {1'b1, address_base_32k};
          load_32k <= 1'b1;
          in_32k <= high_value_32k;
          state <= WRITE_NEW_1_32K;
        end
        WRITE_NEW_1_32K: begin
          // Values for next state
          load_32k <= 1'b0;
          state <= CHECK1_SHOULD_BE_OLD_32K;
        end
        CHECK1_SHOULD_BE_OLD_32K: begin
          if (out_32k !== 16'h4444) $fatal;
          // Values for next state
          state <= CHECK1_SHOULD_BE_NEW_32K;
        end
        CHECK1_SHOULD_BE_NEW_32K: begin
          if (out_32k !== high_value_32k) $fatal;
          // Values for next state
          i <= 0;
          address_32k <= {1'b0, address_base_32k};
          state <= STRESS_ALT_32K;
        end
        STRESS_ALT_32K: begin
          if (i > 10) begin            
            state <= DONE;
          end else begin
            // check that out is the data held at address from last time
            // address from last time is low if address_32k[14] is high_address_bit
            // and vice versa. Since base is the same, I can get the previous
            // address using the not operator on the high bit.
            // Skip first check, because out_32k is determined by
            // CHECK1_SHOULD_BE_NEW_32K output
            if (i > 0) begin
              if (out_32k !== (~address_32k[14] ? high_value_32k : low_value_32k)) $fatal;            
            end
            address_32k <= {~address_32k[14], address_base_32k};
            i <= i + 1;         
          end          
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
