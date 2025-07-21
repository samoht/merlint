open Merlint

let test_creation () =
  let location =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in

  (* Test creating issues with and without location *)
  let issue_with_loc = Issue.v ~loc:location "test payload" in
  let issue_without_loc = Issue.v "test payload" in

  (* Check location retrieval *)
  (match Issue.location issue_with_loc with
  | Some loc ->
      Alcotest.(check string) "location file" "test.ml" loc.Location.file;
      Alcotest.(check int) "location start line" 1 loc.Location.start_line
  | None -> Alcotest.fail "Expected location");

  match Issue.location issue_without_loc with
  | None -> ()
  | Some _ -> Alcotest.fail "Expected no location"

let test_compare () =
  let location1 =
    Location.create ~file:"test.ml" ~start_line:5 ~start_col:10 ~end_line:5
      ~end_col:10
  in
  let location2 =
    Location.create ~file:"test.ml" ~start_line:10 ~start_col:5 ~end_line:10
      ~end_col:5
  in

  (* Test that issues are sorted by location *)
  let issue1 = Issue.v ~loc:location1 "test1" in
  let issue2 = Issue.v ~loc:location2 "test2" in

  Alcotest.(check bool)
    "issue1 comes before issue2" true
    (Issue.compare issue1 issue2 < 0)

let test_pp () =
  let location =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in

  let issue = Issue.v ~loc:location "test message" in
  let pp = Issue.pp Fmt.string in
  let str = Fmt.to_to_string pp issue in

  (* Just check that it produces some output *)
  Alcotest.(check bool) "pp produces output" true (String.length str > 0)

let suite =
  [
    ( "issue",
      [
        Alcotest.test_case "issue creation" `Quick test_creation;
        Alcotest.test_case "compare" `Quick test_compare;
        Alcotest.test_case "pp" `Quick test_pp;
      ] );
  ]
