type t

(** [parse str] parses a string into type [t]. *)
val parse : string -> t

(** [x @> y] composes two values with right-hand precedence. *)
val ( @> ) : t -> t -> t

(** [x <@ y] composes two values with left-hand precedence. *)
val ( <@ ) : t -> t -> t