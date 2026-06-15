type t = Atom of string

let dump = function Atom s -> Codec.encode s
