type t = Ping | Pong

let encode = function Ping -> Codec.tag "p" | Pong -> Codec.tag "P"
