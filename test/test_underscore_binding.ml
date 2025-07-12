open Alcotest
open Merlint

let create_temp_file content =
  let temp_file = Filename.temp_file "test_underscore" ".ml" in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;
  temp_file

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
      fail e
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
      check int "number of underscore binding issues" 1
        (List.length underscore_issues);

      match List.hd underscore_issues with
      | Issue.Used_underscore_binding { binding_name; _ } ->
          check string "binding name" "_used" binding_name
      | _ -> fail "Expected Used_underscore_binding issue")

let no_false_positives () =
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
      fail e
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
      check int "no underscore binding issues" 0 (List.length underscore_issues)

let multiple_usages () =
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
      fail e
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
      check int "one issue for multiple usages" 1
        (List.length underscore_issues);

      match List.hd underscore_issues with
      | Issue.Used_underscore_binding { usage_locations; _ } ->
          check int "number of usage locations" 2 (List.length usage_locations)
      | _ -> fail "Expected Used_underscore_binding issue")

let tests =
  [
    test_case "detect used underscore binding" `Quick detect_used_underscore;
    test_case "no false positives for normal bindings" `Quick no_false_positives;
    test_case "multiple usages of same binding" `Quick multiple_usages;
  ]

let suite = ("Underscore_binding", tests)
