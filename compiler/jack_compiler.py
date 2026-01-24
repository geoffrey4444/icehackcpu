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
                    # Next token is a symbol but is not part of this term
                    self.advance()  # advance past identifier token
                    return VarName(token=current_token)

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

    # Compile statements
    # 'let' varName('['expression']')?'=' expression ';'
    def compile_let_statement(self) -> LetStatement:
        # to get here, current token should be keyword "let"
        if self.current_token().value != "let":
            raise ValueError(
                f"Expected let keyword in let statement, not {self.current_token().value}"
            )
        self.advance()  # consume "let"
        var_name_token = self.current_token()
        if var_name_token.type != "identifier":
            raise ValueError(
                f"Variable name token {var_name_token.value} is type {var_name_token.type}, not identifier"
            )
        self.advance()  # consume varName
        array_index = None
        if self.current_token().value == "[":
            # assigning to index of array
            self.advance()  # consume "["
            array_index = self.compile_expression()
            # after expression for array index, expect "]"
            if self.current_token().value != "]":
                raise ValueError(
                    f"Expected ] after expression for array index in let statement"
                )
            self.advance()  # consume "]"
        # Next token in let statement must be '='
        if self.current_token().value != "=":
            raise ValueError(
                f"Expected = after variable name in let statement, not {self.current_token().value}"
            )
        self.advance()  # consume "="
        expression = self.compile_expression()
        if self.current_token().value != ";":
            raise ValueError(f"Expected ; after expression in let statement")
        self.advance()  # consume ";"

        return LetStatement(
            var_name_token=var_name_token,
            array_index=array_index,
            expression=expression,
        )

    # 'do' subroutineCall ';'
    def compile_do_statement(self) -> DoStatement:
        # to get here, current token should be keyword "do"
        if self.current_token().value != "do":
            raise ValueError(
                f"Expected do keyword in do statement, not {self.current_token().value}"
            )
        self.advance()  # consume "do"
        subroutine_call = self.compile_subroutine_call()
        if self.current_token().value != ";":
            raise ValueError(f"Expected ; after subroutine call in do statement")
        self.advance()  # consume ";"
        return DoStatement(subroutine_call=subroutine_call)

    # 'return' expression? ';'
    def compile_return_statement(self) -> ReturnStatement:
        # to get here, current token should be keyword "return"
        if self.current_token().value != "return":
            raise ValueError(
                f"Expected return keyword in return statement, not {self.current_token().value}"
            )
        self.advance()  # consume "return"
        expression = None
        if self.current_token().value != ";":
            expression = self.compile_expression()
        if self.current_token().value != ";":
            raise ValueError(f"Expected ; after expression in return statement")
        self.advance()  # consume ";"
        return ReturnStatement(expression=expression)

    # 'if' '(' expression ')' '{' statements '}' ('else' '{' statements '}')?
    def compile_if_statement(self) -> IfStatement:
        # to get here, current token should be keyword "if"
        if self.current_token().value != "if":
            raise ValueError(
                f"Expected if keyword in if statement, not {self.current_token().value}"
            )
        self.advance()  # consume "if"
        if self.current_token().value != "(":
            raise ValueError(f"Expected ( after if keyword in if statement")
        self.advance()  # consume "("

        condition = self.compile_expression()

        if self.current_token().value != ")":
            raise ValueError(f"Expected ) after condition in if statement")
        self.advance()  # consume ")"

        if self.current_token().value != "{":
            raise ValueError("Expected { at start of statements block in if statement")
        self.advance()  # consume "{" at start of statements block

        then_statements = self.compile_statements()

        if self.current_token().value != "}":
            raise ValueError("Expected } at end of statements block in if statement")
        self.advance()  # consume "}" at end of statements block

        else_statements = None
        if self.current_token().value == "else":
            self.advance()  # consume "else"

            if self.current_token().value != "{":
                raise ValueError(
                    "Expected { at start of statements block in else statement"
                )
            self.advance()  # consume "{" at start of statements block

            else_statements = self.compile_statements()

            if self.current_token().value != "}":
                raise ValueError(
                    "Expected } at end of statements block in else statement"
                )
            self.advance()  # consume "}" at end of statements block

        return IfStatement(
            condition=condition,
            then_statements=then_statements,
            else_statements=else_statements,
        )

    # 'while' '(' expression ')' '{' statements '}'
    def compile_while_statement(self) -> WhileStatement:
        # to get here, current token should be keyword "while"
        if self.current_token().value != "while":
            raise ValueError(
                f"Expected while keyword in while statement, not {self.current_token().value}"
            )
        self.advance()  # consume "while"
        if self.current_token().value != "(":
            raise ValueError(f"Expected ( after while keyword in while statement")
        self.advance()  # consume "("

        condition = self.compile_expression()

        if self.current_token().value != ")":
            raise ValueError(f"Expected ) after condition in while statement")
        self.advance()  # consume ")"

        if self.current_token().value != "{":
            raise ValueError(
                "Expected { at start of statements block in while statement"
            )
        self.advance()  # consume "{" at start of statements block

        body = self.compile_statements()

        if self.current_token().value != "}":
            raise ValueError("Expected } at end of statements block in while statement")
        self.advance()  # consume "}" at end of statements block

        return WhileStatement(condition=condition, body=body)

    # statement*
    def compile_statements(self) -> Statements:
        statements = Statements(statements=[])
        # Statements always appear between "{" and "}" and
        # begin with one of five keywords, one for each of the five types
        # of statements: let, do, return, if, while.
        # Note: caller of compile_statements() is responsible for
        # consuming '{' and '}'. Here we just look for "}" to recognize
        # when we have finished consuming the statements in a statements block.

        while self.current_token().value != "}":
            if self.current_token().value == "let":
                statements.statements.append(self.compile_let_statement())
            elif self.current_token().value == "do":
                statements.statements.append(self.compile_do_statement())
            elif self.current_token().value == "return":
                statements.statements.append(self.compile_return_statement())
            elif self.current_token().value == "if":
                statements.statements.append(self.compile_if_statement())
            elif self.current_token().value == "while":
                statements.statements.append(self.compile_while_statement())
            else:
                raise ValueError(
                    f"Statement begins with {self.current_token().value}, not let|do|return|if|while"
                )

        return statements

    # Compile program structure
    def compile_variable_declaration(self) -> VariableDeclaration:
        # to get here, current token should be keyword "var"
        if self.current_token().value != "var":
            raise ValueError(
                f"Expected var keyword in variable declaration, not {self.current_token().value}"
            )
        self.advance()  # consume "var"
        type_token = self.current_token()
        if (
            type_token.value not in ["int", "char", "boolean"]
            and self.current_token().type != "identifier"
        ):
            raise ValueError(
                f"Variable type token must be int, char, boolean, or identifier"
            )
        self.advance()  # consume type token
        first_var_name_token = self.current_token()
        if first_var_name_token.type != "identifier":
            raise ValueError(
                f"Variable name token {first_var_name_token.value} is type {first_var_name_token.type}, not identifier"
            )
        self.advance()  # consume variable name token
        # Optionally, you can declare multiple variable names of the same time in one declaration
        other_var_name_tokens = []
        while self.current_token().value == ",":
            self.advance()  # consume ","
            if self.current_token().type != "identifier":
                raise ValueError(
                    f"Variable name token {self.current_token().value} is type {self.current_token().type}, not identifier"
                )
            other_var_name_tokens.append(self.current_token())
            self.advance()  # consume variable name token

        if self.current_token().value != ";":
            raise ValueError("Expected ; token to end variable declaration")
        self.advance()  # consume ";"

        return VariableDeclaration(
            type_token=type_token,
            first_var_name_token=first_var_name_token,
            other_var_name_tokens=other_var_name_tokens,
        )

    def compile_subroutine_body(self) -> SubroutineBody:
        # to get here, current token should be symbol "{"
        if self.current_token().value != "{":
            raise ValueError("Expected { token to start subroutine body")
        self.advance()  # consume "{"

        variable_declarations = []
        while self.current_token().value == "var":
            variable_declarations.append(self.compile_variable_declaration())

        statements = self.compile_statements()

        if self.current_token().value != "}":
            raise ValueError("Expected } token to end subroutine body")
        self.advance()  # consume "}"

        return SubroutineBody(
            variable_declarations=variable_declarations, statements=statements
        )

    def compile_parameter(self) -> Parameter:
        # to get here, current token should be keyword "int" or "char" or "boolean" or identifier
        if (
            self.current_token().value not in ["int", "char", "boolean"]
            and self.current_token().type != "identifier"
        ):
            raise ValueError(
                f"Parameter type token must be int, char, boolean, or identifier"
            )
        type_token = self.current_token()
        self.advance()  # consume parameter type token
        variable_name_token = self.current_token()
        if variable_name_token.type != "identifier":
            raise ValueError(
                f"Variable name token {variable_name_token.value} is type {variable_name_token.type}, not identifier"
            )
        self.advance()  # consume variable name token
        return Parameter(type_token=type_token, variable_name_token=variable_name_token)

    def compile_parameter_list(self) -> ParameterList:
        parameters = []
        # To get here, subroutine should have at least one parameter
        parameters.append(self.compile_parameter())
        while self.current_token().value == ",":
            self.advance()  # consume ","
            parameters.append(self.compile_parameter())
        return ParameterList(parameters=parameters)

    def compile_subroutine_declaration(self) -> SubroutineDeclaration:
        # to get here, current token should be keyword "constructor" or "function" or "method"
        if self.current_token().value not in ["constructor", "function", "method"]:
            raise ValueError(
                f"Expected keyword constructor, function, or method at subroutine declaration start"
            )
        subroutine_kind_token = self.current_token()
        self.advance()  # consume subroutine kind token

        return_type_token = self.current_token()
        if (
            return_type_token.value not in ["void", "int", "char", "boolean"]
            and return_type_token.type != "identifier"
        ):
            raise ValueError(
                f"Return type token must be void, int, char, boolean, or identifier"
            )
        self.advance()  # consume return type token

        name_token = self.current_token()
        if name_token.type != "identifier":
            raise ValueError(
                f"Subroutine name token {name_token.value} is type {name_token.type}, not identifier"
            )
        self.advance()  # consume subroutine name token

        if self.current_token().value != "(":
            raise ValueError(f"Expected ( after subroutine name {name_token.value}")
        self.advance()  # consume "("
        parameter_list = ParameterList(parameters=[])
        if self.current_token().value != ")":
            parameter_list = self.compile_parameter_list()
        if self.current_token().value != ")":
            raise ValueError(
                f"Expected ) after parameter list in subroutine declaration"
            )
        self.advance()  # consume ")"

        subroutine_body = self.compile_subroutine_body()

        return SubroutineDeclaration(
            subroutine_kind_token=subroutine_kind_token,
            return_type_token=return_type_token,
            name_token=name_token,
            parameter_list=parameter_list,
            subroutine_body=subroutine_body,
        )

    def compile_class_variable_declaration(self) -> ClassVariableDeclaration:
        # to get here, current token should be keyword "static" or "field"
        if self.current_token().value not in ["static", "field"]:
            raise ValueError(
                f"Expected keyword static or field at class variable declaration start"
            )
        class_variable_kind_token = self.current_token()
        self.advance()  # consume class variable kind token

        type_token = self.current_token()
        if (
            type_token.value not in ["int", "char", "boolean"]
            and self.current_token().type != "identifier"
        ):
            raise ValueError(
                f"Variable type token must be int, char, boolean, or identifier"
            )
        self.advance()  # consume type token
        first_var_name_token = self.current_token()
        if first_var_name_token.type != "identifier":
            raise ValueError(
                f"Variable name token {first_var_name_token.value} is type {first_var_name_token.type}, not identifier"
            )
        self.advance()  # consume variable name token
        # Optionally, you can declare multiple variable names of the same time in one declaration
        other_var_name_tokens = []
        while self.current_token().value == ",":
            self.advance()  # consume ","
            if self.current_token().type != "identifier":
                raise ValueError(
                    f"Variable name token {self.current_token().value} is type {self.current_token().type}, not identifier"
                )
            other_var_name_tokens.append(self.current_token())
            self.advance()  # consume variable name token

        if self.current_token().value != ";":
            raise ValueError("Expected ; token to end class variable declaration")
        self.advance()  # consume ";"

        return ClassVariableDeclaration(
            class_variable_kind_token=class_variable_kind_token,
            type_token=type_token,
            first_var_name_token=first_var_name_token,
            other_var_name_tokens=other_var_name_tokens,
        )

    def compile_class(self) -> Class:
        # to get here, current token should be keyword "class"
        if self.current_token().value != "class":
            raise ValueError(f"Expected keyword class at class start")
        self.advance()  # consume "class"

        name_token = self.current_token()
        if name_token.type != "identifier":
            raise ValueError(
                f"Class name token {name_token.value} is type {name_token.type}, not identifier"
            )
        self.advance()  # consume class name token

        if self.current_token().value != "{":
            raise ValueError("Expected { token to start class body")
        self.advance()  # consume "{"

        class_variable_declarations = []
        while (
            self.current_token().value == "static"
            or self.current_token().value == "field"
        ):
            class_variable_declarations.append(
                self.compile_class_variable_declaration()
            )

        subroutine_declarations = []
        while (
            self.current_token().value == "constructor"
            or self.current_token().value == "function"
            or self.current_token().value == "method"
        ):
            subroutine_declarations.append(self.compile_subroutine_declaration())

        if self.current_token().value != "}":
            raise ValueError("Expected } token to end class body")
        self.advance()  # consume "}"

        if self.current_token_index != len(self.tokens):
            raise ValueError(
                "Expected end of input after class body; Jack assumes one class per file"
            )

        return Class(
            name_token=name_token,
            class_variable_declarations=class_variable_declarations,
            subroutine_declarations=subroutine_declarations,
        )


