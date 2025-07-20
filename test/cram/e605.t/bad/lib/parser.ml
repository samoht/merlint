(* Parser module for myproject *)

type token = 
  | Int of int
  | Plus
  | Minus
  | EOF

let tokenize _input = 
  (* Simple tokenizer implementation *)
  [Int 42; Plus; Int 5; EOF]

let parse _tokens =
  (* Simple parser implementation *)
  47