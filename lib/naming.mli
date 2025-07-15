(** Legacy naming module - all checks have been moved to rules/*.ml

    @deprecated
      Use individual E3xx rule modules instead:
      - E300: Variant naming convention
      - E305: Module naming convention
      - E310: Value naming convention
      - E315: Type naming convention
      - E320: Long identifier name
      - E325: Function naming convention
      - E330: Redundant module name
      - E335: Used underscore binding *)

val check :
  filename:string -> outline:Outline.t option -> Typedtree.t -> Issue.t list
(** [check ~filename ~outline typedtree] delegates to individual rule modules
    and aggregates their results. *)
