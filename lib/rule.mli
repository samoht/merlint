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

type scope =
  | File  (** Rule runs on each file independently *)
  | Project  (** Rule runs once for the entire project *)

type t = {
  issue : Issue_type.t;  (** The link to the linter's logic *)
  title : string;  (** The official title *)
  category : category;  (** The rule category *)
  scope : scope;  (** Whether rule is per-file or project-wide *)
  hint : string;  (** Explanation of the issue and how to fix it *)
  examples : example list;  (** Optional code examples to illustrate the rule *)
}
(** The canonical definition of a single linting rule *)

val v :
  issue:Issue_type.t ->
  title:string ->
  category:category ->
  ?scope:scope ->
  ?examples:example list ->
  string ->
  t
(** Create a new rule, defaults to File scope *)

val get : t list -> Issue_type.t -> t
(** Get a rule by its issue type *)

val category_name : category -> string
(** Get the display name for a category *)

type code_example = {
  is_good : bool;
  description : string option;
  code : string;
}
(** Types for hints *)

type hint = { text : string; examples : code_example list option }

val get_hint_title : t list -> Issue_type.t -> string
(** Get a short title for a specific issue type *)

val get_hint : t list -> Issue_type.t -> string
(** Get a hint for a specific issue type *)

val get_structured_hint : t list -> Issue_type.t -> hint
(** Get a structured hint with text and optional code examples *)
