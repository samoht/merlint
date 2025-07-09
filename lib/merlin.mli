(** Wrapper for OCaml Merlin commands *)

val get_outline : string -> (Yojson.Safe.t, string) result
(** [get_outline file] gets the outline from Merlin for the given file *)

val dump_value : string -> string -> (Yojson.Safe.t, string) result
(** [dump_value format file] runs merlin dump and extracts the value field *)
