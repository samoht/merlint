(* Requires: opam install re *)
let at_re = Re.compile (Re.str "@")
let contains_at s = Re.execp at_re s