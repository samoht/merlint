let make_error msg line = 
  Stdlib.Printf.sprintf "Error: %s at line %d" msg line
let print_count n = 
  Stdlib.Printf.printf "Processing %d items...\n" n