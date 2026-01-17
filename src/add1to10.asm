// Test program: add up numbers between 1 and 10, inclusive

// i = 0;
@i
M=0
// sum = 0;
@sum
M=0
// while (i < 10)
(LOOP)
  // if (i - 10 > 0) jump to end
  @i
  D=M
  @10
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

  // store sum in TX
  (END)
  @sum
  D=M
  @TX
  M=D
  (DONE)
  @DONE
  0;JMP
