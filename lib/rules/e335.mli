(** E335: Used Underscore-Prefixed Binding

    This rule detects bindings prefixed with underscore (indicating they should
    be unused) that are actually used in the code. *)

val rule : Rule.t
(** The E335 rule definition *)
