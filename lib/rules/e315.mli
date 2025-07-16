(** E315: Type Naming Convention

    This rule ensures that type names follow OCaml naming conventions. Types
    should use snake_case naming (except 't' and 'id' which are idiomatic). *)

val check : Context.t -> Issue.t list
(** [check AST] analyzes the AST to find types with names that don't follow
    snake_case convention. Returns a list of issues for types that violate the
    rule. *)
