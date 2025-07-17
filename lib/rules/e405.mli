(** E405: Missing Type Documentation

    This rule checks that public types have proper documentation. Types exposed
    in .mli files should be documented for API clarity. *)

val rule : Rule.t
(** The E405 rule definition *)