# Emitters

# Code to emit VM code
# Writes different VM statements as strings
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

arithmetic_commands = [
    "add",
    "sub",
    "neg",
    "eq",
    "gt",
    "lt",
    "and",
    "or",
    "not",
]

SymbolRecordKind = Literal[
    "static",
    "field",
    "argument",
    "local",
]


class VmWriter:
    @staticmethod
    def write_push(segment: str, index: int, include_newline: bool = True) -> str:
        if segment not in segments:
            raise ValueError(f"Cannot write vm code: invalid segment {segment}")
        if index < 0:
            raise ValueError(f"Cannot write vm code: index {index} is negative")
        if segment == "constant" and index > 32767:
            raise ValueError(
                f"Cannot write vm code: constant {index} is greater than 32767"
            )
        if segment == "pointer" and index > 1:
            raise ValueError(f"Cannot write vm code: pointer {index} is greater than 1")
        if segment == "temp" and index > 7:
            raise ValueError(f"Cannot write vm code: temp {index} is greater than 7")
        if segment == "uart" and index > 2:
            raise ValueError(f"Cannot write vm code: uart {index} is greater than 2")
        result = f"push {segment} {index}"
        if include_newline:
            result += "\n"
        return result

    @staticmethod
    def write_pop(segment: str, index: int, include_newline: bool = True) -> str:
        if segment not in segments:
            raise ValueError(f"Cannot write vm code: invalid segment {segment}")
        if index < 0:
            raise ValueError(f"Cannot write vm code: index {index} is negative")
        if segment == "constant":
            raise ValueError(f"Cannot write vm code: cannot pop to constant segment")
        if segment == "pointer" and index > 1:
            raise ValueError(f"Cannot write vm code: pointer {index} is greater than 1")
        if segment == "temp" and index > 7:
            raise ValueError(f"Cannot write vm code: temp {index} is greater than 7")
        if segment == "uart" and index > 2:
            raise ValueError(f"Cannot write vm code: uart {index} is greater than 2")
        result = f"pop {segment} {index}"
        if include_newline:
            result += "\n"
        return result

    @staticmethod
    def write_arithmetic(self, command: str, include_newline: bool = True) -> str:
        if command not in arithmetic_commands:
            raise ValueError(
                f"Cannot write vm code: invalid arithmetic command {command}"
            )
        result = f"{command}"
        if include_newline:
            result += "\n"
        return result

    @staticmethod
    def write_label(label: str, include_newline: bool = True) -> str:
        if label == "":
            raise ValueError(f"Cannot write vm code: label cannot be empty")
        result = f"label {label}"
        if include_newline:
            result += "\n"
        return result

    @staticmethod
    def write_goto(label: str, include_newline: bool = True) -> str:
        if label == "":
            raise ValueError(f"Cannot write vm code: label cannot be empty")
        result = f"goto {label}"
        if include_newline:
            result += "\n"
        return result

    @staticmethod
    def write_if_goto(label: str, include_newline: bool = True) -> str:
        if label == "":
            raise ValueError(f"Cannot write vm code: label cannot be empty")
        result = f"if-goto {label}"
        if include_newline:
            result += "\n"
        return result

    @staticmethod
    def write_function(
        function_name: str, number_of_local_variables: int, include_newline: bool = True
    ) -> str:
        if function_name == "":
            raise ValueError(f"Cannot write vm code: function name cannot be empty")
        if number_of_local_variables < 0:
            raise ValueError(
                f"Cannot write vm code: number of local variables cannot be negative"
            )
        result = f"function {function_name} {number_of_local_variables}"
        if include_newline:
            result += "\n"
        return result

    @staticmethod
    def write_call(
        function_name: str, number_of_arguments: int, include_newline: bool = True
    ) -> str:
        if function_name == "":
            raise ValueError(f"Cannot write vm code: function name cannot be empty")
        if number_of_arguments < 0:
            raise ValueError(
                f"Cannot write vm code: number of arguments cannot be negative"
            )
        result = f"call {function_name} {number_of_arguments}"
        if include_newline:
            result += "\n"
        return result

    @staticmethod
    def write_return(include_newline: bool = True) -> str:
        result = f"return"
        if include_newline:
            result += "\n"
        return result


