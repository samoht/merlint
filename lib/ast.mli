(** Core AST types for expression analysis *)

(** Dialect for AST parsing *)
type dialect = Parsetree | Typedtree

exception Parse_error of string
(** Parse error exception *)

exception Type_error
(** Type error exception - raised when typedtree contains type errors *)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type expr =
  | Construct of { name : string; args : expr list }
      (** Constructor application like Error(...) *)
  | Apply of { func : expr; args : expr list }
      (** Function application like Fmt.str "..." 42 *)
  | Ident of string  (** Identifier like Fmt.str *)
  | Constant of string  (** Constants like strings or integers *)
  | If_then_else of { cond : expr; then_expr : expr; else_expr : expr option }
      (** If-then-else expression *)
  | Match of { expr : expr; cases : int }
      (** Match expression with number of cases *)
  | Try of { expr : expr; handlers : int }
      (** Try expression with number of exception handlers *)
  | Function of { params : int; body : expr }  (** Function definition *)
  | Let of { bindings : (string * expr) list; body : expr }  (** Let binding *)
  | Sequence of expr list  (** Sequence of expressions *)
  | Other  (** Other expression nodes we don't care about *)

type t = {
  expressions : expr list;
  functions : (string * expr) list;
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
  val analyze_expr : expr -> info
  val calculate : info -> int
end

(** Generic visitor pattern for expr AST traversal *)
class visitor : object
  method visit_expr : expr -> unit

  method visit_if_then_else :
    cond:expr -> then_expr:expr -> else_expr:expr option -> unit

  method visit_match : expr:expr -> cases:int -> unit
  method visit_try : expr:expr -> handlers:int -> unit
  method visit_apply : func:expr -> args:expr list -> unit
  method visit_let : bindings:(string * expr) list -> body:expr -> unit
  method visit_sequence : expr list -> unit
  method visit_construct : name:string -> args:expr list -> unit
  method visit_function : params:int -> body:expr -> unit
  method visit_ident : string -> unit
  method visit_constant : string -> unit
  method visit_other : unit
end

(** Function finder visitor that searches for a specific function by name *)
class function_finder_visitor : string -> object
  inherit visitor
  method get_result : expr option
end

(** Nesting depth analysis *)
module Nesting : sig
  val calculate_depth : expr -> int
  (** Calculate maximum nesting depth of an AST expression node *)
end

type function_structure_info = { has_pattern_match : bool; case_count : int }
(** Function structure analysis for E005 - function length detection *)

class function_structure_visitor : unit -> object
  inherit visitor
  method get_info : function_structure_info
end

val calculate_expr_line_count : expr -> int
(** Calculate expression line count for function length analysis *)

val name_to_string : name -> string
(** Convert a structured name to a string *)
