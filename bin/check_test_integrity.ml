(* Compile regular expressions once *)

(* Matches a merlint command with -r flag: $ ... merlint ... -r ... *)
let re_merlint_r_cmd =
  Re.compile
    (Re.seq
       [
         Re.char '$';
         Re.rep Re.any;
         Re.str "merlint";
         Re.rep Re.any;
         Re.str "-r";
       ])

(* Build regex for bad test: $ ... merlint ... -r RULE ... (bad.ml|bad/) *)
let make_bad_test_re rule_code =
  Re.compile
    (Re.seq
       [
         Re.char '$';
         Re.rep Re.any;
         Re.str "merlint";
         Re.rep Re.any;
         Re.str "-r";
         Re.rep1 Re.space;
         Re.str rule_code;
         Re.rep Re.any;
         Re.alt [ Re.str "bad.ml"; Re.str "bad/" ];
       ])

(* Build regex for good test: $ ... merlint ... -r RULE ... (good.ml|good/) *)
let make_good_test_re rule_code =
  Re.compile
    (Re.seq
       [
         Re.char '$';
         Re.rep Re.any;
         Re.str "merlint";
         Re.rep Re.any;
         Re.str "-r";
         Re.rep1 Re.space;
         Re.str rule_code;
         Re.rep Re.any;
         Re.alt [ Re.str "good.ml"; Re.str "good/" ];
       ])

let re_dune_error =
  Re.compile
    (Re.seq [ Re.str "ERROR"; Re.rep Re.any; Re.str "Dune build failed" ])

let re_continuing = Re.compile (Re.str "Continuing with analysis")
let re_exit_1 = Re.compile (Re.str "[1]")

let re_zero_issues =
  Re.compile
    (Re.alt
       [ Re.str "✓ 0 total issues"; Re.str "Summary: ✓ All checks passed" ])

let re_merlint_cmd = Re.compile (Re.seq [ Re.bos; Re.str "  $ merlint" ])
let re_two_spaces = Re.compile (Re.seq [ Re.bos; Re.str "  " ])

(* Extract test name regex *)
let re_bad_test_name = Re.compile (Re.alt [ Re.str "bad.ml"; Re.str "bad/" ])
let re_good_test_name = Re.compile (Re.alt [ Re.str "good.ml"; Re.str "good/" ])

(* Get all error codes from rules *)
let get_all_error_codes () =
  Merlint.Data.all_rules |> List.map Merlint.Rule.code
  |> List.map String.lowercase_ascii

(* Extract error code from directory name *)
let extract_error_code dir_name =
  if String.length dir_name > 2 && String.ends_with ~suffix:".t" dir_name then
    let code = String.sub dir_name 0 (String.length dir_name - 2) in
    Some (String.lowercase_ascii code)
  else None

(* Get all test directories *)
let get_test_directories cram_dir =
  if Sys.file_exists cram_dir && Sys.is_directory cram_dir then
    Sys.readdir cram_dir |> Array.to_list
    |> List.filter (fun name ->
           String.ends_with ~suffix:".t" name
           && Sys.is_directory (Filename.concat cram_dir name))
    |> List.filter_map extract_error_code
  else []

