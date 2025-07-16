(** E351: Global Mutable State

    This rule detects global mutable state (refs, arrays) defined at the module
    level. Global mutable state makes code harder to test and reason about. *)

val check : Context.t -> Issue.t list
(** [check_global_mutable_state ~filename outline] checks for global mutable
    state (refs, arrays) defined at the module level. Returns a list of issues
    for each global mutable value found. *)
