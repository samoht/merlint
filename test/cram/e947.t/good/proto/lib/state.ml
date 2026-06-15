type session = { seen : int; payload : string }
type t = Idle | Busy of session

let v = Idle
let handle s (_ : string) = s
