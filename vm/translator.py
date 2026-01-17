import argparse
from pathlib import Path

command_types = ["C_ARITHMETIC", "C_PUSH", "C_POP", "C_LABEL", "C_GOTO", "C_IF", "C_FUNCTION", "C_RETURN", "C_CALL"]
arithmetic_commands = ["add", "sub", "neg", "eq", "gt", "lt", "and", "or", "not"]
comparison_types = ["EQ", "GT", "LT"]
true_or_end = ["TRUE", "END"]

# comparison_type should be from comparison_types
# this_label_true_or_end should be "TRUE" or "END" 
def get_comparison_label(file_stem, counter, comparison_type, this_label_true_or_end):
  return f"{file_stem}${comparison_type}_{this_label_true_or_end}.{counter}"

def get_flow_label(current_func, label_name):
  return f"${current_func}${label_name}"

def get_static_label(file_stem, counter):
  return f"{file_stem}.{counter}"

# Pop two objects from the stack. First popped (second operand, y) is in D, 
# second popped (first operand, x) is available as M.
# Note: if using this, don't change A before pushing.
# SP -= 1
# D = RAM[SP]
# SP -= 1
# M = RAM[SP]
def pop_two_objects_from_stack():
    return """
// pop first object from stack into D, second into M
@SP
AM=M-1
D=M
@SP
AM=M-1
"""

# Push result onto stack after doing math on result of popping two objects.
# Current stack pointer is assumed to be in A.
# Note: if using this, don't have changed A before calling this to push
# the result back to the stack.
# D=A
# @SP
# M=D+1
def push_result_to_stack():
    return """
// push result to stack
@SP
M=M+1
"""

def write_arithmetic(command, file_stem, counter):
  if command not in arithmetic_commands:
    print(f"Error: arithmetic command {command} unknown")
    exit(1)

  result = ""
  match command:
    # pop top two objects from stack, add them, then push
    # pop SP-=1, then returns object at RAM[SP]
    # push writes to RAM[SP], then SP+=1
    case "add":
      return "// add\n" + pop_two_objects_from_stack() + "M=D+M\n" + push_result_to_stack()
    case "sub":
      return "// sub\n" + pop_two_objects_from_stack() + "M=M-D\n" + push_result_to_stack()
    case "neg":
      return "// neg\n@SP\nA=M\n""M=-M\n"
    case "eq":
      return "// eq\n" + pop_two_objects_from_stack() + f"""
D=M-D
@{file_stem}$EQ_TRUE.{counter}
D;JEQ
@SP
A=M
M=0
@{file_stem}$EQ_END.{counter}
0;JMP
({file_stem}$EQ_TRUE.{counter})
@SP
A=M
M=-1
({file_stem}$EQ_END.{counter})
@SP
M=M+1
"""
      + push_result_to_stack()
    case "gt":
      return "// gt\n" + f"""
// pop Y into R13
@SP
AM=M-1
D=M
@R13
M=D
// pop X into R14
@SP
AM=M-1
D=M
@R14
M=D
// D currently holds X. Is X negative?
@{file_stem}$GT_XNEG.{counter}
D;JLT
// X is not negative. Is Y negative?
@R13
D=M
@{file_stem}$GT_SAMESIGN.{counter}
D;JGE
// X is not negative, but Y is negative. X > Y.
@SP
A=M
M=-1
@{file_stem}$GT_END.{counter}
0;JMP
({file_stem}$GT_XNEG.{counter})
// X is negative. Is Y negative?
@R13
D=M
@{file_stem}$GT_SAMESIGN.{counter}
D;JLT
// X is negative, but Y is not negative. X < Y.
@SP
A=M
M=0
@{file_stem}$GT_END.{counter}
0;JMP
({file_stem}$GT_SAMESIGN.{counter})
// either X and Y are both negative, or X and Y are both nonnegative.
// In either case, X > Y if X - Y > 0.
// D currently holds Y, need to get X then compute D=X-Y
@R14
D=M-D
@{file_stem}$GT_TRUE.{counter}
D;JGT
// X - Y <= 0. X is not greater than Y.
@SP
A=M
M=0
@{file_stem}$GT_END.{counter}
0;JMP
({file_stem}$GT_TRUE.{counter})
// X - Y > 0. X is greater than Y.
@SP
A=M
M=-1
({file_stem}$GT_END.{counter})
// Push the result by incrementing the stack pointer
@SP
M=M+1
"""
    case "lt":
      return "// lt\n" + f"""
// pop Y into R13
@SP
AM=M-1
D=M
@R13
M=D
// pop X into R14
@SP
AM=M-1
D=M
@R14
M=D
// D currently holds X. Is X negative?
@{file_stem}$LT_XNEG.{counter}
D;JLT
// X is not negative. Is Y negative?
@R13
D=M
@{file_stem}$LT_SAMESIGN.{counter}
D;JGE
// X is not negative, but Y is negative. X is not less than Y.
@SP
A=M
M=0
@{file_stem}$LT_END.{counter}
0;JMP
({file_stem}$LT_XNEG.{counter})
// X is negative. Is Y negative?
@R13
D=M
@{file_stem}$LT_SAMESIGN.{counter}
D;JLT
// X is negative, but Y is not negative. X < Y.
@SP
A=M
M=-1
@{file_stem}$LT_END.{counter}
0;JMP
({file_stem}$LT_SAMESIGN.{counter})
// either X and Y are both negative, or X and Y are both nonnegative.
// In either case, X < Y if X - Y < 0.
// D currently holds Y, need to get X then compute D=X-Y
@R14
D=M-D
@{file_stem}$LT_TRUE.{counter}
D;JLT
// X - Y >= 0. X is not less than Y.
@SP
A=M
M=0
@{file_stem}$LT_END.{counter}
0;JMP
({file_stem}$LT_TRUE.{counter})
// X - Y < 0. X is less than Y.
@SP
A=M
M=-1
({file_stem}$LT_END.{counter})
// Push the result by incrementing the stack pointer
@SP
M=M+1
"""
    case "and":
      return "// and\n" + pop_two_objects_from_stack() + "M=D&M\n" + push_result_to_stack()
    case "or":
      return "// or\n" + pop_two_objects_from_stack() + "M=D|M\n" + push_result_to_stack()
    case "not":
      return "// not\n@SP\nA=M\nM=!M\n"

