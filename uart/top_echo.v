`default_nettype none

module top(
  input wire CLK,
  input wire RX,
  output wire TX
);

// Wires and registers

reg [7:0] byte_to_send = 8'h30;
reg pending_output = 0;
reg [7:0] pending_byte = 8'b0;

wire valid_output = pending_output;
wire ready_output; // don't initialize; it's driven by u_uart_tx
wire baud_tick; // don't initialize; it's driven by u_baud_tick

reg have_byte_to_send = 0;
reg ready_input = 0;
wire [7:0] byte_received;
wire valid_input;

baud_tick u_baud_tick(.clock(CLK), .tick(baud_tick));

// Parts 

uart_tx u_uart_tx(
  .clock(CLK),
  .baud_tick(baud_tick),
  .byte_to_send(pending_byte),
  .valid(valid_output),
  .ready(ready_output),
  .tx(TX)
);

uart_rx u_uart_rx(
  .clock(CLK),
  .rx(RX),
  .ready(ready_input),
  .byte_received(byte_received),
  .valid(valid_input)
);

// Time logic

always @(posedge CLK) begin
  // Hold received byte if already sending a byte or if have a byte to send
  if (valid_input == 1 && have_byte_to_send == 0 && pending_output == 0) begin
    ready_input <= 1;
    byte_to_send <= byte_received;    
  end
  if (ready_input == 1) begin
    have_byte_to_send <= 1;
    ready_input <= 0;
  end
  if (ready_output == 1 && pending_output == 1) begin
      pending_output <= 0;      
  end
  if (pending_output == 0 && ready_output == 1) begin
    if (have_byte_to_send == 1) begin
      pending_byte <= byte_to_send;
      pending_output <= 1;
      have_byte_to_send <= 0;
    end
  end    
end
endmodule  // top
