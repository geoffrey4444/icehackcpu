import argparse
from dataclasses import dataclass
from pathlib import Path

keywords = [
    "class",
    "constructor",
    "function",
    "method",
    "field",
    "static",
    "var",
    "int",
    "char",
    "boolean",
    "void",
    "true",
    "false",
    "null",
    "this",
    "let",
    "do",
    "if",
    "else",
    "while",
    "return",
]

symbols = [
    "{",
    "}",
    "(",
    ")",
    "[",
    "]",
    ".",
    ",",
    ";",
    "+",
    "-",
    "*",
    "/",
    "&",
    "|",
    "<",
    ">",
    "=",
    "~",
]

whitespace_characters = [" ", "\t", "\n", "\r"]

newline_characters = ["\n", "\r"]

token_types = [
    "KEYWORD",
    "SYMBOL",
    "INTEGER_CONSTANT",
    "STRING_CONSTANT",
    "IDENTIFIER" "KEYWORD_OR_IDENTIFIER",
]


# Dataclass to hold each token with its type
@dataclass
class Token:
    type: str
    value: str


def get_token_type(first_char_of_token):
    if first_char_of_token in symbols:
        return "SYMBOL"
    elif first_char_of_token.isdigit():
        return "INTEGER_CONSTANT"
    elif first_char_of_token == '"':
        return "STRING_CONSTANT"
    else:
        return "KEYWORD_OR_IDENTIFIER"


def should_add_character_to_current_token(character, current_token):
    if current_token.type == "INTEGER_CONSTANT":
        return character.isdigit()
    elif current_token.type == "STRING_CONSTANT":
        return (character != '"') and (character not in newline_characters)
    elif current_token.type == "SYMBOL":
        return False
    elif current_token.type == "KEYWORD_OR_IDENTIFIER":
        return not (
            (character in symbols)
            or (character.isdigit())
            or (character == '"')
            or character in whitespace_characters
        )


def is_token_keyword(token):
    return token.type == "KEYWORD_OR_IDENTIFIER" and token.value in keywords


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_files", type=str, nargs="+", help="Input files containing vack vm code"
    )
    args = parser.parse_args()

    for input_file in args.input_files:
        current_file_path = Path(input_file)
        current_file_stem = current_file_path.stem
        # Get directory of input_file
        current_file_directory = current_file_path.parent
        # Get output file path
        output_file_path = current_file_directory / f"{current_file_stem}.vm"
        print(f"Processing {current_file_stem}.jack -> {current_file_stem}.vm")
        with open(input_file, "r") as f:
            jack_code = f.read()

    tokens = []
    current_token = None
    current_token_type = None
    in_comment_until_next_newline = False
    in_comment_until_next_end_of_comment_string = False

    # loop over characters in jack_code
    for i, c in enumerate(jack_code):
        if not current_token:
            # Not currently assembling a token. Need to determine
            # if current character starts a new token  .
            # First, check if we are already in a comment.
            if in_comment_until_next_newline:
                # We are in a comment that ends at the next newline
                # Do not start a new token, but check if this char ends the comment
                if c in newline_characters:
                    in_comment_until_next_newline = False
                continue
            if in_comment_until_next_end_of_comment_string:
                # We are in a comment that ends at the next */ . Do not start
                # a new token, but check if this char ends the comment.
                if i > 0:
                    if f"{jack_code[i-1]}{c}" == "*/":
                        in_comment_until_next_end_of_comment_string = False
                continue
            # Next, check if this character starts a new comment
            if i < len(jack_code) - 1:
                # Check if this character starts a comment
                if f"{c}{jack_code[i+1]}" == "/*":
                    in_comment_until_next_end_of_comment_string = True
                    continue
                if f"{c}{jack_code[i+1]}" == "//":
                    in_comment_until_next_newline = True
                    continue
            # This character is not in a comment or starting a comment.
            # Is it whitespace? If so, it cannot start a new token.
            if c in whitespace_characters:
                continue

            # OK, this character is not part of a comment, does not start
            # a new comment, and is not whitespace. Therefore, this
            # character starts a new token. The first character
            # determines the token type, except if keyword or identifier,
            # can only tell which after complete token is known
            current_token_type = get_token_type(c)
            current_token = Token(type=current_token_type, value=f"{c}")
            if current_token_type == "SYMBOL":
                # Token is a single-character token
                tokens.append(current_token)
                current_token = None
            elif current_token_type == "STRING_CONSTANT":
                # Do not include double-quote character in the string token
                current_token.value = ""
        else:
            # Is the current character part of the current token?
            if should_add_character_to_current_token(c, current_token):
                current_token.value += c
                continue
            else:
                # Is the completed token KEYWORD_OR_IDENTIFIER? If so, decide which
                if current_token.type == "KEYWORD_OR_IDENTIFIER":
                    if is_token_keyword(current_token):
                        current_token.type = "KEYWORD"
                    else:
                        current_token.type = "IDENTIFIER"

                # previous character completed a token; add it to list of tokens
                tokens.append(current_token)

                # Is the current token a STRING_CONSTANT?
                if current_token.type == "STRING_CONSTANT":
                    if c == '"':
                        # String constant completed; ignore closing double-quote;
                        # start new token on next character (if any) instead
                        current_token = None
                        continue
                    elif c in newline_characters:
                        # Ignore newline character in string constant
                        continue

                current_token = None
                # Does current character start a new token?
                # Just finished a token, so not currently in a comment.
                # Does this char start a comment or is it whitespace?
                # If so, then don't start a new token.
                # Otherwise, start a new token.
                if i < len(jack_code) - 1:
                    if f"{c}{jack_code[i+1]}" == "/*":
                        in_comment_until_next_end_of_comment_string = True
                        continue
                    if f"{c}{jack_code[i+1]}" == "//":
                        in_comment_until_next_newline = True
                        continue
                if c in whitespace_characters:
                    continue
                else:
                    # Start a new token
                    current_token_type = get_token_type(c)
                    current_token = Token(type=current_token_type, value=f"{c}")
                    if current_token_type == "SYMBOL":
                        # Token is a single-character token
                        tokens.append(current_token)
                        current_token = None
                    elif current_token_type == "STRING_CONSTANT":
                        # Do not include double-quote character in the string token
                        current_token.value = ""

    for token in tokens:
        print(f"{token.type} {token.value}")
    print(f"Total tokens: {len(tokens)}")


if __name__ == "__main__":
    main()
