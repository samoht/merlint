(** E001: High Cyclomatic Complexity

    This rule detects functions with high cyclomatic complexity. Cyclomatic
    complexity is a measure of the number of linearly independent paths through
    a function's source code. *)

val rule : Rule.t
(** The E001 rule definition *)
