(** Shared location types and utilities *)

type t = {
  file : string;
  start_line : int;
  start_col : int;
  end_line : int;
  end_col : int;
}
(** Location with range in a file *)

val create :
  file:string ->
  start_line:int ->
  start_col:int ->
  end_line:int ->
  end_col:int ->
  t
(** Create a location *)

val pp : t Fmt.t
(** Pretty print a location *)

val compare : t -> t -> int
(** Compare two locations *)

type range = {
  start_line : int;
  start_col : int;
  end_line : int;
  end_col : int;
}
(** Range in a file *)
