(** E620: Multiple Test Stanzas in Directory *)

type payload = { directory : string; stanza_names : string list }

let check (ctx : Context.project) =
  (* Group test stanzas by directory *)
  let by_dir =
    List.filter_map
      (fun (t : Project_index.source_stanza) ->
        match t.files with
        | f :: _ -> Some (Fpath.parent f |> Fpath.to_string, t.name)
        | [] -> None)
      (Context.test_stanzas ctx)
  in
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
    "Directory '%s' has %d test stanzas (%s) - use a single test runner per \
     directory"
    directory (List.length stanza_names)
    (String.concat ", " stanza_names)

let rule =
  Rule.v ~code:"E620" ~title:"Multiple Test Stanzas in Directory"
    ~category:Testing
    ~hint:
      "Each test directory should have exactly one test stanza with a single \
       test runner (test.ml). Multiple test stanzas in the same directory \
       cause module ownership conflicts and break @check builds."
    ~examples:[] ~pp (Project check)
