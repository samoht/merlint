(** Wrapper for OCaml Merlin commands *)

val dump_value : string -> string -> (Yojson.Safe.t, string) result
(** [dump_value format file] runs merlin dump and extracts the value field *)
