(* File with bad naming conventions *)

module MyModule = struct
  let myFunction x = x + 1
end

type status = WaitingForInput | ProcessingData | Done

let checkValue v = v > 0
