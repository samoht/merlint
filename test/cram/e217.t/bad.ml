(* Constructor: [Error (Fmt.str ...)] -> [Fmt.kstr (fun e -> Error e) ...]. *)
let parse_error msg = Error (Fmt.str "parse: %s" msg)

(* Generic apply: [log (Fmt.str ...)] -> [Fmt.kstr log ...]. *)
let log s = print_endline s
let trace n = log (Fmt.str "n=%d" n)

(* Constructor with multiple cases — both flagged with kstr-Constr suggestion. *)
let maybe x = Some (Fmt.str "value: %s" x)

(* Specialized outputs get tailored suggestions. *)
let log_event buf kind msg =
  Buffer.add_string buf (Fmt.str "[%s] %s\n" kind msg)

let dump_stdout n = print_endline (Fmt.str "n=%d" n)
let dump_stderr n = prerr_endline (Fmt.str "n=%d" n)
let put_string s = print_string (Fmt.str "%s" s)

(* Specialized cases handled by E215/E216/E616 are NOT flagged here. *)
let crash msg = failwith (Fmt.str "crash: %s" msg)
let bad_arg n = invalid_arg (Fmt.str "n: %d" n)
