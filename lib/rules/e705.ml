(** E705: Missing Fuzz MLI File *)

type payload = { filename : string; module_name : string }

let val_suite_re =
  Re.compile
    (Re.seq
       [
         Re.bow;
         Re.str "val";
         Re.rep1 Re.space;
         Re.str "suite";
         Re.rep Re.space;
         Re.str ":";
       ])

let val_re = Re.compile (Re.seq [ Re.bow; Re.str "val"; Re.rep1 Re.space ])
let whitespace_re = Re.compile (Re.rep1 Re.space)

let non_comment_lines content =
  String.split_on_char '\n' content
  |> List.filter (fun line ->
      let trimmed = String.trim line in
      trimmed <> "" && not (String.starts_with ~prefix:"(*" trimmed))

(** Check if a fuzz_*.mli file exports only suite with correct type. *)
let check_fuzz_mli_file dune_describe filename content =
  let basename = Filename.basename filename in
  if
    String.ends_with ~suffix:".mli" basename
    && String.starts_with ~prefix:"fuzz_" basename
    && File.is_in_fuzz_dir (Fpath.v filename)
    && (not (File.is_in_private_library dune_describe filename))
    && not (File.is_in_examples filename)
  then
    let lines = non_comment_lines content in
    let suite_line =
      List.find_opt (fun line -> Re.execp val_suite_re line) lines
    in
    let exports_suite = Option.is_some suite_line in
    let has_correct_type =
      match suite_line with
      | Some line ->
          let normalized =
            Re.replace_string whitespace_re ~by:" " line |> String.trim
          in
          String.ends_with ~suffix:"string * Alcobar.test_case list" normalized
      | None -> true
    in
    let exports_other =
      List.exists
        (fun line -> Re.execp val_re line && not (Re.execp val_suite_re line))
        lines
    in
    if exports_other || (not exports_suite) || not has_correct_type then
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          { filename; module_name = basename |> Filename.chop_extension };
      ]
    else []
  else []

(** Check if fuzz_*.ml files have corresponding .mli files. *)
let check_missing_fuzz_mli dune_describe files =
  List.filter_map
    (fun ml_file ->
      if String.ends_with ~suffix:".ml" ml_file then
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
  let files = Context.all_files ctx in
  let dune_describe = Context.dune_describe ctx in
  let missing_mli_issues = check_missing_fuzz_mli dune_describe files in
  let content_issues =
    List.concat_map
      (fun filename ->
        if String.ends_with ~suffix:".mli" filename then
          try
            let content =
              In_channel.with_open_text filename In_channel.input_all
            in
            check_fuzz_mli_file dune_describe filename content
          with Sys_error _ -> []
        else [])
      files
  in
  missing_mli_issues @ content_issues

let pp ppf { filename; module_name = _ } =
  if String.ends_with ~suffix:".mli" filename then
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
