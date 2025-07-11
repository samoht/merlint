(** Simplified Typedtree parser for identifier extraction *)

type name = {
  prefix : string list;
      (** Module path, e.g., ["Stdlib"; "Obj"] for Stdlib.Obj.magic *)
  base : string;  (** Base identifier, e.g., "magic" *)
}
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type t = {
  identifiers : elt list;
      (** Texp_ident: references to existing values/functions in expressions *)
  patterns : elt list;  (** Tpat_var: new value bindings being defined *)
  modules : elt list;  (** Tstr_module: module definitions *)
  types : elt list;  (** Tstr_type: type definitions *)
  exceptions : elt list;  (** Tstr_exception: exception definitions *)
  variants : elt list;  (** Tpat_construct: variant constructors *)
}
(** Simplified representation focusing on identifiers *)

val of_text : string -> t
(** Parse typedtree output from raw text *)

val of_json : Yojson.Safe.t -> t
(** Parse typedtree output from JSON *)

val of_json_with_filename : Yojson.Safe.t -> string -> t
(** Parse typedtree output from JSON with filename correction *)

val name_to_string : name -> string
(** Convert a structured name to a string *)

val pp : t Fmt.t
(** Pretty print *)
