(** Linting rule definitions and registry *)

(** Rule categories *)
type category =
  | Complexity
  | Security_safety
  | Style_modernization
  | Naming_conventions
  | Documentation
  | Project_structure
  | Testing

type example = {
  is_good : bool;  (** true for good examples, false for bad examples *)
  code : string;  (** The example code *)
}
(** A code example with label *)

val good : string -> example
(** Create a good example *)

val bad : string -> example
(** Create a bad example *)

type 'a scope =
  | File of (Context.file -> 'a Issue.t list)
  | Project of (Context.project -> 'a Issue.t list)

type t
(** Type for rules *)

val v :
  code:string ->
  title:string ->
  category:category ->
  hint:string ->
  ?examples:example list ->
  pp:'a Fmt.t ->
  'a scope ->
  t

val code : t -> string
(** Get the code of a rule *)

val title : t -> string
(** Get the title of a rule *)

val category : t -> category
(** Get the category of a rule *)

val hint : t -> string
(** Get the hint of a rule *)

val examples : t -> example list
(** Get the examples of a rule *)

val category_name : category -> string
(** Get the display name for a category *)

val is_file_scoped : t -> bool
(** Check if a rule operates on individual files *)

val is_project_scoped : t -> bool
(** Check if a rule operates on the entire project *)

(** Module for handling rule execution results *)
module Run : sig
  type result
  (** Result of running a rule, containing the issue and metadata *)

  val file : t -> Context.file -> result list
  (** Run a file-scoped rule on a file context *)

  val project : t -> Context.project -> result list
  (** Run a project-scoped rule on a project context *)

  val code : result -> string
  (** Get the rule code from a result *)

  val title : result -> string
  (** Get the rule title from a result *)

  val pp : result Fmt.t
  (** Pretty-print a result *)

  val location : result -> Location.t option
  (** Get the location from a result *)

  val compare : result -> result -> int
  (** Compare results for sorting *)
end
