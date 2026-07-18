(** E705: Missing Fuzz MLI File *)

type payload = { filename : string; module_name : string }

(** Check if a fuzz_*.mli file exports only suite with correct type. *)
let is_in_private_library ctx index filename =
  ignore ctx;
  File.is_in_private_library_path index (Context.fpath_of_path filename)

let check_fuzz_mli_file ctx index filename view =
  let fp = Context.fpath_of_path filename in
  let filename_s = Context.string_of_path filename in
  let basename = Path.basename filename in
  if
    Path.has_ext ".mli" filename
    && String.starts_with ~prefix:"fuzz_" basename
    && File.is_in_fuzz_dir fp
    && (not (is_in_private_library ctx index filename))
    && not (File.is_in_examples filename_s)
  then
    match
      Suite.is_compliant_view ~expected:"string * Alcobar.test_case list" view
    with
    (* Unresolved: no typedtree, so the suite type could not be read at all --
       not evidence the interface is wrong. *)
    | Suite.Unresolved | Suite.Resolved true -> []
    | Suite.Resolved false ->
        [
          Issue.v
            ~loc:
              (Location.v ~file:filename_s ~start_line:1 ~start_col:0
                 ~end_line:1 ~end_col:0)
            {
              filename = filename_s;
              module_name = basename |> Filename.chop_extension;
            };
        ]
  else []

(** Check if fuzz_*.ml files have corresponding .mli files. *)
let check_missing_fuzz_mli ctx index files =
  let root = Context.project_root_path ctx in
  List.filter_map
    (fun ml_file ->
      let fp = Context.fpath_of_path ml_file in
      let ml_file_s = Context.string_of_path ml_file in
      if Path.has_ext ".ml" ml_file then
        let basename = Path.basename ml_file in
        if
          String.starts_with ~prefix:"fuzz_" basename
          && File.is_in_fuzz_dir fp
          && (not (is_in_private_library ctx index ml_file))
          && not (File.is_in_examples ml_file_s)
        then
          let mli_path = Path.(ml_file |> rem_ext |> add_ext ".mli") in
          if
            Build.source_status ~root ~index (Context.fpath_of_path mli_path)
            = Build.Missing
          then
            let loc =
              Location.v ~file:ml_file_s ~start_line:1 ~start_col:0 ~end_line:1
                ~end_col:0
            in
            Some
              (Issue.v ~loc
                 {
                   filename = ml_file_s;
                   module_name = basename |> Filename.chop_extension;
                 })
          else None
        else None
      else None)
    files

let check ctx =
  let files = Context.analyze_set ctx in
  let index = Context.index ctx in
  let missing_mli_issues = check_missing_fuzz_mli ctx index files in
  let content_issues =
    List.concat_map
      (fun filename ->
        if Path.has_ext ".mli" filename then
          try
            let view = Context.file_view ctx filename in
            check_fuzz_mli_file ctx index filename view
          with
          | File_view.Analysis_error _ -> []
          | CamlinternalLazy.Undefined -> []
        else [])
      files
  in
  missing_mli_issues @ content_issues

let pp ppf { filename; module_name = _ } =
  if File_kind.is_mli filename then
    Fmt.pf ppf
      "Fuzz module interface should only export 'suite' with type string * \
       Alcobar.test_case list"
  else
    Fmt.pf ppf "Fuzz module %s is missing interface file %s" filename
      (Filename.remove_extension filename ^ ".mli")

let rule =
  Rule.v ~code:"E705" ~title:"Missing Fuzz MLI File" ~category:Testing
    ~hint:
      "Fuzz modules (fuzz_*.ml) should have corresponding .mli files that \
       export only 'suite : string * Alcobar.test_case list'. This enforces \
       proper encapsulation of fuzz test internals."
    ~examples:[] ~pp (Project check)
