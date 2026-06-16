(** E943: Misclassified runtime dependency.

    A package declares an opam dep in its runtime [depends:], but every library
    that pulls in that dep lives outside any runtime stanza, or the package does
    not use the dep at all. Three variants:

    - {b test scope}: the dep is reached from a [(test ...)] / [(tests ...)]
      stanza or a private executable attached to the [runtest] alias (fuzz
      driver, regression harness). Suggest [{with-test}].
    - {b dev-setup scope}: the dep is reached only from a private executable
      that is {b not} attached to [runtest] -- generator, benchmark, dev tool.
      Suggest [{with-dev-setup}].
    - {b unused}: the dep is not reached by any stanza in this package. A
      sibling package's executable never justifies this package's runtime
      [depends:].

    Either way, leaving the dep in unconditional [depends:] forces every
    downstream [opam install <pkg>] to pull machinery it doesn't need. *)

type suggestion = Test | Dev_setup | Remove

type payload = {
  package : string;
  misclassified_dep : string;
  used_via : string option;
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

let dep_provides_ocaml_libraries package name =
  match Project_index.package (P.index package) name with
  | None -> false
  | Some dep_pkg -> Project_index.package_libraries dep_pkg <> []

let closed_runtime_library_uses package =
  let libs = Project_index.package_libraries package in
  let name = Project_index.Library.name in
  let own_names = List.rev_map name libs |> Dep_deps.String_set.of_list in
  let deps_by_name =
    let tbl = Hashtbl.create 32 in
    List.iter
      (fun lib ->
        Hashtbl.replace tbl (name lib) (Project_index.Library.deps lib))
      libs;
    fun n -> match Hashtbl.find_opt tbl n with None -> [] | Some xs -> xs
  in
  let uses = P.runtime_library_uses package in
  let reachable = ref Dep_deps.String_set.empty in
  let rec visit n =
    if Dep_deps.String_set.mem n !reachable then ()
    else begin
      reachable := Dep_deps.String_set.add n !reachable;
      if Dep_deps.String_set.mem n own_names then
        List.iter visit (deps_by_name n)
    end
  in
  List.iter visit uses;
  Dep_deps.String_set.elements !reachable

let has_public_artifact package =
  Project_index.package_libraries package
  |> List.exists (fun lib ->
      Project_index.Library.public_name lib |> Option.is_some)
  || P.executable_stanzas package
     |> List.exists (fun (stanza : Project_index.source_stanza) ->
         stanza.public_names <> [])

(* Packages providing a binary referenced via [%{bin:X}] in this package. Such
   tools are build/test scope, never runtime-linked, so they are counted as
   test-scope reaches: a plain runtime [depends:] entry whose only use is such a
   tool is then flagged misclassified (suggest [{with-test}]) rather than unused
   (remove). E941 accepts the same tool in any scope. *)
let bin_use_packages package =
  P.bin_uses package
  |> List.filter_map (Project_index.package_of_binary (P.index package))
  |> List.fold_left
       (fun acc p -> Dep_deps.String_set.add p acc)
       Dep_deps.String_set.empty

let check_package package =
  let pkg_name = P.name package in
  let has_public_artifact = has_public_artifact package in
  let runtime_uses = closed_runtime_library_uses package in
  let test_uses = P.test_library_uses package in
  let dev_uses = P.dev_library_uses package in
  let runtime_pkgs = resolve_pkgs package runtime_uses in
  let test_pkgs =
    Dep_deps.String_set.union
      (resolve_pkgs package test_uses)
      (bin_use_packages package)
  in
  let dev_pkgs = resolve_pkgs package dev_uses in
  let runtime_depends = P.depends package in
  List.filter_map
    (fun dep ->
      if String.equal dep pkg_name then None
      else if Dep_deps.is_conf_pkg dep then None
      else if Dep_deps.String_set.mem dep Dep_deps.build_tools then None
      else if Dep_deps.String_set.mem dep runtime_pkgs then None
      else if Dep_deps.String_set.mem dep test_pkgs then
        let used_via = example_lib_for test_uses ~package ~dep in
        Some
          {
            package = pkg_name;
            misclassified_dep = dep;
            used_via = Some used_via;
            suggest = Test;
          }
      else if Dep_deps.String_set.mem dep dev_pkgs then
        let used_via = example_lib_for dev_uses ~package ~dep in
        Some
          {
            package = pkg_name;
            misclassified_dep = dep;
            used_via = Some used_via;
            suggest = Dev_setup;
          }
      else if has_public_artifact && dep_provides_ocaml_libraries package dep
      then
        Some
          {
            package = pkg_name;
            misclassified_dep = dep;
            used_via = None;
            suggest = Remove;
          }
      else None)
    runtime_depends

let check (ctx : Context.project) =
  Dep_deps.run_per_package ~check_package (Context.index ctx)

let suggest_str = function
  | Test -> "{with-test}"
  | Dev_setup -> "{with-dev-setup}"
  | Remove -> "remove it"

let scope_str = function
  | Test -> "test-scope stanzas (tests or runtest-attached executables)"
  | Dev_setup ->
      "dev-scope stanzas (private executables not attached to runtest)"
  | Remove -> "no stanza in this package"

let pp ppf p =
  match (p.suggest, p.used_via) with
  | Remove, _ ->
      Fmt.pf ppf
        "%s.opam declares %s in [depends:], but %s is not reached by any \
         stanza in package %s. Move it to the package that uses it, or remove \
         it."
        p.package p.misclassified_dep p.misclassified_dep p.package
  | (Test | Dev_setup), Some used_via ->
      Fmt.pf ppf
        "%s.opam declares %s in [depends:], but %s is only reached through %s \
         (e.g. library %s). Move it under a [%s] filter."
        p.package p.misclassified_dep p.misclassified_dep (scope_str p.suggest)
        used_via (suggest_str p.suggest)
  | (Test | Dev_setup), None ->
      Fmt.pf ppf
        "%s.opam declares %s in [depends:], but %s is only reached through %s. \
         Move it under a [%s] filter."
        p.package p.misclassified_dep p.misclassified_dep (scope_str p.suggest)
        (suggest_str p.suggest)

let rule =
  Rule.v ~code:"E943" ~title:"Misclassified runtime dependency"
    ~category:Rule.Project_structure
    ~hint:
      "A dep used only from [(test ...)] / [(tests ...)] or a runtest-attached \
       private executable belongs in [:with-test]. A dep used only from a \
       private executable that's not attached to [runtest] (generator, \
       benchmark, dev tool) belongs in [:with-dev-setup]. Add the appropriate \
       filter: in a hand-written [<pkg>.opam], wrap the entry as [\"alcotest\" \
       {with-test}] or [\"bench\" {with-dev-setup}]; in a [dune-project] \
       [(package (depends ...))] stanza, write [(alcotest :with-test)] or \
       [(bench :with-dev-setup)]. A dep not reached by any stanza in this \
       package should be removed from this package; a sibling executable must \
       declare its own dependency. Build-tool packages dune resolves \
       separately (dune, dune-configurator, js_of_ocaml, ocaml) and [conf-*] \
       system wrappers are exempt."
    ~examples:[] ~pp (Project check)
