(** Canonical tag vocabulary for E915.

    Loads slugs from [categories.toml] at the project root. A slug is any
    top-level or nested table header in the file (e.g., [codec], [codec.text]).
*)

val load : string -> string list
(** [load project_root] returns the list of declared slugs from
    [categories.toml] at [project_root], or the empty list if the file does not
    exist or cannot be read. *)
