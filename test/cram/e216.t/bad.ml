let validate_port port =
  if port < 0 || port > 65535 then
    invalid_arg (Fmt.str "Invalid port: %d" port)
  else port

let validate_name name =
  if name = "" then
    invalid_arg (Fmt.str "Name must not be empty: got '%s'" name)
  else name

(* Multi-line form: regex would have missed this — AST walk catches it. *)
let validate_id id =
  if id < 0 then
    invalid_arg
      (Fmt.str "Invalid id: %d" id)
  else id

(* Another direct form: regex-sensitive rewrites used to miss nearby variants. *)
let validate_size n =
  if n < 0 then invalid_arg (Fmt.str "Size must be non-negative: %d" n)
  else n
