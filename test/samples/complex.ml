(* Function with high cyclomatic complexity *)
let is_number s =
  try
    ignore (int_of_string s);
    true
  with _ -> false

let process_command cmd args =
  match cmd with
  | "add" -> (
      match args with
      | [ a; b ] ->
          if is_number a && is_number b then
            Ok (int_of_string a + int_of_string b)
          else Error "Invalid numbers"
      | _ -> Error "Wrong number of arguments")
  | "sub" -> (
      match args with
      | [ a; b ] ->
          if is_number a && is_number b then
            Ok (int_of_string a - int_of_string b)
          else Error "Invalid numbers"
      | _ -> Error "Wrong number of arguments")
  | "mul" -> (
      match args with
      | [ a; b ] ->
          if is_number a && is_number b then
            Ok (int_of_string a * int_of_string b)
          else Error "Invalid numbers"
      | _ -> Error "Wrong number of arguments")
  | "div" -> (
      match args with
      | [ a; b ] ->
          if is_number a && is_number b then
            let b_int = int_of_string b in
            if b_int = 0 then Error "Division by zero"
            else Ok (int_of_string a / b_int)
          else Error "Invalid numbers"
      | _ -> Error "Wrong number of arguments")
  | _ -> Error "Unknown command"
