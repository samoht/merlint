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
let digest s = s
let signature n payload = Fmt.str "%d.%s" n payload |> digest
let log_event_pipeline buf msg = Fmt.str "event: %s" msg |> Buffer.add_string buf

(* Infix operators (e.g. [Bos.Cmd.( % )]) take their argument before the
   string and cannot be wrapped as [Fmt.kstr op "..."]. The rule should
   NOT flag these. *)
let ( % ) cmd s = cmd ^ " " ^ s
let ( ++ ) cmd s = cmd ^ " " ^ s
let cmd1 base name = base % Fmt.str "name=%s" name
let cmd2 base region = base ++ Fmt.str "region=%s" region

(* These calls do contain [Fmt.str], but it is not the sole string argument to
   a continuation. Rewriting them as [Fmt.kstr Alcotest.check "..."] or
   [Fmt.kstr fail "..."] would not typecheck and should not be suggested. *)
let check_rendered n =
  Alcotest.(check string) "rendered" "n=1" (Fmt.str "n=%d" n)

let fail name msg = failwith (name ^ ": " ^ msg)
let fail_named name n = fail name (Fmt.str "n=%d" n)

let finish ?message () = ignore message
let finish_progress n = finish ~message:(Fmt.str "n=%d" n) ()
