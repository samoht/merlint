(** Common AST types and utilities shared between parsetree and typedtree *)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type dialect =
  | Parsetree
  | Typedtree
      (** AST dialect to distinguish between parsetree and typedtree formats *)

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
      (** References to existing values/functions in expressions *)
  patterns : elt list;  (** New value bindings being defined *)
  modules : elt list;  (** Module definitions *)
  types : elt list;  (** Type definitions *)
  exceptions : elt list;  (** Exception definitions *)
  variants : elt list;  (** Variant constructors *)
  expressions : (expr_node * Location.t option) list;
      (** Expression trees for pattern detection (typedtree only) *)
}
(** Unified AST representation for both parsetree and typedtree *)

val extract_quoted_string : string -> string option
(** Extract quoted string from line *)

val parse_name : ?handle_bang_suffix:bool -> string -> name
(** Parse a structured name from a string like "Str.regexp" or
    "Stdlib!.Obj.magic"
    @param handle_bang_suffix
      if true, removes '!' suffix from module names (for typedtree) *)

val name_to_string : name -> string
(** Convert a structured name to a string *)

val of_json : dialect:dialect -> filename:string -> Yojson.Safe.t -> t
(** Parse AST output from JSON with the specified dialect and filename *)

val pp : t Fmt.t
(** Pretty print the AST *)
