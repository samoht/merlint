(** OCamlmerlin outline output - thin re-export over [Merlin.outline]. *)

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

let flatten = Merlin.flatten_outline
let values = Merlin.values
let by_name = Merlin.by_name
let parsed_type = Merlin.parsed_type
let is_function_type = Merlin.is_function_type
let return_type = Merlin.return_type
let count_parameters = Merlin.count_parameters
let returns_option = Merlin.returns_option
let pp = Merlin.pp_outline

let location filename (item : item) =
  let loc = item.location in
  Some
    (Location.v ~file:filename ~start_line:loc.start.line
       ~start_col:loc.start.col ~end_line:loc.end_.line ~end_col:loc.end_.col)
