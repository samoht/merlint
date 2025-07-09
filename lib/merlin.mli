(** Wrapper for OCaml Merlin commands *)

type file_analysis = {
  browse : (Yojson.Safe.t, string) result;
  parsetree : (Yojson.Safe.t, string) result;
  outline : (Yojson.Safe.t, string) result;
}
(** Result of all merlin analyses for a single file *)

val analyze_file : string -> file_analysis
(** Analyze a file with all merlin commands at once *)

val get_outline : string -> (Yojson.Safe.t, string) result
(** [get_outline file] gets the outline from Merlin for the given file *)

val dump_value : string -> string -> (Yojson.Safe.t, string) result
(** [dump_value format file] runs merlin dump and extracts the value field *)
