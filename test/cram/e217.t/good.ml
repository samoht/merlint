(* Use [Fmt.kstr] to thread the formatted string into the continuation. *)
let parse_error msg = Fmt.kstr (fun e -> Error e) "parse: %s" msg

let log s = print_endline s
let trace n = Fmt.kstr log "n=%d" n

let maybe x = Fmt.kstr (fun s -> Some s) "value: %s" x
