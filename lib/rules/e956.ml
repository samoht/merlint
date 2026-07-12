(** E956: Dead library dependency.

    A stanza's [(libraries ...)] entry is dead when no compilation unit of that
    library appears in the imports the compiler recorded in the stanza's [.cmt]
    artefacts. Matching happens on object names -- the linker-level unit
    identity -- so an internal [wire.ml] of a wrapped library [spy] is
    [Spy__Wire], never [Wire]: a doc-comment token or a source-basename
    collision with another library's entry module can neither hide a dead entry
    nor invent a live one. This is the artefact-backed replacement for
    text-based module-reference scans.

    Not flagged: [(re_export ...)] entries (an umbrella library exposes them to
    its dependents without importing them); stanzas with [-linkall] in
    [(link_flags ...)] (every dependent library links whole, so side-effect-only
    libraries are live); C-shipping libraries in stanzas with
    [(foreign_stubs ...)] (C code can reach their symbols without an OCaml
    import); virtual-library implementations ([(implements ...)] resolves at
    link time); builtin compiler-distributed libraries; libraries whose units
    are unknown (not indexed or not built). A stanza with a missing or stale
    [.cmt] for any of its sources is skipped rather than guessed at. *)

type payload = { stanza : string; library : string }

let pp ppf { stanza; library } =
  Fmt.pf ppf
    "%s is linked by stanza %s but never imported: no compilation unit of %s \
     appears in the stanza's .cmt imports. Remove it from (libraries ...)."
    library stanza library

module String_set = Set.Make (String)

(* Object names imported by one compiled unit, from its [.cmt] / [.cmti]. *)
let unit_imports cmt_path =
  match Ocaml_typing.Cmt_format.read_cmt cmt_path with
  | exception _ -> None
  | infos -> Some (List.map fst infos.Ocaml_typing.Cmt_format.cmt_imports)

(* Union of the imports of every unit in [files]; [None] when any unit's
   artefact is missing or stale -- the stanza is skipped, not judged. *)
let stanza_imports ~root files =
  List.fold_left
    (fun acc file ->
      match acc with
      | None -> None
      | Some set -> (
          match Build.cmt_artefact ~root file with
          | Some (cmt, true) -> (
              match unit_imports cmt with
              | Some units ->
                  Some
                    (List.fold_left
                       (fun set u -> String_set.add u set)
                       set units)
              | None -> None)
          | Some (_, false) | None -> None))
    (Some String_set.empty) files

(* One buildable stanza with a [(libraries ...)] field, whatever its kind. *)
type stanza = {
  name : string;
  dune : Fpath.t;
  files : Fpath.t list;
  libs : string list;
  links_all : bool;
  stubs : bool;
}

let library_stanzas pkg =
  Project_index.package_libraries pkg
  |> List.filter_map (fun lib ->
      match Project_index.Library.source_dir lib with
      | None -> None
      | Some dir ->
          if Project_index.Library.gated lib then None
          else
            (* A [(re_export X)] entry exposes X to this library's own
               dependents; an umbrella library never imports it. *)
            let re_exports = Project_index.Library.re_exports lib in
            Some
              {
                name = Project_index.Library.local_name lib;
                dune = Fpath.(dir / "dune");
                files = Project_index.Library.files lib;
                libs =
                  Project_index.Library.deps lib
                  |> List.filter (fun l -> not (List.mem l re_exports));
                links_all = Project_index.Library.links_all lib;
                stubs = Project_index.Library.has_foreign_stubs lib;
              })

(* [(executables (names a b))] records one source_stanza per name over the
   same directory, files and libraries; judge that stanza once. *)
let source_stanzas pkg =
  Project_index.Package.executable_stanzas pkg
  @ Project_index.Package.test_stanzas pkg
  |> List.filter (fun (s : Project_index.source_stanza) ->
      s.enabled && not s.gated)
  |> List.fold_left
       (fun (seen, acc) (s : Project_index.source_stanza) ->
         let key = (s.dir, s.files, s.libraries) in
         if List.mem key seen then (seen, acc)
         else
           ( key :: seen,
             {
               name = s.name;
               dune = Fpath.(s.dir / "dune");
               files = s.files;
               libs = s.libraries;
               links_all = s.links_all;
               stubs = s.has_foreign_stubs;
             }
             :: acc ))
       ([], [])
  |> snd |> List.rev

let dead_dep ~pkg ~imports ~stubs_stanza name =
  if Dep_deps.is_builtin name then None
  else
    match Project_index.library_used_by pkg name with
    | None -> None
    | Some lib ->
        if Project_index.Library.is_virtual_implementation lib then None
        else if stubs_stanza && Project_index.Library.has_foreign_stubs lib then
          None
        else
          let units = Project_index.Library.unit_names lib in
          if units = [] then None
          else if List.exists (fun u -> String_set.mem u imports) units then
            None
          else Some name

let check_stanza ~root ~pkg s =
  if s.links_all || s.files = [] then []
  else
    match stanza_imports ~root s.files with
    | None -> []
    | Some imports ->
        s.libs
        |> List.filter_map (dead_dep ~pkg ~imports ~stubs_stanza:s.stubs)
        |> List.map (fun library ->
            let loc = Loc.in_file (Loc.current_dir_relative s.dune) in
            Issue.v ~loc { stanza = s.name; library })

let check_package ~root pkg =
  library_stanzas pkg @ source_stanzas pkg
  |> List.concat_map (check_stanza ~root ~pkg)

let check ctx =
  let index = Context.index ctx in
  let root = Context.project_root_path ctx in
  Project_index.source_package_list index
  |> List.concat_map (check_package ~root)

let rule =
  Rule.v ~code:"E956" ~title:"Dead library dependency"
    ~hint:
      "A stanza's [(libraries ...)] entry is dead when no compilation unit of \
       that library appears in the imports the compiler recorded in the \
       stanza's [.cmt] files. Imports are matched by object name (an internal \
       [wire.ml] of library [spy] is [Spy__Wire], never [Wire]), so doc \
       comments and source-basename collisions cannot mask a dead entry. \
       Remove the entry or use the library. [(re_export ...)] entries, stanzas \
       with [-linkall], C-shipping libraries under [(foreign_stubs ...)] \
       stanzas, virtual-library implementations, and stanzas with missing or \
       stale artefacts are not flagged."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
