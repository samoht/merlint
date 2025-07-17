(** E305: Module Naming Convention

    This rule enforces that module names follow OCaml naming conventions:
    - Should start with an uppercase letter
    - Should use Snake_case with capital first letter (e.g., My_module,
      Another_module) *)

val rule : Rule.t
(** The E305 rule definition *)
