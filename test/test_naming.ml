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
  let content =
    {|
module MyModule = struct 
  let x = 1 
end

module AnotherModule = struct
  let y = 2
end

module Already_snake = struct
  let z = 3
end
|}
  in
  let temp_file = create_temp_file content in

  match Merlin.get_typedtree temp_file with
  | Ok typedtree_result ->
      let issues =
        Naming.check ~filename:temp_file ~outline:None typedtree_result
      in
      Sys.remove temp_file;
      let module_issues =
        List.filter
          (fun issue ->
            match issue with Issue.Bad_module_naming _ -> true | _ -> false)
          issues
      in
      (* MyModule and AnotherModule should be flagged, but not Already_snake *)
      Alcotest.(check int)
        "should have 2 module naming issues" 2
        (List.length module_issues);

      List.iter
        (fun issue ->
          match issue with
          | Issue.Bad_module_naming { module_name; expected; _ } ->
              if module_name = "MyModule" then
                Alcotest.(check string)
                  "MyModule should become My_module" "My_module" expected
              else if module_name = "AnotherModule" then
                Alcotest.(check string)
                  "AnotherModule should become Another_module" "Another_module"
                  expected
          | _ -> ())
        module_issues
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

let detect_used_underscore () =
  let source =
    {|
let _unused = 42
let _used = "hello"
let normal = 100

let f () =
  print_endline _used;
  print_int normal
|}
  in
  let temp_file = create_temp_file source in

  match Merlin.get_typedtree temp_file with
  | Error e ->
      Sys.remove temp_file;
      Alcotest.fail e
  | Ok typedtree -> (
      let issues = Naming.check ~filename:temp_file ~outline:None typedtree in
      Sys.remove temp_file;
      (* Should detect _used but not _unused or normal *)
      let underscore_issues =
        List.filter
          (fun issue ->
            match issue with
            | Issue.Used_underscore_binding _ -> true
            | _ -> false)
          issues
      in
      Alcotest.(check int)
        "number of underscore binding issues" 1
        (List.length underscore_issues);

      match List.hd underscore_issues with
      | Issue.Used_underscore_binding { binding_name; _ } ->
          Alcotest.(check string) "binding name" "_used" binding_name
      | _ -> Alcotest.fail "Expected Used_underscore_binding issue")

let no_false_positives_underscore () =
  let source =
    {|
let normal_var = 42
let another_var = "test"

let f () =
  print_int normal_var;
  print_endline another_var
|}
  in
  let temp_file = create_temp_file source in

  match Merlin.get_typedtree temp_file with
  | Error e ->
      Sys.remove temp_file;
      Alcotest.fail e
  | Ok typedtree ->
      let issues = Naming.check ~filename:temp_file ~outline:None typedtree in
      Sys.remove temp_file;
      let underscore_issues =
        List.filter
          (fun issue ->
            match issue with
            | Issue.Used_underscore_binding _ -> true
            | _ -> false)
          issues
      in
      Alcotest.(check int)
        "no underscore binding issues" 0
        (List.length underscore_issues)

let multiple_underscore_usages () =
  let source =
    {|
let _temp = "temporary"

let f () =
  print_endline _temp;
  String.length _temp
|}
  in
  let temp_file = create_temp_file source in

  match Merlin.get_typedtree temp_file with
  | Error e ->
      Sys.remove temp_file;
      Alcotest.fail e
  | Ok typedtree -> (
      let issues = Naming.check ~filename:temp_file ~outline:None typedtree in
      Sys.remove temp_file;
      let underscore_issues =
        List.filter
          (fun issue ->
            match issue with
            | Issue.Used_underscore_binding _ -> true
            | _ -> false)
          issues
      in
      Alcotest.(check int)
        "one issue for multiple usages" 1
        (List.length underscore_issues);

      match List.hd underscore_issues with
      | Issue.Used_underscore_binding { usage_locations; _ } ->
          Alcotest.(check int)
            "number of usage locations" 2
            (List.length usage_locations)
      | _ -> Alcotest.fail "Expected Used_underscore_binding issue")

let suite =
  [
    ( "naming",
      [
        Alcotest.test_case "valid snake_case" `Quick snake_case_valid;
        Alcotest.test_case "camelCase violation" `Quick camel_case_violation;
        Alcotest.test_case "too many underscores" `Quick too_many_underscores;
        Alcotest.test_case "module naming" `Quick module_naming;
        Alcotest.test_case "type naming" `Quick type_naming;
        Alcotest.test_case "detect used underscore binding" `Quick
          detect_used_underscore;
        Alcotest.test_case "no false positives for underscore bindings" `Quick
          no_false_positives_underscore;
        Alcotest.test_case "multiple underscore usages" `Quick
          multiple_underscore_usages;
      ] );
  ]
