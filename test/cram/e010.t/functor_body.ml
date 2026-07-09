(* A deeply nested function inside a functor body is reported at its own
   location, not at the file's first line. *)

module type S = sig
  val base : int
end

module Make (B : S) = struct
  let process x y z =
    if x > B.base then
      if y > B.base then
        if z > B.base then
          if x < 100 then
            if y < 100 then
              x + y + z
            else 0
          else 0
        else 0
      else 0
    else 0
end
