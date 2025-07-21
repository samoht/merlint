(** Wrapper for OCaml Merlin commands. *)

type t = {
  outline : (Outline.t, string) result;
  dump : (Dump.t, string) result;
}
(** Result of merlin analyses for a single file. *)

val analyze_file : string -> t
(** [analyze_file filename] analyzes a file with merlin commands. *)
