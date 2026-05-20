type t = { value : int }
type mode = Fast | Slow
type extensible = ..
type extensible += Added
exception E

module type S = sig
  val run : unit -> unit
end

module M : S = struct
  let run () = ()
end

class c = object
  val mutable iv = 0
  method m = iv
end

class type ct = object
  method n : int
end

let make value =
  M.run ();
  ignore Fast;
  if value < 0 then raise E;
  { value }
