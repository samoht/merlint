(** Hints for fixing different types of issues *)

type code_example = {
  is_good : bool;
  description : string option;
  code : string;
}
(** Code example type *)

type hint = { text : string; examples : code_example list option }
(** Hint with optional code examples *)

val get_hint_title : Issue_type.t -> string
(** Get a short title for a specific issue type *)

val get_hint : Issue_type.t -> string
(** Get a hint for a specific issue type *)

val get_structured_hint : Issue_type.t -> hint
(** Get a structured hint with text and optional code examples *)
