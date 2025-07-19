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

exception Parse_error of string
(** Parse error exception *)

exception Type_error
(** Type error exception - raised when typedtree contains type errors *)

exception Wrong_ast_type

val name_to_string : name -> string
(** Convert a structured name to a string *)

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
