(** E912: Package directory layout.

    OCaml code in an opam package lives in a fixed set of top-level component
    directories under the package root: [lib/] for libraries, [bin/] for
    executables, [test/] for tests and [fuzz/] for fuzzers, plus the auxiliary
    [bench/], [c/] and [examples/] directories. A [scripts/] directory may hold
    private helper executables (codegen, dune-configurator probes, repo
    tooling); anything with a [public_name] belongs in [bin/]. Sub-components
    nest under those roots ([lib/git/], [lib/eio/] for IO adapters,
    [test/interop/]); they never introduce new top-level directories
    ([foo/lib/], [foo/test/]).

    A finding is a dune file with a code stanza (library, executable or test)
    whose top-level directory under the package source root is not in the
    allowed set, sits at the package root itself, or is a public executable
    under [scripts/]. *)

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

(* Libraries and test stanzas: scripts/ is not an allowed home. *)
let check_dir ~package ~root dir =
  match segments ~root dir with
  | None -> None
  | Some (top :: _) when List.mem top allowed_dirs -> None
  | Some segs -> Some (issue ~package ~dir ~problem:Misplaced segs)

let check_executable ~package ~root (s : Project_index.source_stanza) =
  match segments ~root s.dir with
  | None -> None
  | Some (top :: _) when List.mem top allowed_dirs -> None
  | Some ("scripts" :: _ as segs) ->
      if s.public_names = [] then None
      else Some (issue ~package ~dir:s.dir ~problem:Public_in_scripts segs)
  | Some segs -> Some (issue ~package ~dir:s.dir ~problem:Misplaced segs)

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
        |> List.filter_map Project_index.Library.source_dir
        |> List.filter_map (check_dir ~package ~root)
      in
      let exe_issues =
        P.executable_stanzas pkg
        |> List.filter_map (check_executable ~package ~root)
      in
      let test_issues =
        P.test_stanzas pkg
        |> List.filter_map (fun (s : Project_index.source_stanza) ->
            check_dir ~package ~root s.dir)
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
        "%s: public executable in %s/; scripts/ holds private helper \
         executables, public executables live in bin/"
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
       examples/ for example programs. A scripts/ directory may hold private \
       helper executables (codegen, dune-configurator probes); anything with a \
       public_name belongs in bin/. Sub-components nest under those roots \
       (lib/<name>/ with test/<name>/, IO adapters in lib/eio/), never as new \
       top-level directories (foo/lib/, foo/test/)."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
