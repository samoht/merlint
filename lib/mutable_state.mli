(** Detection of global mutable state patterns *)

val check_global_mutable_state : filename:string -> Outline.t -> Issue.t list
(** [check_global_mutable_state ~filename outline] checks for global mutable
    state (refs, arrays) defined at the module level. These make code harder to
    test and reason about. *)

val check_local_mutable_state : filename:string -> Typedtree.t -> Issue.t list
(** [check_local_mutable_state ~filename typedtree] checks for local mutable
    state usage. Currently returns empty list - would need deeper AST analysis.
*)
