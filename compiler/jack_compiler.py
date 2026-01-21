from __future__ import annotations
import argparse
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal, Optional, Union
import xml.etree.ElementTree as et

# Global constants

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

keyword_constants = ["true", "false", "null", "this"]

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

binary_operators = [
    "+",
    "-",
    "*",
    "/",
    "&",
    "|",
    "<",
    ">",
    "=",
]

unary_operators = [
    "-",
    "~",
]

whitespace_characters = [" ", "\t", "\n", "\r"]

newline_characters = ["\n", "\r"]

TokenType = Literal[
    "keyword",
    "symbol",
    "integerConstant",
    "stringConstant",
    "identifier",
    "keyword_or_identifier",
]


# Dataclasses for tokens and program structure


# Token
@dataclass
class Token:
    type: TokenType
    value: str


# Term and expression related classes
@dataclass
class Expression:
    # first term
    first_term: Term
    # other terms: list of pairs of symbol-type tokens representing
    # binary operators (+|-|*|/|&|||<|>|=)
    # a list, possibly empty
    other_terms: list[tuple[Token, Term]] = field(default_factory=list)


@dataclass
class ExpressionList:
    # a list of expressions
    expressions: list[Expression] = field(default_factory=list)


@dataclass
class IntegerConstant:
    # a token of type integerConstant specifying the constant
    token: Token


@dataclass
class StringConstant:
    # a token of type stringConstant specifying the constant
    token: Token


@dataclass
class KeywordConstant:
    # a token of type keyword specifying the constant
    # must be one of true, false, null, this
    token: Token


@dataclass
class VarName:
    # a token of type identifier specifying the variable name
    token: Token


@dataclass
class ArrayAccess:
    # a token of type identifier specifying the array name
    array_name_token: Token
    # an expression specifying the index
    array_index: Expression


@dataclass
class ParentheticalExpression:
    # expression representing the expression enclosed in ()
    expression: Expression


@dataclass
class UnaryOpTerm:
    # a token of type symbol specifying the unary op
    op_token: Token
    # a term to operate on
    term_to_operate_on: Term


@dataclass
class SubroutineCall:
    # a token of type identifier naming the subroutine
    subroutine_name_token: Token
    # an expression list specifying the arguments
    expression_list: ExpressionList
    # receiver (class name or var name; token of type identifier)
    receiver_name_token: Optional[Token] = None


Term = Union[
    IntegerConstant,
    StringConstant,
    KeywordConstant,
    VarName,
    ArrayAccess,
    ParentheticalExpression,
    UnaryOpTerm,
    SubroutineCall,
]

# Statement related classes


@dataclass
class LetStatement:
    var_name_token: Token
    expression: Expression
    array_index: Optional[Expression] = None


@dataclass
class DoStatement:
    subroutine_call: SubroutineCall


@dataclass
class ReturnStatement:
    expression: Optional[Expression] = None


@dataclass
class IfStatement:
    condition: Expression
    then_statements: Statements
    else_statements: Optional[Statements] = None


@dataclass
class WhileStatement:
    condition: Expression
    body: Statements


Statement = Union[
    LetStatement, DoStatement, ReturnStatement, IfStatement, WhileStatement
]


@dataclass
class Statements:
    statements: list[Statement] = field(default_factory=list)


# Program structure related classes


@dataclass
class VariableDeclaration:
    # keyword token (int, char, or boolean) or identifier (class name)
    type_token: Token
    # variable name token(s)
    first_var_name_token: Token
    other_var_name_tokens: list[Token] = field(default_factory=list)


@dataclass
class SubroutineBody:
    variable_declarations: list[VariableDeclaration] = field(default_factory=list)
    statements: Statements = field(default_factory=Statements)


@dataclass
class Parameter:
    type_token: Token
    variable_name_token: Token


@dataclass
class ParameterList:
    parameters: list[Parameter] = field(default_factory=list)


@dataclass
class SubroutineDeclaration:
    # keyword token (constructor or function or method)
    subroutine_kind_token: Token
    # return type: keyword (void, int, char, or boolean) or identifier (class name)
    return_type_token: Token
    # subroutine name token
    name_token: Token
    # parameter list
    parameter_list: ParameterList
    # subroutine body
    subroutine_body: SubroutineBody


@dataclass
class ClassVariableDeclaration:
    # keyword token (static or field)
    class_variable_kind_token: Token
    # type token: keyword (int, char, or boolean) or identifier (class name)
    type_token: Token
    # variable name token(s)
    first_var_name_token: Token
    other_var_name_tokens: list[Token] = field(default_factory=list)


@dataclass
class Class:
    name_token: Token
    class_variable_declarations: list[ClassVariableDeclaration] = field(
        default_factory=list
    )
    subroutine_declarations: list[SubroutineDeclaration] = field(default_factory=list)


