(** Core AST types for control flow and expression analysis

    This module defines types and functions for analyzing the control flow
    structure of OCaml programs (if-then-else, match, try, etc.) to calculate
    metrics like cyclomatic complexity and nesting depth. For name extraction,
    see the Dump module. *)

(** Control flow expression types *)

type expr =
  | If_then_else of { cond : expr; then_expr : expr; else_expr : expr option }
      (** If-then-else expression *)
  | Match of { expr : expr; cases : int }
      (** Match expression with number of cases *)
  | Try of { expr : expr; handlers : int }
      (** Try expression with number of exception handlers *)
  | Function of { params : int; body : expr }  (** Function definition *)
  | Let of { bindings : (string * expr) list; body : expr }  (** Let binding *)
  | Sequence of expr list  (** Sequence of expressions *)
  | Other  (** Catch-all for expressions we don't need to analyze *)

type t = {
  functions : (string * expr) list;
      (** Top-level functions with their control flow structure. This is used
          for complexity and nesting analysis. *)
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
  val analyze : expr -> info
  val calculate : info -> int
end

(** Nesting depth analysis *)
module Nesting : sig
  val depth : expr -> int
  (** Calculate maximum nesting depth of an AST expression node *)
end

(** Extract functions with their control flow from a source file using ppxlib.
    Returns a list of (function_name, control_flow_ast) pairs. *)
val extract_functions : string -> (string * expr) list
