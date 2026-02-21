type t

(** [parse str] parses a string into type [t]. *)
val parse : string -> t

(** [x @> y] composes two values with right-hand precedence. *)
val ( @> ) : t -> t -> t

(** [x <@ y] composes two values with left-hand precedence. *)
val ( <@ ) : t -> t -> t

(** [border_current] sets border color to match the text color. Example:
    {[
      div ~tw:[ text ~shade:600 red; border `Default; border_current ]
      (* Border will be red-600, same as the text *)
    ]} *)
val border_current : t

(** [default] is the default configuration. *)
val default : t

(** [create ~name t] creates a new value. *)
val create : ?debug:bool -> name:string -> t -> t

(** [make ()] is a new value with defaults. *)
val make : ?foo:int -> ?bar:string -> unit -> t