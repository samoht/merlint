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

val own_libs : Project_index.Package.t -> String_set.t
(** [own_libs pkg] is the set of libraries declared by [pkg]. *)

val test_only_libs : Project_index.Package.t -> String_set.t
(** [test_only_libs pkg] is the set of libraries declared by [pkg] whose only
    references in the source tree are from [(test ...)] / [(tests ...)] stanzas.
*)

val opam_loc : Project_index.Package.t -> Location.t
(** [opam_loc pkg] is a [Location.t] pointing at the start of [pkg]'s [.opam]
    file. *)

val run_per_package :
  check_package:(Project_index.Package.t -> 'a list) ->
  Project_index.t ->
  'a Issue.t list
(** [run_per_package ~check_package index] applies [check_package] to every
    {!Project_index.source_package_list}, attaches an {!opam_loc} to each
    payload, and concatenates the results. *)
