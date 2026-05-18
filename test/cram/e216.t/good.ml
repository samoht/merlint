let validate_port port =
  if port < 0 || port > 65535 then
    Fmt.invalid_arg "Invalid port: %d" port
  else port

let validate_name name =
  if name = "" then
    Fmt.invalid_arg "Name must not be empty: got '%s'" name
  else name

let validate_kstr n =
  if n < 0 then Fmt.invalid_arg "n must not be negative: %d" n else n
