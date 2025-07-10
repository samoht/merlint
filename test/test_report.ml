open Merlint

let test_create_report () =
  let issues =
    [
      Issue.Bad_value_naming
        {
          value_name = "badName";
          expected = "bad_name";
          location = Location.create ~file:"test.ml" ~line:1 ~col:4;
        };
    ]
  in

  let report =
    Report.create ~rule_name:"Test Rule" ~passed:false ~issues ~file_count:1
  in

  Alcotest.(check string) "rule name" "Test Rule" report.rule_name;
  Alcotest.(check bool) "passed" false report.passed;
  Alcotest.(check int) "issue count" 1 (List.length report.issues);
  Alcotest.(check int) "file count" 1 report.file_count

let test_print_status () =
  let true_status = Report.print_status true in
  let false_status = Report.print_status false in

  (* Just check that they produce different output *)
  Alcotest.(check bool) "statuses differ" true (true_status <> false_status)

let test_get_all_issues () =
  let issue1 =
    Issue.Bad_value_naming
      {
        value_name = "bad1";
        expected = "bad_1";
        location = Location.create ~file:"file1.ml" ~line:1 ~col:0;
      }
  in
  let issue2 =
    Issue.Function_too_long
      {
        name = "long_func";
        length = 100;
        threshold = 50;
        location = Location.create ~file:"file2.ml" ~line:10 ~col:0;
      }
  in

  let categories =
    [
      ( "Category 1",
        [
          Report.create ~rule_name:"Rule 1" ~passed:false ~issues:[ issue1 ]
            ~file_count:1;
        ] );
      ( "Category 2",
        [
          Report.create ~rule_name:"Rule 2" ~passed:false ~issues:[ issue2 ]
            ~file_count:1;
        ] );
    ]
  in

  let all_reports = List.flatten (List.map snd categories) in
  let all_issues = Report.get_all_issues all_reports in
  Alcotest.(check int) "should have 2 issues" 2 (List.length all_issues);

  (* Check that both issues are present *)
  let has_issue1 = List.exists (Issue.equal issue1) all_issues in
  let has_issue2 = List.exists (Issue.equal issue2) all_issues in
  Alcotest.(check bool) "has issue1" true has_issue1;
  Alcotest.(check bool) "has issue2" true has_issue2

let test_empty_report () =
  let report =
    Report.create ~rule_name:"Empty Rule" ~passed:true ~issues:[] ~file_count:10
  in

  Alcotest.(check bool) "passed" true report.passed;
  Alcotest.(check int) "no issues" 0 (List.length report.issues)

let test_pp_summary () =
  let report =
    Report.create ~rule_name:"Test Rule" ~passed:false
      ~issues:
        [
          Issue.Bad_value_naming
            {
              value_name = "test";
              expected = "test";
              location = Location.create ~file:"test.ml" ~line:1 ~col:0;
            };
        ]
      ~file_count:5
  in

  let output = Fmt.str "%a" Report.pp_summary [ report ] in
  (* Just verify it produces some output and includes the rule name *)
  Alcotest.(check bool) "output not empty" true (String.length output > 0);
  Alcotest.(check bool)
    "contains rule name" true
    (Re.execp (Re.compile (Re.str "Test Rule")) output)

let suite =
  [
    ( "report",
      [
        Alcotest.test_case "create report" `Quick test_create_report;
        Alcotest.test_case "print status" `Quick test_print_status;
        Alcotest.test_case "get all issues" `Quick test_get_all_issues;
        Alcotest.test_case "empty report" `Quick test_empty_report;
        Alcotest.test_case "pp summary" `Quick test_pp_summary;
      ] );
  ]
