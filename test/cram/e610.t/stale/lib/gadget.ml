(* Control is a library module with no source file of its own, so only this
   unit's typedtree records that it exists. *)
module Control = struct
  type t = Idle | Running

  let start = function Idle -> Running | Running -> Running
end

let run () = Control.start Control.Idle
