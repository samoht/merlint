type t = unit

let reader = ()
let writer = ()
let codec = Wire.Codec.v "foo" reader writer
