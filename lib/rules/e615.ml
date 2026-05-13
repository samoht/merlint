(** E615: Test Suite Not Included *)

type payload = { test_module : string; test_runner_file : string }

let log_src = Logs.Src.create "merlint.rules.e615" ~doc:"E615 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

(** Determine if a test file should be excluded based on E606 logic *)
let should_exclude_test_file dune_describe test_file declared_libraries =
  if declared_libraries = [] then false
  else
    let mod_to_libs = Dune_describe.libraries_of_module dune_describe in
    let resolved =
      List.map (Dune_describe.resolve_library dune_describe) declared_libraries
    in
    let basename = Fpath.(test_file |> rem_ext |> basename) in
    match Dune_describe.test_file_library mod_to_libs basename with
    | Some lib -> not (List.mem lib resolved)
    | None -> false

let strip_comments content =
  Re.replace_string
    (Re.compile
       (Re.seq [ Re.str "(*"; Re.non_greedy (Re.rep Re.any); Re.str "*)" ]))
    ~by:"" content

let test_runner files =
  List.find_opt
    (fun f ->
      Fpath.has_ext ".ml" f && Fpath.(f |> rem_ext |> basename) = "test")
    files

let all_test_modules test_file files =
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
    files

let test_modules dune_describe (test_info : Dune_describe.test_info) test_file =
  all_test_modules test_file test_info.files
  |> List.filter_map (fun (basename, f) ->
      if should_exclude_test_file dune_describe f test_info.libraries then (
        Log.debug (fun m ->
            m "E615: Excluding test module '%s' (would be flagged by E606)"
              basename);
        None)
      else Some basename)

let suite_included content test_mod =
  let capitalized_mod = String.capitalize_ascii test_mod in
  let suite_pattern =
    Re.compile (Re.seq [ Re.bow; Re.str capitalized_mod; Re.str ".suite" ])
  in
  Re.execp suite_pattern content

let missing_issue test_file test_mod =
  let loc =
    Location.v
      ~file:(Fpath.to_string test_file)
      ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
  in
  Issue.v ~loc
    { test_module = test_mod; test_runner_file = Fpath.to_string test_file }

let check_test_info dune_describe (test_info : Dune_describe.test_info) =
  Log.debug (fun m ->
      m "E615: Checking test stanza '%s' with %d files" test_info.name
        (List.length test_info.files));
  match test_runner test_info.files with
  | None -> []
  | Some test_file -> (
      try
        let content =
          In_channel.with_open_text
            (Fpath.to_string test_file)
            In_channel.input_all
          |> strip_comments
        in
        let modules = test_modules dune_describe test_info test_file in
        Log.debug (fun m ->
            m
              "E615: Found %d test modules in stanza '%s' (after E606 \
               filtering): %a"
              (List.length modules) test_info.name
              Fmt.(list ~sep:comma string)
              modules);
        modules
        |> List.filter (fun test_mod -> not (suite_included content test_mod))
        |> List.map (missing_issue test_file)
      with Sys_error _ -> [])

(** Check if test.ml includes all test suites *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  Dune_describe.tests dune_describe
  |> List.concat_map (check_test_info dune_describe)

let pp ppf { test_module; test_runner_file } =
  Fmt.pf ppf "Test module %s is not included in %s" test_module test_runner_file

let rule =
  Rule.v ~code:"E615" ~title:"Test Suite Not Included" ~category:Testing
    ~hint:
      "All test modules should be included in the main test runner (test.ml). \
       Add the missing test suite to ensure all tests are run."
    ~examples:[] ~pp (Project check)
