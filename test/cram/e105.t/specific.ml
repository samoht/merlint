let parse_int s =
  try int_of_string s with
  | Failure _ -> 0

let read_config () =
  try 
    let ic = open_in "config.txt" in
    let data = input_line ic in
    close_in ic;
    data
  with
  | Sys_error msg -> 
      Fmt.epr "Config error: %s@." msg;
      "default"
  | End_of_file -> 
      Fmt.epr "Config file is empty@.";
      "default"