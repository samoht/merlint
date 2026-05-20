(** Filename-based OCaml file kind. *)

type t = Ml | Mli | Other

val pp : t Fmt.t
(** [pp] formats a file kind. *)

val of_filename : string -> t
(** [of_filename f] is {!constructor-Ml} when [f] ends in [.ml],
    {!constructor-Mli} when it ends in [.mli], {!constructor-Other} otherwise.
*)

val is_ml : string -> bool
(** [is_ml f] is [of_filename f = Ml]. *)

val is_mli : string -> bool
(** [is_mli f] is [of_filename f = Mli]. *)

val is_ml_or_mli : string -> bool
(** [is_ml_or_mli f] is [of_filename f <> Other]. *)
