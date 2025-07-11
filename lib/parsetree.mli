(** Parsetree parser for fallback identifier extraction *)

type name = {
  prefix : string list;
      (** Module path in reverse order, e.g., ["Obj"; "Stdlib"] for Stdlib.Obj
      *)
  base : string;  (** Base identifier, e.g., "magic" *)
}
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

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

val name_to_string : name -> string
(** Convert a structured name to a string *)

val pp : t Fmt.t
(** Pretty print *)
