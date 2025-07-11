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
      Issue.Complexity_exceeded
        { name = "foo"; location; complexity = 15; threshold = 10 };
      Issue.Function_too_long
        { name = "bar"; location; length = 100; threshold = 50 };
      Issue.No_obj_magic { location };
      Issue.Missing_mli_doc { module_name = "Test"; file = "test.mli" };
      Issue.Missing_test_file
        { module_name = "foo"; expected_test_file = "test_foo.ml"; location };
      Issue.Test_without_library
        { test_file = "test_bar.ml"; expected_module = "bar.ml"; location };
      Issue.Test_suite_not_included
        { test_module = "Test_baz"; test_runner_file = "test.ml"; location };
    ]
  in
  List.iter
    (fun issue ->
      let priority = Issue.priority issue in
      Alcotest.(check bool)
        "priority is valid" true
        (priority >= 1 && priority <= 5))
    issues

let test_to_string () =
  let location =
    Location.create ~file:"test.ml" ~start_line:10 ~start_col:5 ~end_line:10
      ~end_col:5
  in

  let test_cases =
    [
      ( Issue.Complexity_exceeded
          { name = "foo"; location; complexity = 15; threshold = 10 },
        "test.ml:10:5: Function 'foo' has complexity 15 (threshold: 10)" );
      ( Issue.Function_too_long
          { name = "bar"; location; length = 100; threshold = 50 },
        "test.ml:10:5: Function 'bar' is 100 lines long (threshold: 50)" );
      (Issue.No_obj_magic { location }, "test.ml:10:5: Avoid using Obj.magic");
      ( Issue.Missing_mli_doc { module_name = "Test"; file = "test.mli" },
        "test.mli: Missing module documentation" );
    ]
  in

  List.iter
    (fun (issue, expected) ->
      let actual = Issue.format issue in
      Alcotest.(check string) "issue string" expected actual)
    test_cases

let test_get_type () =
  let location =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in
  let test_cases =
    [
      ( Issue.Complexity_exceeded
          { name = "foo"; location; complexity = 15; threshold = 10 },
        Issue_type.Complexity );
      ( Issue.Function_too_long
          { name = "bar"; location; length = 100; threshold = 50 },
        Issue_type.Function_length );
      (Issue.No_obj_magic { location }, Issue_type.Obj_magic);
    ]
  in

  List.iter
    (fun (issue, expected_type) ->
      let actual_type = Issue.get_type issue in
      Alcotest.(check bool)
        "issue type matches" true
        (actual_type = expected_type))
    test_cases

let test_pp () =
  let location =
    Location.create ~file:"test.ml" ~start_line:5 ~start_col:10 ~end_line:5
      ~end_col:10
  in
  let issue = Issue.No_obj_magic { location } in

  let output = Fmt.to_to_string Issue.pp issue in
  Alcotest.(check bool)
    "pp output contains location" true
    (Re.execp (Re.compile (Re.str "test.ml:5:10")) output)

let test_equal () =
  let loc1 =
    Location.create ~file:"test.ml" ~start_line:10 ~start_col:0 ~end_line:1
      ~end_col:0
  in
  let loc2 =
    Location.create ~file:"test.ml" ~start_line:20 ~start_col:0 ~end_line:1
      ~end_col:0
  in

  let issue1 = Issue.No_obj_magic { location = loc1 } in
  let issue2 = Issue.No_obj_magic { location = loc1 } in
  let issue3 = Issue.No_obj_magic { location = loc2 } in

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
      ( Issue_type.Complexity,
        [
          Issue.Complexity_exceeded
            { name = "foo"; location; complexity = 15; threshold = 10 };
        ] );
      ( Issue_type.Missing_mli_file,
        [
          Issue.Missing_mli_file
            { ml_file = "test.ml"; expected_mli = "test.mli"; location };
        ] );
    ]
  in

  List.iter
    (fun (issue_type, issues) ->
      let hint = Issue.get_grouped_hint issue_type issues in
      Alcotest.(check bool)
        "grouped hint is non-empty" true
        (String.length hint > 0))
    test_cases

let suite =
  [
    ( "issue",
      [
        Alcotest.test_case "issue priority" `Quick test_priority;
        Alcotest.test_case "to_string" `Quick test_to_string;
        Alcotest.test_case "get_type" `Quick test_get_type;
        Alcotest.test_case "pp" `Quick test_pp;
        Alcotest.test_case "equal" `Quick test_equal;
        Alcotest.test_case "grouped hints" `Quick test_grouped_hints;
      ] );
  ]
