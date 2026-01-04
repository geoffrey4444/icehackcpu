`default_nettype none

module top(
  input wire CLK,
  output wire TX
);
localparam integer CLK_FREQ = 12000000;
localparam integer SECONDS_PER_TICK = 4;
localparam integer DIV = CLK_FREQ * SECONDS_PER_TICK;

reg [26:0] count = 0;
reg [7:0] byte_to_send = 8'h30;
reg pending = 0;
reg [7:0] pending_byte = 8'b0;

wire valid = pending;
wire ready; // don't initialize; it's driven by u_uart_tx
wire baud_tick; // don't initialize; it's driven by u_baud_tick

wire slow_pulse = (count == DIV - 1);

baud_tick u_baud_tick(.clock(CLK), .tick(baud_tick));

uart_tx u_uart_tx(
  .clock(CLK),
  .baud_tick(baud_tick),
  .byte_to_send(pending_byte),
  .valid(valid),
  .ready(ready),
  .tx(TX)
);

always @(posedge CLK) begin
  if (ready == 1 && pending == 1) begin
      pending <= 0;
      byte_to_send <= byte_to_send + 1;
  end
  if (slow_pulse) begin
    count <= 0;
    if (pending == 0) begin
      pending_byte <= byte_to_send;
      pending <= 1;
    end    
  end else begin
    count <= count + 1;
  end
end
endmodule  // top
