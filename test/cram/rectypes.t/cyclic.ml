(* A unit compiled with [-rectypes]. Two of the types below are cyclic: a node
   of the type expression is its own descendant, so the type is a graph with a
   loop in it rather than a tree. A walk over one that does not record where it
   has been never terminates, and that is a defect in whatever does the walking
   -- [-rectypes] is legal OCaml and a user of merlint may enable it. *)

(* [step] has type [int -> 'a as 'a]: it returns itself, so its chain of arrows
   never ends. merlint's [typed_arg_labels] followed that chain and built an
   infinite list of argument labels, dying of Stack_overflow inside the lazy
   every typedtree-backed rule shares -- one fault, reported as six crashed
   checks. *)
let rec step (_ : int) = step

type 'a box = { v : 'a }

(* [same]'s argument has type ['a box as 'a]: the type is its own type
   argument. E106 walks the operand type of a polymorphic comparison, and
   followed that loop with no exit from it. *)
let same (x : 'a box as 'a) = x = x

(* Two finite declarations beside the cyclic ones. They are violations, of E325
   and of E350, and both rules walk an arrow chain to find them: the transcript
   below shows each still walking a finite type to its end rather than stopping
   at the first node. *)
let get_first ~key (xs : (string * int) list) = List.assoc_opt key xs
let create_window visible resizable = visible && resizable
