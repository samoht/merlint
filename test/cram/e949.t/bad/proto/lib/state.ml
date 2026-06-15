module Sender = struct
  type t = { seq : int }

  let v = { seq = 0 }
end

module Receiver = struct
  type t = { acked : int }

  let v = { acked = 0 }
end
