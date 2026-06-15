type t = Idle

let v = Idle
let handle t (_ : string) : (t * string list, string) result = Ok (t, [])
