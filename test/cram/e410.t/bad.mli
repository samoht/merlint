type t

(* this function parses strings *)
val parse : string -> t

(** [@> x y] incorrect prefix notation for operator. *)
val ( @> ) : t -> t -> t

(** Missing period at the end *)
val ( <@ ) : t -> t -> t