module Codec = struct
  let v name reader writer = (name, reader, writer)
end

let codec = Codec.v "wire" "reader" "writer"
