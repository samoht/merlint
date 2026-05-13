(** E600: Test Module Convention *)

type payload = { filename : string; module_name : string }

let log_src = Logs.Src.create "merlint.rules.e600" ~doc:"E600 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

let is_test_file filename =
  (* Only test executables named test.ml should follow this convention *)
  Filename.basename filename = "test.ml"

let has_test_runner content =
  Re.execp (Re.compile (Re.str "Alcotest.run")) content

let uses_test_module_suites content =
  (* Check if test.ml uses test module suites (Test_*.suite) *)
  Re.execp
    (Re.compile
       (Re.seq
          [
            Re.bow;
            Re.str "Test_";
            Re.rep1 (Re.alt [ Re.alnum; Re.char '_' ]);
            Re.str ".suite";
          ]))
    content

let defines_own_tests content =
  (* Check if test.ml defines its own test list directly *)
  Re.execp
    (Re.compile
       (Re.seq
          [
            Re.str "let";
            Re.rep1 Re.space;
            Re.group (Re.alt [ Re.str "tests"; Re.str "suite" ]);
            Re.rep Re.space;
            Re.str "=";
            Re.rep Re.space;
            Re.str "[";
          ]))
    content

let test_mli_needs_issue content =
  not
    (Suite_mli.is_compliant ~expected:"string * unit Alcotest.test_case list"
       content)

let test_mli_target dune_describe filename =
  let basename = Filename.basename filename in
  String.ends_with ~suffix:".mli" basename
  && String.starts_with ~prefix:"test_" basename
  && basename <> "test.mli"
  && (not (File.is_in_private_library dune_describe filename))
  && not (File.is_in_examples filename)

(** Check if a test.ml file properly uses test module suites instead of defining
    its own tests. *)
let check_test_file_uses_modules filename content =
  Log.debug (fun m -> m "E600: Checking file %s" filename);
  if not (is_test_file filename) then (
    Log.debug (fun m -> m "E600:   Not a test.ml file");
    [])
  else if not (has_test_runner content) then (
    Log.debug (fun m -> m "E600:   No test runner found");
    [])
  else
    let defines_own = defines_own_tests content in
    let uses_modules = uses_test_module_suites content in
    Log.debug (fun m ->
        m "E600:   defines_own_tests=%b, uses_test_module_suites=%b" defines_own
          uses_modules);
    if defines_own && not uses_modules then (
      (* Issue if test.ml defines its own tests instead of using test modules *)
      Log.debug (fun m ->
          m "E600:   Found issue - defines own tests without using modules");
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          { filename; module_name = "test" };
      ])
    else (
      Log.debug (fun m -> m "E600:   No issue found");
      [])

(** Check if test_*.ml file incorrectly contains Alcotest.run. The test runner
    should only be in test.ml, not in individual test modules. *)
let check_runner_in_wrong_file filename content =
  let basename = Filename.basename filename in
  if
    String.ends_with ~suffix:".ml" basename
    && String.starts_with ~prefix:"test_" basename
    && basename <> "test.ml"
    && (not (File.is_in_examples filename))
    && has_test_runner content
  then
    [
      Issue.v
        ~loc:
          (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
             ~end_col:0)
        { filename; module_name = basename |> Filename.chop_extension };
    ]
  else []

(** Check if a test_*.mli file exports only suite with correct type. Skips files
    that belong to private libraries. *)
let check_test_mli_file dune_describe filename content =
  let basename = Filename.basename filename in
  if test_mli_target dune_describe filename then
    if test_mli_needs_issue content then
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          { filename; module_name = basename |> Filename.chop_extension };
      ]
    else []
  else []

let test_ml_target dune_describe ml_file =
  let basename = Filename.basename ml_file in
  String.ends_with ~suffix:".ml" ml_file
  && String.starts_with ~prefix:"test_" basename
  && basename <> "test.ml"
  && (not (File.is_in_private_library dune_describe ml_file))
  && not (File.is_in_examples ml_file)

let file_has_runner ml_file =
  try
    let content = In_channel.with_open_text ml_file In_channel.input_all in
    has_test_runner content
  with Sys_error _ -> false

let missing_test_mli_issue files ml_file =
  let mli_path = Filename.remove_extension ml_file ^ ".mli" in
  if List.mem mli_path files then None
  else
    let basename = Filename.basename ml_file in
    let loc =
      Location.v ~file:ml_file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    in
    Some
      (Issue.v ~loc
         { filename = ml_file; module_name = Filename.chop_extension basename })

(** Check if test_*.ml files have corresponding .mli files. Skip files that
    contain Alcotest.run since they shouldn't be test modules, and files that
    belong to private libraries. *)
let check_missing_test_mli dune_describe files =
  List.filter_map
    (fun ml_file ->
      if test_ml_target dune_describe ml_file && not (file_has_runner ml_file)
      then missing_test_mli_issue files ml_file
      else None)
    files

(** Check all files for test convention issues *)
let check ctx =
  let files = Context.all_files ctx in
  let dune_describe = Context.dune_describe ctx in
  (* Debug log to see what files we're analyzing *)
  Log.debug (fun m -> m "E600: Analyzing %d files:" (List.length files));
  List.iter (fun f -> Log.debug (fun m -> m "E600:   - %s" f)) files;

  (* Check for missing .mli files for test modules *)
  let missing_mli_issues = check_missing_test_mli dune_describe files in

  let content_issues =
    List.concat_map
      (fun filename ->
        if
          String.ends_with ~suffix:".ml" filename
          || String.ends_with ~suffix:".mli" filename
        then
          try
            let content =
              In_channel.with_open_text filename In_channel.input_all
            in
            check_test_file_uses_modules filename content
            @ check_runner_in_wrong_file filename content
            @ check_test_mli_file dune_describe filename content
          with Sys_error _ -> []
        else [])
      files
  in

  missing_mli_issues @ content_issues

let pp ppf { filename; module_name = _ } =
  if String.ends_with ~suffix:".mli" filename then
    Fmt.pf ppf
      "Test module interface should only export 'suite' with type string * \
       unit Alcotest.test_case list"
  else if String.ends_with ~suffix:".ml" filename then
    let basename = Filename.basename filename in
    if String.starts_with ~prefix:"test_" basename && basename <> "test.ml" then
      (* Check if file contains Alcotest.run to determine the error *)
      let has_runner =
        try
          let content =
            In_channel.with_open_text filename In_channel.input_all
          in
          has_test_runner content
        with Sys_error _ -> false
      in
      if has_runner then
        Fmt.pf ppf
          "Alcotest.run should be in test.ml, not in %s - test modules should \
           only export a suite value"
          basename
      else
        Fmt.pf ppf "Test module %s is missing interface file %s" filename
          (Filename.remove_extension filename ^ ".mli")
    else
      Fmt.pf ppf
        "Test file should use test module suites (e.g., Test_user.suite) \
         instead of defining its own test list"
  else
    Fmt.pf ppf
      "Test file should use test module suites (e.g., Test_user.suite) instead \
       of defining its own test list"

let rule =
  Rule.v ~code:"E600" ~title:"Test Module Convention" ~category:Testing
    ~hint:
      "Enforces proper test organization: (1) Test executables (test.ml) \
       should use test suites from test modules (e.g., Test_user.suite) rather \
       than defining their own test lists directly. (2) Test module interfaces \
       (test_*.mli) should only export a 'suite' value with type 'string * \
       unit Alcotest.test_case list' and no other values. (3) Alcotest.run \
       should only appear in test.ml, not in individual test_*.ml modules."
    ~examples:[] ~pp (Project check)
