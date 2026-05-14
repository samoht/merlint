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

(** Packages in the monorepo source tree (as opposed to installed in
    [_opam/lib]). A package counts as local when the index registered a source
    directory for it -- that happens whenever project-index finds a [<pkg>.opam]
    file during the source walk. We don't gate on [origin = Local] because that
    field is only set for packages with a matching install tree under
    [_build/install/default/lib]; on a fresh checkout before [dune build], all
    source packages would otherwise be invisible to this check. *)
let local_packages index =
  Project_index.packages index
  |> List.filter (fun pkg -> Project_index.source_dir index pkg <> None)

(** [own_libs index pkg] is the set of libraries declared by [pkg] itself -- a
    package never needs to declare a dep on itself. *)
let own_libs index pkg = String_set.of_list (Project_index.libraries index pkg)

(** [test_only_libs index pkg] is the set of libraries declared by [pkg] whose
    only references in the source tree are from [(test ...)] / [(tests ...)]
    stanzas -- test helpers whose [(libraries ...)] deps belong in [:with-test],
    not the runtime [depends:]. *)
let test_only_libs index pkg =
  String_set.of_list (Project_index.test_only_libraries index pkg)
