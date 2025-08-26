(** OCamlmerlin outline output - structured representation. *)

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
(** Position in file. *)

type range = { start : position; end_ : position }
(** Range in file. *)

type item = {
  name : string;
  kind : kind;
  type_sig : string option; (* Type signature for values *)
  range : range option;
}
(** Outline item. *)

type t = item list
(** Outline result. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] are equal. Uses polymorphic
    equality. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. Uses
    polymorphic comparison. *)

val empty : unit -> t
(** [empty] creates empty outline. *)

val of_json : Yojson.Safe.t -> t
(** [of_json json] parses outline. *)

val values : t -> item list
(** [values outline] returns all values. *)

val by_name : string -> t -> item option
(** [by_name name outline] finds item. *)

val pp : t Fmt.t
(** [pp] is a pretty-printer for outline. *)

val location : string -> item -> Location.t option
(** [location filename item] extracts location. *)

(** {2 Type signature analysis} *)

val is_function_type : string -> bool
(** [is_function_type signature] checks if function type. *)

val extract_return_type : string -> string
(** [extract_return_type signature] extracts return type. *)

val count_parameters : string -> string -> int
(** [count_parameters signature param_type] counts parameters. *)
