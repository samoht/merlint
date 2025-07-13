(** API design checks for merlint *)

val count_bool_params : string -> int
(** Count boolean parameters in a function signature. Exposed for testing. *)

val check :
  filename:string -> outline:Outline.t option -> Typedtree.t -> Issue.t list
(** Check for API design issues in the given file *)
