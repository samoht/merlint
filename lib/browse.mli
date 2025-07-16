(** OCamlmerlin browse output - for finding value bindings and pattern info *)

type pattern_info = { has_pattern_match : bool; case_count : int }
(** Pattern info for a value binding *)

type value_binding = {
  ast_elt : Ast.elt;
  pattern_info : pattern_info;
  is_function : bool;  (** True if the binding has function parameters *)
  is_simple_list : bool;
      (** True if the binding is just a data structure (list or record) *)
}
(** Value binding information *)

type t = { value_bindings : value_binding list }
(** Browse analysis result *)

val empty : unit -> t
(** Create an empty browse result *)

val of_json : Yojson.Safe.t -> t
(** Parse browse output *)

val get_value_bindings : t -> value_binding list
(** Get all value bindings *)
