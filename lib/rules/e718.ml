(** E718: Non-Fuzz File in Fuzz Directory *)

type payload = {
  directory : string;
  kind :
    [ `naming of string * string | `missing_gen_corpus | `missing_fuzz_runner ];
}

let is_valid basename =
  String.starts_with ~prefix:"fuzz_" basename || String.equal basename "fuzz"

(** Collect all stanzas with files in fuzz/ directories from both test and
    executable stanzas. *)
let fuzz_stanzas dune_describe =
  let from_tests =
    List.filter_map
      (fun (t : Dune.test_info) ->
        let fuzz_files =
          List.filter
            (fun f -> Fpath.has_ext ".ml" f && File.is_in_fuzz_dir f)
            t.files
        in
        match fuzz_files with [] -> None | _ -> Some (t.name, fuzz_files))
      (Dune.tests dune_describe)
  in
  let from_execs =
    List.filter_map
      (fun (name, files) ->
        let fuzz_files =
          List.filter
            (fun f -> Fpath.has_ext ".ml" f && File.is_in_fuzz_dir f)
            files
        in
        match fuzz_files with [] -> None | _ -> Some (name, fuzz_files))
      (Dune.executables dune_describe)
  in
  from_tests @ from_execs

let naming_issue stanza_name file =
  let basename = Fpath.(file |> rem_ext |> basename) in
  if is_valid basename then None
  else
    let dir = Fpath.parent file |> Fpath.to_string in
    let loc =
      Location.v ~file:(Fpath.to_string file) ~start_line:1 ~start_col:0
        ~end_line:1 ~end_col:0
    in
    Some
      (Issue.v ~loc
         { directory = dir; kind = `naming (stanza_name, Fpath.to_string file) })

let naming_issues stanzas =
  List.concat_map
    (fun (stanza_name, files) ->
      List.filter_map (naming_issue stanza_name) files)
    stanzas

let dir_files all_files dir =
  List.filter (fun f -> Fpath.parent f |> Fpath.to_string = dir) all_files

let has_module name files =
  List.exists (fun f -> Fpath.(f |> rem_ext |> basename) = name) files

let has_fuzz_modules files =
  List.exists
    (fun f ->
      String.starts_with ~prefix:"fuzz_" Fpath.(f |> rem_ext |> basename))
    files

let dune_has_gen_corpus dir =
  try
    let content =
      In_channel.with_open_text
        (Filename.concat dir "dune")
        In_channel.input_all
    in
    Re.execp (Re.compile (Re.str "--gen-corpus")) content
  with Sys_error _ -> false

let dir_issue dir kind =
  let dune_file = Filename.concat dir "dune" in
  let loc =
    Location.v ~file:dune_file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
  in
  Issue.v ~loc { directory = dir; kind }

let missing_issues_for_dir all_files dir =
  let files = dir_files all_files dir in
  let issues = [] in
  let issues =
    if dune_has_gen_corpus dir then issues
    else dir_issue dir `missing_gen_corpus :: issues
  in
  let issues =
    if has_fuzz_modules files && not (has_module "fuzz" files) then
      dir_issue dir `missing_fuzz_runner :: issues
    else issues
  in
  List.rev issues

let missing_issues stanzas =
  let all_files = List.concat_map snd stanzas in
  all_files
  |> List.map (fun f -> Fpath.parent f |> Fpath.to_string)
  |> List.sort_uniq String.compare
  |> List.concat_map (missing_issues_for_dir all_files)

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let stanzas = fuzz_stanzas dune_describe in
  naming_issues stanzas @ missing_issues stanzas

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
