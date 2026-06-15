(** E106: Polymorphic comparison

    This rule detects Stdlib's structural [(=)], [(<>)], [(<)], [(>)], [(<=)],
    [(>=)], [compare], [min], [max] and [Hashtbl.hash] applied to a concrete
    non-scalar type, where walking the runtime representation breaks
    abstraction, may crash on functional values, and ignores any custom
    equality. *)

val rule : Rule.t
(** [rule] is the E106 rule definition. *)
