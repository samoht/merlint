(** A module whose typedtree-backed rules need a .cmt to run. *)

type t
(** The type for a value. *)

val v : int -> t
(** [v n] is the value carrying [n]. *)
