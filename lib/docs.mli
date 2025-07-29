(** Documentation style analysis following Daniel Bünzli's conventions.

    This module enforces consistent documentation style:
    - Type documentation ends with a period.
    - Function documentation uses [[name args] description.] format.
    - No redundant phrases like "This function...". *)

type style_issue =
  | Missing_period
  | Bad_function_format
  | Bad_operator_format
  | Redundant_phrase of string
  | Regular_comment_instead_of_doc  (** Documentation style issues. *)

val check_function_doc : name:string -> doc:string -> style_issue list
(** [check_function_doc ~name ~doc] checks function documentation style.
    Functions should use the format: [[function_name args] description.]. *)

val check_type_doc : doc:string -> style_issue list
(** [check_type_doc ~doc] checks type documentation style. Types should have
    brief descriptions ending with a period. *)

val check_value_doc : name:string -> doc:string -> style_issue list
(** [check_value_doc ~name ~doc] checks value documentation style. Values should
    have simple descriptions ending with a period. *)

val pp_style_issue : style_issue Fmt.t
(** [pp_style_issue] pretty-prints a style issue. *)

val equal_style_issue : style_issue -> style_issue -> bool
(** [equal_style_issue a b] returns true if [a] and [b] are equal. *)

type doc_comment = {
  value_name : string;
  signature : string;
  doc : string;
  doc_line : int;
  val_line : int;
}
(** Documentation comment associated with a value. *)

val is_function_signature : string -> bool
(** [is_function_signature signature] returns true if signature indicates a
    function. *)

val extract_doc_comments : string -> doc_comment list
(** [extract_doc_comments content] extracts documentation comments from OCaml
    source. *)
