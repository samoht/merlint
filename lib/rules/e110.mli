(** E110: Silenced Warning

    This rule detects code that silences warnings instead of fixing them.
    Warnings should be addressed rather than suppressed. *)

val check : Context.project -> Issue.t list
(** [check files] analyzes the list of files to find silenced warnings. Returns
    a list of issues for each silenced warning found. *)