(* Check if required files exist in test directory *)
let check_test_files cram_dir error_code =
  let test_dir = Filename.concat cram_dir (error_code ^ ".t") in
  let bad_file = Filename.concat test_dir "bad.ml" in
  let good_file = Filename.concat test_dir "good.ml" in
  (* Also check for subdirectory structure *)
  let bad_dir = Filename.concat test_dir "bad" in
  let good_dir = Filename.concat test_dir "good" in
  let run_file = Filename.concat test_dir "run.t" in
  let dune_project_file = Filename.concat test_dir "dune-project" in
  let dune_file = Filename.concat test_dir "dune" in

  (* Either regular files or directory structure is acceptable *)
  let bad_exists =
    Sys.file_exists bad_file
    || (Sys.file_exists bad_dir && Sys.is_directory bad_dir)
  in
  let good_exists =
    Sys.file_exists good_file
    || (Sys.file_exists good_dir && Sys.is_directory good_dir)
  in
  let run_exists = Sys.file_exists run_file in
  (* Check if this test uses subdirectory structure *)
  let has_subdirs =
    Sys.file_exists bad_dir && Sys.is_directory bad_dir
    && Sys.file_exists good_dir && Sys.is_directory good_dir
  in

  (* For dune-project file:
     - If subdirs exist, dune-project should be in each subdir, NOT at root
     - If no subdirs (regular structure), dune-project should be at root *)
  let dune_project_exists =
    if has_subdirs then
      (* Subdirectory structure - check in subdirs and ensure NOT at root *)
      let bad_dune_project = Filename.concat bad_dir "dune-project" in
      let good_dune_project = Filename.concat good_dir "dune-project" in
      Sys.file_exists bad_dune_project && Sys.file_exists good_dune_project
    else
      (* Regular structure - check at root *)
      Sys.file_exists dune_project_file
  in

  (* Check for incorrect root-level files when using subdirs *)
  let has_incorrect_root_files =
    has_subdirs
    && (Sys.file_exists dune_project_file || Sys.file_exists dune_file)
  in

  (* For dune file: 
     - If bad.ml or good.ml exist at root, we need dune at root
     - If only bad/ and good/ directories exist, we don't need dune at root
       (subdirectories should have their own dune files) *)
  let needs_root_dune = Sys.file_exists bad_file || Sys.file_exists good_file in
  let dune_exists = (not needs_root_dune) || Sys.file_exists dune_file in
  ( bad_exists,
    good_exists,
    run_exists,
    dune_project_exists,
    dune_exists,
    has_subdirs,
    has_incorrect_root_files )

(* Check if run.t file uses correct -r flag format *)
(* Check if a command line has the correct -r flag *)
let check_r_flag_usage parts rule_code =
  let rec find_r_flag = function
    | "-r" :: next :: _ ->
        if next <> rule_code then
          Some (Fmt.str "Line uses '-r %s' instead of '-r %s'" next rule_code)
        else None
    | _ :: rest -> find_r_flag rest
    | [] -> None
  in
  find_r_flag parts

(* Check if line is a bad test *)
let is_bad_test line bad_test_re = Re.execp bad_test_re line

(* Check if line is a good test *)
let is_good_test line good_test_re = Re.execp good_test_re line

(* State for tracking test format checking *)
type format_check_state = {
  has_bad_test : bool;
  has_good_test : bool;
  wrong_formats : string list;
}

(* Process a line from run.t for format checking *)
let process_format_line line rule_code bad_test_re good_test_re state =
  let new_wrong_formats =
    if Re.execp re_merlint_r_cmd line then
      let parts = String.split_on_char ' ' (String.trim line) in
      match check_r_flag_usage parts rule_code with
      | Some err -> err :: state.wrong_formats
      | None -> state.wrong_formats
    else state.wrong_formats
  in
  {
    has_bad_test = state.has_bad_test || is_bad_test line bad_test_re;
    has_good_test = state.has_good_test || is_good_test line good_test_re;
    wrong_formats = new_wrong_formats;
  }

let check_run_t_format cram_dir error_code =
  let test_dir = Filename.concat cram_dir (error_code ^ ".t") in
  let run_file = Filename.concat test_dir "run.t" in
  let rule_code = String.uppercase_ascii error_code in
  let bad_test_re = make_bad_test_re rule_code in
  let good_test_re = make_good_test_re rule_code in

  if not (Sys.file_exists run_file) then (false, false, [])
  else
    let ic = open_in run_file in
    let rec check_lines state =
      try
        let line = input_line ic in
        let new_state =
          process_format_line line rule_code bad_test_re good_test_re state
        in
        check_lines new_state
      with End_of_file ->
        close_in ic;
        (state.has_bad_test, state.has_good_test, List.rev state.wrong_formats)
    in
    let initial_state = { has_bad_test = false; has_good_test = false; wrong_formats = [] } in
    check_lines initial_state

(* Parse run.t file to check expected output *)
(* Extract test name from merlint command line *)
let extract_test_name line =
  if Re.execp re_bad_test_name line then "bad"
  else if Re.execp re_good_test_name line then "good"
  else ""

(* Add test result if valid *)
let add_test_result current_test output_lines acc =
  if current_test <> "" && output_lines <> [] then
    (current_test, List.rev output_lines) :: acc
  else acc

(* State for parsing run.t files *)
type parse_state = {
  current_test : string;
  in_output : bool;
  output_lines : string list;
  acc : (string * string list) list;
}

