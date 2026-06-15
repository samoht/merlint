type t = Idle
type error = Bad

let v = Idle
let handle t = function "bad" -> Error Bad | _ -> Ok t
