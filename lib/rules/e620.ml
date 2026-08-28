(** E620: Multiple Test Stanzas in Directory *)

type payload = { directory : string; stanza_names : string list }

(* Group by the directory the stanza is declared in, which the stanza record
   carries. The parent of a source file is not that directory: a
   [(copy_files ../js/test.ml)] import compiles in the directory holding the
   stanza from a file that stays where it was named, so keying on a file's
   parent files the importing stanza under the directory it imported from and
   the two read as one directory holding two stanzas. *)
let check (ctx : Context.project) =
  let by_dir =
    List.map
      (fun (t : Project_index.source_stanza) ->
        (Context.resolve ctx t.dir, t.name))
      (Context.test_stanzas ctx)
  in
  let dirs = List.sort_uniq Path.compare (List.map fst by_dir) in
  List.concat_map
    (fun dir ->
      let stanzas =
        List.filter_map
          (fun (d, name) -> if Path.compare d dir = 0 then Some name else None)
          by_dir
      in
      if List.length stanzas > 1 then
        let loc =
          Location.v
            ~file:(Context.string_of_path Path.(dir / "dune"))
            ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
        in
        [
          Issue.v ~loc
            { directory = Path.dir_display dir; stanza_names = stanzas };
        ]
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
