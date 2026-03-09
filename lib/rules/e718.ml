(** E718: Non-Fuzz File in Fuzz Directory *)

type payload = {
  directory : string;
  kind :
    [ `naming of string * string | `missing_gen_corpus | `missing_fuzz_runner ];
}

let is_fuzz_dir = File.is_in_fuzz_dir

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
  let missing_issues =
    List.concat_map
      (fun dir ->
        let dir_files =
          List.filter
            (fun f -> Fpath.parent f |> Fpath.to_string = dir)
            all_files
        in
        let has file =
          List.exists
            (fun f -> Fpath.(f |> rem_ext |> basename) = file)
            dir_files
        in
        let has_fuzz_modules =
          List.exists
            (fun f ->
              String.starts_with ~prefix:"fuzz_"
                Fpath.(f |> rem_ext |> basename))
            dir_files
        in
        let issues = ref [] in
        if not (has "gen_corpus") then
          issues :=
            Issue.v
              ~loc:
                (Location.v
                   ~file:(Filename.concat dir "dune")
                   ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0)
              { directory = dir; kind = `missing_gen_corpus }
            :: !issues;
        if has_fuzz_modules && not (has "fuzz") then
          issues :=
            Issue.v
              ~loc:
                (Location.v
                   ~file:(Filename.concat dir "dune")
                   ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0)
              { directory = dir; kind = `missing_fuzz_runner }
            :: !issues;
        List.rev !issues)
      fuzz_dirs
  in
  naming_issues @ missing_issues

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
  | `missing_fuzz_runner ->
      Fmt.pf ppf
        "Fuzz directory '%s' has fuzz_* modules but is missing fuzz.ml runner"
        directory

let rule =
  Rule.v ~code:"E718" ~title:"Non-Fuzz File in Fuzz Directory" ~category:Testing
    ~hint:
      "All .ml files in a fuzz/ directory should follow the fuzz_ naming \
       convention (e.g., fuzz_parser.ml), be the fuzz runner (fuzz.ml), or the \
       corpus generator (gen_corpus.ml). Each fuzz directory must have a \
       gen_corpus.ml."
    ~examples:[] ~pp (Project check)
