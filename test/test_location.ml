open Merlint

let test_create () =
  let loc =
    Location.create ~file:"test.ml" ~start_line:10 ~start_col:5 ~end_line:10
      ~end_col:5
  in
  Alcotest.(check string) "file" "test.ml" loc.file;
  Alcotest.(check int) "line" 10 loc.start_line;
  Alcotest.(check int) "col" 5 loc.start_col

let test_pp () =
  let loc =
    Location.create ~file:"foo.ml" ~start_line:42 ~start_col:7 ~end_line:42
      ~end_col:7
  in
  let str = Fmt.to_to_string Location.pp loc in
  Alcotest.(check string) "formatted location" "foo.ml:42:7" str

let test_compare () =
  let loc1 =
    Location.create ~file:"a.ml" ~start_line:10 ~start_col:5 ~end_line:10
      ~end_col:5
  in
  let loc2 =
    Location.create ~file:"a.ml" ~start_line:10 ~start_col:5 ~end_line:10
      ~end_col:5
  in
  let loc3 =
    Location.create ~file:"a.ml" ~start_line:20 ~start_col:5 ~end_line:10
      ~end_col:5
  in
  let loc4 =
    Location.create ~file:"b.ml" ~start_line:10 ~start_col:5 ~end_line:10
      ~end_col:5
  in

  Alcotest.(check int) "same location" 0 (Location.compare loc1 loc2);
  Alcotest.(check bool) "loc1 < loc3" true (Location.compare loc1 loc3 < 0);
  Alcotest.(check bool) "loc3 > loc1" true (Location.compare loc3 loc1 > 0);
  Alcotest.(check bool) "a.ml < b.ml" true (Location.compare loc1 loc4 < 0)

let test_create_extended () =
  let ext =
    Location.create ~file:"test.ml" ~start_line:10 ~start_col:5 ~end_line:15
      ~end_col:20
  in
  Alcotest.(check string) "file" "test.ml" ext.file;
  Alcotest.(check int) "start_line" 10 ext.start_line;
  Alcotest.(check int) "start_col" 5 ext.start_col;
  Alcotest.(check int) "end_line" 15 ext.end_line;
  Alcotest.(check int) "end_col" 20 ext.end_col

let suite =
  [
    ( "location",
      [
        Alcotest.test_case "create" `Quick test_create;
        Alcotest.test_case "pp" `Quick test_pp;
        Alcotest.test_case "compare" `Quick test_compare;
        Alcotest.test_case "create_extended" `Quick test_create_extended;
      ] );
  ]
