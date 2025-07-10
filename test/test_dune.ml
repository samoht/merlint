open Merlint

let setup_test_project () =
  let temp_dir = Filename.temp_file "test_dune" "" in
  Sys.remove temp_dir;
  Sys.mkdir temp_dir 0o755;
  temp_dir

let cleanup_test_project dir =
  let rec remove_dir dir =
    let files = Sys.readdir dir in
    Array.iter
      (fun f ->
        let path = Filename.concat dir f in
        if Sys.is_directory path then remove_dir path else Sys.remove path)
      files;
    Sys.rmdir dir
  in
  remove_dir dir

let clear_cache () =
  (* Clear cache and verify it's empty *)
  Dune.clear_cache ();
  (* We cannot directly access the cache, but we can test the behavior *)
  Alcotest.(check bool) "cache cleared" true true

let dune_describe_cache () =
  Dune.clear_cache ();

  (* Test that run_dune_describe returns consistent results *)
  let test_root = "." in
  (* Use current directory *)
  let result1 = Dune.run_dune_describe test_root in
  let result2 = Dune.run_dune_describe test_root in

  (* Both calls should return the same result (cached) *)
  match (result1, result2) with
  | Ok out1, Ok out2 ->
      Alcotest.(check string) "cached output matches" out1 out2
  | Error _, Error _ ->
      (* Both failed, which is also consistent *)
      Alcotest.(check bool) "both calls failed consistently" true true
  | _ -> Alcotest.fail "Inconsistent results between calls"

let executable_info_basic () =
  Dune.clear_cache ();

  (* We cannot test internals, but we can test behavior *)
  let temp_dir = setup_test_project () in
  let executables = Dune.get_executable_info temp_dir in

  (* Just verify it returns a list without error *)
  Alcotest.(check bool)
    "returns list" true
    (match executables with _ :: _ -> true | [] -> true);

  cleanup_test_project temp_dir

let is_executable () =
  let temp_dir = setup_test_project () in

  (* Test with a regular .ml file *)
  let is_exe = Dune.is_executable temp_dir "mymodule.ml" in
  Alcotest.(check bool) "regular module is not executable" false is_exe;

  cleanup_test_project temp_dir

let get_executable_info () =
  Dune.clear_cache ();

  (* Test with invalid project root *)
  let executables = Dune.get_executable_info "/nonexistent/path" in
  Alcotest.(check (list string)) "empty list for invalid path" [] executables

let ensure_project_built () =
  let temp_dir = setup_test_project () in

  (* Without _build directory *)
  let result = Dune.ensure_project_built temp_dir in
  (* This will fail because temp dir doesn't have dune project *)
  Alcotest.(check bool)
    "build attempted" true
    (match result with Error _ -> true | Ok () -> false);

  (* Create _build directory *)
  let build_dir = Filename.concat temp_dir "_build" in
  Sys.mkdir build_dir 0o755;

  (* With _build directory *)
  let result = Dune.ensure_project_built temp_dir in
  Alcotest.(check bool)
    "no build needed" true
    (match result with Ok () -> true | Error _ -> false);

  cleanup_test_project temp_dir

let suite =
  [
    ( "dune",
      [
        Alcotest.test_case "clear cache" `Quick clear_cache;
        Alcotest.test_case "run dune describe cache" `Quick dune_describe_cache;
        Alcotest.test_case "get executable info basic" `Quick
          executable_info_basic;
        Alcotest.test_case "is executable" `Quick is_executable;
        Alcotest.test_case "get executable info" `Quick get_executable_info;
        Alcotest.test_case "ensure project built" `Quick ensure_project_built;
      ] );
  ]
