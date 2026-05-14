(** Shared helpers for the dep-declaration rules (E941..E944): predicates over
    library / package names that say "treat this as out-of-scope". *)

module String_set : Set.S with type elt = string

val build_tools : String_set.t
(** [build_tools] is the set of opam packages dune resolves as build tools
    rather than via [(libraries ...)] -- ocaml, dune, dune-configurator,
    js_of_ocaml, js_of_ocaml-compiler. The dep-declaration rules don't flag them
    as missing runtime deps even when absent from [depends:], nor as
    misclassified runtime deps just because their only consumer is a private
    executable. *)

val is_conf_pkg : string -> bool
(** [is_conf_pkg name] is [true] for [conf-*] packages -- system-library
    wrappers that don't expose OCaml libraries. *)

val is_builtin : string -> bool
(** [is_builtin lib] is [true] for libraries shipped with the OCaml distribution
    (unix, str, threads, etc.). *)

val local_packages : Project_index.t -> string list
(** [local_packages index] is the list of packages declared in the monorepo
    source tree (origin = Local), excluding those installed via opam. *)

val own_libs : Project_index.t -> string -> String_set.t
(** [own_libs index pkg] is the set of libraries declared by [pkg]. *)

val test_only_libs : Project_index.t -> string -> String_set.t
(** [test_only_libs index pkg] is the set of libraries declared by [pkg] whose
    only callers in the source tree are [(test ...)] / [(tests ...)] stanzas --
    private test helpers. Their [(libraries ...)] deps belong in [:with-test]
    (E943's territory), not in the runtime [depends:]. The classification is
    done by walking dune stanzas, not by directory name. *)