# Functions for tokenizing


def get_token_type(first_char_of_token):
    if first_char_of_token in symbols:
        return "symbol"
    elif first_char_of_token.isdigit():
        return "integerConstant"
    elif first_char_of_token == '"':
        return "stringConstant"
    else:
        return "keyword_or_identifier"


def should_add_character_to_current_token(character, current_token):
    if current_token.type == "integerConstant":
        return character.isdigit()
    elif current_token.type == "stringConstant":
        return (character != '"') and (character not in newline_characters)
    elif current_token.type == "symbol":
        return False
    elif current_token.type == "keyword_or_identifier":
        return not (
            (character in symbols)
            or (character.isdigit())
            or (character == '"')
            or character in whitespace_characters
        )


def is_token_keyword(token):
    return token.type == "keyword_or_identifier" and token.value in keywords


# function to tokenize code (a stream of characters)
# basically, turn list of characters into a list of words
# input: code (a string)
# output: list of tokens
def tokenize_code(jack_code):
    tokens = []
    current_token = None
    current_token_type = None
    in_comment_until_next_newline = False
    in_comment_until_next_end_of_comment_string = False

    # Tokenize the jack code
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
            if current_token_type == "symbol":
                # Token is a single-character token
                tokens.append(current_token)
                current_token = None
            elif current_token_type == "stringConstant":
                # Do not include double-quote character in the string token
                current_token.value = ""
        else:
            # Is the current character part of the current token?
            if should_add_character_to_current_token(c, current_token):
                current_token.value += c
                continue
            else:
                # Is the completed token keyword_or_identifier? If so, decide which
                if current_token.type == "keyword_or_identifier":
                    if is_token_keyword(current_token):
                        current_token.type = "keyword"
                    else:
                        current_token.type = "identifier"

                # previous character completed a token; add it to list of tokens
                tokens.append(current_token)

                # Is the current token a stringConstant?
                if current_token.type == "stringConstant":
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
                    if current_token_type == "symbol":
                        # Token is a single-character token
                        tokens.append(current_token)
                        current_token = None
                    elif current_token_type == "stringConstant":
                        # Do not include double-quote character in the string token
                        current_token.value = ""
    return tokens


# function tokenize code from one file
# Input: file_path = path to a .jack  file
# Output: list of tokens
def tokenize_code_from_file(file_path):
    with open(file_path, "r") as f:
        jack_code = f.read()
        tokens = tokenize_code(jack_code)
        return tokens


# Functions related to xml output
def xml_from_token_list(tokens):
    root = et.Element("tokens")
    for token in tokens:
        token_element = et.SubElement(root, token.type)
        token_element.text = f" {token.value} "
    et.indent(root, space="")
    xml_string = et.tostring(
        root, encoding="utf-8", method="xml", xml_declaration=False
    ).decode("utf-8")
    return xml_string


# Class for compiling program structure


