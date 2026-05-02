(** OCamlmerlin outline output - structured representation.

    This module re-exports types from ocaml-merlin with merlint-specific
    helpers. *)

(* {2 Re-exported types from Merlin} *)

type kind = Merlin.symbol_kind =
  | Value
  | Type
  | Module
  | Module_type
  | Class
  | Class_type
  | Constructor
  | Exception
  | Field
  | Method
  | Label

type item = Merlin.outline_item
type t = Merlin.outline

(* {2 Re-exported functions from Merlin} *)

let flatten = Merlin.flatten_outline
let values = Merlin.values
let by_name = Merlin.by_name
let is_function_type = Merlin.is_function_type
let extract_return_type = Merlin.extract_return_type
let count_parameters = Merlin.count_parameters

(* {2 Merlint-specific helpers} *)

let pp = Merlin.pp_outline

let location filename (item : item) =
  let loc = item.location in
  Some
    (Location.v ~file:filename ~start_line:loc.start.line
       ~start_col:loc.start.col ~end_line:loc.end_.line ~end_col:loc.end_.col)
