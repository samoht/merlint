(** Project root discovery *)

val root : string -> string
(** [root path] finds the project root by looking for dune-project file. If
    [path] is a directory, searches from that directory. If [path] is a file,
    searches from its parent directory. Returns the current working directory if
    no project root is found. *)
