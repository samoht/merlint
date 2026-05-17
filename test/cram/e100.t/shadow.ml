module Shadow = struct
  module Obj = struct
    let magic x = x
  end
end

open Shadow

let value = Obj.magic 1
