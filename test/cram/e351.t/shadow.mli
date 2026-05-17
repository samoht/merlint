module Shadow : sig
  type 'a ref = Ref of 'a
  type 'a array = Array of 'a list
end

open Shadow

val counter : int ref
val cache : int array
