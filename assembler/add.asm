// Test program: add up numbers between 1 and 100, inclusive

// i = 0;
@i
M=0
// sum = 0;
@sum
M=0
// while (i < 100)
(LOOP)
  // if (i - 100 > 0) jump to end
  @i
  D=M
  @100
  D=D-A
  @END
  D;JGT
  // else, add i to sum and then increment it
  @i
  D=M
  @sum
  D=D+M
  @sum
  M=D
  @i
  D=M+1
  @i
  M=D
  @LOOP
  D;JMP

// Done with loop
(END)
  // store sum in R0
  @sum
  D=M
  @R0
  M=D
  @END
  0;JMP
