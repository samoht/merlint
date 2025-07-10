(** Cyclomatic complexity analysis

    This module provides functions to analyze the cyclomatic complexity,
    function length, and nesting depth of OCaml code using Merlin's AST. *)

type config = {
  max_complexity : int;
  max_function_length : int;
  max_nesting : int;
}

val default_config : config

val analyze_browse_value : config -> Browse.t -> Issue.t list
(** [analyze_browse_value config browse] analyzes browse output for complexity
    issues *)