(* Process a line from run.t file *)
let process_run_t_line line state =
  if Re.execp re_merlint_cmd line then
    (* Start of a new test *)
    let test_name = extract_test_name line in
    let new_acc = add_test_result state.current_test state.output_lines state.acc in
    { current_test = test_name; in_output = true; output_lines = []; acc = new_acc }
  else if state.in_output && Re.execp re_two_spaces line then
    (* Part of the output *)
    { state with output_lines = line :: state.output_lines }
  else
    (* End of output or other content *)
    let new_acc = add_test_result state.current_test state.output_lines state.acc in
    { current_test = ""; in_output = false; output_lines = []; acc = new_acc }

let check_run_t_output cram_dir error_code =
  let test_dir = Filename.concat cram_dir (error_code ^ ".t") in
  let run_file = Filename.concat test_dir "run.t" in

  if not (Sys.file_exists run_file) then []
  else
    let ic = open_in run_file in
    let rec parse_test state =
      try
        let line = input_line ic in
        let new_state = process_run_t_line line state in
        parse_test new_state
      with End_of_file ->
        close_in ic;
        let final_acc = add_test_result state.current_test state.output_lines state.acc in
        List.rev final_acc
    in
    let initial_state = { current_test = ""; in_output = false; output_lines = []; acc = [] } in
    parse_test initial_state

(* Check 1: Every rule must have a test directory *)
let check_missing_test_dirs cram_dir defined_rules test_dirs errors =
  List.iter
    (fun rule_code ->
      if not (List.mem rule_code test_dirs) then
        errors :=
          Fmt.str
            "Error: Rule %s is defined but missing test directory at %s/%s.t/"
            (String.uppercase_ascii rule_code)
            cram_dir rule_code
          :: !errors)
    defined_rules

(* Check 2: Every test directory must correspond to a defined rule *)
let check_undefined_rules cram_dir defined_rules test_dirs errors =
  List.iter
    (fun test_code ->
      if not (List.mem test_code defined_rules) then
        errors :=
          Fmt.str
            "Error: Test directory %s/%s.t/ exists but rule %s is not defined"
            cram_dir test_code
            (String.uppercase_ascii test_code)
          :: !errors)
    test_dirs

(* Check 3: Every test directory must have required files *)
let check_test_directory_structure cram_dir defined_rules test_dirs errors =
  List.iter
    (fun rule_code ->
      if List.mem rule_code test_dirs then (
        let ( bad_exists,
              good_exists,
              run_exists,
              dune_project_exists,
              dune_exists,
              has_subdirs,
              has_incorrect_root_files ) =
          check_test_files cram_dir rule_code
        in
        if not bad_exists then
          errors :=
            Fmt.str "Error: %s/%s.t/bad.ml is missing" cram_dir rule_code
            :: !errors;
        if not good_exists then
          errors :=
            Fmt.str "Error: %s/%s.t/good.ml is missing" cram_dir rule_code
            :: !errors;
        if not run_exists then
          errors :=
            Fmt.str "Error: %s/%s.t/run.t is missing" cram_dir rule_code
            :: !errors
        else
          (* Check 4: run.t must use correct -r flag format *)
          let has_bad_test, has_good_test, wrong_formats =
            check_run_t_format cram_dir rule_code
          in
          if not has_bad_test then
            errors :=
              Fmt.str "Error: %s/%s.t/run.t doesn't test 'merlint -r %s bad.ml'"
                cram_dir rule_code
                (String.uppercase_ascii rule_code)
              :: !errors;
          if not has_good_test then
            errors :=
              Fmt.str
                "Error: %s/%s.t/run.t doesn't test 'merlint -r %s good.ml'"
                cram_dir rule_code
                (String.uppercase_ascii rule_code)
              :: !errors;
          (* Report any wrong -r flag usage *)
          List.iter
            (fun msg ->
              errors :=
                Fmt.str "Error: %s/%s.t/run.t: %s" cram_dir rule_code msg
                :: !errors)
            wrong_formats;
          (* Check 5: test directories SHOULD have dune-project and dune files in correct location *)
          if has_incorrect_root_files then
            errors :=
              Fmt.str
                "Error: %s/%s.t has dune or dune-project at root but uses \
                 subdirectory structure - these files should be in bad/ and \
                 good/ subdirs instead"
                cram_dir rule_code
              :: !errors;
          if not dune_project_exists then
            if has_subdirs then
              errors :=
                Fmt.str
                  "Error: %s/%s.t/{bad,good}/dune-project files are missing"
                  cram_dir rule_code
                :: !errors
            else
              errors :=
                Fmt.str "Error: %s/%s.t/dune-project is missing" cram_dir
                  rule_code
                :: !errors;
          if (not dune_exists) && not has_subdirs then
            errors :=
              Fmt.str "Error: %s/%s.t/dune is missing" cram_dir rule_code
              :: !errors))
    defined_rules

