(* File with silenced warnings *)

let unused_function x = x + 1 [@warning "-27"]

[@@warning "-32"]
let another_unused = 42

let proper_function x = x * 2