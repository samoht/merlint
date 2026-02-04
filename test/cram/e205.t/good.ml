(* Requires: opam install fmt *)
let make_error msg line = 
  Fmt.str "Error: %s at line %d" msg line
let print_count n = 
  Fmt.pr "Processing %d items...@." n