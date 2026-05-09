(* Use the matching Fmt helper directly, no [Fmt.str] wrapping. *)
let parse_error msg = Fmt.kstr (fun e -> Error e) "parse: %s" msg

let log s = print_endline s
let trace n = Fmt.kstr log "n=%d" n

let maybe x = Fmt.kstr (fun s -> Some s) "value: %s" x

let log_event buf kind msg = Fmt.pf (Fmt.with_buffer buf) "[%s] %s\n" kind msg
let dump_stdout n = Fmt.pr "n=%d@." n
let dump_stderr n = Fmt.epr "n=%d@." n
let put_string s = Fmt.pr "%s" s

(* Pipe chains preserve left-to-right data flow; the [Fmt.kstr] rewrite
   would reverse it. The rule should NOT flag these. *)
let pp_int ppf n = Fmt.pf ppf "%d" n
let printed n = n |> Fmt.str "%a" pp_int |> print_endline
let chain n = n |> Fmt.str "%a" pp_int |> String.length

(* Infix operators (e.g. [Bos.Cmd.( % )]) take their argument before the
   string and cannot be wrapped as [Fmt.kstr op "..."]. The rule should
   NOT flag these. *)
let ( % ) cmd s = cmd ^ " " ^ s
let cmd1 base name = base % Fmt.str "name=%s" name
let cmd2 base region = base ^^ Fmt.str "region=%s" region
