let validate_input input =
  if String.length input > 100 then
    Fmt.failwith "Input too long: %d characters" (String.length input)
  else
    input