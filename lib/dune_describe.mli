(** Wrapper for dune commands. *)

type describe
(** Abstract type for dune describe results. *)

val describe : Fpath.t -> describe
(** [describe project_path] returns parsed dune describe output for a project.
*)

val excluded_subdirs_of_dune : Fpath.t -> string list
(** [excluded_subdirs_of_dune dir] reads [dir/dune] (when it exists) and returns
    the union of its [(data_only_dirs ...)] and [(vendored_dirs ...)]
    subdirectory lists. The directory walker uses this to skip subdirs the user
    has already opted out of for compilation purposes. Returns [[]] when no dune
    file is present, when the file fails to parse, or when neither stanza is
    set. *)

val skippable_subdir : parent_dir:Fpath.t -> string -> bool
(** [skippable_subdir ~parent_dir entry] is the single source of truth for
    "should we descend into [parent_dir/entry]?". Returns [true] for: empty
    names, names starting with ['.'] or ['_'] (dotfiles, [_build], [_opam],
    ad-hoc scratch), and any entry listed in [parent_dir]'s dune file
    [(data_only_dirs ...)] / [(vendored_dirs ...)] stanzas. Every filesystem
    walker — discovery and per-rule — calls this so the exclusion semantics stay
    consistent with what dune itself walks. *)

val ensure_project_built :
  path:string -> _ Eio.Process.mgr -> (unit, string) result
(** [ensure_project_built ~path mgr] ensures the project at [path] is built by
    running 'dune build path'. *)

val refresh_stale_cmt_targets :
  path:string ->
  files:Fpath.t list ->
  _ Eio.Process.mgr ->
  (unit, string) result
(** [refresh_stale_cmt_targets ~path ~files mgr] asks dune to rebuild existing
    [.cmt]/[.cmti] targets whose source file is newer than the typedtree
    artifact. This complements {!ensure_project_built}: native builds may update
    [.cmx] while leaving bytecode [.cmt] stale. *)

val is_executable : describe -> Fpath.t -> bool
(** [is_executable describe file_path] checks if a file is an executable (binary
    or test) - no .mli needed. *)

val project_files : describe -> Fpath.t list
(** [project_files describe] returns all project source files. *)

val executable_modules : describe -> string list
(** [executable_modules describe] gets executable module names from dune
    describe. *)

val lib_modules : describe -> string list
(** [lib_modules describe] gets library module names from dune describe. *)

val test_modules : describe -> string list
(** [test_modules describe] gets test module names from dune describe. *)

val merge : describe list -> describe
(** [merge describes] merges multiple describe values into one, deduplicating
    entries. *)

val exclude : string list -> describe -> describe
(** [exclude patterns describe] filters out files matching the given patterns
    from a describe. Patterns can be simple strings or use * for wildcards. *)

val synthetic : string list -> describe
(** [synthetic files] creates a synthetic describe for individual files passed
    on command line. *)

type library_info = {
  name : string; (* Internal library name *)
  public_name : string option; (* Public library name *)
  files : Fpath.t list;
  private_modules : string list;
      (* Module names listed in (private_modules ...) *)
}
(** Information about a library stanza *)

val libraries : describe -> library_info list
(** [libraries describe] returns the list of libraries with their information.
*)

val executables : describe -> (string * Fpath.t list) list
(** [executables describe] returns the list of executables with their name and
    files. *)

type test_info = {
  name : string;
  files : Fpath.t list;
  libraries : string list;
}
(** Information about a test stanza *)

val tests : describe -> test_info list
(** [tests describe] returns the list of test stanzas with their files and
    library dependencies. *)

val libraries_of_module : describe -> (string * string list) list
(** [libraries_of_module describe] maps module basenames to the libraries that
    contain them. *)

val resolve_library : describe -> string -> string
(** [resolve_library describe name] resolves a public library name to its
    internal name, or returns [name] unchanged if not found. *)

val test_file_library : (string * string list) list -> string -> string option
(** [test_file_library mod_to_libs basename] returns the library that a test
    file tests, based on the [test_<module>] naming convention. Returns [None]
    if the module is ambiguous or not found. *)