(* Check 6: Parse run.t files to verify expected behavior *)
let check_expected_outputs cram_dir defined_rules test_dirs errors =
  Fmt.pr "\nChecking expected test outputs...@.";
  List.iter
    (fun rule_code ->
      if List.mem rule_code test_dirs then
        let test_outputs = check_run_t_output cram_dir rule_code in
        (* Check each test in the run.t file *)
        List.iter
          (fun (test_name, output_lines) ->
            (* Check for dune build failure *)
            (* Only consider it an error if merlint doesn't continue with analysis *)
            let has_dune_error =
              List.exists (fun line -> Re.execp re_dune_error line) output_lines
            in
            let continues_with_analysis =
              List.exists (fun line -> Re.execp re_continuing line) output_lines
            in
            if has_dune_error && not continues_with_analysis then
              errors :=
                Fmt.str
                  "Error: %s/%s.t/run.t: %s.ml test shows Dune build failure"
                  cram_dir rule_code test_name
                :: !errors
            else if test_name = "bad" then
              (* bad.ml should exit with code [1] *)
              let has_exit_1 =
                List.exists (fun line -> Re.execp re_exit_1 line) output_lines
              in
              if not has_exit_1 then
                errors :=
                  Fmt.str
                    "Error: %s/%s.t/run.t: bad.ml test doesn't show exit code \
                     [1] - should find issues"
                    cram_dir rule_code
                  :: !errors
              else if test_name = "good" then
                (* good.ml should be successful (no exit code [1] at the end) *)
                let has_exit_1 =
                  List.exists (fun line -> Re.execp re_exit_1 line) output_lines
                in
                (* Check if it shows all checks passed for the specific rule *)
                let shows_zero_issues =
                  List.exists
                    (fun line -> Re.execp re_zero_issues line)
                    output_lines
                in
                if has_exit_1 && shows_zero_issues then
                  errors :=
                    Fmt.str
                      "Error: %s/%s.t/run.t: good.ml test shows exit [1] but \
                       claims 0 issues"
                      cram_dir rule_code
                    :: !errors)
          test_outputs)
    defined_rules

(* Report results and exit *)
let report_results errors =
  if !errors = [] then (
    Fmt.pr "✓ Test integrity check passed!@.";
    exit 0)
  else (
    Fmt.pr "\n✗ Test integrity check failed:\n@.";
    List.iter (fun e -> Fmt.pr "  %s@." e) (List.rev !errors);
    Fmt.pr "\nPlease fix these issues before proceeding.@.";
    exit 1)

let main () =
  let cram_dir = "test/cram" in
  let errors = ref [] in

  (* Get all defined rules and test directories *)
  let defined_rules = get_all_error_codes () in
  let test_dirs = get_test_directories cram_dir in

  Fmt.pr "Checking test integrity...@.";
  Fmt.pr "Found %d defined rules@." (List.length defined_rules);
  Fmt.pr "Found %d test directories@." (List.length test_dirs);

  (* Check 1: Every rule must have a test directory *)
  check_missing_test_dirs cram_dir defined_rules test_dirs errors;

  (* Check 2: Every test directory must correspond to a defined rule *)
  check_undefined_rules cram_dir defined_rules test_dirs errors;

  (* Check 3: Every test directory must have bad.ml, good.ml, run.t, dune-project, and dune *)
  check_test_directory_structure cram_dir defined_rules test_dirs errors;

  (* Check 6: Parse run.t files to verify expected behavior *)
  check_expected_outputs cram_dir defined_rules test_dirs errors;

  (* Report results *)
  report_results errors

let () = main ()
