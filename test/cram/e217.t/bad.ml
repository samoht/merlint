(* Constructor argument: [Error (Fmt.str ...)] -> [Fmt.kstr (fun e -> Error e) ...]. *)
let parse_error msg = Error (Fmt.str "parse: %s" msg)

(* Generic single-argument apply: [log (Fmt.str ...)] -> [Fmt.kstr log ...]. *)
let log s = print_endline s
let trace n = log (Fmt.str "n=%d" n)

(* [Some (Fmt.str ...)] is also a constructor application — flagged. *)
let maybe x = Some (Fmt.str "value: %s" x)

(* Specialized cases handled by E215/E216/E616 are NOT flagged here. *)
let crash msg = failwith (Fmt.str "crash: %s" msg)
let bad_arg n = invalid_arg (Fmt.str "n: %d" n)
