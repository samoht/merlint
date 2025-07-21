(** Shared location types and utilities. *)

type t = {
  file : string;
  start_line : int;
  start_col : int;
  end_line : int;
  end_col : int;
}
(** Location with range in a file. *)

val create :
  file:string ->
  start_line:int ->
  start_col:int ->
  end_line:int ->
  end_col:int ->
  t
(** [create ~file ~start_line ~start_col ~end_line ~end_col] creates a location.
*)

val pp : t Fmt.t
(** [pp formatter location] pretty prints location. *)

val compare : t -> t -> int
(** [compare a b] compares two locations. *)
