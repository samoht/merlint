(** Shared helpers for [.mli] files that should expose exactly
    [val suite : <expected-type>] and nothing else. *)

val is_compliant : expected:string -> string -> bool
(** [is_compliant ~expected content] is [true] iff [content]'s significant lines
    contain exactly one [val suite : ...] declaration whose normalized suffix
    matches [expected], and no other [val ...] exports. *)

val non_comment_lines : string -> string list
(** [non_comment_lines content] is the content split on newlines with blank
    lines and lines that begin with a comment opener dropped. *)

val suite_line : string list -> string option
(** [suite_line lines] is the first line matching [val suite : ...]. *)

val exports_non_suite_val : string list -> bool
(** [exports_non_suite_val lines] is [true] iff at least one line declares a
    [val ...] that is not [val suite : ...]. *)

val matches_suite_type : expected:string -> string -> bool
(** [matches_suite_type ~expected line] is [true] iff [line] (the
    [val suite : ...] declaration) ends in [expected] after whitespace
    normalisation. *)
