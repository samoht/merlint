(** Simple S-expression parser for dune files. *)

type t = Atom of string | List of t list  (** S-expression type. *)

val parse_string : string -> t list
(** [parse_string content] parses s-expressions from a string. *)
