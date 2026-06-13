(** E718: Non-Fuzz File in Fuzz Directory *)

type payload = {
  directory : string;
  kind :
    [ `naming of string * string | `missing_gen_corpus | `missing_fuzz_runner ];
}

let is_valid basename =
  String.starts_with ~prefix:"fuzz_" basename || String.equal basename "fuzz"

let is_ml_fuzz_file file =
  Path.has_ext ".ml" file && File.is_in_fuzz_dir (Context.fpath_of_path file)

(** Collect all stanzas with files in fuzz/ directories from both test and
    executable stanzas. *)
let fuzz_stanzas ctx =
  Context.test_stanzas ctx @ Context.executable_stanzas ctx
  |> List.filter_map (fun (stanza : Project_index.source_stanza) ->
      let fuzz_files =
        stanza.files
        |> List.map (Context.resolve ctx)
        |> List.filter is_ml_fuzz_file
      in
      match fuzz_files with [] -> None | _ -> Some (stanza.name, fuzz_files))

let naming_issue stanza_name file =
  let basename = Path.(file |> rem_ext |> basename) in
  if is_valid basename then None
  else
    let dir = Path.parent file in
    let loc =
      Location.v
        ~file:(Context.string_of_path file)
        ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    in
    Some
      (Issue.v ~loc
         {
           directory = Path.dir_display dir;
           kind = `naming (stanza_name, Context.string_of_path file);
         })

let naming_issues stanzas =
  List.concat_map
    (fun (stanza_name, files) ->
      List.filter_map (naming_issue stanza_name) files)
    stanzas

let dir_files all_files dir =
  List.filter (fun f -> Path.compare (Path.parent f) dir = 0) all_files

let has_module name files =
  List.exists (fun f -> Path.(f |> rem_ext |> basename) = name) files

let has_fuzz_modules files =
  List.exists
    (fun f ->
      String.starts_with ~prefix:"fuzz_" Path.(f |> rem_ext |> basename))
    files

let dune_has_gen_corpus ctx dir =
  try
    let content = Context.file_content ctx Path.(dir / "dune") in
    match Dune.File.of_string content with
    | Error _ -> false
    | Ok dune ->
        Dune.File.rules dune
        |> List.exists (fun rule ->
            Dune.File.Rule.run_actions rule
            |> List.exists (List.exists (( = ) "--gen-corpus")))
  with File_view.Analysis_error _ -> false

let dir_issue dir kind =
  let loc =
    Location.v
      ~file:(Context.string_of_path Path.(dir / "dune"))
      ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
  in
  Issue.v ~loc { directory = Path.dir_display dir; kind }

let missing_issues_for_dir ctx all_files dir =
  let files = dir_files all_files dir in
  let issues = [] in
  let issues =
    if dune_has_gen_corpus ctx dir then issues
    else dir_issue dir `missing_gen_corpus :: issues
  in
  let issues =
    if has_fuzz_modules files && not (has_module "fuzz" files) then
      dir_issue dir `missing_fuzz_runner :: issues
    else issues
  in
  List.rev issues

let missing_issues ctx stanzas =
  let all_files = List.concat_map snd stanzas in
  all_files |> List.map Path.parent
  |> List.sort_uniq Path.compare
  |> List.concat_map (missing_issues_for_dir ctx all_files)

let check (ctx : Context.project) =
  let stanzas = fuzz_stanzas ctx in
  naming_issues stanzas @ missing_issues ctx stanzas

let pp ppf { directory; kind } =
  match kind with
  | `naming (stanza_name, filename) ->
      let basename = Filename.basename filename in
      let modname = Filename.chop_extension basename in
      Fmt.pf ppf
        "File '%s' in fuzz stanza '%s' does not follow the fuzz_ naming \
         convention - rename to fuzz_%s.ml"
        basename stanza_name modname
  | `missing_gen_corpus ->
      Fmt.pf ppf "Fuzz directory '%s' is missing --gen-corpus in fuzz dune rule"
        directory
  | `missing_fuzz_runner ->
      Fmt.pf ppf
        "Fuzz directory '%s' has fuzz_* modules but is missing fuzz.ml runner"
        directory

let rule =
  Rule.v ~code:"E718" ~title:"Non-Fuzz File in Fuzz Directory" ~category:Testing
    ~hint:
      "All .ml files in a fuzz/ directory should follow the fuzz_ naming \
       convention (e.g., fuzz_parser.ml) or be the fuzz runner (fuzz.ml). Each \
       fuzz directory must use fuzz.exe --gen-corpus in its dune rule."
    ~examples:[] ~pp (Project check)
