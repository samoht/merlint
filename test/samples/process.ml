(* Test file for redundant module name detection *)

(* Bad: redundant module name in function names *)
let process_start config = 
  print_endline "Starting process"

let process_stop () = 
  print_endline "Stopping process"

let process_restart config =
  process_stop ();
  process_start config

(* Bad: redundant module name in type names *)
type process_config = {
  name: string;
  timeout: int;
}

type process_state = Running | Stopped

(* Good: no redundant module name *)
let initialize () = 
  print_endline "Initializing"

let cleanup () = 
  print_endline "Cleaning up"

type options = {
  verbose: bool;
}