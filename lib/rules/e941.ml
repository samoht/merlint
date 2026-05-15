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

let is_exempt_pkg used_pkg =
  Dep_deps.String_set.mem used_pkg Dep_deps.build_tools
  || Dep_deps.is_conf_pkg used_pkg

let check_used_lib ~index ~package ~depends_set ~own used_lib =
  if Dep_deps.is_builtin used_lib then `Skip
  else if Dep_deps.String_set.mem used_lib own then `Skip
  else
    match Project_index.package_of index used_lib with
    | None -> `Skip
    | Some used_pkg
      when used_pkg = package || is_exempt_pkg used_pkg
           || Dep_deps.String_set.mem used_pkg depends_set ->
        `Skip
    | Some used_pkg -> `Missing used_pkg

let check_lib ~index ~package ~depends_set ~own lib =
  let used_libs = Project_index.library_libraries index lib in
  List.filter_map
    (fun used_lib ->
      match check_used_lib ~index ~package ~depends_set ~own used_lib with
      | `Skip -> None
      | `Missing used_pkg ->
          Some
            {
              package;
              missing_dep = used_pkg;
              used_via = used_lib;
              source_lib = lib;
            })
    used_libs

let check_bin_use ~index ~package ~depends_set ~build_set bin =
  match Project_index.package_of_binary index bin with
  | None -> None
  | Some used_pkg
    when used_pkg = package
         || Dep_deps.String_set.mem used_pkg Dep_deps.build_tools
         || Dep_deps.String_set.mem used_pkg depends_set
         || Dep_deps.String_set.mem used_pkg build_set ->
      None
  | Some used_pkg ->
      Some
        {
          package;
          missing_dep = used_pkg;
          used_via = Fmt.str "%%{bin:%s}" bin;
          source_lib = "(rule)";
        }

let check_package index package =
  let libs = Project_index.libraries index package in
  let depends =
    Project_index.depends index package |> Dep_deps.String_set.of_list
  in
  let build_depends =
    Project_index.build_depends index package |> Dep_deps.String_set.of_list
  in
  let own = Dep_deps.own_libs index package in
  (* Skip libraries that are only referenced by test stanzas: their
     [(libraries ...)] deps are test-scope, not runtime. E943 covers those.
     The classification comes from project-index, which walks every
     dune stanza in the package at index-build time. *)
  let test_only = Dep_deps.test_only_libs index package in
  let runtime_libs =
    List.filter (fun lib -> not (Dep_deps.String_set.mem lib test_only)) libs
  in
  let lib_findings =
    List.concat_map
      (check_lib ~index ~package ~depends_set:depends ~own)
      runtime_libs
  in
  let bin_findings =
    Project_index.bin_uses index package
    |> List.filter_map
         (check_bin_use ~index ~package ~depends_set:depends
            ~build_set:build_depends)
  in
  lib_findings @ bin_findings

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
    "%s uses library %s (from package %s) via the (libraries ...) of %s, but \
     %s is missing from %s.opam's [depends:]. Add it."
    p.package p.used_via p.missing_dep p.source_lib p.missing_dep p.package

let rule =
  Rule.v ~code:"E941" ~title:"Missing runtime dependency"
    ~category:Rule.Project_structure
    ~hint:
      "When a library in your package's [(libraries L)] resolves to opam \
       package P, P must appear in your package's [depends:]. Otherwise [opam \
       install] from a fresh switch fails for downstream users -- your local \
       build only works because P happens to be in the active switch. The fix \
       depends on how you author opam metadata: if you hand-write \
       [<pkg>.opam], add the package to its [depends:]; if you let dune \
       generate [<pkg>.opam] from [dune-project], add it to the [(package \
       (depends ...))] stanza (use [<pkg>.opam.template] only for fields dune \
       can't generate). Builtin libraries (unix, str, threads, ...), \
       build-tool packages dune resolves separately (ocaml, dune, \
       js_of_ocaml), [conf-*] system-library wrappers, and libraries owned by \
       the package itself are exempt."
    ~examples:[] ~pp (Project check)
