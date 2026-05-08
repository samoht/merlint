(** OCamlmerlin outline output - thin re-export over [Merlin.outline]. *)

type kind = Merlin.symbol_kind =
  | Value
  | Type
  | Module
  | Module_type
  | Class
  | Class_type
  | Constructor
  | Exception
  | Field
  | Method
  | Label

type item = Merlin.outline_item
type t = Merlin.outline

val flatten : t -> item list
val values : t -> item list
val by_name : string -> t -> item option

(** {2 Type access — see {!Merlin}.} *)

val parsed_type : item -> Parsetree.core_type option
val is_function_type : item -> bool
val return_type : item -> Parsetree.core_type option
val count_parameters : item -> matches:(Parsetree.core_type -> bool) -> int
val returns_option : item -> bool
val pp : t Fmt.t
val location : string -> item -> Location.t option
