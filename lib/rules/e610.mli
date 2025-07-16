(** E610: Test Without Library

    This rule ensures that test files have corresponding library modules.
    Orphaned test files should be removed or their library modules should be
    created. *)

val check : Context.project -> Issue.t list
(** [check dune_data files] checks if test files have corresponding library
    modules. Returns a list of issues for orphaned test files. *)
