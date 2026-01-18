import argparse


def symbol(instruction):
    instruct_type = instruction_type(instruction)
    if instruct_type == "A_INSTRUCTION":
        return instruction.split("@")[-1]
    elif instruct_type == "L_INSTRUCTION":
        return instruction.split("(")[-1].split(")")[0]
    else:
        print("symbol called for C_INSTRUCTION")
        exit(1)


def dest(instruction):
    if instruction_type(instruction) != "C_INSTRUCTION":
        print("dest called for instruction that is not a C instruction")
        exit(1)
    if "=" in instruction:
        proposed_dest = instruction.split("=")[0]
        if proposed_dest in list(d_bits_from_dest_dict.keys()):
            return proposed_dest
        else:
            print(
                f"dest called for instruction {instruction} with unkknown destination {proposed_dest}"
            )
            exit(1)
    return "null"


def jump(instruction):
    if instruction_type(instruction) != "C_INSTRUCTION":
        print("jump called for instruction that is not a C instruction")
        exit(1)
    if ";" in instruction:
        proposed_jump = instruction.split(";")[1]
        if proposed_jump in list(j_bits_from_jump_dict.keys()):
            return proposed_jump
        else:
            print(f"unknown jump {proposed_jump}")
            exit(1)
    return "null"


def comp(instruction):
    if instruction_type(instruction) != "C_INSTRUCTION":
        print("comp called for instruction that is not a C instruction")
        exit(1)
    if "=" in instruction:
        instruction = instruction.split("=")[1]
    if ";" in instruction:
        if "M" in instruction.split(";")[0]:
            print("jumps not permitted when instruction contains M")
            exit(1)
        instruction = instruction.split(";")[0]
    if instruction in list(c_bits_from_comp_dict.keys()):
        return instruction
    else:
        print(f"unknown computation {instruction}")
        exit(1)


def decimal_to_binary_string(decimal_string):
    # Max number allowed: 2^15-1 = 32767
    if int(decimal_string) > 32767:
        print(f"address or literal {decimal_string} larger than 32767")
        exit(1)
    # First digit always 0; pad to 15 digits
    # bin() converts integer to binary string beginning with '0b'
    # [2:] skips the '0b' prefix. zfill pads to 15 digits
    return "0" + bin(int(decimal_string))[2:].zfill(15)


c_bits_from_comp_dict = {
    "0": "101010",
    "1": "111111",
    "-1": "111010",
    "D": "001100",
    "A": "110000",
    "M": "110000",
    "!D": "001101",
    "!A": "110001",
    "!M": "110001",
    "-D": "001111",
    "-A": "110011",
    "-M": "110011",
    "D+1": "011111",
    "A+1": "110111",
    "M+1": "110111",
    "D-1": "001110",
    "A-1": "110010",
    "M-1": "110010",
    "D+A": "000010",
    "D+M": "000010",
    "D-A": "010011",
    "D-M": "010011",
    "A-D": "000111",
    "M-D": "000111",
    "D&A": "000000",
    "D&M": "000000",
    "D|A": "010101",
    "D|M": "010101",
}

d_bits_from_dest_dict = {
    "null": "000",
    "M": "001",
    "D": "010",
    "DM": "011",
    "MD": "011",
    "A": "100",
    "AM": "101",
    "MA": "101",
    "AD": "110",
    "DA": "110",
    "ADM": "111",
    "AMD": "111",
    "MAD": "111",
    "MDA": "111",
    "DAM": "111",
    "DMA": "111",
}

j_bits_from_jump_dict = {
    "null": "000",
    "JGT": "001",
    "JEQ": "010",
    "JGE": "011",
    "JLT": "100",
    "JNE": "101",
    "JLE": "110",
    "JMP": "111",
}


