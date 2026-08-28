(** Shared helpers for the dep-declaration rules (E941..E944): predicates over
    library / package names that say "treat this as out-of-scope". *)

module String_set = Set.Make (String)

(** Top-level libraries shipped by the OCaml distribution -- no opam dep
    required to use them. *)
let ocaml_builtins = String_set.of_list Opam.Package.ocaml_builtins

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

(** [own_libs pkg] is the set of libraries declared by [pkg] itself -- a package
    never needs to declare a dep on itself. *)
let own_libs pkg = String_set.of_list (Project_index.Package.library_names pkg)

(** [test_only_libs pkg] is the set of libraries declared by [pkg] whose only
    references in the source tree are from [(test ...)] / [(tests ...)] stanzas
    -- test helpers whose [(libraries ...)] deps belong in [:with-test], not the
    runtime [depends:]. *)
let test_only_libs pkg =
  String_set.of_list (Project_index.Package.test_only_library_names pkg)

(** [opam_loc pkg] is a [Location.t] pointing at line 1 column 0 of [pkg]'s
    [.opam] file. Falls back to a bare relative [<pkg>.opam] when the index has
    no source directory for the package. *)
let opam_loc pkg =
  match Project_index.Package.opam_path pkg with
  | Some path -> Loc.in_file (Loc.current_dir_relative path)
  | None -> Location.in_file (Project_index.Package.name pkg ^ ".opam")

(** [resolution_note ctx ~rule] is what a dep rule calls when the index answers
    "no package provides this name". Over a whole-project index that is an
    answer -- every in-tree package was read, and a name from outside would have
    to come from the switch, which is scanned for exactly the names the sources
    reference -- so the note is dropped and the rule's silence means what it
    says. Over a narrowed index it is not an answer: the provider may sit in a
    directory this run never scanned, and the rule reads that the same way it
    reads "the declaration is fine", both being the empty list. So there it is
    recorded under [rule] and the run counts it apart from the findings. *)
let resolution_note ctx ~rule =
  if Context.index_is_partial ctx then Context.cannot_evaluate ctx ~rule
  else fun (_ : string) -> ()

(** [note_unresolved ~note ~package ~what name] hands [note] the sentence for
    one such name: what could not be resolved, and which package used it. It
    reaches the user through [--json]; the text summary counts the rule. *)
let note_unresolved ~note ~package ~what name =
  Fmt.kstr note "no package provides %s %s, used by %s" what name
    (Project_index.Package.name package)

(** [run_per_package ~check_package index] applies [check_package] to every
    {!Project_index.source_package_list}, attaches an [opam_loc]-derived
    location to each payload, and concatenates the results. The shared driver
    for package-level dep-declaration rules. *)
let run_per_package ~check_package index =
  List.concat_map
    (fun pkg ->
      let loc = opam_loc pkg in
      check_package pkg |> List.map (fun p -> Issue.v ~loc p))
    (Project_index.source_package_list index)
