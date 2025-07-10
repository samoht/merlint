(** Wrapper for OCaml Merlin commands *)

type t = {
  browse : (Browse.t, string) result;
  parsetree : (Parsetree.t, string) result;
  outline : (Outline.t, string) result;
}
(** Result of all merlin analyses for a single file *)

val analyze_file : string -> t
(** Analyze a file with all merlin commands at once *)

val get_outline : string -> (Outline.t, string) result
(** [get_outline file] gets the outline from Merlin for the given file *)

val get_browse : string -> (Browse.t, string) result
(** [get_browse file] gets the browse analysis from Merlin for the given file *)

val get_parsetree : string -> (Parsetree.t, string) result
(** [get_parsetree file] gets the parsetree from Merlin for the given file *)
