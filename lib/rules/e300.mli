(** E300: Variant Naming Convention

    This rule enforces that variant constructors follow OCaml naming
    conventions:
    - Should start with an uppercase letter
    - Should use PascalCase (e.g., MyVariant, SomeConstructor) *)

val rule : Rule.t
(** The E300 rule definition *)
