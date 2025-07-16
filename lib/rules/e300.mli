(** E300: Variant Naming Convention

    This rule enforces that variant constructors follow OCaml naming
    conventions:
    - Should start with an uppercase letter
    - Should use PascalCase (e.g., MyVariant, SomeConstructor) *)

val check : Context.file -> Issue.t list
(** [check AST] analyzes the AST to find variant constructors that don't follow
    naming conventions. Returns a list of issues for variants that violate the
    rule. *)
