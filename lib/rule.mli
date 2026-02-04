(** Linting rule definitions and registry. *)

(** Rule categories. *)
type category =
  | Complexity
  | Security_safety
  | Style_modernization
  | Naming_conventions
  | Documentation
  | Project_structure
  | Testing

type example = {
  is_good : bool;  (** true for good examples, false for bad examples. *)
  code : string;  (** The example code. *)
}
(** A code example with label. *)

type 'a scope =
  | File of (Context.file -> 'a Issue.t list)
  | Project of (Context.project -> 'a Issue.t list)

type t
(** Type for rules. *)

val v :
  code:string ->
  title:string ->
  category:category ->
  hint:string ->
  ?examples:example list ->
  pp:'a Fmt.t ->
  'a scope ->
  t
(** [v ~code ~title ~category ~hint ?examples ~pp scope] creates a new rule. *)

val code : t -> string
(** [code rule] returns rule code. *)

val title : t -> string
(** [title rule] returns rule title. *)

val category : t -> category
(** [category rule] returns rule category. *)

val hint : t -> string
(** [hint rule] returns rule hint. *)

val examples : t -> example list
(** [examples rule] returns rule examples. *)

val category_name : category -> string
(** [category_name category] returns display name. *)

val is_file_scoped : t -> bool
(** [is_file_scoped rule] checks if file scoped. *)

val is_project_scoped : t -> bool
(** [is_project_scoped rule] checks if project scoped. *)

val pp : t Fmt.t
(** [pp] formats a rule for display. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] are the same rule. *)

(** Module for handling rule execution results. *)
module Run : sig
  type result
  (** Result of running a rule, containing the issue and metadata. *)

  val file : t -> Context.file -> result list
  (** [file rule context] runs file rule. *)

  val project : t -> Context.project -> result list
  (** [project rule context] runs project rule. *)

  val code : result -> string
  (** [code result] returns rule code. *)

  val title : result -> string
  (** [title result] returns rule title. *)

  val pp : result Fmt.t
  (** [pp fmt result] pretty prints result. *)

  val location : result -> Location.t option
  (** [location result] returns location. *)

  val compare : result -> result -> int
  (** [compare r1 r2] compares results. *)
end
