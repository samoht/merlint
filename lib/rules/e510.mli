(** E510: Missing Log Source

    This rule checks that logging calls include a source parameter. Logging
    without a source makes it difficult to trace issues in production. *)

val rule : Rule.t
(** The E510 rule definition *)
