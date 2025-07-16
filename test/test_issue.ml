open Merlint

(* Define an Alcotest testable for Issue.t *)
let issue_testable = Alcotest.testable Issue.pp Issue.equal

let test_priority () =
  (* Test that each issue has a defined priority *)
  let location =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in
  let issues =
    [
      Issue.complexity_exceeded ~name:"foo" ~loc:location ~complexity:15
        ~threshold:10;
      Issue.function_too_long ~name:"bar" ~loc:location ~length:100
        ~threshold:50;
      Issue.no_obj_magic ~loc:location;
      Issue.missing_mli_doc ~module_name:"Test" ~file:"test.mli";
      Issue.missing_test_file ~module_name:"foo"
        ~expected_test_file:"test_foo.ml" ~loc:location;
      Issue.test_without_library ~test_file:"test_bar.ml"
        ~expected_module:"bar.ml" ~loc:location;
      Issue.test_suite_not_included ~test_module:"Test_baz"
        ~test_runner_file:"test.ml" ~loc:location;
    ]
  in
  List.iter
    (fun issue ->
      let priority = Issue.priority issue in
      Alcotest.(check bool)
        "priority is valid" true
        (priority >= 1 && priority <= 5))
    issues

let test_find_location () =
  let location =
    Location.create ~file:"test.ml" ~start_line:10 ~start_col:5 ~end_line:10
      ~end_col:5
  in

  let test_cases =
    [
      ( Issue.complexity_exceeded ~name:"foo" ~loc:location ~complexity:15
          ~threshold:10,
        Some location );
      ( Issue.function_too_long ~name:"bar" ~loc:location ~length:100
          ~threshold:50,
        Some location );
      (Issue.no_obj_magic ~loc:location, Some location);
      ( Issue.missing_mli_doc ~module_name:"Test" ~file:"test.mli",
        Some
          (Location.create ~file:"test.mli" ~start_line:1 ~start_col:1
             ~end_line:1 ~end_col:1) );
    ]
  in

  List.iter
    (fun (issue, expected_location) ->
      let actual_location = Issue.location issue in
      match (actual_location, expected_location) with
      | Some actual, Some expected ->
          Alcotest.(check string)
            "file" expected.Location.file actual.Location.file;
          Alcotest.(check int)
            "start_line" expected.Location.start_line actual.Location.start_line
      | None, None -> ()
      | _ -> Alcotest.fail "Location mismatch")
    test_cases

let test_kind () =
  let location =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in
  let test_cases =
    [
      ( Issue.complexity_exceeded ~name:"foo" ~loc:location ~complexity:15
          ~threshold:10,
        Issue.Complexity );
      ( Issue.function_too_long ~name:"bar" ~loc:location ~length:100
          ~threshold:50,
        Issue.Function_length );
      (Issue.no_obj_magic ~loc:location, Issue.Obj_magic);
    ]
  in

  List.iter
    (fun (issue, expected_type) ->
      let actual_type = Issue.kind issue in
      Alcotest.(check bool)
        "issue type matches" true
        (actual_type = expected_type))
    test_cases

let test_compare () =
  let location1 =
    Location.create ~file:"test.ml" ~start_line:5 ~start_col:10 ~end_line:5
      ~end_col:10
  in
  let location2 =
    Location.create ~file:"test.ml" ~start_line:10 ~start_col:5 ~end_line:10
      ~end_col:5
  in

  (* Test that issues are sorted by priority, then location *)
  let high_priority = Issue.no_obj_magic ~loc:location1 in
  (* Priority 1 *)
  let medium_priority =
    Issue.function_too_long ~name:"foo" ~loc:location2 ~length:100 ~threshold:50
  in
  (* Priority 2 *)

  Alcotest.(check bool)
    "higher priority issue comes first" true
    (Issue.compare high_priority medium_priority < 0)

let test_equal () =
  let loc1 =
    Location.create ~file:"test.ml" ~start_line:10 ~start_col:0 ~end_line:1
      ~end_col:0
  in
  let loc2 =
    Location.create ~file:"test.ml" ~start_line:20 ~start_col:0 ~end_line:1
      ~end_col:0
  in

  let issue1 = Issue.no_obj_magic ~loc:loc1 in
  let issue2 = Issue.no_obj_magic ~loc:loc1 in
  let issue3 = Issue.no_obj_magic ~loc:loc2 in

  Alcotest.(check issue_testable) "same issues are equal" issue1 issue2;
  Alcotest.(check bool)
    "different issues are not equal" false
    (Issue.equal issue1 issue3)

let test_grouped_hints () =
  let location =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in

  (* Test that find_grouped_hint works for different issue types *)
  let test_cases =
    [
      ( Issue.Complexity,
        [
          Issue.complexity_exceeded ~name:"foo" ~loc:location ~complexity:15
            ~threshold:10;
        ] );
      ( Issue.Missing_mli_file,
        [
          Issue.missing_mli_file ~ml_file:"test.ml" ~expected_mli:"test.mli"
            ~loc:location;
        ] );
    ]
  in

  List.iter
    (fun (issue_type, _issues) ->
      let hint = Rule.get_hint Data.all_rules issue_type in
      Alcotest.(check bool)
        "grouped hint is non-empty" true
        (String.length hint > 0))
    test_cases

let suite =
  [
    ( "issue",
      [
        Alcotest.test_case "issue priority" `Quick test_priority;
        Alcotest.test_case "find_location" `Quick test_find_location;
        Alcotest.test_case "kind" `Quick test_kind;
        Alcotest.test_case "compare" `Quick test_compare;
        Alcotest.test_case "equal" `Quick test_equal;
        Alcotest.test_case "grouped hints" `Quick test_grouped_hints;
      ] );
  ]
