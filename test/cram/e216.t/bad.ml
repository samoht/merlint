let validate_port port =
  if port < 0 || port > 65535 then
    invalid_arg (Fmt.str "Invalid port: %d" port)
  else port

let validate_name name =
  if name = "" then
    invalid_arg (Fmt.str "Name must not be empty: got '%s'" name)
  else name
