(** Tests for {!Merlint.File_kind}. *)

let test_of_filename () =
  let check name expected got =
    Alcotest.(check bool)
      name true
      (match (expected, got) with
      | Merlint.File_kind.Ml, Merlint.File_kind.Ml -> true
      | Mli, Mli -> true
      | Other, Other -> true
      | _ -> false)
  in
  check "ml" Ml (Merlint.File_kind.of_filename "foo.ml");
  check "mli" Mli (Merlint.File_kind.of_filename "foo.mli");
  check "qualified ml" Ml (Merlint.File_kind.of_filename "lib/dir/foo.ml");
  check "qualified mli" Mli (Merlint.File_kind.of_filename "lib/dir/foo.mli");
  check "uppercase keeps Other" Other (Merlint.File_kind.of_filename "foo.ML");
  check "dotml prefix without dot" Other
    (Merlint.File_kind.of_filename "foo_ml");
  check "no extension" Other (Merlint.File_kind.of_filename "foo");
  check "empty" Other (Merlint.File_kind.of_filename "");
  check ".ml alone" Ml (Merlint.File_kind.of_filename ".ml");
  check ".mli alone" Mli (Merlint.File_kind.of_filename ".mli");
  check "trailing dot" Other (Merlint.File_kind.of_filename "foo.")

let test_is_ml () =
  Alcotest.(check bool) "ml is ml" true (Merlint.File_kind.is_ml "x.ml");
  Alcotest.(check bool) "mli is not ml" false (Merlint.File_kind.is_ml "x.mli");
  Alcotest.(check bool)
    "other is not ml" false
    (Merlint.File_kind.is_ml "x.mll");
  Alcotest.(check bool) "empty is not ml" false (Merlint.File_kind.is_ml "")

let test_is_mli () =
  Alcotest.(check bool) "ml is not mli" false (Merlint.File_kind.is_mli "x.ml");
  Alcotest.(check bool) "mli is mli" true (Merlint.File_kind.is_mli "x.mli");
  Alcotest.(check bool)
    "mll is not mli" false
    (Merlint.File_kind.is_mli "x.mll");
  Alcotest.(check bool) "empty is not mli" false (Merlint.File_kind.is_mli "")

let test_is_ml_or_mli () =
  Alcotest.(check bool) "ml" true (Merlint.File_kind.is_ml_or_mli "x.ml");
  Alcotest.(check bool) "mli" true (Merlint.File_kind.is_ml_or_mli "x.mli");
  Alcotest.(check bool) "mll" false (Merlint.File_kind.is_ml_or_mli "x.mll");
  Alcotest.(check bool) "no ext" false (Merlint.File_kind.is_ml_or_mli "x");
  Alcotest.(check bool) "empty" false (Merlint.File_kind.is_ml_or_mli "")

let suite =
  ( "file_kind",
    [
      Alcotest.test_case "of_filename" `Quick test_of_filename;
      Alcotest.test_case "is_ml" `Quick test_is_ml;
      Alcotest.test_case "is_mli" `Quick test_is_mli;
      Alcotest.test_case "is_ml_or_mli" `Quick test_is_ml_or_mli;
    ] )
