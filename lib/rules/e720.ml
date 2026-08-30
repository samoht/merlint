(** E720: Multiple Fuzz Stanzas in Directory *)

type payload = {
  directory : string;
  package : string;
  stanza_names : string list;
}

(* Collect all stanza names in fuzz/ directories from both test and executable
   stanzas, keyed on the directory each stanza is declared in and the package it
   belongs to. The parent of a source file is not that directory: a
   [(copy_files ../other/fuzz.ml)] import compiles in the directory holding the
   stanza from a file that stays where it was named, so keying on a file's
   parent files the importing stanza under the directory it imported from and
   the two read as one directory holding two stanzas.

   The package is half the key because two fuzz stanzas in one directory are one
   runner split in two only when one package owns both. A dune stanza belongs to
   a single package, so a directory that fuzzes two of them has to declare two,
   and merging them would put both packages' dependencies in one link -- which
   in [ocaml-ssh/fuzz/dune] is the cycle through [ssh-eio] that the second
   stanza exists to keep out of [ssh]'s own fuzz build. *)
let fuzz_stanzas_by_dir ctx =
  let collect_dirs stanzas =
    List.filter_map
      (fun (stanza : Project_index.source_stanza) ->
        if
          String.starts_with ~prefix:"fuzz" stanza.name
          && File.is_fuzz_dir stanza.dir
        then Some ((Context.resolve ctx stanza.dir, stanza.package), stanza.name)
        else None)
      stanzas
  in
  collect_dirs (Context.test_stanzas ctx)
  @ collect_dirs (Context.executable_stanzas ctx)

let compare_key (dir, pkg) (dir', pkg') =
  match Path.compare dir dir' with 0 -> String.compare pkg pkg' | c -> c

let check (ctx : Context.project) =
  let by_dir = fuzz_stanzas_by_dir ctx in
  let keys = List.sort_uniq compare_key (List.map fst by_dir) in
  List.concat_map
    (fun ((dir, package) as key) ->
      let stanzas =
        List.filter_map
          (fun (k, name) -> if compare_key k key = 0 then Some name else None)
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
            {
              directory = Path.dir_display dir;
              package;
              stanza_names = stanzas;
            };
        ]
      else [])
    keys

let pp ppf { directory; package; stanza_names } =
  Fmt.pf ppf
    "Directory '%s' has %d fuzz stanzas for package %s (%s) - use a single \
     fuzz runner per package per directory"
    directory (List.length stanza_names) package
    (String.concat ", " stanza_names)

let rule =
  Rule.v ~code:"E720" ~title:"Multiple Fuzz Stanzas in Directory"
    ~category:Testing
    ~hint:
      "Each fuzz directory should have exactly one executable stanza per \
       package, with a single fuzz runner (fuzz.ml). Use (modules ...) to list \
       all fuzz modules in a single stanza. A directory fuzzing two packages \
       declares one stanza for each: a dune stanza belongs to a single \
       package, and merging them would link both packages' dependencies into \
       one executable."
    ~examples:[] ~pp (Project check)
