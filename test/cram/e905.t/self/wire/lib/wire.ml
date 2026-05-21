module Codec = struct
  type 'a t = string

  let v name _reader _writer = name
end

let codec = Codec.v "wire" () ()
let struct_ = ()
