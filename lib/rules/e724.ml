(** E724: Missing Fuzz Build Rules *)

type payload = {
  directory : string;
  kind :
    [ `missing_runtest
    | `missing_fuzz
    | `missing_both
    | `fuzz_missing_corpus
    | `fuzz_missing_gen_corpus
    | `fuzz_missing_afl_profile ];
}

(** Collect fuzz directories from executable stanzas. *)
let fuzz_dirs ctx =
  let dirs =
    List.filter_map
      (fun exe ->
        let name = Project_index.source_stanza_name exe in
        if not (String.starts_with ~prefix:"fuzz" name) then None
        else
          match
            List.find_opt
              (fun f -> Fpath.has_ext ".ml" f && File.is_in_fuzz_dir f)
              (Project_index.source_stanza_files exe)
          with
          | Some f -> Some (Fpath.parent f |> Fpath.to_string)
          | None -> None)
      (Context.executable_stanzas ctx)
  in
  List.sort_uniq String.compare dirs

let issue ~loc dir kind = Issue.v ~loc { directory = dir; kind }

let presence_issues ~loc dir ~has_runtest ~has_fuzz =
  match (has_runtest, has_fuzz) with
  | true, true -> []
  | false, false -> [ issue ~loc dir `missing_both ]
  | false, true -> [ issue ~loc dir `missing_runtest ]
  | true, false -> [ issue ~loc dir `missing_fuzz ]

let fuzz_content_issues ~loc dir dune =
  let fuzz_rule =
    Dune.File.rules dune
    |> List.find_opt (fun rule -> Dune.File.Rule.alias rule = Some "fuzz")
  in
  let run_args =
    match fuzz_rule with
    | None -> []
    | Some rule -> Dune.File.Rule.run_actions rule
  in
  let has_run_arg arg =
    List.exists (fun args -> List.exists (( = ) arg) args) run_args
  in
  let has_run_args args =
    let rec starts_with needle haystack =
      match (needle, haystack) with
      | [], _ -> true
      | x :: xs, y :: ys when x = y -> starts_with xs ys
      | _ -> false
    in
    let rec loop haystack =
      match haystack with
      | [] -> args = []
      | _ :: xs as ys -> starts_with args ys || loop xs
    in
    List.exists loop run_args
  in
  let has_corpus =
    match fuzz_rule with
    | Some rule ->
        Dune.File.Rule.has_source_tree_dep rule "corpus"
        || Dune.File.Rule.has_source_tree_dep rule "input"
        || has_run_args [ "--gen-corpus"; "corpus" ]
    | None -> false
  in
  let has_gen_corpus = has_run_arg "--gen-corpus" in
  let has_afl_profile =
    match fuzz_rule with
    | Some rule -> Dune.File.Rule.enabled_if_profile rule = Some "afl"
    | None -> false
  in
  [
    (has_corpus, `fuzz_missing_corpus);
    (has_gen_corpus, `fuzz_missing_gen_corpus);
    (has_afl_profile, `fuzz_missing_afl_profile);
  ]
  |> List.filter_map (fun (present, kind) ->
      if present then None else Some (issue ~loc dir kind))

let check_dir ctx dir =
  let dune_file = Filename.concat dir "dune" in
  try
    let content = Context.file_content ctx dune_file in
    match Dune.File.of_string content with
    | Error _ -> []
    | Ok dune ->
        let has_runtest = Dune.File.has_rule_alias dune "runtest" in
        let has_fuzz = Dune.File.has_rule_alias dune "fuzz" in
        let loc =
          Location.v ~file:dune_file ~start_line:1 ~start_col:0 ~end_line:1
            ~end_col:0
        in
        let issues = presence_issues ~loc dir ~has_runtest ~has_fuzz in
        if has_fuzz then issues @ fuzz_content_issues ~loc dir dune else issues
  with File_view.Analysis_error _ -> []

(** Check that fuzz dune files contain required rule aliases with proper
    content. *)
let check (ctx : Context.project) =
  List.concat_map (check_dir ctx) (fuzz_dirs ctx)

let pp ppf { directory; kind } =
  match kind with
  | `missing_runtest ->
      Fmt.pf ppf
        "Fuzz directory '%s' is missing (rule (alias runtest) ...) for \
         property-based testing"
        directory
  | `missing_fuzz ->
      Fmt.pf ppf
        "Fuzz directory '%s' is missing (rule (alias fuzz) ...) for AFL \
         campaigns"
        directory
  | `missing_both ->
      Fmt.pf ppf
        "Fuzz directory '%s' is missing both (rule (alias runtest) ...) and \
         (rule (alias fuzz) ...) build rules"
        directory
  | `fuzz_missing_corpus ->
      Fmt.pf ppf
        "Fuzz directory '%s' (alias fuzz) rule should depend on (source_tree \
         corpus) for seed inputs"
        directory
  | `fuzz_missing_gen_corpus ->
      Fmt.pf ppf
        "Fuzz directory '%s' (alias fuzz) rule should use fuzz.exe \
         --gen-corpus to generate seed corpus"
        directory
  | `fuzz_missing_afl_profile ->
      Fmt.pf ppf
        "Fuzz directory '%s' (alias fuzz) rule should use (enabled_if (= \
         %%{profile} afl)) to only run under AFL profile"
        directory

let rule =
  Rule.v ~code:"E724" ~title:"Missing Fuzz Build Rules" ~category:Testing
    ~hint:
      "Each fuzz directory should have (rule (alias runtest) ...) for \
       property-based testing during dune test, and (rule (alias fuzz) ...) \
       using fuzz.exe --gen-corpus for AFL fuzzing campaigns."
    ~examples:[] ~pp (Project check)
