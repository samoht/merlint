let process_data x =
  match x with
  | 0 -> Error (Fmt.str "Invalid data: %d" x)
  | n -> 
      if n > 100 then
        Error (Fmt.str "Data too large: %d" n)
      else Ok n

let process_string s =
  if s = "" then
    Error (`Msg (Fmt.str "Invalid string: '%s' is empty" s))
  else if String.length s > 100 then
    Error (`Msg (Fmt.str "String too long: %d characters" (String.length s)))
  else
    Ok s