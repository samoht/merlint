(** Wrapper for OCaml Merlin commands *)

type t = {
  browse : (Browse.t, string) result;
  typedtree : (Ast.t, string) result;
  outline : (Outline.t, string) result;
}
(** Result of all merlin analyses for a single file *)

val analyze_file : string -> t
(** Analyze a file with all merlin commands at once *)

val dump_value : string -> string -> (Yojson.Safe.t, string) result
(** [dump_value format file] runs merlin dump command and returns the JSON value
*)
