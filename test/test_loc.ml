let test_relative_inside_root () =
  let root = Fpath.v "/workspace/project" in
  let path = Fpath.v "/workspace/project/lib/foo.ml" in
  Alcotest.(check string)
    "relative path" "lib/foo.ml"
    (Fpath.to_string (Merlint.Loc.relative_to ~root path))

let test_relative_outside_keeps_original () =
  let root = Fpath.v "/workspace/project" in
  let path = Fpath.v "/workspace/other/foo.ml" in
  Alcotest.(check string)
    "outside path" "/workspace/other/foo.ml"
    (Fpath.to_string (Merlint.Loc.relative_to ~root path))

let test_file_uses_fpath_string () =
  let loc = Merlint.Loc.in_file (Fpath.v "lib/foo.ml") in
  Alcotest.(check string) "file" "lib/foo.ml" loc.file

let tests =
  [
    ("relative_inside_root", `Quick, test_relative_inside_root);
    ("relative_outside_root", `Quick, test_relative_outside_keeps_original);
    ("in_file_uses_fpath_string", `Quick, test_file_uses_fpath_string);
  ]

let suite = ("loc", tests)
