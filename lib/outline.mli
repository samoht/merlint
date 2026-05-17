(** Declaration outline helpers shared by File_view and rules. *)

type kind = Merlin.Outline.symbol_kind =
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

type item = Merlin.Outline.item
type t = Merlin.Outline.t

val flatten : t -> item list
(** [flatten t] returns every item in [t] including nested children. *)

val values : t -> item list
(** [values t] is the subset of [flatten t] with [kind = Value]. *)

val by_name : string -> t -> item option
(** [by_name name t] is the first item in [flatten t] whose [name] matches. *)

(** {2 Type access — see {!Merlin}.} *)

val parsed_type : item -> Parsetree.core_type option
(** [parsed_type item] is the structured form of [item]'s type signature, or
    [None] when merlin reported no type or the string failed to parse. *)

val is_function_type : item -> bool
(** [is_function_type item] is [true] when [parsed_type item] is an arrow type.
*)

val return_type : item -> Parsetree.core_type option
(** [return_type item] walks the arrow chain of [parsed_type item] and returns
    the final non-arrow target. *)

val count_parameters : item -> matches:(Parsetree.core_type -> bool) -> int
(** [count_parameters item ~matches] counts unlabeled positional arguments of
    [item]'s type whose domain satisfies [matches]. *)

val returns_option : item -> bool
(** [returns_option item] is [true] when {!return_type} is a [_ option]. *)

val pp : t Fmt.t
(** [pp] is a debug formatter listing the items by name. *)

val location : string -> item -> Location.t option
(** [location filename item] lifts [item.location] into merlint's [Location.t].
*)
