type t = Idle

let v = Idle
let incoming t (_ : string) = t
let outgoing t = (t, [])
let close t = (t, None)
