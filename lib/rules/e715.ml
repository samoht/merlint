(** E715: Fuzz Module Not Included *)

module Issue_location = Location

type payload = { module_ : string; runner_file : string }

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

let missing_include_issue runner_file fuzz_mod =
  let loc =
    Issue_location.v
      ~file:(Fpath.to_string runner_file)
      ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
  in
  Issue.v ~loc { module_ = fuzz_mod; runner_file = Fpath.to_string runner_file }

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
        let view = Context.file_view ctx (Context.resolve ctx runner_file) in
        let modules = fuzz_modules runner_file fuzz_files in
        Log.debug (fun m ->
            m "E715: stanza '%s' has %d fuzz modules" stanza_name
              (List.length modules));
        List.filter_map
          (fun fuzz_mod ->
            match Suite.references view (String.capitalize_ascii fuzz_mod) with
            | Suite.Unresolved | Suite.Resolved true ->
                (* Unresolved: the runner's typedtree is not built, so we cannot
                   see its references -- skip rather than flag every module. *)
                None
            | Suite.Resolved false ->
                Some (missing_include_issue runner_file fuzz_mod))
          modules
      with File_view.Analysis_error _ -> [])

(** Check if fuzz.ml includes all fuzz modules via Fuzz_*.suite *)
let check (ctx : Context.project) =
  let test_issues =
    Context.test_stanzas ctx
    |> List.concat_map (fun (t : Project_index.source_stanza) ->
        check_stanza ctx t.name t.files)
  in
  let executable_issues =
    Context.executable_stanzas ctx
    |> List.concat_map (fun (exe : Project_index.source_stanza) ->
        check_stanza ctx exe.name exe.files)
  in
  test_issues @ executable_issues

let pp ppf { module_; runner_file } =
  Fmt.pf ppf "Fuzz module %s is not included in %s" module_ runner_file

let rule =
  Rule.v ~code:"E715" ~title:"Fuzz Module Not Included" ~category:Testing
    ~hint:
      "All fuzz modules should be included in the fuzz runner (fuzz.ml) via \
       Fuzz_*.suite references. This ensures all fuzz tests are actually \
       executed."
    ~examples:[] ~pp (Project check)
