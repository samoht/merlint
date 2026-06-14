(** E941: Missing runtime dependency.

    A library in this package's [(libraries ...)] resolves to an opam package
    that isn't declared in the package's runtime [depends:]. [opam install] from
    a fresh switch can't build the package -- the missing dependency happens to
    be in the active switch for the local build to succeed, but downstream users
    don't get it for free.

    Built off the {!Project_index}: every package's library set, every library's
    [(libraries ...)] field, and every package's runtime [depends:] (already
    filtered to drop [{with-test}] / [{with-doc}]) are read from the index.
    Builtin libraries, implicit packages, [conf-*] packages, and the package's
    own libraries are excluded. *)

type payload = {
  package : string;
  missing_dep : string;
  used_via : string;
  source_lib : string;
}

module P = Project_index.Package

let is_exempt_pkg used_pkg =
  Dep_deps.String_set.mem used_pkg Dep_deps.build_tools
  || Dep_deps.is_conf_pkg used_pkg

let check_used_lib ~package ~depends_set ~own used_lib =
  if Dep_deps.is_builtin used_lib then `Skip
  else if Dep_deps.String_set.mem used_lib own then `Skip
  else
    match Project_index.library_used_by package used_lib with
    | None -> `Skip
    | Some lib ->
        let used_pkg = P.name (Project_index.Library.package lib) in
        if
          used_pkg = P.name package
          || is_exempt_pkg used_pkg
          || Dep_deps.String_set.mem used_pkg depends_set
        then `Skip
        else `Missing used_pkg

let check_lib ~package ~depends_set ~own lib =
  let lib_name = Project_index.Library.name lib in
  Project_index.Library.deps lib
  |> List.filter_map (fun used_lib ->
      match check_used_lib ~package ~depends_set ~own used_lib with
      | `Skip -> None
      | `Missing used_pkg ->
          Some
            {
              package = P.name package;
              missing_dep = used_pkg;
              used_via = used_lib;
              source_lib = lib_name;
            })

let check_runtime_use ~package ~depends_set ~own used_lib =
  match check_used_lib ~package ~depends_set ~own used_lib with
  | `Skip -> None
  | `Missing used_pkg ->
      Some
        {
          package = P.name package;
          missing_dep = used_pkg;
          used_via = used_lib;
          source_lib = "a public executable";
        }

(* A [%{bin:X}] reference is a tool dependency: the binary is run when a rule or
   cram test fires (build or test time), not linked at runtime. So it is
   satisfied by the providing package appearing in any dependency scope --
   runtime [depends:], build, or [{with-test}] -- not only runtime. *)
let check_bin_use ~package ~depends_set ~build_set ~test_set bin =
  match Project_index.package_of_binary (P.index package) bin with
  | None -> None
  | Some used_pkg
    when used_pkg = P.name package
         || Dep_deps.String_set.mem used_pkg Dep_deps.build_tools
         || Dep_deps.String_set.mem used_pkg depends_set
         || Dep_deps.String_set.mem used_pkg build_set
         || Dep_deps.String_set.mem used_pkg test_set ->
      None
  | Some used_pkg ->
      Some
        {
          package = P.name package;
          missing_dep = used_pkg;
          used_via = Fmt.str "%%{bin:%s}" bin;
          source_lib = "(rule)";
        }

(* E941 should fire only for libraries that [opam install] actually builds,
   i.e. those reachable from a public (installed) artifact. A stanza is
   install-reachable iff it has a [public_name], or it is linked (via
   [(libraries ...)]) by an install-reachable stanza. Seed the set with the
   package's public libraries and the libraries linked directly by its public
   executables, then close over [(libraries ...)] edges within the package. A
   private library reached only from private executables (e.g.
   [enabled_if]-gated benches) is never installed, so its deps belong in
   [{with-test}] and stay out of this set; E943 covers their (libraries). *)
let install_reachable_libs package =
  let libs = Project_index.package_libraries package in
  let name = Project_index.Library.name in
  let own_names = List.rev_map name libs |> Dep_deps.String_set.of_list in
  let deps_within =
    let tbl = Hashtbl.create 32 in
    List.iter
      (fun lib ->
        Hashtbl.replace tbl (name lib)
          (Project_index.Library.deps lib
          |> List.filter (fun d -> Dep_deps.String_set.mem d own_names)))
      libs;
    fun n -> try Hashtbl.find tbl n with Not_found -> []
  in
  let public_libs =
    List.filter_map
      (fun lib ->
        Option.map (fun _ -> name lib) (Project_index.Library.public_name lib))
      libs
  in
  let public_exe_libs =
    P.executable_stanzas package
    |> List.filter (fun (s : Project_index.source_stanza) ->
        s.public_names <> [])
    |> List.concat_map (fun (s : Project_index.source_stanza) -> s.libraries)
    |> List.filter (fun l -> Dep_deps.String_set.mem l own_names)
  in
  let reachable = ref Dep_deps.String_set.empty in
  let rec visit n =
    if not (Dep_deps.String_set.mem n !reachable) then begin
      reachable := Dep_deps.String_set.add n !reachable;
      List.iter visit (deps_within n)
    end
  in
  List.iter visit (public_libs @ public_exe_libs);
  List.filter (fun lib -> Dep_deps.String_set.mem (name lib) !reachable) libs

let check_package package =
  let depends = P.depends package |> Dep_deps.String_set.of_list in
  let build_depends = P.build_depends package |> Dep_deps.String_set.of_list in
  let test_depends = P.test_depends package |> Dep_deps.String_set.of_list in
  let own = Dep_deps.own_libs package in
  let runtime_libs = install_reachable_libs package in
  let lib_findings =
    List.concat_map (check_lib ~package ~depends_set:depends ~own) runtime_libs
  in
  let libs_checked =
    runtime_libs
    |> List.concat_map Project_index.Library.deps
    |> Dep_deps.String_set.of_list
  in
  let executable_findings =
    P.executable_stanzas package
    |> List.filter (fun (stanza : Project_index.source_stanza) ->
        stanza.public_names <> [])
    |> List.concat_map (fun (stanza : Project_index.source_stanza) ->
        stanza.libraries)
    |> List.sort_uniq String.compare
    |> List.filter (fun used_lib ->
        not (Dep_deps.String_set.mem used_lib libs_checked))
    |> List.filter_map (check_runtime_use ~package ~depends_set:depends ~own)
  in
  let bin_findings =
    P.bin_uses package
    |> List.filter_map
         (check_bin_use ~package ~depends_set:depends ~build_set:build_depends
            ~test_set:test_depends)
  in
  lib_findings @ executable_findings @ bin_findings

let check (ctx : Context.project) =
  Dep_deps.run_per_package ~check_package (Context.index ctx)

let pp ppf p =
  Fmt.pf ppf
    "%s uses library %s (from package %s) via the (libraries ...) of %s, but \
     %s is missing from %s.opam's [depends:]. Add it."
    p.package p.used_via p.missing_dep p.source_lib p.missing_dep p.package

let rule =
  Rule.v ~code:"E941" ~title:"Missing runtime dependency"
    ~category:Rule.Project_structure
    ~hint:
      "When a library in your package's [(libraries L)] resolves to opam \
       package P, P must appear in your package's [depends:]. This includes \
       libraries linked by public executables, since [opam install] builds \
       those through [@install]. Otherwise [opam install] from a fresh switch \
       fails for downstream users -- your local build only works because P \
       happens to be in the active switch. The fix depends on how you author \
       opam metadata: if you hand-write [<pkg>.opam], add the package to its \
       [depends:]; if you let dune generate [<pkg>.opam] from [dune-project], \
       add it to the [(package (depends ...))] stanza (use \
       [<pkg>.opam.template] only for fields dune can't generate). Builtin \
       libraries (unix, str, threads, ...), build-tool packages dune resolves \
       separately (ocaml, dune, js_of_ocaml), [conf-*] system-library \
       wrappers, and libraries owned by the package itself are exempt."
    ~examples:[] ~pp (Project check)
