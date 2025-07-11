open Merlint

let create_temp_file content =
  let temp_file = Filename.temp_file "test_naming" ".ml" in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;
  temp_file

let snake_case_valid () =
  let content = "let my_function x = x + 1\nlet another_var = 42" in
  let temp_file = create_temp_file content in

  match Merlin.get_typedtree temp_file with
  | Ok typedtree_result ->
      let issues =
        Naming.check ~filename:temp_file ~outline:None typedtree_result
      in
      Sys.remove temp_file;
      Alcotest.(check int) "no naming issues" 0 (List.length issues)
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let camel_case_violation () =
  let content = "let myFunction x = x + 1\nlet anotherVar = 42" in
  let temp_file = create_temp_file content in

  match Merlin.get_typedtree temp_file with
  | Ok typedtree_result ->
      let issues =
        Naming.check ~filename:temp_file ~outline:None typedtree_result
      in
      Sys.remove temp_file;
      Alcotest.(check int) "should have 2 issues" 2 (List.length issues);
      (* Check that issues are for the expected identifiers *)
      List.iter
        (function
          | Issue.Bad_value_naming { value_name; _ } ->
              Alcotest.(check bool)
                "should be camelCase"
                (value_name = "myFunction" || value_name = "anotherVar")
                true
          | Issue.Bad_function_naming { function_name; _ } ->
              Alcotest.(check bool)
                "should be camelCase"
                (function_name = "myFunction" || function_name = "anotherVar")
                true
          | _ -> Alcotest.fail "Expected naming issue")
        issues
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let too_many_underscores () =
  let content = "let very_long_function_name x = x + 1" in
  let temp_file = create_temp_file content in

  match Merlin.get_typedtree temp_file with
  | Ok typedtree_result -> (
      let issues =
        Naming.check ~filename:temp_file ~outline:None typedtree_result
      in
      Sys.remove temp_file;
      Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
      match List.hd issues with
      | Issue.Long_identifier_name { name; underscore_count; _ } ->
          Alcotest.(check string) "name" "very_long_function_name" name;
          Alcotest.(check bool)
            "has many underscores" true (underscore_count > 3)
      | _ -> Alcotest.fail "Expected Long_identifier_name issue")
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let module_naming () =
  let content = "module MyModule = struct let x = 1 end" in
  let temp_file = create_temp_file content in

  match Merlin.get_typedtree temp_file with
  | Ok typedtree_result ->
      let issues =
        Naming.check ~filename:temp_file ~outline:None typedtree_result
      in
      Sys.remove temp_file;
      (* Module names in PascalCase are valid *)
      Alcotest.(check int)
        "no issues for PascalCase module" 0 (List.length issues)
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let type_naming () =
  let content = "type my_type = int\ntype AnotherType = string" in
  let temp_file = create_temp_file content in

  match Merlin.get_typedtree temp_file with
  | Ok typedtree_result ->
      let issues =
        Naming.check ~filename:temp_file ~outline:None typedtree_result
      in
      Sys.remove temp_file;
      (* Both snake_case and PascalCase are valid for types *)
      Alcotest.(check int) "no issues for type names" 0 (List.length issues)
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let suite =
  [
    ( "naming",
      [
        Alcotest.test_case "valid snake_case" `Quick snake_case_valid;
        Alcotest.test_case "camelCase violation" `Quick camel_case_violation;
        Alcotest.test_case "too many underscores" `Quick too_many_underscores;
        Alcotest.test_case "module naming" `Quick module_naming;
        Alcotest.test_case "type naming" `Quick type_naming;
      ] );
  ]
