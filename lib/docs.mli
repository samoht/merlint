(** Documentation style analysis following Daniel Bünzli's conventions.

    This module enforces consistent documentation style:
    - Type documentation ends with a period.
    - Function documentation starts with the documented name when it uses
      [[name args] description.] format. If it mentions arguments, it mentions
      at least all mandatory arguments and no impossible arguments.
    - No redundant phrases like "This function...". *)

(** Documentation style issues. *)
type style_issue =
  | Missing_period
  | Bad_function_format
  | Bad_value_format
  | Bad_operator_format
  | Wrong_arg_count of { min : int; max : int; found : int }
  | Redundant_phrase of string

val check_function_doc :
  name:string -> signature:string -> doc:string -> style_issue list
(** [check_function_doc ~name ~signature ~doc] checks function documentation
    style. If using [name args] format, verifies that [name] names the
    documented function. If the doc pattern mentions arguments, it must mention
    at least all mandatory arguments and at most all arguments. Optional
    arguments may be omitted. *)

val check_type_doc : doc:string -> style_issue list
(** [check_type_doc ~doc] checks type documentation style. Types should have
    brief descriptions ending with a period. *)

val check_value_doc : name:string -> doc:string -> style_issue list
(** [check_value_doc ~name ~doc] checks value documentation style. Values should
    use the format: [[value_name] description.]. *)

val pp_style_issue : style_issue Fmt.t
(** [pp_style_issue] pretty-prints a style issue. *)

val style_issue_message : style_issue -> string
(** [style_issue_message issue] is the report text for [issue]. *)

val equal_style_issue : style_issue -> style_issue -> bool
(** [equal_style_issue a b] returns true if [a] and [b] are equal. *)
