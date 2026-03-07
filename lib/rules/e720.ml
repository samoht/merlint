(** E720: Multiple Fuzz Stanzas in Directory *)

type payload = { directory : string; stanza_names : string list }

let is_fuzz_dir file =
  let dir = Fpath.parent file |> Fpath.basename in
  String.equal dir "fuzz"

(** Collect all stanza names in fuzz/ directories from both test and executable
    stanzas. *)
let fuzz_stanzas_by_dir dune_describe =
  let collect_dirs entries =
    List.filter_map
      (fun (name, files) ->
        match
          List.find_opt (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f) files
        with
        | Some f -> Some (Fpath.parent f |> Fpath.to_string, name)
        | None -> None)
      entries
  in
  let from_tests =
    List.map
      (fun (t : Dune.test_info) -> (t.name, t.files))
      (Dune.tests dune_describe)
    |> collect_dirs
  in
  let from_execs = Dune.executables dune_describe |> collect_dirs in
  from_tests @ from_execs

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let by_dir = fuzz_stanzas_by_dir dune_describe in
  let dirs = List.sort_uniq String.compare (List.map fst by_dir) in
  List.concat_map
    (fun dir ->
      let stanzas =
        List.filter_map
          (fun (d, name) -> if d = dir then Some name else None)
          by_dir
      in
      if List.length stanzas > 1 then
        let loc =
          Location.v
            ~file:(Filename.concat dir "dune")
            ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
        in
        [ Issue.v ~loc { directory = dir; stanza_names = stanzas } ]
      else [])
    dirs

let pp ppf { directory; stanza_names } =
  Fmt.pf ppf
    "Directory '%s' has %d fuzz stanzas (%s) - use a single fuzz runner per \
     directory"
    directory (List.length stanza_names)
    (String.concat ", " stanza_names)

let rule =
  Rule.v ~code:"E720" ~title:"Multiple Fuzz Stanzas in Directory"
    ~category:Testing
    ~hint:
      "Each fuzz directory should have exactly one executable stanza with a \
       single fuzz runner (fuzz.ml). Use (modules ...) to list all fuzz \
       modules in a single stanza."
    ~examples:[] ~pp (Project check)
