type t

(** [parse str] converts a string to type [t].
    @raise Invalid_argument if [str] is malformed. *)
val parse : string -> t