# SymbolTable class: manage lookup for addresses of identifiers


@dataclass
class SymbolTableRecord:
    type: str
    kind: SymbolRecordKind
    index: int


@dataclass
class SymbolTable:
    counts_by_kind: dict[SymbolRecordKind, int] = field(default_factory=dict)
    records: dict[str, SymbolTableRecord] = field(default_factory=dict)

    def reset(self):
        self.counts_by_kind = {
            "static": 0,
            "field": 0,
            "argument": 0,
            "local": 0,
        }
        self.records = {}

    def __post_init__(self):
        self.reset()

    def define(self, symbol_name: str, symbol_type: str, kind: SymbolRecordKind):
        index_for_new_symbol = self.counts_by_kind[kind]
        self.counts_by_kind[kind] += 1
        self.records[symbol_name] = SymbolTableRecord(
            type=symbol_type, kind=kind, index=index_for_new_symbol
        )

    def var_count(self, kind: SymbolRecordKind) -> int:
        return self.counts_by_kind[kind]

    def kind_of(self, symbol_name: str) -> Optional[SymbolRecordKind]:
        record = self.records.get(symbol_name, None)
        return record.kind if record else None

    def type_of(self, symbol_name: str) -> Optional[str]:
        record = self.records.get(symbol_name, None)
        return record.type if record else None

    def index_of(self, symbol_name: str) -> Optional[int]:
        record = self.records.get(symbol_name, None)
        return record.index if record else None


