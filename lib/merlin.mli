(** Wrapper for OCaml Merlin commands *)

type t = { outline : (Outline.t, string) result; dump : (Ast.t, string) result }
(** Result of merlin analyses for a single file *)

val analyze_file : string -> t
(** Analyze a file with merlin commands *)

val dump_value : string -> string -> (Yojson.Safe.t, string) result
(** [dump_value format file] runs merlin dump command and returns the JSON value
*)
