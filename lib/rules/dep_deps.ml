(** Shared helpers for the dep-declaration rules (E941..E944): predicates over
    library / package names that say "treat this as out-of-scope". *)

module String_set = Set.Make (String)

(** Top-level libraries shipped by the OCaml distribution -- no opam dep
    required to use them. *)
let ocaml_builtins =
  String_set.of_list
    [
      "unix";
      "threads";
      "str";
      "dynlink";
      "bigarray";
      "stdlib";
      "runtime_events";
      "compiler-libs";
      "ocamlfind";
      "findlib";
      "bytes";
    ]

(** Build-time tools rather than runtime libraries: the OCaml compiler, the dune
    build system, and the [js_of_ocaml] binary used to compile bytecode to
    JavaScript. These do show up in [depends:] for real builds, but the
    dep-declaration rules don't flag them as "missing runtime deps" because dune
    resolves them as tools rather than as [(libraries ...)] entries. *)
let build_tools =
  String_set.of_list
    [
      "ocaml";
      "dune";
      "dune-configurator";
      "js_of_ocaml";
      "js_of_ocaml-compiler";
    ]

(** [conf-*] packages wrap system libraries (e.g. [conf-libssl]); they aren't
    OCaml libraries and don't show up in [(libraries ...)]. *)
let is_conf_pkg name = String.starts_with ~prefix:"conf-" name

let top_namespace name =
  match String.index_opt name '.' with
  | Some i -> String.sub name 0 i
  | None -> name

(** [is_builtin lib] is [true] if [lib] (or its top namespace) is an OCaml
    distribution library: [unix], [str], [threads.posix], etc. *)
let is_builtin lib = String_set.mem (top_namespace lib) ocaml_builtins

(** [own_libs index pkg] is the set of libraries declared by [pkg] itself -- a
    package never needs to declare a dep on itself. *)
let own_libs index pkg = String_set.of_list (Project_index.libraries index pkg)

(** [test_only_libs index pkg] is the set of libraries declared by [pkg] whose
    only references in the source tree are from [(test ...)] / [(tests ...)]
    stanzas -- test helpers whose [(libraries ...)] deps belong in [:with-test],
    not the runtime [depends:]. *)
let test_only_libs index pkg =
  String_set.of_list (Project_index.test_only_libraries index pkg)

(** [opam_loc index pkg] is a [Location.t] pointing at line 1 column 0 of
    [pkg]'s [.opam] file. Falls back to a bare relative [<pkg>.opam] when the
    index has no source directory for the package. *)
let opam_loc index pkg =
  match Project_index.opam_path index pkg with
  | Some path -> Location.in_file (Fpath.to_string path)
  | None -> Location.in_file (pkg ^ ".opam")

(** [run_per_package ~check_package index] applies [check_package] to every
    {!Project_index.source_packages}, attaches an [opam_loc]-derived location to
    each payload, and concatenates the results. The shared driver for
    package-level dep-declaration rules. *)
let run_per_package ~check_package index =
  List.concat_map
    (fun pkg ->
      let loc = opam_loc index pkg in
      check_package index pkg |> List.map (fun p -> Issue.v ~loc p))
    (Project_index.source_packages index)
