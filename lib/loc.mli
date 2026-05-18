(** Location conversion helpers shared by typedtree-backed rules. *)

val of_typed :
  filename:string -> Ocaml_parsing.Location.t -> Merlin.Location.t
(** [of_typed ~filename loc] converts a compiler location to a Merlin
    location. *)

val relative_to : root:Fpath.t -> Fpath.t -> Fpath.t
(** [relative_to ~root path] returns [path] relative to [root] when possible. *)

val current_dir_relative : Fpath.t -> Fpath.t
(** [current_dir_relative path] returns [path] relative to the current
    directory when possible. *)

val in_file : Fpath.t -> Location.t
(** [in_file path] creates a location for [path]. *)
