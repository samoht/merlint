(** Wrapper for OCaml Merlin commands *)

type t = {
  browse : (Browse.t, string) result;
  typedtree : (Typedtree.t, string) result;
  outline : (Outline.t, string) result;
}
(** Result of all merlin analyses for a single file *)

val analyze_file : string -> t
(** Analyze a file with all merlin commands at once *)

val get_outline : string -> (Outline.t, string) result
(** [get_outline file] gets the outline from Merlin for the given file *)

val get_typedtree : string -> (Typedtree.t, string) result
(** [get_typedtree file] gets the typedtree from Merlin for the given file *)

val get_parsetree : string -> (Parsetree.t, string) result
(** [get_parsetree file] gets the parsetree from Merlin for the given file *)
