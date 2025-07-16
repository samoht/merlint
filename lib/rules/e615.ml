(** E615: Test Suite Not Included *)

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
        let test_modules = Context.test_modules ctx in

        (* Check which test modules are not included in test.ml *)
        let missing_includes = ref [] in
        List.iter
          (fun test_mod ->
            (* Look for Test_<module>.suite in test.ml *)
            let suite_pattern =
              Re.compile
                (Re.seq
                   [
                     Re.str (String.capitalize_ascii test_mod); Re.str ".suite";
                   ])
            in
            if not (Re.execp suite_pattern test_content) then
              missing_includes := test_mod :: !missing_includes)
          test_modules;

        List.map
          (fun test_mod ->
            Issue.Test_suite_not_included
              {
                test_module = test_mod;
                test_runner_file = test_file;
                location =
                  Location.create ~file:test_file ~start_line:1 ~start_col:0
                    ~end_line:1 ~end_col:0;
              })
          !missing_includes
      with _ -> [])
