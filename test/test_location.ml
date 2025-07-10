open Merlint

let test_create () =
  let loc = Location.create ~file:"test.ml" ~line:10 ~col:5 in
  Alcotest.(check string) "file" "test.ml" loc.file;
  Alcotest.(check int) "line" 10 loc.line;
  Alcotest.(check int) "col" 5 loc.col

let test_pp () =
  let loc = Location.create ~file:"foo.ml" ~line:42 ~col:7 in
  let str = Fmt.to_to_string Location.pp loc in
  Alcotest.(check string) "formatted location" "foo.ml:42:7" str

let test_compare () =
  let loc1 = Location.create ~file:"a.ml" ~line:10 ~col:5 in
  let loc2 = Location.create ~file:"a.ml" ~line:10 ~col:5 in
  let loc3 = Location.create ~file:"a.ml" ~line:20 ~col:5 in
  let loc4 = Location.create ~file:"b.ml" ~line:10 ~col:5 in

  Alcotest.(check int) "same location" 0 (Location.compare loc1 loc2);
  Alcotest.(check bool) "loc1 < loc3" true (Location.compare loc1 loc3 < 0);
  Alcotest.(check bool) "loc3 > loc1" true (Location.compare loc3 loc1 > 0);
  Alcotest.(check bool) "a.ml < b.ml" true (Location.compare loc1 loc4 < 0)

let test_create_extended () =
  let ext =
    Location.create_extended ~file:"test.ml" ~start_line:10 ~start_col:5
      ~end_line:15 ~end_col:20
  in
  Alcotest.(check string) "file" "test.ml" ext.file;
  Alcotest.(check int) "start_line" 10 ext.start_line;
  Alcotest.(check int) "start_col" 5 ext.start_col;
  Alcotest.(check int) "end_line" 15 ext.end_line;
  Alcotest.(check int) "end_col" 20 ext.end_col

let test_to_simple () =
  let ext =
    Location.create_extended ~file:"test.ml" ~start_line:10 ~start_col:5
      ~end_line:15 ~end_col:20
  in
  let simple = Location.to_simple ext in
  Alcotest.(check string) "file" "test.ml" simple.file;
  Alcotest.(check int) "line" 10 simple.line;
  Alcotest.(check int) "col" 5 simple.col

let test_range_type () =
  (* Just test that the range type exists and can be created *)
  let range : Location.range =
    { start_line = 1; start_col = 0; end_line = 5; end_col = 10 }
  in
  Alcotest.(check int) "start_line" 1 range.start_line;
  Alcotest.(check int) "end_col" 10 range.end_col

let suite =
  [
    ( "location",
      [
        Alcotest.test_case "create" `Quick test_create;
        Alcotest.test_case "pp" `Quick test_pp;
        Alcotest.test_case "compare" `Quick test_compare;
        Alcotest.test_case "create_extended" `Quick test_create_extended;
        Alcotest.test_case "to_simple" `Quick test_to_simple;
        Alcotest.test_case "range type" `Quick test_range_type;
      ] );
  ]
