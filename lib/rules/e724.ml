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

let is_fuzz_dir = File.is_in_fuzz_dir

(** Collect fuzz directories from executable stanzas. *)
let fuzz_dirs dune_describe =
  let dirs =
    List.filter_map
      (fun (name, files) ->
        if not (String.starts_with ~prefix:"fuzz" name) then None
        else
          match
            List.find_opt
              (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f)
              files
          with
          | Some f -> Some (Fpath.parent f |> Fpath.to_string)
          | None -> None)
      (Dune.executables dune_describe)
  in
  List.sort_uniq String.compare dirs

(** Check that fuzz dune files contain required rule aliases with proper
    content. *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let dirs = fuzz_dirs dune_describe in
  List.concat_map
    (fun dir ->
      let dune_file = Filename.concat dir "dune" in
      try
        let content =
          In_channel.with_open_text dune_file In_channel.input_all
        in
        let has_runtest =
          Re.execp (Re.compile (Re.str "(alias runtest)")) content
        in
        let has_fuzz = Re.execp (Re.compile (Re.str "(alias fuzz)")) content in
        let loc =
          Location.v ~file:dune_file ~start_line:1 ~start_col:0 ~end_line:1
            ~end_col:0
        in
        let presence_issues =
          match (has_runtest, has_fuzz) with
          | true, true -> []
          | false, false ->
              [ Issue.v ~loc { directory = dir; kind = `missing_both } ]
          | false, true ->
              [ Issue.v ~loc { directory = dir; kind = `missing_runtest } ]
          | true, false ->
              [ Issue.v ~loc { directory = dir; kind = `missing_fuzz } ]
        in
        (* If fuzz alias exists, check it references corpus and gen_corpus *)
        let content_issues =
          if has_fuzz then (
            let has_corpus =
              Re.execp (Re.compile (Re.str "source_tree corpus")) content
              || Re.execp (Re.compile (Re.str "source_tree input")) content
              || Re.execp (Re.compile (Re.str "--gen-corpus corpus")) content
            in
            let has_gen_corpus =
              Re.execp (Re.compile (Re.str "--gen-corpus")) content
            in
            let has_afl_profile =
              Re.execp (Re.compile (Re.str "profile")) content
              && Re.execp (Re.compile (Re.str "afl")) content
            in
            let issues = ref [] in
            if not has_corpus then
              issues :=
                Issue.v ~loc { directory = dir; kind = `fuzz_missing_corpus }
                :: !issues;
            if not has_gen_corpus then
              issues :=
                Issue.v ~loc
                  { directory = dir; kind = `fuzz_missing_gen_corpus }
                :: !issues;
            if not has_afl_profile then
              issues :=
                Issue.v ~loc
                  { directory = dir; kind = `fuzz_missing_afl_profile }
                :: !issues;
            !issues)
          else []
        in
        presence_issues @ content_issues
      with _ -> [])
    dirs

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
