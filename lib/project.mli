(** Project root discovery *)

val root : string -> string
(** [root path] finds the nearest project root by looking for dune-project file.
    If [path] is a directory, searches from that directory. If [path] is a file,
    searches from its parent directory. Returns the current working directory if
    no project root is found. *)

val workspace_root : string -> string
(** [workspace_root path] finds the outermost dune-project root by walking up
    from [path]. In a monorepo, this returns the top-level root rather than a
    subdirectory's own project root. *)

val config_files : string -> string list
(** [config_files path] returns all [.merlint] config file paths from [path] up
    to the workspace root, ordered outermost-first. Closer configs override
    settings from outer ones; exclusions accumulate. *)
