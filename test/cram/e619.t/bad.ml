let validate_input input =
  if String.length input > 100 then
    failwith (Fmt.str "Input too long: %d characters" (String.length input))
  else
    input