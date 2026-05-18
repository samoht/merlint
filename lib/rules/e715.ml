(** E715: Fuzz Module Not Included *)

module Issue_location = Location

type payload = { fuzz_module : string; fuzz_runner_file : string }

let log_src = Logs.Src.create "merlint.rules.e715" ~doc:"E715 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

let fuzz_modules runner_file fuzz_files =
  List.filter_map
    (fun f ->
      if f = runner_file then None
      else
        let basename = Fpath.(f |> rem_ext |> basename) in
        if String.starts_with ~prefix:"fuzz_" basename then Some basename
        else None)
    fuzz_files

let module_in_runner view fuzz_mod =
  Suite.references view (String.capitalize_ascii fuzz_mod)

let missing_include_issue runner_file fuzz_mod =
  let loc =
    Issue_location.v
      ~file:(Fpath.to_string runner_file)
      ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
  in
  Issue.v ~loc
    { fuzz_module = fuzz_mod; fuzz_runner_file = Fpath.to_string runner_file }

let check_stanza ctx stanza_name files =
  let fuzz_files =
    List.filter (fun f -> Fpath.has_ext ".ml" f && File.is_in_fuzz_dir f) files
  in
  match
    List.find_opt
      (fun f -> Fpath.(f |> rem_ext |> basename) = "fuzz")
      fuzz_files
  with
  | None -> []
  | Some runner_file -> (
      try
        let view = Context.file_view ctx (Fpath.to_string runner_file) in
        let modules = fuzz_modules runner_file fuzz_files in
        Log.debug (fun m ->
            m "E715: stanza '%s' has %d fuzz modules" stanza_name
              (List.length modules));
        modules
        |> List.filter (fun fuzz_mod -> not (module_in_runner view fuzz_mod))
        |> List.map (missing_include_issue runner_file)
      with File_view.Analysis_error _ -> [])

(** Check if fuzz.ml includes all fuzz modules via Fuzz_*.suite *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let test_issues =
    Dune_describe.tests dune_describe
    |> List.concat_map (fun (t : Dune_describe.test_info) ->
        check_stanza ctx t.name t.files)
  in
  let executable_issues =
    Dune_describe.executables dune_describe
    |> List.concat_map (fun (name, files) -> check_stanza ctx name files)
  in
  test_issues @ executable_issues

let pp ppf { fuzz_module; fuzz_runner_file } =
  Fmt.pf ppf "Fuzz module %s is not included in %s" fuzz_module fuzz_runner_file

let rule =
  Rule.v ~code:"E715" ~title:"Fuzz Module Not Included" ~category:Testing
    ~hint:
      "All fuzz modules should be included in the fuzz runner (fuzz.ml) via \
       Fuzz_*.suite references. This ensures all fuzz tests are actually \
       executed."
    ~examples:[] ~pp (Project check)
