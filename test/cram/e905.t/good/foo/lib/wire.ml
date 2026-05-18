module Codec = struct
  type 'a t = string

  let v name _reader _writer = name
end
