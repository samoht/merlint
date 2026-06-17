type t = Idle

let v = Idle
let outgoing t = (t, [])
let close t = (t, None)
