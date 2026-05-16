(** Core AST types for control flow and expression analysis.

    This module defines types and functions for analyzing the control flow
    structure of OCaml programs (if-then-else, match, try, etc.) to calculate
    metrics like cyclomatic complexity and nesting depth. For name extraction,
    see the Dump module. *)

open Ocaml_parsing

(** Control flow expression types. *)

type expr =
  | If_then_else of { cond : expr; then_expr : expr; else_expr : expr option }
      (** If-then-else expression. *)
  | Match of { expr : expr; cases : expr list }
      (** Match expression with the body of each case. *)
  | Try of { expr : expr; handlers : expr list }
      (** Try expression with the body of each exception handler. *)
  | Function of { params : int; body : expr }  (** Function definition. *)
  | Let of { bindings : (string * expr) list; body : expr }  (** Let binding. *)
  | Sequence of expr list  (** Sequence of expressions. *)
  | List  (** List literals and array literals. *)
  | Record of { fields : int }  (** Record literals with field count. *)
  | Other  (** Catch-all for expressions we don't need to analyze. *)

type t = {
  functions : (string * expr) list;
      (** Top-level functions with their control flow structure. Used for
          complexity and nesting analysis. *)
}
(** Parsed AST representation. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] are structurally equal. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. *)

val pp : t Fmt.t
(** [pp] is a pretty-printer for the AST representation. *)

(** Cyclomatic complexity analysis. *)
module Complexity : sig
  type info = {
    total : int;
    if_then_else : int;
    match_cases : int;
    try_handlers : int;
    boolean_operators : int;
  }

  val empty : info
  (** [empty] is the zero-valued complexity info. *)

  val analyze : expr -> info
  (** [analyze expr] returns complexity information for an expression. *)

  val calculate : info -> int
  (** [calculate info] returns the total cyclomatic complexity from info. *)

  val equal : info -> info -> bool
  (** [equal a b] returns true if [a] and [b] are equal. *)

  val pp : info Fmt.t
  (** [pp fmt info] pretty-prints complexity info. *)
end

(** Nesting depth analysis. *)
module Nesting : sig
  val depth : expr -> int
  (** [depth expr] calculates the maximum nesting depth of an AST expression
      node. *)
end

val trailing_record_fields : expr -> int
(** [trailing_record_fields expr] returns the number of fields in a trailing
    record literal at the tail position of [expr]. Returns 0 if the expression
    does not end with a record. Used by E005 to exempt trailing record
    construction from function length counts. *)

val extract_functions : string -> (string * expr) list
(** [extract_functions source] extracts functions with their control flow from a
    source file. Returns a list of (function_name, control_flow_ast) pairs. *)

val functions_of_structure : Parsetree.structure -> (string * expr) list
(** [functions_of_structure s] extracts the top-level functions with their
    control flow from an already-parsed [Parsetree.structure]. *)

val parse_structure : filename:string -> string -> Parsetree.structure option
(** [parse_structure ~filename content] parses [content] into a Parsetree
    structure. Returns [None] for [.mli] files and on parse error. *)

val merlint_of_loc : filename:string -> Location.t -> Merlin.Location.t
(** [merlint_of_loc ~filename loc] converts a compiler-libs location into a
    merlint location. *)

val iter_apply :
  Parsetree.structure ->
  (Parsetree.expression ->
  Longident.t ->
  (Asttypes.arg_label * Parsetree.expression) list ->
  unit) ->
  unit
(** [iter_apply structure f] calls [f expr fn args] for every
    [Pexp_apply (Pexp_ident fn, args)] node in [structure]. The [expr] carries
    the surrounding expression's location. *)

val iter_expressions :
  Parsetree.structure -> (Parsetree.expression -> unit) -> unit
(** [iter_expressions structure f] calls [f expr] for every expression node in
    [structure]. *)

val is_apply_of : string list -> Parsetree.expression -> bool
(** [is_apply_of path expr] is [true] when [expr] is
    [Pexp_apply (Pexp_ident path, _)]. *)

val lident_last_eq : string -> Longident.t -> bool
(** [lident_last_eq name lid] is [true] when [lid]'s rightmost segment equals
    [name]. Matches both unqualified ([invalid_arg]) and module-qualified
    ([Stdlib.invalid_arg]) usage. *)
