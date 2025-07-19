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
