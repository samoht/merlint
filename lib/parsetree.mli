(** Parsetree parser for fallback identifier extraction *)

open Ast

type t = {
  identifiers : elt list;
      (** Pexp_ident: references to existing values/functions in expressions *)
  patterns : elt list;  (** Ppat_var: new value bindings being defined *)
  modules : elt list;  (** Pstr_module: module definitions *)
  types : elt list;  (** Pstr_type: type definitions *)
  exceptions : elt list;  (** Pstr_exception: exception definitions *)
  variants : elt list;  (** Ppat_construct: variant constructors *)
}
(** Simplified representation focusing on identifiers *)

val of_text : string -> t
(** Parse parsetree output from raw text *)

val of_json : Yojson.Safe.t -> t
(** Parse parsetree output from JSON *)

val of_json_with_filename : Yojson.Safe.t -> string -> t
(** Parse parsetree output from JSON with filename correction *)

val pp : t Fmt.t
(** Pretty print *)
