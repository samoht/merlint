(** E315: Type Naming Convention

    This rule ensures that type names follow OCaml naming conventions. Types
    should use snake_case naming (except 't' and 'id' which are idiomatic). *)

val rule : Rule.t
(** The E315 rule definition *)
