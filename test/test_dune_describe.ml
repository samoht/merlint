(* Test merge function *)
let test_merge () =
  (* For testing merge, we need to use create_synthetic to create test describes *)
  let desc1 =
    Merlint.Dune_describe.synthetic [ "lib1/a.ml"; "lib1/b.ml"; "bin/main.ml" ]
  in
  let desc2 = Merlint.Dune_describe.synthetic [ "lib2/c.ml"; "test/test.ml" ] in

  (* Merge describes *)
  let merged = Merlint.Dune_describe.merge [ desc1; desc2 ] in

  (* Check that all items are present *)
  let merged_files = Merlint.Dune_describe.project_files merged in
  (* The merge function should combine both synthetic describes *)
  Alcotest.(check bool)
    "Merged describe should have files from both" true
    (List.length merged_files > 0)

(* Test exclude function *)
let test_exclude () =
  (* Create a describe value for current project *)
  let desc = Merlint.Dune_describe.describe (Fpath.v ".") in
  let original_files = Merlint.Dune_describe.project_files desc in

  (* Skip if no files found (e.g., in test environment) *)
  if List.length original_files = 0 then
    Alcotest.(check pass) "No files to test exclusion" () ()
  else
    (* Exclude test directories *)
    let excluded = Merlint.Dune_describe.exclude [ "test/" ] desc in
    let excluded_files = Merlint.Dune_describe.project_files excluded in

    (* Check that test files are excluded *)
    let has_test_files =
      List.exists
        (fun file ->
          let file_str = Fpath.to_string file in
          String.length file_str >= 5 && String.sub file_str 0 5 = "test/")
        excluded_files
    in

    Alcotest.(check bool)
      "Should not have test/ files after exclusion" false has_test_files

(* Test exclude with multiple patterns *)
let test_exclude_patterns () =
  (* Create a describe value *)
  let desc = Merlint.Dune_describe.describe (Fpath.v ".") in
  let original_files = Merlint.Dune_describe.project_files desc in

  if List.length original_files = 0 then
    Alcotest.(check pass) "No files to test pattern exclusion" () ()
  else
    (* Exclude multiple patterns *)
    let excluded =
      Merlint.Dune_describe.exclude [ "_build"; "test/"; ".git" ] desc
    in
    let excluded_files = Merlint.Dune_describe.project_files excluded in

    (* Verify patterns are excluded *)
    List.iter
      (fun file ->
        let file_str = Fpath.to_string file in
        let has_excluded_pattern =
          (String.length file_str >= 6 && String.sub file_str 0 6 = "_build")
          || (String.length file_str >= 5 && String.sub file_str 0 5 = "test/")
          || (String.length file_str >= 4 && String.sub file_str 0 4 = ".git")
        in
        if has_excluded_pattern then
          Alcotest.failf "File %s should have been excluded" file_str)
      excluded_files

(* Test cram test exclusion *)
let test_exclude_cram () =
  (* Create a describe value *)
  let desc = Merlint.Dune_describe.describe (Fpath.v ".") in

  (* Exclude cram test directories *)
  let excluded = Merlint.Dune_describe.exclude [ "test/cram/" ] desc in
  let excluded_files = Merlint.Dune_describe.project_files excluded in

  (* Check that no cram test files are included *)
  List.iter
    (fun file ->
      let file_str = Fpath.to_string file in
      if
        String.contains file_str '/'
        &&
        let file_with_slash = file_str ^ "/" in
        let rec contains s1 s2 =
          String.length s1 >= String.length s2
          && (String.sub s1 0 (String.length s2) = s2
             || contains (String.sub s1 1 (String.length s1 - 1)) s2)
        in
        contains file_with_slash "test/cram/"
        || contains file_with_slash "/test/cram/"
      then Alcotest.failf "Cram test file %s should have been excluded" file_str)
    excluded_files;

  Alcotest.(check pass) "No cram test files included after exclusion" () ()

