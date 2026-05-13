(** E615: Test Suite Not Included *)

type payload = { test_module : string; test_runner_file : string }

let log_src = Logs.Src.create "merlint.rules.e615" ~doc:"E615 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

(** Determine if a test file should be excluded based on E606 logic *)
let should_exclude_test_file dune_describe test_file declared_libraries =
  if declared_libraries = [] then false
  else
    let mod_to_libs = Dune.libraries_of_module dune_describe in
    let resolved =
      List.map (Dune.resolve_library dune_describe) declared_libraries
    in
    let basename = Fpath.(test_file |> rem_ext |> basename) in
    match Dune.test_file_library mod_to_libs basename with
    | Some lib -> not (List.mem lib resolved)
    | None -> false

(** Check if test.ml includes all test suites *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let issues = ref [] in

  (* Check each test stanza separately *)
  List.iter
    (fun test_info ->
      (* Debug logging *)
      Log.debug (fun m ->
          m "E615: Checking test stanza '%s' with %d files" test_info.Dune.name
            (List.length test_info.Dune.files));

      (* Find test.ml in this test stanza *)
      let test_ml =
        List.find_opt
          (fun f ->
            Fpath.has_ext ".ml" f && Fpath.(f |> rem_ext |> basename) = "test")
          test_info.Dune.files
      in

      match test_ml with
      | None -> () (* No test.ml in this test stanza, that's ok *)
      | Some test_file -> (
          try
            let test_content =
              In_channel.with_open_text
                (Fpath.to_string test_file)
                In_channel.input_all
            in

            (* Remove comments to avoid false matches *)
            let test_content_no_comments =
              Re.replace_string
                (Re.compile
                   (Re.seq
                      [
                        Re.str "(*"; Re.non_greedy (Re.rep Re.any); Re.str "*)";
                      ]))
                ~by:"" test_content
            in

            (* Find test modules in this test stanza *)
            let all_test_modules =
              List.filter_map
                (fun f ->
                  if Fpath.has_ext ".ml" f && f <> test_file then
                    let basename = Fpath.(f |> rem_ext |> basename) in
                    if
                      String.starts_with ~prefix:"test_" basename
                      && basename <> "test_helpers"
                    then Some (basename, f)
                    else None
                  else None)
                test_info.Dune.files
            in

            (* Filter out test modules that would be flagged by E606 *)
            let test_modules =
              List.filter_map
                (fun (basename, f) ->
                  if
                    should_exclude_test_file dune_describe f
                      test_info.Dune.libraries
                  then (
                    Log.debug (fun m ->
                        m
                          "E615: Excluding test module '%s' (would be flagged \
                           by E606)"
                          basename);
                    None)
                  else Some basename)
                all_test_modules
            in

            Log.debug (fun m ->
                m
                  "E615: Found %d test modules in stanza '%s' (after E606 \
                   filtering): %a"
                  (List.length test_modules) test_info.Dune.name
                  Fmt.(list ~sep:comma string)
                  test_modules);

            (* Check which test modules are not included in test.ml *)
            let missing_includes = ref [] in
            List.iter
              (fun test_mod ->
                let capitalized_mod = String.capitalize_ascii test_mod in
                let suite_pattern =
                  Re.compile
                    (Re.seq [ Re.bow; Re.str capitalized_mod; Re.str ".suite" ])
                in
                if not (Re.execp suite_pattern test_content_no_comments) then
                  missing_includes := test_mod :: !missing_includes)
              test_modules;

            List.iter
              (fun test_mod ->
                let loc =
                  Location.v
                    ~file:(Fpath.to_string test_file)
                    ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
                in
                issues :=
                  Issue.v ~loc
                    {
                      test_module = test_mod;
                      test_runner_file = Fpath.to_string test_file;
                    }
                  :: !issues)
              !missing_includes
          with _ -> ()))
    (Dune.tests dune_describe);

  List.rev !issues

let pp ppf { test_module; test_runner_file } =
  Fmt.pf ppf "Test module %s is not included in %s" test_module test_runner_file

let rule =
  Rule.v ~code:"E615" ~title:"Test Suite Not Included" ~category:Testing
    ~hint:
      "All test modules should be included in the main test runner (test.ml). \
       Add the missing test suite to ensure all tests are run."
    ~examples:[] ~pp (Project check)
