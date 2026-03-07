(** E619: Non-Fuzz File in Fuzz Directory *)

type payload = { filename : string; stanza_name : string; kind : [ `naming | `missing_runner ] }

let is_fuzz_dir file =
  let dir = Fpath.parent file |> Fpath.basename in
  String.equal dir "fuzz"

let is_valid basename =
  String.starts_with ~prefix:"fuzz_" basename || String.equal basename "fuzz"

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let tests = Dune.tests dune_describe in
  (* Check naming convention in fuzz dirs *)
  let naming_issues =
    List.concat_map
      (fun (test_info : Dune.test_info) ->
        List.filter_map
          (fun file ->
            if Fpath.has_ext ".ml" file && is_fuzz_dir file then
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
                       stanza_name = test_info.Dune.name;
                       kind = `naming;
                     })
              else None
            else None)
          test_info.Dune.files)
      tests
  in
  (* Check for missing fuzz.ml runner in fuzz dirs *)
  let fuzz_dirs =
    List.filter_map
      (fun (test_info : Dune.test_info) ->
        let fuzz_files =
          List.filter
            (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f)
            test_info.Dune.files
        in
        match fuzz_files with [] -> None | _ -> Some (test_info, fuzz_files))
      tests
  in
  let runner_issues =
    List.filter_map
      (fun (test_info, files) ->
        let has_runner =
          List.exists
            (fun f ->
              let basename = Fpath.(f |> rem_ext |> basename) in
              String.equal basename "fuzz")
            files
        in
        if not has_runner then
          let file = List.hd files in
          let loc =
            Location.v
              ~file:(Fpath.parent file |> Fpath.to_string |> fun d ->
                     Filename.concat d "dune")
              ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
          in
          Some
            (Issue.v ~loc
               {
                 filename = Fpath.parent file |> Fpath.to_string;
                 stanza_name = test_info.Dune.name;
                 kind = `missing_runner;
               })
        else None)
      fuzz_dirs
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
      Fmt.pf ppf
        "Fuzz directory '%s' (stanza '%s') has no fuzz.ml runner"
        filename stanza_name

let rule =
  Rule.v ~code:"E619" ~title:"Non-Fuzz File in Fuzz Directory" ~category:Testing
    ~hint:
      "All .ml files in a fuzz/ directory should follow the fuzz_ naming \
       convention (e.g., fuzz_parser.ml) or be the fuzz runner (fuzz.ml). \
       Each fuzz/ directory must have a fuzz.ml runner."
    ~examples:[] ~pp (Project check)
