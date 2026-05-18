let validate_input input =
  if String.length input > 100 then
    failwith (Fmt.str "Input too long: %d characters" (String.length input))
  else
    input

(* Multi-line form: regex would have missed this — AST walk catches it. *)
let validate_short input =
  if String.length input < 1 then
    failwith
      (Fmt.str "Input too short: %d characters" (String.length input))
  else
    input

(* Another direct form: regex-sensitive rewrites used to miss nearby variants. *)
let validate_zero n =
  if n = 0 then failwith (Fmt.str "n must not be zero: %d" n) else n

let validate_kstr n =
  if n < 0 then Fmt.kstr failwith "n must not be negative: %d" n else n
