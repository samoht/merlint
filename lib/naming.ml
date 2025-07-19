(** Naming convention utilities *)

let to_snake_case name =
  (* Convert PascalCase to snake_case *)
  let buffer = Buffer.create (String.length name) in
  let add_char c = Buffer.add_char buffer c in
  let add_underscore () =
    if
      Buffer.length buffer > 0
      && Buffer.nth buffer (Buffer.length buffer - 1) <> '_'
    then Buffer.add_char buffer '_'
  in

  for i = 0 to String.length name - 1 do
    let c = name.[i] in
    if c >= 'A' && c <= 'Z' then (
      if i > 0 then add_underscore ();
      add_char (Char.lowercase_ascii c))
    else add_char c
  done;
  Buffer.contents buffer

let is_pascal_case name =
  String.length name > 0
  && name.[0] >= 'A'
  && name.[0] <= 'Z'
  && not (String.contains name '_')
