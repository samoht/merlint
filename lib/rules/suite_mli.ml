(** Shared helpers for [.mli] files that should expose exactly one [suite] value
    with the expected test-suite type. *)

open Ocaml_parsing

type expected = Alcotest | Alcobar

let expected_of_string = function
  | "string * unit Alcotest.test_case list" -> Some Alcotest
  | "string * Alcobar.test_case list" -> Some Alcobar
  | _ -> None

let rec type_constr path arg_matches (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt; _ }, args) ->
      Longident.flatten txt = path
      && List.length args = List.length arg_matches
      && List.for_all2 (fun matches arg -> matches arg) arg_matches args
  | Ptyp_alias (ct, _) | Ptyp_poly (_, ct) -> type_constr path arg_matches ct
  | _ -> false

let string_type = type_constr [ "string" ] []
let unit_type = type_constr [ "unit" ] []
let list_type elem = type_constr [ "list" ] [ elem ]

let alcotest_case_list =
  list_type (type_constr [ "Alcotest"; "test_case" ] [ unit_type ])

let alcobar_case_list = list_type (type_constr [ "Alcobar"; "test_case" ] [])

let rec suite_type expected (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_tuple [ (None, name); (None, cases) ] -> (
      string_type name
      &&
      match expected with
      | Alcotest -> alcotest_case_list cases
      | Alcobar -> alcobar_case_list cases)
  | Ptyp_alias (ct, _) | Ptyp_poly (_, ct) -> suite_type expected ct
  | _ -> false

let is_value_suite expected (vd : Parsetree.value_description) =
  vd.pval_name.txt = "suite" && suite_type expected vd.pval_type

let significant_item (item : Parsetree.signature_item) =
  match item.psig_desc with Psig_attribute _ -> None | _ -> Some item

let is_compliant_signature ~expected signature =
  match expected_of_string expected with
  | None -> false
  | Some expected -> (
      match List.filter_map significant_item signature with
      | [ { psig_desc = Psig_value vd; _ } ] -> is_value_suite expected vd
      | _ -> false)

let is_compliant_view ~expected view =
  match File_view.signature view with
  | None -> false
  | Some signature -> is_compliant_signature ~expected signature
