`default_nettype none
`timescale 1ns/1ps  // so #1; is a 1ns delay

module tb_dff;
reg clock = 0; 
reg in = 0;
wire out;
wire out_for_learning;
reg run_clock = 1;

// The data flip-flop (dff) module I will test
dff u_dff(.clock(clock), .in(in), .out(out));

dff_for_learning u_dff_for_learning(.clock(clock), .in(in), .out(out_for_learning));

// Define a clock with a 10ns period
// = is instant assignment, => = assign at end of time step
// In the simulator, time steps are every 1ns (#1). Instant is fine here;
// I want to instantly update my artificial clock.
// Note: every 5 ns, clock toggles, so period is 10ns = 2 toggles
// note: posedge means clock goes from 0 to 1...ticks at 5, 15, 25, ... ns
// Instead of always #5 clock = ~clock; ... only tick when clock active
// by using a loop with a while statement
initial begin : clock_generate
  while (run_clock) #5 clock = ~clock;
end
initial begin
  clock = 0;
  in = 0;
  #15; // wait to make sure in and out are initially 0
  #2  in = 1;                     // t=17ns : set high
  #1  if (out != 0) $fatal;       // t=18ns : still low, no tick yet
  #6  if (out != 0) $fatal;       // t=24ns : still low, no tick yet
  #2  if (out != 1) $fatal;       // t=26ns : now high; after tick
  #12 if (out != 1) $fatal;       // t=38ns : stay high after another tick
  #3 in = 0;                      // t=41ns : set low
  #1 if (out != 1) $fatal;        // t=42ns : still high
  #2 if (out != 1) $fatal;        // t=44ns : still high
  #2 if (out != 0) $fatal;        // t=46ns : now low; after tick
  #10 if (out != 0) $fatal;       // t=56ns : still low after another tick
  
  clock = 0;
  in = 0;
  #15; // wait to make sure in and out are initially 0
  #2  in = 1;                     // t=17ns : set high
  #1  if (out_for_learning != 0) $fatal;       // t=18ns : still low, no tick yet
  #6  if (out_for_learning != 0) $fatal;       // t=24ns : still low, no tick yet
  #2  if (out_for_learning != 1) $fatal;       // t=26ns : now high; after tick
  #12 if (out_for_learning != 1) $fatal;       // t=38ns : stay high after another tick
  #3 in = 0;                      // t=41ns : set low
  #1 if (out_for_learning != 1) $fatal;        // t=42ns : still high
  #2 if (out_for_learning != 1) $fatal;        // t=44ns : still high
  #2 if (out_for_learning != 0) $fatal;        // t=46ns : now low; after tick
  #10 if (out_for_learning != 0) $fatal;       // t=56ns : still low after another tick
  
  run_clock = 0; // we're done; stop clock updates
end
endmodule  // tb_dff