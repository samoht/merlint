(* Configuration module *)

type config = {
  debug : bool;
  verbose : bool;
  max_iterations : int;
}

let default = {
  debug = false;
  verbose = false;
  max_iterations = 100;
}

let from_env () =
  let debug = try Sys.getenv "DEBUG" = "1" with Not_found -> false in
  { default with debug }