def compute_instruction_to_binary_string(instruction):
    if instruction_type(instruction) != "C_INSTRUCTION":
        print(
            "comput_instruction_to_binary_string received an instruction that is not a compute instruction"
        )
        exit(1)
    comp_text = comp(instruction)
    dest_text = dest(instruction)
    jump_text = jump(instruction)
    instruction = instruction.split("=")[-1]
    instruction = instruction.split(";")[0]
    a_bit = "1" if "M" in instruction else "0"
    return (
        "111"
        + a_bit
        + c_bits_from_comp_dict[comp_text]
        + d_bits_from_dest_dict[dest_text]
        + j_bits_from_jump_dict[jump_text]
    )


def instruction_to_binary_string(instruction):
    if instruction_type(instruction) == "A_INSTRUCTION":
        # No symbol support just yet... it's just a number
        return decimal_to_binary_string(symbol(instruction))
    elif instruction_type(instruction) == "L_INSTRUCTION":
        return


def instruction_type(instruction):
    if instruction.startswith("@"):
        return "A_INSTRUCTION"
    elif instruction.startswith("(") and instruction.endswith(")"):
        return "L_INSTRUCTION"
    else:
        return "C_INSTRUCTION"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_file", type=str, help="Input file containing hack assembly code"
    )
    args = parser.parse_args()

    # First, open the file
    # list of assembly commands
    lines_to_parse = []
    with open(args.input_file, "r") as input_file:
        for line in input_file:
            # remove leading and trailing whitespace
            line = line.strip()
            # ignore commented lines and empty lines, but add other lines for parsing
            line = line.split("//", 1)[0].strip()
            if not line:
                continue
            # remove all spaces and tabs and newlines
            lines_to_parse.append(
                line.replace(" ", "").replace("\t", "").replace("\n", "")
            )

    symbol_table = {
        "R0": 0,
        "R1": 1,
        "R2": 2,
        "R3": 3,
        "R4": 4,
        "R5": 5,
        "R6": 6,
        "R7": 7,
        "R8": 8,
        "R9": 9,
        "R10": 10,
        "R11": 11,
        "R12": 12,
        "R13": 13,
        "R14": 14,
        "R15": 15,
        "SCREEN": 16384,
        "KBD": 24576,
        "UART": 24577,
        "TX": 24577,
        "RX": 24578,
        "UARTSTAT": 24579,
        "SP": 0,
        "LCL": 1,
        "ARG": 2,
        "THIS": 3,
        "THAT": 4,
        "TEMP": 5,
    }
    address_of_next_free_ram_for_variable = 16
    object_code = ""
    line_number_of_latest_a_or_c = -1
    # First pass: find symbols and store them in the symbol table
    for line in lines_to_parse:
        instruct_type = instruction_type(line)
        if instruct_type == "A_INSTRUCTION" or instruct_type == "C_INSTRUCTION":
            line_number_of_latest_a_or_c += 1
        if instruct_type == "L_INSTRUCTION":
            symbol_table[symbol(line)] = line_number_of_latest_a_or_c + 1
    # Second pass: return machine code
    for line in lines_to_parse:
        instruct_type = instruction_type(line)
        decimal_address = None
        if instruct_type == "A_INSTRUCTION":
            symbol_text = symbol(line)
            # if symbol_text is alrady in the symbol table, just
            # replace it with its value
            if symbol_text in symbol_table:
                decimal_address = symbol_table[symbol_text]
            # if symbol_text is a number, it is a decimal address already;
            # just use it
            elif symbol_text.isdigit():
                decimal_address = symbol_text
            # if symbol_text is not a number yet not in the symbol table,
            # it is a new variable. Add it to the symbol table and
            # assign it the next available RAM address
            else:
                decimal_address = address_of_next_free_ram_for_variable
                address_of_next_free_ram_for_variable += 1
                symbol_table[symbol_text] = decimal_address
            object_code += decimal_to_binary_string(decimal_address) + "\n"
        elif instruct_type == "C_INSTRUCTION":
            object_code += compute_instruction_to_binary_string(line) + "\n"
        elif instruct_type == "L_INSTRUCTION":
            pass
        else:
            print(f"unknown instruction type {instruct_type}")
            exit(1)

    print(object_code)

    # print("\n\n\n\n")
    # for key in symbol_table:
    #   print(f"{key} -> {symbol_table[key]}")


if __name__ == "__main__":
    main()
