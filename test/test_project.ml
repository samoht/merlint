open Merlint

let test_find_project_root () =
  (* Test finding project root *)
  let cwd = Sys.getcwd () in
  let project_root = Project.root cwd in
  (* Should find a dune-project file somewhere up the tree *)
  Alcotest.(check bool)
    "found project root" true
    (Sys.file_exists (Filename.concat project_root "dune-project"))

let test_root_from_file () =
  (* Test finding project root from a file path *)
  let test_file = "lib/project.ml" in
  if Sys.file_exists test_file then
    let project_root = Project.root test_file in
    Alcotest.(check bool)
      "found project root from file" true
      (Sys.file_exists (Filename.concat project_root "dune-project"))
  else ()

let test_root_from_dir () =
  (* Test finding project root from a directory path *)
  let test_dir = "lib" in
  if Sys.file_exists test_dir && Sys.is_directory test_dir then
    let project_root = Project.root test_dir in
    Alcotest.(check bool)
      "found project root from directory" true
      (Sys.file_exists (Filename.concat project_root "dune-project"))
  else ()

let suite =
  ( "project",
    [
      ("find project root", `Quick, test_find_project_root);
      ("project root from file", `Quick, test_root_from_file);
      ("project root from directory", `Quick, test_root_from_dir);
    ] )
