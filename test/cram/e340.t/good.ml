(* Define error helpers at the top of the file *)
let err_invalid x = Error (Fmt.str "Invalid data: %d" x)
let err_too_large n = Error (Fmt.str "Data too large: %d" n)
let err_invalid_string s = Error (`Msg (Fmt.str "Invalid string: '%s' is empty" s))
let err_string_too_long len = Error (`Msg (Fmt.str "String too long: %d characters" len))

let process_data x =
  match x with
  | 0 -> err_invalid x
  | n -> 
      if n > 100 then
        err_too_large n
      else Ok n

let process_string s =
  if s = "" then
    err_invalid_string s
  else if String.length s > 100 then
    err_string_too_long (String.length s)
  else
    Ok s