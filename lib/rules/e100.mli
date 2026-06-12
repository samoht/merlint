(** E100: No Obj usage

    This rule detects any reference into the [Stdlib.Obj] module (magic, repr,
    obj, tag, ...), all of which bypass OCaml's type system and can lead to
    runtime crashes. *)

val rule : Rule.t
(** [rule] is the E100 rule definition. *)
