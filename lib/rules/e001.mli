(** E001: High Cyclomatic Complexity

    This rule detects functions with high cyclomatic complexity. Cyclomatic
    complexity is a measure of the number of linearly independent paths through
    a function's source code. *)

type config = { max_complexity : int }

val check : Context.t -> Issue.t list
(** [check config browse_data] analyzes the browse data to find functions with
    cyclomatic complexity exceeding the configured threshold. The configuration
    record contains max_complexity field (default: 10). Returns a list of issues
    for functions that violate the rule. *)
