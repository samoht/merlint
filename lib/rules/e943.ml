(** E943: Misclassified test-only dependency.

    A package declares an opam dep in its runtime [depends:], but every library
    that pulls in that dep lives in a test-scope stanza ([(test ...)],
    [(tests ...)], or a private [(executable ...)] with no [public_name]). The
    dep should carry a [{with-test}] filter -- otherwise [opam install <pkg>]
    forces downstream users to install the test framework just to run the
    package.

    Built off the {!Project_index}'s per-package usage split: every library used
    by [pkg] is classified as runtime or test, and runtime depends are
    cross-checked against that classification. *)

type payload = {
  package : string;
  misclassified_dep : string;
  used_via : string;
}

let resolve_pkgs index libs =
  List.fold_left
    (fun acc lib ->
      match Project_index.package_of index lib with
      | Some p -> Dep_deps.String_set.add p acc
      | None -> acc)
    Dep_deps.String_set.empty libs

let example_lib_for ~index ~package ~dep =
  Project_index.test_library_uses index package
  |> List.find_opt (fun lib -> Project_index.package_of index lib = Some dep)
  |> Option.value ~default:dep

let check_package index package =
  let runtime_uses = Project_index.runtime_library_uses index package in
  let test_uses = Project_index.test_library_uses index package in
  let runtime_pkgs = resolve_pkgs index runtime_uses in
  let test_pkgs = resolve_pkgs index test_uses in
  let runtime_depends = Project_index.depends index package in
  List.filter_map
    (fun dep ->
      if dep = package then None
      else if Dep_deps.is_conf_pkg dep then None
      else if Dep_deps.String_set.mem dep Dep_deps.build_tools then None
      else if Dep_deps.String_set.mem dep runtime_pkgs then None
      else if Dep_deps.String_set.mem dep test_pkgs then
        let used_via = example_lib_for ~index ~package ~dep in
        Some { package; misclassified_dep = dep; used_via }
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

let pp ppf p =
  Fmt.pf ppf
    "%s.opam declares %s in [depends:], but %s is only reached through \
     test-scope stanzas (e.g. library %s). Move it under a [{with-test}] \
     filter."
    p.package p.misclassified_dep p.misclassified_dep p.used_via

let rule =
  Rule.v ~code:"E943" ~title:"Misclassified test-only dependency"
    ~category:Rule.Project_structure
    ~hint:
      "A dep that's used only from [(test ...)] / [(tests ...)] stanzas or a \
       private [(executable ...)] (no [public_name]) belongs in [:with-test], \
       not in the runtime [depends:]. Add a [{with-test}] filter: in a \
       hand-written [<pkg>.opam], wrap the entry as [\"alcotest\" \
       {with-test}]; in a [dune-project] [(package (depends ...))] stanza, \
       write [(alcotest :with-test)]. Downstream users who [opam install \
       <pkg>] will then skip the test framework. Build-tool packages dune \
       resolves separately and [conf-*] system wrappers are exempt."
    ~examples:[] ~pp (Project check)
