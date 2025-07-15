(** Simplified Typedtree parser for identifier extraction *)

open Ast

type expr_node =
  | Construct of { name : string; args : expr_node list }
      (** Constructor application like Error(...) *)
  | Apply of { func : expr_node; args : expr_node list }
      (** Function application like Fmt.str "..." 42 *)
  | Ident of string  (** Identifier like Fmt.str *)
  | Constant of string  (** Constants like strings or integers *)
  | Other  (** Other expression nodes we don't care about *)

type t = {
  identifiers : elt list;
      (** Texp_ident: references to existing values/functions in expressions *)
  patterns : elt list;  (** Tpat_var: new value bindings being defined *)
  modules : elt list;  (** Tstr_module: module definitions *)
  types : elt list;  (** Tstr_type: type definitions *)
  exceptions : elt list;  (** Tstr_exception: exception definitions *)
  variants : elt list;  (** Tpat_construct: variant constructors *)
  expressions : (expr_node * Location.t option) list;
      (** Expression trees for pattern detection *)
}
(** Simplified representation focusing on identifiers *)

val of_text : string -> t
(** Parse typedtree output from raw text *)

val of_json : Yojson.Safe.t -> t
(** Parse typedtree output from JSON *)

val of_json_with_filename : Yojson.Safe.t -> string -> t
(** Parse typedtree output from JSON with filename correction *)

val pp : t Fmt.t
(** Pretty print *)
