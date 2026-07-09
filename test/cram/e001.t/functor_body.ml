(* Complexity must be measured inside module bodies that are not a bare
   [struct ... end]: a functor body (Tmod_functor) and a signature-constrained
   body (Tmod_constraint). Both hide the same over-complex function. *)

module type S = sig
  val base : int
end

module Make (B : S) = struct
  let check_input x y z =
    if x > B.base then
      if y > B.base then
        if z > B.base then
          if x + y > z then
            if y + z > x then if x + z > y then "valid" else "invalid"
            else "invalid"
          else "invalid"
        else "invalid"
      else "invalid"
    else "invalid"
end

module Constrained : sig
  val check_input : int -> int -> int -> string
end = struct
  let check_input x y z =
    if x > 0 then
      if y > 0 then
        if z > 0 then
          if x + y > z then
            if y + z > x then if x + z > y then "valid" else "invalid"
            else "invalid"
          else "invalid"
        else "invalid"
      else "invalid"
    else "invalid"
end
