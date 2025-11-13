(** Dump module - extracts names and identifiers from AST text dumps.

    This module parses the textual representation of OCaml AST dumps (from
    Merlin) to extract names of functions, modules, types, etc. It does NOT
    analyze control flow or expression structure - use the Ast module for that.
*)

type name = { prefix : string list; base : string }
(** Structured name type. *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items. *)

type t = {
  modules : elt list;  (** Module names. *)
  types : elt list;  (** Type declarations. *)
  exceptions : elt list;  (** Exception declarations. *)
  variants : elt list;  (** Variant constructors. *)
  identifiers : elt list;  (** Value identifiers (usage). *)
  patterns : elt list;  (** Pattern variables. *)
  values : elt list;  (** Value bindings (definitions). *)
}

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] are structurally equal. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. *)

val pp : t Fmt.t
(** [pp] is a pretty-printer for the dump data. *)

exception Parse_error of string
(** Parse error exception. *)

exception Type_error
(** Type error exception - raised when typedtree contains type errors. *)

exception Wrong_ast_type

val name_to_string : name -> string
(** [name_to_string name] converts a structured name to a string. *)

val parsetree : string -> t
(** [parsetree text] parses parsetree text dump into AST structure. *)

val typedtree : string -> t
(** [typedtree text] parses typedtree text dump into AST structure. *)

(** {2 Utility functions for working with dump data.} *)

val iter_identifiers_with_location : t -> (elt -> Location.t -> unit) -> unit
(** [iter_identifiers_with_location dump_data f] applies f to each identifier
    with location. *)

val location : elt -> Location.t option
(** [location elt] extracts location from element. *)

val check_module_usage :
  full_path:string -> elt list -> string -> (loc:Location.t -> 'a) -> 'a list
(** [check_module_usage ~full_path identifiers module_name issue_constructor]
    checks for specific module usage. Automatically fixes location paths to use
    full_path instead of basename. *)

val check_function_usage :
  full_path:string ->
  elt list ->
  string ->
  string ->
  (loc:Location.t -> 'a) ->
  'a list
(** [check_function_usage ~full_path identifiers module_name function_name
     issue_constructor] checks for specific function usage. Automatically fixes
    location paths to use full_path instead of basename. *)

val check_function_call_pattern :
  string -> string -> string -> (string * int * bool -> 'a) -> string -> 'a list
(** [check_function_call_pattern content function_name arg_pattern
     issue_constructor filename] checks for function calls with specific
    argument patterns. For example, to find 'fail (Fmt.str' patterns, use:
    check_function_call_pattern content "fail" "Fmt.str" issue_constructor
    filename. *)

val check_elements :
  full_path:string ->
  elt list ->
  (string -> 'a option) ->
  (string -> Location.t -> 'a -> 'b) ->
  'b list
(** [check_elements ~full_path elements check_fn create_issue_fn] generic
    element checking. Automatically fixes location paths to use full_path
    instead of basename. *)

val fix_all_paths : full_path:string -> t -> t
(** [fix_all_paths ~full_path dump] fixes all locations in dump structure to use
    full_path instead of basename. This is automatically called by Context.dump,
    so rules don't need to call it directly. *)
