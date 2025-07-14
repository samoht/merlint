(* Global mutable state - avoid this *)
let counter = ref 0
let incr_counter () = counter := !counter + 1

let global_cache = Array.make 100 None
let cached_results = Hashtbl.create 100