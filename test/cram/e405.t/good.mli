type t

(** [parse str] converts a string to type [t].
    @raise Invalid_argument if [str] is malformed. *)
val parse : string -> t

val format : t -> string
(** [format t] converts a value of type [t] to a string representation. *)

(** [process n] processes an integer value. *)
val process : int -> int