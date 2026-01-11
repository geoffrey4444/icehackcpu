`default_nettype none

module ram16k(
  input wire clock,
  input wire [15:0] in,
  input wire load,
  input wire [13:0] address,
  output wire [15:0] out
);
`ifdef SIM
// Implementation for iverilog simulator
reg [15:0] data [0:16383];
reg [15:0] data_out = 16'h0000;
assign out = data_out;
always @(posedge clock) begin
  // Read: out ready next tick
  // Write: out reflects new value the tick after next
  data_out <= data[address];
  if (load == 1'b1) begin    
    data[address] <= in;
  end
end
`else
// Hardware implementation for real hardware
SB_SPRAM256KA u_spram(
  .CLOCK(clock),
  .CHIPSELECT(1'b1),
  .WREN(load),
  .ADDRESS(address),
  .DATAIN(in),
  .MASKWREN(4'b1111), // write all 4 nibbles for the 16-bit value
  .DATAOUT(out),
  .STANDBY(1'b0),
  .SLEEP(1'b0),
  .POWEROFF(1'b1)
);
`endif
endmodule  // ram16k

module ram32k(
  input wire clock,
  input wire [15:0] in,
  input wire load,
  input wire [14:0] address,
  output wire [15:0] out
);
wire [13:0] lower_address;
assign lower_address = address[13:0];
wire high_address_bit;
assign high_address_bit = address[14];
wire [15:0] out_low;
wire [15:0] out_high;
reg select_low_or_high = 1'b0;
wire load_low, load_high;
assign load_low = load & ~high_address_bit;
assign load_high = load & high_address_bit;

ram16k u_ram_low(
  .clock(clock),
  .in(in),
  .load(load_low),
  .address(lower_address),
  .out(out_low)
  );

ram16k u_ram_high(
  .clock(clock),
  .in(in),
  .load(load_high),
  .address(lower_address),
  .out(out_high)
  );

always @(posedge clock) begin
  select_low_or_high <= high_address_bit;
end

assign out = select_low_or_high ? out_high : out_low;

endmodule // ram32k