# VMGenerator: walks the JackCompiler output tree,
# writing vm code for the different constructs
class VMGenerator:
    vm_writer: VmWriter
    class_symbol_table: SymbolTable
    subroutine_symbol_table: SymbolTable
    current_class_name: str

    def __init__(self):
        self.vm_writer = VmWriter()
        self.class_symbol_table = SymbolTable()
        self.subroutine_symbol_table = SymbolTable()
        self.current_class_name = ""

    def generate_vm_code_for_integer_constant(self, node: IntegerConstant) -> str:
        return self.vm_writer.write_push("constant", node.token.value)

    def generate_vm_code_for_keyword_constant(self, node: KeywordConstant) -> str:
        result = ""
        if node.token.value == "true":
            result += self.vm_writer.write_push("constant", 1)
            result += self.vm_writer.write_arithmetic("neg")
        elif node.token.value == "false":
            result += self.vm_writer.write_push("constant", 0)
        elif node.token.value == "null":
            result += self.vm_writer.write_push("constant", 0)
        elif node.token.value == "this":
            result += self.vm_writer.write_push("pointer", 0)
        else:
            raise ValueError(f"Unknown keyword constant {node.token.value}")
        return result

    # I *think* what this does is use a system call to allocate a string
    # in the heap, then put the pointer to that string on the stack.
    # I won't be able to run this code until I actually have an implementation
    # of String.new and String.append.
    def generate_vm_code_for_string_constant(self, node: StringConstant) -> str:
        text = node.token.value
        number_of_chars = len(text)
        number_of_chars_integer_constant = IntegerConstant(
            token=Token(type="integerConstant", value=str(number_of_chars))
        )
        result = self.generate_vm_code_for_integer_constant(
            number_of_chars_integer_constant
        )
        result += self.vm_writer.write_call("String.new", 1)
        for char in text:
            result += self.vm_writer.write_push("constant", ord(char))
            result += self.vm_writer.write_call("String.appendChar", 2)
        return result

    def generate_vm_code_for_parenthetical_expression(
        self, node: ParentheticalExpression
    ) -> str:
        return self.generate_vm_code_for_expression(node.expression)

    def generate_vm_code_for_unary_op_term(self, node: UnaryOpTerm) -> str:
        result = self.generate_vm_code_for_term(node.term_to_operate_on)
        result += self.generate_vm_code_for_unary_operator(node.op_token)
        return result

    def generate_vm_code_for_unary_operator(self, operator_token: Token) -> str:
        match operator_token.value:
            case "-":
                return self.vm_writer.write_arithmetic("neg")
            case "~":
                return self.vm_writer.write_arithmetic("not")
            case _:
                raise ValueError(f"Unknown unary operator {operator_token.value}")

    def generate_vm_code_for_var_name(self, node: VarName) -> str:
        result = ""
        variable_name = node.token.value
        variable_kind = self.subroutine_symbol_table.kind_of(variable_name)
        variable_index = self.subroutine_symbol_table.index_of(variable_name)
        if variable_kind == None:
            variable_kind = self.class_symbol_table.kind_of(variable_name)
            if variable_kind == None:
                raise ValueError(
                    f"Variable {variable_name} not found in symbol tables. Missing declaration?"
                )
            variable_index = self.class_symbol_table.index_of(variable_name)
        if variable_kind == "static":
            result += self.vm_writer.write_push("static", variable_index)
        elif variable_kind == "field":
            result += self.vm_writer.write_push("this", variable_index)
        elif variable_kind == "argument":
            result += self.vm_writer.write_push("argument", variable_index)
        elif variable_kind == "local":
            result += self.vm_writer.write_push("local", variable_index)
        else:
            raise ValueError(f"Unknown variable kind {variable_kind}")
        return result

    def generate_vm_code_for_term(self, node: Term) -> str:
        match node:
            case IntegerConstant():
                return self.generate_vm_code_for_integer_constant(node)
            case KeywordConstant():
                return self.generate_vm_code_for_keyword_constant(node)
            case VarName():
                return self.generate_vm_code_for_var_name(node)
            case StringConstant():
                return self.generate_vm_code_for_string_constant(node)
            case ParentheticalExpression():
                return self.generate_vm_code_for_parenthetical_expression(node)
            case UnaryOpTerm():
                return self.generate_vm_code_for_unary_op_term(node)
            case ArrayAccess():
                return self.generate_vm_code_for_array_access(node)
            case SubroutineCall():
                return self.generate_vm_code_for_subroutine_call(node)
            # Still need ArrayAccess and SubroutineCall

    def generate_vm_code_for_binary_operator(self, operator_token: Token) -> str:
        match operator_token.value:
            case "+":
                return self.vm_writer.write_arithmetic("add")
            case "-":
                return self.vm_writer.write_arithmetic("sub")
            case "*":
                return self.vm_writer.write_call("Math.multiply", 2)
            case "/":
                return self.vm_writer.write_call("Math.divide", 2)
            case "&":
                return self.vm_writer.write_arithmetic("and")
            case "|":
                return self.vm_writer.write_arithmetic("or")
            case "<":
                return self.vm_writer.write_arithmetic("lt")
            case ">":
                return self.vm_writer.write_arithmetic("gt")
            case "=":
                return self.vm_writer.write_arithmetic("eq")
            case _:
                raise ValueError(f"Unknown operator {operator_token.value}")

    def generate_vm_code_for_expression(self, node: Expression) -> str:
        result = ""
        first_term = node.first_term
        other_terms = node.other_terms
        result += self.generate_vm_code_for_term(first_term)
        for operator_token, term in other_terms:
            result += self.generate_vm_code_for_term(term)
            result += self.generate_vm_code_for_binary_operator(operator_token)
        return result

    def generate_vm_code_for_expression_list(self, node: ExpressionList) -> str:
        result = ""
        for expression in node.expressions:
            result += self.generate_vm_code_for_expression(expression)
        return result

    def generate_vm_code_for_subroutine_call(self, node: SubroutineCall) -> str:
        # Possibilities for receiver name
        #   1. Receiver is an object name in one of the symbol tables
        #         - Push address of object (parameter 0)
        #         - Push each expression in expression_list
        #         - Class name is type from symbol table
        #         - Call ClassName.FunctionName 1 + len(expression_list)
        #   2. Receiver is None, so it refers to the current class
        #         - Push pointer 0 (address of current object) (param 0)
        #         - Push each expression in expression_list
        #         - Class name is self.current_class_name (set in compile_class)
        #         - Call ClassName.FunctionName 1 + len(expression_list)
        #   3. Receiver is a class name, so it refers to a static method
        #         - Push each expression in expression list
        #         - Class name is receiver
        #         - Call ClassName.FunctionName len(expression_list)
        result = ""
        receiver_name = (
            node.receiver_name_token.value if node.receiver_name_token else None
        )
        if receiver_name == None:
            # Subroutine a method of the current object
            # Push 'this' (address of current object) as parameter 0
            result += self.vm_writer.write_push("pointer", 0)

            # Push each expression in expression_list
            result += self.generate_vm_code_for_expression_list(node.expression_list)

            # Class name is self.current_class_name
            full_name_to_call = (
                f"{self.current_class_name}.{node.subroutine_name_token.value}"
            )

            result += self.vm_writer.write_call(
                full_name_to_call, len(node.expression_list.expressions) + 1
            )
        elif receiver_name in self.subroutine_symbol_table.records:
            # Subroutine is a method of an object stored in a local
            # variable or passed in as an argument
            #
            # receiver_name names either an argument or a local variable
            # kind is argument or local. At the index of the kind segment,
            # the object's base address is stored as a pointer.
            # Push the address of the object as parameter 0
            receiver_kind = self.subroutine_symbol_table.kind_of(receiver_name)
            if receiver_kind not in ["argument", "local"]:
                raise ValueError(
                    f"Receiver {receiver_name} must be an argument or a local variable, not {receiver_kind}"
                )
            receiver_index = self.subroutine_symbol_table.index_of(receiver_name)
            result += self.vm_writer.write_push(receiver_kind, receiver_index)

            # Push each expression in expression_list
            result += self.generate_vm_code_for_expression_list(node.expression_list)

            # Class name is type from symbol table
            receiver_type = self.subroutine_symbol_table.type_of(receiver_name)
            full_name_to_call = f"{receiver_type}.{node.subroutine_name_token.value}"

            result += self.vm_writer.write_call(
                full_name_to_call, len(node.expression_list.expressions) + 1
            )
        elif receiver_name in self.class_symbol_table.records:
            # Subroutine is a method of an object stored as a static or
            # field variable of the current class.
            receiver_kind = self.class_symbol_table.kind_of(receiver_name)
            if receiver_kind not in ["static", "field"]:
                raise ValueError(
                    f"Receiver {receiver_name} must be a static or field variable, not {receiver_kind}"
                )

            # If kind is static, address of object is stored in static segment of memory
            # If kind is field, address of object is stored in this segment of memory
            if receiver_kind == "field":
                receiver_kind = "this"
            receiver_index = self.class_symbol_table.index_of(receiver_name)
            result += self.vm_writer.write_push(receiver_kind, receiver_index)

            # Push each expression in expression_list
            result += self.generate_vm_code_for_expression_list(node.expression_list)

            # Class name is type from symbol table
            receiver_type = self.class_symbol_table.type_of(receiver_name)
            full_name_to_call = f"{receiver_type}.{node.subroutine_name_token.value}"

            result += self.vm_writer.write_call(
                full_name_to_call, len(node.expression_list.expressions) + 1
            )
        else:
            # Subroutine is a class-level function, not a method

            # Push each expression in expression_list
            result += self.generate_vm_code_for_expression_list(node.expression_list)

            # Class name is receiver_name
            full_name_to_call = f"{receiver_name}.{node.subroutine_name_token.value}"

            # Note: no base address to push, so do not call with "+ 1" arguments
            result += self.vm_writer.write_call(
                full_name_to_call, len(node.expression_list.expressions)
            )

        return result

    # Array access (rvalue ... lvalue array access handled in let statement)
    def generate_vm_code_for_array_access(self, node: ArrayAccess) -> str:
        # Get base address of array from one of the symbol tables
        array_name = node.array_name_token.value
        array_kind = self.subroutine_symbol_table.kind_of(array_name)
        array_base_address_index = self.class_symbol_table.index_of(array_name)
        if array_kind == None:
            array_kind = self.class_symbol_table.kind_of(array_name)
            array_base_address_index = self.class_symbol_table.index_of(array_name)
            if array_kind == "field":
                array_kind = "this"
            if array_kind == None:
                raise ValueError(
                    f"Array {array_name} not found in symbol tables. Missing declaration?"
                )
        result = self.vm_writer.write_push(array_kind, array_base_address_index)
        result += self.generate_vm_code_for_expression(node.array_index)
        result += self.vm_writer.write_arithmetic("add")

        # Stack now as base address of the array element we want
        # Pop the address to set THAT base address, then push that[0] on stack
        result += self.vm_writer.write_pop("pointer", 1)
        result += self.vm_writer.write_push("that", 0)

        return result

    # Do statement

    # Return statement

    # Let statement

    # If statement

    # While statement

    # Statement

    # Statements

    # varDec

    # subroutineBody

    # parameterList (?? Does the compiler ever use this?)

    # subroutineDec

    # classVarDec

    # class


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


