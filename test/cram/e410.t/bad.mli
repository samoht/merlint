type t

(** [@> x y] incorrect prefix notation for operator. *)
val ( @> ) : t -> t -> t

(** Missing period at the end *)
val ( <@ ) : t -> t -> t

(** The default configuration. *)
val default : t

(** [create t] is missing args. *)
val create : ?debug:bool -> name:string -> t -> t
