(** Helper functions for creating code examples. *)

val good : string -> Rule.example
(** [good code] creates a good example. *)

val bad : string -> Rule.example
(** [bad code] creates a bad example. *)
