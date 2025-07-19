(** OCamlmerlin outline output - structured representation *)

(** Outline item kinds we care about *)
type kind =
  | Value
  | Type
  | Module
  | Class
  | Exception
  | Constructor
  | Field
  | Method
  | Other of string

type position = { line : int; col : int }
(** Position in file *)

type range = { start : position; end_ : position }
(** Range in file *)

type item = {
  name : string;
  kind : kind;
  type_sig : string option; (* Type signature for values *)
  range : range option;
}
(** Outline item *)

type t = item list
(** Outline result *)

val empty : unit -> t
(** Create an empty outline *)

val of_json : Yojson.Safe.t -> t
(** Parse outline from JSON *)

val get_values : t -> item list
(** Get all values from outline *)

val find_by_name : string -> t -> item option
(** Find item by name *)

val pp : t Fmt.t
(** Pretty print outline *)

val location : string -> item -> Location.t option
(** [location filename item] extracts location from outline item *)

(** {2 Type signature analysis} *)

val is_function_type : string -> bool
(** [is_function_type signature] checks if signature represents a function type
*)

val extract_return_type : string -> string
(** [extract_return_type signature] extracts return type from function signature
*)

val count_parameters : string -> string -> int
(** [count_parameters signature param_type] counts occurrences of param_type in
    signature *)
