let parse_int s =
  try int_of_string s with _ -> 0

let read_config () =
  try 
    let ic = open_in "config.txt" in
    let data = input_line ic in
    close_in ic;
    data
  with _ -> "default"