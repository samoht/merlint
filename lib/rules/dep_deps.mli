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

val is_project_target : string -> bool
(** [is_project_target name] is [true] when [name], drawn from
    {!Project_index.bin_uses}, is a target this project builds rather than a
    binary some opam package installs. [%{bin:NAME}] and [%{exe:PATH.exe}]
    arrive as one set of names, and two spellings mark the second: a path
    separator, which a [(public_name ...)] never contains, and a [.exe] suffix,
    which a [(public_name ...)] never ends in -- the only mark left on the
    same-directory spelling [%{exe:fuzz.exe}]. Such a name is not a dependency
    candidate, so "no package provides it" is an answer for it however narrow
    this run's scan was, and it is never handed to {!note_unresolved}. *)

val own_libs : Project_index.Package.t -> String_set.t
(** [own_libs pkg] is the set of libraries declared by [pkg]. *)

val test_only_libs : Project_index.Package.t -> String_set.t
(** [test_only_libs pkg] is the set of libraries declared by [pkg] whose only
    references in the source tree are from [(test ...)] / [(tests ...)] stanzas.
*)

val opam_loc : Project_index.Package.t -> Location.t
(** [opam_loc pkg] is a [Location.t] pointing at the start of [pkg]'s [.opam]
    file. *)

val resolution_note : Context.project -> rule:string -> string -> unit
(** [resolution_note ctx ~rule question] is the sink a dep rule hands its
    unresolved names to, partially applied to the calling rule's code. Over a
    whole-project index it discards them: every in-tree package was read, so "no
    package provides this name" is an answer. Over a narrowed one
    ({!Context.index_is_partial}) it records them through
    {!Context.cannot_evaluate}, because there the same lookup cannot tell a name
    nothing provides from one whose provider this run never scanned. *)

val note_unresolved :
  note:(string -> unit) ->
  package:Project_index.Package.t ->
  what:string ->
  string ->
  unit
(** [note_unresolved ~note ~package ~what name] hands [note] one sentence: no
    package provides [name] (a [what] -- "library", "binary"), and [package]
    uses it. The index answers "nothing provides it" both when nothing does and
    when this run never scanned whatever does, so the rule cannot say whether
    [package] declares it. Pass {!Context.cannot_evaluate} partially applied to
    the calling rule's code. *)

val run_per_package :
  check_package:(Project_index.Package.t -> 'a list) ->
  Project_index.t ->
  'a Issue.t list
(** [run_per_package ~check_package index] applies [check_package] to every
    {!Project_index.source_package_list}, attaches an {!opam_loc} to each
    payload, and concatenates the results. *)
