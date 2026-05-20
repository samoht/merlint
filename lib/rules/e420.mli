(** E420: Missing Odoc Cross-Reference Links.

    This rule detects documentation code spans that name exported interface
    items and should therefore be odoc links. *)

val rule : Rule.t
(** [rule] is the E420 rule definition. *)
