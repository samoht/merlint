type wire_err = Of_wire_error of string

exception Parse_error of string

let err_wire fmt = Fmt.kstr (fun s -> Error (Of_wire_error s)) fmt
let fail_parse fmt = Fmt.kstr (fun s -> raise (Parse_error s)) fmt

(* One-shot helpers — kstr body of a let binding, even with a literal
   format. These are the [extract a helper] outcome, just specialised
   to a single call. The rule must not flag them either. *)
let err_too_long n =
  Fmt.kstr (fun s -> Error (Of_wire_error s)) "too long: %d" n

let fail_bad x = Fmt.kstr (fun s -> raise (Parse_error s)) "bad token %s" x

let parse_header s = if s = "" then err_wire "empty header" else Ok s

let parse_body s =
  if String.length s > 1024 then
    err_wire "body too long: %d bytes" (String.length s)
  else Ok s

let parse_int s =
  match int_of_string_opt s with
  | Some n -> n
  | None -> fail_parse "not an int: %S" s
