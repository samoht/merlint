(** Typedtree-derived control-flow metrics for top-level value bindings. *)

type complexity = {
  total : int;
  if_then_else : int;
  matches : int;
  try_handlers : int;
  boolean_operators : int;
  loops : int;
}
(** Control-flow complexity counters for a typed expression. *)

type value = {
  name : string;
  loc : Ocaml_parsing.Location.t;
  is_function : bool;
  complexity : int;
  nesting : int;
  match_cases : int;
  trailing_record_fields : int;
  pure_data : bool;
}
(** Top-level value metrics consumed by complexity and size rules. *)

val complexity : Ocaml_typing.Typedtree.expression -> int
(** [complexity expr] returns the cyclomatic complexity of [expr]. *)

val nesting : Ocaml_typing.Typedtree.expression -> int
(** [nesting expr] returns the maximum control-flow nesting depth of [expr]. *)

val of_structure : Ocaml_typing.Typedtree.structure -> value list
(** [of_structure structure] extracts metrics for top-level value bindings. *)
