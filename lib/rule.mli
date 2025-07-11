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

type t = {
  issue : Issue_type.t;  (** The link to the linter's logic *)
  title : string;  (** The official title *)
  category : category;  (** The rule category *)
  hint : string;  (** Explanation of the issue and how to fix it *)
  examples : example list;  (** Optional code examples to illustrate the rule *)
}
(** The canonical definition of a single linting rule *)

val v :
  issue:Issue_type.t ->
  title:string ->
  category:category ->
  ?examples:example list ->
  string ->
  t
(** Create a new rule *)

val get : t list -> Issue_type.t -> t
(** Get a rule by its issue type *)

val by_category : t list -> (category * t list) list
(** Get all rules grouped by category *)

val category_to_string : category -> string
(** Get the string representation of a category *)

val category_description : category -> string
(** Get the description of a category *)

val category_range : category -> string
(** Get the error code range for a category *)