@dataclass
class JackCompiler:
    tokens: list[Token]
    current_token_index: int = 0

    def current_token(self) -> Token:
        return self.tokens[self.current_token_index]

    def next_token(self) -> Token:
        if self.has_next_token():
            return self.tokens[self.current_token_index + 1]
        else:
            raise ValueError("Next token requested, but no next token available")

    def has_next_token(self) -> bool:
        return self.current_token_index + 1 < len(self.tokens)

    def advance(self):
        self.current_token_index += 1

    # term: integerConstant | stringConstant | keywordConstant | varName
    # | varName '[' expression']' | '(' expression ')' | (unaryOp term)
    # | subroutineCall
    def compile_term(self) -> Term:
        # current token determines term type, expect when we must also look
        # ahead one token
        current_token = self.current_token()
        if current_token.type == "integerConstant":
            self.advance()
            return IntegerConstant(token=current_token)
        elif current_token.type == "stringConstant":
            self.advance()
            return StringConstant(token=current_token)
        elif current_token.type == "keyword":
            if current_token.value in keyword_constants:
                self.advance()
                return KeywordConstant(token=current_token)
            else:
                raise ValueError(
                    f"Keyword {current_token.value} is not a keyword constant"
                )
        elif current_token.type == "symbol":
            if current_token.value == "(":
                self.advance()  # advance past "("
                result = ParentheticalExpression(expression=self.compile_expression())
                if self.current_token().value == ")":
                    self.advance()
                    return result
                else:
                    raise ValueError(
                        "Expected closing ) after ( in paranethetical expression"
                    )
            elif current_token.value in unary_operators:
                unary_op_token = current_token
                self.advance()
                return UnaryOpTerm(
                    op_token=unary_op_token, term_to_operate_on=self.compile_term()
                )
            else:
                raise ValueError(f"Unexpected symbol {current_token.value} in term")
        elif current_token.type == "identifier":
            # Need to look ahead 1 token to decide what's next
            # Possibilities:
            #   1. Next token is '[' -- ArrayAccess
            #   2. Next token is '(' -- SubroutineCall
            #   3. Next token is not a symbol -- VarName
            if not (self.has_next_token()):
                self.advance()
                return VarName(token=current_token)
            if self.next_token().type != "symbol":
                self.advance()  # advance past identifier token
                return VarName(token=current_token)
            else:
                if self.next_token().value == "[":
                    array_name_token = current_token
                    self.advance()  # consumed identifier; current token is now "["
                    if self.current_token().value != "[":
                        raise ValueError(
                            f"Expected [ after identifier {current_token.value} in array access"
                        )
                    self.advance()  # consumed "("; current token is now first token of expression
                    array_index = self.compile_expression()
                    if self.current_token().value == "]":
                        self.advance()
                        return ArrayAccess(
                            array_name_token=array_name_token, array_index=array_index
                        )
                    else:
                        raise ValueError("Expected closing ] after [ in array access")
                elif self.next_token().value == "(":
                    return self.compile_subroutine_call()
                elif self.next_token().value == ".":
                    return self.compile_subroutine_call()
                else:
                    raise ValueError(
                        f"Unexpected symbol {self.next_token().value} after identifier {current_token.value}"
                    )

    def compile_subroutine_call(self) -> SubroutineCall:
        subroutine_name_token = self.current_token()
        receiver_name_token = None
        if subroutine_name_token.type != "identifier":
            raise ValueError(
                f"Subroutine name token {subroutine_name_token.value} is type {subroutine_name_token.type}, not identifier"
            )
        self.advance()
        # Two possibilities:
        #  1. Next token is "(" -- implicitly call method of this
        #  2. Next token is "." -- call method of class or object
        if self.current_token().value == ".":
            self.advance()  # advance past "."
            receiver_name_token = subroutine_name_token
            subroutine_name_token = self.current_token()
            if subroutine_name_token.type != "identifier":
                raise ValueError(
                    f"Subroutine name token {subroutine_name_token.value} is type {subroutine_name_token.type}, not identifier"
                )
            self.advance()  # advance past subroutine name token
        if self.current_token().value == "(":
            self.advance()  # advance past "("
            if self.current_token().value == ")":
                self.advance()  # advance past ")"
                return SubroutineCall(
                    subroutine_name_token=subroutine_name_token,
                    receiver_name_token=receiver_name_token,
                    expression_list=ExpressionList(expressions=[]),
                )
            else:
                expression_list = self.compile_expression_list()
                if self.current_token().value != ")":
                    raise ValueError(
                        "Expected closing ) after ( in expression list in subroutine call"
                    )
                self.advance()  # advance past ")"
                return SubroutineCall(
                    subroutine_name_token=subroutine_name_token,
                    receiver_name_token=receiver_name_token,
                    expression_list=expression_list,
                )
        else:
            raise ValueError(
                f"Expected ( after subroutine name {subroutine_name_token.value}"
            )

    # Don't call this function if the expression list is empty
    # Insead, in what would have bene the caller, recognize the list
    # is empty (e.g. by finding ")" right away)
    def compile_expression_list(self) -> ExpressionList:
        expressions = [self.compile_expression()]
        while self.current_token().value == ",":
            self.advance()  # advance past ","
            expressions.append(self.compile_expression())
        return ExpressionList(expressions=expressions)

    def compile_expression(self) -> Expression:
        # Compile term and advance to next token not part of that term
        # Note: compile_term() advances to appropriate token
        expression = Expression(first_term=self.compile_term())
        while (
            self.current_token().type == "symbol"
            and self.current_token().value in binary_operators
        ):
            operator_token = self.current_token()
            self.advance()
            next_term = self.compile_term()
            expression.other_terms.append((operator_token, next_term))
        return expression


# main function: drive compilation


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_files", type=str, nargs="+", help="Input files containing vack vm code"
    )
    args = parser.parse_args()

    tokens = []
    for input_file in args.input_files:
        current_file_path = Path(input_file)
        current_file_stem = current_file_path.stem
        # Get directory of input_file
        current_file_directory = current_file_path.parent
        # Get output file path
        output_file_path = current_file_directory / f"{current_file_stem}.vm"
        # print(f"Processing {current_file_stem}.jack -> {current_file_stem}.vm")

        # For now, tokenize all files into one big list
        # Later, parse and output xml for each file separately
        tokens += tokenize_code_from_file(current_file_path)

    # print xml with windows line endings to match test file from nand2tetris
    print(xml_from_token_list(tokens).replace("\n", "\r\n"), end="\r\n")


if __name__ == "__main__":
    main()
