(** The doc comments of one source file, keyed by the declaration each attaches
    to.

    A doc comment is a property of the source: the compiler's lexer turns
    [(** ... *)] into a docstring and its parser hangs it on the declaration
    beside it. Reading them here, from a parse of the file on disk, is what
    makes them available for a file nobody has compiled -- an artefact has them
    only because the compiler wrote it, and merlin's own lexer does not emit
    them at all. *)

type comment = {
  text : string;  (** The comment's body, trimmed. *)
  loc : Location.t;  (** Where the comment itself is, for reporting on it. *)
}
(** The type for one doc comment. *)

type t
(** The type for a file's doc comments. *)

val v : filename:string -> content:string -> t
(** [v ~filename ~content] is the doc comments [content] attaches to its
    declarations. Source that does not parse has none: a file mid-edit yields an
    empty {!type-t} rather than an error, since a rule that reads doc comments
    has nothing to say about a file whose declarations cannot be read. *)

val find : t -> start:int -> stop:int -> comment option
(** [find t ~start ~stop] is the doc comment attached to the declaration
    spanning byte offsets [start] to [stop], and [None] when that declaration
    carries none. The offsets are those of the declaration, not of the comment.
*)
