import argparse
from pathlib import Path

arithmetic_commands = ["add", "sub", "neg", "eq", "gt", "lt", "and", "or", "not"]
pushpop_commands = ["push", "pop"]
comparison_types = ["EQ", "GT", "LT"]
true_or_end = ["TRUE", "END"]
segments = [
    "argument",
    "local",
    "static",
    "constant",
    "this",
    "that",
    "pointer",
    "temp",
    "uart",
]


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
# Current stack pointer is assumed to be in A, and result should already
# be written at the current stack pointer address. This just increments
# the stack pointer.
# Note: if using this, don't have changed A before calling this to push
# the result back to the stack.
# @SP
# M=M+1
def push_result_to_stack():
    return """
// push result to stack
@SP
M=M+1
"""


# TODO: Fix push/pop should use the standard pattern...my version
# seems to be correct but not the "clean" way that's easier to read...
# this is just for the local/argument/this/that segments...
# and I think I could get away with only R13, not R13 and R14, with this fix...

base_address_of_segments = {
    "argument": "ARG",
    "local": "LCL",
    "this": "THIS",
    "that": "THAT",
    "pointer": "THIS",
    "temp": "R5",
    "uart": "UART",
}


# Get the address to push or pop to. For most segments, the address
# is simply the base segment + the index. But for static variables,
# the address is actually given by a label.
def get_base_address_for_push_pop(segment, index, file_stem):
    if segment == "static":
        return get_static_label(file_stem, index)
    else:
        base_address = base_address_of_segments[segment]
        return f"{base_address}"


