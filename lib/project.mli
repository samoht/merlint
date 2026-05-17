(** Project root discovery *)

val root : string -> string
(** [root path] finds the enclosing Dune root: the nearest [dune-workspace]
    ancestor when present, otherwise the nearest [dune-project]. If [path] is a
    directory, searches from that directory. If [path] is a file, searches from
    its parent directory. Returns the current working directory if no project
    root is found. *)

val workspace_root : string -> string
(** [workspace_root path] is kept for compatibility and uses the same Dune root
    policy as {!root}. *)

val config_files : string -> string list
(** [config_files path] returns all [merlint.toml] config file paths from [path]
    up to the workspace root, ordered outermost-first. Closer configs override
    settings from outer ones; exclusions accumulate. *)
