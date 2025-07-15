(** E300: Variant Naming Convention

    This rule enforces that variant constructors follow OCaml naming
    conventions:
    - Should start with an uppercase letter
    - Should use PascalCase (e.g., MyVariant, SomeConstructor) *)

val check : Typedtree.t -> Issue.t list
(** [check typedtree] analyzes the typedtree to find variant constructors that
    don't follow naming conventions. Returns a list of issues for variants that
    violate the rule. *)
