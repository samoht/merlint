(* Canonical filesystem paths for merlint. Re-exports the index's path type so
   merlint and the project index share one path representation: a path is made
   canonical once and then carried, compared and rendered without further
   normalisation. *)
include Project_index.Path

(* [display] as a directory path (trailing slash), for directory diagnostics. *)
let dir_display p = Fpath.(to_string (to_dir_path (v (display p))))
