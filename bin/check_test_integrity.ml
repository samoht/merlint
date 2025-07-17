open Printf

let string_contains s sub = Re.execp (Re.compile (Re.str sub)) s

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
  let dune_project_exists = Sys.file_exists dune_project_file in
  let dune_exists = Sys.file_exists dune_file in
  (bad_exists, good_exists, run_exists, dune_project_exists, dune_exists)

(* Check if run.t file uses correct -r flag format *)
let check_run_t_format cram_dir error_code =
  let test_dir = Filename.concat cram_dir (error_code ^ ".t") in
  let run_file = Filename.concat test_dir "run.t" in
  let rule_code = String.uppercase_ascii error_code in

  if Sys.file_exists run_file then
    let ic = open_in run_file in
    let rec check_lines has_bad_test has_good_test wrong_formats =
      try
        let line = input_line ic in
        let new_wrong_formats =
          if
            String.contains line '$'
            && string_contains line "merlint"
            && string_contains line "-r"
          then
            (* Check if it's using the correct format: -r E### *)
            let parts = String.split_on_char ' ' (String.trim line) in
            let rec check_r_flag = function
              | "-r" :: next :: _ ->
                  if next <> rule_code then
                    Some
                      (sprintf "Line uses '-r %s' instead of '-r %s'" next
                         rule_code)
                  else None
              | _ :: rest -> check_r_flag rest
              | [] -> None
            in
            match check_r_flag parts with
            | Some err -> err :: wrong_formats
            | None -> wrong_formats
          else wrong_formats
        in
        let has_bad =
          has_bad_test
          || String.contains line '$'
             && string_contains line "merlint"
             && string_contains line "-r"
             && string_contains line rule_code
             && (string_contains line "bad.ml" || string_contains line "bad/")
        in
        let has_good =
          has_good_test
          || String.contains line '$'
             && string_contains line "merlint"
             && string_contains line "-r"
             && string_contains line rule_code
             && (string_contains line "good.ml" || string_contains line "good/")
        in
        check_lines has_bad has_good new_wrong_formats
      with End_of_file ->
        close_in ic;
        (has_bad_test, has_good_test, List.rev wrong_formats)
    in
    check_lines false false []
  else (false, false, [])

(* Parse run.t file to check expected output *)
let check_run_t_output cram_dir error_code =
  let test_dir = Filename.concat cram_dir (error_code ^ ".t") in
  let run_file = Filename.concat test_dir "run.t" in

  if Sys.file_exists run_file then
    let ic = open_in run_file in
    let rec parse_test current_test in_output output_lines acc =
      try
        let line = input_line ic in
        if String.starts_with ~prefix:"  $ merlint" line then
          (* Start of a new test *)
          let test_name =
            if string_contains line "bad.ml" || string_contains line "bad/" then
              "bad"
            else if
              string_contains line "good.ml" || string_contains line "good/"
            then "good"
            else ""
          in
          (* Process previous test if any *)
          let new_acc =
            if current_test <> "" && output_lines <> [] then
              (current_test, List.rev output_lines) :: acc
            else acc
          in
          parse_test test_name true [] new_acc
        else if in_output && String.starts_with ~prefix:"  " line then
          (* Part of the output *)
          parse_test current_test true (line :: output_lines) acc
        else
          (* End of output or other content *)
          let new_acc =
            if current_test <> "" && output_lines <> [] then
              (current_test, List.rev output_lines) :: acc
            else acc
          in
          parse_test "" false [] new_acc
      with End_of_file ->
        close_in ic;
        let final_acc =
          if current_test <> "" && output_lines <> [] then
            (current_test, List.rev output_lines) :: acc
          else acc
        in
        List.rev final_acc
    in
    parse_test "" false [] []
  else []

let main () =
  let cram_dir = "test/cram" in
  let errors = ref [] in

  (* Get all defined rules and test directories *)
  let defined_rules = get_all_error_codes () in
  let test_dirs = get_test_directories cram_dir in

  printf "Checking test integrity...\n";
  printf "Found %d defined rules\n" (List.length defined_rules);
  printf "Found %d test directories\n" (List.length test_dirs);

  (* Check 1: Every rule must have a test directory *)
  List.iter
    (fun rule_code ->
      if not (List.mem rule_code test_dirs) then
        errors :=
          sprintf
            "Error: Rule %s is defined but missing test directory at %s/%s.t/"
            (String.uppercase_ascii rule_code)
            cram_dir rule_code
          :: !errors)
    defined_rules;

  (* Check 2: Every test directory must correspond to a defined rule *)
  List.iter
    (fun test_code ->
      if not (List.mem test_code defined_rules) then
        errors :=
          sprintf
            "Error: Test directory %s/%s.t/ exists but rule %s is not defined"
            cram_dir test_code
            (String.uppercase_ascii test_code)
          :: !errors)
    test_dirs;

  (* Check 3: Every test directory must have bad.ml, good.ml, run.t, dune-project, and dune *)
  List.iter
    (fun rule_code ->
      if List.mem rule_code test_dirs then (
        let ( bad_exists,
              good_exists,
              run_exists,
              dune_project_exists,
              dune_exists ) =
          check_test_files cram_dir rule_code
        in
        if not bad_exists then
          errors :=
            sprintf "Error: %s/%s.t/bad.ml is missing" cram_dir rule_code
            :: !errors;
        if not good_exists then
          errors :=
            sprintf "Error: %s/%s.t/good.ml is missing" cram_dir rule_code
            :: !errors;
        (if not run_exists then
           errors :=
             sprintf "Error: %s/%s.t/run.t is missing" cram_dir rule_code
             :: !errors
         else
           (* Check 4: run.t must use correct -r flag format *)
           let has_bad_test, has_good_test, wrong_formats =
             check_run_t_format cram_dir rule_code
           in
           if not has_bad_test then
             errors :=
               sprintf
                 "Error: %s/%s.t/run.t doesn't test 'merlint -r %s bad.ml'"
                 cram_dir rule_code
                 (String.uppercase_ascii rule_code)
               :: !errors;
           if not has_good_test then
             errors :=
               sprintf
                 "Error: %s/%s.t/run.t doesn't test 'merlint -r %s good.ml'"
                 cram_dir rule_code
                 (String.uppercase_ascii rule_code)
               :: !errors;
           (* Report any wrong -r flag usage *)
           List.iter
             (fun msg ->
               errors :=
                 sprintf "Error: %s/%s.t/run.t: %s" cram_dir rule_code msg
                 :: !errors)
             wrong_formats);
        (* Check 5: test directories SHOULD have dune-project and dune files *)
        if not dune_project_exists then
          errors :=
            sprintf "Error: %s/%s.t/dune-project is missing" cram_dir rule_code
            :: !errors;
        if not dune_exists then
          errors :=
            sprintf "Error: %s/%s.t/dune is missing" cram_dir rule_code
            :: !errors))
    defined_rules;

  (* Check 6: Parse run.t files to verify expected behavior *)
  printf "\nChecking expected test outputs...\n";
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
              List.exists
                (fun line ->
                  string_contains line "ERROR"
                  && string_contains line "Dune build failed")
                output_lines
            in
            let continues_with_analysis =
              List.exists
                (fun line -> string_contains line "Continuing with analysis")
                output_lines
            in

            if has_dune_error && not continues_with_analysis then
              errors :=
                sprintf
                  "Error: %s/%s.t/run.t: %s.ml test shows Dune build failure"
                  cram_dir rule_code test_name
                :: !errors
            else if test_name = "bad" then
              (* bad.ml should exit with code [1] *)
              let has_exit_1 =
                List.exists
                  (fun line -> string_contains line "[1]")
                  output_lines
              in
              if not has_exit_1 then
                errors :=
                  sprintf
                    "Error: %s/%s.t/run.t: bad.ml test doesn't show exit code \
                     [1] - should find issues"
                    cram_dir rule_code
                  :: !errors
              else if test_name = "good" then
                (* good.ml should be successful (no exit code [1] at the end) *)
                let has_exit_1 =
                  List.exists
                    (fun line -> string_contains line "[1]")
                    output_lines
                in
                (* Check if it shows all checks passed for the specific rule *)
                let shows_zero_issues =
                  List.exists
                    (fun line ->
                      string_contains line "✓ 0 total issues"
                      || string_contains line "Summary: ✓ All checks passed")
                    output_lines
                in
                if has_exit_1 && shows_zero_issues then
                  errors :=
                    sprintf
                      "Error: %s/%s.t/run.t: good.ml test shows exit [1] but \
                       claims 0 issues"
                      cram_dir rule_code
                    :: !errors)
          test_outputs)
    defined_rules;

  (* Report results *)
  if !errors = [] then (
    printf "✓ Test integrity check passed!\n";
    exit 0)
  else (
    printf "\n✗ Test integrity check failed:\n\n";
    List.iter (fun e -> printf "  %s\n" e) (List.rev !errors);
    printf "\nPlease fix these issues before proceeding.\n";
    exit 1)

let () = main ()
