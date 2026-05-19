(** E615: Test Suite Not Included *)

module Issue_location = Location

type payload = { test_module : string; test_runner_file : string }

let log_src = Logs.Src.create "merlint.rules.e615" ~doc:"E615 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

type env = { index : Project_index.t; module_map : (string * string list) list }

(** Determine if a test file should be excluded based on E606 logic *)
let should_exclude_test_file env test_file declared_libraries =
  if declared_libraries = [] then false
  else
    let resolved =
      List.map (Project.Query.resolve_library env.index) declared_libraries
    in
    let basename =
      Filename.remove_extension (Filename.basename (Fpath.to_string test_file))
    in
    match Project.Query.test_file_library env.module_map basename with
    | Some lib -> not (List.mem lib resolved)
    | None -> false

let module_basename f =
  Filename.remove_extension (Filename.basename (Fpath.to_string f))

let test_runner files =
  List.find_opt
    (fun f -> File_kind.is_ml (Fpath.to_string f) && module_basename f = "test")
    files

let all_test_modules test_file files =
  List.filter_map
    (fun f ->
      if File_kind.is_ml (Fpath.to_string f) && f <> test_file then
        let basename = module_basename f in
        if
          String.starts_with ~prefix:"test_" basename
          && not (File.is_unit_companion_module basename)
        then Some (basename, f)
        else None
      else None)
    files

let test_modules env test_stanza test_file =
  let files = Project_index.source_stanza_files test_stanza in
  let libraries = Project_index.source_stanza_libraries test_stanza in
  all_test_modules test_file files
  |> List.filter_map (fun (basename, f) ->
      if should_exclude_test_file env f libraries then (
        Log.debug (fun m ->
            m "E615: Excluding test module '%s' (would be flagged by E606)"
              basename);
        None)
      else Some basename)

let suite_included callers test_mod =
  match callers with
  | None -> false
  | Some c -> Suite.references_in c (String.capitalize_ascii test_mod)

let missing_issue test_file test_mod =
  let loc =
    Issue_location.v
      ~file:(Fpath.to_string test_file)
      ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
  in
  Issue.v ~loc
    { test_module = test_mod; test_runner_file = Fpath.to_string test_file }

let check_test_info ctx env test_stanza =
  let name = Project_index.source_stanza_name test_stanza in
  let files = Project_index.source_stanza_files test_stanza in
  Log.debug (fun m ->
      m "E615: Checking test stanza '%s' with %d files" name (List.length files));
  match test_runner files with
  | None -> []
  | Some test_file -> (
      try
        let view = Context.file_view ctx (Fpath.to_string test_file) in
        if not (File_view.is_resolved view) then []
        else
          let modules = test_modules env test_stanza test_file in
          Log.debug (fun m ->
              m
                "E615: Found %d test modules in stanza '%s' (after E606 \
                 filtering): %a"
                (List.length modules) name
                Fmt.(list ~sep:comma string)
                modules);
          let callers = Suite.callers view in
          modules
          |> List.filter (fun test_mod -> not (suite_included callers test_mod))
          |> List.map (missing_issue test_file)
      with File_view.Analysis_error _ -> [])

let stanza_is_selected ctx stanza =
  Project_index.source_stanza_files stanza
  |> List.exists (fun file -> ctx.Context.in_analyze_set (Fpath.to_string file))

let enumerate ctx =
  let index = Context.index ctx in
  match Context.test_stanzas ctx |> List.filter (stanza_is_selected ctx) with
  | [] -> []
  | test_stanzas ->
      let env = { index; module_map = Project.Query.library_module_map index } in
      List.map (fun test_stanza -> (env, test_stanza)) test_stanzas

let check_unit ctx (env, test_stanza) = check_test_info ctx env test_stanza

let pp ppf { test_module; test_runner_file } =
  Fmt.pf ppf "Test module %s is not included in %s" test_module test_runner_file

let rule =
  Rule.v ~code:"E615" ~title:"Test Suite Not Included" ~category:Testing
    ~hint:
      "All test modules should be included in the main test runner (test.ml). \
       Add the missing test suite to ensure all tests are run."
    ~examples:[] ~pp
    (Project_units { enumerate; check = check_unit })
