`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb;
reg a, b, c;
reg signed [15:0] a16;
reg signed [15:0] b16;
reg signed [15:0] c16;
wire signed [15:0] sum16;
wire signed [15:0] sum16reverse;
wire signed [15:0] sum16assoc1;
wire signed [15:0] sum16bc;
wire signed [15:0] sum16assoc2;
wire sum, carry, full_sum, full_carry;
integer i, j, k;
localparam signed [15:0] MAX = 16'sd32767;
localparam signed [15:0] MIN = -16'sd32768;

half_adder u_half_adder(.a(a), .b(b), .sum(sum), .carry(carry));
full_adder u_full_adder(.a(a), .b(b), .c(c), .sum(full_sum), .carry(full_carry));
add16 u_add16(.a(a16), .b(b16), .sum(sum16));
add16 u_add16reverse(.a(b16), .b(a16), .sum(sum16reverse));
add16 u_add16dist1(.a(sum16), .b(c16), .sum(sum16assoc1));
add16 u_add16bc(.a(b16), .b(c16), .sum(sum16bc));
add16 u_add16dist2(.a(sum16bc), .b(a16), .sum(sum16assoc2));

initial begin
for (i = 0; i < 2; ++i) begin
  for (j = 0; j < 2; ++j) begin
    for (k = 0; k < 2; ++k) begin
      a = i;
      b = j;
      c = k;
      #1;

      if (k == 0) begin
        if ((a == 0) & (b == 0) & ((carry != 0) | (sum != 0))) $fatal;
        if ((a == 0) & (b == 1) & ((carry != 0) | (sum != 1))) $fatal;
        if ((a == 1) & (b == 0) & ((carry != 0) | (sum != 1))) $fatal;
        if ((a == 1) & (b == 1) & ((carry != 1) | (sum != 0))) $fatal; 
      end
      if ((a == 0) & (b == 0) & (c == 0) & ((full_carry != 0) | (full_sum != 0))) $fatal;
      if ((a == 0) & (b == 0) & (c == 1) & ((full_carry != 0) | (full_sum != 1))) $fatal;
      if ((a == 0) & (b == 1) & (c == 0) & ((full_carry != 0) | (full_sum != 1))) $fatal;
      if ((a == 0) & (b == 1) & (c == 1) & ((full_carry != 1) | (full_sum != 0))) $fatal;
      if ((a == 1) & (b == 0) & (c == 0) & ((full_carry != 0) | (full_sum != 1))) $fatal;
      if ((a == 1) & (b == 0) & (c == 1) & ((full_carry != 1) | (full_sum != 0))) $fatal;
      if ((a == 1) & (b == 1) & (c == 0) & ((full_carry != 1) | (full_sum != 0))) $fatal;
      if ((a == 1) & (b == 1) & (c == 1) & ((full_carry != 1) | (full_sum != 1))) $fatal;
    end   
  end
end

// Test full adder

repeat (1000) begin
  // check random addition properties
  a16 = $signed($random);
  b16 = $signed($random);
  c16 = $signed($random);
  #1;

  if ($signed(sum16reverse) != $signed(sum16)) $fatal; // commutative
  if ($signed(sum16assoc1) != $signed(sum16assoc2)) $fatal; // associative

  // Additive identity
  b16 = $signed(16'sd0);
  #1;
  if ($signed(sum16) != $signed(a16)) $fatal;
  if ($signed(sum16reverse) != $signed(a16)) $fatal;

  // additive inverse
  b16 = $signed(-a16);
  #1;
  if (sum16 != 16'sd0) $fatal;
  if ($signed(sum16reverse) != 16'sd0) $fatal;

  // two's complement
  b16 = $signed(~a16 + $signed(16'sd1));
  #1;
  if ($signed(sum16) != 16'sd0) $fatal;

  // MIN/MAX tests
  a16 = MAX;
  b16 = 16'sd0;
  #1;
  if ($signed(sum16) != $signed(MAX)) $fatal; // MAX + 0 = MAX
  b16 = 16'sd1;
  #1;
  if ($signed(sum16) != $signed(MIN)) $fatal; // MAX + 1 = MIN
  b16 = -16'sd1;
  #1;
  if ($signed(sum16) != 16'sd32766) $fatal; // MAX - 1 = 32766
  b16 = MAX;
  #1;
  if ($signed(sum16) != -16'sd2) $fatal; // MAX + MAX = -2
  b16 = -MAX;
  #1;
  if ($signed(sum16) != 16'sd0) $fatal; // MAX + (-MAX) = 0
  b16 = MIN;
  #1;
  if ($signed(sum16) != -16'sd1) $fatal; // MAX + MIN = -1
  b16 = -MIN;
  #1;
  if ($signed(sum16) != -16'sd1) $fatal; // MAX + (-MIN) = MAX + MIN = -1

  a16 = MIN;
  b16 = 16'sd0;
  #1;
  if ($signed(sum16) != $signed(MIN)) $fatal; // MIN + 0 = MIN
  b16 = 16'sd1;
  #1;
  if ($signed(sum16) != $signed(-16'sd32767)) $fatal; // MIN + 1 = -32767
  b16 = -16'sd1;
  #1;
  if ($signed(sum16) != $signed(MAX)) $fatal; // MIN - 1 = MAX
  b16 = MIN;
  #1;
  if ($signed(sum16) != 16'sd0) $fatal; // MIN + MIN = 0
  b16 = -MIN;
  #1;
  if ($signed(sum16) != 16'sd0) $fatal; // MIN + (-MIN) = 0

  // Carry tests
  a16 = 16'h1;
  b16 = 16'h1;
  #1;
  if ($signed(sum16) != 16'sd2) $fatal; // 1 + 1 = 2
  a16 = 16'hF;
  #1;
  if ($signed(sum16) != 16'sd16) $fatal; // 15 + 1 = 16
  a16 = 16'hFF;
  #1;
  if ($signed(sum16) != 16'sd256) $fatal; // 255 + 1 = 256
  a16 = 16'hFFF;
  #1;
  if ($signed(sum16) != 16'sd4096) $fatal; // 4095 + 1 = 4096
  a16 = 16'h7FFF;
  #1;
  if ($signed(sum16) != 16'h8000) $fatal; // 7FFF + 1 = 8000
  a16 = 16'hFFFF;
  #1;
  if ($signed(sum16) != 16'h0000) $fatal; // FFFF + 1 = 0000
  a16 = 16'hAAAA;
  b16 = 16'h5555;
  #1;
  if ($signed(sum16) != 16'hFFFF) $fatal; // AAAA + 5555 = FFFF
  a16 = 16'h5555;
  b16 = 16'h5555;
  #1;
  if ($signed(sum16) != 16'hAAAA) $fatal; // 5555 + 5555 = AAAA

  // Mix large and small numbers
  a16 = 16'sd1;
  b16 = -16'sd1;
  #1;
  if ($signed(sum16) != 16'sd0) $fatal; // 1 + (-1) = 0
  a16 = 16'sd2;
  #1;
  if ($signed(sum16) != 16'sd1) $fatal; // 2 + (-1) = 1
  a16 = 16'sd1;
  b16 = -16'sd2;
  #1;
  if ($signed(sum16) != -16'sd1) $fatal; // 1 + (-2) = -1
  a16 = 16'sd30000;
  b16 = -16'sd1;
  #1;
  if ($signed(sum16) != 16'sd29999) $fatal; // 30000 + (-1) = 29999
  a16 = 16'sd32767;
  b16 = -16'sd100;
  #1;
  if ($signed(sum16) != 16'sd32667) $fatal; // 32767 + (-100) = 32667
  a16 = -16'sd30000;
  b16 = 16'sd1;
  #1;
  if ($signed(sum16) != -16'sd29999) $fatal; // -30000 + 1 = -29999
  a16 = -16'sd32768;
  b16 = 100;
  #1;
  if ($signed(sum16) != -16'sd32668) $fatal; // -32768 + 100 = -32668

  // The classic
  a16 = 16'sd2;
  b16 = 16'sd2;
  #1;
  if ($signed(sum16) != 16'sd4) $fatal; // 2 + 2 = 4


end

end
endmodule  // tb