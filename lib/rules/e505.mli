(** E505: Missing MLI File

    This rule ensures that library modules have corresponding .mli files.
    Library modules should have interface files for proper encapsulation. *)

val check : Context.t -> Issue.t list
(** [check project_root files] checks if library modules have corresponding .mli
    files. Returns a list of issues for missing .mli files. *)
