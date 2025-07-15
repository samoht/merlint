(** E615: Test Suite Not Included *)

(** Check if test.ml includes all test suites *)
let check dune_describe files =
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
        let content =
          In_channel.with_open_text test_file In_channel.input_all
        in
        let test_modules = E605.get_test_modules dune_describe in

        (* Check if each test module's suite is included *)
        let missing_suites =
          List.filter
            (fun mod_name ->
              let suite_pattern = Fmt.str "Test_%s.suite" mod_name in
              not (Re.execp (Re.compile (Re.str suite_pattern)) content))
            test_modules
        in

        List.map
          (fun mod_name ->
            Issue.Test_suite_not_included
              {
                test_module = Fmt.str "Test_%s" mod_name;
                test_runner_file = test_file;
                location =
                  Location.create ~file:test_file ~start_line:1 ~start_col:0
                    ~end_line:1 ~end_col:0;
              })
          missing_suites
      with _ -> [])
