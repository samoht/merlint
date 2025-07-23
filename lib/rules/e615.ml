(** E615: Test Suite Not Included *)

type payload = { test_module : string; test_runner_file : string }

(** Check if test.ml includes all test suites *)
let check (ctx : Context.project) =
  let files = Context.all_files ctx in
  (* Find test.ml *)
  let test_ml =
    List.find_opt
      (fun f ->
        f = "test/test.ml" || String.ends_with ~suffix:"/test/test.ml" f)
      files
  in

  match test_ml with
  | None -> []
  | Some test_file -> (
      try
        let test_content =
          In_channel.with_open_text test_file In_channel.input_all
        in

        (* Remove comments to avoid false matches *)
        let test_content_no_comments =
          Re.replace_string
            (Re.compile
               (Re.seq
                  [ Re.str "(*"; Re.non_greedy (Re.rep Re.any); Re.str "*)" ]))
            ~by:"" test_content
        in

        (* Find test modules by looking for test_*.ml files in the same directory *)
        let test_dir = Filename.dirname test_file in
        let test_modules =
          List.filter_map
            (fun f ->
              if
                String.starts_with ~prefix:test_dir f
                && String.ends_with ~suffix:".ml" f
                && f <> test_file
              then
                let basename = Filename.basename f in
                if String.starts_with ~prefix:"test_" basename then
                  let module_name = Filename.chop_extension basename in
                  Some module_name
                else None
              else None)
            files
        in

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

        List.map
          (fun test_mod ->
            let loc =
              Location.create ~file:test_file ~start_line:1 ~start_col:0
                ~end_line:1 ~end_col:0
            in
            Issue.v ~loc
              { test_module = test_mod; test_runner_file = test_file })
          !missing_includes
      with _ -> [])

let pp ppf { test_module; test_runner_file } =
  Fmt.pf ppf "Test module %s is not included in %s" test_module test_runner_file

let rule =
  Rule.v ~code:"E615" ~title:"Test Suite Not Included" ~category:Testing
    ~hint:
      "All test modules should be included in the main test runner (test.ml). \
       Add the missing test suite to ensure all tests are run."
    ~examples:
      [
        Example.bad Examples.E615.Bad_test.test_ml;
        Example.good Examples.E615.Good_test.test_ml;
      ]
    ~pp (Project check)
