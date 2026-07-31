(** E425: Type Documentation Bound to a Constructor.

    This rule detects a doc comment written after the last constructor of a
    variant type, where OCaml attaches it to that constructor and leaves the
    type undocumented. *)

val rule : Rule.t
(** [rule] is the E425 rule definition. *)
