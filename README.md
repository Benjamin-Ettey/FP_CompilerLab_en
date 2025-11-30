
Documentation

This is a simple functional programming language I designed for my Functional Programming lab project. The whole idea was to create my own language, define the rules, write a parser, and create an interpreter that can run programs written in the language.

I decided to make something close to Lisp. This made parsing easier and allowed me to focus on core functional programming ideas like recursion, functions, closures, and expression evaluation.

Language Syntax

The basic structure of the language uses brackets:

( keyword arg1 arg2 ... )

Examples:
(let x 5)
(+ 4 6)
(fun (n) (* n n))

We also support nested expressions like:
(* (+ 2 3) 4)

What the Language Supports

Here are the main features my language can do:

1. Named variables using “let”
2. Recursion (so we can do factorial)
3. First‑class functions
4. Closures (functions remember variables)
5. Lazy evaluation for “if” expressions
6. Lists
7. Built‑in library functions for lists (head, tail, print, file write, file read)

Example Program

This calculates factorial:

(let fact 
    (fun (n)
        (if (= n 0)
            1
            (* n (fact (- n 1))))
        )
)

(print (fact 5))

How the Interpreter Works

 Tokenizer: breaks the input text into small pieces  
 Parser: builds an AST (abstract syntax tree)  
 Evaluator: walks the AST and executes expressions  
 Environment: stores variables and function bindings  

Every time you run a program, the interpreter reads it, parses it, and evaluates the result.


I kept the syntax simple on purpose because writing parsers is stressful. Making everything bracket‑based made the structure clear.

Final Notes

This project helped me understand how languages work internally - parsing, evaluating, environments, and recursion. Even though the language is simple, it is expressive enough to compute real things like factorial, power, Fibonacci, etc.
I also used chatgpt to help me build the parser because i got confused at that side.
