(** E205: Consider Using Fmt Module

    This rule suggests using the Fmt module instead of Printf/Format. While
    Printf and Format are part of OCaml's standard library and perfectly fine to
    use, Fmt offers additional features. *)

val rule : Rule.t
(** The E205 rule definition *)