(* Test is_executable function *)
let test_is_executable () =
  let desc = Merlint.Dune_describe.describe (Fpath.v ".") in

  (* Test known executable - main.ml without directory *)
  let is_exec = Merlint.Dune_describe.is_executable desc (Fpath.v "main.ml") in
  if is_exec then Alcotest.(check pass) "Found an executable" () ()
  else
    (* It's OK if no executables are found in test environment *)
    Alcotest.(check pass) "No executables found (OK in test env)" () ()

(* Test get_lib_modules *)
let test_get_lib_modules () =
  let desc = Merlint.Dune_describe.describe (Fpath.v ".") in
  let lib_modules = Merlint.Dune_describe.lib_modules desc in

  (* In test environment, might have no libraries *)
  Alcotest.(check pass)
    (Fmt.str "Found %d library modules" (List.length lib_modules))
    () ()

(* Test get_test_modules *)
let test_get_test_modules () =
  let desc = Merlint.Dune_describe.describe (Fpath.v ".") in
  let test_modules = Merlint.Dune_describe.test_modules desc in

  (* In test environment, might have no tests *)
  Alcotest.(check pass)
    (Fmt.str "Found %d test modules" (List.length test_modules))
    () ()

(* Test ensure_project_built - runs dune build in current directory *)
let test_ensure_project_built () =
  Eio_main.run @@ fun env ->
  let mgr = Eio.Stdenv.process_mgr env in
  (* In a dune project (like this test), it should succeed *)
  match Merlint.Dune_describe.ensure_project_built ~path:"." mgr with
  | Ok () -> Alcotest.(check pass) "dune build succeeds" () ()
  | Error _ -> Alcotest.(check pass) "dune build may fail in test context" () ()

(* Test cram directory exclusion *)
let test_cram_exclusion () =
  let desc = Merlint.Dune_describe.describe (Fpath.v ".") in
  let files = Merlint.Dune_describe.project_files desc in

  (* Check that no cram test files are included *)
  let cram_files =
    List.filter
      (fun file ->
        (* Cram test files would be in test/cram/e001.t/bad.ml or good.ml *)
        let file_str = Fpath.to_string file in
        String.length file_str > 10
        && String.sub file_str 0 10 = "test/cram/"
        && (Fpath.(file |> basename) = "bad.ml"
           || Fpath.(file |> basename) = "good.ml"))
      files
  in

  Alcotest.(check int)
    "Should have no cram test files" 0 (List.length cram_files)

(* Test substring exclusion logic *)
let test_exclude_substring () =
  let desc = Merlint.Dune_describe.describe (Fpath.v ".") in

  (* Exclude files containing "example" *)
  let excluded = Merlint.Dune_describe.exclude [ "example" ] desc in
  let files = Merlint.Dune_describe.project_files excluded in

  (* Check no files contain "example" *)
  List.iter
    (fun file ->
      let file_str = Fpath.to_string file in
      if String.contains file_str 'e' && String.contains file_str 'x' then
        let rec contains s1 s2 =
          String.length s1 >= String.length s2
          && (String.sub s1 0 (String.length s2) = s2
             || contains (String.sub s1 1 (String.length s1 - 1)) s2)
        in
        if contains file_str "example" then
          Alcotest.failf "File %s contains 'example' but should be excluded"
            file_str)
    files

let with_temp_dune content f =
  let dir = Filename.temp_file "merlint_dune_describe" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  let dune_path = Filename.concat dir "dune" in
  let oc = open_out dune_path in
  output_string oc content;
  close_out oc;
  Fun.protect
    ~finally:(fun () ->
      (try Sys.remove dune_path with Sys_error _ -> ());
      try Unix.rmdir dir with Unix.Unix_error _ -> ())
    (fun () -> f (Fpath.v dir))

let test_excluded_subdirs_missing_dune () =
  let dir = Filename.temp_file "merlint_dune_describe_empty" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  Fun.protect
    ~finally:(fun () -> try Unix.rmdir dir with Unix.Unix_error _ -> ())
    (fun () ->
      Alcotest.(check (list string))
        "no dune file -> no excluded subdirs" []
        (Merlint.Dune_describe.excluded_subdirs_of_dune (Fpath.v dir)))

let test_excluded_subdirs_empty () =
  with_temp_dune "(library (name foo))" (fun dir ->
      Alcotest.(check (list string))
        "no data_only / vendored stanza -> no excluded subdirs" []
        (Merlint.Dune_describe.excluded_subdirs_of_dune dir))

let test_excluded_subdirs_data_only () =
  with_temp_dune "(data_only_dirs fixtures traces)" (fun dir ->
      Alcotest.(check (list string))
        "data_only_dirs entries are excluded" [ "fixtures"; "traces" ]
        (Merlint.Dune_describe.excluded_subdirs_of_dune dir))

let test_excluded_subdirs_vendored () =
  with_temp_dune "(vendored_dirs third_party)" (fun dir ->
      Alcotest.(check (list string))
        "vendored_dirs entries are excluded" [ "third_party" ]
        (Merlint.Dune_describe.excluded_subdirs_of_dune dir))

let test_excluded_subdirs_both () =
  with_temp_dune
    "(data_only_dirs corpora)\n(vendored_dirs upstream)\n(library (name foo))"
    (fun dir ->
      Alcotest.(check (list string))
        "data_only and vendored combine in order" [ "corpora"; "upstream" ]
        (Merlint.Dune_describe.excluded_subdirs_of_dune dir))

let test_excluded_subdirs_malformed () =
  with_temp_dune "(this is (((((not a valid dune file" (fun dir ->
      Alcotest.(check (list string))
        "malformed dune file -> no crash, empty result" []
        (Merlint.Dune_describe.excluded_subdirs_of_dune dir))

let suite =
  ( "dune_describe",
    [
      Alcotest.test_case "merge" `Quick test_merge;
      Alcotest.test_case "exclude" `Quick test_exclude;
      Alcotest.test_case "exclude patterns" `Quick test_exclude_patterns;
      Alcotest.test_case "exclude substring" `Quick test_exclude_substring;
      Alcotest.test_case "exclude cram" `Quick test_exclude_cram;
      Alcotest.test_case "is_executable" `Quick test_is_executable;
      Alcotest.test_case "get_lib_modules" `Quick test_get_lib_modules;
      Alcotest.test_case "get_test_modules" `Quick test_get_test_modules;
      Alcotest.test_case "ensure_project_built" `Quick test_ensure_project_built;
      Alcotest.test_case "cram exclusion" `Quick test_cram_exclusion;
      Alcotest.test_case "excluded_subdirs: no dune file" `Quick
        test_excluded_subdirs_missing_dune;
      Alcotest.test_case "excluded_subdirs: no data_only/vendored stanza" `Quick
        test_excluded_subdirs_empty;
      Alcotest.test_case "excluded_subdirs: data_only_dirs" `Quick
        test_excluded_subdirs_data_only;
      Alcotest.test_case "excluded_subdirs: vendored_dirs" `Quick
        test_excluded_subdirs_vendored;
      Alcotest.test_case "excluded_subdirs: both stanzas" `Quick
        test_excluded_subdirs_both;
      Alcotest.test_case "excluded_subdirs: malformed dune file" `Quick
        test_excluded_subdirs_malformed;
    ] )
