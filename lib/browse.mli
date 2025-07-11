(** OCamlmerlin browse output - for finding value bindings and pattern info *)

type location = Location.t
(** Location information *)

type pattern_info = { has_pattern_match : bool; case_count : int }
(** Pattern info for a value binding *)

type value_binding = {
  name : string option;
  location : location option;
  pattern_info : pattern_info;
}
(** Value binding information *)

type t = { value_bindings : value_binding list }
(** Browse analysis result *)

val of_json : Yojson.Safe.t -> t
(** Parse browse output *)

val get_value_bindings : t -> value_binding list
(** Get all value bindings *)
