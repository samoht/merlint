type t = { value : int }
type mode = Fast | Slow
exception E

module type S = sig
  val run : unit -> unit
end

module M : S = struct
  let run () = ()
end

class c = object
  method m = 0
end

class type ct = object
  method n : int
end

let make value =
  M.run ();
  ignore Fast;
  if value < 0 then raise E;
  { value }
