(** Tests for File module *)

let test_process_lines_with_location () =
  (* Test processing lines with location *)
  let content = "line1\nline2\nline3" in
  let results = 
    Merlint.File.process_lines_with_location "test.ml" content
      (fun line_num line _loc -> 
        if line_num = 2 then Some line else None)
  in
  Alcotest.(check int) "found one line" 1 (List.length results);
  match results with
  | [line] -> Alcotest.(check string) "correct line" "line2" line
  | _ -> Alcotest.fail "Expected exactly one result"

let test_empty_file () =
  (* Test processing empty file *)
  let results = 
    Merlint.File.process_lines_with_location "test.ml" ""
      (fun _ _ _ -> Some "found")
  in
  Alcotest.(check int) "no results" 0 (List.length results)

let tests =
  [
    ("process_lines_with_location", `Quick, test_process_lines_with_location);
    ("empty_file", `Quick, test_empty_file);
  ]

let suite = ("file", tests)