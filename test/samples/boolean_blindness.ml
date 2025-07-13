(* Test file for boolean blindness detection *)

(* Should trigger E350: Functions with multiple boolean parameters *)
let create_window visible resizable fullscreen =
  if visible then
    if resizable then
      if fullscreen then "visible resizable fullscreen"
      else "visible resizable windowed"
    else
      if fullscreen then "visible fixed fullscreen"
      else "visible fixed windowed"
  else
    "hidden"

(* Should trigger E350: Two boolean parameters *)
let configure_app debug_mode verbose =
  if debug_mode && verbose then
    print_endline "Debug mode with verbose output"
  else if debug_mode then
    print_endline "Debug mode"
  else
    ()

(* Should NOT trigger: Only one boolean parameter *)
let set_visibility visible =
  if visible then "show" else "hide"

(* Should NOT trigger: No boolean parameters *)
let create_user ~name ~email =
  Printf.sprintf "User: %s <%s>" name email

(* Should trigger E350: Optional boolean parameters still count *)
let setup_logger ?(color = true) ?(timestamps = false) ?(verbose = false) () =
  Printf.sprintf "Logger: color=%b timestamps=%b verbose=%b" color timestamps verbose