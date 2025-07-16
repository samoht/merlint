(** E600: Test Module Convention

    This rule ensures that test files follow proper conventions. Test modules
    should export 'suite' not module name. *)

val check : Context.t -> Issue.t list
(** [check files] analyzes the list of files to find test files that don't
    follow proper conventions. Returns a list of issues for files that violate
    the rule. *)
