let validate_input input =
  if String.length input > 100 then
    Fmt.failwith "Input too long: %d characters" (String.length input)
  else
    input

let validate_kstr n =
  if n < 0 then Fmt.failwith "n must not be negative: %d" n else n
