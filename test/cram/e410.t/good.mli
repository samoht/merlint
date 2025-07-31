type t

(** [parse str] parses a string into type [t]. *)
val parse : string -> t

(** [x @> y] composes two values with right-hand precedence. *)
val ( @> ) : t -> t -> t

(** [x <@ y] composes two values with left-hand precedence. *)
val ( <@ ) : t -> t -> t

(** Sets border color to match the text color. Example:
    {[
      div ~tw:[ text ~shade:600 red; border `Default; border_current ]
      (* Border will be red-600, same as the text *)
    ]} *)
val border_current : t