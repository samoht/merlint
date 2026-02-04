(** E350: Boolean Blindness

    This rule detects functions with 2 or more boolean parameters, which can
    lead to confusion about argument order and meaning. *)

val rule : Rule.t
(** The E350 rule definition *)
