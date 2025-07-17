(** Linting engine *)

val get_project_root : string -> string
(** Find the project root by looking for dune-project file. Given a file or
    directory path, searches upward for dune-project. *)

val run :
  filter:Filter.t ->
  exclude:string list ->
  ?files:string list ->
  string ->
  Rule.Run.result list
(** Run all checks on a project. [run ~filter ~exclude ?files project_root] runs
    all enabled rules on the project at [project_root], excluding files matching
    patterns in [exclude]. If [files] is provided, analyzes only those files;
    otherwise discovers files using dune describe. Returns a sorted list of
    issues found. *)
