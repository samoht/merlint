(** E510: Missing Log Source

    This rule checks that logging calls include a source parameter. Logging
    without a source makes it difficult to trace issues in production. *)

val check : Context.file -> Issue.t list
(** [check files] checks if logging calls include source parameters. Returns a
    list of issues for logging calls without sources. *)
