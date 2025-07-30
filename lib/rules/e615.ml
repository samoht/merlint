(** E615: Test Suite Not Included *)

type payload = { test_module : string; test_runner_file : string }

(** Check if test.ml includes all test suites *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let issues = ref [] in

  (* Check each test stanza separately *)
  List.iter
    (fun (test_stanza, test_files) ->
      (* Debug logging *)
      Logs.debug (fun m ->
          m "E615: Checking test stanza '%s' with %d files" test_stanza
            (List.length test_files));

      (* Find test.ml in this test stanza *)
      let test_ml =
        List.find_opt
          (fun f ->
            Fpath.has_ext ".ml" f && Fpath.(f |> rem_ext |> basename) = "test")
          test_files
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
            let test_modules =
              List.filter_map
                (fun f ->
                  if Fpath.has_ext ".ml" f && f <> test_file then
                    let basename = Fpath.(f |> rem_ext |> basename) in
                    if String.starts_with ~prefix:"test_" basename then
                      Some basename
                    else None
                  else None)
                test_files
            in

            Logs.debug (fun m ->
                m "E615: Found %d test modules in stanza '%s': %a"
                  (List.length test_modules) test_stanza
                  Fmt.(list ~sep:comma string)
                  test_modules);

            (* Check which test modules are not included in test.ml *)
            let missing_includes = ref [] in
            List.iter
              (fun test_mod ->
                (* Look for Test_<module>.suite in test.ml *)
                (* test_parser -> Test_parser (only capitalize first part) *)
                let capitalized_mod = String.capitalize_ascii test_mod in
                let suite_pattern =
                  Re.compile
                    (Re.seq
                       [
                         Re.bow;
                         (* Word boundary to avoid matching in comments *)
                         Re.str capitalized_mod;
                         Re.str ".suite";
                       ])
                in
                if not (Re.execp suite_pattern test_content_no_comments) then
                  missing_includes := test_mod :: !missing_includes)
              test_modules;

            List.iter
              (fun test_mod ->
                let loc =
                  Location.create
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
    (Dune.get_tests dune_describe);

  List.rev !issues

let pp ppf { test_module; test_runner_file } =
  Fmt.pf ppf "Test module %s is not included in %s" test_module test_runner_file

let rule =
  Rule.v ~code:"E615" ~title:"Test Suite Not Included" ~category:Testing
    ~hint:
      "All test modules should be included in the main test runner (test.ml). \
       Add the missing test suite to ensure all tests are run."
    ~examples:[] ~pp (Project check)
