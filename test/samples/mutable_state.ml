(* Test file for mutable state detection *)

(* Should trigger E351: ref usage *)
let counter = ref 0
let increment () = counter := !counter + 1

(* Should trigger E351: mutable record fields *)
type config = {
  mutable debug : bool;
  mutable log_level : int;
}

let cfg = { debug = false; log_level = 0 }
let toggle_debug () = cfg.debug <- not cfg.debug

(* Should trigger E351: array creation *)
let cache = Array.make 100 None
let clear_cache () = Array.fill cache 0 100 None

(* Should NOT trigger: immutable alternatives *)
let add_one x = x + 1

type immutable_config = {
  debug : bool;
  log_level : int;
}

let update_config config ~debug = { config with debug }

(* Should trigger E351: using ref in local scope *)
let compute_sum lst =
  let sum = ref 0 in
  List.iter (fun x -> sum := !sum + x) lst;
  !sum