type t = Idle

let v = Idle
let handle t (_ : string) = t
let outgoing t = (t, [])
let close t = (t, None)
