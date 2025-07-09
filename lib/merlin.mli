(** Wrapper for OCaml Merlin commands *)

val dump : string -> string -> (Yojson.Safe.t, string) result
(** [dump format file] runs merlin dump command and returns full JSON *)

val dump_value : string -> string -> (Yojson.Safe.t, string) result
(** [dump_value format file] runs merlin dump and extracts the value field *)
