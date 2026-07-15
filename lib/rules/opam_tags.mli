(** Helpers shared by rules that read the [tags:] field of an opam file. *)

val read_opt : string -> string list option
(** [read_opt path] is the list of tags from [path]'s [tags:] field, accepting
    both the list form ([tags: ["a" "b"]]) and the single-string form
    ([tags: "a"]). Returns [None] when the field is absent or the file can't be
    opened. *)

val read : string -> string list
(** [read path] is like {!read_opt} but folds absent fields and unreadable files
    into the empty list. *)

val is_io_free : string -> bool
(** [is_io_free t] is [true] when [t] is the top-level [protocol] tag, the bare
    [codec] tag, or a [codec.*] sub-tag. *)

val has_io_free : string list -> bool
(** [has_io_free tags] is [List.exists is_io_free tags]. *)
