let make_error msg line = 
  Printf.sprintf "Error: %s at line %d" msg line
let print_count n = 
  Printf.printf "Processing %d items...\n" n