# Emit XML for parsed Jack code
# The nodes are the different dataclass instances
# The emit() function gets called recursively, routes to the correct
# emitter for each node type
class EmitJackParsedXml:
    def emit_token(self, node: Token):
        tag = node.type.value if hasattr(node.type, "value") else str(node.type)
        element = et.Element(tag)
        element.text = f" {node.value} "
        return element

    def emit_string_constant(self, node: StringConstant):
        element = et.Element("term")
        element.append(self.emit_token(node.token))
        return element

    def emit_integer_constant(self, node: IntegerConstant):
        element = et.Element("term")
        element.append(self.emit_token(node.token))
        return element

    def emit_keyword_constant(self, node: KeywordConstant):
        element = et.Element("term")
        element.append(self.emit_token(node.token))
        return element

    def emit_var_name(self, node: VarName):
        element = et.Element("term")
        element.append(self.emit_token(node.token))
        return element

    def emit_array_access(self, node: ArrayAccess):
        element = et.Element("term")
        left_bracket_token = Token(type="symbol", value="[")
        right_bracket_token = Token(type="symbol", value="]")
        name_token = node.array_name_token
        index_expression = node.array_index
        element.append(self.emit_token(name_token))
        element.append(self.emit_token(left_bracket_token))
        element.append(self.emit_expression(index_expression))
        element.append(self.emit_token(right_bracket_token))
        return element

    def emit_parenthetical_expression(self, node: ParentheticalExpression):
        element = et.Element("term")
        left_paren_token = Token(type="symbol", value="(")
        right_paren_token = Token(type="symbol", value=")")
        element.append(self.emit_token(left_paren_token))
        element.append(self.emit_expression(node.expression))
        element.append(self.emit_token(right_paren_token))
        return element

    def emit_unary_op_term(self, node: UnaryOpTerm):
        element = et.Element("term")
        op_token = node.op_token
        term_to_operate_on = node.term_to_operate_on
        element.append(self.emit_token(op_token))
        element.append(self.emit_term(term_to_operate_on))
        return element

    def emit_subroutine_call(self, node: SubroutineCall):
        element = et.Element("term")
        subroutine_name_token = node.subroutine_name_token
        receiver_name_token = node.receiver_name_token
        dot_tok = Token(type="symbol", value=".")
        left_paren_token = Token(type="symbol", value="(")
        right_paren_token = Token(type="symbol", value=")")
        expression_list = node.expression_list
        if receiver_name_token != None:
            element.append(self.emit_token(receiver_name_token))
            element.append(self.emit_token(dot_tok))
        element.append(self.emit_token(subroutine_name_token))
        element.append(self.emit_token(left_paren_token))
        element.append(self.emit_expression_list(expression_list))
        element.append(self.emit_token(right_paren_token))
        return element

    def emit_expression(self, node: Expression):
        element = et.Element("expression")
        first_term = node.first_term
        other_terms = node.other_terms
        element.append(self.emit_term(first_term))
        for operator_token, term in other_terms:
            element.append(self.emit_token(operator_token))
            element.append(self.emit_term(term))
        return element

    def emit_expression_list(self, node: ExpressionList):
        element = et.Element("expressionList")
        comma_token = Token(type="symbol", value=",")
        for i, expression in enumerate(node.expressions):
            element.append(self.emit_expression(expression))
            if i < len(node.expressions) - 1 and len(node.expressions) > 1:
                element.append(self.emit_token(comma_token))
        return element

    def emit_term(self, node: Term):
        match node:
            case IntegerConstant():
                return self.emit_integer_constant(node)
            case StringConstant():
                return self.emit_string_constant(node)
            case KeywordConstant():
                return self.emit_keyword_constant(node)
            case VarName():
                return self.emit_var_name(node)
            case ArrayAccess():
                return self.emit_array_access(node)
            case ParentheticalExpression():
                return self.emit_parenthetical_expression(node)
            case UnaryOpTerm():
                return self.emit_unary_op_term(node)
            case SubroutineCall():
                return self.emit_subroutine_call(node)
            case _:
                raise ValueError(f"Unexpected term type {type(node)}")

    def emit_let_statement(self, node: LetStatement):
        element = et.Element("letStatement")
        var_name_token = node.var_name_token
        expression = node.expression
        array_index = node.array_index
        let_token = Token(type="keyword", value="let")
        equal_token = Token(type="symbol", value="=")
        semicolon_token = Token(type="symbol", value=";")
        left_bracket_token = Token(type="symbol", value="[")
        right_bracket_token = Token(type="symbol", value="]")

        element.append(self.emit_token(let_token))
        element.append(self.emit_token(var_name_token))
        if array_index != None:
            element.append(self.emit_token(left_bracket_token))
            element.append(self.emit_expression(array_index))
            element.append(self.emit_token(right_bracket_token))
        element.append(self.emit_token(equal_token))
        element.append(self.emit_expression(expression))
        element.append(self.emit_token(semicolon_token))
        return element

    def emit_do_statement(self, node: DoStatement):
        element = et.Element("doStatement")
        do_token = Token(type="keyword", value="do")
        subroutine_call = node.subroutine_call
        semicolon_token = Token(type="symbol", value=";")
        element.append(self.emit_token(do_token))
        # Extend the do statement with the children of the
        # term element returned by emit_subroutine_call()
        subroutine_call_element = self.emit_subroutine_call(subroutine_call)
        element.extend(list(subroutine_call_element))
        element.append(self.emit_token(semicolon_token))
        return element

    def emit_return_statement(self, node: ReturnStatement):
        element = et.Element("returnStatement")
        return_token = Token(type="keyword", value="return")
        expression = node.expression
        semicolon_token = Token(type="symbol", value=";")
        element.append(self.emit_token(return_token))
        if expression != None:
            element.append(self.emit_expression(expression))
        element.append(self.emit_token(semicolon_token))
        return element

    def emit_if_statement(self, node: IfStatement):
        element = et.Element("ifStatement")
        if_token = Token(type="keyword", value="if")
        left_paren_token = Token(type="symbol", value="(")
        right_paren_token = Token(type="symbol", value=")")
        left_bracket_token = Token(type="symbol", value="{")
        right_bracket_token = Token(type="symbol", value="}")
        else_token = Token(type="keyword", value="else")

        element.append(self.emit_token(if_token))
        element.append(self.emit_token(left_paren_token))
        element.append(self.emit_expression(node.condition))
        element.append(self.emit_token(right_paren_token))
        element.append(self.emit_token(left_bracket_token))
        element.append(self.emit_statements(node.then_statements))
        element.append(self.emit_token(right_bracket_token))
        if node.else_statements != None:
            element.append(self.emit_token(else_token))
            element.append(self.emit_token(left_bracket_token))
            element.append(self.emit_statements(node.else_statements))
            element.append(self.emit_token(right_bracket_token))
        return element

    def emit_while_statement(self, node: WhileStatement):
        element = et.Element("whileStatement")
        while_token = Token(type="keyword", value="while")
        left_paren_token = Token(type="symbol", value="(")
        right_paren_token = Token(type="symbol", value=")")
        left_bracket_token = Token(type="symbol", value="{")
        right_bracket_token = Token(type="symbol", value="}")
        element.append(self.emit_token(while_token))
        element.append(self.emit_token(left_paren_token))
        element.append(self.emit_expression(node.condition))
        element.append(self.emit_token(right_paren_token))
        element.append(self.emit_token(left_bracket_token))
        element.append(self.emit_statements(node.body))
        element.append(self.emit_token(right_bracket_token))
        return element

    def emit_statement(self, node: Statement):
        match node:
            case LetStatement():
                return self.emit_let_statement(node)
            case DoStatement():
                return self.emit_do_statement(node)
            case ReturnStatement():
                return self.emit_return_statement(node)
            case IfStatement():
                return self.emit_if_statement(node)
            case WhileStatement():
                return self.emit_while_statement(node)
            case _:
                raise ValueError(f"Unexpected statement type {type(node)}")

    def emit_statements(self, node: Statements):
        element = et.Element("statements")
        for statement in node.statements:
            element.append(self.emit_statement(statement))
        return element

    def emit_variable_declaration(self, node: VariableDeclaration):
        element = et.Element("varDec")
        var_token = Token(type="keyword", value="var")
        type_token = node.type_token
        first_var_name_token = node.first_var_name_token
        other_var_name_tokens = node.other_var_name_tokens
        comma_token = Token(type="symbol", value=",")
        semicolon_token = Token(type="symbol", value=";")
        element.append(self.emit_token(var_token))
        element.append(self.emit_token(type_token))
        element.append(self.emit_token(first_var_name_token))
        for var_name_token in other_var_name_tokens:
            element.append(self.emit_token(comma_token))
            element.append(self.emit_token(var_name_token))
        element.append(self.emit_token(semicolon_token))
        return element

    def emit_subroutine_body(self, node: SubroutineBody):
        element = et.Element("subroutineBody")
        left_brace_token = Token(type="symbol", value="{")
        right_brace_token = Token(type="symbol", value="}")
        variable_declarations = node.variable_declarations
        statements = node.statements
        element.append(self.emit_token(left_brace_token))
        for var_declaration in variable_declarations:
            element.append(self.emit_variable_declaration(var_declaration))
        element.append(self.emit_statements(statements))
        element.append(self.emit_token(right_brace_token))
        return element

    def emit_parameter_list(self, node: ParameterList):
        element = et.Element("parameterList")
        comma_token = Token(type="symbol", value=",")
        for i, parameter in enumerate(node.parameters):
            element.extend(list(self.emit_parameter(parameter)))
            if i < len(node.parameters) - 1 and len(node.parameters) > 1:
                element.append(self.emit_token(comma_token))
        return element

    def emit_parameter(self, node: Parameter):
        element = et.Element("parameter")
        type_token = node.type_token
        variable_name_token = node.variable_name_token
        element.append(self.emit_token(type_token))
        element.append(self.emit_token(variable_name_token))
        return element

    def emit_subroutine_declaration(self, node: SubroutineDeclaration):
        element = et.Element("subroutineDec")
        subroutine_kind_token = node.subroutine_kind_token
        return_type_token = node.return_type_token
        name_token = node.name_token
        parameter_list = node.parameter_list
        subroutine_body = node.subroutine_body
        left_paren_token = Token(type="symbol", value="(")
        right_paren_token = Token(type="symbol", value=")")
        element.append(self.emit_token(subroutine_kind_token))
        element.append(self.emit_token(return_type_token))
        element.append(self.emit_token(name_token))
        element.append(self.emit_token(left_paren_token))
        element.append(self.emit_parameter_list(parameter_list))
        element.append(self.emit_token(right_paren_token))
        element.append(self.emit_subroutine_body(subroutine_body))
        return element

    def emit_class_variable_declaration(self, node: ClassVariableDeclaration):
        element = et.Element("classVarDec")
        class_variable_kind_token = node.class_variable_kind_token
        type_token = node.type_token
        first_var_name_token = node.first_var_name_token
        other_var_name_tokens = node.other_var_name_tokens
        semicolon_token = Token(type="symbol", value=";")
        comma_token = Token(type="symbol", value=",")
        element.append(self.emit_token(class_variable_kind_token))
        element.append(self.emit_token(type_token))
        element.append(self.emit_token(first_var_name_token))
        for var_name_token in other_var_name_tokens:
            element.append(self.emit_token(comma_token))
            element.append(self.emit_token(var_name_token))
        element.append(self.emit_token(semicolon_token))
        return element

    def emit_class(self, node: Class):
        element = et.Element("class")
        class_token = Token(type="keyword", value="class")
        name_token = node.name_token
        class_variable_declarations = node.class_variable_declarations
        subroutine_declarations = node.subroutine_declarations
        left_brace_token = Token(type="symbol", value="{")
        right_brace_token = Token(type="symbol", value="}")
        element.append(self.emit_token(class_token))
        element.append(self.emit_token(name_token))
        element.append(self.emit_token(left_brace_token))
        for class_variable_declaration in class_variable_declarations:
            element.append(
                self.emit_class_variable_declaration(class_variable_declaration)
            )
        for subroutine_declaration in subroutine_declarations:
            element.append(self.emit_subroutine_declaration(subroutine_declaration))
        element.append(self.emit_token(right_brace_token))
        return element

    def emit(self, node):
        # Match looks for different class patterns
        match node:
            case Class():
                return self.emit_class(node)
            case ClassVariableDeclaration():
                return self.emit_class_variable_declaration(node)
            case SubroutineDeclaration():
                return self.emit_subroutine_declaration(node)
            case ParameterList():
                return self.emit_parameter_list(node)
            case Parameter():
                return self.emit_parameter(node)
            case SubroutineBody():
                return self.emit_subroutine_body(node)
            case VariableDeclaration():
                return self.emit_variable_declaration(node)
            case Statements():
                return self.emit_statements(node)
            case LetStatement():
                return self.emit_let_statement(node)
            case DoStatement():
                return self.emit_do_statement(node)
            case ReturnStatement():
                return self.emit_return_statement(node)
            case IfStatement():
                return self.emit_if_statement(node)
            case WhileStatement():
                return self.emit_while_statement(node)
            case ExpressionList():
                return self.emit_expression_list(node)
            case Expression():
                return self.emit_expression(node)
            case SubroutineCall():
                return self.emit_subroutine_call(node)
            case UnaryOpTerm():
                return self.emit_unary_op_term(node)
            case ParentheticalExpression():
                return self.emit_parenthetical_expression(node)
            case ArrayAccess():
                return self.emit_array_access(node)
            case VarName():
                return self.emit_var_name(node)
            case KeywordConstant():
                return self.emit_keyword_constant(node)
            case IntegerConstant():
                return self.emit_integer_constant(node)
            case StringConstant():
                return self.emit_string_constant(node)
            case Token():
                return self.emit_token(node)
            case _:
                raise ValueError(f"Unexpected node type {type(node)}")

    def node_to_string(self, node):
        node_to_output = self.emit(node)
        et.indent(node_to_output, space="  ")
        xml_string = et.tostring(
            node_to_output,
            encoding="utf-8",
            method="xml",
            xml_declaration=False,
            short_empty_elements=False,
        ).decode("utf-8")
        return xml_string

    # Emit vm code


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
        print(f"Processing {current_file_stem}.jack -> {current_file_stem}.vm")

        # Tokenize the current file and output the result
        tokens = tokenize_code_from_file(current_file_path)

        output_file_path_tokens = current_file_directory / f"{current_file_stem}T.xml"
        with open(output_file_path_tokens, "w") as output_file:
            output_file.write(xml_from_token_list(tokens).replace("\n", "\r\n"))
            print(f"  Output XML to {output_file_path_tokens}")

        # Compile the current file
        jack_compiler = JackCompiler(tokens=tokens)
        compiled_class = jack_compiler.compile_class()

        output_file_path_raw = current_file_directory / f"{current_file_stem}.raw"
        with open(output_file_path_raw, "w") as output_file:
            output_file.write(str(compiled_class))
            print(f"  Output raw to {output_file_path_raw}")

        output_file_path_xml = current_file_directory / f"{current_file_stem}.xml"
        with open(output_file_path_xml, "w") as output_file:
            output_file.write(
                EmitJackParsedXml().node_to_string(compiled_class).replace("\n", "\r\n")
            )
            print(f"  Output XML to {output_file_path_xml}")

    # print xml with windows line endings to match test file from nand2tetris
    # print(xml_from_token_list(tokens).replace("\n", "\r\n"), end="\r\n")


if __name__ == "__main__":
    main()
