(** E718: Non-Fuzz File in Fuzz Directory *)

type payload = {
  filename : string;
  stanza_name : string;
  kind : [ `naming | `missing_runner ];
}

let is_fuzz_dir file =
  let dir = Fpath.parent file |> Fpath.basename in
  String.equal dir "fuzz"

let is_valid basename =
  String.starts_with ~prefix:"fuzz_" basename || String.equal basename "fuzz"

(** Collect all fuzz stanzas from both test and executable stanzas. *)
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
              let loc =
                Location.v ~file:(Fpath.to_string file) ~start_line:1
                  ~start_col:0 ~end_line:1 ~end_col:0
              in
              Some
                (Issue.v ~loc
                   {
                     filename = Fpath.to_string file;
                     stanza_name;
                     kind = `naming;
                   })
            else None)
          files)
      stanzas
  in
  let runner_issues =
    List.filter_map
      (fun (stanza_name, files) ->
        let has_runner =
          List.exists
            (fun f ->
              let basename = Fpath.(f |> rem_ext |> basename) in
              String.equal basename "fuzz")
            files
        in
        if not has_runner then
          let file = List.hd files in
          let dir = Fpath.parent file |> Fpath.to_string in
          let loc =
            Location.v
              ~file:(Filename.concat dir "dune")
              ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
          in
          Some
            (Issue.v ~loc
               { filename = dir; stanza_name; kind = `missing_runner })
        else None)
      stanzas
  in
  naming_issues @ runner_issues

let pp ppf { filename; stanza_name; kind } =
  match kind with
  | `naming ->
      let basename = Filename.basename filename in
      let modname = Filename.chop_extension basename in
      Fmt.pf ppf
        "File '%s' in fuzz stanza '%s' does not follow the fuzz_ naming \
         convention - rename to fuzz_%s.ml"
        basename stanza_name modname
  | `missing_runner ->
      Fmt.pf ppf "Fuzz directory '%s' (stanza '%s') has no fuzz.ml runner"
        filename stanza_name

let rule =
  Rule.v ~code:"E718" ~title:"Non-Fuzz File in Fuzz Directory" ~category:Testing
    ~hint:
      "All .ml files in a fuzz/ directory should follow the fuzz_ naming \
       convention (e.g., fuzz_parser.ml) or be the fuzz runner (fuzz.ml). Each \
       fuzz/ directory must have a fuzz.ml runner."
    ~examples:[] ~pp (Project check)
