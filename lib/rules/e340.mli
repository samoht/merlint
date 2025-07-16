(** E340: Error Pattern Detection

    This rule detects usage of Error (Fmt.str ...) patterns and suggests using
    error helper functions (err_foo) instead. *)

val check : Context.file -> Issue.t list
(** [check file_path file_content] detects Error (Fmt.str ...) patterns in file
    content. Returns a list of issues for each pattern found. *)
