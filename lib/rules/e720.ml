(** E720: Multiple Fuzz Stanzas in Directory *)

type payload = { directory : string; stanza_names : string list }

(** Collect all stanza names in fuzz/ directories from both test and executable
    stanzas. *)
let fuzz_stanzas_by_dir ctx =
  let collect_dirs stanzas =
    List.filter_map
      (fun (stanza : Project_index.source_stanza) ->
        let name = stanza.name in
        if not (String.starts_with ~prefix:"fuzz" name) then None
        else
          match
            List.find_opt
              (fun f -> Fpath.has_ext ".ml" f && File.is_in_fuzz_dir f)
              stanza.files
          with
          | Some f -> Some (Context.Path.parent (Context.resolve ctx f), name)
          | None -> None)
      stanzas
  in
  collect_dirs (Context.test_stanzas ctx)
  @ collect_dirs (Context.executable_stanzas ctx)

let check (ctx : Context.project) =
  let by_dir = fuzz_stanzas_by_dir ctx in
  let dirs = List.sort_uniq Context.Path.compare (List.map fst by_dir) in
  List.concat_map
    (fun dir ->
      let stanzas =
        List.filter_map
          (fun (d, name) ->
            if Context.Path.compare d dir = 0 then Some name else None)
          by_dir
      in
      if List.length stanzas > 1 then
        let loc =
          Location.v
            ~file:(Context.string_of_path Context.Path.(dir / "dune"))
            ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
        in
        [
          Issue.v ~loc
            {
              directory = Context.Path.dir_display_string dir;
              stanza_names = stanzas;
            };
        ]
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
