(** E942: Disallowed library dependency.

    Bans configured library / opam-package names from a package's dependencies.
    The ban list is [disallowed_libraries] in [merlint.toml] (read from the
    project root, since this is a project-scoped rule); it is empty by default,
    so the rule is silent until a project opts in.

    A package is flagged when one of its banned names appears in any
    [(libraries ...)] field it owns -- across its libraries, executables, and
    tests -- or in its opam [depends:]. Matching is literal on the name as
    written, so [fmt] catches both [(libraries fmt)] and a [fmt] runtime
    dependency. This is the build-level companion to E221, which bans module
    {e use} in source. *)

type payload = { package : string; library : string }

module P = Project_index.Package

let stanza_libraries stanzas =
  List.concat_map
    (fun (stanza : Project_index.source_stanza) -> stanza.libraries)
    stanzas

(** [used_libraries package] is every library / opam-package name [package]
    depends on: the [(libraries ...)] of its own libraries, executables and
    tests, plus its opam [depends:]. *)
let used_libraries package =
  List.concat
    [
      Project_index.package_libraries package
      |> List.concat_map Project_index.Library.deps;
      stanza_libraries (P.executable_stanzas package);
      stanza_libraries (P.test_stanzas package);
      P.depends package;
    ]
  |> List.sort_uniq String.compare

let check_package disallowed package =
  let disallowed = Dep_deps.String_set.of_list disallowed in
  let own = Dep_deps.own_libs package in
  used_libraries package
  |> List.filter (fun lib ->
      Dep_deps.String_set.mem lib disallowed
      && not (Dep_deps.String_set.mem lib own))
  |> List.map (fun library -> { package = P.name package; library })

let check (ctx : Context.project) =
  match ctx.config.disallowed_libraries with
  | [] -> []
  | disallowed ->
      Dep_deps.run_per_package ~check_package:(check_package disallowed)
        (Context.index ctx)

let pp ppf { package; library } =
  Fmt.pf ppf
    "%s depends on %s, which is disallowed by disallowed_libraries in \
     merlint.toml. Remove it from the package's (libraries ...) and \
     [depends:]."
    package library

let rule =
  Rule.v ~code:"E942" ~title:"Disallowed library dependency"
    ~category:Rule.Project_structure
    ~hint:
      "This package links or declares a dependency banned by the \
       [disallowed_libraries] list in merlint.toml. Drop the dependency, or \
       relax the ban. The list is empty by default; set it (e.g. \
       [disallowed_libraries = [\"fmt\"]]) to enforce a build-level boundary, \
       the companion to E221's source-level module ban."
    ~examples:[] ~pp (Project check)
