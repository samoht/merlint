let module_name_matches ~expected actual =
  actual = expected || String.ends_with ~suffix:("__" ^ expected) actual

let references_suite view module_name =
  match File_view.resolved_identifiers view with
  | None -> false
  | Some refs ->
      List.exists
        (fun ref_ ->
          let name = File_view.Reference.name ref_ in
          File_view.Name.base name = "suite"
          &&
          match List.rev (File_view.Name.prefix name) with
          | actual :: _ -> module_name_matches ~expected:module_name actual
          | [] -> false)
        refs

let references_suite_with_prefix view ~prefix =
  match File_view.resolved_identifiers view with
  | None -> false
  | Some refs ->
      List.exists
        (fun ref_ ->
          let name = File_view.Reference.name ref_ in
          File_view.Name.base name = "suite"
          &&
          match List.rev (File_view.Name.prefix name) with
          | module_name :: _ -> String.starts_with ~prefix module_name
          | [] -> false)
        refs

let calls_test_case view =
  File_view.calls_path view [ "Alcobar"; "test_case" ]
  || File_view.calls_path view [ "Alcotest"; "test_case" ]
