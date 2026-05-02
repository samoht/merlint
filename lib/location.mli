(** Re-export of Merlin's location types for source positions. *)

include module type of Merlin.Location

val in_file : string -> t
(** [in_file file] is a location pointing at the very start of [file] (line 1,
    column 0). Use it when an issue is about a whole file rather than a specific
    line — it lets the engine's per-file exclusion logic treat the issue as
    belonging to that file. *)
