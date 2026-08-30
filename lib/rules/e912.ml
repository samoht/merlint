(** E912: Package directory layout.

    OCaml code in an opam package lives in a fixed set of top-level component
    directories under the package root: [lib/] for libraries, [bin/] for
    executables, [test/] for tests and [fuzz/] for fuzzers, plus the auxiliary
    [bench/], [c/] and [examples/] directories. A [scripts/] directory may hold
    the private helpers a package builds with (codegen, dune-configurator
    probes, repo tooling), executables and the libraries beside them alike;
    anything with a [public_name] belongs in [bin/] or [lib/]. Sub-components
    nest under those roots ([lib/git/], [lib/eio/] for IO adapters,
    [test/interop/]); they never introduce new top-level directories
    ([foo/lib/], [foo/test/]).

    A finding is a dune file with a code stanza (library, executable or test)
    whose top-level directory under the package source root is not in the
    allowed set, sits at the package root itself, or is public code under
    [scripts/]. *)

type problem = Misplaced | Public_in_scripts
type payload = { package : string; dir : string; problem : problem }

module P = Project_index.Package

let allowed_dirs = [ "lib"; "bin"; "test"; "fuzz"; "bench"; "c"; "examples" ]

let segments ~root dir =
  match Fpath.relativize ~root dir with
  | None -> None
  | Some rel ->
      Some
        (Fpath.segs (Fpath.normalize rel)
        |> List.filter (fun s -> s <> "." && s <> ""))

let issue ~package ~dir ~problem segs =
  let rel = match segs with [] -> "." | _ -> String.concat "/" segs in
  let loc = Loc.current_dir_relative Fpath.(dir / "dune") |> Loc.in_file in
  Issue.v ~loc { package; dir = rel; problem }

(* [scripts/] is the one home outside the standard layout that code may have,
   and what earns it the exception is privacy, not the kind of stanza: a helper
   a package only builds with ships nothing, so there is no consumer to point at
   [bin/] or [lib/] for it. A helper factored out into a library beside those
   executables is the same helper with its own [.mli] and lives under the same
   exception -- writing it as one is what the tree asks for, not something to
   pay for by moving the directory. Public code is the other half of the same
   sentence: a [public_name] is a package saying it ships this, and what a
   package ships is looked for in [bin/] and [lib/]. A test is not a helper:
   [test/] is where the layout says tests are, and [scripts/] never covers
   one. *)
let check_code_dir ~package ~root ~scripts_allowed ~public dir =
  match segments ~root dir with
  | None -> None
  | Some (top :: _) when List.mem top allowed_dirs -> None
  | Some ("scripts" :: _ as segs) when scripts_allowed ->
      if public then Some (issue ~package ~dir ~problem:Public_in_scripts segs)
      else None
  | Some segs -> Some (issue ~package ~dir ~problem:Misplaced segs)

let check_library ~package ~root lib =
  match Project_index.Library.source_dir lib with
  | None -> None
  | Some dir ->
      check_code_dir ~package ~root ~scripts_allowed:true
        ~public:(Option.is_some (Project_index.Library.public_name lib))
        dir

let check_executable ~package ~root (s : Project_index.source_stanza) =
  check_code_dir ~package ~root ~scripts_allowed:true
    ~public:(s.public_names <> []) s.dir

let check_test ~package ~root (s : Project_index.source_stanza) =
  check_code_dir ~package ~root ~scripts_allowed:false ~public:false s.dir

(* Several stanzas can share a directory; keep one issue per finding. *)
let dedup issues =
  let seen = Hashtbl.create 16 in
  List.filter
    (fun i ->
      let { dir; problem; _ } = Issue.payload i in
      if Hashtbl.mem seen (dir, problem) then false
      else begin
        Hashtbl.add seen (dir, problem) ();
        true
      end)
    issues

let check_package pkg =
  match P.source_dir pkg with
  | None -> []
  | Some root ->
      let package = P.name pkg in
      let lib_issues =
        Project_index.package_libraries pkg
        |> List.filter_map (check_library ~package ~root)
      in
      let exe_issues =
        P.executable_stanzas pkg
        |> List.filter_map (check_executable ~package ~root)
      in
      let test_issues =
        P.test_stanzas pkg |> List.filter_map (check_test ~package ~root)
      in
      dedup (lib_issues @ exe_issues @ test_issues)

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_package_list
  |> List.filter (fun pkg -> not (P.is_anonymous pkg))
  |> List.concat_map check_package

let pp ppf { package; dir; problem } =
  match problem with
  | Public_in_scripts ->
      Fmt.pf ppf
        "%s: public code in %s/; scripts/ holds private helpers, public \
         executables live in bin/ and public libraries in lib/"
        package dir
  | Misplaced ->
      if dir = "." then
        Fmt.pf ppf
          "%s: code stanza at the package root; move libraries to lib/ and \
           executables to bin/"
          package
      else
        Fmt.pf ppf
          "%s: code in %s/ is outside the standard package layout; move \
           libraries under lib/, executables under bin/, tests under test/, \
           fuzzers under fuzz/"
          package dir

let rule =
  Rule.v ~code:"E912" ~title:"Package directory layout"
    ~hint:
      "Organise each opam package into the standard top-level component \
       directories: lib/ for libraries, bin/ for executables, test/ for tests, \
       fuzz/ for fuzzers, bench/ for benchmarks, c/ for C codegen and \
       examples/ for example programs. A scripts/ directory may hold the \
       private helpers a package builds with (codegen, dune-configurator \
       probes), executables and the libraries beside them alike; anything with \
       a public_name belongs in bin/ or lib/. Sub-components nest under those \
       roots (lib/<name>/ with test/<name>/, IO adapters in lib/eio/), never \
       as new top-level directories (foo/lib/, foo/test/)."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
