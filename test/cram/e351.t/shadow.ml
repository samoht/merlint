module Shadow = struct
  type 'a ref = Ref of 'a
  type 'a array = Array of 'a list
end

open Shadow

let counter = Ref 0
let cache = Array []
