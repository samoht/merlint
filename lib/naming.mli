(** Naming convention utilities *)

val to_snake_case : string -> string
(** [to_snake_case name] converts PascalCase to snake_case *)

val to_pascal_case : string -> string
(** [to_pascal_case name] converts snake_case to PascalCase *)

val is_pascal_case : string -> bool
(** [is_pascal_case name] checks if name follows PascalCase convention *)
