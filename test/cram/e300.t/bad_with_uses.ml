type t = BadCase | Good_case

let x = BadCase

let y =
  match x with
  | BadCase -> Good_case
  | Good_case -> BadCase
