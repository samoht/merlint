(* Use the matching Fmt helper directly, no [Fmt.str] wrapping. *)
let parse_error msg = Fmt.kstr (fun e -> Error e) "parse: %s" msg

let log s = print_endline s
let trace n = Fmt.kstr log "n=%d" n

let maybe x = Fmt.kstr (fun s -> Some s) "value: %s" x

let log_event buf kind msg = Fmt.bprintf buf "[%s] %s\n" kind msg
let dump_stdout n = Fmt.pr "n=%d@." n
let dump_stderr n = Fmt.epr "n=%d@." n
let put_string s = Fmt.pr "%s" s
