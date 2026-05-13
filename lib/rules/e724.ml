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
let fuzz_dirs dune_describe =
  let dirs =
    List.filter_map
      (fun (name, files) ->
        if not (String.starts_with ~prefix:"fuzz" name) then None
        else
          match
            List.find_opt
              (fun f -> Fpath.has_ext ".ml" f && File.is_in_fuzz_dir f)
              files
          with
          | Some f -> Some (Fpath.parent f |> Fpath.to_string)
          | None -> None)
      (Dune_describe.executables dune_describe)
  in
  List.sort_uniq String.compare dirs

let has_alias alias content =
  Re.execp (Re.compile (Fmt.kstr Re.str "(alias %s)" alias)) content

let issue ~loc dir kind = Issue.v ~loc { directory = dir; kind }

let presence_issues ~loc dir ~has_runtest ~has_fuzz =
  match (has_runtest, has_fuzz) with
  | true, true -> []
  | false, false -> [ issue ~loc dir `missing_both ]
  | false, true -> [ issue ~loc dir `missing_runtest ]
  | true, false -> [ issue ~loc dir `missing_fuzz ]

let fuzz_content_issues ~loc dir content =
  let has_corpus =
    Re.execp (Re.compile (Re.str "source_tree corpus")) content
    || Re.execp (Re.compile (Re.str "source_tree input")) content
    || Re.execp (Re.compile (Re.str "--gen-corpus corpus")) content
  in
  let has_gen_corpus = Re.execp (Re.compile (Re.str "--gen-corpus")) content in
  let has_afl_profile =
    Re.execp (Re.compile (Re.str "profile")) content
    && Re.execp (Re.compile (Re.str "afl")) content
  in
  [
    (has_corpus, `fuzz_missing_corpus);
    (has_gen_corpus, `fuzz_missing_gen_corpus);
    (has_afl_profile, `fuzz_missing_afl_profile);
  ]
  |> List.filter_map (fun (present, kind) ->
      if present then None else Some (issue ~loc dir kind))

let check_dir dir =
  let dune_file = Filename.concat dir "dune" in
  try
    let content = In_channel.with_open_text dune_file In_channel.input_all in
    let has_runtest = has_alias "runtest" content in
    let has_fuzz = has_alias "fuzz" content in
    let loc =
      Location.v ~file:dune_file ~start_line:1 ~start_col:0 ~end_line:1
        ~end_col:0
    in
    let issues = presence_issues ~loc dir ~has_runtest ~has_fuzz in
    if has_fuzz then issues @ fuzz_content_issues ~loc dir content else issues
  with Sys_error _ -> []

(** Check that fuzz dune files contain required rule aliases with proper
    content. *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  List.concat_map check_dir (fuzz_dirs dune_describe)

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
