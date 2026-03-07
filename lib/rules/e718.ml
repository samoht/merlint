(** E718: Non-Fuzz File in Fuzz Directory *)

type payload = {
  directory : string;
  kind : [ `naming of string * string | `missing_gen_corpus ];
}

let is_fuzz_dir file =
  let dir = Fpath.parent file |> Fpath.basename in
  String.equal dir "fuzz"

let is_valid basename =
  String.starts_with ~prefix:"fuzz_" basename
  || String.equal basename "fuzz"
  || String.equal basename "gen_corpus"

(** Collect all stanzas with files in fuzz/ directories from both test and
    executable stanzas. *)
let fuzz_stanzas dune_describe =
  let from_tests =
    List.filter_map
      (fun (t : Dune.test_info) ->
        let fuzz_files =
          List.filter (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f) t.files
        in
        match fuzz_files with [] -> None | _ -> Some (t.name, fuzz_files))
      (Dune.tests dune_describe)
  in
  let from_execs =
    List.filter_map
      (fun (name, files) ->
        let fuzz_files =
          List.filter (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f) files
        in
        match fuzz_files with [] -> None | _ -> Some (name, fuzz_files))
      (Dune.executables dune_describe)
  in
  from_tests @ from_execs

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let stanzas = fuzz_stanzas dune_describe in
  let naming_issues =
    List.concat_map
      (fun (stanza_name, files) ->
        List.filter_map
          (fun file ->
            let basename = Fpath.(file |> rem_ext |> basename) in
            if not (is_valid basename) then
              let dir = Fpath.parent file |> Fpath.to_string in
              let loc =
                Location.v ~file:(Fpath.to_string file) ~start_line:1
                  ~start_col:0 ~end_line:1 ~end_col:0
              in
              Some
                (Issue.v ~loc
                   {
                     directory = dir;
                     kind = `naming (stanza_name, Fpath.to_string file);
                   })
            else None)
          files)
      stanzas
  in
  (* Check each fuzz directory has a gen_corpus.ml *)
  let all_files = List.concat_map snd stanzas in
  let fuzz_dirs =
    List.map (fun f -> Fpath.parent f |> Fpath.to_string) all_files
    |> List.sort_uniq String.compare
  in
  let gen_corpus_issues =
    List.filter_map
      (fun dir ->
        let has_gen_corpus =
          List.exists
            (fun f ->
              Fpath.parent f |> Fpath.to_string = dir
              && Fpath.(f |> rem_ext |> basename) = "gen_corpus")
            all_files
        in
        if not has_gen_corpus then
          let loc =
            Location.v
              ~file:(Filename.concat dir "dune")
              ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
          in
          Some (Issue.v ~loc { directory = dir; kind = `missing_gen_corpus })
        else None)
      fuzz_dirs
  in
  naming_issues @ gen_corpus_issues

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
      Fmt.pf ppf "Fuzz directory '%s' is missing gen_corpus.ml" directory

let rule =
  Rule.v ~code:"E718" ~title:"Non-Fuzz File in Fuzz Directory" ~category:Testing
    ~hint:
      "All .ml files in a fuzz/ directory should follow the fuzz_ naming \
       convention (e.g., fuzz_parser.ml), be the fuzz runner (fuzz.ml), or the \
       corpus generator (gen_corpus.ml). Each fuzz directory must have a \
       gen_corpus.ml."
    ~examples:[] ~pp (Project check)
