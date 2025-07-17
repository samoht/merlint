open Merlint

let test_create_report () =
  (* Create some dummy Rule.Run.result values for testing *)
  let issues = [] in
  (* Empty for now since we can't easily create Rule.Run.result in tests *)

  let report =
    Report.create ~rule_name:"Test Rule" ~passed:false ~issues ~file_count:1
  in

  Alcotest.(check string) "rule name" "Test Rule" report.rule_name;
  Alcotest.(check bool) "passed" false report.passed;
  Alcotest.(check int) "issue count" 0 (List.length report.issues);
  Alcotest.(check int) "file count" 1 report.file_count

let test_print_status () =
  let true_status = Report.print_status true in
  let false_status = Report.print_status false in

  (* Just check that they produce different output *)
  Alcotest.(check bool) "statuses differ" true (true_status <> false_status)

let test_get_all_issues () =
  (* Create multiple reports *)
  let report1 =
    Report.create ~rule_name:"Rule 1" ~passed:true ~issues:[] ~file_count:1
  in
  let report2 =
    Report.create ~rule_name:"Rule 2" ~passed:true ~issues:[] ~file_count:2
  in

  let all_issues = Report.get_all_issues [ report1; report2 ] in
  Alcotest.(check int) "total issues" 0 (List.length all_issues)

let test_print_color () =
  let green_text = Report.print_color true "PASS" in
  let red_text = Report.print_color false "FAIL" in

  (* Check that they return different colored versions *)
  Alcotest.(check bool) "colored outputs differ" true (green_text <> red_text);
  Alcotest.(check bool)
    "green contains PASS" true
    (String.contains (String.uppercase_ascii green_text) 'P');
  Alcotest.(check bool)
    "red contains FAIL" true
    (String.contains (String.uppercase_ascii red_text) 'F')

let suite =
  [
    ( "report",
      [
        Alcotest.test_case "create report" `Quick test_create_report;
        Alcotest.test_case "print status" `Quick test_print_status;
        Alcotest.test_case "get all issues" `Quick test_get_all_issues;
        Alcotest.test_case "print color" `Quick test_print_color;
      ] );
  ]
