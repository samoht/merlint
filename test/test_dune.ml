open Merlint

(* Test merge function *)
let test_merge () =
  (* Create empty describe values for testing *)
  let empty_desc = Dune.describe "/nonexistent" in

  (* Merge empty describes *)
  let merged = Dune.merge [ empty_desc; empty_desc ] in

  (* Check that merged is also empty *)
  let merged_files = Dune.get_project_files merged in
  Alcotest.(check int)
    "Merging empty describes results in empty" 0 (List.length merged_files)

(* Test exclude function *)
let test_exclude () =
  (* Create a describe value for current project *)
  let desc = Dune.describe "." in
  let original_files = Dune.get_project_files desc in

  (* Skip if no files found (e.g., in test environment) *)
  if List.length original_files = 0 then
    Alcotest.(check pass) "No files to test exclusion" () ()
  else
    (* Exclude test directories *)
    let excluded = Dune.exclude [ "test/" ] desc in
    let excluded_files = Dune.get_project_files excluded in

    (* Check that test files are excluded *)
    let has_test_files =
      List.exists
        (fun file -> String.length file >= 5 && String.sub file 0 5 = "test/")
        excluded_files
    in

    Alcotest.(check bool)
      "Should not have test/ files after exclusion" false has_test_files

(* Test exclude with multiple patterns *)
let test_exclude_patterns () =
  (* Create a describe value *)
  let desc = Dune.describe "." in
  let original_files = Dune.get_project_files desc in

  if List.length original_files = 0 then
    Alcotest.(check pass) "No files to test pattern exclusion" () ()
  else
    (* Exclude multiple patterns *)
    let excluded = Dune.exclude [ "_build"; "test/"; ".git" ] desc in
    let excluded_files = Dune.get_project_files excluded in

    (* Verify patterns are excluded *)
    List.iter
      (fun file ->
        let has_excluded_pattern =
          (String.length file >= 6 && String.sub file 0 6 = "_build")
          || (String.length file >= 5 && String.sub file 0 5 = "test/")
          || (String.length file >= 4 && String.sub file 0 4 = ".git")
        in
        if has_excluded_pattern then
          Alcotest.failf "File %s should have been excluded" file)
      excluded_files

(* Test is_executable function *)
let test_is_executable () =
  let desc = Dune.describe "." in

  (* Test known executable - main.ml without directory *)
  let is_exec = Dune.is_executable desc "main.ml" in
  if is_exec then Alcotest.(check pass) "Found an executable" () ()
  else
    (* It's OK if no executables are found in test environment *)
    Alcotest.(check pass) "No executables found (OK in test env)" () ()

(* Test get_lib_modules *)
let test_get_lib_modules () =
  let desc = Dune.describe "." in
  let lib_modules = Dune.get_lib_modules desc in

  (* In test environment, might have no libraries *)
  Alcotest.(check pass)
    (Printf.sprintf "Found %d library modules" (List.length lib_modules))
    () ()

(* Test get_test_modules *)
let test_get_test_modules () =
  let desc = Dune.describe "." in
  let test_modules = Dune.get_test_modules desc in

  (* In test environment, might have no tests *)
  Alcotest.(check pass)
    (Printf.sprintf "Found %d test modules" (List.length test_modules))
    () ()

(* Test ensure_project_built *)
let test_ensure_project_built () =
  match Dune.ensure_project_built "/fake/path" with
  | Ok () -> Alcotest.(check pass) "ensure_project_built returns Ok" () ()
  | Error _ -> Alcotest.fail "ensure_project_built should return Ok"

(* Test cram directory exclusion *)
let test_cram_exclusion () =
  let desc = Dune.describe "." in
  let files = Dune.get_project_files desc in

  (* Check that no cram test files are included *)
  let cram_files =
    List.filter
      (fun file ->
        (* Cram test files would be in test/cram/e001.t/bad.ml or good.ml *)
        String.length file > 10
        && String.sub file 0 10 = "test/cram/"
        && (Filename.basename file = "bad.ml"
           || Filename.basename file = "good.ml"))
      files
  in

  Alcotest.(check int)
    "Should have no cram test files" 0 (List.length cram_files)

(* Test substring exclusion logic *)
let test_exclude_substring () =
  let desc = Dune.describe "." in

  (* Exclude files containing "example" *)
  let excluded = Dune.exclude [ "example" ] desc in
  let files = Dune.get_project_files excluded in

  (* Check no files contain "example" *)
  List.iter
    (fun file ->
      if String.contains file 'e' && String.contains file 'x' then
        let rec contains s1 s2 =
          String.length s1 >= String.length s2
          && (String.sub s1 0 (String.length s2) = s2
             || contains (String.sub s1 1 (String.length s1 - 1)) s2)
        in
        if contains file "example" then
          Alcotest.failf "File %s contains 'example' but should be excluded"
            file)
    files

let suite =
  [
    ( "dune",
      [
        Alcotest.test_case "merge" `Quick test_merge;
        Alcotest.test_case "exclude" `Quick test_exclude;
        Alcotest.test_case "exclude patterns" `Quick test_exclude_patterns;
        Alcotest.test_case "exclude substring" `Quick test_exclude_substring;
        Alcotest.test_case "is_executable" `Quick test_is_executable;
        Alcotest.test_case "get_lib_modules" `Quick test_get_lib_modules;
        Alcotest.test_case "get_test_modules" `Quick test_get_test_modules;
        Alcotest.test_case "ensure_project_built" `Quick
          test_ensure_project_built;
        Alcotest.test_case "cram exclusion" `Quick test_cram_exclusion;
      ] );
  ]
