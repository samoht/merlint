(* Good example - encapsulated state *)

(* Internal state - not exposed in interface *)
let counter = ref 0
let cache = Hashtbl.create 100

(* Functions that encapsulate state access *)
let init () = 
  counter := 0;
  Hashtbl.clear cache

let increment () = 
  incr counter;
  !counter

let get_count () = !counter

let cache_get key = 
  try Some (Hashtbl.find cache key)
  with Not_found -> None

let cache_set key value = 
  Hashtbl.replace cache key value

let cache_clear () = 
  Hashtbl.clear cache