def write_pushpop(command, segment, index, file_stem):
    if (segment == "constant") and (int(index) > 32767):
        print(f"Error: cannot push constant {index} because it is larger than 32767")
        exit(1)
    if int(index) < 0:
        print(f"Error: {index} is negative")
        exit(1)
    if (segment == "pointer" and int(index) > 1) or (
        segment == "temp" and int(index) > 7
    ):
        print(f"Error: cannot push {segment} {index} because index is out of range")
        exit(1)
    if segment == "uart" and int(index) > 2:
        print(f"Error: cannot push {segment} {index} because index is out of range")
        exit(1)
    result = f"// {command} {segment} {index}\n"
    if command == "push":
        if segment != "static":
            result += f"@{index}\nD=A\n"
        if segment != "constant":
            result += f"@{get_base_address_for_push_pop(segment, index, file_stem)}\n"
            if segment in ["local", "argument", "this", "that"]:
                result += f"A=M\n"
            if segment != "static":
                result += f"A=D+A\n"
            result += f"D=M\n"
        return (
            result
            + """
@SP
A=M
M=D
@SP
M=M+1
"""
        )
    elif command == "pop":
        if segment == "constant":
            print(f"Error: cannot pop to constant segment")
            exit(1)
        if segment != "static":
            result += f"@{index}\nD=A\n"
        result += f"@{get_base_address_for_push_pop(segment, index, file_stem)}\n"
        if segment in ["local", "argument", "this", "that"]:
            result += f"A=M\n"
        if segment != "static":
            result += f"A=D+A\n"
        result += f"D=A\n@R13\nM=D\n"
        return (
            result
            + f"""
@SP
AM=M-1
D=M
@R13
A=M
M=D
"""
        )
    else:
        print(f"Error: unknown command {command}")
        exit(1)


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
            return (
                "// add\n"
                + pop_two_objects_from_stack()
                + "M=D+M\n"
                + push_result_to_stack()
            )
        case "sub":
            return (
                "// sub\n"
                + pop_two_objects_from_stack()
                + "M=M-D\n"
                + push_result_to_stack()
            )
        case "neg":
            return "// neg\n@SP\nA=M-1\n" "M=-M\n"
        case "eq":
            return (
                "// eq\n"
                + pop_two_objects_from_stack()
                + f"""
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
            )

        case "gt":
            return (
                "// gt\n"
                + f"""
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
            )
        case "lt":
            return (
                "// lt\n"
                + f"""
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
            )
        case "and":
            return (
                "// and\n"
                + pop_two_objects_from_stack()
                + "M=D&M\n"
                + push_result_to_stack()
            )
        case "or":
            return (
                "// or\n"
                + pop_two_objects_from_stack()
                + "M=D|M\n"
                + push_result_to_stack()
            )
        case "not":
            return "// not\n@SP\nA=M-1\nM=!M\n"


# Note: LCL, ARG, THIS, THAT are made up addresses for testing.
# In a real code, these pointers only take a valid value via call/return
def write_prolog():
    return """
// prolog
// set SP to 256, start of stack (stack grows up to higher addresses)
@256
D=A
@SP
M=D
@3000
D=A
@LCL
M=D
@3010
D=A
@ARG
M=D
@3020
D=A
@THIS
M=D
@3030
D=A
@THAT
M=D
"""


def write_epilog():
    return """
// epilog
// infinite loop when finished
(INFINITE_LOOP_PROGRAM_COMPLETE)
@INFINITE_LOOP_PROGRAM_COMPLETE
0;JMP
"""


def write_function(function_name, function_number_of_local_variables):
    result = f"// function {function_name} {function_number_of_local_variables}\n"
    result += f"({function_name})\n"
    for _ in range(int(function_number_of_local_variables)):
        result += write_pushpop("push", "constant", "0", "")
    return result


def write_call(
    function_to_call, function_number_of_arguments, current_function, call_counter
):
    result = f"// call {function_to_call} {function_number_of_arguments}\n"
    return_address = f"{current_function}$ret.{call_counter}"
    push_d_to_stack = """\
@SP
A=M
M=D
@SP
M=M+1
"""
    # push return address
    result += f"@{return_address}\nD=A\n{push_d_to_stack}"
    # push LCL
    result += f"@LCL\nD=M\n{push_d_to_stack}"
    # push ARG
    result += f"@ARG\nD=M\n{push_d_to_stack}"
    # push THIS
    result += f"@THIS\nD=M\n{push_d_to_stack}"
    # push THAT
    result += f"@THAT\nD=M\n{push_d_to_stack}"
    # ARG = SP - 5 - function_number_of_arguments
    result += f"""
@SP
D=M
@5
D=D-A
@{function_number_of_arguments}
D=D-A
@ARG
M=D
"""
    # LCL = SP
    result += """
@SP
D=M
@LCL
M=D
"""
    # goto function_name
    result += f"""
@{function_to_call}
0;JMP
"""
    # (return_address)
    result += f"({return_address})\n"

    return result

def write_return():
    return "@VM_RETURN\n0;JMP\n"

def write_common_return_code():
    # frame = LCL (R13)
    # return_address = *(frame - 5) (R14)
    # *arg = pop() (overwrite first input parameter with function result)
    # SP = ARG+1 (stack pointer is right after returned result)
    # THAT = *(frame - 1)
    # THIS = *(frame - 2)
    # ARG = *(frame - 3)
    # LCL = *(frame - 4)
    # goto return_address

    result = """
(VM_RETURN)
// frame = LCL (R13)
@LCL
D=M
@R13
M=D
// return_address = *(frame - 5) (R14)
@5
A=D-A
D=M
@R14
M=D
// pop return value into *(ARG[0])
@SP
AM=M-1
D=M
@ARG
A=M
M=D
// SP = ARG+1 (stack pointer is right after returned result)
@ARG
D=M+1
@SP
M=D
// THAT = *(frame - 1)
@R13
D=M
@1
A=D-A
D=M
@THAT
M=D
// THIS = *(frame - 2)
@R13
D=M
@2
A=D-A
D=M
@THIS
M=D
// ARG = *(frame - 3)
@R13
D=M
@3
A=D-A
D=M
@ARG
M=D
// LCL = *(frame - 4)
@R13
D=M
@4
A=D-A
D=M
@LCL
M=D
// goto return_address
@R14
A=M
0;JMP
"""

    return result


def write_label(label_name, current_function):
    label = f"{current_function}${label_name}" if current_function else label_name
    return f"// label {label_name}\n({label})\n"


def write_goto(label_name, current_function):
    label = f"{current_function}${label_name}" if current_function else label_name
    return f"// goto {label_name}\n@{label}\n0;JMP\n"


def write_if_goto(label_name, current_function):
    label = f"{current_function}${label_name}" if current_function else label_name
    return f"""
// if-goto {label_name}
@SP
AM=M-1
D=M
@{label}
D;JNE
"""

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_files", type=str, nargs="+", help="Input files containing vack vm code"
    )
    parser.add_argument(
        "--write_prolog_and_epilog",
        action="store_true",
        help="Write prolog and epilog for testing (i.e. if no sys.Init)",
    )
    args = parser.parse_args()

    # Globals for label generation
    current_function = ""
    label_counter = 0
    call_counter = 0

    os_prolog = """
// Set stack pointer to 256, start of stack (stack grows to higher addresses)
@256
D=A
@SP
M=D

// Call Sys.init
@Sys.init
0;JMP

"""
    assembly_code = write_prolog() if args.write_prolog_and_epilog else os_prolog

    # loop over input files
    for input_file in args.input_files:
        # First, open the file
        # list of vm commands
        lines_to_parse = []
        with open(input_file, "r") as opened_input_file:
            for line in opened_input_file:
                # remove leading and trailing whitespace
                line = line.strip()
                # ignore commented lines and empty lines, but add other
                # lines for parsing
                line = line.split("//", 1)[0].strip()
                if not line:
                    continue
                # convert tabs to spaces and remove newline characters
                lines_to_parse.append(line.replace("\t", " ").replace("\n", ""))

        current_file_stem = Path(input_file).stem

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
        # 13-15 misc variables
        #  16-255 static variables
        #  256-2047 stack
        #  24577 UART
        #    UART[0] TX
        #    UART[1] RX
        #    UART[2] UARTSTAT (maybe omit??)
        for line in lines_to_parse:
            # figure out type of command
            command_words = line.split()
            command_name = command_words[0].lower()
            if command_name in pushpop_commands:
                segment = command_words[1].lower()
                index = command_words[2]
                assembly_code += write_pushpop(
                    command_name, segment, index, current_file_stem
                )
            elif command_name in arithmetic_commands:
                assembly_code += write_arithmetic(
                    command_name, current_file_stem, label_counter
                )
                label_counter += 1
            elif command_name == "function":
                function_name = command_words[1]
                current_function = function_name
                call_counter = 0
                function_number_of_local_variables = command_words[2]
                assembly_code += write_function(
                    function_name, function_number_of_local_variables
                )
            elif command_name == "call":
                function_to_call = command_words[1]
                function_number_of_arguments = command_words[2]
                assembly_code += write_call(
                    function_to_call,
                    function_number_of_arguments,
                    current_function,
                    call_counter,
                )
                call_counter += 1
            elif command_name == "return":
                assembly_code += write_return()
            elif command_name == "label":
                label_name = command_words[1]
                assembly_code += write_label(label_name, current_function)
            elif command_name == "goto":
                label_name = command_words[1]
                assembly_code += write_goto(label_name, current_function)
            elif command_name == "if-goto":
                label_name = command_words[1]
                assembly_code += write_if_goto(label_name, current_function)
            else:
                print(f"Error: unknown command {command_name}")
                exit(1)
    assembly_code += write_common_return_code()
    if args.write_prolog_and_epilog:
        assembly_code += write_epilog()
    print(assembly_code)


if __name__ == "__main__":
    main()
