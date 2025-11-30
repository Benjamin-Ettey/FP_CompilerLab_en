open System

//  AST
type Expr =
  | Atom of string
  | List of Expr list

//  Value
type Value =
  | VInt of int
  | VBool of bool
  | VList of Value list
  | VClosure of string list * Expr * Env
  | VPrimitive of (Value list -> Value)
  | VThunk of (unit -> Value) ref

and Env = Map<string, Value>

// Tokenizer
let tokenize(input:string) : string[] =
  let sb = System.Text.StringBuilder()
  let tokens = System.Collections.Generic.List<string>()
  let pushTok() = if sb.Length > 0 then tokens.Add(sb.ToString()); sb.Clear() |> ignore
  let add(ch:char) = sb.Append(ch) |> ignore
  let mutable i = 0
  while i < input.Length do
    match input.[i] with
    | '(' -> pushTok(); tokens.Add("("); i <- i + 1
    | ')' -> pushTok(); tokens.Add(")"); i <- i + 1
    | ' ' | '\n' | '\r' | '\t' -> pushTok(); i <- i + 1
    | ';' -> while i < input.Length && input.[i] <> '\n' do i <- i + 1
    | c -> add c; i <- i + 1
  pushTok()
  tokens.ToArray()

//  Parser
let parse(tokens:string[]) : Expr * int =
  let rec parseAt i =
    if i >= tokens.Length then failwith "Unexpected end of tokens"
    match tokens.[i] with
    | "(" ->
        let mutable j = i + 1
        let elems = System.Collections.Generic.List<Expr>()
        while j < tokens.Length && tokens.[j] <> ")" do
          let (e, next) = parseAt j
          elems.Add(e)
          j <- next
        if j >= tokens.Length then failwith "Missing )"
        (List (List.ofSeq elems), j + 1)
    | ")" -> failwith "Unexpected )"
    | atom -> (Atom atom, i + 1)
  parseAt 0

let parseAll(input:string) : Expr list =
  let tokens = tokenize input
  let results = System.Collections.Generic.List<Expr>()
  let mutable i = 0
  while i < tokens.Length do
    let (e, next) = parse tokens.[i..]
    results.Add(e)
    i <- i + next
  List.ofSeq results

// Utilities
let isInteger(s:string) =
  match System.Int32.TryParse(s) with
  | true, v -> Some v
  | _ -> None

let rec ensureThunk(v:Value) : Value =
  match v with
  | VThunk r ->
      let res = (!r)()
      r := (fun() -> res)
      res
  | _ -> v

// Evaluation
let rec eval(expr:Expr) (env:Env) : Value =
  match expr with
  | Atom a ->
      match a with
      | "#t" -> VBool true
      | "#f" -> VBool false
      | _ ->
          match isInteger a with
          | Some n -> VInt n
          | None ->
              match env.TryFind(a) with
              | Some v -> ensureThunk v
              | None -> failwithf "Unbound symbol: %s" a

  | List [] -> VList []

  | List (Atom "quote" :: _) -> VList []

  | List (Atom "if" :: cond :: thenExpr :: elseExpr :: []) ->
      match eval cond env with
      | VBool true -> eval thenExpr env
      | VBool false -> eval elseExpr env
      | _ -> failwith "if condition must be boolean"

  | List (Atom "lambda" :: List paramList :: body :: []) ->
      let paramNames = paramList |> List.map (function Atom s -> s | _ -> failwith "Invalid param")
      VClosure(paramNames, body, env)

  | List (Atom "let" :: List binds :: body :: []) ->
      let pairs =
        binds |> List.map (function | List [Atom name; expr] -> name, eval expr env | _ -> failwith "Invalid let binding")
      let newEnv = pairs |> List.fold (fun m (k,v) -> Map.add k v m) env
      eval body newEnv

  | List (Atom "letrec" :: List binds :: body :: []) ->
      let placeholders = binds |> List.map (function | List [Atom name; _] -> name, ref (fun() -> VInt 0) | _ -> failwith "Invalid letrec binding")
      let envWithPlace = placeholders |> List.fold (fun m (n,r) -> Map.add n (VThunk r) m) env
      for (name, r) in placeholders do
        let boundExpr = binds |> List.find (function List [Atom n; _] -> n = name | _ -> false)
        let expr = match boundExpr with | List [_; e] -> e | _ -> failwith "logic"
        let value = eval expr envWithPlace
        r := (fun() -> value)
      eval body envWithPlace

  | List (Atom "begin" :: exprs) -> exprs |> List.map (fun e -> eval e env) |> List.last

  | List (Atom "delay" :: e :: []) -> VThunk (ref (fun() -> eval e env))

  | List (Atom "force" :: e :: []) ->
      match eval e env with
      | VThunk r -> ensureThunk (VThunk r)
      | other -> other

  | List (fn :: args) ->
      let f = eval fn env
      match f with
      | VPrimitive p -> let avals = args |> List.map (fun a -> eval a env) in p avals
      | VClosure(paramNames, body, closureEnv) ->
          if List.length paramNames <> List.length args then failwith "Arity mismatch"
          let argVals = args |> List.map (fun a -> eval a env)
          let newEnv = List.zip paramNames argVals |> List.fold (fun m (k,v) -> Map.add k v m) closureEnv
          eval body newEnv
      | _ -> failwith "Not a function"

//  Standard library
let prim name f = name, VPrimitive f
let primitives =
  [
    prim "+" (function | [VInt a; VInt b] -> VInt(a + b) | _ -> failwith "+ expects two integers")
    prim "-" (function | [VInt a; VInt b] -> VInt(a - b) | _ -> failwith "- expects two integers")
    prim "*" (function | [VInt a; VInt b] -> VInt(a * b) | _ -> failwith "* expects two integers")
    prim "/" (function | [VInt a; VInt b] when b<>0 -> VInt(a / b) | _ -> failwith "/ expects two integers and non-zero divisor")
    prim "=" (function | [VInt a; VInt b] -> VBool(a=b) | _ -> failwith "= expects two integers")
    prim "<" (function | [VInt a; VInt b] -> VBool(a<b) | _ -> failwith "< expects two integers")
    prim ">" (function | [VInt a; VInt b] -> VBool(a>b) | _ -> failwith "> expects two integers")
    prim "print" (fun args ->
        args |> List.iter (function
            | VInt n -> printf "%d" n
            | VBool b -> printf "%b" b
            | VList _ -> printf "(list) "
            | VClosure _ -> printf "(closure) "
            | VPrimitive _ -> printf "(primitive) "
            | VThunk _ -> printf "(thunk) ")
        printfn ""
        VBool true)
  ] |> Map.ofList


let initialEnv = primitives

//  Example program
let factorialProgram = "(begin (letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))) (print (fact 5))))"

[<EntryPoint>]
let main argv =
  try
    printfn "Parsing..."
    let exprs = parseAll factorialProgram
    printfn "Evaluating..."
    for e in exprs do ignore (eval e initialEnv)
    0
  with ex ->
    printfn "Error: %s" ex.Message
    1
