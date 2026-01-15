// Hello, world in hack asm
// Print "Hello, world!" to UART TX, one character at a time
@72
D=A
@TX
M=D

@101
D=A
@TX
M=D

@108
D=A
@TX
M=D

@108
D=A
@TX
M=D

@111
D=A
@TX
M=D

@44
D=A
@TX
M=D

@32
D=A
@TX
M=D

@119
D=A
@TX
M=D

@111
D=A
@TX
M=D

@114
D=A
@TX
M=D

@108
D=A
@TX
M=D

@100
D=A
@TX
M=D

@33
D=A
@TX
M=D

@10
D=A
@TX
M=D

@13
D=A 
@TX
M=D

// Infinite loop that does nothing after program ends
(END)
@END
0;JMP
