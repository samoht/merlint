(** Linting rule definitions and registry - New self-contained design *)

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

(** Check scope - whether the rule operates on files or the whole project *)
type check_scope =
  | File_check of (Context.file -> Issue.t list)
  | Project_check of (Context.project -> Issue.t list)

type t = {
  id : Issue.rule_id;  (** Rule identifier *)
  title : string;  (** The official title *)
  category : category;  (** The rule category *)
  hint : string;  (** Explanation of the issue and how to fix it *)
  examples : example list;  (** Optional code examples to illustrate the rule *)
  
  (* The check function, now part of the rule itself *)
  check : check_scope;
  
  (* The formatter, also part of the rule - formats the issue data *)
  format_issue : Issue.data -> string;
}
(** The canonical definition of a single linting rule - now self-contained *)

val v :
  id:Issue.rule_id ->
  title:string ->
  category:category ->
  hint:string ->
  ?examples:example list ->
  check:check_scope ->
  format_issue:(Issue.data -> string) ->
  unit ->
  t
(** Create a new rule *)

val get_by_id : t list -> Issue.rule_id -> t option
(** Get a rule by its ID *)

val category_name : category -> string
(** Get the display name for a category *)