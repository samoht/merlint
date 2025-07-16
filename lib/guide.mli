(** Style guide document structure *)

(** A type to represent the hierarchical structure of the style guide *)
type element =
  | Title of string
  | Section of string * element list
  | Paragraph of string
  | Code of string  (** Code examples *)
  | Rule of Issue.kind  (** Reference to a linting rule *)

val content : element list
(** The complete definition of the style guide's structure *)
