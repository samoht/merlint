(** OCamlmerlin outline output - thin re-export over [Merlin.outline]. *)

type kind = Merlin.Outline.symbol_kind =
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

type item = Merlin.Outline.item
type t = Merlin.Outline.t

let flatten = Merlin.Outline.flatten
let values = Merlin.Outline.values
let by_name = Merlin.Outline.by_name
let parsed_type = Merlin.Outline.parsed_type
let is_function_type = Merlin.Outline.is_function_type
let return_type = Merlin.Outline.return_type
let count_parameters = Merlin.Outline.count_parameters
let returns_option = Merlin.Outline.returns_option
let pp = Merlin.Outline.pp

let location filename (item : item) =
  let loc = item.location in
  Some
    (Location.v ~file:filename ~start_line:loc.start.line
       ~start_col:loc.start.col ~end_line:loc.end_.line ~end_col:loc.end_.col)
