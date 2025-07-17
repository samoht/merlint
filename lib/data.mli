(** Central registry of all linting rules *)

val all_rules : Rule.t list
(** All available linting rules *)

val file_rules : Rule.t list
(** Rules that operate on individual files *)

val project_rules : Rule.t list
(** Rules that operate on the entire project *)
