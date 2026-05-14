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

type suggestion = With_test | With_dev_setup

type payload = {
  package : string;
  misclassified_dep : string;
  used_via : string;
  suggest : suggestion;
}

let resolve_pkgs index libs =
  List.fold_left
    (fun acc lib ->
      match Project_index.package_of index lib with
      | Some p -> Dep_deps.String_set.add p acc
      | None -> acc)
    Dep_deps.String_set.empty libs

let example_lib_for libs ~index ~dep =
  libs
  |> List.find_opt (fun lib -> Project_index.package_of index lib = Some dep)
  |> Option.value ~default:dep

let check_package index package =
  let runtime_uses = Project_index.runtime_library_uses index package in
  let test_uses = Project_index.test_library_uses index package in
  let dev_uses = Project_index.dev_library_uses index package in
  let runtime_pkgs = resolve_pkgs index runtime_uses in
  let test_pkgs = resolve_pkgs index test_uses in
  let dev_pkgs = resolve_pkgs index dev_uses in
  let runtime_depends = Project_index.depends index package in
  List.filter_map
    (fun dep ->
      if dep = package then None
      else if Dep_deps.is_conf_pkg dep then None
      else if Dep_deps.String_set.mem dep Dep_deps.build_tools then None
      else if Dep_deps.String_set.mem dep runtime_pkgs then None
      else if Dep_deps.String_set.mem dep test_pkgs then
        let used_via = example_lib_for test_uses ~index ~dep in
        Some { package; misclassified_dep = dep; used_via; suggest = With_test }
      else if Dep_deps.String_set.mem dep dev_pkgs then
        let used_via = example_lib_for dev_uses ~index ~dep in
        Some
          {
            package;
            misclassified_dep = dep;
            used_via;
            suggest = With_dev_setup;
          }
      else None)
    runtime_depends

let opam_loc index pkg =
  match Project_index.source_dir index pkg with
  | Some dir ->
      Location.in_file (Fpath.to_string (Fpath.add_seg dir (pkg ^ ".opam")))
  | None -> Location.in_file (pkg ^ ".opam")

let check (ctx : Context.project) =
  let index = Context.index ctx in
  List.concat_map
    (fun pkg ->
      let loc = opam_loc index pkg in
      check_package index pkg |> List.map (fun p -> Issue.v ~loc p))
    (Dep_deps.local_packages index)

let suggest_str = function
  | With_test -> "{with-test}"
  | With_dev_setup -> "{with-dev-setup}"

let scope_str = function
  | With_test -> "test-scope stanzas (tests or runtest-attached executables)"
  | With_dev_setup ->
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
