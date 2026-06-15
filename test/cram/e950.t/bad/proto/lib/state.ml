type t = Idle

let v = Idle

let handle t = function
  | "bad" -> failwith "nope"
  | "unreachable" -> assert false
  | _ -> t
