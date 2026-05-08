(* Inline Fmt.kstr (fun _ -> Error _) and (fun _ -> raise _) call sites
   that should be extracted into top-of-file helpers. *)
type wire_err = Of_wire_error of string

exception Parse_error of string

(* Mis-named helper: this raises but its name doesn't start with [fail_].
   The rule should flag it and suggest a rename. *)
let eval_errorf fmt = Fmt.kstr (fun s -> raise (Parse_error s)) fmt

let parse_header s =
  if s = "" then Fmt.kstr (fun s -> Error (Of_wire_error s)) "empty header"
  else Ok s

let parse_body s =
  if String.length s > 1024 then
    Fmt.kstr
      (fun s -> Error (Of_wire_error s))
      "body too long: %d bytes" (String.length s)
  else Ok s

let parse_int s =
  match int_of_string_opt s with
  | Some n -> n
  | None -> Fmt.kstr (fun s -> raise (Parse_error s)) "not an int: %S" s
