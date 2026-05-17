(** E705: Missing Fuzz MLI File *)

type payload = { filename : string; module_name : string }

(** Check if a fuzz_*.mli file exports only suite with correct type. *)
let check_fuzz_mli_file dune_describe filename view =
  let basename = Filename.basename filename in
  if
    File_kind.is_mli basename
    && String.starts_with ~prefix:"fuzz_" basename
    && File.is_in_fuzz_dir (Fpath.v filename)
    && (not (File.is_in_private_library dune_describe filename))
    && not (File.is_in_examples filename)
  then
    if
      Suite_mli.is_compliant_view ~expected:"string * Alcobar.test_case list"
        view
    then []
    else
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          { filename; module_name = basename |> Filename.chop_extension };
      ]
  else []

(** Check if fuzz_*.ml files have corresponding .mli files. *)
let check_missing_fuzz_mli dune_describe files =
  List.filter_map
    (fun ml_file ->
      if File_kind.is_ml ml_file then
        let fp = Fpath.v ml_file in
        let basename = Filename.basename ml_file in
        if
          String.starts_with ~prefix:"fuzz_" basename
          && File.is_in_fuzz_dir fp
          && (not (File.is_in_private_library dune_describe ml_file))
          && not (File.is_in_examples ml_file)
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

let check ctx =
  let files = Context.files_to_analyze ctx in
  let dune_describe = Context.dune_describe ctx in
  let missing_mli_issues = check_missing_fuzz_mli dune_describe files in
  let content_issues =
    List.concat_map
      (fun filename ->
        if File_kind.is_mli filename then
          try
            let view = Context.file_view ctx filename in
            check_fuzz_mli_file dune_describe filename view
          with File_view.Analysis_error _ -> []
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
