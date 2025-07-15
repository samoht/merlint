(** Legacy API design module - all checks have been moved to rules/*.ml *)

val check :
  filename:string -> outline:Outline.t option -> Typedtree.t -> Issue.t list
(** Legacy function for unit tests - returns empty list since all checks moved
    to rules/*.ml *)
