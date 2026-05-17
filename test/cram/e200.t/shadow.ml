module Shadow = struct
  module Str = struct
    let regexp x = x
    let string_match _ _ _ = false
  end
end

open Shadow

let contains_at s =
  Str.string_match (Str.regexp ".*@.*") s 0
