(** Parser module - handles all AST text parsing functionality *)

open Ast

type token = { indent : int; content : string; loc : Location.t option }
(** Phase 1: Token type for lexing *)

(** Phase 2: Generic tree structure for indentation-based parsing *)
type 'a tree = Node of 'a * 'a tree list

val normalize_node_type : dialect -> string -> string
(** Normalize node type based on dialect *)

val text : dialect -> string -> t
(** Parse AST text with specific dialect *)

val parsetree : string -> t
(** Parse parsetree text dump into AST structure *)

val typedtree : string -> t
(** Parse typedtree text dump into AST structure *)
