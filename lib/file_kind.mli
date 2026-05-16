(** Filename-based OCaml file kind. *)

type t = Ml | Mli | Other

val of_filename : string -> t
(** [of_filename f] is [Ml] when [f] ends in [.ml], [Mli] when it ends in
    [.mli], [Other] otherwise. *)

val is_ml : string -> bool
(** [is_ml f] is [of_filename f = Ml]. *)

val is_mli : string -> bool
(** [is_mli f] is [of_filename f = Mli]. *)

val is_ml_or_mli : string -> bool
(** [is_ml_or_mli f] is [of_filename f <> Other]. *)
