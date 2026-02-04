[@@@ocaml.warning "-32"]
let unused_function x = x + 1

[@@ocaml.warning "-27"]
let partial_match = function
  | Some x -> x

[@ocaml.warning "-9"]
type t = { mutable field : int; another : string }