type session = { mutable seen : int; payload : bytes }
type t = Idle | Busy of session

let v = Idle
let handle s (_ : string) = s
