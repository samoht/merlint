(** E943: Misclassified test / dev dependency.

    A package declares an opam dep in its runtime [depends:], but every library
    that pulls in that dep lives outside any runtime stanza. Two variants:

    - {b test scope}: the dep is reached from a [(test ...)] / [(tests ...)]
      stanza or a private executable attached to the [runtest] alias (fuzz
      driver, regression harness). Suggest [{with-test}].
    - {b dev-setup scope}: the dep is reached only from a private executable
      that is {b not} attached to [runtest] -- generator, benchmark, dev tool.
      Suggest [{with-dev-setup}].

    Either way, leaving the dep in unconditional [depends:] forces every
    downstream [opam install <pkg>] to pull machinery it doesn't need. *)

type suggestion = Test | Dev_setup

type payload = {
  package : string;
  misclassified_dep : string;
  used_via : string;
  suggest : suggestion;
}

module P = Project_index.Package

let packages_of_lib package lib =
  Project_index.libraries_used_by package [ lib ]
  |> List.map Project_index.Library.package
  |> List.map Project_index.Package.name

let resolve_pkgs package libs =
  List.fold_left
    (fun acc lib ->
      packages_of_lib package lib
      |> List.fold_left (fun acc pkg -> Dep_deps.String_set.add pkg acc) acc)
    Dep_deps.String_set.empty libs

let example_lib_for libs ~package ~dep =
  libs
  |> List.find_opt (fun lib -> List.mem dep (packages_of_lib package lib))
  |> Option.value ~default:dep

let check_package package =
  let pkg_name = P.name package in
  let runtime_uses = P.runtime_library_uses package in
  let test_uses = P.test_library_uses package in
  let dev_uses = P.dev_library_uses package in
  let runtime_pkgs = resolve_pkgs package runtime_uses in
  let test_pkgs = resolve_pkgs package test_uses in
  let dev_pkgs = resolve_pkgs package dev_uses in
  let runtime_depends = P.depends package in
  List.filter_map
    (fun dep ->
      if dep = pkg_name then None
      else if Dep_deps.is_conf_pkg dep then None
      else if Dep_deps.String_set.mem dep Dep_deps.build_tools then None
      else if Dep_deps.String_set.mem dep runtime_pkgs then None
      else if Dep_deps.String_set.mem dep test_pkgs then
        let used_via = example_lib_for test_uses ~package ~dep in
        Some
          {
            package = pkg_name;
            misclassified_dep = dep;
            used_via;
            suggest = Test;
          }
      else if Dep_deps.String_set.mem dep dev_pkgs then
        let used_via = example_lib_for dev_uses ~package ~dep in
        Some
          {
            package = pkg_name;
            misclassified_dep = dep;
            used_via;
            suggest = Dev_setup;
          }
      else None)
    runtime_depends

let check (ctx : Context.project) =
  Dep_deps.run_per_package ~check_package (Context.index ctx)

let suggest_str = function
  | Test -> "{with-test}"
  | Dev_setup -> "{with-dev-setup}"

let scope_str = function
  | Test -> "test-scope stanzas (tests or runtest-attached executables)"
  | Dev_setup ->
      "dev-scope stanzas (private executables not attached to runtest)"

let pp ppf p =
  Fmt.pf ppf
    "%s.opam declares %s in [depends:], but %s is only reached through %s \
     (e.g. library %s). Move it under a [%s] filter."
    p.package p.misclassified_dep p.misclassified_dep (scope_str p.suggest)
    p.used_via (suggest_str p.suggest)

let rule =
  Rule.v ~code:"E943" ~title:"Misclassified test / dev dependency"
    ~category:Rule.Project_structure
    ~hint:
      "A dep used only from [(test ...)] / [(tests ...)] or a runtest-attached \
       private executable belongs in [:with-test]. A dep used only from a \
       private executable that's not attached to [runtest] (generator, \
       benchmark, dev tool) belongs in [:with-dev-setup]. Add the appropriate \
       filter: in a hand-written [<pkg>.opam], wrap the entry as [\"alcotest\" \
       {with-test}] or [\"bench\" {with-dev-setup}]; in a [dune-project] \
       [(package (depends ...))] stanza, write [(alcotest :with-test)] or \
       [(bench :with-dev-setup)]. Build-tool packages dune resolves separately \
       (dune, dune-configurator, js_of_ocaml, ocaml) and [conf-*] system \
       wrappers are exempt."
    ~examples:[] ~pp (Project check)
