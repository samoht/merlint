let process_data x =
  match x with
  | 0 -> Error (Fmt.str "Invalid data: %d" x)
  | n -> 
      if n > 100 then
        Error (Fmt.str "Data too large: %d" n)
      else Ok n