def write_pushpop(command, segment, index):
    return ""

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_file", type=str, help="Input file containing vack vm code"
    )
    args = parser.parse_args()

    # First, open the file
    # list of vm commands
    lines_to_parse = []
    with open(args.input_file, "r") as input_file:
        for line in input_file:
            # remove leading and trailing whitespace
            line = line.strip()
            # ignore commented lines and empty lines, but add other lines for parsing
            if line.startswith("//") or line == "":
                continue
            # convert tabs to spaces and remove newline characters
            lines_to_parse.append(
                line.replace("\t", " ").replace("\n", "")
            )         

    # Globals for label generation
    # Variables for label generation
        
    current_file_stem = Path(__file__).stem
    current_function = ""
    label_counter = 0

    assembly_code = ""    

    # Goal: generate hack assembly code corresponding to each line of vack
    # virtual machine (vm) code. Must support the following instructions:
    #  push segment index
    #  pop segment index
    #  add
    #  sub
    #  neg
    #  eq
    #  gt
    #  lt
    #  and
    #  or
    #  not
    #
    # segments include the following:
    #  argument   function's argument variables
    #  local      function's local variables
    #  static     class variable associated with no particular object
    #  constant   (virtual ... just implement as literals)
    #  this       
    #  that
    #  pointer
    #  tmp
    #  uart (tx = uart index 0, rx = uart index 1)
    #
    # Memory layout
    #  0-16 registers
    #    0 SP
    #    1 LCL
    #    2 ARG
    #    3 THIS
    #    4 THAT
    # 5-12 temp
    #13-15 misc variables
    #  16-255 static variables
    #  256-2047 stack
    #  24577 UART
    #    UART[0] TX
    #    UART[1] RX
    #    UART[2] UARTSTAT (maybe omit??)
    for line in lines_to_parse:
        print(line)

    print(assembly_code)


if __name__ == "__main__":
    main()
