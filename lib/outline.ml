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

(* Walk through a chain of [t1 -> t2 -> ... -> tn] arrows and return [tn]. *)
let rec final_arrow_target ct =
  match ct.Parsetree.ptyp_desc with
  | Ptyp_arrow (_, _, rhs) -> final_arrow_target rhs
  | _ -> ct

let returns_option signature =
  (* Catch only the parse-failure exceptions [Parse.core_type] can raise on
     ill-formed type strings. Anything else (e.g. an internal compiler-libs
     [assert false]) propagates so we don't mask real bugs. *)
  match
    try Some (Parse.core_type (Lexing.from_string signature))
    with Syntaxerr.Error _ | Lexer.Error _ -> None
  with
  | None -> false
  | Some core_type -> (
      let final = final_arrow_target core_type in
      match final.ptyp_desc with
      | Ptyp_constr ({ txt; _ }, [ _ ]) -> (
          match txt with
          | Longident.Lident "option" -> true
          | Ldot (_, { txt = "option"; _ }) -> true
          | _ -> false)
      | _ -> false)

(* {2 Merlint-specific helpers} *)

let pp = Merlin.pp_outline

let location filename (item : item) =
  let loc = item.location in
  Some
    (Location.v ~file:filename ~start_line:loc.start.line
       ~start_col:loc.start.col ~end_line:loc.end_.line ~end_col:loc.end_.col)
