(** E205: Consider Using Fmt Module

    This rule suggests using the Fmt module instead of Printf/Format. While
    Printf and Format are part of OCaml's standard library and perfectly fine to
    use, Fmt offers additional features. *)

val check : Typedtree.t -> Issue.t list
(** [check typedtree] analyzes the typedtree to find usage of Printf/Format
    modules. Returns a list of issues for each usage found. *)
