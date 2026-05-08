(** OCamlmerlin outline output - structured representation.

    This module re-exports types from ocaml-merlin with merlint-specific
    helpers. *)

(** {2 Re-exported types from Merlin} *)

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
(** Outline item. *)

type t = Merlin.outline
(** Outline result. *)

(** {2 Re-exported functions from Merlin} *)

val flatten : t -> item list
(** [flatten outline] returns all items including nested children, flattened. *)

val values : t -> item list
(** [values outline] returns all items with kind [Value]. *)

val by_name : string -> t -> item option
(** [by_name name outline] finds the first item with the given name. *)

val is_function_type : string -> bool
(** [is_function_type signature] returns true if the signature contains [->]. *)

val extract_return_type : string -> string
(** [extract_return_type signature] extracts the rightmost type after [->]. *)

val returns_option : string -> bool
(** [returns_option signature] is [true] when [signature] parses as a function
    type whose final return position is [_ option] (or [Module.option]). Robust
    against arrow chains, parens, labelled args, and nested constructors --
    backed by [Parse.core_type], not string suffix matching. Returns [false] for
    non-function types and on parse failure. *)

val count_parameters : string -> string -> int
(** [count_parameters signature param_type] counts occurrences of [param_type]
    in the [signature]. *)

(** {2 Merlint-specific helpers} *)

val pp : t Fmt.t
(** [pp] is a pretty-printer for outline. *)

val location : string -> item -> Location.t option
(** [location filename item] extracts location for merlint's Location.t. *)
