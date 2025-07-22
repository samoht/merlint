(** Wrapper for OCaml Merlin commands. *)

type t = {
  outline : (Outline.t, string) result;
  dump : (Dump.t, string) result;
}
(** Result of merlin analyses for a single file. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] have equal results. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. *)

val pp : t Fmt.t
(** [pp fmt t] pretty-prints the merlin result. *)

val analyze_file : string -> t
(** [analyze_file filename] analyzes a file with merlin commands. *)
