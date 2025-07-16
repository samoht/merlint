(** E005: Function Too Long

    This rule detects functions that exceed the maximum allowed length.
    Functions should be kept concise for better readability and maintainability.
*)

type config = { max_function_length : int }

val check : Context.t -> Issue.t list
(** [check config browse_data] analyzes the browse data to find functions that
    exceed the configured length threshold. Returns a list of issues for
    functions that violate the rule. *)
