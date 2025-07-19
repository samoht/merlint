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

let get_module_name filename =
  let base_name = Filename.basename filename |> Filename.chop_extension in
  (* Remove _test suffix if present *)
  if String.ends_with ~suffix:"_test" base_name then
    String.sub base_name 0 (String.length base_name - 5)
  else base_name

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
            (Location.create ~file:filename ~start_line:1 ~start_col:0
               ~end_line:1 ~end_col:0)
          { filename; module_name = "test" };
      ])
    else (
      Logs.debug (fun m -> m "E600:   No issue found");
      [])

(** Check if a test_*.mli file exports only suite with correct type *)
let check_test_mli_file filename content =
  let basename = Filename.basename filename in
  (* Only check test_*.mli files in test directories, not test.mli *)
  if
    not
      (String.starts_with ~prefix:"test_" basename
      && String.ends_with ~suffix:".mli" basename
      && String.contains filename '/'
      &&
      let parts = String.split_on_char '/' filename in
      List.exists (fun p -> p = "test" || p = "tests") parts)
  then []
  else
    (* Check if it has the correct suite signature *)
    let has_correct_suite =
      Re.execp
        (Re.compile
           (Re.seq
              [
                Re.str "val";
                Re.rep1 Re.space;
                Re.str "suite";
                Re.rep Re.space;
                Re.str ":";
                Re.rep Re.space;
                Re.str "(string * unit Alcotest.test_case list) list";
              ]))
        content
    in
    (* Check if it exports anything else (simplified check) *)
    let lines = String.split_on_char '\n' content in
    let val_lines =
      List.filter
        (fun line ->
          let trimmed = String.trim line in
          String.starts_with ~prefix:"val " trimmed
          && not (String.starts_with ~prefix:"val suite" trimmed))
        lines
    in
    if (not has_correct_suite) || val_lines <> [] then
      [
        Issue.v
          ~loc:
            (Location.create ~file:filename ~start_line:1 ~start_col:0
               ~end_line:1 ~end_col:0)
          { filename; module_name = get_module_name filename };
      ]
    else []

(** Check all files for test convention issues *)
let check ctx =
  let files = Context.all_files ctx in
  (* Debug log to see what files we're analyzing *)
  Logs.debug (fun m -> m "E600: Analyzing %d files:" (List.length files));
  List.iter (fun f -> Logs.debug (fun m -> m "E600:   - %s" f)) files;

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

let pp ppf { filename = _; module_name = _ } =
  Fmt.pf ppf
    "Test file should use test module suites (e.g., Test_user.suite) instead \
     of defining its own test list"

let rule =
  Rule.v ~code:"E600" ~title:"Test Module Convention" ~category:Testing
    ~hint:
      "Test executables (test.ml) should use test suites exported by test \
       modules (test_*.ml) rather than defining their own test lists. This \
       promotes modularity and ensures test modules are properly integrated."
    ~examples:
      [
        { Rule.is_good = false; code = Examples.E600.Bad.test_ml };
        { Rule.is_good = true; code = Examples.E600.Good.test_ml };
      ]
    ~pp (Project check)
