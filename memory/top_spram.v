`default_nettype none

module top(
  input wire CLK,
  output wire LED1,
  output wire LED2,
  output wire LED3,
  output wire LED4,
  output wire LED5,
);

// States for my FSM
localparam integer WRITE = 0;
localparam integer READ_WAIT = 1;
localparam integer LATCH = 2;
localparam integer DONE = 3;

wire [15:0] data_to_write = 16'h4;
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

// insert SPRAM module here
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
      state <= READ_WAIT;
    end
    READ_WAIT: begin
      state <= LATCH;
    end
    LATCH: begin
      data_to_show <= spram_data_out;
      state <= DONE; 
    end
    DONE: begin
      state <= DONE;
    end
  endcase
end
endmodule  // top
