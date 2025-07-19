(** Dump module - extracts names and identifiers from AST text dumps

    This module parses the textual representation of OCaml AST dumps (from
    Merlin) to extract names of functions, modules, types, etc. It does NOT
    analyze control flow or expression structure - use the Ast module for that.
*)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type t = {
  modules : elt list;  (** Module names *)
  types : elt list;  (** Type declarations *)
  exceptions : elt list;  (** Exception declarations *)
  variants : elt list;  (** Variant constructors *)
  identifiers : elt list;  (** Value identifiers (usage) *)
  patterns : elt list;  (** Pattern variables *)
  values : elt list;  (** Value bindings (definitions) *)
}
(** Extracted names and identifiers from the AST dump *)

(** What kind of AST dump we're parsing *)
type what = Parsetree | Typedtree

exception Parse_error of string
(** Parse error exception *)

exception Type_error
(** Type error exception - raised when typedtree contains type errors *)

exception Wrong_ast_type
(** Wrong AST type exception - raised when parsing Typedtree but found Parsetree
    nodes *)

(** Token kinds *)
type token_kind =
  | Word of string
  | Location of
      Location.t (* Parsed location like (file.ml[1,0+0]..file.ml[1,0+31]) *)
  | Module (* Tstr_module / Pstr_module *)
  | Type (* Tstr_type / Pstr_type *)
  | TypeDeclaration (* type_declaration *)
  | Value (* Tstr_value / Pstr_value *)
  | Exception (* Tstr_exception / Pstr_exception *)
  | Variant (* Ttype_variant / Ptype_variant *)
  | Ident (* Texp_ident / Pexp_ident *)
  | Construct (* Texp_construct / Pexp_construct *)
  | Pattern (* Tpat_var / Ppat_var *)
  | Attribute (* Tstr_attribute / Pstr_attribute *)
  | LParen
  | RParen
  | LBracket
  | RBracket

type token = { kind : token_kind; loc : Location.t option }
(** Token representation *)

val name_to_string : name -> string
(** Convert a structured name to a string *)

val pp_token : Format.formatter -> token -> unit
(** Pretty print a token for debugging *)

val normalize_node_type : what -> string -> string
(** Normalize node type based on what *)

val lex_text : what -> string -> token list
(** Lex AST text into tokens - for debugging *)

val text : what -> string -> t
(** Parse AST text with specific what *)

val parsetree : string -> t
(** Parse parsetree text dump into AST structure *)

val typedtree : string -> t
(** Parse typedtree text dump into AST structure *)

(** {2 Utility functions for working with dump data} *)

val iter_identifiers_with_location : t -> (elt -> Location.t -> unit) -> unit
(** [iter_identifiers_with_location dump_data f] applies [f] to each identifier
    that has a location *)

val location : elt -> Location.t option
(** [location elt] extracts location from element *)

val check_module_usage : elt list -> string -> (loc:Location.t -> 'a) -> 'a list
(** [check_module_usage identifiers module_name issue_constructor] checks for
    specific module usage *)

val check_function_usage :
  elt list -> string -> string -> (loc:Location.t -> 'a) -> 'a list
(** [check_function_usage identifiers module_name function_name
     issue_constructor] checks for specific function usage *)

val check_elements :
  elt list ->
  (string -> 'a option) ->
  (string -> Location.t -> 'a -> 'b) ->
  'b list
(** [check_elements elements check_fn create_issue_fn] generic element checking
    pattern *)
