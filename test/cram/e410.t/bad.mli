type t

(** [@> x y] incorrect prefix notation for operator. *)
val ( @> ) : t -> t -> t

(** Missing period at the end *)
val ( <@ ) : t -> t -> t

(** The default configuration. *)
val default : t

(** [create t] is missing args. *)
val create : ?debug:bool -> name:string -> t -> t

(** [trim t extra] has too many args. *)
val trim : t -> t

(** [combine "a b" x y] counts a literal as one arg but still over-counts. *)
val combine : string -> string

(** [describe t] is a summary of {b t} *)
val describe : t -> string
