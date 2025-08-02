(** E600: Test Module Convention *)

type payload = { filename : string; module_name : string }

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

(** Check if a test.ml file properly uses test module suites instead of defining
    its own tests. *)
let check_test_file_uses_modules filename content =
  Logs.debug (fun m -> m "E600: Checking file %s" filename);
  if not (is_test_file filename) then (
    Logs.debug (fun m -> m "E600:   Not a test.ml file");
    [])
  else if not (has_test_runner content) then (
    Logs.debug (fun m -> m "E600:   No test runner found");
    [])
  else
    let defines_own = defines_own_tests content in
    let uses_modules = uses_test_module_suites content in
    Logs.debug (fun m ->
        m "E600:   defines_own_tests=%b, uses_test_module_suites=%b" defines_own
          uses_modules);
    if defines_own && not uses_modules then (
      (* Issue if test.ml defines its own tests instead of using test modules *)
      Logs.debug (fun m ->
          m "E600:   Found issue - defines own tests without using modules");
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          { filename; module_name = "test" };
      ])
    else (
      Logs.debug (fun m -> m "E600:   No issue found");
      [])

(** Check if a test_*.mli file exports only suite with correct type *)
let check_test_mli_file filename content =
  let basename = Filename.basename filename in
  if
    String.ends_with ~suffix:".mli" basename
    && String.starts_with ~prefix:"test_" basename
    && basename <> "test.mli"
  then
    (* Parse the interface to check what's exported *)
    let lines = String.split_on_char '\n' content in
    let non_comment_lines =
      List.filter
        (fun line ->
          let trimmed = String.trim line in
          trimmed <> "" && not (String.starts_with ~prefix:"(*" trimmed))
        lines
    in
    (* Check if it exports only a suite with the correct type *)
    let exports_suite =
      List.exists
        (fun line ->
          Re.execp
            (Re.compile
               (Re.seq
                  [
                    Re.bow;
                    Re.str "val";
                    Re.rep1 Re.space;
                    Re.str "suite";
                    Re.rep Re.space;
                    Re.str ":";
                  ]))
            line)
        non_comment_lines
    in
    let exports_other =
      List.exists
        (fun line ->
          let is_val_line =
            Re.execp
              (Re.compile (Re.seq [ Re.bow; Re.str "val"; Re.rep1 Re.space ]))
              line
          in
          let is_suite_line =
            Re.execp
              (Re.compile
                 (Re.seq
                    [
                      Re.bow;
                      Re.str "val";
                      Re.rep1 Re.space;
                      Re.str "suite";
                      Re.rep Re.space;
                      Re.str ":";
                    ]))
              line
          in
          is_val_line && not is_suite_line)
        non_comment_lines
    in
    if exports_other || not exports_suite then
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          { filename; module_name = basename |> Filename.chop_extension };
      ]
    else []
  else []

(** Check if test_*.ml files have corresponding .mli files *)
let check_missing_test_mli files =
  List.filter_map
    (fun ml_file ->
      if String.ends_with ~suffix:".ml" ml_file then
        let basename = Filename.basename ml_file in
        if String.starts_with ~prefix:"test_" basename && basename <> "test.ml"
        then
          let base_name = Filename.remove_extension ml_file in
          let mli_path = base_name ^ ".mli" in
          if not (List.mem mli_path files) then
            let loc =
              Location.v ~file:ml_file ~start_line:1 ~start_col:0 ~end_line:1
                ~end_col:0
            in
            Some
              (Issue.v ~loc
                 {
                   filename = ml_file;
                   module_name = basename |> Filename.chop_extension;
                 })
          else None
        else None
      else None)
    files

(** Check all files for test convention issues *)
let check ctx =
  let files = Context.all_files ctx in
  (* Debug log to see what files we're analyzing *)
  Logs.debug (fun m -> m "E600: Analyzing %d files:" (List.length files));
  List.iter (fun f -> Logs.debug (fun m -> m "E600:   - %s" f)) files;

  (* Check for missing .mli files for test modules *)
  let missing_mli_issues = check_missing_test_mli files in

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
            @ check_test_mli_file filename content
          with _ -> []
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
       unit Alcotest.test_case list' and no other values."
    ~examples:[] ~pp (Project check)
