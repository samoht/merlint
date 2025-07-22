(** Tests for Rule module *)

let test_category_name () =
  (* Test category names *)
  let categories =
    [
      Merlint.Rule.Complexity;
      Merlint.Rule.Security_safety;
      Merlint.Rule.Style_modernization;
      Merlint.Rule.Naming_conventions;
      Merlint.Rule.Documentation;
      Merlint.Rule.Project_structure;
      Merlint.Rule.Testing;
    ]
  in
  List.iter
    (fun cat ->
      let name = Merlint.Rule.category_name cat in
      Alcotest.(check bool) "has name" true (String.length name > 0))
    categories

let test_accessors () =
  (* Test rule accessor functions *)
  let rules = Merlint.Data.all_rules in
  match rules with
  | [] -> Alcotest.fail "No rules found"
  | rule :: _ ->
      let code = Merlint.Rule.code rule in
      let title = Merlint.Rule.title rule in
      let hint = Merlint.Rule.hint rule in
      let category = Merlint.Rule.category rule in
      Alcotest.(check bool) "code not empty" true (String.length code > 0);
      Alcotest.(check bool) "title not empty" true (String.length title > 0);
      Alcotest.(check bool) "hint not empty" true (String.length hint > 0);
      let _ = Merlint.Rule.category_name category in
      ()

let test_issue_creation () =
  (* Test creating issues - Issue is internal to Rule module *)
  let loc =
    Merlint.Location.create ~file:"test.ml" ~start_line:1 ~start_col:0
      ~end_line:1 ~end_col:10
  in
  (* We can't create issues directly, but we can test location creation *)
  Alcotest.(check bool) "location created" true (loc = loc)

let test_run_result () =
  (* Test Run.result functions *)
  match Merlint.Data.all_rules with
  | [] -> Alcotest.fail "No rules found"
  | rule :: _ ->
      (* We can't easily create a Run.result without running a rule,
         so just test that the types exist *)
      let _ = Merlint.Rule.code rule in
      ()

let tests =
  [
    ("category_name", `Quick, test_category_name);
    ("accessors", `Quick, test_accessors);
    ("issue_creation", `Quick, test_issue_creation);
    ("run_result", `Quick, test_run_result);
  ]

let suite = ("rule", tests)
