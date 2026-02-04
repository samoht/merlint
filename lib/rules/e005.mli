(** E005: Long Functions

    This rule detects functions that exceed a configurable length threshold.
    Long functions are harder to understand, test, and maintain. *)

val rule : Rule.t
(** The E005 rule definition *)
