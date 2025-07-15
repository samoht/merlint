(** E305: Module Naming Convention

    This rule enforces that module names follow OCaml naming conventions:
    - Should start with an uppercase letter
    - Should use Snake_case with capital first letter (e.g., My_module,
      Another_module) *)

val check : Typedtree.t -> Issue.t list
(** [check typedtree] analyzes the typedtree to find modules that don't follow
    naming conventions. Returns a list of issues for modules that violate the
    rule. *)
