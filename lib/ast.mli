(** Core AST types for expression analysis *)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type expr_node =
  | Construct of { name : string; args : expr_node list }
      (** Constructor application like Error(...) *)
  | Apply of { func : expr_node; args : expr_node list }
      (** Function application like Fmt.str "..." 42 *)
  | Ident of string  (** Identifier like Fmt.str *)
  | Constant of string  (** Constants like strings or integers *)
  | If_then_else of {
      cond : expr_node;
      then_expr : expr_node;
      else_expr : expr_node option;
    }  (** If-then-else expression *)
  | Match of { expr : expr_node; cases : int }
      (** Match expression with number of cases *)
  | Try of { expr : expr_node; handlers : int }
      (** Try expression with number of exception handlers *)
  | Function of { params : int; body : expr_node }  (** Function definition *)
  | Let of { bindings : (string * expr_node) list; body : expr_node }
      (** Let binding *)
  | Sequence of expr_node list  (** Sequence of expressions *)
  | Other  (** Other expression nodes we don't care about *)

type t = {
  expressions : expr_node list;
  functions : (string * expr_node) list;
      (** Named functions extracted from the typedtree *)
  modules : elt list;  (** Module definitions *)
  types : elt list;  (** Type definitions *)
  exceptions : elt list;  (** Exception definitions *)
  variants : elt list;  (** Variant constructors *)
  identifiers : elt list;
      (** All identifiers for compatibility with existing rules *)
  patterns : elt list;  (** Pattern definitions for compatibility *)
}
(** Parsed AST representation *)

(** Cyclomatic complexity analysis *)
module Complexity : sig
  type info = {
    total : int;
    if_then_else : int;
    match_cases : int;
    try_handlers : int;
    boolean_operators : int;
  }

  val empty : info
  val analyze_expr : expr_node -> info
  val calculate : info -> int
end

(** Generic visitor pattern for expr_node AST traversal *)
class visitor : object
  method visit_expr : expr_node -> unit

  method visit_if_then_else :
    cond:expr_node -> then_expr:expr_node -> else_expr:expr_node option -> unit

  method visit_match : expr:expr_node -> cases:int -> unit
  method visit_try : expr:expr_node -> handlers:int -> unit
  method visit_apply : func:expr_node -> args:expr_node list -> unit

  method visit_let :
    bindings:(string * expr_node) list -> body:expr_node -> unit

  method visit_sequence : expr_node list -> unit
  method visit_construct : name:string -> args:expr_node list -> unit
  method visit_function : params:int -> body:expr_node -> unit
  method visit_ident : string -> unit
  method visit_constant : string -> unit
  method visit_other : unit
end

(** Function finder visitor that searches for a specific function by name *)
class function_finder_visitor : string -> object
  inherit visitor
  method get_result : expr_node option
end

(** Nesting depth analysis *)
module Nesting : sig
  val calculate_depth : expr_node -> int
  (** Calculate maximum nesting depth of an AST expression node *)
end

type function_structure_info = { has_pattern_match : bool; case_count : int }
(** Function structure analysis for E005 - function length detection *)

class function_structure_visitor : unit -> object
  inherit visitor
  method get_info : function_structure_info
end

val calculate_expr_line_count : expr_node -> int
(** Calculate expression line count for function length analysis *)

val of_typedtree_text : string -> t
(** Parse typedtree text dump into AST structure *)

val name_to_string : name -> string
(** Convert a structured name to a string *)
