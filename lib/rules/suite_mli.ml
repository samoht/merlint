(** Shared helpers for [.mli] files that should expose exactly one [suite] value
    with the expected test-suite type. *)

type expected = Alcotest | Alcobar

let expected_of_string = function
  | "string * unit Alcotest.test_case list" -> Some Alcotest
  | "string * Alcobar.test_case list" -> Some Alcobar
  | _ -> None

let string_type = File_view.Type_view.is_string
let unit_type = File_view.Type_view.is_unit
let list_type elem = File_view.Type_view.is_list ~elem

let alcotest_case_list =
  list_type (fun typ ->
      match File_view.Type_view.constr typ with
      | Some (name, [ arg ]) ->
          File_view.Name.equals_path name [ "Alcotest"; "test_case" ]
          && unit_type arg
      | _ -> false)

let alcobar_case_list =
  list_type (fun typ ->
      match File_view.Type_view.constr typ with
      | Some (name, []) ->
          File_view.Name.equals_path name [ "Alcobar"; "test_case" ]
      | _ -> false)

let suite_type expected ct =
  match File_view.Type_view.tuple ct with
  | Some [ name; cases ] -> (
      string_type name
      &&
      match expected with
      | Alcotest -> alcotest_case_list cases
      | Alcobar -> alcobar_case_list cases)
  | _ -> false

let is_value_suite expected item =
  File_view.Item.name item = "suite"
  &&
  match File_view.Item.type_sig item with
  | Some typ -> suite_type expected typ
  | None -> false

let is_compliant_items ~expected items =
  match expected_of_string expected with
  | None -> false
  | Some expected -> (
      match items with
      | [ item ] when File_view.Item.kind item = File_view.Item.Value ->
          is_value_suite expected item
      | _ -> false)

let is_compliant_view ~expected view =
  is_compliant_items ~expected (File_view.items view)
