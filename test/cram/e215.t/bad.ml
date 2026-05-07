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

(* Module-qualified form: regex would have missed [Stdlib.failwith]. *)
let validate_zero n =
  if n = 0 then Stdlib.failwith (Fmt.str "n must not be zero: %d" n) else n
