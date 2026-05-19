(** Shared structural project queries used by lint rules. *)

val source_libraries : Project_index.t -> Project_index.Library.t list
(** [source_libraries index] returns every library stanza discovered in the
    source tree. *)

val library_module_map : Project_index.t -> (string * string list) list
(** [library_module_map index] maps each [.ml] module basename to the local
    names of source libraries that own it. *)

val resolve_library : Project_index.t -> string -> string
(** [resolve_library index name] maps a public library reference back to the
    local stanza name when the referenced library is in the source tree. Unknown
    and already-local names pass through unchanged. *)

val test_file_library : (string * string list) list -> string -> string option
(** [test_file_library module_map basename] returns the unique source library
    tested by [basename] when [basename] follows the [test_<module>] naming
    convention. *)
