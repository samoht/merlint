(** Shared location types and utilities *)

type t = { file : string; line : int; col : int }
(** Location in a file *)

val create : file:string -> line:int -> col:int -> t
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

type extended = {
  file : string;
  start_line : int;
  start_col : int;
  end_line : int;
  end_col : int;
}
(** Extended location with range *)

val to_simple : extended -> t
(** Convert extended location to simple location (using start position) *)

val create_extended :
  file:string ->
  start_line:int ->
  start_col:int ->
  end_line:int ->
  end_col:int ->
  extended
(** Create extended location *)
